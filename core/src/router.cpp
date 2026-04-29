// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "controllers/artist_controller.h"
#include "controllers/track_controller.h"
#include "controllers/work_controller.h"
#include "models/track.h"
#include "utils/json_validator.h"
#include "utils/make_error.h"

#include "router.h"

namespace lyra {

using json = nlohmann::json;
using Type = JsonFieldType;

json Router::route(const json &request) {
    json response;

    // Syntax Check: If 'command' exist in json request
    if (!request.contains("command") || !request["command"].is_string()) {
        return ApiResponse::error(
            {ErrorType::InvalidCommandFormat, "Missing or invalid 'command' field"});
    }

    const std::string command = request["command"];

    // Extract parameters,
    // If NULL, return a empty JSON Object
    json params = request.value("params", json::object());

    // Distribute to different controllers
    if (command == "CreateArtist") {
        auto err = JsonValidator::validate(params, {{"name", Type::String, true},
                                                    {"musicbrainz_id", Type::String, false},
                                                    {"ytm_id", Type::String, false},
                                                    {"spotify_id", Type::String, false}});

        if (err)
            return *err;

        Artist artist = params.get<Artist>();
        auto db_err = ArtistController::create(artist);

        if (!db_err) {
            response["code"] = 201; // Created
            response["data"]["id"] = artist.id;
            response["data"]["name"] = artist.name;
            response["message"] = "Create Artist success.";
        } else {
            response = ApiResponse::error({ErrorType::DatabaseError, *db_err});
        }

    } else if (command == "UpdateArtist") {
        auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"name", Type::String, false},
                                                    {"musicbrainz_id", Type::String, false},
                                                    {"ytm_id", Type::String, false},
                                                    {"spotify_id", Type::String, false}});

        if (err)
            return *err;

        ArtistUpdate update_data = params.get<ArtistUpdate>();

        if (!update_data.has_updates()) {
            return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
        }

        auto db_err = ArtistController::update(update_data);

        if (!db_err) {
            response["code"] = 200;
            response["data"]["id"] = update_data.id;
            response["message"] = "Update Artist success.";
        } else {
            response = ApiResponse::error({ErrorType::DatabaseError, *db_err});
        }

    } else if (command == "GetArtist") { // ------------ GetArtist ------------
        auto err =
            JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
        if (err)
            return *err;

        std::optional<Artist> artist = ArtistController::get(params["id"].get<std::string>());

        if (artist.has_value()) {
            response = ApiResponse::success(artist.value());
        } else {
            response = ApiResponse::error({ErrorType::ArtistNotFound, "Artist not found"});
        }
    } else if (command == "CreateTrack") {
        auto err =
            JsonValidator::validate(params, {{"pcm_hash", Type::String, true},
                                             {"title", Type::String, false},
                                             {"work_id", Type::String, false, StringFormat::UUID},
                                             {"recording_year", Type::Year, false},
                                             {"recording_month", Type::Integer, false},
                                             {"recording_day", Type::Integer, false},
                                             {"recording_location", Type::String, false},
                                             {"duration", Type::Integer, false},
                                             {"isrc", Type::String, false},
                                             {"musicbrainz_id", Type::String, false},
                                             {"ytm_id", Type::String, false},
                                             {"spotify_id", Type::String, false}});

        if (err)
            return *err;

        Track track = params.get<Track>();
        auto db_err = TrackController::create(track);

        if (!db_err) {
            response["code"] = 201; // Created
            response["data"]["id"] = track.id;
            response["data"]["pcm_hash"] = track.pcm_hash;
            response["data"]["title"] = track.title;
            response["message"] = "Create Track success.";
        } else {
            response = ApiResponse::error({ErrorType::DatabaseError, *db_err});
        }
    } else if (command == "GetTrack") {

        auto err =
            JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
        if (err)
            return *err;

        std::optional<Track> track = TrackController::get(params["id"].get<std::string>());

        if (track.has_value()) {
            response = ApiResponse::success(track.value());
        } else {
            response = ApiResponse::error({ErrorType::TrackNotFound, "Track not found"});
        }

    } else if (command == "UpdateTrack") {

        auto err =
            JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
        if (err)
            return *err;

        TrackUpdate update_data = params.get<TrackUpdate>();
        if (!update_data.has_updates()) {
            response =
                ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
            return response;
        }

        std::optional<std::string> db_err = TrackController::update(update_data);
        if (!db_err.has_value()) {
            // No error string returned from the database -> Success
            response = ApiResponse::success({{"id", update_data.id}});
            response["message"] = "Update Track success.";
        } else {
            // An error string was returned -> Pass the specific DB error up to the client
            response = ApiResponse::error({ErrorType::DatabaseError, db_err.value()});
        }

    } else if (command == "CreateWork") {
        auto err = JsonValidator::validate(params, {
            {"title", Type::String, true},
            {"composition_start_year", Type::Year, false},
            {"composition_end_year", Type::Year, false},
            {"composition_date_text", Type::String, false},
            {"iswc", Type::String, false},
            {"musicbrainz_id", Type::String, false}
        });

        if (err) return *err;

        // Validate composition_start_year <= composition_end_year
        if (params.contains("composition_start_year") && params["composition_start_year"].is_number() &&
            params.contains("composition_end_year") && params["composition_end_year"].is_number()) {
            if (params["composition_start_year"].get<int>() > params["composition_end_year"].get<int>()) {
                return ApiResponse::error({ErrorType::OutOfRange, "composition_start_year cannot be greater than composition_end_year"});
            }
        }

        Work work = params.get<Work>();
        auto db_err = WorkController::create(work);

        if (!db_err) {
            response["code"] = 201;
            response["data"] = work;
            response["message"] = "Create Work success.";
        } else {
            response = ApiResponse::error({ErrorType::DatabaseError, *db_err});
        }

    } else if (command == "GetWork") {
        auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
        if (err)
            return *err;

        std::optional<Work> work = WorkController::get(params["id"].get<std::string>());

        if (work.has_value()) {
            response = ApiResponse::success(work.value());
        } else {
            response = ApiResponse::error({ErrorType::WorkNotFound, "Work not found"});
        }

    } else if (command == "UpdateWork") {
        auto err = JsonValidator::validate(params, {
            {"id", Type::String, true, StringFormat::UUID},
            {"title", Type::String, false},
            {"composition_start_year", Type::Year, false},
            {"composition_end_year", Type::Year, false},
            {"composition_date_text", Type::String, false},
            {"iswc", Type::String, false},
            {"musicbrainz_id", Type::String, false}
        });

        if (err) return *err;

        // Validate composition_start_year <= composition_end_year
        if (params.contains("composition_start_year") && params["composition_start_year"].is_number() &&
            params.contains("composition_end_year") && params["composition_end_year"].is_number()) {
            if (params["composition_start_year"].get<int>() > params["composition_end_year"].get<int>()) {
                return ApiResponse::error({ErrorType::OutOfRange, "composition_start_year cannot be greater than composition_end_year"});
            }
        }

        WorkUpdate update_data = params.get<WorkUpdate>();

        if (!update_data.has_updates()) {
            return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
        }

        auto db_err = WorkController::update(update_data);

        if (!db_err) {
            response = ApiResponse::success({{"id", update_data.id}});
            response["message"] = "Update Work success.";
        } else {
            response = ApiResponse::error({ErrorType::DatabaseError, *db_err});
        }

    } else if (command == "AddTrackArtist") {
        auto err = JsonValidator::validate(
            params, {{"track_id", Type::String, true, StringFormat::UUID},
                     {"artist_id", Type::String, true, StringFormat::UUID},
                     {"role", Type::String, true},
                     {"position", Type::Integer, false}});
        if (err)
            return *err;

        TrackArtistParams track_artist = params.get<TrackArtistParams>();
        auto db_err = TrackController::add_artist(track_artist);

        if (!db_err) {
            response["code"] = 201;
            response["data"]["track_id"] = track_artist.track_id;
            response["data"]["artist_id"] = track_artist.artist_id;
            if (track_artist.role) {
                response["data"]["role"] = *track_artist.role;
            }
            if (track_artist.position) {
                response["data"]["position"] = *track_artist.position;
            }
            response["message"] = "Add Track_Artist success.";
        } else {
            response = ApiResponse::error({ErrorType::DatabaseError, *db_err});
        }

    } else if (command == "RemoveTrackArtist") {
        auto err = JsonValidator::validate(
            params, {{"track_id", Type::String, true, StringFormat::UUID},
                     {"artist_id", Type::String, true, StringFormat::UUID}});
        if (err)
            return *err;

        TrackArtistParams track_artist = params.get<TrackArtistParams>();
        auto db_err = TrackController::remove_artist(track_artist);

        if (!db_err) {
            response["code"] = 200;
            response["message"] = "Remove Track_Artist success.";
        } else {
            response = ApiResponse::error({ErrorType::DatabaseError, *db_err});
        }

    } else if (command == "UpdateTrackArtist") {
        auto err = JsonValidator::validate(
            params, {{"track_id", Type::String, true, StringFormat::UUID},
                     {"artist_id", Type::String, true, StringFormat::UUID},
                     {"role", Type::String, false},
                     {"position", Type::Integer, false}});
        if (err)
            return *err;

        TrackArtistParams track_artist = params.get<TrackArtistParams>();
        auto db_err = TrackController::update_artist(track_artist);

        if (!db_err) {
            response["code"] = 200;
            response["data"]["track_id"] = track_artist.track_id;
            response["data"]["artist_id"] = track_artist.artist_id;
            if (track_artist.role) {
                response["data"]["role"] = *track_artist.role;
            }
            if (track_artist.position) {
                response["data"]["position"] = *track_artist.position;
            }
            response["message"] = "Update Track_Artist success.";
        } else {
            response = ApiResponse::error({ErrorType::DatabaseError, *db_err});
        }
    } else {
        // Error: Unknown command
        return ApiResponse::error({ErrorType::UnknownCommand, "Unknown command: " + command});
    }

    return response;
}

} // namespace lyra
