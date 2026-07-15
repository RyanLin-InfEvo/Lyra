// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/track.h"
#include "../utils/uuid_generator.h"
#include "track_controller.h"

namespace lyra {

using json = nlohmann::json;

TrackController::TrackController(ITrackRepository &repo)
    : m_repo(repo) {}

tl::expected<void, std::string> TrackController::create(Track &track) {
    track.id = UuidGenerator::generate_v4();
    return m_repo.insert(track);
}

tl::expected<Track, std::string> TrackController::get(const std::string &id) {
    return m_repo.get(id);
}

tl::expected<void, std::string> TrackController::update(const TrackUpdate &track_update) {
    return m_repo.update(track_update);
}

tl::expected<void, std::string> TrackController::add_artist(const TrackArtistParams &params) {
    return m_repo.add_artist(params);
}

tl::expected<void, std::string> TrackController::remove_artist(const TrackArtistParams &params) {
    return m_repo.remove_artist(params.track_id, params.artist_id);
}

tl::expected<void, std::string> TrackController::update_artist(const TrackArtistParams &params) {
    return m_repo.update_artist(params);
}

tl::expected<PaginatedResult<Track>, std::string> TrackController::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return m_repo.list(offset, limit, search);
}

tl::expected<std::vector<Track>, std::string> TrackController::get_by_title(const std::string &title) {
    return m_repo.get_by_title(title);
}

} // namespace lyra
