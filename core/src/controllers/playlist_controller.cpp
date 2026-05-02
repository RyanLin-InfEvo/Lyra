// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <string>
#include <vector>

#include "../models/playlist.h"
#include "../services/database_manager.h"
#include "../utils/uuid_generator.h"
#include "playlist_controller.h"

namespace lyra {

std::optional<std::string> PlaylistController::create(Playlist &playlist) {
    playlist.id = UuidGenerator::generate_v4();
    return DatabaseManager::insert_playlist(playlist);
}

std::optional<Playlist> PlaylistController::get(const std::string &id) {
    return DatabaseManager::get_playlist(id);
}

std::optional<std::string> PlaylistController::update(const PlaylistUpdate &playlist_update) {
    return DatabaseManager::update_playlist(playlist_update);
}

std::optional<std::string> PlaylistController::add_track(const std::string &playlist_id,
                                                         const std::string &track_id,
                                                         std::optional<int> position) {
    return DatabaseManager::add_playlist_track(playlist_id, track_id, position);
}

std::optional<std::string> PlaylistController::remove_track(const std::string &playlist_id,
                                                            const std::string &track_id) {
    return DatabaseManager::remove_playlist_track(playlist_id, track_id);
}

std::vector<std::string> PlaylistController::get_tracks(const std::string &playlist_id) {
    return DatabaseManager::get_playlist_tracks(playlist_id);
}

} // namespace lyra
