// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../database_context.h"
#include "../i_work_repository.h"
#include "sqlite_entity_repository.h"

namespace lyra {

class SqliteWorkRepository : public IWorkRepository, public SqliteEntityRepository<Work, WorkUpdate> {
  public:
    explicit SqliteWorkRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Work &work) override;
    tl::expected<void, std::string> update(const WorkUpdate &update_data) override;
    tl::expected<Work, std::string> get(const std::string &work_id) override;
    tl::expected<PaginatedResult<Work>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) override;
    tl::expected<std::vector<Work>, std::string> get_by_title(const std::string &title) override;

    tl::expected<std::optional<Work>, std::string> get_by_iswc(const std::string &iswc) override;
    tl::expected<std::vector<Work>, std::string> get_by_musicbrainz_id(const std::string &musicbrainz_id) override;

  protected:
    tl::expected<void, std::string> do_insert(SQLite::Database &db, const Work &work) override;
    void build_update(SqliteUpdateBuilder &builder, const WorkUpdate &data) const override;
};

} // namespace lyra
