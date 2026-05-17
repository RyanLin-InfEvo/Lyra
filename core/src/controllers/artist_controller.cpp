// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/artist.h"
#include "../utils/uuid_generator.h"
#include "artist_controller.h"

namespace lyra {

using json = nlohmann::json;

ArtistController::ArtistController(IArtistRepository &repo)
    : m_repo(repo) {}

tl::expected<void, std::string> ArtistController::create(Artist &artist) {
    artist.id = UuidGenerator::generate_v4();

    return m_repo.insert(artist);
}

tl::expected<Artist, std::string> ArtistController::get(const std::string &id) {
    return m_repo.get(id);
}

tl::expected<void, std::string> ArtistController::update(const ArtistUpdate &artist_update) {
    return m_repo.update(artist_update);
}

} // namespace lyra
