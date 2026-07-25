// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <nlohmann/json.hpp>
#include <string>
#include <system_error>
#include <utility>
#include <vector>

#include "../models/asset.h"
#include "../models/audio.h"
#include "../services/repositories/i_image_repository.h"
#include "../utils/audio_helper.h"
#include "../utils/sha256.h"
#include "../utils/storage_helper.h"
#include "../utils/uuid_generator.h"
#include "asset_controller.h"

namespace lyra {

namespace {

struct ImageFormatInfo {
    std::string mime_type;
    std::string extension;
};

/**
 * Detects the image format (MIME type and file extension) of raw binary image data
 * by inspecting magic byte signatures at specific offsets.
 *
 * Supported Formats:
 * - PNG: 8-byte signature (\x89PNG\r\n\x1a\n) -> image/png, .png
 * - JPEG: 3-byte signature (\xFF\xD8\xFF) -> image/jpeg, .jpg
 * - GIF: Starts with "GIF" -> image/gif, .gif
 * - WebP: RIFF container with "WEBP" at offset 8 -> image/webp, .webp
 * - HEIC/HEIF: ISOBMFF box check at offset 4 for "ftyp" brand matching
 *              (heic, heix, hevc, mif1, msf1) -> image/heic, .heic
 * - AVIF: ISOBMFF box check at offset 4 for "ftyp" brand matching
 *         (avif, avis) -> image/avif, .avif
 * - BMP: 2-byte signature ("BM") -> image/bmp, .bmp
 * - TIFF: Little-endian ("II*\0") or Big-endian ("MM\0*") -> image/tiff, .tiff
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

AssetController::AssetController(IAssetRepository &repo, IAudioRepository &audio_repo, const std::string &storage_root, IImageRepository *image_repo)
    : m_repo(repo), m_audio_repo(audio_repo), m_storage_root(storage_root), m_image_repo(image_repo) {}

tl::expected<void, std::string> AssetController::create(Asset &asset) {
    return m_repo.insert(asset);
}

tl::expected<Asset, std::string> AssetController::get(const std::string &file_hash) {
    return m_repo.get(file_hash);
}

tl::expected<void, std::string> AssetController::update(const AssetUpdate &asset_update) {
    return m_repo.update(asset_update);
}

tl::expected<PaginatedResult<Asset>, std::string> AssetController::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return m_repo.list(offset, limit, search);
}

tl::expected<AssetIngestResult, std::string> AssetController::ingest(const std::string &source_path) {
    const std::string ext = std::filesystem::path(source_path).extension().string();
    const std::filesystem::path temp_path = utils::StorageHelper::generate_temp_path(m_storage_root, ext);

    utils::TempCleanup cleanup{temp_path};

    auto copy_res = utils::StorageHelper::copy_to_temp(source_path, temp_path);
    if (!copy_res.has_value()) {
        return tl::unexpected(copy_res.error());
    }

    // Get the sha256 of the file
    std::string file_hash = utils::Sha256::hash_file(temp_path.string());
    if (file_hash.empty()) {
        return tl::unexpected("Failed to calculate SHA-256 hash of file");
    }

    // Existing check
    auto existing_asset_res = m_repo.get(file_hash);
    if (existing_asset_res.has_value()) {

        auto pcm_hashes_res = m_repo.get_audio_by_asset(file_hash);
        if (!pcm_hashes_res.has_value()) {
            return tl::unexpected("Failed to query audio relations: " + pcm_hashes_res.error());
        }
        if (pcm_hashes_res.value().empty()) {
            return tl::unexpected("Asset exists but has no associated audio");
        }
        auto audio_res = m_audio_repo.get(pcm_hashes_res.value()[0]);
        if (!audio_res.has_value()) { // Checks if the `pcm_hash` have metadata in `Audio` table
            return tl::unexpected("Failed to retrieve audio metadata for existing asset: " + audio_res.error());
        }

        Audio audio = audio_res.value();
        nlohmann::json metadata = audio;
        AssetIngestResult res;
        res.asset = existing_asset_res.value();
        res.metadata = metadata;
        return res;
    }

    // Get pcm_hash
    auto pcm_hash_res = utils::AudioHelper::calculate_pcm_hash(temp_path.string());
    if (!pcm_hash_res.has_value()) return tl::unexpected("Failed to calculate PCM hash: " + pcm_hash_res.error());
    std::string pcm_hash = pcm_hash_res.value();

    // Get metadata
    auto metadata_res = utils::AudioHelper::extract_metadata(temp_path.string());
    if (!metadata_res.has_value()) return tl::unexpected("Failed to extract audio metadata: " + metadata_res.error());
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

    // Move file to target_path
    auto move_res = utils::StorageHelper::move_to_cas(temp_path, target_path);
    if (!move_res.has_value()) {
        return tl::unexpected(move_res.error());
    }
    cleanup.dismiss();

    // Get mime_type
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
    audio.parent_hash = ""; // TODO ?
    audio.quality_score = 0;
    audio.bit_depth = 16; // TODO
    audio.sample_rate = extracted_meta.sample_rate;
    audio.channels = extracted_meta.channels;
    audio.duration = extracted_meta.duration;
    audio.integrated_loudness = 0.0; // TODO
    audio.true_peak = 0.0;           // TODO

    auto insert_res = m_repo.insert_asset_with_audio(asset, audio);
    if (!insert_res.has_value()) { // Rollback, clean up orphaned CAS file on database failure
        utils::StorageHelper::remove_file(target_path);
        return tl::unexpected("Failed to insert asset and audio: " + insert_res.error());
    }

    std::optional<std::string> cover_image_hash = std::nullopt;
    std::optional<std::string> cover_file_hash = std::nullopt;

    // Process embedded cover art if present in the audio metadata
    if (extracted_meta.has_cover_art) {
        // 1. Cover Art Extraction
        // Extract raw binary image data from the ingested CAS audio file, falling back to the source path.
        auto cover_bytes_res = utils::AudioHelper::extract_cover_art(target_path.string());
        if (!cover_bytes_res.has_value()) {
            cover_bytes_res = utils::AudioHelper::extract_cover_art(source_path);
        }

        if (cover_bytes_res.has_value() && !cover_bytes_res.value().empty()) {
            const auto &img_bytes = cover_bytes_res.value();

            // 2. Magic Byte Format Detection & Content Hashing
            // Compute the SHA-256 hash of raw image bytes for content-addressed storage (CAS).
            std::string img_hash = utils::Sha256::hash_bytes(img_bytes);

            // Detect image format (MIME type and file extension) via magic byte signature analysis.
            ImageFormatInfo fmt_info = detect_image_format(img_bytes);
            const std::string &img_mime = fmt_info.mime_type;
            const std::string &img_ext = fmt_info.extension;

            // 3. Temp File Creation
            // Write raw image bytes to a temporary file path prior to CAS placement.
            const std::filesystem::path img_temp_path = utils::StorageHelper::generate_temp_path(m_storage_root, img_ext);
            utils::TempCleanup img_cleanup{img_temp_path};

            std::ofstream img_out(img_temp_path, std::ios::binary);
            if (img_out.is_open()) {
                img_out.write(reinterpret_cast<const char *>(img_bytes.data()), img_bytes.size());
                img_out.close();

                // 4. CAS Storage Movement
                // Move temporary image file to its deterministic CAS path based on SHA-256 hash and extension.
                const std::filesystem::path img_target_path = utils::StorageHelper::resolve_cas_path(m_storage_root, img_hash, img_ext);
                auto img_move_res = utils::StorageHelper::move_to_cas(img_temp_path, img_target_path);
                if (img_move_res.has_value()) {
                    img_cleanup.dismiss();

                    // 5. Database Asset and Image Insertions
                    // Ensure generic asset table has a record for the newly ingested cover art image.
                    auto existing_img_asset = m_repo.get(img_hash);
                    if (!existing_img_asset.has_value()) {
                        Asset img_asset;
                        img_asset.file_hash = img_hash;
                        img_asset.mime_type = img_mime;
                        img_asset.asset_type = "image";
                        img_asset.file_size = static_cast<int>(img_bytes.size());
                        m_repo.insert(img_asset);
                    }

                    // Ensure specialized image table has a record for the cover art if repository exists.
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

tl::expected<std::string, std::string> AssetController::resolve_file_path(const std::string &file_hash) {

    // Validate hash format to prevent path traversal
    bool is_valid_hash = (file_hash.length() == 64) && std::all_of(file_hash.begin(), file_hash.end(), [](unsigned char c) {
                             return std::isxdigit(c);
                         });
    if (!is_valid_hash) {
        return tl::unexpected("Invalid file hash format: " + file_hash);
    }

    const std::filesystem::path target_dir = utils::StorageHelper::resolve_cas_dir(m_storage_root, file_hash);

    if (!std::filesystem::exists(target_dir)) {
        return tl::unexpected("Asset file not found in storage: " + file_hash);
    }

    auto find_res = utils::StorageHelper::find_file_by_prefix(target_dir, file_hash);
    if (!find_res.has_value()) {
        return tl::unexpected("Asset file not found in storage: " + file_hash);
    }
    return find_res.value();
}

tl::expected<std::vector<std::string>, std::string> AssetController::get_assets_by_audio(const std::string &pcm_hash) {
    return m_repo.get_assets_by_audio(pcm_hash);
}

} // namespace lyra
