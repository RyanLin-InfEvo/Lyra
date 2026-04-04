/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <optional>

namespace lyra {
namespace utils {
template <typename... Args>
[[nodiscard]] constexpr bool any_has_value(const std::optional<Args> &...opts) noexcept {
    return (... || opts.has_value());
}
} // namespace utils
} // namespace lyra
