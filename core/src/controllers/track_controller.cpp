// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "../models/relation_types.h"
#include "../models/track.h"
#include "../services/database_manager.h"
#include "../utils/json_helper.h"
#include "../utils/json_validator.h"
#include "../utils/make_error.h"
#include "../utils/uuid_generator.h"
#include "track_controller.h"

using json = nlohmann::json;

json TrackController::create(const json &params) { // `const json &params` is come from the 'params' object in the request json.

    // Format Check: Validate required and optional fields
    auto err = JsonValidator::validate(
        params,
        {{"pcm_hash", JsonFieldType::String, true},
         {"title", JsonFieldType::String, false},
         {"work_id", JsonFieldType::String, false, StringFormat::UUID},
         {"recording_year", JsonFieldType::Number, false},
         {"recording_month", JsonFieldType::Number, false},
         {"recording_day", JsonFieldType::Number, false},
         {"recording_location", JsonFieldType::String, false},
         {"duration", JsonFieldType::Number, false},
         {"isrc", JsonFieldType::String, false},
         {"musicbrainz_id", JsonFieldType::String, false},
         {"ytm_id", JsonFieldType::String, false},
         {"spotify_id", JsonFieldType::String, false}});

    if (err)
        return *err;

    // Create Track Object
    Track new_track;
    new_track.id = UuidGenerator::generate_v4();
    new_track.pcm_hash = params["pcm_hash"].get<std::string>();

    new_track.title = JsonHelper::get_optional<std::string>(params, "title");
    new_track.work_id = JsonHelper::get_optional<std::string>(params, "work_id");

    new_track.recording_year = JsonHelper::get_optional<int>(params, "recording_year");
    new_track.recording_month = JsonHelper::get_optional<int>(params, "recording_month");
    new_track.recording_day = JsonHelper::get_optional<int>(params, "recording_day");
    new_track.duration = JsonHelper::get_optional<int>(params, "duration");

    new_track.recording_location = JsonHelper::get_optional<std::string>(params, "recording_location");
    new_track.isrc = JsonHelper::get_optional<std::string>(params, "isrc");
    new_track.musicbrainz_id = JsonHelper::get_optional<std::string>(params, "musicbrainz_id");
    new_track.ytm_id = JsonHelper::get_optional<std::string>(params, "ytm_id");
    new_track.spotify_id = JsonHelper::get_optional<std::string>(params, "spotify_id");

    // Call: Database
    auto db_err = DatabaseManager::insert_track(new_track);

    // Return Result
    if (!db_err) {
        // Success
        json response;
        response["code"] = 201; // Created
        response["data"]["id"] = new_track.id;
        response["data"]["pcm_hash"] = new_track.pcm_hash;
        response["data"]["title"] = new_track.title;
        response["message"] = "Create Track success.";
        return response;
    } else {
        // Error
        return ApiResponse::error(ErrorType::DatabaseError, *db_err);
    }
}

std::optional<Track> TrackController::get(const std::string &uuid) {
    return DatabaseManager::get_track(uuid);
}

json TrackController::update(const json &params) {

    // Format Check: Validate required ID and optional fields
    auto err = JsonValidator::validate(
        params,
        {{"id", JsonFieldType::String, true, StringFormat::UUID},
         {"pcm_hash", JsonFieldType::String, false},
         {"title", JsonFieldType::String, false},
         {"work_id", JsonFieldType::String, false, StringFormat::UUID},
         {"recording_year", JsonFieldType::Number, false},
         {"recording_month", JsonFieldType::Number, false},
         {"recording_day", JsonFieldType::Number, false},
         {"recording_location", JsonFieldType::String, false},
         {"duration", JsonFieldType::Number, false},
         {"isrc", JsonFieldType::String, false},
         {"musicbrainz_id", JsonFieldType::String, false},
         {"ytm_id", JsonFieldType::String, false},
         {"spotify_id", JsonFieldType::String, false}});

    if (err)
        return *err;

    // Create TrackUpdate DTO
    TrackUpdate update_data;
    update_data.id = params["id"].get<std::string>();

    // Extract optional fields etc.
    update_data.pcm_hash = JsonHelper::get_optional<std::string>(params, "pcm_hash");
    update_data.title = JsonHelper::get_optional<std::string>(params, "title");
    update_data.work_id = JsonHelper::get_optional<std::string>(params, "work_id");
    update_data.recording_year = JsonHelper::get_optional<int>(params, "recording_year");
    update_data.recording_month = JsonHelper::get_optional<int>(params, "recording_month");
    update_data.recording_day = JsonHelper::get_optional<int>(params, "recording_day");
    update_data.recording_location = JsonHelper::get_optional<std::string>(params, "recording_location");
    update_data.duration = JsonHelper::get_optional<int>(params, "duration");
    update_data.isrc = JsonHelper::get_optional<std::string>(params, "isrc");
    update_data.musicbrainz_id = JsonHelper::get_optional<std::string>(params, "musicbrainz_id");
    update_data.ytm_id = JsonHelper::get_optional<std::string>(params, "ytm_id");
    update_data.spotify_id = JsonHelper::get_optional<std::string>(params, "spotify_id");

    // Check if there is anything to update
    if (!update_data.has_updates()) {
        return ApiResponse::error(ErrorType::InvalidValue, "No fields provided to update.");
    }

    // Call: Database
    auto db_err = DatabaseManager::update_track(update_data);

    // Return Result
    if (!db_err) {
        // Success
        json response;
        response["code"] = 200;
        response["data"]["id"] = update_data.id;
        response["message"] = "Update Track success.";
        return response;
    } else {
        // Error
        return ApiResponse::error(ErrorType::DatabaseError, *db_err);
    }
}

json TrackController::add_artist(const json &params) {

    auto err = JsonValidator::validate(params, {{"track_uuid", JsonFieldType::String, true, StringFormat::UUID},
                                                {"artist_uuid", JsonFieldType::String, true, StringFormat::UUID},
                                                {"role", JsonFieldType::String, false},
                                                {"position", JsonFieldType::Number, false}});
    if (err)
        return *err;

    const std::string track_id = params["track_uuid"].get<std::string>();
    const std::string artist_id = params["artist_uuid"].get<std::string>();
    const std::optional<std::string> role_str = JsonHelper::get_optional<std::string>(params, "role");
    const std::optional<int> position = JsonHelper::get_optional<int>(params, "position");

    ArtistRole final_role = ArtistRole::Main;

    if (role_str) {
        auto parsed_role = ArtistRoleMapper::from_string(*role_str);
        if (!parsed_role) {
            return ApiResponse::error(ErrorType::InvalidValue, "Invalid role for Track_Artist.");
        }
        final_role = *parsed_role;
    }

    auto db_err = DatabaseManager::add_track_artist({.track_id = track_id,
                                                     .artist_id = artist_id,
                                                     .role = final_role,
                                                     .position = position});

    if (!db_err) {
        json response;
        response["code"] = 201;
        response["data"]["track_uuid"] = track_id;
        response["data"]["artist_uuid"] = artist_id;
        response["data"]["role"] = ArtistRoleMapper::to_string(final_role);
        if (position) {
            response["data"]["position"] = *position;
        }
        response["message"] = "Add Track_Artist success.";
        return response;
    } else {
        return ApiResponse::error(ErrorType::DatabaseError, *db_err);
    }
}

json TrackController::remove_artist(const json &params) {

    auto err = JsonValidator::validate(params, {{"track_uuid", JsonFieldType::String, true, StringFormat::UUID},
                                                {"artist_uuid", JsonFieldType::String, true, StringFormat::UUID}});
    if (err)
        return *err;

    const std::string track_id = params["track_uuid"].get<std::string>();
    const std::string artist_id = params["artist_uuid"].get<std::string>();

    auto db_err = DatabaseManager::remove_track_artist(track_id, artist_id);

    if (!db_err) {
        json response;
        response["code"] = 200;
        response["message"] = "Remove Track_Artist success.";
        return response;
    } else {
        return ApiResponse::error(ErrorType::DatabaseError, *db_err);
    }
}

json TrackController::update_artist(const json &params) {

    auto err = JsonValidator::validate(params, {{"track_uuid", JsonFieldType::String, true, StringFormat::UUID},
                                                {"artist_uuid", JsonFieldType::String, true, StringFormat::UUID},
                                                {"role", JsonFieldType::String, false},
                                                {"position", JsonFieldType::Number, false}});
    if (err)
        return *err;

    const std::string track_id = params["track_uuid"].get<std::string>();
    const std::string artist_id = params["artist_uuid"].get<std::string>();
    const std::optional<std::string> role_str = JsonHelper::get_optional<std::string>(params, "role");
    const std::optional<int> position = JsonHelper::get_optional<int>(params, "position");

    ArtistRole final_role = ArtistRole::Main;

    if (role_str) {
        auto parsed_role = ArtistRoleMapper::from_string(*role_str);
        if (!parsed_role) {
            return ApiResponse::error(ErrorType::InvalidValue, "Invalid role for Track_Artist.");
        }
        final_role = *parsed_role;
    }

    auto db_err = DatabaseManager::update_track_artist({.track_id = track_id,
                                                        .artist_id = artist_id,
                                                        .role = final_role,
                                                        .position = position});

    if (!db_err) {
        json response;
        response["code"] = 200;
        response["data"]["track_uuid"] = track_id;
        response["data"]["artist_uuid"] = artist_id;
        response["data"]["role"] = ArtistRoleMapper::to_string(final_role);
        if (position) {
            response["data"]["position"] = *position;
        }
        response["message"] = "Update Track_Artist success.";
        return response;
    } else {
        return ApiResponse::error(ErrorType::DatabaseError, *db_err);
    }
}
