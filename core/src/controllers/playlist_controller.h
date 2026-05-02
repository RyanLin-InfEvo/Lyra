/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <optional>
#include <string>
#include <vector>

#include "../models/playlist.h"

namespace lyra {

class PlaylistController {
  public:
    // Create Playlist
    static std::optional<std::string> create(Playlist &playlist);

    // Get Playlist
    static std::optional<Playlist> get(const std::string &id);

    // Update Playlist
    static std::optional<std::string> update(const PlaylistUpdate &playlist_update);

    // Add track to playlist
    static std::optional<std::string> add_track(const std::string &playlist_id, const std::string &track_id, std::optional<int> position = std::nullopt);

    // Remove track from playlist
    static std::optional<std::string> remove_track(const std::string &playlist_id, const std::string &track_id);

    // Get track IDs in playlist
    static std::vector<std::string> get_tracks(const std::string &playlist_id);
};

} // namespace lyra
