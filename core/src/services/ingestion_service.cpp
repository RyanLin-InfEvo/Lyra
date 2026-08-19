/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "ingestion_service.h"

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "../models/album.h"
#include "../models/artist.h"
#include "../models/asset.h"
#include "../models/audio.h"
#include "../models/relation_types.h"
#include "../models/track.h"
#include "../services/database_context.h"
#include "../services/repositories/i_album_repository.h"
#include "../services/repositories/i_artist_repository.h"
#include "../services/repositories/i_asset_repository.h"
#include "../services/repositories/i_audio_repository.h"
#include "../services/repositories/i_image_repository.h"
#include "../services/repositories/i_track_repository.h"
#include "../utils/audio_helper.h"
#include "../utils/sha256.h"
#include "../utils/storage_helper.h"
#include "../utils/uuid_generator.h"

namespace lyra {

namespace {

struct ImageFormatInfo {
    std::string mime_type;
    std::string extension;
};

/**
 * Detects the image format (MIME type and file extension) of raw binary image data
 * by inspecting magic byte signatures at specific offsets.
 */
ImageFormatInfo detect_image_format(const std::vector<uint8_t> &img_bytes) {
    // 1. PNG Signature: \x89PNG\r\n\x1a\n (0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    if (img_bytes.size() >= 8 &&
        img_bytes[0] == 0x89 && img_bytes[1] == 'P' && img_bytes[2] == 'N' && img_bytes[3] == 'G' &&
        img_bytes[4] == 0x0D && img_bytes[5] == 0x0A && img_bytes[6] == 0x1A && img_bytes[7] == 0x0A) {
        return {"image/png", ".png"};
    }

    // 2. JPEG Signature: \xFF\xD8\xFF
    if (img_bytes.size() >= 3 &&
        img_bytes[0] == 0xFF && img_bytes[1] == 0xD8 && img_bytes[2] == 0xFF) {
        return {"image/jpeg", ".jpg"};
    }

    // 3. GIF Signature: Starts with "GIF" (GIF87a or GIF89a)
    if (img_bytes.size() >= 6 &&
        img_bytes[0] == 'G' && img_bytes[1] == 'I' && img_bytes[2] == 'F') {
        return {"image/gif", ".gif"};
    }

    // 4. WebP Signature: "RIFF" at offset 0 and "WEBP" at offset 8
    if (img_bytes.size() >= 12 &&
        img_bytes[0] == 'R' && img_bytes[1] == 'I' && img_bytes[2] == 'F' && img_bytes[3] == 'F' &&
        img_bytes[8] == 'W' && img_bytes[9] == 'E' && img_bytes[10] == 'B' && img_bytes[11] == 'P') {
        return {"image/webp", ".webp"};
    }

    // 5. BMP Signature: Starts with "BM" (0x42, 0x4D)
    if (img_bytes.size() >= 2 &&
        img_bytes[0] == 'B' && img_bytes[1] == 'M') {
        return {"image/bmp", ".bmp"};
    }

    // 6. TIFF Signature: Little-endian "II*\0" (0x49 0x49 0x2A 0x00) or Big-endian "MM\0*" (0x4D 0x4D 0x00 0x2A)
    if (img_bytes.size() >= 4) {
        if ((img_bytes[0] == 'I' && img_bytes[1] == 'I' && img_bytes[2] == 0x2A && img_bytes[3] == 0x00) ||
            (img_bytes[0] == 'M' && img_bytes[1] == 'M' && img_bytes[2] == 0x00 && img_bytes[3] == 0x2A)) {
            return {"image/tiff", ".tiff"};
        }
    }

    // 7. ISOBMFF formats: HEIC/HEIF and AVIF
    // Checks for 'ftyp' box type starting at byte offset 4
    if (img_bytes.size() >= 12 &&
        img_bytes[4] == 'f' && img_bytes[5] == 't' && img_bytes[6] == 'y' && img_bytes[7] == 'p') {

        auto matches_brand = [&](size_t offset, const char brand[4]) {
            return offset + 4 <= img_bytes.size() &&
                   img_bytes[offset] == brand[0] &&
                   img_bytes[offset + 1] == brand[1] &&
                   img_bytes[offset + 2] == brand[2] &&
                   img_bytes[offset + 3] == brand[3];
        };

        // Total ftyp box size in big-endian bytes 0..3
        uint32_t box_size = (static_cast<uint32_t>(img_bytes[0]) << 24) |
                            (static_cast<uint32_t>(img_bytes[1]) << 16) |
                            (static_cast<uint32_t>(img_bytes[2]) << 8) |
                            static_cast<uint32_t>(img_bytes[3]);

        size_t max_offset = img_bytes.size();
        if (box_size > 0 && static_cast<size_t>(box_size) < max_offset) {
            max_offset = static_cast<size_t>(box_size);
        }

        bool is_avif = false;
        bool is_heic = false;

        static const char AVIF_BRANDS[][4] = {{'a', 'v', 'i', 'f'}, {'a', 'v', 'i', 's'}};
        static const char HEIC_BRANDS[][4] = {
            {'h', 'e', 'i', 'c'}, {'h', 'e', 'i', 'x'}, {'h', 'e', 'v', 'c'}, {'m', 'i', 'f', '1'}, {'m', 's', 'f', '1'}};

        for (size_t offset = 8; offset + 4 <= max_offset; offset += 4) {
            if (offset == 12) continue; // Skip 4-byte minor version field

            for (const auto &b : AVIF_BRANDS) {
                if (matches_brand(offset, b)) {
                    is_avif = true;
                    break;
                }
            }
            if (is_avif) break;

            for (const auto &b : HEIC_BRANDS) {
                if (matches_brand(offset, b)) {
                    is_heic = true;
                    break;
                }
            }
            if (is_heic) break;
        }

        if (is_avif) {
            return {"image/avif", ".avif"};
        }
        if (is_heic) {
            return {"image/heic", ".heic"};
        }
    }

    // Default fallback format: JPEG
    return {"image/jpeg", ".jpg"};
}

} // namespace

IngestionService::IngestionService(
    IDatabaseContext &db_context,
    IAssetRepository &asset_repo,
    IAudioRepository &audio_repo,
    IArtistRepository &artist_repo,
    IAlbumRepository &album_repo,
    ITrackRepository &track_repo,
    const std::string &storage_root,
    IImageRepository *image_repo)
    : m_db_context(db_context),
      m_asset_repo(asset_repo),
      m_audio_repo(audio_repo),
      m_artist_repo(artist_repo),
      m_album_repo(album_repo),
      m_track_repo(track_repo),
      m_storage_root(storage_root),
      m_image_repo(image_repo) {}

tl::expected<AssetIngestResult, std::string> IngestionService::ingest_asset(const std::string &source_path) {
    const std::string ext = std::filesystem::path(source_path).extension().string();
    const std::filesystem::path temp_path = utils::StorageHelper::generate_temp_path(m_storage_root, ext);

    utils::TempCleanup cleanup{temp_path};

    auto copy_res = utils::StorageHelper::copy_to_temp(source_path, temp_path);
    if (!copy_res.has_value()) {
        return tl::unexpected(copy_res.error());
    }

    // Calculate sha256 hash of the file
    std::string file_hash = utils::Sha256::hash_file(temp_path.string());
    if (file_hash.empty()) {
        return tl::unexpected("Failed to calculate SHA-256 hash of file");
    }

    // Check if asset already exists in database
    auto existing_asset_res = m_asset_repo.get(file_hash);
    if (existing_asset_res.has_value()) {
        auto pcm_hashes_res = m_asset_repo.get_audio_by_asset(file_hash);
        if (!pcm_hashes_res.has_value()) {
            return tl::unexpected("Failed to query audio relations: " + pcm_hashes_res.error());
        }
        if (pcm_hashes_res.value().empty()) {
            return tl::unexpected("Asset exists but has no associated audio");
        }
        auto audio_res = m_audio_repo.get(pcm_hashes_res.value()[0]);
        if (!audio_res.has_value()) {
            return tl::unexpected("Failed to retrieve audio metadata for existing asset: " + audio_res.error());
        }

        Audio audio = audio_res.value();
        nlohmann::json metadata = audio;
        AssetIngestResult res;
        res.asset = existing_asset_res.value();
        res.metadata = metadata;
        return res;
    }

    // Calculate PCM hash
    auto pcm_hash_res = utils::AudioHelper::calculate_pcm_hash(temp_path.string());
    if (!pcm_hash_res.has_value()) {
        return tl::unexpected("Failed to calculate PCM hash: " + pcm_hash_res.error());
    }
    std::string pcm_hash = pcm_hash_res.value();

    // Extract audio metadata
    auto metadata_res = utils::AudioHelper::extract_metadata(temp_path.string());
    if (!metadata_res.has_value()) {
        return tl::unexpected("Failed to extract audio metadata: " + metadata_res.error());
    }
    auto extracted_meta = metadata_res.value();

    // Validate metadata
    if (extracted_meta.duration <= 0.0 || extracted_meta.channels <= 0 || extracted_meta.sample_rate <= 0) {
        return tl::unexpected("Invalid audio metadata: duration, channels, and sample rate must be greater than zero.");
    }

    const std::filesystem::path target_path = utils::StorageHelper::resolve_cas_path(m_storage_root, file_hash, ext);

    // Get file size from temp path before moving
    auto size_res = utils::StorageHelper::get_file_size(temp_path);
    if (!size_res.has_value()) {
        return tl::unexpected(size_res.error());
    }
    uintmax_t file_size = size_res.value();

    // Move file to deterministic CAS location
    auto move_res = utils::StorageHelper::move_to_cas(temp_path, target_path);
    if (!move_res.has_value()) {
        return tl::unexpected(move_res.error());
    }
    cleanup.dismiss();

    // Determine MIME type based on extension
    std::string lower_ext = ext;
    std::transform(lower_ext.begin(), lower_ext.end(), lower_ext.begin(),
                   [](unsigned char c) { return std::tolower(c); });

    static const std::unordered_map<std::string_view, std::string_view> MIME_MAP = {
        {".wav", "audio/wav"},
        {".mp3", "audio/mpeg"},
        {".flac", "audio/flac"},
        {".ogg", "audio/ogg"},
        {".opus", "audio/opus"},
        {".m4a", "audio/mp4"},
        {".aac", "audio/aac"},
        {".webm", "audio/webm"},
        {".aiff", "audio/x-aiff"},
        {".aif", "audio/x-aiff"}};

    std::string mime_type = "audio/octet-stream";
    auto mime_it = MIME_MAP.find(lower_ext);
    if (mime_it != MIME_MAP.end()) {
        mime_type = mime_it->second;
    }

    Asset asset;
    asset.file_hash = file_hash;
    asset.mime_type = mime_type;
    asset.asset_type = "audio";
    asset.file_size = static_cast<int>(file_size);

    Audio audio;
    audio.pcm_hash = pcm_hash;
    audio.parent_hash = "";
    audio.quality_score = 0;
    audio.bit_depth = 16;
    audio.sample_rate = extracted_meta.sample_rate;
    audio.channels = extracted_meta.channels;
    audio.duration = extracted_meta.duration;
    audio.integrated_loudness = 0.0;
    audio.true_peak = 0.0;

    auto insert_res = m_asset_repo.insert_asset_with_audio(asset, audio);
    if (!insert_res.has_value()) {
        // Rollback, clean up orphaned CAS file on database failure
        utils::StorageHelper::remove_file(target_path);
        return tl::unexpected("Failed to insert asset and audio: " + insert_res.error());
    }

    std::optional<std::string> cover_image_hash = std::nullopt;
    std::optional<std::string> cover_file_hash = std::nullopt;

    // Process embedded cover art if present in the audio metadata
    if (extracted_meta.has_cover_art) {
        // Extract raw binary image data from the ingested CAS audio file, falling back to source path
        auto cover_bytes_res = utils::AudioHelper::extract_cover_art(target_path.string());
        if (!cover_bytes_res.has_value()) {
            cover_bytes_res = utils::AudioHelper::extract_cover_art(source_path);
        }

        if (cover_bytes_res.has_value() && !cover_bytes_res.value().empty()) {
            const auto &img_bytes = cover_bytes_res.value();

            std::string img_hash = utils::Sha256::hash_bytes(img_bytes);
            ImageFormatInfo fmt_info = detect_image_format(img_bytes);
            const std::string &img_mime = fmt_info.mime_type;
            const std::string &img_ext = fmt_info.extension;

            const std::filesystem::path img_temp_path = utils::StorageHelper::generate_temp_path(m_storage_root, img_ext);
            utils::TempCleanup img_cleanup{img_temp_path};

            std::ofstream img_out(img_temp_path, std::ios::binary);
            if (img_out.is_open()) {
                img_out.write(reinterpret_cast<const char *>(img_bytes.data()), img_bytes.size());
                img_out.close();

                const std::filesystem::path img_target_path = utils::StorageHelper::resolve_cas_path(m_storage_root, img_hash, img_ext);
                auto img_move_res = utils::StorageHelper::move_to_cas(img_temp_path, img_target_path);
                if (img_move_res.has_value()) {
                    img_cleanup.dismiss();

                    auto existing_img_asset = m_asset_repo.get(img_hash);
                    if (!existing_img_asset.has_value()) {
                        Asset img_asset;
                        img_asset.file_hash = img_hash;
                        img_asset.mime_type = img_mime;
                        img_asset.asset_type = "image";
                        img_asset.file_size = static_cast<int>(img_bytes.size());
                        m_asset_repo.insert(img_asset);
                    }

                    if (m_image_repo) {
                        auto existing_img_rec = m_image_repo->get(img_hash);
                        if (!existing_img_rec.has_value()) {
                            Image img_rec;
                            img_rec.image_hash = img_hash;
                            img_rec.file_hash = img_hash;
                            img_rec.width = 0;
                            img_rec.height = 0;
                            m_image_repo->insert(img_rec);
                        }
                    }

                    cover_image_hash = img_hash;
                    cover_file_hash = img_hash;
                }
            }
        }
    }

    AssetIngestResult res;
    res.asset = asset;
    res.metadata = audio;
    res.cover_image_hash = cover_image_hash;
    res.cover_file_hash = cover_file_hash;
    return res;
}

tl::expected<TrackImportResult, std::string> IngestionService::import_track(const TrackImportRequest &request) {
    // 1. Extract metadata tags first
    auto metadata_res = utils::AudioHelper::extract_metadata(request.source_path);
    if (!metadata_res) {
        return tl::unexpected("Failed to extract metadata: " + metadata_res.error());
    }
    const auto &tags = metadata_res.value();

    // 2. Begin transaction
    auto tx = m_db_context.begin_transaction();

    // 3. Ingest asset
    auto ingest_res = ingest_asset(request.source_path);
    if (!ingest_res) {
        return tl::unexpected("Asset ingestion failed: " + ingest_res.error());
    }
    const auto &audio_json = ingest_res.value().metadata;
    std::string pcm_hash = audio_json["pcm_hash"].get<std::string>();
    double duration_sec = audio_json["duration"].get<double>();

    // 4. Extract metadata fields
    std::string title;
    if (tags.title && !tags.title->empty()) {
        title = *tags.title;
    } else {
        title = std::filesystem::path(request.source_path).stem().string();
    }

    // 5. Artist deduplication & creation
    std::string artist_id;
    if (tags.artist && !tags.artist->empty()) {
        auto artist_name = *tags.artist;
        auto artist_lookup = m_artist_repo.get_by_name(artist_name);
        if (!artist_lookup) {
            return tl::unexpected("Database error retrieving artist: " + artist_lookup.error());
        }
        if (!artist_lookup.value().empty()) {
            artist_id = artist_lookup.value()[0].id;
        } else {
            Artist artist;
            artist.id = UuidGenerator::generate_v4();
            artist.name = artist_name;
            auto res = m_artist_repo.insert(artist);
            if (!res) {
                return tl::unexpected("Failed to create artist: " + res.error());
            }
            artist_id = artist.id;
        }
    }

    // 6. Album deduplication & creation
    std::string album_id;
    if (tags.album && !tags.album->empty()) {
        auto album_title = *tags.album;
        auto album_lookup = m_album_repo.get_by_title(album_title);
        if (!album_lookup) {
            return tl::unexpected("Database error retrieving album: " + album_lookup.error());
        }
        if (!album_lookup.value().empty()) {
            album_id = album_lookup.value()[0].id;
        } else {
            Album album;
            album.id = UuidGenerator::generate_v4();
            album.title = album_title;
            auto res = m_album_repo.insert(album);
            if (!res) {
                return tl::unexpected("Failed to create album: " + res.error());
            }
            album_id = album.id;
        }
    }

    // 7. Track creation
    std::optional<uint16_t> recording_year = std::nullopt;
    std::optional<uint8_t> recording_month = std::nullopt;
    std::optional<uint8_t> recording_day = std::nullopt;
    if (tags.date && !tags.date->empty()) {
        const auto &date_str = *tags.date;
        try {
            if (date_str.length() >= 4) {
                bool all_digits = true;
                for (int i = 0; i < 4; ++i) {
                    if (!std::isdigit(static_cast<unsigned char>(date_str[i]))) {
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
                if (std::isdigit(static_cast<unsigned char>(date_str[5])) &&
                    std::isdigit(static_cast<unsigned char>(date_str[6]))) {
                    recording_month = static_cast<uint8_t>(std::stoi(date_str.substr(5, 2)));
                }
                if (std::isdigit(static_cast<unsigned char>(date_str[8])) &&
                    std::isdigit(static_cast<unsigned char>(date_str[9]))) {
                    recording_day = static_cast<uint8_t>(std::stoi(date_str.substr(8, 2)));
                }
            }
        } catch (...) {
            // ignore
        }
    }

    Track track;
    track.id = UuidGenerator::generate_v4();
    track.pcm_hash = pcm_hash;
    track.title = title;
    track.recording_year = recording_year;
    track.recording_month = recording_month;
    track.recording_day = recording_day;
    track.duration = static_cast<uint32_t>(duration_sec * 1000.0);

    auto create_track_res = m_track_repo.insert(track);
    if (!create_track_res) {
        return tl::unexpected("Failed to create track: " + create_track_res.error());
    }

    // 8. Link Artist
    if (!artist_id.empty()) {
        TrackArtistParams artist_params;
        artist_params.track_id = track.id;
        artist_params.artist_id = artist_id;
        artist_params.role = ArtistRole::Main;
        artist_params.position = 1;
        auto link_artist_res = m_track_repo.add_artist(artist_params);
        if (!link_artist_res) {
            return tl::unexpected("Failed to link artist to track: " + link_artist_res.error());
        }
    }

    // 9. Link Album
    if (!album_id.empty()) {
        std::optional<int> position = std::nullopt;
        if (tags.track && !tags.track->empty()) {
            const auto &track_str = *tags.track;
            std::string pos_str;
            for (char c : track_str) {
                if (std::isdigit(static_cast<unsigned char>(c))) {
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
        auto link_album_res = m_track_repo.add_album(album_params);
        if (!link_album_res) {
            return tl::unexpected("Failed to link album to track: " + link_album_res.error());
        }
    }

    // 10. Link Cover Image if present
    if (ingest_res.value().cover_image_hash.has_value() && m_image_repo) {
        const std::string &cover_hash = *ingest_res.value().cover_image_hash;
        auto link_track_img = m_image_repo->link_entity(track.id, cover_hash, "front");
        if (!link_track_img) {
            return tl::unexpected("Failed to link cover image to track: " + link_track_img.error());
        }
        if (!album_id.empty()) {
            auto existing_images = m_image_repo->get_images_by_entity(album_id);
            if (!existing_images) {
                return tl::unexpected("Failed to query album images: " + existing_images.error());
            }
            if (existing_images.value().empty()) {
                auto link_album_img = m_image_repo->link_entity(album_id, cover_hash, "front");
                if (!link_album_img) {
                    return tl::unexpected("Failed to link cover image to album: " + link_album_img.error());
                }
            }
        }
    }

    // 11. Commit transaction
    tx->commit();

    TrackImportResult res;
    res.track_id = track.id;
    res.pcm_hash = track.pcm_hash;
    res.title = track.title.value_or("");
    if (!artist_id.empty()) res.artist_id = artist_id;
    if (!album_id.empty()) res.album_id = album_id;
    res.cover_image_hash = ingest_res.value().cover_image_hash;

    return res;
}

} // namespace lyra
