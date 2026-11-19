// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/tag.h"
#include "../../utils/paginated_result.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

class ITagRepository {
  public:
    virtual ~ITagRepository() = default;

    virtual tl::expected<void, std::string> insert(const Tag &tag) = 0;
    virtual tl::expected<void, std::string> update(const TagUpdate &update_data) = 0;
    virtual tl::expected<Tag, std::string> get(const std::string &tag_id) = 0;
    virtual tl::expected<void, std::string> delete_tag(const std::string &tag_id) = 0;
    virtual tl::expected<PaginatedResult<Tag>, std::string> list(
        int offset,
        int limit,
        const std::optional<std::string> &search,
        const std::optional<std::string> &category = std::nullopt) = 0;

    virtual tl::expected<void, std::string> assign_to_entity(
        const std::string &entity_id,
        const std::string &tag_id,
        const std::optional<std::string> &entity_type = std::nullopt) = 0;
    virtual tl::expected<void, std::string> remove_from_entity(
        const std::string &entity_id,
        const std::string &tag_id,
        const std::optional<std::string> &entity_type = std::nullopt) = 0;
    virtual tl::expected<std::vector<Tag>, std::string> get_entity_tags(
        const std::string &entity_id,
        const std::optional<std::string> &entity_type = std::nullopt) = 0;
};

} // namespace lyra
