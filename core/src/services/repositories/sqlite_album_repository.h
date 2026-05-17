// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../database_context.h"
#include "i_album_repository.h"

namespace lyra {

class SqliteAlbumRepository : public IAlbumRepository {
  public:
    explicit SqliteAlbumRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const Album &album) override;
    tl::expected<void, std::string> update(const AlbumUpdate &update_data) override;
    tl::expected<Album, std::string> get(const std::string &album_id) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
