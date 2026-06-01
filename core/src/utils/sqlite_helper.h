/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <SQLiteCpp/SQLiteCpp.h>
#include <optional>

namespace lyra {
namespace SqliteHelper {

// Safely get SQLite column. If not null, return std::optional, else return std::nullopt
template <typename T>
inline std::optional<T> get_optional(SQLite::Statement &query, const char *column_name) {
    auto col = query.getColumn(column_name);
    if (col.isNull()) {
        return std::nullopt;
    }
    return static_cast<T>(col);
}

// Have a default value
template <typename T>
inline T get_safe(SQLite::Statement &query, const char *column_name, const T &default_val) {
    return get_optional<T>(query, column_name).value_or(default_val);
}

std::string escape_like(const std::string& input, char escape_char = '\\');

} // namespace SqliteHelper
} // namespace lyra
