// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../database_context.h"
#include "../i_source_data_repository.h"

namespace lyra {

class SqliteSourceDataRepository : public ISourceDataRepository {
  public:
    explicit SqliteSourceDataRepository(IDatabaseContext &context);

    tl::expected<void, std::string> insert(const SourceData &source_data) override;
    tl::expected<SourceData, std::string> get(const std::string &id) override;
    tl::expected<SourceData, std::string> get_by_asset(const std::string &file_hash) override;
    tl::expected<std::vector<SourceData>, std::string> list_by_asset(const std::string &file_hash) override;

  private:
    IDatabaseContext &m_context;
};

} // namespace lyra
