// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../database_context.h"
#include "i_asset_repository.h"

namespace lyra {

class SqliteAssetRepository : public IAssetRepository {
  public:
    explicit SqliteAssetRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Asset &asset) override;
    tl::expected<void, std::string> update(const AssetUpdate &update_data) override;
    tl::expected<Asset, std::string> get(const std::string &file_hash) override;
    tl::expected<PaginatedResult<Asset>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
