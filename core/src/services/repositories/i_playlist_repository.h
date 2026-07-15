// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/playlist.h"
#include "../../utils/paginated_result.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

class IPlaylistRepository {
  public:
    virtual ~IPlaylistRepository() = default;

    virtual tl::expected<void, std::string> insert(const Playlist &playlist) = 0;
    virtual tl::expected<void, std::string> update(const PlaylistUpdate &update_data) = 0;
    virtual tl::expected<Playlist, std::string> get(const std::string &playlist_id) = 0;
    virtual tl::expected<PaginatedResult<Playlist>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) = 0;

    virtual tl::expected<void, std::string> add_track(const std::string &playlist_id, const std::string &track_id, std::optional<int> position) = 0;
    virtual tl::expected<void, std::string> remove_track(const std::string &playlist_id, const std::string &track_id) = 0;
    virtual std::vector<std::string> get_tracks(const std::string &playlist_id) = 0;
    virtual tl::expected<std::vector<Playlist>, std::string> get_by_title(const std::string &title) = 0;
};

} // namespace lyra
