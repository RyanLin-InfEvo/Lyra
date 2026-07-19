/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/uuid_generator.h"
#include <iostream>
#include <regex>
#include <string>
#include <unordered_set>

using namespace lyra;

bool test_uuid_v4_format() {
    std::cout << "Running test_uuid_v4_format..." << std::endl;

    // UUID v4 format regex:
    // xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx where y is [8, 9, a, b]
    static const std::regex uuid4_regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$");

    std::unordered_set<std::string> generated_uuids;

    for (int i = 0; i < 100; ++i) {
        std::string uuid = UuidGenerator::generate_v4();

        // 1. Check format
        if (!std::regex_match(uuid, uuid4_regex)) {
            std::cerr << "UUID v4 check failed for: " << uuid << std::endl;
            return false;
        }

        // 2. Check uniqueness (collision prevention)
        if (generated_uuids.count(uuid) > 0) {
            std::cerr << "UUID collision detected (extremely unlikely!): " << uuid << std::endl;
            return false;
        }
        generated_uuids.insert(uuid);
    }

    return true;
}

int main() {
    if (!test_uuid_v4_format()) {
        return 1;
    }

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
