/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "../models/work.h"
#include <nlohmann/json.hpp>

namespace lyra {

class WorkController {
  public:
    // Create Work
    static std::optional<std::string> create(Work &work);

    // Get Work
    static std::optional<Work> get(const std::string &id);

    // Update Work
    static std::optional<std::string> update(const WorkUpdate &work_update);
};

} // namespace lyra
