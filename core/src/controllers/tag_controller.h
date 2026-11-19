// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/tag.h"
#include "../services/repositories/i_tag_repository.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

class TagController {
  public:
    explicit TagController(ITagRepository &repo);

    tl::expected<void, std::string> create(Tag &tag);
    tl::expected<Tag, std::string> get(const std::string &id);
    tl::expected<void, std::string> delete_tag(const std::string &id);
    tl::expected<PaginatedResult<Tag>, std::string> list(
        int offset,
        int limit,
        const std::optional<std::string> &search,
        const std::optional<std::string> &category = std::nullopt);

    tl::expected<void, std::string> assign_to_entity(
        const std::string &entity_id,
        const std::string &tag_id,
        const std::optional<std::string> &entity_type = std::nullopt);
    tl::expected<void, std::string> remove_from_entity(
        const std::string &entity_id,
        const std::string &tag_id,
        const std::optional<std::string> &entity_type = std::nullopt);
    tl::expected<std::vector<Tag>, std::string> get_entity_tags(
        const std::string &entity_id,
        const std::optional<std::string> &entity_type = std::nullopt);

  private:
    ITagRepository &m_repo;
};

} // namespace lyra
