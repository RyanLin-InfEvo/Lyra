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

        // Parsing JSON strings into JSON objects
        json request = json::parse(json_request);

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
