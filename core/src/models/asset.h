/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <string>
#include <optional>
#include <nlohmann/json.hpp>
#include "../utils/optional_helper.h"

namespace lyra {

struct Asset {
    std::string file_hash;
    std::string mime_type = "";
    std::string asset_type = "";
    int file_size = 0;
    std::string created_at = "";
};

struct AssetUpdate {
    std::string file_hash;
    std::optional<std::string> mime_type;
    std::optional<std::string> asset_type;
    std::optional<int> file_size;
    std::optional<std::string> created_at;

    [[nodiscard]] bool has_updates() const noexcept {
        return utils::any_has_value(mime_type, asset_type, file_size, created_at);
    }
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(Asset, file_hash, mime_type, asset_type, file_size, created_at)
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(AssetUpdate, file_hash, mime_type, asset_type, file_size, created_at)

} // namespace lyra
