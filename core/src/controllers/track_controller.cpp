// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

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

json TrackController::get(const json &params) {

    // Format Check: Validate required UUID
    auto err = JsonValidator::validate(
        params, {{"uuid", JsonFieldType::String, true, StringFormat::UUID}});

    if (err)
        return *err;

    // Call: Database
    std::optional<Track> track = DatabaseManager::get_track(params["uuid"].get<std::string>());

    // Return Result
    if (track.has_value()) {
        // Success
        json response;
        response["code"] = 200;
        response["data"]["id"] = track->id;
        response["data"]["pcm_hash"] = track->pcm_hash;
        response["data"]["work_id"] = track->work_id;
        response["data"]["title"] = track->title;
        response["data"]["recording_year"] = track->recording_year;
        response["data"]["recording_month"] = track->recording_month;
        response["data"]["recording_day"] = track->recording_day;
        response["data"]["recording_location"] = track->recording_location;
        response["data"]["duration"] = track->duration;
        response["data"]["isrc"] = track->isrc;
        response["data"]["musicbrainz_id"] = track->musicbrainz_id;
        response["data"]["ytm_id"] = track->ytm_id;
        response["data"]["spotify_id"] = track->spotify_id;
        return response;
    } else {
        // Error
        return ApiResponse::error(ErrorType::TrackNotFound, "Track not found");
    }
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
