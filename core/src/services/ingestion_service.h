/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <filesystem>
#include <memory>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

#include "../models/album.h"
#include "../models/artist.h"
#include "../models/asset.h"
#include "../models/audio.h"
#include "../models/text.h"
#include "../models/track.h"

namespace lyra {

class IDatabaseContext;
class IAssetRepository;
class IAudioRepository;
class IArtistRepository;
class IAlbumRepository;
class ITrackRepository;
class IImageRepository;
class ISourceDataRepository;
class TextService;
class ConfigurationService;

struct AssetIngestResult {
    Asset asset;
    nlohmann::json metadata;
    std::optional<std::string> cover_image_hash = std::nullopt;
    std::optional<std::string> cover_file_hash = std::nullopt;
};

struct TrackImportRequest {
    std::string source_path;
    std::string source_type = "";
    std::string note = "";
    bool import_embedded_lyrics = true;
};

struct TrackImportResult {
    std::string track_id;
    std::string pcm_hash;
    std::string title;
    std::optional<std::string> artist_id = std::nullopt;
    std::optional<std::string> album_id = std::nullopt;
    std::optional<std::string> cover_image_hash = std::nullopt;
    std::vector<Text> imported_texts;
};

class IngestionService {
  public:
    IngestionService(
        IDatabaseContext &db_context,
        IAssetRepository &asset_repo,
        IAudioRepository &audio_repo,
        IArtistRepository &artist_repo,
        IAlbumRepository &album_repo,
        ITrackRepository &track_repo,
        const std::string &storage_root,
        IImageRepository *image_repo = nullptr,
        ISourceDataRepository *source_data_repo = nullptr,
        TextService *text_service = nullptr,
        const ConfigurationService *config_service = nullptr);

    tl::expected<AssetIngestResult, std::string> ingest_asset(
        const std::string &source_path,
        const std::string &source_type = "",
        const std::string &note = "");
    tl::expected<TrackImportResult, std::string> import_track(const TrackImportRequest &request);

  private:
    tl::expected<AssetIngestResult, std::string> ingest_asset_internal(
        const std::string &source_path,
        const std::string &source_type,
        const std::string &note,
        bool precompute_waveform,
        std::filesystem::path *out_audio_path = nullptr);

    void precompute_waveform_if_needed(
        const std::string &pcm_hash,
        const std::filesystem::path &audio_file_path) const;

    IDatabaseContext &m_db_context;
    IAssetRepository &m_asset_repo;
    IAudioRepository &m_audio_repo;
    IArtistRepository &m_artist_repo;
    IAlbumRepository &m_album_repo;
    ITrackRepository &m_track_repo;
    std::string m_storage_root;
    IImageRepository *m_image_repo;
    ISourceDataRepository *m_source_data_repo;
    TextService *m_text_service;
    const ConfigurationService *m_config_service;
};

} // namespace lyra
