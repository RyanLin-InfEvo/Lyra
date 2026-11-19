// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/source_data.h"
#include "../services/repositories/i_source_data_repository.h"
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

class SourceDataController {
  public:
    explicit SourceDataController(ISourceDataRepository &repo);

    tl::expected<void, std::string> create(SourceData &source_data);
    tl::expected<SourceData, std::string> get(const std::string &id);
    tl::expected<SourceData, std::string> get_by_asset(const std::string &file_hash);
    tl::expected<std::vector<SourceData>, std::string> list_by_asset(const std::string &file_hash);

  private:
    ISourceDataRepository &m_repo;
};

} // namespace lyra
