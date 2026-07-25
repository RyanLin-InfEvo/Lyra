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

namespace lyra {

enum class ErrorType {
    // 404 Series
    ArtistNotFound,
    TrackNotFound,
    AlbumNotFound,
    WorkNotFound,
    PlaylistNotFound,
    AssetNotFound,
    AudioNotFound,
    UnknownCommand,
    RelationNotFound,
    NotFound,
    // 400 Series
    MissingParameter,
    InvalidValue,
    InvalidCommandFormat,
    OutOfRange,
    Conflict,
    // 500 Series
    DatabaseError
};

struct Error {
    ErrorType type;
    std::string message;
};

class ApiResponse {
  public:
    // Success return
    static json success(const json &data);

    // Error return
    static json error(const Error &err);

  private:
    // Mapping 'Enum' to {code, type}
    static std::pair<int, std::string> getErrorMapping(ErrorType type);
};

} // namespace lyra
