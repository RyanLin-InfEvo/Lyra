// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/asset.h"
#include "../services/repositories/i_asset_repository.h"
#include <nlohmann/json.hpp>
#include <tl/expected.hpp>

namespace lyra {

using json = nlohmann::json;

class AssetController {
  public:
    explicit AssetController(IAssetRepository &repo);

    tl::expected<void, std::string> create(Asset &asset);
    tl::expected<Asset, std::string> get(const std::string &file_hash);
    tl::expected<void, std::string> update(const AssetUpdate &asset_update);
    tl::expected<PaginatedResult<Asset>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search);

  private:
    IAssetRepository &m_repo;
};

} // namespace lyra
