// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <cstring>
#include <fmt/core.h>
#include <nlohmann/json.hpp>
#include <string>

#include "lyra_c_api.h"
#include "router.h"
#include "services/database_manager.h"

using json = nlohmann::json;
using namespace lyra;

// Lyra core initialization
int lyra_init(const char *storage_root) {
    try {
        std::string db_path = std::string(storage_root) + "/lyra.db";
        DatabaseManager::init_database(db_path);
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

        json response = Router::route(request);

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
