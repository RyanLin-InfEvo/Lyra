/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "../models/artist.h"
#include <nlohmann/json.hpp>

using json = nlohmann::json;

class ArtistController {
  public:
    // Create Artist
    static std::optional<std::string> create(Artist &artist);

    // Get Artist
    static std::optional<Artist> get(const std::string &id);

    // Update Artist
    static std::optional<std::string> update(const ArtistUpdate &artist_update);
};
