// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/asset.h"
#include "../../models/audio.h"
#include "../../utils/paginated_result.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>

namespace lyra {

class IAssetRepository {
  public:
    virtual ~IAssetRepository() = default;

    virtual tl::expected<void, std::string> insert(const Asset &asset) = 0;
    virtual tl::expected<void, std::string> update(const AssetUpdate &update_data) = 0;
    virtual tl::expected<Asset, std::string> get(const std::string &file_hash) = 0;
    virtual tl::expected<PaginatedResult<Asset>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) = 0;

    virtual tl::expected<void, std::string> insert_asset_with_audio(const Asset &asset, const Audio &audio) = 0;
    virtual tl::expected<std::vector<std::string>, std::string> get_assets_by_audio(const std::string &pcm_hash) = 0;
    virtual tl::expected<std::vector<Asset>, std::string> get_assets_by_pcm(const std::string &pcm_hash) = 0;
    virtual tl::expected<std::vector<std::string>, std::string> get_audio_by_asset(const std::string &file_hash) = 0;
};

} // namespace lyra
