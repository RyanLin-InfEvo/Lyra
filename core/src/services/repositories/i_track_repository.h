// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <string>
#include <tl/expected.hpp>
#include <vector>
#include "../../models/track.h"
#include "../../models/relation_types.h"

namespace lyra {

class ITrackRepository {
  public:
    virtual ~ITrackRepository() = default;

    virtual tl::expected<void, std::string> insert(const Track &track) = 0;
    virtual tl::expected<void, std::string> update(const TrackUpdate &update_data) = 0;
    virtual tl::expected<Track, std::string> get(const std::string &track_id) = 0;

    // Track-Artist relations
    virtual tl::expected<void, std::string> add_artist(const TrackArtistParams &params) = 0;
    virtual tl::expected<void, std::string> remove_artist(const std::string& track_id, const std::string& artist_id) = 0;
    virtual tl::expected<void, std::string> update_artist(const TrackArtistParams &params) = 0;
};

} // namespace lyra
