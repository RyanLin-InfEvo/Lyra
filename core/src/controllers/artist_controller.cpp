// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/artist.h"
#include "../services/database_manager.h"
#include "../utils/json_validator.h"
#include "../utils/make_error.h"
#include "../utils/uuid_generator.h"
#include "artist_controller.h"

using json = nlohmann::json;

json ArtistController::create(const json &params) {

    // Format Check: If 'name' avilable in params
    auto err = JsonValidator::validate(
        params, {{"id", JsonFieldType::String, true},
                 {"name", JsonFieldType::String, true},
                 {"musicbrainz_id", JsonFieldType::String, false},
                 {"ytm_id", JsonFieldType::String, false},
                 {"spotify_id", JsonFieldType::String, false}});

    if (err)
        return *err;

    // Create Artist Object
    Artist new_artist;

    new_artist.id = UuidGenerator::generate_v4();
    new_artist.name = params.value("name", "");

    // Call: Database
    auto db_err = DatabaseManager::insert_artist(new_artist);

    // Return
    if (!db_err) {
        // Success
        json response;
        response["code"] = 200;
        response["data"]["id"] = new_artist.id;
        response["data"]["name"] = new_artist.name;
        response["message"] = "Create Artist success.";
        return response;
    } else {
        // Error
        return ApiResponse::error(ErrorType::DatabaseError, *db_err);
    }
}

json ArtistController::get(const json &params) {

    if (!params.contains("uuid") || params["uuid"].get<std::string>().empty()) {
        return ApiResponse::error(ErrorType::MissingParameter,
                                  "Must provide uuid");
    }

    std::optional<Artist> artist =
        DatabaseManager::get_artist(params["uuid"].get<std::string>());

    if (artist.has_value()) {
        // Success
        json response;
        response["code"] = 200;
        response["data"]["id"] = artist->id;
        response["data"]["name"] = artist->name;
        return response;
    } else {
        // Error
        return ApiResponse::error(ErrorType::ArtistNotFound, "Artist not found");
    }
}
