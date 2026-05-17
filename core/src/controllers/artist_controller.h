/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "../models/artist.h"
#include "../services/repositories/i_artist_repository.h"
#include <nlohmann/json.hpp>
#include <memory>
#include <tl/expected.hpp>

namespace lyra {

using json = nlohmann::json;

class ArtistController {
  public:
    explicit ArtistController(IArtistRepository &repo);

    // Create Artist
    tl::expected<void, std::string> create(Artist &artist);

    // Get Artist
    tl::expected<Artist, std::string> get(const std::string &id);

    // Update Artist
    tl::expected<void, std::string> update(const ArtistUpdate &artist_update);

  private:
    IArtistRepository &m_repo;
};

} // namespace lyra
