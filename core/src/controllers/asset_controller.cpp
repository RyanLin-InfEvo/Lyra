// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/asset.h"
#include "asset_controller.h"

namespace lyra {

using json = nlohmann::json;

AssetController::AssetController(IAssetRepository &repo)
    : m_repo(repo) {}

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

} // namespace lyra
