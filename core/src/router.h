/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>

namespace lyra {

using json = nlohmann::json;

class Router {
  public:
    static json route(const json &request);
};

} // namespace lyra
