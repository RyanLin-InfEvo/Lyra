/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/make_error.h"
#include <cassert>
#include <iostream>
#include <string>

using namespace lyra;

bool test_api_response_success() {
    std::cout << "Running test_api_response_success..." << std::endl;

    json data = {{"key", "value"}};
    json res = ApiResponse::success(data);

    if (res["code"] != 200) {
        std::cerr << "test_api_response_success failed: code is not 200" << std::endl;
        return false;
    }
    if (res["data"]["key"] != "value") {
        std::cerr << "test_api_response_success failed: data is incorrect" << std::endl;
        return false;
    }

    return true;
}

bool test_api_response_error_mapping() {
    std::cout << "Running test_api_response_error_mapping..." << std::endl;

    // Test 1: ArtistNotFound (404 series)
    {
        json res = ApiResponse::error({ErrorType::ArtistNotFound, "Artist not found"});
        if (res["code"] != 404) {
            std::cerr << "Test ArtistNotFound failed: code is not 404" << std::endl;
            return false;
        }
        if (res["error"]["type"] != "ArtistNotFound") {
            std::cerr << "Test ArtistNotFound failed: type is not 'ArtistNotFound'" << std::endl;
            return false;
        }
        if (res["error"]["message"] != "Artist not found") {
            std::cerr << "Test ArtistNotFound failed: message is incorrect" << std::endl;
            return false;
        }
    }

    // Test 2: MissingParameter (400 series)
    {
        json res = ApiResponse::error({ErrorType::MissingParameter, "Missing param"});
        if (res["code"] != 400) {
            std::cerr << "Test MissingParameter failed: code is not 400" << std::endl;
            return false;
        }
        if (res["error"]["type"] != "MissingParameter") {
            std::cerr << "Test MissingParameter failed: type is not 'MissingParameter'" << std::endl;
            return false;
        }
    }

    // Test 3: Conflict (409)
    {
        json res = ApiResponse::error({ErrorType::Conflict, "Conflict detected"});
        if (res["code"] != 409) {
            std::cerr << "Test Conflict failed: code is not 409" << std::endl;
            return false;
        }
        if (res["error"]["type"] != "Conflict") {
            std::cerr << "Test Conflict failed: type is not 'Conflict'" << std::endl;
            return false;
        }
    }

    // Test 4: DatabaseError (500 series)
    {
        json res = ApiResponse::error({ErrorType::DatabaseError, "Db failed"});
        if (res["code"] != 500) {
            std::cerr << "Test DatabaseError failed: code is not 500" << std::endl;
            return false;
        }
        if (res["error"]["type"] != "DatabaseError") {
            std::cerr << "Test DatabaseError failed: type is not 'DatabaseError'" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_api_response_fallback() {
    std::cout << "Running test_api_response_fallback..." << std::endl;

    // Cast an invalid integer to ErrorType to trigger switch fallback
    ErrorType invalid_type = static_cast<ErrorType>(9999);
    json res = ApiResponse::error({invalid_type, "Fallback error"});

    if (res["code"] != 500) {
        std::cerr << "test_api_response_fallback failed: code is not 500" << std::endl;
        return false;
    }
    if (res["error"]["type"] != "UnknownError") {
        std::cerr << "test_api_response_fallback failed: type is not 'UnknownError'" << std::endl;
        return false;
    }
    if (res["error"]["message"] != "Fallback error") {
        std::cerr << "test_api_response_fallback failed: message is incorrect" << std::endl;
        return false;
    }

    return true;
}

int main() {
    if (!test_api_response_success()) return 1;
    if (!test_api_response_error_mapping()) return 1;
    if (!test_api_response_fallback()) return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
