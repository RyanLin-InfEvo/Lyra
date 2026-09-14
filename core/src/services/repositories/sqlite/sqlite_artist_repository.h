// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../database_context.h"
#include "../i_artist_repository.h"
#include "sqlite_entity_repository.h"

namespace lyra {

class SqliteArtistRepository : public IArtistRepository, public SqliteEntityRepository<Artist, ArtistUpdate> {
  public:
    explicit SqliteArtistRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Artist &artist) override;
    tl::expected<void, std::string> update(const ArtistUpdate &update_data) override;
    tl::expected<Artist, std::string> get(const std::string &artist_id) override;
    tl::expected<PaginatedResult<Artist>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) override;
    tl::expected<std::vector<Artist>, std::string> get_by_name(const std::string &name) override;

  protected:
    tl::expected<void, std::string> do_insert(SQLite::Database &db, const Artist &artist) override;
    void build_update(SqliteUpdateBuilder &builder, const ArtistUpdate &data) const override;
};

} // namespace lyra
