// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../database_context.h"
#include "../i_tag_repository.h"
#include "sqlite_entity_repository.h"

namespace lyra {

class SqliteTagRepository : public ITagRepository, public SqliteEntityRepository<Tag, TagUpdate> {
  public:
    explicit SqliteTagRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Tag &tag) override;
    tl::expected<void, std::string> update(const TagUpdate &update_data) override;
    tl::expected<Tag, std::string> get(const std::string &tag_id) override;
    tl::expected<void, std::string> delete_tag(const std::string &tag_id) override;
    tl::expected<PaginatedResult<Tag>, std::string> list(
        int offset,
        int limit,
        const std::optional<std::string> &search,
        const std::optional<std::string> &category = std::nullopt) override;

    tl::expected<void, std::string> assign_to_entity(
        const std::string &entity_id,
        const std::string &tag_id,
        const std::optional<std::string> &entity_type = std::nullopt) override;
    tl::expected<void, std::string> remove_from_entity(
        const std::string &entity_id,
        const std::string &tag_id,
        const std::optional<std::string> &entity_type = std::nullopt) override;
    tl::expected<std::vector<Tag>, std::string> get_entity_tags(
        const std::string &entity_id,
        const std::optional<std::string> &entity_type = std::nullopt) override;

  protected:
    tl::expected<void, std::string> do_insert(SQLite::Database &db, const Tag &tag) override;
    void build_update(SqliteUpdateBuilder &builder, const TagUpdate &data) const override;
};

} // namespace lyra
