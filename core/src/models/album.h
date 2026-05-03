/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "../utils/optional_helper.h"

namespace lyra {

struct Album {
    std::string id;
    std::string title;
    std::optional<uint16_t> release_year;
    std::optional<uint8_t> release_month;
    std::optional<uint8_t> release_day;
};

struct AlbumUpdate {
    std::string id;
    std::optional<std::string> title;
    std::optional<uint16_t> release_year;
    std::optional<uint8_t> release_month;
    std::optional<uint8_t> release_day;

    [[nodiscard]] bool has_updates() const noexcept {
        return utils::any_has_value(title, release_year, release_month, release_day);
    }
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(Album, id, title, release_year, release_month, release_day)
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(AlbumUpdate, id, title, release_year, release_month, release_day)

} // namespace lyra
