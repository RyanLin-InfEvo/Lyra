// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <filesystem>
#include <functional>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <unordered_map>

#include "controllers/album_controller.h"
#include "controllers/artist_controller.h"
#include "controllers/asset_controller.h"
#include "controllers/audio_controller.h"
#include "controllers/playlist_controller.h"
#include "controllers/track_controller.h"
#include "controllers/work_controller.h"
#include "models/relation_types.h"
#include "models/track.h"
#include "services/audio_engine.h"
#include "services/cover_art_service.h"
#include "services/database_context.h"
#include "services/ingestion_service.h"
#include "services/repositories/sqlite/sqlite_album_repository.h"
#include "services/repositories/sqlite/sqlite_artist_repository.h"
#include "services/repositories/sqlite/sqlite_asset_repository.h"
#include "services/repositories/sqlite/sqlite_audio_repository.h"
#include "services/repositories/sqlite/sqlite_image_repository.h"
#include "services/repositories/sqlite/sqlite_playlist_repository.h"
#include "services/repositories/sqlite/sqlite_track_repository.h"
#include "services/repositories/sqlite/sqlite_work_repository.h"
#include "services/waveform_service.h"
#include "utils/audio_helper.h"
#include "utils/json_helper.h"
#include "utils/json_validator.h"
#include "utils/make_error.h"
#include "utils/storage_helper.h"

#include "router.h"

namespace lyra {

using json = nlohmann::json;
using Type = JsonFieldType;

Router::Router(const std::string &db_path) {
    m_db_context = std::make_unique<SqliteDatabaseContext>(db_path);

    m_album_repo = std::make_unique<SqliteAlbumRepository>(*m_db_context);
    m_artist_repo = std::make_unique<SqliteArtistRepository>(*m_db_context);
    m_asset_repo = std::make_unique<SqliteAssetRepository>(*m_db_context);
    m_audio_repo = std::make_unique<SqliteAudioRepository>(*m_db_context);
    m_image_repo = std::make_unique<SqliteImageRepository>(*m_db_context);
    m_playlist_repo = std::make_unique<SqlitePlaylistRepository>(*m_db_context);
    m_track_repo = std::make_unique<SqliteTrackRepository>(*m_db_context);
    m_work_repo = std::make_unique<SqliteWorkRepository>(*m_db_context);

    m_storage_root = std::filesystem::path(db_path).parent_path().string();

    m_album_controller = std::make_unique<AlbumController>(*m_album_repo);
    m_artist_controller = std::make_unique<ArtistController>(*m_artist_repo);
    m_asset_controller = std::make_unique<AssetController>(*m_asset_repo, m_storage_root);
    m_audio_controller = std::make_unique<AudioController>(*m_audio_repo);
    m_playlist_controller = std::make_unique<PlaylistController>(*m_playlist_repo);
    m_track_controller = std::make_unique<TrackController>(*m_track_repo);
    m_work_controller = std::make_unique<WorkController>(*m_work_repo);
    m_audio_engine = std::make_unique<AudioEngine>();
    m_ingestion_service = std::make_unique<IngestionService>(
        *m_db_context,
        *m_asset_repo,
        *m_audio_repo,
        *m_artist_repo,
        *m_album_repo,
        *m_track_repo,
        m_storage_root,
        m_image_repo.get());
    m_cover_art_service = std::make_unique<CoverArtService>(
        *m_image_repo,
        *m_track_repo,
        *m_album_repo,
        *m_artist_repo,
        *m_playlist_repo,
        *m_asset_repo,
        m_storage_root);

    init_handlers();
}

Router::~Router() = default;

void Router::set_event_callback(std::function<void(const std::string &)> callback) {
    if (m_audio_engine) m_audio_engine->set_event_callback(std::move(callback));
}

AudioEngine &Router::get_audio_engine() {
    return *m_audio_engine;
}

void Router::init_handlers() {
    // Artist
    m_handlers["CreateArtist"] = [this](const json &p) { return handleCreateArtist(p); };
    m_handlers["UpdateArtist"] = [this](const json &p) { return handleUpdateArtist(p); };
    m_handlers["GetArtist"] = [this](const json &p) { return handleGetArtist(p); };
    m_handlers["ListArtists"] = [this](const json &p) { return handleListArtists(p); };

    // Track
    m_handlers["CreateTrack"] = [this](const json &p) { return handleCreateTrack(p); };
    m_handlers["UpdateTrack"] = [this](const json &p) { return handleUpdateTrack(p); };
    m_handlers["GetTrack"] = [this](const json &p) { return handleGetTrack(p); };
    m_handlers["ListTracks"] = [this](const json &p) { return handleListTracks(p); };
    m_handlers["ImportTrack"] = [this](const json &p) { return handleImportTrack(p); };

    // Album
    m_handlers["CreateAlbum"] = [this](const json &p) { return handleCreateAlbum(p); };
    m_handlers["UpdateAlbum"] = [this](const json &p) { return handleUpdateAlbum(p); };
    m_handlers["GetAlbum"] = [this](const json &p) { return handleGetAlbum(p); };
    m_handlers["ListAlbums"] = [this](const json &p) { return handleListAlbums(p); };

    // Asset
    m_handlers["CreateAsset"] = [this](const json &p) { return handleCreateAsset(p); };
    m_handlers["UpdateAsset"] = [this](const json &p) { return handleUpdateAsset(p); };
    m_handlers["GetAsset"] = [this](const json &p) { return handleGetAsset(p); };
    m_handlers["ListAssets"] = [this](const json &p) { return handleListAssets(p); };
    m_handlers["IngestAsset"] = [this](const json &p) { return handleIngestAsset(p); };
    m_handlers["GetResourcePath"] = [this](const json &p) { return handleGetResourcePath(p); };

    // Audio
    m_handlers["CreateAudio"] = [this](const json &p) { return handleCreateAudio(p); };
    m_handlers["UpdateAudio"] = [this](const json &p) { return handleUpdateAudio(p); };
    m_handlers["GetAudio"] = [this](const json &p) { return handleGetAudio(p); };
    m_handlers["ListAudio"] = [this](const json &p) { return handleListAudio(p); };

    // Work
    m_handlers["CreateWork"] = [this](const json &p) { return handleCreateWork(p); };
    m_handlers["UpdateWork"] = [this](const json &p) { return handleUpdateWork(p); };
    m_handlers["GetWork"] = [this](const json &p) { return handleGetWork(p); };
    m_handlers["ListWorks"] = [this](const json &p) { return handleListWorks(p); };

    // Track-Artist
    m_handlers["AddTrackArtist"] = [this](const json &p) { return handleAddTrackArtist(p); };
    m_handlers["RemoveTrackArtist"] = [this](const json &p) { return handleRemoveTrackArtist(p); };
    m_handlers["UpdateTrackArtist"] = [this](const json &p) { return handleUpdateTrackArtist(p); };

    // Playlist
    m_handlers["CreatePlaylist"] = [this](const json &p) { return handleCreatePlaylist(p); };
    m_handlers["UpdatePlaylist"] = [this](const json &p) { return handleUpdatePlaylist(p); };
    m_handlers["GetPlaylist"] = [this](const json &p) { return handleGetPlaylist(p); };
    m_handlers["ListPlaylists"] = [this](const json &p) { return handleListPlaylists(p); };

    // Playlist-Track
    m_handlers["AddPlaylistTrack"] = [this](const json &p) { return handleAddPlaylistTrack(p); };
    m_handlers["RemovePlaylistTrack"] = [this](const json &p) { return handleRemovePlaylistTrack(p); };
    m_handlers["GetPlaylistTracks"] = [this](const json &p) { return handleGetPlaylistTracks(p); };

    // Exact query endpoints
    m_handlers["GetTracksByTitle"] = [this](const json &p) { return handleGetTracksByTitle(p); };
    m_handlers["GetArtistsByName"] = [this](const json &p) { return handleGetArtistsByName(p); };
    m_handlers["GetAlbumsByTitle"] = [this](const json &p) { return handleGetAlbumsByTitle(p); };
    m_handlers["GetWorksByTitle"] = [this](const json &p) { return handleGetWorksByTitle(p); };
    m_handlers["GetPlaylistsByTitle"] = [this](const json &p) { return handleGetPlaylistsByTitle(p); };

    // Cover Art endpoints
    m_handlers["GetAlbumCover"] = [this](const json &p) { return handleGetAlbumCover(p); };
    m_handlers["GetTrackCover"] = [this](const json &p) { return handleGetTrackCover(p); };
    m_handlers["GetArtistCover"] = [this](const json &p) { return handleGetArtistCover(p); };
    m_handlers["GetPlaylistCover"] = [this](const json &p) { return handleGetPlaylistCover(p); };
    m_handlers["GetEntityImages"] = [this](const json &p) { return handleGetEntityImages(p); };

    // Audio Engine Control endpoints
    m_handlers["audio.play"] = [this](const json &p) { return handleAudioPlay(p); };
    m_handlers["audio.pause"] = [this](const json &p) { return handleAudioPause(p); };
    m_handlers["audio.resume"] = [this](const json &p) { return handleAudioResume(p); };
    m_handlers["audio.seek"] = [this](const json &p) { return handleAudioSeek(p); };
    m_handlers["audio.stop"] = [this](const json &p) { return handleAudioStop(p); };
    m_handlers["audio.set_volume"] = [this](const json &p) { return handleAudioSetVolume(p); };
    m_handlers["audio.get_state"] = [this](const json &p) { return handleAudioGetState(p); };
    m_handlers["audio.compare_versions"] = [this](const json &p) { return handleAudioCompareVersions(p); };
    m_handlers["audio.get_waveform"] = [this](const json &p) { return handleAudioGetWaveform(p); };
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

struct PaginationParams {
    int offset = 0;
    int limit = 20;
    std::optional<std::string> search = std::nullopt;
};

tl::expected<PaginationParams, json> parse_pagination(const json &params) {
    auto err = JsonValidator::validate(params, {{"offset", Type::Integer, false},
                                                {"limit", Type::Integer, false},
                                                {"search", Type::String, false}});
    if (err) {
        return tl::unexpected(*err);
    }

    int offset = JsonHelper::get_safe<int>(params, "offset", 0);
    int limit = JsonHelper::get_safe<int>(params, "limit", 20);

    if (offset < 0) {
        return tl::unexpected(ApiResponse::error({ErrorType::OutOfRange, "offset cannot be negative"}));
    }
    if (limit <= 0) {
        return tl::unexpected(ApiResponse::error({ErrorType::OutOfRange, "limit must be greater than 0"}));
    }
    if (limit > 100) {
        return tl::unexpected(ApiResponse::error({ErrorType::OutOfRange, "limit cannot exceed 100"}));
    }

    std::optional<std::string> search = std::nullopt;
    if (auto opt_s = JsonHelper::get_optional<std::string>(params, "search")) {
        size_t start = opt_s->find_first_not_of(" \t\r\n");
        if (start != std::string::npos) {
            size_t end = opt_s->find_last_not_of(" \t\r\n");
            search = opt_s->substr(start, end - start + 1);
        }
    }

    return PaginationParams{offset, limit, search};
}

tl::expected<std::string, json> resolveFileHash(
    const json &params,
    TrackController &track_controller,
    AssetController &asset_controller) {
    if (params.contains("file_hash") && !params["file_hash"].is_null()) {
        return params["file_hash"].get<std::string>();
    } else if (params.contains("pcm_hash") && !params["pcm_hash"].is_null()) {
        std::string pcm_hash = params["pcm_hash"].get<std::string>();
        auto assets_res = asset_controller.get_assets_by_audio(pcm_hash);
        if (!assets_res || assets_res.value().empty()) {
            return tl::unexpected(ApiResponse::error({ErrorType::AssetNotFound, "No assets found for the PCM hash"}));
        }
        return assets_res.value()[0];
    } else if (params.contains("track_id") && !params["track_id"].is_null()) {
        std::string track_id = params["track_id"].get<std::string>();
        auto track_res = track_controller.get(track_id);
        if (!track_res) {
            return tl::unexpected(ApiResponse::error({ErrorType::TrackNotFound, track_res.error()}));
        }
        std::string pcm_hash = track_res.value().pcm_hash;
        auto assets_res = asset_controller.get_assets_by_audio(pcm_hash);
        if (!assets_res || assets_res.value().empty()) {
            return tl::unexpected(ApiResponse::error({ErrorType::AssetNotFound, "No assets found for the track's audio"}));
        }
        return assets_res.value()[0];
    }

    return tl::unexpected(ApiResponse::error({ErrorType::MissingParameter, "Must provide track_id, pcm_hash, or file_hash"}));
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

json Router::handleListArtists(const json &params) {
    auto parse_res = parse_pagination(params);
    if (!parse_res) {
        return parse_res.error();
    }
    const auto &p = parse_res.value();
    auto res = m_artist_controller->list(p.offset, p.limit, p.search);
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Track Handlers ---

json Router::handleCreateTrack(const json &params) {
    // TODO: Once audio file upload or decoding is implemented, calculate pcm_hash
    // on the server side from the audio payload to prevent client-side manipulation/attacks.
    auto err = JsonValidator::validate(params, {{"pcm_hash", Type::String, true},
                                                {"title", Type::String, false},
                                                {"work_id", Type::String, false, StringFormat::UUID},
                                                {"recording_year", Type::Year, false},
                                                {"recording_month", Type::Month, false},
                                                {"recording_day", Type::Day, false},
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

json Router::handleListTracks(const json &params) {
    auto parse_res = parse_pagination(params);
    if (!parse_res) {
        return parse_res.error();
    }
    const auto &p = parse_res.value();
    auto res = m_track_controller->list(p.offset, p.limit, p.search);
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleImportTrack(const json &params) {
    auto err = JsonValidator::validate(params, {{"source_path", Type::String, true}});
    if (err) return *err;

    TrackImportRequest req;
    req.source_path = params["source_path"].get<std::string>();

    auto res = m_ingestion_service->import_track(req);
    if (!res) return ApiResponse::error({ErrorType::InvalidValue, res.error()});

    const auto &val = res.value();
    json response_data;
    response_data["track_id"] = val.track_id;
    response_data["pcm_hash"] = val.pcm_hash;
    response_data["title"] = val.title;
    if (val.artist_id.has_value()) response_data["artist_id"] = *val.artist_id;
    if (val.album_id.has_value()) response_data["album_id"] = *val.album_id;
    if (val.cover_image_hash.has_value()) response_data["cover_image_hash"] = *val.cover_image_hash;

    return ApiResponse::success(response_data);
}

// --- Album Handlers ---

json Router::handleCreateAlbum(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true},
                                                {"release_year", Type::Year, false},
                                                {"release_month", Type::Month, false},
                                                {"release_day", Type::Day, false}});
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
                                                {"release_month", Type::Month, false},
                                                {"release_day", Type::Day, false}});
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

json Router::handleListAlbums(const json &params) {
    auto parse_res = parse_pagination(params);
    if (!parse_res) {
        return parse_res.error();
    }
    const auto &p = parse_res.value();
    auto res = m_album_controller->list(p.offset, p.limit, p.search);
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Asset Handlers ---

json Router::handleCreateAsset(const json &params) {
    auto err = JsonValidator::validate(params, {{"file_hash", Type::String, true},
                                                {"pcm_hash", Type::String, false},
                                                {"mime_type", Type::String, false},
                                                {"asset_type", Type::String, false},
                                                {"file_size", Type::Integer, false}});
    if (err) return *err;

    Asset asset = params.get<Asset>();
    // When a `pcm_hash` is provided, link this physical file asset to the logical audio entity
    // via the Audio_Asset junction table within an atomic transaction.
    if (params.contains("pcm_hash") && !params["pcm_hash"].get<std::string>().empty()) {
        Audio audio;
        audio.pcm_hash = params["pcm_hash"].get<std::string>();
        auto res = m_asset_repo->insert_asset_with_audio(asset, audio);
        if (res) {
            json response;
            response["code"] = 201;
            response["data"]["file_hash"] = asset.file_hash;
            response["message"] = "Create Asset success.";
            return response;
        }
        return ApiResponse::error({ErrorType::DatabaseError, res.error()});
    }

    // Otherwise, insert standalone non-audio asset (e.g. cover art, lyrics) without Audio relationship.
    auto res = m_asset_controller->create(asset);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"]["file_hash"] = asset.file_hash;
        response["message"] = "Create Asset success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetAsset(const json &params) {
    auto err = JsonValidator::validate(params, {{"file_hash", Type::String, true}});
    if (err) return *err;

    auto res = m_asset_controller->get(params["file_hash"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::AssetNotFound, res.error()});
}

json Router::handleUpdateAsset(const json &params) {
    auto err = JsonValidator::validate(params, {{"file_hash", Type::String, true},
                                                {"mime_type", Type::String, false},
                                                {"asset_type", Type::String, false},
                                                {"file_size", Type::Integer, false}});
    if (err) return *err;

    AssetUpdate update_data = params.get<AssetUpdate>();
    if (!update_data.has_updates()) {
        return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
    }

    auto res = m_asset_controller->update(update_data);
    if (res) {
        json response = ApiResponse::success({{"file_hash", update_data.file_hash}});
        response["message"] = "Update Asset success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleListAssets(const json &params) {
    auto parse_res = parse_pagination(params);
    if (!parse_res) {
        return parse_res.error();
    }
    const auto &p = parse_res.value();
    auto res = m_asset_controller->list(p.offset, p.limit, p.search);
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleIngestAsset(const json &params) {
    auto err = JsonValidator::validate(params, {{"source_path", Type::String, true}});
    if (err) return *err;

    auto res = m_ingestion_service->ingest_asset(params["source_path"].get<std::string>());
    if (res) {
        json data;
        const auto &ingest_val = res.value();
        data["asset"] = ingest_val.asset;
        data[ingest_val.asset.asset_type] = ingest_val.metadata;
        if (ingest_val.cover_image_hash.has_value()) {
            data["cover_image_hash"] = *ingest_val.cover_image_hash;
        }
        if (ingest_val.cover_file_hash.has_value()) {
            data["cover_file_hash"] = *ingest_val.cover_file_hash;
        }
        return ApiResponse::success(data);
    }
    return ApiResponse::error({ErrorType::InvalidValue, res.error()});
}

json Router::handleGetResourcePath(const json &params) {
    auto err = JsonValidator::validate(params, {{"track_id", Type::String, false, StringFormat::UUID},
                                                {"file_hash", Type::String, false},
                                                {"pcm_hash", Type::String, false}});
    if (err) return *err;

    auto file_hash_res = resolveFileHash(params, *m_track_controller, *m_asset_controller);
    if (!file_hash_res) {
        return file_hash_res.error();
    }
    std::string file_hash = file_hash_res.value();

    auto asset_info_res = m_asset_controller->get(file_hash);
    if (!asset_info_res) {
        return ApiResponse::error({ErrorType::AssetNotFound, asset_info_res.error()});
    }

    auto path_res = m_asset_controller->resolve_file_path(file_hash);
    if (!path_res) {
        return ApiResponse::error({ErrorType::AssetNotFound, path_res.error()});
    }

    json response_data;
    response_data["path"] = path_res.value();
    response_data["mime_type"] = asset_info_res.value().mime_type;

    return ApiResponse::success(response_data);
}

// --- Audio Handlers ---

json Router::handleCreateAudio(const json &params) {
    auto err = JsonValidator::validate(params, {{"pcm_hash", Type::String, true},
                                                {"parent_hash", Type::String, false},
                                                {"quality_score", Type::Integer, false},
                                                {"bit_depth", Type::Integer, false},
                                                {"sample_rate", Type::Integer, false},
                                                {"channels", Type::Integer, false},
                                                {"duration", Type::Number, false},
                                                {"integrated_loudness", Type::Number, false},
                                                {"true_peak", Type::Number, false}});
    if (err) return *err;

    Audio audio = params.get<Audio>();
    auto res = m_audio_controller->create(audio);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"]["pcm_hash"] = audio.pcm_hash;
        response["message"] = "Create Audio success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetAudio(const json &params) {
    auto err = JsonValidator::validate(params, {{"pcm_hash", Type::String, true}});
    if (err) return *err;

    auto res = m_audio_controller->get(params["pcm_hash"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::AudioNotFound, res.error()});
}

json Router::handleUpdateAudio(const json &params) {
    auto err = JsonValidator::validate(params, {{"pcm_hash", Type::String, true},
                                                {"parent_hash", Type::String, false},
                                                {"quality_score", Type::Integer, false},
                                                {"bit_depth", Type::Integer, false},
                                                {"sample_rate", Type::Integer, false},
                                                {"channels", Type::Integer, false},
                                                {"duration", Type::Number, false},
                                                {"integrated_loudness", Type::Number, false},
                                                {"true_peak", Type::Number, false}});
    if (err) return *err;

    AudioUpdate update_data = params.get<AudioUpdate>();
    if (!update_data.has_updates()) {
        return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
    }

    auto res = m_audio_controller->update(update_data);
    if (res) {
        json response = ApiResponse::success({{"pcm_hash", update_data.pcm_hash}});
        response["message"] = "Update Audio success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleListAudio(const json &params) {
    auto parse_res = parse_pagination(params);
    if (!parse_res) {
        return parse_res.error();
    }
    const auto &p = parse_res.value();
    auto res = m_audio_controller->list(p.offset, p.limit, p.search);
    if (res) {
        return ApiResponse::success(res.value());
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

    if (auto year_err = validateWorkCompositionYears(params))
        return *year_err;

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

    if (auto year_err = validateWorkCompositionYears(params))
        return *year_err;

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

json Router::handleListWorks(const json &params) {
    auto parse_res = parse_pagination(params);
    if (!parse_res) {
        return parse_res.error();
    }
    const auto &p = parse_res.value();
    auto res = m_work_controller->list(p.offset, p.limit, p.search);
    if (res) {
        return ApiResponse::success(res.value());
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
        if (track_artist.role)
            response["data"]["role"] = *track_artist.role;
        if (track_artist.position)
            response["data"]["position"] = *track_artist.position;
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
        if (track_artist.role)
            response["data"]["role"] = *track_artist.role;
        if (track_artist.position)
            response["data"]["position"] = *track_artist.position;
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

json Router::handleListPlaylists(const json &params) {
    auto parse_res = parse_pagination(params);
    if (!parse_res) {
        return parse_res.error();
    }
    const auto &p = parse_res.value();
    auto res = m_playlist_controller->list(p.offset, p.limit, p.search);
    if (res) {
        return ApiResponse::success(res.value());
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
    auto err = JsonValidator::validate(params, {{"id", Type::String, false, StringFormat::UUID},
                                                {"playlist_id", Type::String, false, StringFormat::UUID}});
    if (err) return *err;

    std::string playlist_id;
    if (params.contains("id") && params["id"].is_string()) {
        playlist_id = params["id"].get<std::string>();
    } else if (params.contains("playlist_id") && params["playlist_id"].is_string()) {
        playlist_id = params["playlist_id"].get<std::string>();
    } else {
        return ApiResponse::error({ErrorType::MissingParameter, "Missing 'id' or 'playlist_id' parameter"});
    }

    std::vector<std::string> tracks = m_playlist_controller->get_tracks(playlist_id);
    return ApiResponse::success(tracks);
}

json Router::handleGetTracksByTitle(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true}});
    if (err) return *err;

    auto res = m_track_controller->get_by_title(params["title"].get<std::string>());
    if (res) return ApiResponse::success(res.value());

    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetArtistsByName(const json &params) {
    auto err = JsonValidator::validate(params, {{"name", Type::String, true}});
    if (err) return *err;

    auto res = m_artist_controller->get_by_name(params["name"].get<std::string>());
    if (res) return ApiResponse::success(res.value());

    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetAlbumsByTitle(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true}});
    if (err) return *err;

    auto res = m_album_controller->get_by_title(params["title"].get<std::string>());
    if (res) return ApiResponse::success(res.value());
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetWorksByTitle(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true}});
    if (err) return *err;

    auto res = m_work_controller->get_by_title(params["title"].get<std::string>());
    if (res) return ApiResponse::success(res.value());

    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetPlaylistsByTitle(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true}});
    if (err) return *err;

    auto res = m_playlist_controller->get_by_title(params["title"].get<std::string>());
    if (res) return ApiResponse::success(res.value());
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Cover Art & Image Handlers ---

json Router::build_image_response(const CoverResolutionResult &res) {
    json data;
    data["image_hash"] = res.image_hash;
    data["file_hash"] = res.file_hash;
    data["path"] = res.file_path;
    data["mime_type"] = res.mime_type;
    data["width"] = res.width;
    data["height"] = res.height;

    json response = ApiResponse::success(data);
    response["status"] = "success";
    return response;
}

json Router::handleGetAlbumCover(const json &params) {
    auto err = JsonValidator::validate(params, {{"album_id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    if (!m_cover_art_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Cover art service not available"});
    }

    std::string album_id = params["album_id"].get<std::string>();
    auto res = m_cover_art_service->get_album_cover(album_id);
    if (!res) {
        return ApiResponse::error(res.error());
    }

    return build_image_response(res.value());
}

json Router::handleGetTrackCover(const json &params) {
    auto err = JsonValidator::validate(params, {{"track_id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    if (!m_cover_art_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Cover art service not available"});
    }

    std::string track_id = params["track_id"].get<std::string>();
    auto res = m_cover_art_service->get_track_cover(track_id);
    if (!res) {
        return ApiResponse::error(res.error());
    }

    return build_image_response(res.value());
}

json Router::handleAudioPlay(const json &p) {
    // Play a file_path, track_id, id, asset_id, or audio_id
    std::string file_path;
    if (p.contains("file_path") && p["file_path"].is_string()) {
        file_path = p["file_path"].get<std::string>();
    } else if (p.contains("track_id") && p["track_id"].is_string()) {
        std::string track_id = p["track_id"].get<std::string>();
        auto track_res = m_track_controller->get(track_id);
        if (!track_res) {
            return ApiResponse::error(Error{ErrorType::TrackNotFound, "Track not found: " + track_id});
        }
        std::string pcm_hash = track_res.value().pcm_hash;
        auto assets_res = m_asset_controller->get_assets_by_audio(pcm_hash);
        if (!assets_res || assets_res->empty()) {
            return ApiResponse::error(Error{ErrorType::AssetNotFound, "No assets found for track's audio: " + track_id});
        }
        auto path_res = m_asset_controller->resolve_file_path((*assets_res)[0]);
        if (!path_res) {
            return ApiResponse::error(Error{ErrorType::NotFound, "File path not found for asset: " + (*assets_res)[0]});
        }
        file_path = *path_res;
    } else if (p.contains("id") && p["id"].is_string()) {
        std::string track_id = p["id"].get<std::string>();
        auto track_res = m_track_controller->get(track_id);
        if (!track_res) {
            return ApiResponse::error(Error{ErrorType::TrackNotFound, "Track not found: " + track_id});
        }
        std::string pcm_hash = track_res.value().pcm_hash;
        auto assets_res = m_asset_controller->get_assets_by_audio(pcm_hash);
        if (!assets_res || assets_res->empty()) {
            return ApiResponse::error(Error{ErrorType::AssetNotFound, "No assets found for track's audio: " + track_id});
        }
        auto path_res = m_asset_controller->resolve_file_path((*assets_res)[0]);
        if (!path_res) {
            return ApiResponse::error(Error{ErrorType::NotFound, "File path not found for asset: " + (*assets_res)[0]});
        }
        file_path = *path_res;
    } else if (p.contains("asset_id") && p["asset_id"].is_string()) {
        std::string asset_id = p["asset_id"].get<std::string>();
        auto path_res = m_asset_controller->resolve_file_path(asset_id);
        if (!path_res) {
            return ApiResponse::error(Error{ErrorType::NotFound, "File path not found for asset: " + asset_id});
        }
        file_path = *path_res;
    } else if (p.contains("audio_id") && p["audio_id"].is_string()) {
        std::string pcm_hash = p["audio_id"].get<std::string>();
        auto assets_res = m_asset_controller->get_assets_by_audio(pcm_hash);
        if (!assets_res || assets_res->empty()) {
            return ApiResponse::error(Error{ErrorType::AudioNotFound, "No assets found for audio: " + pcm_hash});
        }
        auto path_res = m_asset_controller->resolve_file_path((*assets_res)[0]);
        if (!path_res) {
            return ApiResponse::error(Error{ErrorType::NotFound, "File path not found for asset: " + (*assets_res)[0]});
        }
        file_path = *path_res;
    } else {
        return ApiResponse::error(Error{ErrorType::MissingParameter, "Missing 'file_path', 'track_id', 'id', 'asset_id', or 'audio_id' parameter"});
    }

    if (!std::filesystem::exists(file_path)) {
        return ApiResponse::error(Error{ErrorType::NotFound, "Audio file does not exist on disk: " + file_path});
    }

    double start_pos = 0.0;
    if (p.contains("start_position") && p["start_position"].is_number()) {
        start_pos = p["start_position"].get<double>();
    } else if (p.contains("start_position_seconds") && p["start_position_seconds"].is_number()) {
        start_pos = p["start_position_seconds"].get<double>();
    }

    bool success = m_audio_engine->play(file_path, start_pos);
    if (!success) {
        return ApiResponse::error(Error{ErrorType::InvalidValue, "Failed to initialize decoder for audio file: " + file_path});
    }
    return ApiResponse::success(m_audio_engine->get_state_json());
}

json Router::handleAudioPause(const json &p) {
    (void)p;
    m_audio_engine->pause();
    return ApiResponse::success(m_audio_engine->get_state_json());
}

json Router::handleAudioResume(const json &p) {
    (void)p;
    m_audio_engine->resume();
    return ApiResponse::success(m_audio_engine->get_state_json());
}

json Router::handleAudioSeek(const json &p) {
    double pos = 0.0;
    if (p.contains("position") && p["position"].is_number()) {
        pos = p["position"].get<double>();
    } else if (p.contains("position_seconds") && p["position_seconds"].is_number()) {
        pos = p["position_seconds"].get<double>();
    } else {
        return ApiResponse::error(Error{ErrorType::MissingParameter, "Missing or invalid 'position' or 'position_seconds' parameter"});
    }

    bool relative = false;
    if (p.contains("relative") && p["relative"].is_boolean()) {
        relative = p["relative"].get<bool>();
    }

    m_audio_engine->seek(pos, relative);
    return ApiResponse::success(m_audio_engine->get_state_json());
}

json Router::handleAudioStop(const json &p) {
    (void)p;
    m_audio_engine->stop();
    return ApiResponse::success(m_audio_engine->get_state_json());
}

json Router::handleAudioSetVolume(const json &p) {
    if (!p.contains("volume") || !p["volume"].is_number()) {
        return ApiResponse::error(Error{ErrorType::MissingParameter, "Missing or invalid 'volume' parameter"});
    }
    float vol = p["volume"].get<float>();
    m_audio_engine->set_volume(vol);
    return ApiResponse::success(m_audio_engine->get_state_json());
}

json Router::handleAudioGetState(const json &p) {
    (void)p;
    return ApiResponse::success(m_audio_engine->get_state_json());
}

json Router::handleAudioCompareVersions(const json &p) {
    std::vector<Audio> candidate_audios;

    if (p.contains("track_id") && !p["track_id"].is_null()) {
        if (!p["track_id"].is_string()) {
            return ApiResponse::error({ErrorType::InvalidValue, "track_id must be a string"});
        }
        std::string track_id = p["track_id"].get<std::string>();
        if (track_id.empty()) {
            return ApiResponse::error({ErrorType::MissingParameter, "track_id cannot be empty"});
        }
        auto track_res = m_track_controller->get(track_id);
        if (!track_res) {
            return ApiResponse::error({ErrorType::TrackNotFound, "Track not found: " + track_id});
        }
        if (track_res->pcm_hash.empty()) {
            return ApiResponse::error({ErrorType::AudioNotFound, "Track has no associated audio"});
        }
        auto versions_res = m_audio_controller->get_related_versions(track_res->pcm_hash);
        if (!versions_res || versions_res->empty()) {
            return ApiResponse::error({ErrorType::AudioNotFound, "Audio not found: " + track_res->pcm_hash});
        }
        candidate_audios = std::move(versions_res.value());
    } else if (p.contains("pcm_hashes") && !p["pcm_hashes"].is_null()) {
        if (!p["pcm_hashes"].is_array()) {
            return ApiResponse::error({ErrorType::InvalidValue, "pcm_hashes must be an array"});
        }
        if (p["pcm_hashes"].empty()) {
            return ApiResponse::error({ErrorType::MissingParameter, "pcm_hashes cannot be empty"});
        }
        for (const auto &item : p["pcm_hashes"]) {
            if (!item.is_string()) {
                return ApiResponse::error({ErrorType::InvalidValue, "pcm_hashes items must be strings"});
            }
        }
        for (const auto &item : p["pcm_hashes"]) {
            std::string hash = item.get<std::string>();
            auto audio_res = m_audio_controller->get(hash);
            if (!audio_res) {
                return ApiResponse::error({ErrorType::AudioNotFound, "Audio not found: " + hash});
            }
            candidate_audios.push_back(std::move(audio_res.value()));
        }
    } else {
        return ApiResponse::error({ErrorType::MissingParameter, "Missing 'pcm_hashes' or 'track_id' parameter"});
    }

    // Local data structure representing an audio version candidate and its quality metrics.
    struct VersionItem {
        std::string pcm_hash;
        std::string format;
        int quality_score = 0;
        bool is_lossless = false;
        int64_t file_size = 0;
        bool is_master = false;
    };

    std::vector<VersionItem> versions;
    versions.reserve(candidate_audios.size());

    // Evaluate quality metrics for each candidate audio file.
    for (const auto &audio : candidate_audios) {
        auto qinfo = utils::AudioHelper::evaluate_quality(audio);
        VersionItem item;
        item.pcm_hash = audio.pcm_hash;
        item.format = qinfo.format;
        item.quality_score = qinfo.quality_score;
        item.is_lossless = qinfo.is_lossless;
        item.file_size = qinfo.file_size;
        item.is_master = false;
        versions.push_back(std::move(item));
    }

    // Sort candidates to determine the optimal master version using a hierarchical priority:
    // 1. Quality score (higher score preferred)
    // 2. Lossless preference (lossless preferred over lossy)
    // 3. File size (larger file size preferred for tie-breaking fidelity)
    // 4. PCM hash (lexicographical order for deterministic tie-breaking)
    std::sort(versions.begin(), versions.end(), [](const VersionItem &a, const VersionItem &b) {
        if (a.quality_score != b.quality_score) {
            return a.quality_score > b.quality_score;
        }
        if (a.is_lossless != b.is_lossless) {
            return a.is_lossless && !b.is_lossless;
        }
        if (a.file_size != b.file_size) {
            return a.file_size > b.file_size;
        }
        return a.pcm_hash < b.pcm_hash;
    });

    // Mark the highest-ranking candidate as the recommended master.
    if (!versions.empty()) {
        versions[0].is_master = true;
    }

    std::string recommended_master = versions.empty() ? "" : versions[0].pcm_hash;

    json versions_array = json::array();
    for (const auto &v : versions) {
        json item;
        item["pcm_hash"] = v.pcm_hash;
        item["format"] = v.format;
        item["quality_score"] = v.quality_score;
        item["is_lossless"] = v.is_lossless;
        item["file_size"] = v.file_size;
        item["is_master"] = v.is_master;
        versions_array.push_back(item);
    }

    return ApiResponse::success({{"recommended_master", recommended_master},
                                 {"versions", versions_array}});
}

json Router::handleAudioGetWaveform(const json &p) {
    std::string pcm_hash;

    if (p.contains("track_id") && !p["track_id"].is_null()) {
        if (!p["track_id"].is_string()) {
            return ApiResponse::error({ErrorType::InvalidValue, "track_id must be a string"});
        }
        std::string track_id = p["track_id"].get<std::string>();
        if (track_id.empty()) {
            return ApiResponse::error({ErrorType::MissingParameter, "track_id cannot be empty"});
        }
        auto track_res = m_track_controller->get(track_id);
        if (!track_res) {
            return ApiResponse::error({ErrorType::TrackNotFound, "Track not found: " + track_id});
        }
        if (track_res->pcm_hash.empty()) {
            return ApiResponse::error({ErrorType::AudioNotFound, "Track has no associated audio"});
        }
        pcm_hash = track_res->pcm_hash;
        // Verify referential integrity: ensure the referenced Audio entity exists in the database.
        auto audio_res = m_audio_controller->get(pcm_hash);
        if (!audio_res) {
            return ApiResponse::error({ErrorType::AudioNotFound, "Audio not found for track: " + pcm_hash});
        }
    } else if (p.contains("pcm_hash") && !p["pcm_hash"].is_null()) {
        if (!p["pcm_hash"].is_string()) {
            return ApiResponse::error({ErrorType::InvalidValue, "pcm_hash must be a string"});
        }
        pcm_hash = p["pcm_hash"].get<std::string>();
        if (pcm_hash.empty()) {
            return ApiResponse::error({ErrorType::MissingParameter, "pcm_hash cannot be empty"});
        }
        // Verify that the requested Audio entity exists before attempting asset resolution and waveform generation.
        auto audio_res = m_audio_controller->get(pcm_hash);
        if (!audio_res) {
            return ApiResponse::error({ErrorType::AudioNotFound, "Audio not found: " + pcm_hash});
        }
    } else {
        return ApiResponse::error({ErrorType::MissingParameter, "Missing 'pcm_hash' or 'track_id' parameter"});
    }

    uint32_t points = 300;
    if (p.contains("points") && !p["points"].is_null()) {
        if (!p["points"].is_number_integer()) {
            return ApiResponse::error({ErrorType::InvalidValue, "points must be an integer"});
        }
        int64_t pts = p["points"].get<int64_t>();
        if (pts < 50 || pts > 1000) {
            return ApiResponse::error({ErrorType::OutOfRange, "points must be between 50 and 1000"});
        }
        points = static_cast<uint32_t>(pts);
    }


    auto assets_res = m_asset_controller->get_assets_by_audio(pcm_hash);
    if (!assets_res || assets_res->empty()) {
        return ApiResponse::error({ErrorType::AssetNotFound, "No assets found for audio: " + pcm_hash});
    }

    auto path_res = m_asset_controller->resolve_file_path((*assets_res)[0]);
    if (!path_res || !std::filesystem::exists(*path_res)) {
        return ApiResponse::error({ErrorType::AssetNotFound, "Asset file not found on disk for asset: " + (*assets_res)[0]});
    }

    auto wf_res = WaveformService::get_or_compute_waveform(m_storage_root, pcm_hash, *path_res, points);
    if (!wf_res) {
        return ApiResponse::error({ErrorType::NotFound, "Failed to compute waveform: " + wf_res.error()});
    }

    json data;
    data["pcm_hash"] = pcm_hash;
    data["points"] = wf_res->points;
    json peaks_array = json::array();
    for (const auto &pk : wf_res->peaks) {
        peaks_array.push_back({pk.first, pk.second});
    }
    data["peaks"] = std::move(peaks_array);
    data["rms"] = wf_res->rms;

    return ApiResponse::success(data);
}

json Router::handleGetArtistCover(const json &params) {
    auto err = JsonValidator::validate(params, {{"artist_id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    if (!m_cover_art_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Cover art service not available"});
    }

    std::string artist_id = params["artist_id"].get<std::string>();
    auto res = m_cover_art_service->get_artist_cover(artist_id);
    if (!res) {
        return ApiResponse::error(res.error());
    }

    return build_image_response(res.value());
}

json Router::handleGetPlaylistCover(const json &params) {
    auto err = JsonValidator::validate(params, {{"playlist_id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    if (!m_cover_art_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Cover art service not available"});
    }

    std::string playlist_id = params["playlist_id"].get<std::string>();
    auto res = m_cover_art_service->get_playlist_cover(playlist_id);
    if (!res) {
        return ApiResponse::error(res.error());
    }

    return build_image_response(res.value());
}

json Router::handleGetEntityImages(const json &params) {
    auto err = JsonValidator::validate(
        params, {{"entity_id", Type::String, true, StringFormat::UUID}, {"role", Type::String, false}});
    if (err) return *err;

    if (!m_cover_art_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Cover art service not available"});
    }

    std::string entity_id = params["entity_id"].get<std::string>();
    std::optional<std::string> role;
    if (params.contains("role") && !params["role"].is_null()) {
        role = params["role"].get<std::string>();
    }

    auto res = m_cover_art_service->get_entity_images(entity_id, role);
    if (!res) {
        return ApiResponse::error(res.error());
    }

    json result_list = json::array();
    for (const auto &item : res.value()) {
        json j;
        j["image_hash"] = item.image_hash;
        j["file_hash"] = item.file_hash;
        j["path"] = item.file_path;
        j["mime_type"] = item.mime_type;
        j["width"] = item.width;
        j["height"] = item.height;
        j["dominant_color"] = item.dominant_color;
        if (item.role.has_value()) {
            j["role"] = *item.role;
        } else {
            j["role"] = nullptr;
        }
        result_list.push_back(j);
    }

    json response = ApiResponse::success(result_list);
    response["status"] = "success";
    return response;
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
