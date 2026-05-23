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
#include "models/relation_types.h"
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

    init_handlers();
}

Router::~Router() = default;

void Router::init_handlers() {
    m_handlers["CreateArtist"] = [this](const json &p) { return handleCreateArtist(p); };
    m_handlers["UpdateArtist"] = [this](const json &p) { return handleUpdateArtist(p); };
    m_handlers["GetArtist"] = [this](const json &p) { return handleGetArtist(p); };

    m_handlers["CreateTrack"] = [this](const json &p) { return handleCreateTrack(p); };
    m_handlers["UpdateTrack"] = [this](const json &p) { return handleUpdateTrack(p); };
    m_handlers["GetTrack"] = [this](const json &p) { return handleGetTrack(p); };

    m_handlers["CreateAlbum"] = [this](const json &p) { return handleCreateAlbum(p); };
    m_handlers["UpdateAlbum"] = [this](const json &p) { return handleUpdateAlbum(p); };
    m_handlers["GetAlbum"] = [this](const json &p) { return handleGetAlbum(p); };

    m_handlers["CreateWork"] = [this](const json &p) { return handleCreateWork(p); };
    m_handlers["UpdateWork"] = [this](const json &p) { return handleUpdateWork(p); };
    m_handlers["GetWork"] = [this](const json &p) { return handleGetWork(p); };

    m_handlers["AddTrackArtist"] = [this](const json &p) { return handleAddTrackArtist(p); };
    m_handlers["RemoveTrackArtist"] = [this](const json &p) { return handleRemoveTrackArtist(p); };
    m_handlers["UpdateTrackArtist"] = [this](const json &p) { return handleUpdateTrackArtist(p); };

    m_handlers["CreatePlaylist"] = [this](const json &p) { return handleCreatePlaylist(p); };
    m_handlers["UpdatePlaylist"] = [this](const json &p) { return handleUpdatePlaylist(p); };
    m_handlers["GetPlaylist"] = [this](const json &p) { return handleGetPlaylist(p); };
    m_handlers["AddPlaylistTrack"] = [this](const json &p) { return handleAddPlaylistTrack(p); };
    m_handlers["RemovePlaylistTrack"] = [this](const json &p) { return handleRemovePlaylistTrack(p); };
    m_handlers["GetPlaylistTracks"] = [this](const json &p) { return handleGetPlaylistTracks(p); };
}

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

// --- Artist Handlers ---

json Router::handleCreateArtist(const json &params) {
    auto err = JsonValidator::validate(params, {{"name", Type::String, true},
                                                {"musicbrainz_id", Type::String, false},
                                                {"ytm_id", Type::String, false},
                                                {"spotify_id", Type::String, false}});
    if (err) return *err;

    Artist artist = params.get<Artist>();
    auto res = m_artist_controller->create(artist);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"]["id"] = artist.id;
        response["data"]["name"] = artist.name;
        response["message"] = "Create Artist success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleUpdateArtist(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                {"name", Type::String, false},
                                                {"musicbrainz_id", Type::String, false},
                                                {"ytm_id", Type::String, false},
                                                {"spotify_id", Type::String, false}});
    if (err) return *err;

    ArtistUpdate update_data = params.get<ArtistUpdate>();
    if (!update_data.has_updates()) {
        return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
    }

    auto res = m_artist_controller->update(update_data);
    if (res) {
        json response;
        response["code"] = 200;
        response["data"]["id"] = update_data.id;
        response["message"] = "Update Artist success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetArtist(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    auto res = m_artist_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::ArtistNotFound, res.error()});
}

// --- Track Handlers ---

json Router::handleCreateTrack(const json &params) {
    auto err = JsonValidator::validate(params, {{"pcm_hash", Type::String, true},
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

    Track track = params.get<Track>();
    auto res = m_track_controller->create(track);
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
}

json Router::handleGetTrack(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    auto res = m_track_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::TrackNotFound, res.error()});
}

json Router::handleUpdateTrack(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    TrackUpdate update_data = params.get<TrackUpdate>();
    if (!update_data.has_updates()) {
        return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
    }

    auto res = m_track_controller->update(update_data);
    if (res) {
        json response = ApiResponse::success({{"id", update_data.id}});
        response["message"] = "Update Track success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Album Handlers ---

json Router::handleCreateAlbum(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true},
                                                {"release_year", Type::Year, false},
                                                {"release_month", Type::Integer, false},
                                                {"release_day", Type::Integer, false}});
    if (err) return *err;

    Album album = params.get<Album>();
    auto res = m_album_controller->create(album);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"]["id"] = album.id;
        response["data"]["title"] = album.title;
        response["message"] = "Create Album success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetAlbum(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    auto res = m_album_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::AlbumNotFound, res.error()});
}

json Router::handleUpdateAlbum(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                {"title", Type::String, false},
                                                {"release_year", Type::Year, false},
                                                {"release_month", Type::Integer, false},
                                                {"release_day", Type::Integer, false}});
    if (err) return *err;

    AlbumUpdate update_data = params.get<AlbumUpdate>();
    if (!update_data.has_updates()) {
        return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
    }

    auto res = m_album_controller->update(update_data);
    if (res) {
        json response = ApiResponse::success({{"id", update_data.id}});
        response["message"] = "Update Album success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Work Handlers ---

json Router::handleCreateWork(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true},
                                                {"composition_start_year", Type::Year, false},
                                                {"composition_end_year", Type::Year, false},
                                                {"composition_date_text", Type::String, false},
                                                {"iswc", Type::String, false},
                                                {"musicbrainz_id", Type::String, false}});
    if (err) return *err;

    if (auto year_err = validateWorkCompositionYears(params)) return *year_err;

    Work work = params.get<Work>();
    auto res = m_work_controller->create(work);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"] = work;
        response["message"] = "Create Work success.";
        return response;
    }
    if (res.error().find("UNIQUE constraint failed: Work.iswc") != std::string::npos) {
        return ApiResponse::error({ErrorType::Conflict, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetWork(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    auto res = m_work_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::WorkNotFound, res.error()});
}

json Router::handleUpdateWork(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                {"title", Type::String, false},
                                                {"composition_start_year", Type::Year, false},
                                                {"composition_end_year", Type::Year, false},
                                                {"composition_date_text", Type::String, false},
                                                {"iswc", Type::String, false},
                                                {"musicbrainz_id", Type::String, false}});
    if (err) return *err;

    if (auto year_err = validateWorkCompositionYears(params)) return *year_err;

    bool has_start = params.contains("composition_start_year") && !params["composition_start_year"].is_null();
    bool has_end = params.contains("composition_end_year") && !params["composition_end_year"].is_null();
    if ((has_start && !has_end) || (!has_start && has_end)) {
        auto get_res = m_work_controller->get(params["id"].get<std::string>());
        if (!get_res) {
            return ApiResponse::error({ErrorType::WorkNotFound, get_res.error()});
        }
        const auto &existing_work = get_res.value();
        if (has_start && existing_work.composition_end_year.has_value()) {
            if (params["composition_start_year"].get<uint16_t>() > *existing_work.composition_end_year) {
                return ApiResponse::error(
                    {ErrorType::OutOfRange,
                     "composition_start_year cannot be greater than composition_end_year"});
            }
        }
        if (has_end && existing_work.composition_start_year.has_value()) {
            if (*existing_work.composition_start_year > params["composition_end_year"].get<uint16_t>()) {
                return ApiResponse::error(
                    {ErrorType::OutOfRange,
                     "composition_start_year cannot be greater than composition_end_year"});
            }
        }
    }

    WorkUpdate update_data = params.get<WorkUpdate>();
    if (!update_data.has_updates()) {
        return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
    }

    auto res = m_work_controller->update(update_data);
    if (res) {
        json response = ApiResponse::success({{"id", update_data.id}});
        response["message"] = "Update Work success.";
        return response;
    }
    if (res.error().find("UNIQUE constraint failed: Work.iswc") != std::string::npos) {
        return ApiResponse::error({ErrorType::Conflict, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Track-Artist Relation Handlers ---

json Router::handleAddTrackArtist(const json &params) {
    auto err = JsonValidator::validate(params, {{"track_id", Type::String, true, StringFormat::UUID},
                                                {"artist_id", Type::String, true, StringFormat::UUID},
                                                {"role", Type::String, true},
                                                {"position", Type::Integer, false}});
    if (err) return *err;

    std::string role_str = params["role"].get<std::string>();
    if (!ArtistRoleMapper::from_string(role_str)) {
        return ApiResponse::error({ErrorType::InvalidValue, "Invalid artist role: " + role_str});
    }

    TrackArtistParams track_artist = params.get<TrackArtistParams>();
    auto res = m_track_controller->add_artist(track_artist);
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
    std::string err_msg = res.error();
    if (err_msg.find("Track not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::TrackNotFound, err_msg});
    } else if (err_msg.find("Artist not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::ArtistNotFound, err_msg});
    }
    return ApiResponse::error({ErrorType::DatabaseError, err_msg});
}

json Router::handleRemoveTrackArtist(const json &params) {
    auto err = JsonValidator::validate(params, {{"track_id", Type::String, true, StringFormat::UUID},
                                                {"artist_id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    TrackArtistParams track_artist = params.get<TrackArtistParams>();
    auto res = m_track_controller->remove_artist(track_artist);
    if (res) {
        json response;
        response["code"] = 200;
        response["message"] = "Remove Track_Artist success.";
        return response;
    }
    std::string err_msg = res.error();
    if (err_msg.find("Relation not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::RelationNotFound, "Relation between Track and Artist not found."});
    }
    return ApiResponse::error({ErrorType::DatabaseError, err_msg});
}

json Router::handleUpdateTrackArtist(const json &params) {
    auto err = JsonValidator::validate(params, {{"track_id", Type::String, true, StringFormat::UUID},
                                                {"artist_id", Type::String, true, StringFormat::UUID},
                                                {"role", Type::String, false},
                                                {"position", Type::Integer, false}});
    if (err) return *err;

    if (params.contains("role")) {
        std::string role_str = params["role"].get<std::string>();
        if (!ArtistRoleMapper::from_string(role_str)) {
            return ApiResponse::error({ErrorType::InvalidValue, "Invalid artist role: " + role_str});
        }
    }

    TrackArtistParams track_artist = params.get<TrackArtistParams>();
    auto res = m_track_controller->update_artist(track_artist);
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
    std::string err_msg = res.error();
    if (err_msg.find("Relation not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::RelationNotFound, "Relation between Track and Artist not found."});
    }
    return ApiResponse::error({ErrorType::DatabaseError, err_msg});
}

// --- Playlist Handlers ---

json Router::handleCreatePlaylist(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true},
                                                {"description", Type::String, false}});
    if (err) return *err;

    Playlist playlist = params.get<Playlist>();
    auto res = m_playlist_controller->create(playlist);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"] = playlist;
        response["message"] = "Create Playlist success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetPlaylist(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    auto res = m_playlist_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::PlaylistNotFound, res.error()});
}

json Router::handleUpdatePlaylist(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                {"title", Type::String, false},
                                                {"description", Type::String, false}});
    if (err) return *err;

    PlaylistUpdate update_data = params.get<PlaylistUpdate>();
    if (!update_data.has_updates()) {
        return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
    }

    auto res = m_playlist_controller->update(update_data);
    if (res) {
        json response = ApiResponse::success({{"id", update_data.id}});
        response["message"] = "Update Playlist success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleAddPlaylistTrack(const json &params) {
    auto err = JsonValidator::validate(params, {{"playlist_id", Type::String, true, StringFormat::UUID},
                                                {"track_id", Type::String, true, StringFormat::UUID},
                                                {"position", Type::Integer, false}});
    if (err) return *err;

    auto res = m_playlist_controller->add_track(params["playlist_id"], params["track_id"],
                                                params.contains("position") ? std::optional<int>(params["position"].get<int>()) : std::nullopt);
    if (res) {
        json response;
        response["code"] = 201;
        response["message"] = "Add PlaylistTrack success.";
        return response;
    }
    std::string err_msg = res.error();
    if (err_msg.find("Playlist ID not found") != std::string::npos || err_msg.find("Playlist not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::PlaylistNotFound, err_msg});
    } else if (err_msg.find("Track ID not found") != std::string::npos || err_msg.find("Track not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::TrackNotFound, err_msg});
    }
    return ApiResponse::error({ErrorType::DatabaseError, err_msg});
}

json Router::handleRemovePlaylistTrack(const json &params) {
    auto err = JsonValidator::validate(params, {{"playlist_id", Type::String, true, StringFormat::UUID},
                                                {"track_id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    auto res = m_playlist_controller->remove_track(params["playlist_id"], params["track_id"]);
    if (res) {
        json response;
        response["code"] = 200;
        response["message"] = "Remove PlaylistTrack success.";
        return response;
    }
    std::string err_msg = res.error();
    if (err_msg.find("Track not found in playlist") != std::string::npos) {
        return ApiResponse::error({ErrorType::RelationNotFound, "Track not found in playlist."});
    }
    return ApiResponse::error({ErrorType::DatabaseError, err_msg});
}

json Router::handleGetPlaylistTracks(const json &params) {
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    std::vector<std::string> tracks = m_playlist_controller->get_tracks(params["id"].get<std::string>());
    return ApiResponse::success(tracks);
}

json Router::route(const json &request) {
    if (!request.contains("command") || !request["command"].is_string()) {
        return ApiResponse::error(
            {ErrorType::InvalidCommandFormat, "Missing or invalid 'command' field"});
    }

    const std::string command = request["command"];
    json params = request.value("params", json::object());

    auto it = m_handlers.find(command);
    if (it != m_handlers.end()) {
        return it->second(params);
    }

    return ApiResponse::error({ErrorType::UnknownCommand, "Unknown command: " + command});
}

} // namespace lyra
