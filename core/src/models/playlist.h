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

struct Playlist {
    std::string id;
    std::string title;
    std::optional<std::string> description;
};

struct PlaylistUpdate {
    std::string id;
    std::optional<std::string> title;
    std::optional<std::string> description;

    [[nodiscard]] bool has_updates() const noexcept {
        return utils::any_has_value(title, description);
    }
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(Playlist, id, title, description)
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(PlaylistUpdate, id, title, description)

} // namespace lyra
