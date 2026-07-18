/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/sqlite_helper.h"
#include <cassert>
#include <iostream>
#include <string>

using namespace lyra::SqliteHelper;

bool test_escape_like_default_escape() {
    std::cout << "Running test_escape_like_default_escape..." << std::endl;

    // Test 1: Empty string
    if (escape_like("") != "") {
        std::cerr << "Test 1 failed: empty string" << std::endl;
        return false;
    }

    // Test 2: Standard string without special characters
    if (escape_like("hello") != "hello") {
        std::cerr << "Test 2 failed: standard string" << std::endl;
        return false;
    }

    // Test 3: String with '%'
    if (escape_like("hello%world") != "hello\\%world") {
        std::cerr << "Test 3 failed: percentage character" << std::endl;
        return false;
    }

    // Test 4: String with '_'
    if (escape_like("hello_world") != "hello\\_world") {
        std::cerr << "Test 4 failed: underscore character" << std::endl;
        return false;
    }

    // Test 5: String with '\\'
    if (escape_like("hello\\world") != "hello\\\\world") {
        std::cerr << "Test 5 failed: escape character itself" << std::endl;
        return false;
    }

    // Test 6: String with multiple special characters
    if (escape_like("%_\\") != "\\%\\_\\\\") {
        std::cerr << "Test 6 failed: multiple special characters" << std::endl;
        return false;
    }

    return true;
}

bool test_escape_like_custom_escape() {
    std::cout << "Running test_escape_like_custom_escape..." << std::endl;

    // Test 1: Empty string with custom escape '/'
    if (escape_like("", '/') != "") {
        std::cerr << "Test 1 failed: empty string" << std::endl;
        return false;
    }

    // Test 2: Standard string with custom escape '/'
    if (escape_like("hello", '/') != "hello") {
        std::cerr << "Test 2 failed: standard string" << std::endl;
        return false;
    }

    // Test 3: String with '%' with custom escape '/'
    if (escape_like("hello%world", '/') != "hello/%world") {
        std::cerr << "Test 3 failed: percentage character" << std::endl;
        return false;
    }

    // Test 4: String with '_' with custom escape '/'
    if (escape_like("hello_world", '/') != "hello/_world") {
        std::cerr << "Test 4 failed: underscore character" << std::endl;
        return false;
    }

    // Test 5: String with '\\' with custom escape '/' (should NOT be escaped)
    if (escape_like("hello\\world", '/') != "hello\\world") {
        std::cerr << "Test 5 failed: backslash character (should not be escaped)" << std::endl;
        return false;
    }

    // Test 6: String with '/' with custom escape '/' (should be escaped)
    if (escape_like("hello/world", '/') != "hello//world") {
        std::cerr << "Test 6 failed: custom escape character itself" << std::endl;
        return false;
    }

    // Test 7: Multiple special characters with custom escape '/'
    if (escape_like("%_/", '/') != "/%/_//") {
        std::cerr << "Test 7 failed: multiple special characters" << std::endl;
        return false;
    }

    return true;
}

int main() {
    if (!test_escape_like_default_escape())
        return 1;
    if (!test_escape_like_custom_escape())
        return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
