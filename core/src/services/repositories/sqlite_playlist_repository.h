// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../database_context.h"
#include "i_playlist_repository.h"

namespace lyra {

class SqlitePlaylistRepository : public IPlaylistRepository {
  public:
    explicit SqlitePlaylistRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Playlist &playlist) override;
    tl::expected<void, std::string> update(const PlaylistUpdate &update_data) override;
    tl::expected<Playlist, std::string> get(const std::string &playlist_id) override;

    tl::expected<void, std::string> add_track(const std::string &playlist_id, const std::string &track_id, std::optional<int> position) override;
    tl::expected<void, std::string> remove_track(const std::string &playlist_id, const std::string &track_id) override;
    std::vector<std::string> get_tracks(const std::string &playlist_id) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
