/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "cover_art_service.h"

#include <filesystem>

#include "../utils/storage_helper.h"
#include "repositories/i_album_repository.h"
#include "repositories/i_artist_repository.h"
#include "repositories/i_asset_repository.h"
#include "repositories/i_image_repository.h"
#include "repositories/i_playlist_repository.h"
#include "repositories/i_track_repository.h"

namespace lyra {

CoverArtService::CoverArtService(
    IImageRepository &image_repo,
    ITrackRepository &track_repo,
    IAlbumRepository &album_repo,
    IArtistRepository &artist_repo,
    IPlaylistRepository &playlist_repo,
    IAssetRepository &asset_repo,
    const std::string &storage_root)
    : m_image_repo(image_repo),
      m_track_repo(track_repo),
      m_album_repo(album_repo),
      m_artist_repo(artist_repo),
      m_playlist_repo(playlist_repo),
      m_asset_repo(asset_repo),
      m_storage_root(storage_root) {}

tl::expected<CoverResolutionResult, Error> CoverArtService::resolve_image(
    const Image &img, const std::string &source_entity_type, const std::string &source_entity_id) {
    auto asset_res = m_asset_repo.get(img.file_hash);
    if (!asset_res) {
        return tl::unexpected(Error{ErrorType::AssetNotFound, asset_res.error()});
    }
    std::string mime_type = asset_res->mime_type;
    uintmax_t file_size = asset_res->file_size;

    std::string ext;
    if (mime_type == "image/jpeg" || mime_type == "image/jpg") {
        ext = ".jpg";
    } else if (mime_type == "image/png") {
        ext = ".png";
    } else if (mime_type == "image/gif") {
        ext = ".gif";
    } else if (mime_type == "image/webp") {
        ext = ".webp";
    }

    std::string path;
    if (!ext.empty()) {
        auto cas_path = utils::StorageHelper::resolve_cas_path(m_storage_root, img.file_hash, ext);
        if (std::filesystem::exists(cas_path)) {
            path = cas_path.string();
        }
    }

    if (path.empty()) {
        auto cas_dir = utils::StorageHelper::resolve_cas_dir(m_storage_root, img.file_hash);
        if (std::filesystem::exists(cas_dir)) {
            auto find_res = utils::StorageHelper::find_file_by_prefix(cas_dir, img.file_hash);
            if (find_res.has_value() && std::filesystem::exists(find_res.value())) {
                path = find_res.value();
            }
        }
    }

    if (path.empty()) {
        path = utils::StorageHelper::resolve_cas_path(m_storage_root, img.file_hash, ext.empty() ? ".jpg" : ext).string();
    }

    if (file_size == 0 && std::filesystem::exists(path)) {
        std::error_code ec;
        auto fs = std::filesystem::file_size(path, ec);
        if (!ec) {
            file_size = fs;
        }
    }

    CoverResolutionResult res;
    res.image_hash = img.image_hash;
    res.file_hash = img.file_hash;
    res.mime_type = mime_type;
    res.width = img.width;
    res.height = img.height;
    res.file_size = file_size;
    res.file_path = path;
    res.source_entity_type = source_entity_type;
    res.source_entity_id = source_entity_id;
    res.dominant_color = img.dominant_color;
    res.role = img.role;

    return res;
}

tl::expected<CoverResolutionResult, Error> CoverArtService::get_album_cover(const std::string &album_id) {
    auto images_res = m_image_repo.get_images_by_entity(album_id);
    if (!images_res || images_res.value().empty()) {
        return tl::unexpected(Error{ErrorType::NotFound, "No cover image found for album: " + album_id});
    }
    return resolve_image(images_res.value()[0], "album", album_id);
}

tl::expected<CoverResolutionResult, Error> CoverArtService::get_track_cover(const std::string &track_id) {
    // 1. Direct track cover
    auto images_res = m_image_repo.get_images_by_entity(track_id);
    if (images_res && !images_res.value().empty()) {
        return resolve_image(images_res.value()[0], "track", track_id);
    }

    // 2. Fallback to album cover if track belongs to an album
    auto album_id_res = m_track_repo.get_album_id_by_track(track_id);
    if (!album_id_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, album_id_res.error()});
    }

    if (album_id_res.value().has_value()) {
        const auto &album_id = *album_id_res.value();
        auto album_images_res = m_image_repo.get_images_by_entity(album_id);
        if (album_images_res && !album_images_res.value().empty()) {
            return resolve_image(album_images_res.value()[0], "album", album_id);
        }
    }

    return tl::unexpected(Error{ErrorType::NotFound, "No cover image found for track or its album: " + track_id});
}

tl::expected<CoverResolutionResult, Error> CoverArtService::get_artist_cover(const std::string &artist_id) {
    auto artist_res = m_artist_repo.get(artist_id);
    if (!artist_res) {
        return tl::unexpected(Error{ErrorType::ArtistNotFound, "Artist not found: " + artist_id});
    }

    auto avatar_images = m_image_repo.get_images_by_entity(artist_id, "artist_avatar");
    if (avatar_images && !avatar_images.value().empty()) {
        return resolve_image(avatar_images.value()[0], "artist", artist_id);
    }

    auto latest_album_cover = m_image_repo.get_artist_latest_album_cover(artist_id);
    if (latest_album_cover) {
        return resolve_image(latest_album_cover.value(), "album", artist_id);
    }

    return tl::unexpected(Error{ErrorType::NotFound, "No cover image found for artist: " + artist_id});
}

tl::expected<CoverResolutionResult, Error> CoverArtService::get_playlist_cover(const std::string &playlist_id) {
    auto playlist_res = m_playlist_repo.get(playlist_id);
    if (!playlist_res) {
        return tl::unexpected(Error{ErrorType::PlaylistNotFound, "Playlist not found: " + playlist_id});
    }

    auto playlist_images = m_image_repo.get_images_by_entity(playlist_id);
    if (playlist_images && !playlist_images.value().empty()) {
        return resolve_image(playlist_images.value()[0], "playlist", playlist_id);
    }

    auto first_track_res = m_playlist_repo.get_first_track_id(playlist_id);
    if (!first_track_res) {
        return tl::unexpected(Error{ErrorType::NotFound, "No cover image found for playlist: " + playlist_id});
    }

    std::string first_track_id = first_track_res.value();
    auto track_cover_res = get_track_cover(first_track_id);
    if (track_cover_res) {
        return track_cover_res;
    }

    return tl::unexpected(Error{ErrorType::NotFound, "No cover image found for playlist: " + playlist_id});
}

tl::expected<std::vector<CoverResolutionResult>, Error> CoverArtService::get_entity_images(
    const std::string &entity_id, const std::optional<std::string> &role) {
    auto exists_res = m_image_repo.entity_exists(entity_id);
    if (!exists_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, exists_res.error()});
    }
    if (!exists_res.value()) {
        return tl::unexpected(Error{ErrorType::NotFound, "Entity not found: " + entity_id});
    }

    auto images_res = m_image_repo.get_images_by_entity(entity_id, role);
    if (!images_res) {
        return tl::unexpected(Error{ErrorType::DatabaseError, images_res.error()});
    }

    std::vector<CoverResolutionResult> results;
    results.reserve(images_res.value().size());
    for (const auto &img : images_res.value()) {
        auto res = resolve_image(img, "entity", entity_id);
        if (res) {
            results.push_back(std::move(res.value()));
        }
    }

    return results;
}

} // namespace lyra
