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
using namespace lyra;

std::optional<std::string> TrackController::create(Track &track) {
    // Generate UUID for the new track
    track.id = UuidGenerator::generate_v4();

    return DatabaseManager::insert_track(track);
}

std::optional<Track> TrackController::get(const std::string &id) {
    return DatabaseManager::get_track(id);
}

std::optional<std::string> TrackController::update(const TrackUpdate &track_update) {
    return DatabaseManager::update_track(track_update);
}

json TrackController::add_artist(const json &params) {

    auto err = JsonValidator::validate(params, {{"track_id", JsonFieldType::String, true, StringFormat::UUID},
                                                {"artist_id", JsonFieldType::String, true, StringFormat::UUID},
                                                {"role", JsonFieldType::String, false},
                                                {"position", JsonFieldType::Number, false}});
    if (err)
        return *err;

    const std::string track_id = params["track_id"].get<std::string>();
    const std::string artist_id = params["artist_id"].get<std::string>();
    const std::optional<std::string> role_str = JsonHelper::get_optional<std::string>(params, "role");
    const std::optional<int> position = JsonHelper::get_optional<int>(params, "position");

    ArtistRole final_role = ArtistRole::Main;

    if (role_str) {
        auto parsed_role = ArtistRoleMapper::from_string(*role_str);
        if (!parsed_role) {
            return ApiResponse::error({ErrorType::InvalidValue, "Invalid role for Track_Artist."});
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
        return ApiResponse::error({ErrorType::DatabaseError, *db_err});
    }
}

json TrackController::remove_artist(const json &params) {

    auto err = JsonValidator::validate(params, {{"track_id", JsonFieldType::String, true, StringFormat::UUID},
                                                {"artist_id", JsonFieldType::String, true, StringFormat::UUID}});
    if (err)
        return *err;

    const std::string track_id = params["track_id"].get<std::string>();
    const std::string artist_id = params["artist_id"].get<std::string>();

    auto db_err = DatabaseManager::remove_track_artist(track_id, artist_id);

    if (!db_err) {
        json response;
        response["code"] = 200;
        response["message"] = "Remove Track_Artist success.";
        return response;
    } else {
        return ApiResponse::error({ErrorType::DatabaseError, *db_err});
    }
}

json TrackController::update_artist(const json &params) {

    auto err = JsonValidator::validate(params, {{"track_id", JsonFieldType::String, true, StringFormat::UUID},
                                                {"artist_id", JsonFieldType::String, true, StringFormat::UUID},
                                                {"role", JsonFieldType::String, false},
                                                {"position", JsonFieldType::Number, false}});
    if (err)
        return *err;

    const std::string track_id = params["track_id"].get<std::string>();
    const std::string artist_id = params["artist_id"].get<std::string>();
    const std::optional<std::string> role_str = JsonHelper::get_optional<std::string>(params, "role");
    const std::optional<int> position = JsonHelper::get_optional<int>(params, "position");

    ArtistRole final_role = ArtistRole::Main;

    if (role_str) {
        auto parsed_role = ArtistRoleMapper::from_string(*role_str);
        if (!parsed_role) {
            return ApiResponse::error({ErrorType::InvalidValue, "Invalid role for Track_Artist."});
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
        response["data"]["track_id"] = track_id;
        response["data"]["artist_id"] = artist_id;
        response["data"]["role"] = ArtistRoleMapper::to_string(final_role);
        if (position) {
            response["data"]["position"] = *position;
        }
        response["message"] = "Update Track_Artist success.";
        return response;
    } else {
        return ApiResponse::error({ErrorType::DatabaseError, *db_err});
    }
}
