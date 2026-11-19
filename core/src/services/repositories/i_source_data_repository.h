// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/source_data.h"
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

class ISourceDataRepository {
  public:
    virtual ~ISourceDataRepository() = default;

    virtual tl::expected<void, std::string> insert(const SourceData &source_data) = 0;
    virtual tl::expected<SourceData, std::string> get(const std::string &id) = 0;
    virtual tl::expected<SourceData, std::string> get_by_asset(const std::string &file_hash) = 0;
    virtual tl::expected<std::vector<SourceData>, std::string> list_by_asset(const std::string &file_hash) = 0;
};

} // namespace lyra
