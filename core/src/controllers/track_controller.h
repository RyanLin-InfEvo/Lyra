/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "../models/track.h"
#include <nlohmann/json.hpp>

namespace lyra {

using json = nlohmann::json;

class TrackController {
  public:
    // Create Track
    static std::optional<std::string> create(Track &track);

    // Get Track
    static std::optional<Track> get(const std::string &id);

    static std::optional<std::string> update(const TrackUpdate &track_update);

    static json add_artist(const json &params);
    static json remove_artist(const json &params);
    static json update_artist(const json &params);
};

} // namespace lyra
