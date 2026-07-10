// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <nlohmann/json.hpp>
#include <string>
#include <system_error>
#include <utility>

#include "../models/asset.h"
#include "../models/audio.h"
#include "../utils/audio_helper.h"
#include "../utils/sha256.h"
#include "../utils/uuid_generator.h"
#include "asset_controller.h"

namespace lyra {

using json = nlohmann::json;

AssetController::AssetController(IAssetRepository &repo, IAudioRepository &audio_repo, const std::string &storage_root)
    : m_repo(repo), m_audio_repo(audio_repo), m_storage_root(storage_root) {}

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

tl::expected<std::pair<Asset, nlohmann::json>, std::string> AssetController::ingest(const std::string &source_path) {
    namespace fs = std::filesystem;
    const fs::path src_path(source_path);
    const std::string ext = src_path.extension().string();
    const std::string temp_filename = UuidGenerator::generate_v4() + ext;
    const fs::path tmp_dir = fs::path(m_storage_root) / "tmp";

    // Ensure source path is a regular file and exists
    if (!fs::is_regular_file(src_path)) return tl::unexpected("Source path does not exist or is not a regular file: " + source_path);

    // Cerate temp dir, /tmp
    try {
        fs::create_directories(tmp_dir);
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to create temporary directory: " + std::string(e.what()));
    }
    fs::path temp_path = tmp_dir / temp_filename;

    // Setup fallback for cleaing-up the /tmp
    struct TempCleanup {
        fs::path path;
        bool active = true;
        ~TempCleanup() {
            if (active && !path.empty()) {
                std::error_code ec;
                fs::remove(path, ec);
            }
        }
        void dismiss() { active = false; }
    };
    TempCleanup cleanup{temp_path};

    // Copy to /tmp
    try {
        fs::copy_file(src_path, temp_path, fs::copy_options::overwrite_existing);
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to copy source file to temp path: " + std::string(e.what()));
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
        if (!audio_res.has_value()) { // Checks if the `pch_hash` have metadata in `Audio` table
            return tl::unexpected("Failed to retrieve audio metadata for existing asset: " + audio_res.error());
        }

        Audio audio = audio_res.value();
        nlohmann::json metadata = audio;
        return std::make_pair(existing_asset_res.value(), metadata);
    }

    // Get pcm_hash
    auto pcm_hash_res = utils::AudioHelper::calculate_pcm_hash(temp_path.string());
    if (!pcm_hash_res.has_value()) return tl::unexpected("Failed to calculate PCM hash: " + pcm_hash_res.error());
    std::string pcm_hash = pcm_hash_res.value();

    // Get metafata
    auto metadata_res = utils::AudioHelper::extract_metadata(temp_path.string());
    if (!metadata_res.has_value()) return tl::unexpected("Failed to extract audio metadata: " + metadata_res.error());
    auto extracted_meta = metadata_res.value();

    // Vaildate metadata
    if (extracted_meta.duration <= 0.0 || extracted_meta.channels <= 0 || extracted_meta.sample_rate <= 0) {
        return tl::unexpected("Invalid audio metadata: duration, channels, and sample rate must be greater than zero.");
    }


    // Initialze varaibles, target_path, ./objects/xx/yy/the_hash.ext
    std::string xx = file_hash.substr(0, 2);
    std::string yy = file_hash.substr(2, 2);
    fs::path target_dir = fs::path(m_storage_root) / "objects" / xx / yy;
    fs::path target_path = target_dir / (file_hash + ext);

    try { // Create target_dir
        fs::create_directories(target_dir);
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to create target directories: " + std::string(e.what()));
    }

    // Get file size from temp path before moving
    uintmax_t file_size = 0;
    try {
        file_size = fs::file_size(temp_path);
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to determine file size: " + std::string(e.what()));
    }

    try { // Move file to target_path
        fs::rename(temp_path, target_path);
        cleanup.dismiss();
    } catch (const std::exception &e) {
        std::error_code ec;
        fs::copy_file(temp_path, target_path, fs::copy_options::overwrite_existing, ec);
        if (ec) {
            return tl::unexpected("Failed to move/copy temp file to CAS path: " + ec.message());
        }
        fs::remove(temp_path, ec);
        cleanup.dismiss();
    }

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
        std::error_code ec;
        fs::remove(target_path, ec);
        return tl::unexpected("Failed to insert asset and audio: " + insert_res.error());
    }

    nlohmann::json metadata = audio;
    return std::make_pair(asset, metadata);
}

tl::expected<std::string, std::string> AssetController::resolve_file_path(const std::string &file_hash) {

    // Validate hash format to prevent path traversal
    bool is_valid_hash = (file_hash.length() == 64) && std::all_of(file_hash.begin(), file_hash.end(), [](unsigned char c) {
                             return std::isxdigit(c);
                         });
    if (!is_valid_hash) {
        return tl::unexpected("Invalid file hash format: " + file_hash);
    }

    namespace fs = std::filesystem;
    std::string xx = file_hash.substr(0, 2);
    std::string yy = file_hash.substr(2, 2);
    fs::path target_dir = fs::path(m_storage_root) / "objects" / xx / yy;

    if (!fs::exists(target_dir)) {
        return tl::unexpected("Asset file not found in storage: " + file_hash);
    }

    try {
        for (const auto &entry : fs::directory_iterator(target_dir)) {
            if (!entry.is_regular_file()) {
                continue;
            }
            std::string filename = entry.path().filename().string();
            if (filename.rfind(file_hash, 0) == 0) {
                return entry.path().string();
            }
        }
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to scan storage directory: " + std::string(e.what()));
    }
    return tl::unexpected("Asset file not found in storage: " + file_hash);
}

tl::expected<std::vector<std::string>, std::string> AssetController::get_assets_by_audio(const std::string &pcm_hash) {
    return m_repo.get_assets_by_audio(pcm_hash);
}

} // namespace lyra
