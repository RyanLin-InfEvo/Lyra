// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../database_context.h"
#include "../i_track_repository.h"

namespace lyra {

class SqliteTrackRepository : public ITrackRepository {
  public:
    explicit SqliteTrackRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Track &track) override;
    tl::expected<void, std::string> update(const TrackUpdate &update_data) override;
    tl::expected<Track, std::string> get(const std::string &track_id) override;
    tl::expected<PaginatedResult<Track>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) override;

    tl::expected<void, std::string> add_artist(const TrackArtistParams &params) override;
    tl::expected<void, std::string> remove_artist(const std::string& track_id, const std::string& artist_id) override;
    tl::expected<void, std::string> update_artist(const TrackArtistParams &params) override;

    tl::expected<void, std::string> add_album(const TrackAlbumParams &params) override;
    tl::expected<void, std::string> remove_album(const std::string& track_id, const std::string& album_id) override;
    tl::expected<void, std::string> update_album(const TrackAlbumParams &params) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
