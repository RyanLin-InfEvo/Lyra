/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <SQLiteCpp/SQLiteCpp.h>
#include <concepts>
#include <cstring>
#include <optional>
#include <string>
#include <type_traits>
#include <vector>

namespace lyra {
namespace SqliteHelper {

// Check if a statement's result columns include the specified column name
inline bool has_column(SQLite::Statement &query, const char *column_name) {
    const int count = query.getColumnCount();
    for (int i = 0; i < count; ++i) {
        if (std::strcmp(query.getColumnName(i), column_name) == 0) {
            return true;
        }
    }
    return false;
}

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

std::string escape_like(const std::string &input, char escape_char = '\\');

// Query helper template: fetch a single mapped row
template <typename Mapper>
    requires std::invocable<Mapper, SQLite::Statement &>
inline auto fetch_one(SQLite::Statement &query, Mapper &&mapper) {
    using ResultType = std::decay_t<std::invoke_result_t<Mapper, SQLite::Statement &>>;
    if (query.executeStep()) {
        return std::optional<ResultType>(mapper(query));
    }
    return std::optional<ResultType>(std::nullopt);
}

// Query helper template: fetch all mapped rows into a std::vector
template <typename Mapper>
    requires std::invocable<Mapper, SQLite::Statement &>
inline auto fetch_all(SQLite::Statement &query, Mapper &&mapper, size_t reserve_count = 0) {
    using ResultType = std::decay_t<std::invoke_result_t<Mapper, SQLite::Statement &>>;
    std::vector<ResultType> items;
    if (reserve_count > 0) {
        items.reserve(reserve_count);
    }
    while (query.executeStep()) {
        items.push_back(mapper(query));
    }
    return items;
}

} // namespace SqliteHelper
} // namespace lyra
