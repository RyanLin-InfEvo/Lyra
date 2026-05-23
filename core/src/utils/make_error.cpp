// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>
#include <utility>

#include "make_error.h"

using json = nlohmann::json;

namespace lyra {

// Success return
json ApiResponse::success(const json &data) {
    json response;
    response["code"] = 200;
    response["data"] = data;
    return response;
}

// Error return
json ApiResponse::error(const Error &err) {
    json response;

    auto [code, type_str] = getErrorMapping(err.type);

    response["code"] = code;
    response["error"]["type"] = type_str;
    response["error"]["message"] = err.message;

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
        case ErrorType::AlbumNotFound:
            return {404, "AlbumNotFound"};
        case ErrorType::WorkNotFound:
            return {404, "WorkNotFound"};
        case ErrorType::PlaylistNotFound:
            return {404, "PlaylistNotFound"};
        case ErrorType::UnknownCommand:
            return {404, "UnknownCommand"};
        case ErrorType::RelationNotFound:
            return {404, "RelationNotFound"};

        // 400 Series
        case ErrorType::MissingParameter:
            return {400, "MissingParameter"};
        case ErrorType::InvalidValue:
            return {400, "InvalidValue"};
        case ErrorType::InvalidCommandFormat:
            return {400, "InvalidCommandFormat"};
        case ErrorType::OutOfRange:
            return {400, "OutOfRange"};
        case ErrorType::Conflict:
            return {409, "Conflict"};

        // 500 Series
        case ErrorType::DatabaseError:
            return {500, "DatabaseError"};
    }
}
} // namespace lyra
