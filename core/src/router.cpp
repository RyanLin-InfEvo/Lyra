// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "controllers/artist_controller.h"
#include "controllers/track_controller.h"
#include "models/track.h"
#include "utils/json_validator.h"
#include "utils/make_error.h"

#include "router.h"

using json = nlohmann::json;

json Router::route(const json &request) {
    json response;

    // Syntax Check: If 'command' exist in json request
    if (!request.contains("command") || !request["command"].is_string()) {
        response["code"] = 400;
        response["error"]["message"] = "Missing or invalid 'command' field";
        return response;
    }

    std::string command = request["command"];

    // Extract parameters,
    // If NULL, return a empty JSON Object
    json params = request.value("params", json::object());

    // Distribute to different controllers
    if (command == "CreateArtist") {
        response = ArtistController::create(params);
    } else if (command == "UpdateArtist") {
        response = ArtistController::update(params);
    } else if (command == "GetArtist") {
        response = ArtistController::get(params);
    } else if (command == "CreateTrack") {
        response = TrackController::create(params);
    } else if (command == "GetTrack") {

        auto err = JsonValidator::validate(params, {{"id", JsonFieldType::String, true, StringFormat::UUID}});
        if (err)
            return *err;

        std::optional<Track> track = TrackController::get(params["id"].get<std::string>());

        if (track.has_value()) {
            response = ApiResponse::success(track.value());
        } else {
            response = ApiResponse::error(ErrorType::TrackNotFound, "Track not found");
        }

    } else if (command == "UpdateTrack") {

        auto err = JsonValidator::validate(params, {{"id", JsonFieldType::String, true, StringFormat::UUID}});
        if (err)
            return *err;

        TrackUpdate update_data = params.get<TrackUpdate>();
        if (!update_data.has_updates()) {
            response = ApiResponse::error(ErrorType::InvalidValue, "No fields provided to update.");
            return response;
        }

        std::optional<std::string> db_err = TrackController::update(update_data);
        if (!db_err.has_value()) {
            // No error string returned from the database -> Success
            response = ApiResponse::success({{"id", update_data.id}});
            response["message"] = "Update Track success.";
        } else {
            // An error string was returned -> Pass the specific DB error up to the client
            response = ApiResponse::error(ErrorType::DatabaseError, db_err.value());
        }

    } else if (command == "AddTrackArtist") {
        response = TrackController::add_artist(params);
    } else if (command == "RemoveTrackArtist") {
        response = TrackController::remove_artist(params);
    } else if (command == "UpdateTrackArtist") {
        response = TrackController::update_artist(params);
    } else {
        // Error: Unknown command
        response["code"] = 404;
        response["error"]["message"] = "Unknown command: " + command;
    }

    return response;
}
