// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/artist.h"
#include "../services/database_manager.h"
#include "../utils/json_helper.h"
#include "../utils/json_validator.h"
#include "../utils/make_error.h"
#include "../utils/uuid_generator.h"
#include "artist_controller.h"

using json = nlohmann::json;

json ArtistController::create(const json &params) {

    // Format Check: If 'name' avilable in params
    auto err = JsonValidator::validate(
        params, {{"name", JsonFieldType::String, true},
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

json ArtistController::update(const json &params) {

    // Format Check: Validate required ID and optional fields
    auto err = JsonValidator::validate(
        params, {{"id", JsonFieldType::String, true, StringFormat::UUID},
                 {"name", JsonFieldType::String, false},
                 {"musicbrainz_id", JsonFieldType::String, false},
                 {"ytm_id", JsonFieldType::String, false},
                 {"spotify_id", JsonFieldType::String, false}});

    if (err)
        return *err;

    // Create ArtistUpdate DTO
    ArtistUpdate update_data;
    update_data.id = params["id"].get<std::string>();

    // Extract optional fields if they exist
    update_data.name = JsonHelper::get_optional<std::string>(params, "name");
    update_data.musicbrainz_id = JsonHelper::get_optional<std::string>(params, "musicbrainz_id");
    update_data.ytm_id = JsonHelper::get_optional<std::string>(params, "ytm_id");
    update_data.spotify_id = JsonHelper::get_optional<std::string>(params, "spotify_id");

    // Check if there is anything to update
    if (!update_data.has_updates()) {
        return ApiResponse::error(ErrorType::InvalidValue, "No fields provided to update.");
    }

    // Call: Database
    auto db_err = DatabaseManager::update_artist(update_data);

    // Return
    if (!db_err) {
        json response;
        response["code"] = 200;
        response["data"]["id"] = update_data.id;
        response["message"] = "Update Artist success.";
        return response;
    } else {
        return ApiResponse::error(ErrorType::DatabaseError, *db_err);
    }
}

json ArtistController::get(const json &params) {

    // Format Check: Validate required UUID
    auto err = JsonValidator::validate(
        params, {{"uuid", JsonFieldType::String, true, StringFormat::UUID}});

    if (err)
        return *err;

    std::optional<Artist> artist =
        DatabaseManager::get_artist(params["uuid"].get<std::string>());

    if (artist.has_value()) {
        // Success
        json response;
        response["code"] = 200;
        response["data"]["id"] = artist->id;
        response["data"]["name"] = artist->name;
        response["data"]["musicbrainz_id"] = artist->musicbrainz_id;
        response["data"]["ytm_id"] = artist->ytm_id;
        response["data"]["spotify_id"] = artist->spotify_id;
        return response;
    } else {
        // Error
        return ApiResponse::error(ErrorType::ArtistNotFound, "Artist not found");
    }
}
