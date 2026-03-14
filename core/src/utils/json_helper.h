/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

using json = nlohmann::json;

namespace JsonHelper {

// Safely get Json field. If not null and also exist, then return std::optional, else return std::nullopt
template <typename T>
inline std::optional<T> get_optional(const json &j, const std::string &key) {
    if (j.contains(key) && !j[key].is_null()) {
        return j[key].get<T>();
    }
    return std::nullopt;
}

// Have a default value
template <typename T>
inline T get_safe(const json &j, const std::string &key, const T &default_val) {
    return get_optional<T>(j, key).value_or(default_val);
}

} // namespace JsonHelper
