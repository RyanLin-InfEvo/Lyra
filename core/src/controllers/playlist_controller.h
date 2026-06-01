// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/playlist.h"
#include "../services/repositories/i_playlist_repository.h"
#include <nlohmann/json.hpp>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

using json = nlohmann::json;

class PlaylistController {
  public:
    explicit PlaylistController(IPlaylistRepository &repo);

    tl::expected<void, std::string> create(Playlist &playlist);
    tl::expected<Playlist, std::string> get(const std::string &id);
    tl::expected<void, std::string> update(const PlaylistUpdate &playlist_update);
    tl::expected<PaginatedResult<Playlist>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search);
    tl::expected<void, std::string> add_track(const std::string &playlist_id, const std::string &track_id, std::optional<int> position);
    tl::expected<void, std::string> remove_track(const std::string &playlist_id, const std::string &track_id);
    std::vector<std::string> get_tracks(const std::string &playlist_id);

  private:
    IPlaylistRepository &m_repo;
};

} // namespace lyra
