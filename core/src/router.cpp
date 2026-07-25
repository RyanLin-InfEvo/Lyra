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
#include "services/database_context.h"
#include "services/repositories/sqlite/sqlite_album_repository.h"
#include "services/repositories/sqlite/sqlite_artist_repository.h"
#include "services/repositories/sqlite/sqlite_asset_repository.h"
#include "services/repositories/sqlite/sqlite_audio_repository.h"
#include "services/repositories/sqlite/sqlite_image_repository.h"
#include "services/repositories/sqlite/sqlite_playlist_repository.h"
#include "services/repositories/sqlite/sqlite_track_repository.h"
#include "services/repositories/sqlite/sqlite_work_repository.h"
#include "utils/audio_helper.h"
#include "utils/json_helper.h"
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
    m_asset_repo = std::make_unique<SqliteAssetRepository>(*m_db_context);
    m_audio_repo = std::make_unique<SqliteAudioRepository>(*m_db_context);
    m_image_repo = std::make_unique<SqliteImageRepository>(*m_db_context);
    m_playlist_repo = std::make_unique<SqlitePlaylistRepository>(*m_db_context);
    m_track_repo = std::make_unique<SqliteTrackRepository>(*m_db_context);
    m_work_repo = std::make_unique<SqliteWorkRepository>(*m_db_context);

    std::string storage_root = std::filesystem::path(db_path).parent_path().string();

    m_album_controller = std::make_unique<AlbumController>(*m_album_repo);
    m_artist_controller = std::make_unique<ArtistController>(*m_artist_repo);
    m_asset_controller = std::make_unique<AssetController>(*m_asset_repo, *m_audio_repo, storage_root, m_image_repo.get());
    m_audio_controller = std::make_unique<AudioController>(*m_audio_repo);
    m_playlist_controller = std::make_unique<PlaylistController>(*m_playlist_repo);
    m_track_controller = std::make_unique<TrackController>(*m_track_repo);
    m_work_controller = std::make_unique<WorkController>(*m_work_repo);

    init_handlers();
}

Router::~Router() = default;

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

template <typename GetFn, typename CreateFn>
tl::expected<std::string, json> get_or_create_entity(
    const std::string &key,
    const std::string &entity_type, // For error log
    GetFn &&get_fn,
    CreateFn &&create_fn) {
    auto get_res = get_fn(key);
    if (!get_res) {
        return tl::unexpected(ApiResponse::error({ErrorType::DatabaseError,
                                                  "Database error retrieving " + entity_type + ": " + get_res.error()}));
    }
    if (!get_res.value().empty()) {
        return get_res.value()[0].id;
    }

    auto create_res = create_fn(key);
    if (!create_res) {
        return tl::unexpected(ApiResponse::error({ErrorType::DatabaseError,
                                                  "Failed to create " + entity_type + ": " + create_res.error()}));
    }
    return *create_res;
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

    std::string source_path = params["source_path"].get<std::string>();

    // 1. Extract metadata tags first
    auto metadata_res = utils::AudioHelper::extract_metadata(source_path);
    if (!metadata_res) {
        return ApiResponse::error({ErrorType::InvalidValue, "Failed to extract metadata: " + metadata_res.error()});
    }
    const auto &tags = metadata_res.value();

    // 2. Begin transaction
    auto tx = m_db_context->begin_transaction();

    // 3. Ingest asset
    auto ingest_res = m_asset_controller->ingest(source_path);
    if (!ingest_res) {
        return ApiResponse::error({ErrorType::InvalidValue, "Asset ingestion failed: " + ingest_res.error()});
    }
    const auto &asset = ingest_res.value().asset;
    const auto &audio_json = ingest_res.value().metadata;
    std::string pcm_hash = audio_json["pcm_hash"].get<std::string>();
    double duration_sec = audio_json["duration"].get<double>();

    // 4. Extract metadata fields
    std::string title;
    if (tags.title && !tags.title->empty()) {
        title = *tags.title;
    } else {
        title = std::filesystem::path(source_path).stem().string();
    }

    // Artist deduplication & creation
    std::string artist_id;
    if (tags.artist && !tags.artist->empty()) {
        auto artist_name = *tags.artist;
        auto artist_res = get_or_create_entity(
            artist_name,
            "artist",
            [&](const std::string &name) { return m_artist_repo->get_by_name(name); },
            [&](const std::string &name) -> tl::expected<std::string, std::string> {
                Artist artist;
                artist.name = name;
                auto res = m_artist_controller->create(artist);
                if (!res) return tl::unexpected(res.error());
                return artist.id;
            });
        if (!artist_res) return artist_res.error();
        artist_id = artist_res.value();
    }

    // Album deduplication & creation
    std::string album_id;
    if (tags.album && !tags.album->empty()) {
        auto album_title = *tags.album;
        auto album_res = get_or_create_entity(
            album_title,
            "album",
            [&](const std::string &title) { return m_album_repo->get_by_title(title); },
            [&](const std::string &title) -> tl::expected<std::string, std::string> {
                Album album;
                album.title = title;
                auto res = m_album_controller->create(album);
                if (!res) return tl::unexpected(res.error());
                return album.id;
            });
        if (!album_res) return album_res.error();
        album_id = album_res.value();
    }

    // Track creation
    std::optional<uint16_t> recording_year = std::nullopt;
    std::optional<uint8_t> recording_month = std::nullopt;
    std::optional<uint8_t> recording_day = std::nullopt;
    if (tags.date && !tags.date->empty()) {
        const auto &date_str = *tags.date;
        try {
            if (date_str.length() >= 4) {
                bool all_digits = true;
                for (int i = 0; i < 4; ++i) {
                    if (!std::isdigit(date_str[i])) {
                        all_digits = false;
                        break;
                    }
                }
                if (all_digits) {
                    recording_year = static_cast<uint16_t>(std::stoi(date_str.substr(0, 4)));
                }
            }
        } catch (...) {
            // ignore
        }
        try {
            if (date_str.length() >= 10 && date_str[4] == '-' && date_str[7] == '-') {
                if (std::isdigit(date_str[5]) && std::isdigit(date_str[6])) {
                    recording_month = static_cast<uint8_t>(std::stoi(date_str.substr(5, 2)));
                }
                if (std::isdigit(date_str[8]) && std::isdigit(date_str[9])) {
                    recording_day = static_cast<uint8_t>(std::stoi(date_str.substr(8, 2)));
                }
            }
        } catch (...) {
            // ignore
        }
    }

    Track track;
    track.pcm_hash = pcm_hash;
    track.title = title;
    track.recording_year = recording_year;
    track.recording_month = recording_month;
    track.recording_day = recording_day;
    track.duration = static_cast<uint32_t>(duration_sec * 1000.0);

    auto create_track_res = m_track_controller->create(track);
    if (!create_track_res) {
        return ApiResponse::error({ErrorType::DatabaseError, "Failed to create track: " + create_track_res.error()});
    }

    // Link Artist
    if (!artist_id.empty()) {
        TrackArtistParams artist_params;
        artist_params.track_id = track.id;
        artist_params.artist_id = artist_id;
        artist_params.role = ArtistRole::Main;
        artist_params.position = 1;
        auto link_artist_res = m_track_repo->add_artist(artist_params);
        if (!link_artist_res) {
            return ApiResponse::error({ErrorType::DatabaseError, "Failed to link artist to track: " + link_artist_res.error()});
        }
    }

    // Link Album
    if (!album_id.empty()) {
        std::optional<int> position = std::nullopt;
        if (tags.track && !tags.track->empty()) {
            const auto &track_str = *tags.track;
            std::string pos_str;
            for (char c : track_str) {
                if (std::isdigit(c)) {
                    pos_str += c;
                } else {
                    break;
                }
            }
            if (!pos_str.empty()) {
                try {
                    position = std::stoi(pos_str);
                } catch (...) {
                    // ignore
                }
            }
        }

        TrackAlbumParams album_params;
        album_params.track_id = track.id;
        album_params.album_id = album_id;
        album_params.position = position;
        auto link_album_res = m_track_repo->add_album(album_params);
        if (!link_album_res) {
            return ApiResponse::error({ErrorType::DatabaseError, "Failed to link album to track: " + link_album_res.error()});
        }
    }

    // Link Cover Image if present
    if (ingest_res.value().cover_image_hash.has_value() && m_image_repo) {
        const std::string &cover_hash = *ingest_res.value().cover_image_hash;
        auto link_track_img = m_image_repo->link_entity(track.id, cover_hash, "front");
        if (!link_track_img) {
            return ApiResponse::error({ErrorType::DatabaseError, "Failed to link cover image to track: " + link_track_img.error()});
        }
        if (!album_id.empty()) {
            auto existing_images = m_image_repo->get_images_by_entity(album_id);
            if (!existing_images) {
                return ApiResponse::error({ErrorType::DatabaseError, "Failed to query album images: " + existing_images.error()});
            }
            if (existing_images.value().empty()) {
                auto link_album_img = m_image_repo->link_entity(album_id, cover_hash, "front");
                if (!link_album_img) {
                    return ApiResponse::error({ErrorType::DatabaseError, "Failed to link cover image to album: " + link_album_img.error()});
                }
            }
        }
    }

    // Commit transaction
    tx->commit();

    json response_data;
    response_data["track_id"] = track.id;
    response_data["pcm_hash"] = track.pcm_hash;
    response_data["title"] = track.title.value_or("");
    if (!artist_id.empty()) response_data["artist_id"] = artist_id;
    if (!album_id.empty()) response_data["album_id"] = album_id;
    if (ingest_res.value().cover_image_hash.has_value()) {
        response_data["cover_image_hash"] = *ingest_res.value().cover_image_hash;
    }

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
                                                {"mime_type", Type::String, false},
                                                {"asset_type", Type::String, false},
                                                {"file_size", Type::Integer, false}});
    if (err) return *err;

    Asset asset = params.get<Asset>();
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

    auto res = m_asset_controller->ingest(params["source_path"].get<std::string>());
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
    auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID}});
    if (err) return *err;

    std::vector<std::string> tracks = m_playlist_controller->get_tracks(params["id"].get<std::string>());
    return ApiResponse::success(tracks);
}

json Router::handleGetTracksByTitle(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true}});
    if (err) return *err;

    auto res = m_track_controller->get_by_title(params["title"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetArtistsByName(const json &params) {
    auto err = JsonValidator::validate(params, {{"name", Type::String, true}});
    if (err) return *err;

    auto res = m_artist_controller->get_by_name(params["name"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetAlbumsByTitle(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true}});
    if (err) return *err;

    auto res = m_album_controller->get_by_title(params["title"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetWorksByTitle(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true}});
    if (err) return *err;

    auto res = m_work_controller->get_by_title(params["title"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetPlaylistsByTitle(const json &params) {
    auto err = JsonValidator::validate(params, {{"title", Type::String, true}});
    if (err) return *err;

    auto res = m_playlist_controller->get_by_title(params["title"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
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
