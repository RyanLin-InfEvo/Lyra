// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include <string>
#include <tl/expected.hpp>
#include "../../models/work.h"

namespace lyra {

class IWorkRepository {
  public:
    virtual ~IWorkRepository() = default;

    virtual tl::expected<void, std::string> insert(const Work &work) = 0;
    virtual tl::expected<void, std::string> update(const WorkUpdate &update_data) = 0;
    virtual tl::expected<Work, std::string> get(const std::string &work_id) = 0;
};

} // namespace lyra
