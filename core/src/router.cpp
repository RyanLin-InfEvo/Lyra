// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <cmath>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <initializer_list>
#include <limits>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <string_view>
#include <system_error>
#include <unordered_map>
#include <utility>

#include "controllers/album_controller.h"
#include "controllers/artist_controller.h"
#include "controllers/asset_controller.h"
#include "controllers/audio_controller.h"
#include "controllers/playlist_controller.h"
#include "controllers/source_data_controller.h"
#include "controllers/tag_controller.h"
#include "controllers/track_controller.h"
#include "controllers/work_controller.h"
#include "models/relation_types.h"
#include "models/track.h"
#include "services/audio_engine.h"
#include "services/audio_scorer.h"
#include "services/configuration_service.h"
#include "services/cover_art_service.h"
#include "services/database_context.h"
#include "services/ingestion_service.h"
#include "services/playback_service.h"
#include "services/repositories/sqlite/sqlite_album_repository.h"
#include "services/repositories/sqlite/sqlite_artist_repository.h"
#include "services/repositories/sqlite/sqlite_asset_repository.h"
#include "services/repositories/sqlite/sqlite_audio_repository.h"
#include "services/repositories/sqlite/sqlite_image_repository.h"
#include "services/repositories/sqlite/sqlite_playlist_repository.h"
#include "services/repositories/sqlite/sqlite_source_data_repository.h"
#include "services/repositories/sqlite/sqlite_tag_repository.h"
#include "services/repositories/sqlite/sqlite_text_repository.h"
#include "services/repositories/sqlite/sqlite_track_repository.h"
#include "services/repositories/sqlite/sqlite_work_repository.h"
#include "services/text_service.h"
#include "services/waveform_service.h"
#include "utils/audio_helper.h"
#include "utils/json_helper.h"
#include "utils/json_validator.h"
#include "utils/make_error.h"
#include "utils/storage_helper.h"
#include "utils/utf8_helper.h"

#include "router.h"

namespace lyra {

using json = nlohmann::json;
using Type = JsonFieldType;

/**
 * @brief Translates domain-level PlaybackError into JSON-RPC / API Error responses.
 *
 * Implements layered boundary defense between core domain errors and HTTP/API error codes:
 *
 * 1. **Fail-Fast Parameter Validation (HTTP 400 - ErrorType::InvalidValue):**
 *    Invalid client parameters (empty identifiers, malformed UUIDs, non-hex hashes, invalid options)
 *    are immediately mapped to `ErrorType::InvalidValue`. This ensures client protocol errors fail
 *    fast before any database query or storage lookup is initiated.
 *
 * 2. **Missing Resource Boundary Defense (HTTP 404 - Not Found Matrix):**
 *    When a requested entity does not exist in the database or physical CAS storage, the error is
 *    mapped to a strongly typed semantic Not Found error corresponding to the target domain entity:
 *    - DirectFile target: Generic `NotFound`
 *    - Track target / "Track not found": `ErrorType::TrackNotFound`
 *    - Audio target / "Audio not found" / NoPlayableAsset: `ErrorType::AudioNotFound`
 *    - Asset target / CasObjectMissing: `ErrorType::AssetNotFound`
 *
 * 3. **Decoder / Engine Execution Errors (HTTP 400 - ErrorType::InvalidValue):**
 *    If the underlying AudioEngine fails to initialize the decoder (corrupted audio headers,
 *    unsupported codecs, truncated bitstreams), it maps to `ErrorType::InvalidValue` to indicate
 *    an unprocessable media resource to the client.
 */
static json api_error_from_playback_error(const PlaybackError &err, PlaybackTargetType type) {
    if (err.code == PlaybackErrorCode::DeviceUnavailable) {
        return ApiResponse::error(Error{ErrorType::DeviceUnavailable, err.message});
    }
    if (err.code == PlaybackErrorCode::InvalidParameter) {
        return ApiResponse::error(Error{ErrorType::InvalidValue, err.message});
    }

    if (type == PlaybackTargetType::DirectFile) {
        if (err.code == PlaybackErrorCode::EngineError) {
            return ApiResponse::error(Error{ErrorType::InvalidValue, err.message});
        }
        return ApiResponse::error(Error{ErrorType::NotFound, err.message});
    }

    if (err.message.find("Track not found") != std::string::npos) {
        return ApiResponse::error(Error{ErrorType::TrackNotFound, err.message});
    }

    if (type == PlaybackTargetType::Asset) {
        if (err.code == PlaybackErrorCode::EngineError) {
            return ApiResponse::error(Error{ErrorType::InvalidValue, err.message});
        }
        return ApiResponse::error(Error{ErrorType::AssetNotFound, err.message});
    }

    switch (err.code) {
        case PlaybackErrorCode::TargetNotFound: {
            if (err.message.find("Audio not found") != std::string::npos || type == PlaybackTargetType::Audio) { // TODO: String matching, Fragile!
                return ApiResponse::error(Error{ErrorType::AudioNotFound, err.message});
            }
            if (type == PlaybackTargetType::Track) {
                return ApiResponse::error(Error{ErrorType::TrackNotFound, err.message});
            }
            return ApiResponse::error(Error{ErrorType::AssetNotFound, err.message});
        }
        case PlaybackErrorCode::NoPlayableAsset: {
            return ApiResponse::error(Error{ErrorType::AudioNotFound, err.message});
        }
        case PlaybackErrorCode::CasObjectMissing: {
            return ApiResponse::error(Error{ErrorType::AssetNotFound, err.message});
        }
        case PlaybackErrorCode::EngineError: {
            return ApiResponse::error(Error{ErrorType::InvalidValue, err.message});
        }
        case PlaybackErrorCode::InvalidParameter: {
            return ApiResponse::error(Error{ErrorType::InvalidValue, err.message});
        }
        case PlaybackErrorCode::Success:
        default: {
            return ApiResponse::error(Error{ErrorType::NotFound, err.message});
        }
    }
}

Router::Router(const std::string &db_path) {
    m_db_context = std::make_unique<SqliteDatabaseContext>(db_path);

    m_album_repo = std::make_unique<SqliteAlbumRepository>(*m_db_context);
    m_artist_repo = std::make_unique<SqliteArtistRepository>(*m_db_context);
    m_asset_repo = std::make_unique<SqliteAssetRepository>(*m_db_context);
    m_audio_repo = std::make_unique<SqliteAudioRepository>(*m_db_context);
    m_image_repo = std::make_unique<SqliteImageRepository>(*m_db_context);
    m_playlist_repo = std::make_unique<SqlitePlaylistRepository>(*m_db_context);
    m_source_data_repo = std::make_unique<SqliteSourceDataRepository>(*m_db_context);
    m_tag_repo = std::make_unique<SqliteTagRepository>(*m_db_context);
    m_text_repo = std::make_unique<SqliteTextRepository>(*m_db_context);
    m_track_repo = std::make_unique<SqliteTrackRepository>(*m_db_context);
    m_work_repo = std::make_unique<SqliteWorkRepository>(*m_db_context);

    m_storage_root = std::filesystem::path(db_path).parent_path().string();

    m_album_controller = std::make_unique<AlbumController>(*m_album_repo);
    m_artist_controller = std::make_unique<ArtistController>(*m_artist_repo);
    m_asset_controller = std::make_unique<AssetController>(*m_asset_repo, m_storage_root);
    m_audio_controller = std::make_unique<AudioController>(*m_audio_repo);
    m_playlist_controller = std::make_unique<PlaylistController>(*m_playlist_repo);
    m_source_data_controller = std::make_unique<SourceDataController>(*m_source_data_repo);
    m_tag_controller = std::make_unique<TagController>(*m_tag_repo);
    m_track_controller = std::make_unique<TrackController>(*m_track_repo);
    m_work_controller = std::make_unique<WorkController>(*m_work_repo);
    m_audio_engine = std::make_unique<AudioEngine>();
    m_text_service = std::make_unique<TextService>(
        *m_db_context,
        *m_asset_repo,
        *m_text_repo,
        m_storage_root);
    m_ingestion_service = std::make_unique<IngestionService>(
        *m_db_context,
        *m_asset_repo,
        *m_audio_repo,
        *m_artist_repo,
        *m_album_repo,
        *m_track_repo,
        m_storage_root,
        m_image_repo.get(),
        m_source_data_repo.get(),
        m_text_service.get());
    m_cover_art_service = std::make_unique<CoverArtService>(
        *m_image_repo,
        *m_track_repo,
        *m_album_repo,
        *m_artist_repo,
        *m_playlist_repo,
        *m_asset_repo,
        m_storage_root);
    m_playback_service = std::make_unique<PlaybackService>(
        m_storage_root,
        *m_audio_engine,
        *m_track_repo,
        *m_audio_repo,
        *m_asset_repo);

    m_configuration_service = std::make_unique<ConfigurationService>(
        *m_db_context, m_storage_root, m_audio_engine.get());

    init_handlers();
}

Router::~Router() = default;

void Router::set_event_callback(std::function<void(const std::string &)> callback) {
    if (m_audio_engine) m_audio_engine->set_event_callback(std::move(callback));
}

AudioEngine &Router::get_audio_engine() {
    return *m_audio_engine;
}

PlaybackService &Router::get_playback_service() {
    return *m_playback_service;
}

ConfigurationService &Router::get_configuration_service() {
    return *m_configuration_service;
}

void Router::init_handlers() {
    // Artist
    m_handlers["CreateArtist"] = [this](const json &p) { return handleCreateArtist(p); };
    m_handlers["UpdateArtist"] = [this](const json &p) { return handleUpdateArtist(p); };
    m_handlers["GetArtist"] = [this](const json &p) { return handleGetArtist(p); };
    m_handlers["ListArtists"] = [this](const json &p) { return handleListArtists(p); };
    m_handlers["GetArtistTracks"] = [this](const json &p) { return handleGetArtistTracks(p); };
    m_handlers["GetArtistAlbums"] = [this](const json &p) { return handleGetArtistAlbums(p); };

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
    m_handlers["GetAlbumTracks"] = [this](const json &p) { return handleGetAlbumTracks(p); };

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
    m_handlers["GetAudioVersions"] = [this](const json &p) { return handleGetAudioVersions(p); };

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
    m_handlers["DeletePlaylist"] = [this](const json &p) { return handleDeletePlaylist(p); };

    // Playlist-Track
    m_handlers["AddPlaylistTrack"] = [this](const json &p) { return handleAddPlaylistTrack(p); };
    m_handlers["RemovePlaylistTrack"] = [this](const json &p) { return handleRemovePlaylistTrack(p); };
    m_handlers["GetPlaylistTracks"] = [this](const json &p) { return handleGetPlaylistTracks(p); };
    m_handlers["ReorderPlaylistTracks"] = [this](const json &p) { return handleReorderPlaylistTracks(p); };

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
    m_handlers["audio.list_devices"] = [this](const json &p) { return handleAudioListDevices(p); };
    m_handlers["audio.set_output_device"] = [this](const json &p) { return handleAudioSetOutputDevice(p); };
    m_handlers["audio.preload_next"] = [this](const json &p) { return handleAudioQueueNext(p); };
    m_handlers["audio.queue_next"] = [this](const json &p) { return handleAudioQueueNext(p); };

    // System Config endpoints
    m_handlers["system.get_config"] = [this](const json &p) { return handleSystemGetConfig(p); };
    m_handlers["system.set_config"] = [this](const json &p) { return handleSystemSetConfig(p); };

    // Tag endpoints
    m_handlers["tag.list"] = [this](const json &p) { return handleTagList(p); };
    m_handlers["tag.create"] = [this](const json &p) { return handleTagCreate(p); };
    m_handlers["tag.delete"] = [this](const json &p) { return handleTagDelete(p); };
    m_handlers["tag.assign"] = [this](const json &p) { return handleTagAssign(p); };
    m_handlers["tag.remove"] = [this](const json &p) { return handleTagRemove(p); };
    m_handlers["tag.get_entity_tags"] = [this](const json &p) { return handleTagGetEntityTags(p); };

    // SourceData endpoints
    m_handlers["source_data.get_by_asset"] = [this](const json &p) { return handleSourceDataGetByAsset(p); };
    m_handlers["source_data.create"] = [this](const json &p) { return handleSourceDataCreate(p); };

    // Text & Lyrics endpoints
    m_handlers["text.save"] = [this](const json &p) { return handleTextSave(p); };
    m_handlers["text.get"] = [this](const json &p) { return handleTextGet(p); };
    m_handlers["text.get_entity_texts"] = [this](const json &p) { return handleTextGetEntityTexts(p); };
    m_handlers["text.unlink"] = [this](const json &p) { return handleTextUnlink(p); };
}


namespace {

constexpr int64_t kIntMin = std::numeric_limits<int>::min();
constexpr int64_t kIntMax = std::numeric_limits<int>::max();
constexpr int64_t kUint32Max = std::numeric_limits<uint32_t>::max();

std::optional<json> validateWorkCompositionYears(const json &params) {
    const json *start_year = JsonHelper::find_value(params, "composition_start_year");
    const json *end_year = JsonHelper::find_value(params, "composition_end_year");
    if (start_year && start_year->is_number() && end_year && end_year->is_number()) {
        if (start_year->get<int>() > end_year->get<int>()) {
            return ApiResponse::error(
                {ErrorType::OutOfRange,
                 "composition_start_year cannot be greater than composition_end_year"});
        }
    }
    return std::nullopt;
}

const std::vector<ValidationRule> &audio_field_rules() {
    static const std::vector<ValidationRule> rules = {
        {"pcm_hash", Type::String, true, StringFormat::SingleLineText},
        {.key = "parent_hash", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
        {.key = "quality_score", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kIntMax},
        {.key = "bit_depth", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kIntMax},
        {.key = "sample_rate", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kIntMax},
        {.key = "channels", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kIntMax},
        {.key = "duration", .expected_type = Type::Number, .is_required = false, .min_number = 0.0},
        {"integrated_loudness", Type::Number, false},
        {"true_peak", Type::Number, false}};
    return rules;
}

template <typename T>
void populate_artist_fields(T &dst, const json &params) {
    JsonHelper::assign_if_present(dst.name, params, "name");
    JsonHelper::assign_if_present(dst.musicbrainz_id, params, "musicbrainz_id");
    JsonHelper::assign_if_present(dst.ytm_id, params, "ytm_id");
    JsonHelper::assign_if_present(dst.spotify_id, params, "spotify_id");
}

template <typename T>
void populate_track_fields(T &dst, const json &params) {
    JsonHelper::assign_if_present(dst.pcm_hash, params, "pcm_hash");
    JsonHelper::assign_if_present(dst.work_id, params, "work_id");
    JsonHelper::assign_if_present(dst.title, params, "title");
    JsonHelper::assign_if_present(dst.recording_year, params, "recording_year");
    JsonHelper::assign_if_present(dst.recording_month, params, "recording_month");
    JsonHelper::assign_if_present(dst.recording_day, params, "recording_day");
    JsonHelper::assign_if_present(dst.recording_location, params, "recording_location");
    JsonHelper::assign_if_present(dst.duration, params, "duration");
    JsonHelper::assign_if_present(dst.isrc, params, "isrc");
    JsonHelper::assign_if_present(dst.musicbrainz_id, params, "musicbrainz_id");
    JsonHelper::assign_if_present(dst.ytm_id, params, "ytm_id");
    JsonHelper::assign_if_present(dst.spotify_id, params, "spotify_id");
}

template <typename T>
void populate_album_fields(T &dst, const json &params) {
    JsonHelper::assign_if_present(dst.title, params, "title");
    JsonHelper::assign_if_present(dst.release_year, params, "release_year");
    JsonHelper::assign_if_present(dst.release_month, params, "release_month");
    JsonHelper::assign_if_present(dst.release_day, params, "release_day");
}

template <typename T>
void populate_asset_fields(T &dst, const json &params) {
    JsonHelper::assign_if_present(dst.file_hash, params, "file_hash");
    JsonHelper::assign_if_present(dst.mime_type, params, "mime_type");
    JsonHelper::assign_if_present(dst.asset_type, params, "asset_type");
    JsonHelper::assign_if_present(dst.file_size, params, "file_size");
}

template <typename T>
void populate_audio_fields(T &dst, const json &params) {
    JsonHelper::assign_if_present(dst.pcm_hash, params, "pcm_hash");
    JsonHelper::assign_if_present(dst.parent_hash, params, "parent_hash");
    JsonHelper::assign_if_present(dst.quality_score, params, "quality_score");
    JsonHelper::assign_if_present(dst.bit_depth, params, "bit_depth");
    JsonHelper::assign_if_present(dst.sample_rate, params, "sample_rate");
    JsonHelper::assign_if_present(dst.channels, params, "channels");
    JsonHelper::assign_if_present(dst.duration, params, "duration");
    JsonHelper::assign_if_present(dst.integrated_loudness, params, "integrated_loudness");
    JsonHelper::assign_if_present(dst.true_peak, params, "true_peak");
}

template <typename T>
void populate_work_fields(T &dst, const json &params) {
    JsonHelper::assign_if_present(dst.title, params, "title");
    JsonHelper::assign_if_present(dst.composition_start_year, params, "composition_start_year");
    JsonHelper::assign_if_present(dst.composition_end_year, params, "composition_end_year");
    JsonHelper::assign_if_present(dst.composition_date_text, params, "composition_date_text");
    JsonHelper::assign_if_present(dst.iswc, params, "iswc");
    JsonHelper::assign_if_present(dst.musicbrainz_id, params, "musicbrainz_id");
}

std::optional<json> reject_empty_string_keys(
    const json &p,
    std::initializer_list<std::pair<std::string_view, std::string_view>> key_error_labels) {
    for (const auto &[key, label] : key_error_labels) {
        if (const json *val = JsonHelper::find_value(p, key);
            val && val->is_string() && val->get_ref<const std::string &>().empty()) {
            return ApiResponse::error(
                {ErrorType::MissingParameter, std::string(label) + " cannot be empty"});
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
    if (auto err = JsonValidator::validate(
            params, {{.key = "offset", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kIntMax},
                     {.key = "limit", .expected_type = Type::Integer, .is_required = false, .min_int = 1, .max_int = 100},
                     {"search", Type::String, false, StringFormat::SingleLineText}});
        err) {
        return tl::unexpected(*err);
    }

    int offset = JsonHelper::get_safe<int>(params, "offset", 0);
    int limit = JsonHelper::get_safe<int>(params, "limit", 20);

    std::optional<std::string> search = std::nullopt;
    if (auto opt_s = JsonHelper::get_optional<std::string>(params, "search")) {
        size_t start = opt_s->find_first_not_of(' ');
        if (start != std::string::npos) {
            size_t end = opt_s->find_last_not_of(' ');
            search = opt_s->substr(start, end - start + 1);
        }
    }

    return PaginationParams{offset, limit, search};
}

} // namespace

// --- Artist Handlers ---

json Router::handleCreateArtist(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"name", Type::String, true, StringFormat::SingleLineText},
                                                    {"musicbrainz_id", Type::String, false, StringFormat::SingleLineText},
                                                    {"ytm_id", Type::String, false, StringFormat::SingleLineText},
                                                    {"spotify_id", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    Artist artist;
    populate_artist_fields(artist, params);
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
    if (auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"name", Type::String, false, StringFormat::SingleLineText},
                                                    {"musicbrainz_id", Type::String, false, StringFormat::SingleLineText},
                                                    {"ytm_id", Type::String, false, StringFormat::SingleLineText},
                                                    {"spotify_id", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    ArtistUpdate update_data;
    update_data.id = params["id"].get<std::string>();
    populate_artist_fields(update_data, params);
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
    if (auto err = JsonValidator::validate(params,
                                           {{"id", Type::String, true, StringFormat::UUID}});
        err) return *err;

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

json Router::handleGetArtistTracks(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"artist_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    auto res = m_track_controller->get_by_artist(params["artist_id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    if (res.error().find("Artist not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::ArtistNotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetArtistAlbums(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"artist_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    auto res = m_album_controller->get_by_artist(params["artist_id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    if (res.error().find("Artist not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::ArtistNotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Track Handlers ---

json Router::handleCreateTrack(const json &params) {
    // TODO: Once audio file upload or decoding is implemented, calculate pcm_hash
    // on the server side from the audio payload to prevent client-side manipulation/attacks.
    if (auto err = JsonValidator::validate(params, {{"pcm_hash", Type::String, true, StringFormat::SingleLineText},
                                                    {"title", Type::String, false, StringFormat::SingleLineText},
                                                    {"work_id", Type::String, false, StringFormat::UUID},
                                                    {"recording_year", Type::Year, false},
                                                    {"recording_month", Type::Month, false},
                                                    {"recording_day", Type::Day, false},
                                                    {"recording_location", Type::String, false, StringFormat::SingleLineText},
                                                    {.key = "duration", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kUint32Max},
                                                    {"isrc", Type::String, false, StringFormat::SingleLineText},
                                                    {"musicbrainz_id", Type::String, false, StringFormat::SingleLineText},
                                                    {"ytm_id", Type::String, false, StringFormat::SingleLineText},
                                                    {"spotify_id", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    Track track;
    populate_track_fields(track, params);
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
    if (auto err = JsonValidator::validate(params,
                                           {{"id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    auto res = m_track_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::TrackNotFound, res.error()});
}

json Router::handleUpdateTrack(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"pcm_hash", Type::String, false, StringFormat::SingleLineText},
                                                    {"title", Type::String, false, StringFormat::SingleLineText},
                                                    {"work_id", Type::String, false, StringFormat::UUID},
                                                    {"recording_year", Type::Year, false},
                                                    {"recording_month", Type::Month, false},
                                                    {"recording_day", Type::Day, false},
                                                    {"recording_location", Type::String, false, StringFormat::SingleLineText},
                                                    {.key = "duration", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kUint32Max},
                                                    {"isrc", Type::String, false, StringFormat::SingleLineText},
                                                    {"musicbrainz_id", Type::String, false, StringFormat::SingleLineText},
                                                    {"ytm_id", Type::String, false, StringFormat::SingleLineText},
                                                    {"spotify_id", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    TrackUpdate update_data;
    update_data.id = params["id"].get<std::string>();
    populate_track_fields(update_data, params);
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

/**
 * @brief Handles 'ImportTrack' to ingest an audio file into CAS and create Track/Artist/Album metadata.
 *
 * UI Usage Notes:
 * - Pre-import toggle: Pass `"import_embedded_lyrics": true|false` (defaults to `true`) to match the UI
 *   import dialog checkbox for whether embedded audio tag lyrics should be imported automatically.
 * - Sibling `.lrc` sidecar files on disk are intentionally NOT scanned by Core; UI should handle sidecar
 *   discovery/encoding conversion and call `text.save` after user confirmation.
 * - Post-import undo: `data.imported_texts` lists every `Text` metadata record auto-attached during import
 *   (may be empty). UI can display a toast/banner and let the user remove any unwanted item via `text.unlink`.
 */
json Router::handleImportTrack(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"source_path", Type::String, true, StringFormat::SingleLineText},
                     {.key = "source_type", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "note", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::MultilineText, .allow_empty = true},
                     {"import_embedded_lyrics", Type::Boolean, false}});
        err) return *err;

    TrackImportRequest req;
    req.source_path = params["source_path"].get<std::string>();
    req.source_type = JsonHelper::get_safe<std::string>(params, "source_type", "");
    req.note = JsonHelper::get_safe<std::string>(params, "note", "");
    req.import_embedded_lyrics = JsonHelper::get_safe<bool>(params, "import_embedded_lyrics", true);

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

    json imported_texts_json = json::array();
    for (const auto &t : val.imported_texts) {
        imported_texts_json.push_back(t);
    }
    response_data["imported_texts"] = std::move(imported_texts_json);

    return ApiResponse::success(response_data);
}

// --- Album Handlers ---

json Router::handleCreateAlbum(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"title", Type::String, true, StringFormat::SingleLineText},
                                                    {"release_year", Type::Year, false},
                                                    {"release_month", Type::Month, false},
                                                    {"release_day", Type::Day, false}});
        err) return *err;

    Album album;
    populate_album_fields(album, params);
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
    if (auto err = JsonValidator::validate(params,
                                           {{"id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    auto res = m_album_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::AlbumNotFound, res.error()});
}

json Router::handleUpdateAlbum(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"title", Type::String, false, StringFormat::SingleLineText},
                                                    {"release_year", Type::Year, false},
                                                    {"release_month", Type::Month, false},
                                                    {"release_day", Type::Day, false}});
        err) return *err;

    AlbumUpdate update_data;
    update_data.id = params["id"].get<std::string>();
    populate_album_fields(update_data, params);
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

json Router::handleGetAlbumTracks(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"album_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    auto res = m_track_controller->get_by_album(params["album_id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    if (res.error().find("Album not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::AlbumNotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Asset Handlers ---

json Router::handleCreateAsset(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"file_hash", Type::String, true, StringFormat::SingleLineText},
                     {"pcm_hash", Type::String, false, StringFormat::SingleLineText},
                     {.key = "mime_type", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "asset_type", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "file_size", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kIntMax}});
        err) return *err;

    Asset asset;
    populate_asset_fields(asset, params);

    // When a `pcm_hash` is provided, link this physical file asset to the logical audio entity
    // via the Audio_Asset junction table within an atomic transaction.
    if (auto pcm_hash = JsonHelper::get_optional<std::string>(params, "pcm_hash")) {
        Audio audio;
        audio.pcm_hash = *pcm_hash;
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
    if (auto err = JsonValidator::validate(params,
                                           {{"file_hash", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

    auto res = m_asset_controller->get(params["file_hash"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::AssetNotFound, res.error()});
}

json Router::handleUpdateAsset(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"file_hash", Type::String, true, StringFormat::SingleLineText},
                     {.key = "mime_type", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "asset_type", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "file_size", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = kIntMax}});
        err) return *err;

    AssetUpdate update_data;
    populate_asset_fields(update_data, params);
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
    if (auto err = JsonValidator::validate(
            params, {{"source_path", Type::String, true, StringFormat::SingleLineText},
                     {.key = "source_type", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "note", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::MultilineText, .allow_empty = true}});
        err) return *err;

    std::string source_type = JsonHelper::get_safe<std::string>(params, "source_type", "");
    std::string note = JsonHelper::get_safe<std::string>(params, "note", "");

    auto res = m_ingestion_service->ingest_asset(params["source_path"].get<std::string>(), source_type, note);
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

/**
 * @brief Handles 'GetResourcePath' to resolve the physical disk file path of an audio resource.
 *
 * Implements polymorphic Target resolution and fail-fast defensive parameter validation:
 * 1. Schema Validation:
 *    Enforces UUID format if track_id is present, and validates expected data types.
 * 2. Option Extraction:
 *    Parses `pin_version` (controls Star Topology arbitration vs pinned PCM playback)
 *    and format preference (`preferred_format` or legacy `format`).
 * 3. Polymorphic Target Extraction & Boundary Defense:
 *    Inspects parameters in priority order (`file_hash` -> Asset, `track_id` -> Track, `pcm_hash` -> Audio).
 *    Explicitly validates non-nullity, string type, and non-emptiness. Rejecting null or empty
 *    strings prevents silent fallthroughs or database scans against uninitialized keys.
 * 4. Resolution & Error Mapping:
 *    Delegates resolution to `PlaybackService::resolve` and maps domain errors to API status codes
 *    via `api_error_from_playback_error`.
 */
json Router::handleGetResourcePath(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"track_id", Type::String, false, StringFormat::UUID},
                                                    {"file_hash", Type::String, false, StringFormat::SingleLineText},
                                                    {"pcm_hash", Type::String, false, StringFormat::SingleLineText},
                                                    {"preferred_format", Type::String, false, StringFormat::SingleLineText},
                                                    {"format", Type::String, false, StringFormat::SingleLineText},
                                                    {"pin_version", Type::Boolean, false}});
        err) return *err;

    PlaybackTarget target;
    PlaybackOptions options;
    options.pin_version = JsonHelper::get_safe<bool>(params, "pin_version", false);
    options.preferred_format = JsonHelper::get_first_optional<std::string>(params, {"preferred_format", "format"});

    if (auto file_hash = JsonHelper::get_optional<std::string>(params, "file_hash")) {
        target = PlaybackTarget::from_asset(*file_hash);
    } else if (auto track_id = JsonHelper::get_optional<std::string>(params, "track_id")) {
        target = PlaybackTarget::from_track(*track_id);
    } else if (auto pcm_hash = JsonHelper::get_optional<std::string>(params, "pcm_hash")) {
        target = PlaybackTarget::from_audio(*pcm_hash);
    } else {
        return ApiResponse::error({ErrorType::MissingParameter, "Must provide track_id, pcm_hash, or file_hash"});
    }

    auto resolved_res = m_playback_service->resolve(target, options);
    if (!resolved_res) {
        return api_error_from_playback_error(resolved_res.error(), target.type);
    }

    json response_data;
    response_data["path"] = resolved_res->file_path;
    response_data["mime_type"] = resolved_res->mime_type;

    return ApiResponse::success(response_data);
}

// --- Audio Handlers ---

json Router::handleCreateAudio(const json &params) {
    if (auto err = JsonValidator::validate(params, audio_field_rules()); err)
        return *err;

    Audio audio;
    populate_audio_fields(audio, params);

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
    if (auto err = JsonValidator::validate(params,
                                           {{"pcm_hash", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

    auto res = m_audio_controller->get(params["pcm_hash"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::AudioNotFound, res.error()});
}

json Router::handleUpdateAudio(const json &params) {
    if (auto err = JsonValidator::validate(params, audio_field_rules()); err)
        return *err;

    AudioUpdate update_data;
    populate_audio_fields(update_data, params);
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

/**
 * @brief Handles 'GetAudioVersions' to retrieve the Star Topology audio version family with linked Assets.
 *
 * UI Usage Notes:
 * - Exclusive lookup modes (strict XOR): provide EITHER `pcm_hash` OR `track_id` (not both).
 * - Returns an array of `Audio` objects ordered with the Master Audio first (`parent_hash == ""`),
 *   followed by derived versions, each hydrated with its associated `assets` array.
 */
json Router::handleGetAudioVersions(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"track_id", Type::String, false, StringFormat::UUID},
                     {"pcm_hash", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    const bool has_track = JsonHelper::has_value(params, "track_id");
    const bool has_pcm = JsonHelper::has_value(params, "pcm_hash");
    if (!has_track && !has_pcm) {
        return ApiResponse::error({ErrorType::MissingParameter, "Must provide either 'pcm_hash' or 'track_id'."});
    }
    if (has_track && has_pcm) {
        return ApiResponse::error({ErrorType::InvalidValue, "Cannot provide both 'pcm_hash' and 'track_id'."});
    }

    std::string pcm_hash;
    if (has_track) {
        auto track_res = m_track_controller->get(params["track_id"].get<std::string>());
        if (!track_res) {
            if (track_res.error().find("Track not found") != std::string::npos) {
                return ApiResponse::error({ErrorType::TrackNotFound, track_res.error()});
            }
            return ApiResponse::error({ErrorType::DatabaseError, track_res.error()});
        }
        if (track_res->pcm_hash.empty()) {
            return ApiResponse::error({ErrorType::AudioNotFound, "Track has no associated audio."});
        }
        pcm_hash = track_res->pcm_hash;
    } else {
        const std::string raw_hash = params["pcm_hash"].get<std::string>();
        const size_t start = raw_hash.find_first_not_of(" \t\r\n");
        if (start == std::string::npos) {
            return ApiResponse::error({ErrorType::InvalidValue, "Value of key 'pcm_hash' should not be blank."});
        }
        const size_t end = raw_hash.find_last_not_of(" \t\r\n");
        pcm_hash = raw_hash.substr(start, end - start + 1);
    }

    auto res = m_audio_controller->get_related_versions(pcm_hash);
    if (res) {
        return ApiResponse::success(res.value());
    }
    if (res.error().find("Audio not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::AudioNotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Work Handlers ---

json Router::handleCreateWork(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"title", Type::String, true, StringFormat::SingleLineText},
                                                    {"composition_start_year", Type::Year, false},
                                                    {"composition_end_year", Type::Year, false},
                                                    {"composition_date_text", Type::String, false, StringFormat::SingleLineText},
                                                    {"iswc", Type::String, false, StringFormat::SingleLineText},
                                                    {"musicbrainz_id", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    if (auto year_err = validateWorkCompositionYears(params))
        return *year_err;

    Work work;
    populate_work_fields(work, params);
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
    if (auto err = JsonValidator::validate(params,
                                           {{"id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    auto res = m_work_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::WorkNotFound, res.error()});
}

json Router::handleUpdateWork(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"id", Type::String, true, StringFormat::UUID},
                                                    {"title", Type::String, false, StringFormat::SingleLineText},
                                                    {"composition_start_year", Type::Year, false},
                                                    {"composition_end_year", Type::Year, false},
                                                    {"composition_date_text", Type::String, false, StringFormat::SingleLineText},
                                                    {"iswc", Type::String, false, StringFormat::SingleLineText},
                                                    {"musicbrainz_id", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    if (auto year_err = validateWorkCompositionYears(params))
        return *year_err;

    bool has_start = JsonHelper::has_value(params, "composition_start_year");
    if (bool has_end = JsonHelper::has_value(params, "composition_end_year");
        (has_start && !has_end) || (!has_start && has_end)) {
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

    WorkUpdate update_data;
    update_data.id = params["id"].get<std::string>();
    populate_work_fields(update_data, params);
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
    if (auto err = JsonValidator::validate(params, {{"track_id", Type::String, true, StringFormat::UUID},
                                                    {"artist_id", Type::String, true, StringFormat::UUID},
                                                    {"role", Type::String, true, StringFormat::SingleLineText},
                                                    {.key = "position", .expected_type = Type::Integer, .is_required = false, .min_int = kIntMin, .max_int = kIntMax}});
        err) return *err;

    std::string role_str = params["role"].get<std::string>();
    auto role_opt = ArtistRoleMapper::from_string(role_str);
    if (!role_opt) {
        return ApiResponse::error({ErrorType::InvalidValue, "Invalid artist role: " + role_str});
    }

    TrackArtistParams track_artist;
    track_artist.track_id = params["track_id"].get<std::string>();
    track_artist.artist_id = params["artist_id"].get<std::string>();
    track_artist.role = *role_opt;
    track_artist.position = JsonHelper::get_optional<int>(params, "position");
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
    if (auto err = JsonValidator::validate(params, {{"track_id", Type::String, true, StringFormat::UUID},
                                                    {"artist_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    TrackArtistParams track_artist;
    track_artist.track_id = params["track_id"].get<std::string>();
    track_artist.artist_id = params["artist_id"].get<std::string>();
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
    if (auto err = JsonValidator::validate(params, {{"track_id", Type::String, true, StringFormat::UUID},
                                                    {"artist_id", Type::String, true, StringFormat::UUID},
                                                    {"role", Type::String, false, StringFormat::SingleLineText},
                                                    {.key = "position", .expected_type = Type::Integer, .is_required = false, .min_int = kIntMin, .max_int = kIntMax}});
        err) return *err;

    std::optional<ArtistRole> role_opt;
    if (auto role_str = JsonHelper::get_optional<std::string>(params, "role")) {
        role_opt = ArtistRoleMapper::from_string(*role_str);
        if (!role_opt) {
            return ApiResponse::error({ErrorType::InvalidValue, "Invalid artist role: " + *role_str});
        }
    }

    auto pos_opt = JsonHelper::get_optional<int>(params, "position");
    if (!role_opt.has_value() && !pos_opt.has_value()) {
        return ApiResponse::error({ErrorType::InvalidValue, "No fields provided to update."});
    }

    TrackArtistParams track_artist;
    track_artist.track_id = params["track_id"].get<std::string>();
    track_artist.artist_id = params["artist_id"].get<std::string>();
    track_artist.role = role_opt;
    track_artist.position = pos_opt;
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
    if (auto err = JsonValidator::validate(
            params, {{"title", Type::String, true, StringFormat::SingleLineText},
                     {.key = "description", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::MultilineText, .allow_empty = true}});
        err) return *err;

    Playlist playlist;
    playlist.title = params["title"].get<std::string>();
    playlist.description = JsonHelper::get_optional<std::string>(params, "description");
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
    if (auto err = JsonValidator::validate(params,
                                           {{"id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    auto res = m_playlist_controller->get(params["id"].get<std::string>());
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::PlaylistNotFound, res.error()});
}

json Router::handleUpdatePlaylist(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"id", Type::String, true, StringFormat::UUID},
                     {"title", Type::String, false, StringFormat::SingleLineText},
                     {.key = "description", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::MultilineText, .allow_empty = true}});
        err) return *err;

    PlaylistUpdate update_data;
    update_data.id = params["id"].get<std::string>();
    update_data.title = JsonHelper::get_optional<std::string>(params, "title");
    update_data.description = JsonHelper::get_optional<std::string>(params, "description");
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

json Router::handleDeletePlaylist(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"id", Type::String, false, StringFormat::UUID},
                     {"playlist_id", Type::String, false, StringFormat::UUID}});
        err) return *err;

    auto id_opt = JsonHelper::get_optional<std::string>(params, "id");
    auto playlist_id_opt = JsonHelper::get_optional<std::string>(params, "playlist_id");
    if (!id_opt && !playlist_id_opt) {
        return ApiResponse::error({ErrorType::MissingParameter, "Missing 'id' or 'playlist_id' parameter"});
    }
    if (id_opt && playlist_id_opt && *id_opt != *playlist_id_opt) {
        return ApiResponse::error({ErrorType::InvalidValue, "Conflicting 'id' and 'playlist_id' parameters"});
    }
    const std::string &target_id = id_opt ? *id_opt : *playlist_id_opt;

    auto res = m_playlist_controller->delete_playlist(target_id);
    if (res) {
        json response = ApiResponse::success({{"id", target_id}});
        response["message"] = "Delete Playlist success.";
        return response;
    }
    if (res.error().find("Playlist not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::PlaylistNotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleAddPlaylistTrack(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"playlist_id", Type::String, true, StringFormat::UUID},
                                                    {"track_id", Type::String, true, StringFormat::UUID},
                                                    {.key = "position", .expected_type = Type::Integer, .is_required = false, .min_int = kIntMin, .max_int = kIntMax}});
        err) return *err;

    auto pos_opt = JsonHelper::get_optional<int>(params, "position");
    auto res = m_playlist_controller->add_track(params["playlist_id"], params["track_id"], pos_opt);
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
    if (auto err = JsonValidator::validate(params, {{"playlist_id", Type::String, true, StringFormat::UUID},
                                                    {"track_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

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
    if (auto err = JsonValidator::validate(params, {{"id", Type::String, false, StringFormat::UUID},
                                                    {"playlist_id", Type::String, false, StringFormat::UUID}});
        err) return *err;

    auto playlist_id = JsonHelper::get_first_optional<std::string>(params, {"id", "playlist_id"});
    if (!playlist_id) {
        return ApiResponse::error({ErrorType::MissingParameter, "Missing 'id' or 'playlist_id' parameter"});
    }

    auto tracks = m_playlist_controller->get_tracks(*playlist_id);
    if (tracks) return ApiResponse::success(tracks.value());

    return ApiResponse::error({ErrorType::DatabaseError, tracks.error()});
}

/**
 * @brief Handles 'ReorderPlaylistTracks' to atomically reorder tracks in a playlist.
 *
 * UI Usage Notes:
 * - Index semantics: `old_index` and `new_index` are 0-based destination indices in `[0, count - 1]`
 *   (e.g., moving index `0` to `2` on `[A, B, C]` yields `[B, C, A]`).
 * - Flutter `ReorderableListView.onReorder(oldIndex, newIndex)` passes `newIndex` relative to the
 *   pre-removal list (so dragging down passes `newIndex == count` at the end). UI callers MUST apply
 *   `if (oldIndex < newIndex) newIndex -= 1;` before calling this RPC, because `new_index >= count`
 *   is rejected with HTTP 400 `OutOfRange`.
 */
json Router::handleReorderPlaylistTracks(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"playlist_id", Type::String, true, StringFormat::UUID},
                     {.key = "old_index", .expected_type = Type::Integer, .is_required = true, .min_int = 0, .max_int = kIntMax},
                     {.key = "new_index", .expected_type = Type::Integer, .is_required = true, .min_int = 0, .max_int = kIntMax}});
        err) return *err;

    const std::string playlist_id = params["playlist_id"].get<std::string>();
    const int old_index = params["old_index"].get<int>();
    const int new_index = params["new_index"].get<int>();

    auto res = m_playlist_controller->reorder_tracks(playlist_id, old_index, new_index);
    if (res) {
        json response = ApiResponse::success({{"playlist_id", playlist_id}, {"track_ids", res.value()}});
        response["message"] = "Reorder PlaylistTracks success.";
        return response;
    }

    const std::string &err_msg = res.error();
    if (err_msg.find("Playlist not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::PlaylistNotFound, err_msg});
    }
    if (err_msg.find("Index out of range") != std::string::npos) {
        return ApiResponse::error({ErrorType::OutOfRange, err_msg});
    }
    return ApiResponse::error({ErrorType::DatabaseError, err_msg});
}

json Router::handleGetTracksByTitle(const json &params) {
    if (auto err = JsonValidator::validate(params,
                                           {{"title", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

    auto res = m_track_controller->get_by_title(params["title"].get<std::string>());
    if (res) return ApiResponse::success(res.value());

    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetArtistsByName(const json &params) {
    if (auto err = JsonValidator::validate(params,
                                           {{"name", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

    auto res = m_artist_controller->get_by_name(params["name"].get<std::string>());
    if (res) return ApiResponse::success(res.value());

    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetAlbumsByTitle(const json &params) {
    if (auto err = JsonValidator::validate(params,
                                           {{"title", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

    auto res = m_album_controller->get_by_title(params["title"].get<std::string>());
    if (res) return ApiResponse::success(res.value());
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetWorksByTitle(const json &params) {
    if (auto err = JsonValidator::validate(params,
                                           {{"title", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

    auto res = m_work_controller->get_by_title(params["title"].get<std::string>());
    if (res) return ApiResponse::success(res.value());

    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleGetPlaylistsByTitle(const json &params) {
    if (auto err = JsonValidator::validate(params,
                                           {{"title", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

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
    if (auto err = JsonValidator::validate(params,
                                           {{"album_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

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
    if (auto err = JsonValidator::validate(params,
                                           {{"track_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

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
    if (auto err = JsonValidator::validate(
            p, {{"start_position", Type::Number, false},
                {"start_position_seconds", Type::Number, false},
                {"preferred_format", Type::String, false, StringFormat::SingleLineText},
                {"format", Type::String, false, StringFormat::SingleLineText},
                {"pin_version", Type::Boolean, false},
                {.key = "file_path", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                {.key = "file_hash", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                {.key = "asset_id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                {.key = "track_id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::UUID, .allow_empty = true},
                {.key = "id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::UUID, .allow_empty = true},
                {.key = "pcm_hash", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                {.key = "audio_id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true}});
        err) return *err;

    if (auto empty_err = reject_empty_string_keys(p, {{"file_path", "file_path"},
                                                      {"file_hash", "file_hash"},
                                                      {"asset_id", "file_hash"},
                                                      {"track_id", "track_id"},
                                                      {"id", "track_id"},
                                                      {"pcm_hash", "pcm_hash"},
                                                      {"audio_id", "pcm_hash"}})) {
        return *empty_err;
    }

    PlaybackTarget target;
    PlaybackOptions options;
    if (auto start_pos = JsonHelper::get_first_optional<double>(p, {"start_position", "start_position_seconds"})) {
        options.start_position_seconds = *start_pos;
    }
    options.preferred_format = JsonHelper::get_first_optional<std::string>(p, {"preferred_format", "format"});
    options.pin_version = JsonHelper::get_safe<bool>(p, "pin_version", false);

    if (auto file_path = JsonHelper::get_optional<std::string>(p, "file_path")) {
        std::error_code ec;
        if (!std::filesystem::is_regular_file(*file_path, ec) || ec) {
            return ApiResponse::error(Error{ErrorType::NotFound, "Audio file does not exist on disk: " + *file_path});
        }
        target = PlaybackTarget::from_file(*file_path);
    } else if (auto file_hash = JsonHelper::get_first_optional<std::string>(p, {"file_hash", "asset_id"})) {
        target = PlaybackTarget::from_asset(*file_hash);
    } else if (auto track_id = JsonHelper::get_first_optional<std::string>(p, {"track_id", "id"})) {
        target = PlaybackTarget::from_track(*track_id);
    } else if (auto pcm_hash = JsonHelper::get_first_optional<std::string>(p, {"pcm_hash", "audio_id"})) {
        target = PlaybackTarget::from_audio(*pcm_hash);
    } else {
        return ApiResponse::error(Error{ErrorType::MissingParameter, "Missing 'file_path', 'track_id', 'id', 'asset_id', or 'audio_id' parameter"});
    }

    if (auto play_res = m_playback_service->play(target, options); !play_res) {
        return api_error_from_playback_error(play_res.error(), target.type);
    }

    return ApiResponse::success(m_playback_service->get_state_json());
}

json Router::handleAudioPause(const json &p) {
    (void)p;
    if (!m_playback_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Playback service not available"});
    }
    if (!m_playback_service->pause()) {
        return ApiResponse::error(Error{
            ErrorType::InvalidValue,
            "Cannot pause playback: audio is not playing"});
    }
    return ApiResponse::success(m_playback_service->get_state_json());
}

json Router::handleAudioResume(const json &p) {
    (void)p;
    if (!m_playback_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Playback service not available"});
    }
    if (!m_playback_service->resume()) {
        if (m_audio_engine && m_audio_engine->get_last_error() == AudioEngineError::DeviceUnavailable) {
            return ApiResponse::error(Error{
                ErrorType::DeviceUnavailable,
                "Audio output device is unavailable: " + m_audio_engine->get_output_device()});
        }
        return ApiResponse::error(Error{
            ErrorType::InvalidValue,
            "Cannot resume playback: audio is not paused"});
    }
    return ApiResponse::success(m_playback_service->get_state_json());
}

json Router::handleAudioSeek(const json &p) {
    if (!m_playback_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Playback service not available"});
    }

    const json *pos_val = JsonHelper::find_value(p, "position");
    if (pos_val) {
        if (!pos_val->is_number()) {
            return ApiResponse::error(Error{ErrorType::InvalidValue, "'position' must be a number"});
        }
        if (!std::isfinite(pos_val->get<double>())) {
            return ApiResponse::error(Error{ErrorType::InvalidValue, "'position' must be a finite number"});
        }
    }
    const json *pos_sec_val = JsonHelper::find_value(p, "position_seconds");
    if (pos_sec_val) {
        if (!pos_sec_val->is_number()) {
            return ApiResponse::error(Error{ErrorType::InvalidValue, "'position_seconds' must be a number"});
        }
        if (!std::isfinite(pos_sec_val->get<double>())) {
            return ApiResponse::error(Error{ErrorType::InvalidValue, "'position_seconds' must be a finite number"});
        }
    }
    const json *rel_val = JsonHelper::find_value(p, "relative");
    if (rel_val && !rel_val->is_boolean()) {
        return ApiResponse::error(Error{ErrorType::InvalidValue, "'relative' parameter must be a boolean"});
    }

    auto pos_opt = JsonHelper::get_first_optional<double>(p, {"position", "position_seconds"});
    if (!pos_opt) {
        if (p.contains("position") && !p.contains("position_seconds")) {
            return ApiResponse::error(Error{ErrorType::MissingParameter, "Missing required parameter: position"});
        }
        if (p.contains("position_seconds") && !p.contains("position")) {
            return ApiResponse::error(Error{ErrorType::MissingParameter, "Missing required parameter: position_seconds"});
        }
        return ApiResponse::error(Error{ErrorType::MissingParameter, "Missing required parameter: 'position' or 'position_seconds'"});
    }

    double pos = *pos_opt;
    bool relative = JsonHelper::get_safe<bool>(p, "relative", false);

    if (!m_playback_service->seek(pos, relative)) {
        return ApiResponse::error(Error{
            ErrorType::InvalidValue,
            "Cannot seek playback: no active audio stream"});
    }
    return ApiResponse::success(m_playback_service->get_state_json());
}

json Router::handleAudioStop(const json &p) {
    (void)p;
    m_playback_service->stop();
    return ApiResponse::success(m_playback_service->get_state_json());
}

json Router::handleAudioSetVolume(const json &p) {
    const json *vol_val = JsonHelper::find_value(p, "volume");
    if (!vol_val) {
        return ApiResponse::error(Error{ErrorType::MissingParameter, "Missing required parameter: volume"});
    }
    if (!vol_val->is_number()) {
        return ApiResponse::error(Error{ErrorType::InvalidValue, "Invalid type for parameter 'volume': expected number"});
    }
    double vol = vol_val->get<double>();
    if (m_configuration_service) {
        if (auto res = m_configuration_service->update_config(
                json{{"audio", {{"volume", vol}}}});
            !res) {
            return res.error();
        }
    } else {
        if (std::isnan(vol) || !std::isfinite(vol) || vol < 0.0 || vol > 1.0) {
            return ApiResponse::error(
                {ErrorType::OutOfRange, "audio.volume must be between 0.0 and 1.0"});
        }
        if (m_playback_service) {
            m_playback_service->set_volume(static_cast<float>(vol));
        }
    }
    return ApiResponse::success(m_playback_service->get_state_json());
}

json Router::handleAudioGetState(const json &p) {
    (void)p;
    return ApiResponse::success(m_playback_service->get_state_json());
}

json Router::handleAudioCompareVersions(const json &p) {
    if (auto err = JsonValidator::validate(
            p, {{"preferred_format", Type::String, false, StringFormat::SingleLineText},
                {"format", Type::String, false, StringFormat::SingleLineText},
                {.key = "track_id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::UUID, .allow_empty = true},
                {"pcm_hashes", Type::Array, false}});
        err) return *err;

    PlaybackOptions options;
    options.preferred_format = JsonHelper::get_first_optional<std::string>(p, {"preferred_format", "format"});

    tl::expected<VersionComparisonResult, PlaybackError> cmp_res;
    auto track_id = JsonHelper::get_optional<std::string>(p, "track_id");
    if (track_id && track_id->empty()) {
        return ApiResponse::error({ErrorType::MissingParameter, "track_id cannot be empty"});
    }

    std::vector<std::string> hashes;
    const json *pcm_hashes_val = JsonHelper::find_value(p, "pcm_hashes");
    if (pcm_hashes_val) {
        if (pcm_hashes_val->empty()) {
            return ApiResponse::error({ErrorType::MissingParameter, "pcm_hashes cannot be empty"});
        }
        hashes.reserve(pcm_hashes_val->size());
        for (const auto &item : *pcm_hashes_val) {
            if (!item.is_string()) {
                return ApiResponse::error({ErrorType::InvalidValue, "pcm_hashes items must be strings"});
            }
            const std::string &h = item.get_ref<const std::string &>();
            if (h.empty() || !utils::is_valid_utf8(h) || utils::contains_control_chars(h, false)) {
                return ApiResponse::error({ErrorType::InvalidValue, "pcm_hashes items must be non-empty valid UTF-8 without control characters"});
            }
            hashes.push_back(h);
        }
    }

    if (track_id) {
        cmp_res = m_playback_service->compare_versions(PlaybackTarget::from_track(*track_id), options);
    } else if (pcm_hashes_val) {
        cmp_res = m_playback_service->compare_versions(hashes, options);
    } else {
        return ApiResponse::error({ErrorType::MissingParameter, "Missing 'pcm_hashes' or 'track_id' parameter"});
    }

    if (!cmp_res) {
        PlaybackTargetType target_type = track_id.has_value() ? PlaybackTargetType::Track : PlaybackTargetType::Audio;
        return api_error_from_playback_error(cmp_res.error(), target_type);
    }

    json versions_array = json::array();
    for (const auto &v : cmp_res->versions) {
        json item;
        item["pcm_hash"] = v.pcm_hash;
        item["format"] = v.format;
        item["quality_score"] = v.quality_score;
        item["is_lossless"] = v.is_lossless;
        item["file_size"] = v.file_size;
        item["is_master"] = v.is_master;
        versions_array.push_back(item);
    }

    return ApiResponse::success({{"recommended_master", cmp_res->recommended_master},
                                 {"versions", versions_array}});
}

json Router::handleAudioGetWaveform(const json &p) {
    if (auto err = JsonValidator::validate(
            p, {{.key = "track_id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::UUID, .allow_empty = true},
                {.key = "pcm_hash", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                {.key = "points", .expected_type = Type::Integer, .is_required = false, .min_int = 30, .max_int = 1200},
                {"preferred_format", Type::String, false, StringFormat::SingleLineText},
                {"format", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    uint32_t points = JsonHelper::get_safe<uint32_t>(p, "points", 300);

    if (auto empty_err = reject_empty_string_keys(p, {{"track_id", "track_id"},
                                                      {"pcm_hash", "pcm_hash"}})) {
        return *empty_err;
    }

    std::string pcm_hash;

    if (auto track_id = JsonHelper::get_optional<std::string>(p, "track_id")) {
        auto track_res = m_track_controller->get(*track_id);
        if (!track_res) {
            return ApiResponse::error({ErrorType::TrackNotFound, "Track not found: " + *track_id});
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
    } else if (auto pcm_hash_opt = JsonHelper::get_optional<std::string>(p, "pcm_hash")) {
        pcm_hash = std::move(*pcm_hash_opt);
        // Verify that the requested Audio entity exists before attempting asset resolution and waveform generation.
        if (auto audio_res = m_audio_controller->get(pcm_hash); !audio_res) {
            return ApiResponse::error({ErrorType::AudioNotFound, "Audio not found: " + pcm_hash});
        }
    } else {
        return ApiResponse::error({ErrorType::MissingParameter, "Missing 'pcm_hash' or 'track_id' parameter"});
    }

    PlaybackOptions options;
    options.preferred_format = JsonHelper::get_first_optional<std::string>(p, {"preferred_format", "format"});

    PlaybackTarget target = PlaybackTarget::from_audio(pcm_hash);
    auto resolved_res = m_playback_service->resolve(target, options);
    if (!resolved_res) {
        return api_error_from_playback_error(resolved_res.error(), target.type);
    }

    auto wf_res = WaveformService::get_or_compute_waveform(m_storage_root, pcm_hash, resolved_res->file_path, points);
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
    if (auto err = JsonValidator::validate(params,
                                           {{"artist_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

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
    if (auto err = JsonValidator::validate(params,
                                           {{"playlist_id", Type::String, true, StringFormat::UUID}});
        err) return *err;

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
    if (auto err = JsonValidator::validate(
            params, {{"entity_id", Type::String, true, StringFormat::UUID},
                     {"role", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    if (!m_cover_art_service) {
        return ApiResponse::error(Error{ErrorType::DatabaseError, "Cover art service not available"});
    }

    std::string entity_id = params["entity_id"].get<std::string>();
    std::optional<std::string> role = JsonHelper::get_optional<std::string>(params, "role");

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

json Router::handleAudioListDevices([[maybe_unused]] const json &params) {
    auto devices = m_playback_service->list_devices();
    json data;
    data["devices"] = devices;
    data["current_device_id"] = m_playback_service->get_output_device();
    return ApiResponse::success(data);
}

json Router::handleAudioSetOutputDevice(const json &params) {
    if (auto err = JsonValidator::validate(params,
                                           {{"device_id", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

    std::string device_id = params["device_id"].get<std::string>();

    if (m_configuration_service) {
        if (auto res = m_configuration_service->update_config(
                json{{"audio", {{"output_device_id", device_id}}}});
            !res) {
            return res.error();
        }
    } else if (!m_playback_service->set_output_device(device_id)) {
        return ApiResponse::error({ErrorType::InvalidValue, "Failed to set audio output device: " + device_id});
    }

    json data;
    data["device_id"] = device_id;
    data["success"] = true;
    json response = ApiResponse::success(data);
    response["message"] = "Output device updated successfully.";
    return response;
}

/**
 * @brief Handles 'audio.preload_next' and 'audio.queue_next' to buffer the subsequent track.
 *
 * Implements polymorphic Target resolution and defensive parameter validation:
 * 1. Queue Cancellation Handling:
 *    If parameters are empty, or `file_path` is explicitly null/empty with no other identifiers,
 *    this indicates an explicit command to clear the preload queue.
 *    Delegates to `m_playback_service->clear_preload_next()` and returns `{ "next_file_path": "", "queued": false }`.
 * 2. Option Parsing:
 *    Extracts `pin_version` (to prevent/allow Star Topology auto-arbitration) and format preferences.
 * 3. Polymorphic Target Resolution & Boundary Defense:
 *    - `file_path`: Validates file existence on local storage and creates DirectFile target.
 *    - Backwards-compatibility Aliases: Normalizes `id` -> `track_id`, `audio_id` -> `pcm_hash`,
 *      and `asset_id` -> `file_hash`.
 *    - Defensive validation: Guarantees parameters are valid string types and non-empty.
 *      Empty strings fail-fast with `ErrorType::MissingParameter`.
 * 4. Preload Execution & Error Translation:
 *    Calls `m_playback_service->preload_next(target, options)` and maps any resolution or
 *    engine failure via `api_error_from_playback_error`.
 */
json Router::handleAudioQueueNext(const json &params) {
    if (auto err = JsonValidator::validate(
            params, {{"preferred_format", Type::String, false, StringFormat::SingleLineText},
                     {"format", Type::String, false, StringFormat::SingleLineText},
                     {"pin_version", Type::Boolean, false},
                     {.key = "file_path", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "file_hash", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "asset_id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "track_id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::UUID, .allow_empty = true},
                     {.key = "id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::UUID, .allow_empty = true},
                     {.key = "pcm_hash", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                     {.key = "audio_id", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true}});
        err) return *err;

    const bool has_other_id =
        JsonHelper::has_value(params, "file_hash") || JsonHelper::has_value(params, "asset_id") ||
        JsonHelper::has_value(params, "track_id") || JsonHelper::has_value(params, "id") ||
        JsonHelper::has_value(params, "pcm_hash") || JsonHelper::has_value(params, "audio_id");

    const bool is_clear_file_path =
        params.contains("file_path") &&
        (params["file_path"].is_null() ||
         (params["file_path"].is_string() && params["file_path"].get_ref<const std::string &>().empty()));

    if (params.empty() || (is_clear_file_path && !has_other_id)) {
        m_playback_service->clear_preload_next();
        json data;
        data["next_file_path"] = "";
        data["queued"] = false;
        return ApiResponse::success(data);
    }

    if (auto empty_err = reject_empty_string_keys(params, {{"file_path", "file_path"},
                                                           {"file_hash", "file_hash"},
                                                           {"asset_id", "file_hash"},
                                                           {"track_id", "track_id"},
                                                           {"id", "track_id"},
                                                           {"pcm_hash", "pcm_hash"},
                                                           {"audio_id", "pcm_hash"}})) {
        return *empty_err;
    }

    PlaybackTarget target;
    PlaybackOptions options;
    options.pin_version = JsonHelper::get_safe<bool>(params, "pin_version", false);
    options.preferred_format = JsonHelper::get_first_optional<std::string>(params, {"preferred_format", "format"});

    if (auto file_path = JsonHelper::get_optional<std::string>(params, "file_path")) {
        std::error_code ec;
        if (!std::filesystem::is_regular_file(*file_path, ec) || ec) {
            return ApiResponse::error({ErrorType::NotFound, "Audio file does not exist on disk: " + *file_path});
        }
        target = PlaybackTarget::from_file(*file_path);
    } else if (auto file_hash = JsonHelper::get_first_optional<std::string>(params, {"file_hash", "asset_id"})) {
        target = PlaybackTarget::from_asset(*file_hash);
    } else if (auto track_id = JsonHelper::get_first_optional<std::string>(params, {"track_id", "id"})) {
        target = PlaybackTarget::from_track(*track_id);
    } else if (auto pcm_hash = JsonHelper::get_first_optional<std::string>(params, {"pcm_hash", "audio_id"})) {
        target = PlaybackTarget::from_audio(*pcm_hash);
    } else {
        return ApiResponse::error({ErrorType::MissingParameter, "Missing 'file_path', 'track_id', or 'pcm_hash' parameter"});
    }

    auto preload_res = m_playback_service->preload_next(target, options);
    if (!preload_res) {
        return api_error_from_playback_error(preload_res.error(), target.type);
    }

    json data;
    data["next_file_path"] = preload_res->file_path;
    data["queued"] = true;
    return ApiResponse::success(data);
}

json Router::handleSystemGetConfig([[maybe_unused]] const json &p) {
    if (!m_configuration_service) {
        return ApiResponse::error({ErrorType::DatabaseError, "Configuration service not available"});
    }
    return ApiResponse::success(m_configuration_service->get_config_json());
}

json Router::handleSystemSetConfig(const json &p) {
    if (!m_configuration_service) {
        return ApiResponse::error({ErrorType::DatabaseError, "Configuration service not available"});
    }
    auto res = m_configuration_service->update_config(p);
    if (!res) {
        return res.error();
    }
    return ApiResponse::success(*res);
}

// --- Tag Handlers ---

json Router::handleTagList(const json &params) {
    auto parse_res = parse_pagination(params);
    if (!parse_res) {
        return parse_res.error();
    }
    if (auto cat_err = JsonValidator::validate(params, {{"category", Type::String, false, StringFormat::SingleLineText}});
        cat_err) {
        return *cat_err;
    }

    std::optional<std::string> category = std::nullopt;
    if (auto opt_cat = JsonHelper::get_optional<std::string>(params, "category")) {
        size_t start = opt_cat->find_first_not_of(" \t\r\n");
        if (start == std::string::npos) {
            return ApiResponse::error({ErrorType::InvalidValue, "Value of key 'category' should not be blank."});
        }
        size_t end = opt_cat->find_last_not_of(" \t\r\n");
        category = opt_cat->substr(start, end - start + 1);
    }

    const auto &p = parse_res.value();
    auto res = m_tag_controller->list(p.offset, p.limit, p.search, category);
    if (res) {
        return ApiResponse::success(res.value());
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleTagCreate(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"name", Type::String, true, StringFormat::SingleLineText},
                                                    {"category", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    std::string raw_name = params["name"].get<std::string>();
    size_t name_start = raw_name.find_first_not_of(" \t\r\n");
    if (name_start == std::string::npos) {
        return ApiResponse::error({ErrorType::InvalidValue, "Value of key 'name' should not be blank."});
    }
    size_t name_end = raw_name.find_last_not_of(" \t\r\n");

    Tag tag;
    tag.name = raw_name.substr(name_start, name_end - name_start + 1);
    if (auto opt_cat = JsonHelper::get_optional<std::string>(params, "category")) {
        size_t cat_start = opt_cat->find_first_not_of(" \t\r\n");
        if (cat_start == std::string::npos) {
            return ApiResponse::error({ErrorType::InvalidValue, "Value of key 'category' should not be blank."});
        }
        size_t cat_end = opt_cat->find_last_not_of(" \t\r\n");
        tag.category = opt_cat->substr(cat_start, cat_end - cat_start + 1);
    } else {
        tag.category = "general";
    }

    auto res = m_tag_controller->create(tag);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"] = tag;
        response["message"] = "Create Tag success.";
        return response;
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleTagDelete(const json &params) {
    if (auto err = JsonValidator::validate(params,
                                           {{"id", Type::String, true, StringFormat::UUID}});
        err) return *err;

    std::string id = params["id"].get<std::string>();
    auto res = m_tag_controller->delete_tag(id);
    if (res) {
        json response = ApiResponse::success({{"id", id}});
        response["message"] = "Delete Tag success.";
        return response;
    }
    if (res.error().find("Tag not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::TagNotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

namespace {

tl::expected<std::optional<std::string>, json> parse_optional_tag_entity_type(const json &params) {
    auto opt_type = JsonHelper::get_optional<std::string>(params, "entity_type");
    if (opt_type.has_value()) {
        if (*opt_type != "track" && *opt_type != "album" && *opt_type != "artist" &&
            *opt_type != "work" && *opt_type != "playlist") {
            return tl::unexpected(ApiResponse::error({ErrorType::InvalidValue, "Invalid entity_type: " + *opt_type}));
        }
    }
    return opt_type;
}

} // namespace

json Router::handleTagAssign(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"entity_id", Type::String, true, StringFormat::UUID},
                                                    {"tag_id", Type::String, true, StringFormat::UUID},
                                                    {"entity_type", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    auto entity_type = parse_optional_tag_entity_type(params);
    if (!entity_type) return entity_type.error();

    std::string entity_id = params["entity_id"].get<std::string>();
    std::string tag_id = params["tag_id"].get<std::string>();
    auto res = m_tag_controller->assign_to_entity(entity_id, tag_id, *entity_type);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"] = {{"entity_id", entity_id}, {"tag_id", tag_id}};
        response["message"] = "Assign Tag success.";
        return response;
    }
    std::string err_msg = res.error();
    if (err_msg.find("Entity not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::NotFound, err_msg});
    }
    if (err_msg.find("Tag not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::TagNotFound, err_msg});
    }
    return ApiResponse::error({ErrorType::DatabaseError, err_msg});
}

json Router::handleTagRemove(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"entity_id", Type::String, true, StringFormat::UUID},
                                                    {"tag_id", Type::String, true, StringFormat::UUID},
                                                    {"entity_type", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    auto entity_type = parse_optional_tag_entity_type(params);
    if (!entity_type) return entity_type.error();

    std::string entity_id = params["entity_id"].get<std::string>();
    std::string tag_id = params["tag_id"].get<std::string>();
    auto res = m_tag_controller->remove_from_entity(entity_id, tag_id, *entity_type);
    if (res) {
        json response = ApiResponse::success({{"entity_id", entity_id}, {"tag_id", tag_id}});
        response["message"] = "Remove Tag success.";
        return response;
    }
    std::string err_msg = res.error();
    if (err_msg.find("Entity not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::NotFound, err_msg});
    }
    if (err_msg.find("Relation not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::RelationNotFound, "Relation between Entity and Tag not found."});
    }
    return ApiResponse::error({ErrorType::DatabaseError, err_msg});
}

json Router::handleTagGetEntityTags(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"entity_id", Type::String, true, StringFormat::UUID},
                                                    {"entity_type", Type::String, false, StringFormat::SingleLineText}});
        err) return *err;

    auto entity_type = parse_optional_tag_entity_type(params);
    if (!entity_type) return entity_type.error();

    std::string entity_id = params["entity_id"].get<std::string>();
    auto res = m_tag_controller->get_entity_tags(entity_id, *entity_type);
    if (res) {
        return ApiResponse::success(res.value());
    }
    if (res.error().find("Entity not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::NotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- SourceData Handlers ---

json Router::handleSourceDataGetByAsset(const json &params) {
    if (auto err = JsonValidator::validate(params,
                                           {{"file_hash", Type::String, true, StringFormat::SingleLineText}});
        err) return *err;

    // Input string post processing to remove leading/trailing " \t\r\n"
    std::string raw_hash = params["file_hash"].get<std::string>();
    size_t start = raw_hash.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) {
        return ApiResponse::error({ErrorType::InvalidValue, "Value of key 'file_hash' should not be blank."});
    }
    size_t end = raw_hash.find_last_not_of(" \t\r\n");
    std::string file_hash = raw_hash.substr(start, end - start + 1);
    //


    // Call & response
    auto res = m_source_data_controller->get_by_asset(file_hash);
    if (res) {
        return ApiResponse::success(res.value());
    }
    if (res.error().find("Asset not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::AssetNotFound, res.error()});
    }
    if (res.error().find("SourceData not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::NotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

json Router::handleSourceDataCreate(const json &params) {
    if (auto err = JsonValidator::validate(
            params,
            {{"file_hash", Type::String, true, StringFormat::SingleLineText},
             {.key = "source_type", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
             {.key = "original_path", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
             {.key = "note", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::MultilineText, .allow_empty = true}});
        err) return *err;

    // Input string post processing to remove leading/trailing " \t\r\n"
    std::string raw_hash = params["file_hash"].get<std::string>();
    size_t hash_start = raw_hash.find_first_not_of(" \t\r\n");
    if (hash_start == std::string::npos) {
        return ApiResponse::error({ErrorType::InvalidValue, "Value of key 'file_hash' should not be blank."});
    }
    size_t hash_end = raw_hash.find_last_not_of(" \t\r\n");
    //


    // prepare SourceData source_data
    SourceData source_data;
    source_data.file_hash = raw_hash.substr(hash_start, hash_end - hash_start + 1);
    source_data.source_type = JsonHelper::get_safe<std::string>(params, "source_type", "");
    source_data.original_path = JsonHelper::get_safe<std::string>(params, "original_path", "");
    source_data.note = JsonHelper::get_safe<std::string>(params, "note", "");
    //


    // Call & response
    auto res = m_source_data_controller->create(source_data);
    if (res) {
        json response;
        response["code"] = 201;
        response["data"] = source_data;
        response["message"] = "Create SourceData success.";
        return response;
    }
    if (res.error().find("Asset not found") != std::string::npos) {
        return ApiResponse::error({ErrorType::AssetNotFound, res.error()});
    }
    return ApiResponse::error({ErrorType::DatabaseError, res.error()});
}

// --- Text & Lyrics Handlers ---

/**
 * @brief Handles 'text.save' to store UTF-8 text into CAS or attach an existing Text record to an entity.
 *
 * UI Usage Notes:
 * - Exclusive payload modes (XOR):
 *   1) Content mode: provide `entity_id`, `role`, `content` (UTF-8), `format` (`lrc|txt|srt|ttml`),
 *      and optional `language`. Core normalizes `\r\n`/`\r` -> `\n` before hashing & storing to CAS.
 *   2) Attach mode: provide `entity_id`, `role`, and `text_hash` (do NOT pass `format` or `language`).
 * - Additive semantics: Existing associations with the same `(role, language)` are preserved, not overwritten.
 * - Response includes `data.existing_same_slot_count`: if `> 0`, UI should inform the user that other text
 *   entries already exist for the same `(role, language)` and offer checkboxes to remove old ones via `text.unlink`.
 * - Control-character validation: Core rejects any C0/C1 control characters in `content` other than `\t`, `\n`, `\r`
 *   (and never silently strips them). UI should proactively detect invisible control characters when importing `.lrc`/`.txt`
 *   files or pasting from clipboard and prompt the user to clean or normalize them before calling `text.save`.
 */
json Router::handleTextSave(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"entity_id", Type::String, true, StringFormat::UUID},
                                                    {"role", Type::String, true},
                                                    {"content", Type::String, false},
                                                    {"text_hash", Type::String, false},
                                                    {"format", Type::String, false},
                                                    {.key = "language", .expected_type = Type::String, .is_required = false, .allow_empty = true}});
        err) return *err;

    if (!m_text_service) {
        return ApiResponse::error({ErrorType::DatabaseError, "Text service not available"});
    }

    SaveTextRequest req;
    req.entity_id = params["entity_id"].get<std::string>();
    req.role = params["role"].get<std::string>();
    req.content = JsonHelper::get_optional<std::string>(params, "content");
    req.text_hash = JsonHelper::get_optional<std::string>(params, "text_hash");
    req.format = JsonHelper::get_optional<std::string>(params, "format");
    req.language = JsonHelper::get_optional<std::string>(params, "language");

    auto res = m_text_service->save_text(req);
    if (!res) {
        return ApiResponse::error(res.error());
    }

    json data = res->text;
    data["existing_same_slot_count"] = res->existing_same_slot_count;

    json response;
    response["code"] = 201;
    response["data"] = std::move(data);
    response["message"] = "Save Text success.";
    return response;
}

/**
 * @brief Handles 'text.get' to retrieve a single text payload (including UTF-8 `content`).
 *
 * UI Usage Notes:
 * - Exclusive lookup modes (XOR):
 *   1) Direct lookup: pass `text_hash` (must NOT include `role` or `language`). Always unambiguous.
 *   2) Entity lookup: pass `entity_id` with optional `role` and `language` filters.
 * - Ambiguity protection: In `entity_id` mode, if multiple matching records exist, Core returns HTTP 409 `Conflict`.
 *   When receiving `Conflict`, UI should call `text.get_entity_texts` to list metadata variants (language/role/hash)
 *   and then fetch the user's chosen variant via `text.get({ "text_hash": ... })`.
 */
json Router::handleTextGet(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"text_hash", Type::String, false},
                                                    {"entity_id", Type::String, false, StringFormat::UUID},
                                                    {"role", Type::String, false},
                                                    {.key = "language", .expected_type = Type::String, .is_required = false, .allow_empty = true}});
        err) return *err;

    if (!m_text_service) {
        return ApiResponse::error({ErrorType::DatabaseError, "Text service not available"});
    }

    const bool has_hash = JsonHelper::has_value(params, "text_hash");
    const bool has_entity = JsonHelper::has_value(params, "entity_id");
    if (!has_hash && !has_entity) {
        return ApiResponse::error({ErrorType::MissingParameter, "Must provide either 'text_hash' or 'entity_id'."});
    }
    if (has_hash && has_entity) {
        return ApiResponse::error({ErrorType::InvalidValue, "Cannot provide both 'text_hash' and 'entity_id'."});
    }

    tl::expected<TextContentResult, Error> res = tl::unexpected(Error{ErrorType::DatabaseError, ""});
    if (has_hash) { // Direct lookup
        if (JsonHelper::has_value(params, "role") || JsonHelper::has_value(params, "language")) {
            return ApiResponse::error({ErrorType::InvalidValue,
                                       "Cannot specify 'role' or 'language' when querying by 'text_hash'."});
        }
        res = m_text_service->get_text_by_hash(params["text_hash"].get<std::string>());
    } else { // Entity lookup
        auto role = JsonHelper::get_optional<std::string>(params, "role");
        auto language = JsonHelper::get_optional<std::string>(params, "language");
        res = m_text_service->get_entity_text(
            params["entity_id"].get<std::string>(), role, language);
    }

    if (!res) {
        return ApiResponse::error(res.error());
    }

    json data = res->text;
    data["content"] = res->content;
    return ApiResponse::success(data);
}

/**
 * @brief Handles 'text.get_entity_texts' to list text metadata records linked to an entity (without file content).
 *
 * UI Usage Notes:
 * - Use to inspect all available text versions/languages/roles on a Track/Album/Artist/Work/Playlist before
 *   fetching specific content with `text.get({ "text_hash": ... })`, or to render a cleanup dialog after `text.save`
 *   reports `existing_same_slot_count > 0`.
 */
json Router::handleTextGetEntityTexts(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"entity_id", Type::String, true, StringFormat::UUID},
                                                    {"role", Type::String, false},
                                                    {.key = "language", .expected_type = Type::String, .is_required = false, .allow_empty = true}});
        err) return *err;

    if (!m_text_service) {
        return ApiResponse::error({ErrorType::DatabaseError, "Text service not available"});
    }

    auto role = JsonHelper::get_optional<std::string>(params, "role");
    auto language = JsonHelper::get_optional<std::string>(params, "language");
    auto res = m_text_service->get_entity_texts(
        params["entity_id"].get<std::string>(), role, language);
    if (!res) {
        return ApiResponse::error(res.error());
    }

    json arr = json::array();
    for (const auto &item : res.value()) {
        arr.push_back(item);
    }
    return ApiResponse::success(arr);
}

/**
 * @brief Handles 'text.unlink' to remove the association between an entity and a Text record.
 *
 * UI Usage Notes:
 * - Use when the user confirms deleting an older duplicate text entry (after `text.save` reports
 *   `existing_same_slot_count > 0`) or opts to undo/remove an auto-imported embedded lyric from `ImportTrack`.
 */
json Router::handleTextUnlink(const json &params) {
    if (auto err = JsonValidator::validate(params, {{"entity_id", Type::String, true, StringFormat::UUID},
                                                    {"text_hash", Type::String, true}});
        err) return *err;

    if (!m_text_service) {
        return ApiResponse::error({ErrorType::DatabaseError, "Text service not available"});
    }

    const std::string entity_id = params["entity_id"].get<std::string>();
    const std::string text_hash = params["text_hash"].get<std::string>();
    auto res = m_text_service->unlink_entity_text(entity_id, text_hash);
    if (!res) {
        return ApiResponse::error(res.error());
    }

    json response = ApiResponse::success({{"entity_id", entity_id}, {"text_hash", text_hash}});
    response["message"] = "Unlink Text success.";
    return response;
}

json Router::route(const json &request) {
    if (!request.is_object() || !request.contains("command") || !request["command"].is_string()) {
        return ApiResponse::error(
            {ErrorType::InvalidCommandFormat, "Missing or invalid 'command' field"});
    }

    const std::string command = request["command"];
    json params = request.value("params", json::object());

    if (auto it = m_handlers.find(command); it != m_handlers.end()) {
        if (!params.is_object()) {
            return ApiResponse::error(
                {ErrorType::InvalidCommandFormat,
                 "'params' must be a JSON object, got " + std::string(params.type_name())});
        }
        return it->second(params);
    }

    return ApiResponse::error({ErrorType::UnknownCommand, "Unknown command: " + command});
}

} // namespace lyra
