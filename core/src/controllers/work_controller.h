// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#pragma once

#include "../models/work.h"
#include "../services/repositories/i_work_repository.h"
#include <nlohmann/json.hpp>
#include <tl/expected.hpp>

namespace lyra {

using json = nlohmann::json;

class WorkController {
  public:
    explicit WorkController(IWorkRepository &repo);

    tl::expected<void, std::string> create(Work &work);
    tl::expected<Work, std::string> get(const std::string &id);
    tl::expected<void, std::string> update(const WorkUpdate &work_update);

  private:
    IWorkRepository &m_repo;
};

} // namespace lyra
