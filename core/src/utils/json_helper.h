/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <cstdint>
#include <initializer_list>
#include <limits>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <string_view>

namespace lyra {

using json = nlohmann::json;

namespace JsonHelper {

// Returns pointer to non-null JSON value for key if j is an object, else nullptr (single lookup).
inline const json *find_value(const json &j, std::string_view key) {
    if (!j.is_object()) {
        return nullptr;
    }
    if (auto it = j.find(key); it != j.end() && !it->is_null()) {
        return &(*it);
    }
    return nullptr;
}

// Prevent dangling pointer into a temporary json rvalue.
const json *find_value(const json &&, std::string_view) = delete;

inline bool has_value(const json &j, std::string_view key) {
    return find_value(j, key) != nullptr;
}

// Safely converts a JSON integer (signed or unsigned) to int64_t without uint64_t wraparound.
// Returns std::nullopt if val is not a JSON integer or if an unsigned JSON integer exceeds INT64_MAX.
inline std::optional<int64_t> try_get_int64(const json &val) {
    if (val.is_number_unsigned()) {
        const uint64_t u = val.get<uint64_t>();
        if (u > static_cast<uint64_t>(std::numeric_limits<int64_t>::max())) {
            return std::nullopt;
        }
        return static_cast<int64_t>(u);
    }
    if (val.is_number_integer()) {
        return val.get<int64_t>();
    }
    return std::nullopt;
}

// Get non-null JSON field as std::optional<T>, else std::nullopt.
// Precondition: callers must pre-validate JSON types (e.g., via JsonValidator);
// mismatched JSON types will throw nlohmann::json::type_error.
template <typename T>
inline std::optional<T> get_optional(const json &j, std::string_view key) {
    if (const json *val = find_value(j, key)) {
        return val->get<T>();
    }
    return std::nullopt;
}

// Get non-null JSON field as T, or default_val if missing or null.
// Precondition: callers must pre-validate JSON types (e.g., via JsonValidator);
// mismatched JSON types will throw nlohmann::json::type_error.
template <typename T>
inline T get_safe(const json &j, std::string_view key, const T &default_val) {
    return get_optional<T>(j, key).value_or(default_val);
}

// Return the first non-null value matching keys in priority order.
// Precondition: callers must pre-validate JSON types (e.g., via JsonValidator);
// mismatched JSON types will throw nlohmann::json::type_error.
template <typename T>
inline std::optional<T> get_first_optional(const json &j, std::initializer_list<std::string_view> keys) {
    for (std::string_view key : keys) {
        if (const json *val = find_value(j, key)) {
            return val->get<T>();
        }
    }
    return std::nullopt;
}

// Assigns j[key] to dst if key exists and is non-null; leaves dst unchanged otherwise.
// Precondition: callers must pre-validate JSON types (e.g., via JsonValidator);
// mismatched JSON types will throw nlohmann::json::type_error.
template <typename T>
inline void assign_if_present(T &dst, const json &j, std::string_view key) {
    if (const json *val = find_value(j, key)) {
        dst = val->get<T>();
    }
}

template <typename T>
inline void assign_if_present(std::optional<T> &dst, const json &j, std::string_view key) {
    if (const json *val = find_value(j, key)) {
        dst = val->get<T>();
    }
}

} // namespace JsonHelper

} // namespace lyra
