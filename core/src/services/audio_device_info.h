/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>
#include <string>
#include <type_traits>
#include <vector>

namespace lyra {

constexpr uint32_t DEFAULT_BUFFER_SIZE_FRAMES = 256;
constexpr uint32_t MIN_BUFFER_SIZE_FRAMES = 32;
constexpr uint32_t MAX_BUFFER_SIZE_FRAMES = 8192;

struct AudioDeviceInfo {
    std::string id;
    std::string name;
    bool is_default{false};
    int min_channels{1};
    int max_channels{2};
    int min_sample_rate{44100};
    int max_sample_rate{192000};
};

inline void to_json(nlohmann::json &j, const AudioDeviceInfo &info) {
    j = nlohmann::json{
        {"id", info.id},
        {"name", info.name},
        {"is_default", info.is_default},
        {"min_channels", info.min_channels},
        {"max_channels", info.max_channels},
        {"min_sample_rate", info.min_sample_rate},
        {"max_sample_rate", info.max_sample_rate}};
}

namespace detail {
template <typename T>
inline void parse_field(const nlohmann::json &j, const char *key, T &target) {
    if (!j.contains(key)) return;
    const auto &val = j[key];
    if (val.is_null()) {
        throw nlohmann::json::type_error::create(
            302, std::string("field '") + key + "' must not be null", &j);
    }
    if constexpr (std::is_same_v<T, std::string>) {
        if (!val.is_string()) {
            throw nlohmann::json::type_error::create(
                302, std::string("field '") + key + "' must be string, but is " + val.type_name(), &j);
        }
    } else if constexpr (std::is_same_v<T, bool>) {
        if (!val.is_boolean()) {
            throw nlohmann::json::type_error::create(
                302, std::string("field '") + key + "' must be boolean, but is " + val.type_name(), &j);
        }
    } else if constexpr (std::is_integral_v<T>) {
        if (!val.is_number_integer()) {
            throw nlohmann::json::type_error::create(
                302, std::string("field '") + key + "' must be integer, but is " + val.type_name(), &j);
        }
    }
    target = val.get<T>();
}
} // namespace detail

inline void from_json(const nlohmann::json &j, AudioDeviceInfo &info) {
    if (!j.is_object()) {
        throw nlohmann::json::type_error::create(
            302, "type must be object, but is " + std::string(j.type_name()), &j);
    }

    detail::parse_field(j, "id", info.id);
    detail::parse_field(j, "name", info.name);
    detail::parse_field(j, "is_default", info.is_default);
    detail::parse_field(j, "min_channels", info.min_channels);
    detail::parse_field(j, "max_channels", info.max_channels);
    detail::parse_field(j, "min_sample_rate", info.min_sample_rate);
    detail::parse_field(j, "max_sample_rate", info.max_sample_rate);
}

} // namespace lyra
