// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/album.h"
#include "../../utils/paginated_result.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>

namespace lyra {

class IAlbumRepository {
  public:
    virtual ~IAlbumRepository() = default;

    virtual tl::expected<void, std::string> insert(const Album &album) = 0;
    virtual tl::expected<void, std::string> update(const AlbumUpdate &update_data) = 0;
    virtual tl::expected<Album, std::string> get(const std::string &album_id) = 0;
    virtual tl::expected<PaginatedResult<Album>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) = 0;
    virtual tl::expected<std::vector<Album>, std::string> get_by_title(const std::string &title) = 0;
};

} // namespace lyra
