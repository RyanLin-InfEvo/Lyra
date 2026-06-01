// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <string>
#include <tl/expected.hpp>
#include <optional>
#include "../../models/work.h"
#include "../../utils/paginated_result.h"

namespace lyra {

class IWorkRepository {
  public:
    virtual ~IWorkRepository() = default;

    virtual tl::expected<void, std::string> insert(const Work &work) = 0;
    virtual tl::expected<void, std::string> update(const WorkUpdate &update_data) = 0;
    virtual tl::expected<Work, std::string> get(const std::string &work_id) = 0;
    virtual tl::expected<PaginatedResult<Work>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) = 0;
};

} // namespace lyra
