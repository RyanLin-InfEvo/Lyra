/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>

using json = nlohmann::json;

class ArtistController {
  public:
    // Create Artist
    static json create(const json &params);

    // Get Artist
    static json get(const json &params);

    // Update Artist
    static json update(const json &params);
};
