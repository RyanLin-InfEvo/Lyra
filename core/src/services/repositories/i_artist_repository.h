// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/artist.h"
#include "../../utils/paginated_result.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>

namespace lyra {

class IArtistRepository {
  public:
    virtual ~IArtistRepository() = default;

    virtual tl::expected<void, std::string> insert(const Artist &artist) = 0;
    virtual tl::expected<void, std::string> update(const ArtistUpdate &update_data) = 0;
    virtual tl::expected<Artist, std::string> get(const std::string &artist_id) = 0;
    virtual tl::expected<PaginatedResult<Artist>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) = 0;
    virtual tl::expected<std::vector<Artist>, std::string> get_by_name(const std::string &name) = 0;
};

} // namespace lyra
