/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "../models/album.h"
#include <nlohmann/json.hpp>
#include <optional>
#include <string>

namespace lyra {

using json = nlohmann::json;

class AlbumController {
  public:
    // Create Album
    static std::optional<std::string> create(Album &album);

    // Get Album
    static std::optional<Album> get(const std::string &id);

    // Update Album
    static std::optional<std::string> update(const AlbumUpdate &album_update);
};

} // namespace lyra
