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

    tl::expected<void, std::string> insert_asset_with_audio(const Asset &asset, const Audio &audio) override;
    tl::expected<std::vector<std::string>, std::string> get_assets_by_audio(const std::string &pcm_hash) override;
    tl::expected<std::vector<std::string>, std::string> get_audio_by_asset(const std::string &file_hash) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
