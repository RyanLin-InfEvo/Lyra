/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <optional>
#include <nlohmann/json.hpp>

namespace lyra {
namespace utils {
template <typename... Args>
[[nodiscard]] constexpr bool any_has_value(const std::optional<Args> &...opts) noexcept {
    return (... || opts.has_value());
}
} // namespace utils
} // namespace lyra

namespace nlohmann {
    template <typename T>
    struct adl_serializer<std::optional<T>> {
        static void to_json(json& j, const std::optional<T>& opt) {
            if (opt == std::nullopt) {
                j = nullptr;
            } else {
                j = *opt;
            }
        }

        static void from_json(const json& j, std::optional<T>& opt) {
            if (j.is_null()) {
                opt = std::nullopt;
            } else {
                opt = j.get<T>();
            }
        }
    };
}
