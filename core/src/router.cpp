// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>

#include "controllers/artist_controller.h"
#include "controllers/track_controller.h"
#include "router.h"

using json = nlohmann::json;

json Router::route(const json &request) {
    json response;

    // Syntax Check: If 'command' exist in request
    if (!request.contains("command") || !request["command"].is_string()) {
        response["code"] = 400;
        response["error"]["message"] = "Missing or invalid 'command' field";
        return response;
    }

    std::string command = request["command"];

    // Extract parameters,
    // If NULL, return a empty JSON Object
    json params = request.value("params", json::object());

    // Distrobute to different controllers
    if (command == "CreateArtist") {
        response = ArtistController::create(params);
    } else if (command == "UpdateArtist") {
        response = ArtistController::update(params);
    } else if (command == "GetArtist") {
        response = ArtistController::get(params);
    } else if (command == "CreateTrack") {
        response = TrackController::create(params);
    } else if (command == "GetTrack") {
        response = TrackController::get(params);
    } else {
        // Error: Unknown command
        response["code"] = 404;
        response["error"]["message"] = "Unknown command: " + command;
    }

    return response;
}
