// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "asset_controller.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <string>
#include <utility>
#include <vector>

#include "../models/asset.h"
#include "../utils/storage_helper.h"

namespace lyra {

AssetController::AssetController(IAssetRepository &repo, const std::string &storage_root)
    : m_repo(repo), m_storage_root(storage_root) {}

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
