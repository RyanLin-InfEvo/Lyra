// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <functional>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <unordered_map>

#include "controllers/album_controller.h"
#include "controllers/artist_controller.h"
#include "controllers/playlist_controller.h"
#include "controllers/track_controller.h"
#include "controllers/work_controller.h"
#include "models/track.h"
#include "services/database_context.h"
#include "services/repositories/sqlite_album_repository.h"
#include "services/repositories/sqlite_artist_repository.h"
#include "services/repositories/sqlite_playlist_repository.h"
#include "services/repositories/sqlite_track_repository.h"
#include "services/repositories/sqlite_work_repository.h"
#include "utils/json_validator.h"
#include "utils/make_error.h"

#include "router.h"

namespace lyra {

using json = nlohmann::json;
using Type = JsonFieldType;

Router::Router(const std::string &db_path) {
    m_db_context = std::make_unique<SqliteDatabaseContext>(db_path);

    m_album_repo = std::make_unique<SqliteAlbumRepository>(*m_db_context);
    m_artist_repo = std::make_unique<SqliteArtistRepository>(*m_db_context);
    m_playlist_repo = std::make_unique<SqlitePlaylistRepository>(*m_db_context);
    m_track_repo = std::make_unique<SqliteTrackRepository>(*m_db_context);
    m_work_repo = std::make_unique<SqliteWorkRepository>(*m_db_context);

    m_album_controller = std::make_unique<AlbumController>(*m_album_repo);
    m_artist_controller = std::make_unique<ArtistController>(*m_artist_repo);
    m_playlist_controller = std::make_unique<PlaylistController>(*m_playlist_repo);
    m_track_controller = std::make_unique<TrackController>(*m_track_repo);
    m_work_controller = std::make_unique<WorkController>(*m_work_repo);
}

Router::~Router() = default;

namespace {

std::optional<json> validateWorkCompositionYears(const json &params) {
    if (params.contains("composition_start_year") && params["composition_start_year"].is_number() &&
        params.contains("composition_end_year") && params["composition_end_year"].is_number()) {
        if (params["composition_start_year"].get<int>() > params["composition_end_year"].get<int>()) {
            return ApiResponse::error(
                {ErrorType::OutOfRange,
                 "composition_start_year cannot be greater than composition_end_year"});
        }
    }
    return std::nullopt;
}

} // namespace

json Router::route(const json &request) {
    if (!request.contains("command") || !request["command"].is_string()) {
        return ApiResponse::error(
            {ErrorType::InvalidCommandFormat, "Missing or invalid 'command' field"});
    }

    const std::string command = request["command"];
    json params = request.value("params", json::object());

    // Define handlers as a local map that captures 'this'
    static const std::unordered_map<std::string, std::function<json(Router *, const json &)>> handlers = {
        {"CreateArtist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"name", Type::String, true},
                                                    {"musicbrainz_id", Type::String, false},
                                                    {"ytm_id", Type::String, false},
                                                    {"spotify_id", Type::String, false}});
            if (err) return *err;

            Artist artist = p.get<Artist>();
            auto res = r->m_artist_controller->create(artist);
            if (res) {
                json response;
                response["code"] = 201;
                response["data"]["id"] = artist.id;
                response["data"]["name"] = artist.name;
                response["message"] = "Create Artist success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"UpdateArtist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"name", Type::String, false},
                                                    {"musicbrainz_id", Type::String, false},
                                                    {"ytm_id", Type::String, false},
                                                    {"spotify_id", Type::String, false}});
            if (err) return *err;

            ArtistUpdate update_data = p.get<ArtistUpdate>();
            if (!update_data.has_updates()) {
                return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
            }

            auto res = r->m_artist_controller->update(update_data);
            if (res) {
                json response;
                response["code"] = 200;
                response["data"]["id"] = update_data.id;
                response["message"] = "Update Artist success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"GetArtist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            auto res = r->m_artist_controller->get(p["id"].get<std::string>());
            if (res) {
                return ApiResponse::success(res.value());
            }
            return ApiResponse::error({ErrorType::ArtistNotFound, res.error()});
        }},
        {"CreateTrack", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"pcm_hash", Type::String, true},
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
            if (err) return *err;

            Track track = p.get<Track>();
            auto res = r->m_track_controller->create(track);
            if (res) {
                json response;
                response["code"] = 201;
                response["data"]["id"] = track.id;
                response["data"]["pcm_hash"] = track.pcm_hash;
                response["data"]["title"] = track.title;
                response["message"] = "Create Track success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"GetTrack", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            auto res = r->m_track_controller->get(p["id"].get<std::string>());
            if (res) {
                return ApiResponse::success(res.value());
            }
            return ApiResponse::error({ErrorType::TrackNotFound, res.error()});
        }},
        {"UpdateTrack", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            TrackUpdate update_data = p.get<TrackUpdate>();
            if (!update_data.has_updates()) {
                return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
            }

            auto res = r->m_track_controller->update(update_data);
            if (res) {
                json response = ApiResponse::success({{"id", update_data.id}});
                response["message"] = "Update Track success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"CreateAlbum", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"title", Type::String, true},
                                                    {"release_year", Type::Year, false},
                                                    {"release_month", Type::Integer, false},
                                                    {"release_day", Type::Integer, false}});
            if (err) return *err;

            Album album = p.get<Album>();
            auto res = r->m_album_controller->create(album);
            if (res) {
                json response;
                response["code"] = 201;
                response["data"]["id"] = album.id;
                response["data"]["title"] = album.title;
                response["message"] = "Create Album success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"GetAlbum", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            auto res = r->m_album_controller->get(p["id"].get<std::string>());
            if (res) {
                return ApiResponse::success(res.value());
            }
            return ApiResponse::error({ErrorType::AlbumNotFound, res.error()});
        }},
        {"UpdateAlbum", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"title", Type::String, false},
                                                    {"release_year", Type::Year, false},
                                                    {"release_month", Type::Integer, false},
                                                    {"release_day", Type::Integer, false}});
            if (err) return *err;

            AlbumUpdate update_data = p.get<AlbumUpdate>();
            if (!update_data.has_updates()) {
                return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
            }

            auto res = r->m_album_controller->update(update_data);
            if (res) {
                json response = ApiResponse::success({{"id", update_data.id}});
                response["message"] = "Update Album success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"CreateWork", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"title", Type::String, true},
                                                    {"composition_start_year", Type::Year, false},
                                                    {"composition_end_year", Type::Year, false},
                                                    {"composition_date_text", Type::String, false},
                                                    {"iswc", Type::String, false},
                                                    {"musicbrainz_id", Type::String, false}});
            if (err) return *err;

            if (auto year_err = validateWorkCompositionYears(p)) return *year_err;

            Work work = p.get<Work>();
            auto res = r->m_work_controller->create(work);
            if (res) {
                json response;
                response["code"] = 201;
                response["data"] = work;
                response["message"] = "Create Work success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"GetWork", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            auto res = r->m_work_controller->get(p["id"].get<std::string>());
            if (res) {
                return ApiResponse::success(res.value());
            }
            return ApiResponse::error({ErrorType::WorkNotFound, res.error()});
        }},
        {"UpdateWork", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"title", Type::String, false},
                                                    {"composition_start_year", Type::Year, false},
                                                    {"composition_end_year", Type::Year, false},
                                                    {"composition_date_text", Type::String, false},
                                                    {"iswc", Type::String, false},
                                                    {"musicbrainz_id", Type::String, false}});
            if (err) return *err;

            if (auto year_err = validateWorkCompositionYears(p)) return *year_err;

            WorkUpdate update_data = p.get<WorkUpdate>();
            if (!update_data.has_updates()) {
                return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
            }

            auto res = r->m_work_controller->update(update_data);
            if (res) {
                json response = ApiResponse::success({{"id", update_data.id}});
                response["message"] = "Update Work success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"AddTrackArtist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"track_id", Type::String, true, StringFormat::UUID},
                                                    {"artist_id", Type::String, true, StringFormat::UUID},
                                                    {"role", Type::String, true},
                                                    {"position", Type::Integer, false}});
            if (err) return *err;

            TrackArtistParams track_artist = p.get<TrackArtistParams>();
            auto res = r->m_track_controller->add_artist(track_artist);
            if (res) {
                json response;
                response["code"] = 201;
                response["data"]["track_id"] = track_artist.track_id;
                response["data"]["artist_id"] = track_artist.artist_id;
                if (track_artist.role) response["data"]["role"] = *track_artist.role;
                if (track_artist.position) response["data"]["position"] = *track_artist.position;
                response["message"] = "Add Track_Artist success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"RemoveTrackArtist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"track_id", Type::String, true, StringFormat::UUID},
                                                    {"artist_id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            TrackArtistParams track_artist = p.get<TrackArtistParams>();
            auto res = r->m_track_controller->remove_artist(track_artist);
            if (res) {
                json response;
                response["code"] = 200;
                response["message"] = "Remove Track_Artist success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"UpdateTrackArtist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"track_id", Type::String, true, StringFormat::UUID},
                                                    {"artist_id", Type::String, true, StringFormat::UUID},
                                                    {"role", Type::String, false},
                                                    {"position", Type::Integer, false}});
            if (err) return *err;

            TrackArtistParams track_artist = p.get<TrackArtistParams>();
            auto res = r->m_track_controller->update_artist(track_artist);
            if (res) {
                json response;
                response["code"] = 200;
                response["data"]["track_id"] = track_artist.track_id;
                response["data"]["artist_id"] = track_artist.artist_id;
                if (track_artist.role) response["data"]["role"] = *track_artist.role;
                if (track_artist.position) response["data"]["position"] = *track_artist.position;
                response["message"] = "Update Track_Artist success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"CreatePlaylist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"title", Type::String, true},
                                                    {"description", Type::String, false}});
            if (err) return *err;

            Playlist playlist = p.get<Playlist>();
            auto res = r->m_playlist_controller->create(playlist);
            if (res) {
                json response;
                response["code"] = 201;
                response["data"] = playlist;
                response["message"] = "Create Playlist success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"GetPlaylist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            auto res = r->m_playlist_controller->get(p["id"].get<std::string>());
            if (res) {
                return ApiResponse::success(res.value());
            }
            return ApiResponse::error({ErrorType::PlaylistNotFound, res.error()});
        }},
        {"UpdatePlaylist", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"title", Type::String, false},
                                                    {"description", Type::String, false}});
            if (err) return *err;

            PlaylistUpdate update_data = p.get<PlaylistUpdate>();
            if (!update_data.has_updates()) {
                return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
            }

            auto res = r->m_playlist_controller->update(update_data);
            if (res) {
                json response = ApiResponse::success({{"id", update_data.id}});
                response["message"] = "Update Playlist success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"AddPlaylistTrack", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"playlist_id", Type::String, true, StringFormat::UUID},
                                                    {"track_id", Type::String, true, StringFormat::UUID},
                                                    {"position", Type::Integer, false}});
            if (err) return *err;

            auto res = r->m_playlist_controller->add_track(p["playlist_id"], p["track_id"],
                                                        p.contains("position") ? std::optional<int>(p["position"].get<int>()) : std::nullopt);
            if (res) {
                json response;
                response["code"] = 201;
                response["message"] = "Add PlaylistTrack success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"RemovePlaylistTrack", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"playlist_id", Type::String, true, StringFormat::UUID},
                                                    {"track_id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            auto res = r->m_playlist_controller->remove_track(p["playlist_id"], p["track_id"]);
            if (res) {
                json response;
                response["code"] = 200;
                response["message"] = "Remove PlaylistTrack success.";
                return response;
            }
            return ApiResponse::error({ErrorType::DatabaseError, res.error()});
        }},
        {"GetPlaylistTracks", [](Router *r, const json &p) {
            auto err = JsonValidator::validate(p, {{"id", Type::String, true, StringFormat::UUID}});
            if (err) return *err;

            std::vector<std::string> tracks = r->m_playlist_controller->get_tracks(p["id"].get<std::string>());
            return ApiResponse::success(tracks);
        }}
    };

    auto it = handlers.find(command);
    if (it != handlers.end()) {
        return it->second(this, params);
    }

    return ApiResponse::error({ErrorType::UnknownCommand, "Unknown command: " + command});
}

} // namespace lyra
