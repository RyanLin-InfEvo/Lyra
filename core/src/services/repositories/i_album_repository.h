// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <string>
#include <tl/expected.hpp>
#include "../../models/album.h"

namespace lyra {

class IAlbumRepository {
  public:
    virtual ~IAlbumRepository() = default;

    virtual tl::expected<void, std::string> insert(const Album &album) = 0;
    virtual tl::expected<void, std::string> update(const AlbumUpdate &update_data) = 0;
    virtual tl::expected<Album, std::string> get(const std::string &album_id) = 0;
};

} // namespace lyra
