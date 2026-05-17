// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../database_context.h"
#include "i_artist_repository.h"

namespace lyra {

class SqliteArtistRepository : public IArtistRepository {
  public:
    explicit SqliteArtistRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Artist &artist) override;
    tl::expected<void, std::string> update(const ArtistUpdate &update_data) override;
    tl::expected<Artist, std::string> get(const std::string &artist_id) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
