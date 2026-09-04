// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/asset.h"
#include "../services/repositories/i_asset_repository.h"
#include "../utils/paginated_result.h"
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

using json = nlohmann::json;

struct ResolvedAsset {
    Asset asset;
    std::string file_path;
};

class AssetController {
  public:
    AssetController(IAssetRepository &repo, const std::string &storage_root);

    tl::expected<void, std::string> create(Asset &asset);
    tl::expected<Asset, std::string> get(const std::string &file_hash);
    tl::expected<void, std::string> update(const AssetUpdate &asset_update);
    tl::expected<PaginatedResult<Asset>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search);

    tl::expected<std::string, std::string> resolve_file_path(const std::string &file_hash);
    tl::expected<std::vector<std::string>, std::string> get_assets_by_audio(const std::string &pcm_hash);
    tl::expected<std::vector<Asset>, std::string> get_assets_by_pcm(const std::string &pcm_hash);

    tl::expected<ResolvedAsset, std::string> resolve_best_audio_asset(
        const std::string &pcm_hash,
        const std::optional<std::string> &preferred_format = std::nullopt,
        const std::optional<Audio> &audio_entity = std::nullopt);

  private:
    IAssetRepository &m_repo;
    std::string m_storage_root;
};

} // namespace lyra
