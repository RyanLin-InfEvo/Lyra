// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../database_context.h"
#include "../i_image_repository.h"

namespace lyra {

class SqliteImageRepository : public IImageRepository {
  public:
    explicit SqliteImageRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Image &image) override;
    tl::expected<Image, std::string> get(const std::string &image_hash) override;
    tl::expected<PaginatedResult<Image>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) override;

    tl::expected<void, std::string> link_entity(
        const std::string &entity_id, const std::string &image_hash,
        const std::optional<std::string> &role = std::nullopt) override;
    tl::expected<void, std::string> unlink_entity(
        const std::string &entity_id, const std::string &image_hash) override;
    tl::expected<std::vector<Image>, std::string> get_images_by_entity(
        const std::string &entity_id, const std::optional<std::string> &role = std::nullopt) override;
    tl::expected<Image, std::string> get_artist_latest_album_cover(
        const std::string &artist_id) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
