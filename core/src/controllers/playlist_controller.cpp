// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/playlist.h"
#include "../utils/uuid_generator.h"
#include "playlist_controller.h"

namespace lyra {

using json = nlohmann::json;

PlaylistController::PlaylistController(IPlaylistRepository &repo)
    : m_repo(repo) {}

tl::expected<void, std::string> PlaylistController::create(Playlist &playlist) {
    playlist.id = UuidGenerator::generate_v4();
    return m_repo.insert(playlist);
}

tl::expected<Playlist, std::string> PlaylistController::get(const std::string &id) {
    return m_repo.get(id);
}

tl::expected<void, std::string> PlaylistController::update(const PlaylistUpdate &playlist_update) {
    return m_repo.update(playlist_update);
}

tl::expected<void, std::string> PlaylistController::add_track(const std::string &playlist_id,
                                                        const std::string &track_id,
                                                        std::optional<int> position) {
    return m_repo.add_track(playlist_id, track_id, position);
}

tl::expected<void, std::string> PlaylistController::remove_track(const std::string &playlist_id,
                                                           const std::string &track_id) {
    return m_repo.remove_track(playlist_id, track_id);
}

std::vector<std::string> PlaylistController::get_tracks(const std::string &playlist_id) {
    return m_repo.get_tracks(playlist_id);
}

tl::expected<PaginatedResult<Playlist>, std::string> PlaylistController::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return m_repo.list(offset, limit, search);
}

} // namespace lyra
