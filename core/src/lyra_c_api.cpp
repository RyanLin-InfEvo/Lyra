// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <cstring>
#include <fmt/core.h>
#include <memory>
#include <nlohmann/json.hpp>
#include <string>

#include "lyra_c_api.h"
#include "router.h"

using json = nlohmann::json;
using namespace lyra;

namespace {
std::unique_ptr<Router> g_router;
}

// Lyra core initialization
int lyra_init(const char *storage_root) {
    try {
        if (storage_root == nullptr) {
            throw std::invalid_argument("storage_root is null");
        }

        // Security: Limit storage_root length to prevent DoS or path overflow
        const size_t MAX_PATH_LENGTH = 4096;
        if (strnlen(storage_root, MAX_PATH_LENGTH + 1) > MAX_PATH_LENGTH) {
            throw std::length_error("storage_root exceeds maximum length (4096)");
        }

        std::string db_path = std::string(storage_root) + "/lyra.db";
        g_router = std::make_unique<Router>(db_path);
        return 0;

    } catch (const std::exception &e) {
        return -1;
    }
}

char *lyra_dispatch(const char *json_request) {
    try {
        if (json_request == nullptr) {
            throw std::invalid_argument("JSON request is null");
        }

        if (!g_router) {
            throw std::runtime_error("Lyra not initialized. Call lyra_init first.");
        }

        // Security: Limit JSON length to prevent DoS (10MB)
        const size_t MAX_JSON_LENGTH = 10 * 1024 * 1024;
        if (strnlen(json_request, MAX_JSON_LENGTH + 1) > MAX_JSON_LENGTH) {
            throw std::runtime_error("JSON request exceeds maximum length (10MB)");
        }

        // Security: Limit JSON depth to prevent stack overflow (max 64 levels)
        const int MAX_JSON_DEPTH = 64;
        json request = json::parse(json_request, [](int depth, json::parse_event_t event, json &parsed) {
            if (depth > MAX_JSON_DEPTH) {
                throw std::runtime_error("JSON exceeds maximum nesting depth (64)");
            }
            return true;
        });

        json response = g_router->route(request);

        // Convert JSON object to string
        std::string response_str = response.dump();

        // Return response string
        return strdup(response_str.c_str());

    } catch (const std::exception &e) {

        json error_res;
        error_res["code"] = 400;
        error_res["error"]["message"] = e.what();
        return strdup(error_res.dump().c_str());
    } catch (...) {
        json error_res;
        error_res["code"] = 500;
        error_res["error"]["message"] = "UNKNOWN_FATAL_ERROR: An unknown error bypassed all exception handlers.";
        return strdup(error_res.dump().c_str());
    }
}

// Free memory
void lyra_free_string(char *str) {
    if (str != nullptr) {
        free(str);
    }
}
