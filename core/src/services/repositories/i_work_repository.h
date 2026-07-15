// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../../models/work.h"
#include "../../utils/paginated_result.h"
#include <optional>
#include <string>
#include <tl/expected.hpp>

namespace lyra {

class IWorkRepository {
  public:
    virtual ~IWorkRepository() = default;

    virtual tl::expected<void, std::string> insert(const Work &work) = 0;
    virtual tl::expected<void, std::string> update(const WorkUpdate &update_data) = 0;
    virtual tl::expected<Work, std::string> get(const std::string &work_id) = 0;
    virtual tl::expected<PaginatedResult<Work>, std::string> list(
        int offset, int limit, const std::optional<std::string> &search) = 0;
    virtual tl::expected<std::vector<Work>, std::string> get_by_title(const std::string &title) = 0;
};

} // namespace lyra
