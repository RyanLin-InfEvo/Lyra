// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/track.h"
#include "../services/database_manager.h"
#include "../utils/json_validator.h"
#include "../utils/make_error.h"
#include "../utils/uuid_generator.h"
#include "track_controller.h"

using json = nlohmann::json;

json TrackController::create(const json &params) { // `const json &params` is come from the 'params' object in the request json.

    // Format Check: Validate required and optional fields
    // pcm_hash is required by DB schema
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
    new_track.title = params.value("title", "");
    new_track.work_id = params.value("work_id", "");

    // Optional integer fields
    if (params.contains("recording_year") && !params["recording_year"].is_null()) {
        new_track.recording_year = params["recording_year"].get<int>();
    }
    if (params.contains("recording_month") && !params["recording_month"].is_null()) {
        new_track.recording_month = params["recording_month"].get<int>();
    }
    if (params.contains("recording_day") && !params["recording_day"].is_null()) {
        new_track.recording_day = params["recording_day"].get<int>();
    }

    if (params.contains("duration") && !params["duration"].is_null()) {
        new_track.duration = params["duration"].get<int>();
    }

    new_track.recording_location = params.value("recording_location", "");
    new_track.isrc = params.value("isrc", "");
    new_track.musicbrainz_id = params.value("musicbrainz_id", "");
    new_track.ytm_id = params.value("ytm_id", "");
    new_track.spotify_id = params.value("spotify_id", "");

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
