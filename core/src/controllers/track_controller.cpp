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
    new_track.title = JsonHelper::get_safe<std::string>(params, "title", "");
    new_track.work_id = JsonHelper::get_safe<std::string>(params, "work_id", "");

    // Optional integer fields
    auto recording_year_opt = JsonHelper::get_optional<int>(params, "recording_year");
    if (recording_year_opt) {
        new_track.recording_year = *recording_year_opt;
    }
    auto recording_month_opt = JsonHelper::get_optional<int>(params, "recording_month");
    if (recording_month_opt) {
        new_track.recording_month = *recording_month_opt;
    }
    auto recording_day_opt = JsonHelper::get_optional<int>(params, "recording_day");
    if (recording_day_opt) {
        new_track.recording_day = *recording_day_opt;
    }

    auto duration_opt = JsonHelper::get_optional<int>(params, "duration");
    if (duration_opt) {
        new_track.duration = *duration_opt;
    }

    new_track.recording_location = JsonHelper::get_safe<std::string>(params, "recording_location", "");
    new_track.isrc = JsonHelper::get_safe<std::string>(params, "isrc", "");
    new_track.musicbrainz_id = JsonHelper::get_safe<std::string>(params, "musicbrainz_id", "");
    new_track.ytm_id = JsonHelper::get_safe<std::string>(params, "ytm_id", "");
    new_track.spotify_id = JsonHelper::get_safe<std::string>(params, "spotify_id", "");

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
