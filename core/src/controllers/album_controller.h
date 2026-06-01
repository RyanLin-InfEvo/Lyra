// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/album.h"
#include "../services/repositories/i_album_repository.h"
#include <nlohmann/json.hpp>
#include <tl/expected.hpp>

namespace lyra {

using json = nlohmann::json;

class AlbumController {
  public:
    explicit AlbumController(IAlbumRepository &repo);

    tl::expected<void, std::string> create(Album &album);
    tl::expected<Album, std::string> get(const std::string &id);
    tl::expected<void, std::string> update(const AlbumUpdate &album_update);
    tl::expected<PaginatedResult<Album>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search);

  private:
    IAlbumRepository &m_repo;
};

} // namespace lyra
