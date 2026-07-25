// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/asset.h"
#include "../models/audio.h"
#include "../services/repositories/i_asset_repository.h"
#include "../services/repositories/i_audio_repository.h"
#include <nlohmann/json.hpp>
#include <string_view>
#include <tl/expected.hpp>
#include <unordered_map>
#include <utility>
#include <vector>

namespace lyra {

using json = nlohmann::json;

class IImageRepository;

struct AssetIngestResult {
    Asset asset;
    nlohmann::json metadata;
    std::optional<std::string> cover_image_hash = std::nullopt;
    std::optional<std::string> cover_file_hash = std::nullopt;
};

class AssetController {
  public:
    AssetController(IAssetRepository &repo, IAudioRepository &audio_repo, const std::string &storage_root, IImageRepository *image_repo = nullptr);

    tl::expected<void, std::string> create(Asset &asset);
    tl::expected<Asset, std::string> get(const std::string &file_hash);
    tl::expected<void, std::string> update(const AssetUpdate &asset_update);
    tl::expected<PaginatedResult<Asset>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search);

    tl::expected<AssetIngestResult, std::string> ingest(const std::string &source_path);
    tl::expected<std::string, std::string> resolve_file_path(const std::string &file_hash);
    tl::expected<std::vector<std::string>, std::string> get_assets_by_audio(const std::string &pcm_hash);

  private:
    IAssetRepository &m_repo;
    IAudioRepository &m_audio_repo;
    std::string m_storage_root;
    IImageRepository *m_image_repo;
};

} // namespace lyra
