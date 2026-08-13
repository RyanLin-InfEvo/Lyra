// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/image.h"
#include "../../utils/paginated_result.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

class IImageRepository {
  public:
    virtual ~IImageRepository() = default;

    virtual tl::expected<void, std::string> insert(const Image &image) = 0;
    virtual tl::expected<Image, std::string> get(const std::string &image_hash) = 0;
    virtual tl::expected<PaginatedResult<Image>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) = 0;

    virtual tl::expected<void, std::string> link_entity(
        const std::string &entity_id, const std::string &image_hash,
        const std::optional<std::string> &role = std::nullopt) = 0;
    virtual tl::expected<void, std::string> unlink_entity(
        const std::string &entity_id, const std::string &image_hash) = 0;
    virtual tl::expected<std::vector<Image>, std::string> get_images_by_entity(
        const std::string &entity_id, const std::optional<std::string> &role = std::nullopt) = 0;
    virtual tl::expected<Image, std::string> get_artist_latest_album_cover(
        const std::string &artist_id) = 0;
};

} // namespace lyra
