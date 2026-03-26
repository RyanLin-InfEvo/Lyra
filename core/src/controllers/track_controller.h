/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "../models/track.h"
#include <nlohmann/json.hpp>

using json = nlohmann::json;

class TrackController {
  public:
    // Create Track
    static json create(const json &params);

    // Get Track
    static std::optional<Track> get(const std::string &uuid);

    static json update(const json &params);

    static json add_artist(const json &params);
    static json remove_artist(const json &params);
    static json update_artist(const json &params);
};
