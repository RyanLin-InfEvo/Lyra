/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>

using json = nlohmann::json;

class TrackController {
  public:
    // Create Track
    static json create(const json &params);

    // Get Track
    static json get(const json &params);

    static json update(const json &params);
};
