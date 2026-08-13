/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <optional>
#include <string>

namespace lyra {

struct Image {
    std::string image_hash;
    std::string file_hash;
    int width = 0;
    int height = 0;
    std::string dominant_color = "";
    std::optional<std::string> role = std::nullopt;
};

} // namespace lyra
