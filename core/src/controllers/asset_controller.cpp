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
#include "../utils/storage_helper.h"
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
