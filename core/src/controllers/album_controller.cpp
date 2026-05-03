// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

#include "../models/album.h"
#include "../services/database_manager.h"
#include "../utils/uuid_generator.h"
#include "album_controller.h"

namespace lyra {

using json = nlohmann::json;

std::optional<std::string> AlbumController::create(Album &album) {
    album.id = UuidGenerator::generate_v4();

    return DatabaseManager::insert_album(album);
}

std::optional<Album> AlbumController::get(const std::string &id) {
    return DatabaseManager::get_album(id);
}

std::optional<std::string> AlbumController::update(const AlbumUpdate &album_update) {
    return DatabaseManager::update_album(album_update);
}

} // namespace lyra
