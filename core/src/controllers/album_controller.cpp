// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <string>

#include "../models/album.h"
#include "../utils/uuid_generator.h"
#include "album_controller.h"

namespace lyra {

using json = nlohmann::json;

AlbumController::AlbumController(IAlbumRepository &repo)
    : m_repo(repo) {}

tl::expected<void, std::string> AlbumController::create(Album &album) {
    album.id = UuidGenerator::generate_v4();
    return m_repo.insert(album);
}

tl::expected<Album, std::string> AlbumController::get(const std::string &id) {
    return m_repo.get(id);
}

tl::expected<void, std::string> AlbumController::update(const AlbumUpdate &album_update) {
    return m_repo.update(album_update);
}

tl::expected<PaginatedResult<Album>, std::string> AlbumController::list(
    int offset, int limit, const std::optional<std::string> &search) {
    return m_repo.list(offset, limit, search);
}

tl::expected<std::vector<Album>, std::string> AlbumController::get_by_title(const std::string &title) {
    return m_repo.get_by_title(title);
}

} // namespace lyra
