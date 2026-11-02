/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_device_info.h"
#include <cassert>
#include <iostream>
#include <string>
#include <vector>

using namespace lyra;

bool test_valid_roundtrip() {
    std::cout << "Running test_valid_roundtrip..." << std::endl;
    AudioDeviceInfo info;
    info.id = "hw:0,0";
    info.name = "Built-in Audio";
    info.is_default = true;
    info.min_channels = 2;
    info.max_channels = 8;
    info.min_sample_rate = 44100;
    info.max_sample_rate = 192000;

    nlohmann::json j = info;
    assert(j["id"] == "hw:0,0");
    assert(j["name"] == "Built-in Audio");
    assert(j["is_default"] == true);
    assert(j["min_channels"] == 2);
    assert(j["max_channels"] == 8);
    assert(j["min_sample_rate"] == 44100);
    assert(j["max_sample_rate"] == 192000);

    auto parsed = j.get<AudioDeviceInfo>();
    assert(parsed.id == info.id);
    assert(parsed.name == info.name);
    assert(parsed.is_default == info.is_default);
    assert(parsed.min_channels == info.min_channels);
    assert(parsed.max_channels == info.max_channels);
    assert(parsed.min_sample_rate == info.min_sample_rate);
    assert(parsed.max_sample_rate == info.max_sample_rate);

    return true;
}

bool test_valid_partial() {
    std::cout << "Running test_valid_partial..." << std::endl;
    nlohmann::json empty_obj = nlohmann::json::object();
    auto parsed_empty = empty_obj.get<AudioDeviceInfo>();
    assert(parsed_empty.id.empty());
    assert(parsed_empty.name.empty());
    assert(!parsed_empty.is_default);
    assert(parsed_empty.min_channels == 1);
    assert(parsed_empty.max_channels == 2);
    assert(parsed_empty.min_sample_rate == 44100);
    assert(parsed_empty.max_sample_rate == 192000);

    nlohmann::json partial_obj = {{"id", "custom_id"}};
    auto parsed_partial = partial_obj.get<AudioDeviceInfo>();
    assert(parsed_partial.id == "custom_id");
    assert(parsed_partial.min_channels == 1);

    return true;
}

bool test_reject_non_object() {
    std::cout << "Running test_reject_non_object..." << std::endl;
    std::vector<std::string> non_objects = {
        "null",
        "123",
        "-45.6",
        "\"a string\"",
        "true",
        "false",
        "[]",
        "[1, 2, 3]"};

    for (const auto &raw : non_objects) {
        nlohmann::json j = nlohmann::json::parse(raw);
        bool threw = false;
        try {
            auto parsed = j.get<AudioDeviceInfo>();
            (void)parsed;
        } catch (const std::exception &e) {
            threw = true;
        }
        if (!threw) {
            std::cerr << "FAILED: non-object JSON failed to throw for input: " << raw << std::endl;
            return false;
        }
    }
    return true;
}

bool test_reject_null_fields() {
    std::cout << "Running test_reject_null_fields..." << std::endl;
    std::vector<std::pair<std::string, nlohmann::json>> null_cases = {
        {"id", {{"id", nullptr}}},
        {"name", {{"name", nullptr}}},
        {"is_default", {{"is_default", nullptr}}},
        {"min_channels", {{"min_channels", nullptr}}},
        {"max_channels", {{"max_channels", nullptr}}},
        {"min_sample_rate", {{"min_sample_rate", nullptr}}},
        {"max_sample_rate", {{"max_sample_rate", nullptr}}}};

    for (const auto &c : null_cases) {
        bool threw = false;
        try {
            auto parsed = c.second.get<AudioDeviceInfo>();
            (void)parsed;
        } catch (const std::exception &e) {
            threw = true;
        }
        if (!threw) {
            std::cerr << "FAILED: null field failed to throw for key: " << c.first << std::endl;
            return false;
        }
    }
    return true;
}

bool test_reject_invalid_field_types() {
    std::cout << "Running test_reject_invalid_field_types..." << std::endl;
    std::vector<std::pair<std::string, nlohmann::json>> invalid_type_cases = {
        {"id", {{"id", 123}}},
        {"id", {{"id", true}}},
        {"id", {{"id", nlohmann::json::array()}}},
        {"name", {{"name", 123}}},
        {"is_default", {{"is_default", "true"}}},
        {"is_default", {{"is_default", 1}}},
        {"min_channels", {{"min_channels", "2"}}},
        {"min_channels", {{"min_channels", true}}},
        {"max_channels", {{"max_channels", "8"}}},
        {"max_channels", {{"max_channels", nlohmann::json::array({8})}}},
        {"min_sample_rate", {{"min_sample_rate", "44100"}}},
        {"max_sample_rate", {{"max_sample_rate", "192000"}}}};

    for (const auto &c : invalid_type_cases) {
        bool threw = false;
        try {
            auto parsed = c.second.get<AudioDeviceInfo>();
            (void)parsed;
        } catch (const std::exception &e) {
            threw = true;
        }
        if (!threw) {
            std::cerr << "FAILED: invalid type failed to throw for key: " << c.first
                      << ", json: " << c.second.dump() << std::endl;
            return false;
        }
    }
    return true;
}

int main() {
    if (!test_valid_roundtrip()) return 1;
    if (!test_valid_partial()) return 1;
    if (!test_reject_non_object()) return 1;
    if (!test_reject_null_fields()) return 1;
    if (!test_reject_invalid_field_types()) return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
