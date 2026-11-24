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

struct Tag {
    std::string id;
    std::string name;
    std::string category = "general";
    std::optional<std::string> created_at;
};

struct TagUpdate {
    std::string id;
    std::optional<std::string> name;
    std::optional<std::string> category;

    [[nodiscard]] bool has_updates() const noexcept {
        return utils::any_has_value(name, category);
    }
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(Tag, id, name, category, created_at)
// NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(TagUpdate, id, name, category)

} // namespace lyra
