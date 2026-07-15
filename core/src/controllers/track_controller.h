// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/track.h"
#include "../services/repositories/i_track_repository.h"
#include <nlohmann/json.hpp>
#include <tl/expected.hpp>

namespace lyra {

using json = nlohmann::json;

class TrackController {
  public:
    explicit TrackController(ITrackRepository &repo);

    tl::expected<void, std::string> create(Track &track);
    tl::expected<Track, std::string> get(const std::string &id);
    tl::expected<void, std::string> update(const TrackUpdate &track_update);
    tl::expected<PaginatedResult<Track>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search);
    tl::expected<void, std::string> add_artist(const TrackArtistParams &params);
    tl::expected<void, std::string> remove_artist(const TrackArtistParams &params);
    tl::expected<void, std::string> update_artist(const TrackArtistParams &params);
    tl::expected<std::vector<Track>, std::string> get_by_title(const std::string &title);

  private:
    ITrackRepository &m_repo;
};

} // namespace lyra
