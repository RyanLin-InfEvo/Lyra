// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "make_error.h"

// Success return
json ApiResponse::success(const json &data) {
    json response;
    response["code"] = 200;
    response["data"] = data;
    return response;
}

// Error return
json ApiResponse::error(ErrorType type, const std::string &msg) {
    json response;

    auto [code, type_str] = getErrorMapping(type);

    response["code"] = code;
    response["error"]["type"] = (code == 0) ? json(static_cast<int>(type)) : json(type_str); // If type is not found in enum 'ErrorType'
    response["error"]["message"] = msg;

    return response;
}

// Mapping 'Enum' to {code, type}
std::pair<int, std::string> ApiResponse::getErrorMapping(ErrorType type) {
    switch (type) {
        // 404 Series
        case ErrorType::ArtistNotFound:
            return {404, "ArtistNotFound"};
        case ErrorType::TrackNotFound:
            return {404, "TrackNotFound"};

        // 400 Series
        case ErrorType::MissingParameter:
            return {400, "MissingParameter"};

        // 500 Series
        case ErrorType::DatabaseError:
            return {500, "DatabaseError"};

        default:
            return {0, ""};
    }
}
