/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

#include "../models/image.h"
#include "../utils/make_error.h"

namespace lyra {

class IImageRepository;
class ITrackRepository;
class IAlbumRepository;
class IArtistRepository;
class IPlaylistRepository;
class IAssetRepository;

struct CoverResolutionResult {
    std::string image_hash;
    std::string file_hash;
    std::string mime_type;
    int width = 0;
    int height = 0;
    uintmax_t file_size = 0;
    std::string file_path;
    std::string source_entity_type;
    std::string source_entity_id;
    std::string dominant_color = "";
    std::optional<std::string> role = std::nullopt;
};

class CoverArtService {
  public:
    CoverArtService(
        IImageRepository &image_repo,
        ITrackRepository &track_repo,
        IAlbumRepository &album_repo,
        IArtistRepository &artist_repo,
        IPlaylistRepository &playlist_repo,
        IAssetRepository &asset_repo,
        const std::string &storage_root);

    tl::expected<CoverResolutionResult, Error> get_track_cover(const std::string &track_id);
    tl::expected<CoverResolutionResult, Error> get_album_cover(const std::string &album_id);
    tl::expected<CoverResolutionResult, Error> get_artist_cover(const std::string &artist_id);
    tl::expected<CoverResolutionResult, Error> get_playlist_cover(const std::string &playlist_id);
    tl::expected<std::vector<CoverResolutionResult>, Error> get_entity_images(
        const std::string &entity_id, const std::optional<std::string> &role = std::nullopt);

  private:
    tl::expected<CoverResolutionResult, Error> resolve_image(
        const Image &img, const std::string &source_entity_type, const std::string &source_entity_id);

    IImageRepository &m_image_repo;
    ITrackRepository &m_track_repo;
    IAlbumRepository &m_album_repo;
    IArtistRepository &m_artist_repo;
    IPlaylistRepository &m_playlist_repo;
    IAssetRepository &m_asset_repo;
    std::string m_storage_root;
};

} // namespace lyra
