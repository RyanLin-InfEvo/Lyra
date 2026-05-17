// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <string>
#include <tl/expected.hpp>
#include "../../models/artist.h"

namespace lyra {

class IArtistRepository {
  public:
    virtual ~IArtistRepository() = default;

    virtual tl::expected<void, std::string> insert(const Artist &artist) = 0;
    virtual tl::expected<void, std::string> update(const ArtistUpdate &update_data) = 0;
    virtual tl::expected<Artist, std::string> get(const std::string &artist_id) = 0;
};

} // namespace lyra
