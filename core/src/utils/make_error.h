/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>
#include <string>
#include <utility>

using json = nlohmann::json;

enum class ErrorType {
    // 404 Series
    ArtistNotFound,
    TrackNotFound,

    // 400 Series
    MissingParameter,
    InvalidValue,

    // 500 Series
    DatabaseError
};

class ApiResponse {
  public:
    // Success return
    static json success(const json &data);

    // Error return
    static json error(ErrorType type, const std::string &msg);

  private:
    // Mapping 'Enum' to {code, type}
    static std::pair<int, std::string> getErrorMapping(ErrorType type);
};
