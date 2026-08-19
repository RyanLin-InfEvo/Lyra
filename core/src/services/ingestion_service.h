/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

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
#include "../models/track.h"

namespace lyra {

class IDatabaseContext;
class IAssetRepository;
class IAudioRepository;
class IArtistRepository;
class IAlbumRepository;
class ITrackRepository;
class IImageRepository;

struct AssetIngestResult {
    Asset asset;
    nlohmann::json metadata;
    std::optional<std::string> cover_image_hash = std::nullopt;
    std::optional<std::string> cover_file_hash = std::nullopt;
};

struct TrackImportRequest {
    std::string source_path;
};

struct TrackImportResult {
    std::string track_id;
    std::string pcm_hash;
    std::string title;
    std::optional<std::string> artist_id = std::nullopt;
    std::optional<std::string> album_id = std::nullopt;
    std::optional<std::string> cover_image_hash = std::nullopt;
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
        IImageRepository *image_repo = nullptr);

    tl::expected<AssetIngestResult, std::string> ingest_asset(const std::string &source_path);
    tl::expected<TrackImportResult, std::string> import_track(const TrackImportRequest &request);

  private:
    IDatabaseContext &m_db_context;
    IAssetRepository &m_asset_repo;
    IAudioRepository &m_audio_repo;
    IArtistRepository &m_artist_repo;
    IAlbumRepository &m_album_repo;
    ITrackRepository &m_track_repo;
    std::string m_storage_root;
    IImageRepository *m_image_repo;
};

} // namespace lyra
