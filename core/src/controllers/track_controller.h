/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "../models/relation_types.h"
#include "../models/track.h"

namespace lyra {

class TrackController {
public:
    // Create Track
    static std::optional<std::string> create(Track &track);

    // Get Track
    static std::optional<Track> get(const std::string &id);

    static std::optional<std::string> update(const TrackUpdate &track_update);

    static std::optional<std::string> add_artist(const TrackArtistParams &params);
    static std::optional<std::string> remove_artist(const TrackArtistParams &params);
    static std::optional<std::string> update_artist(const TrackArtistParams &params);
};

} // namespace lyra
