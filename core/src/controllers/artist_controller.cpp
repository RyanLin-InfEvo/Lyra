// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/artist.h"
#include "../services/database_manager.h"
#include "../utils/uuid_generator.h"
#include "artist_controller.h"

using json = nlohmann::json;

std::optional<std::string> ArtistController::create(Artist &artist) {
    artist.id = UuidGenerator::generate_v4();

    return DatabaseManager::insert_artist(artist);
}

std::optional<Artist> ArtistController::get(const std::string &id) {
    return DatabaseManager::get_artist(id);
}

std::optional<std::string> ArtistController::update(const ArtistUpdate &artist_update) {
    return DatabaseManager::update_artist(artist_update);
}
