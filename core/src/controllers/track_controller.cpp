// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "../models/relation_types.h"
#include "../models/track.h"
#include "../services/database_manager.h"
#include "../utils/uuid_generator.h"
#include "track_controller.h"

namespace lyra {

std::optional<std::string> TrackController::create(Track &track) {
    // Generate UUID for the new track
    track.id = UuidGenerator::generate_v4();

    return DatabaseManager::insert_track(track);
}

std::optional<Track> TrackController::get(const std::string &id) {
    return DatabaseManager::get_track(id);
}

std::optional<std::string> TrackController::update(const TrackUpdate &track_update) {
    return DatabaseManager::update_track(track_update);
}

std::optional<std::string> TrackController::add_artist(const TrackArtistParams &params) {
    return DatabaseManager::add_track_artist(params);
}

std::optional<std::string> TrackController::remove_artist(const TrackArtistParams &params) {
    return DatabaseManager::remove_track_artist(params.track_id, params.artist_id);
}

std::optional<std::string> TrackController::update_artist(const TrackArtistParams &params) {
    return DatabaseManager::update_track_artist(params);
}


} // namespace lyra
