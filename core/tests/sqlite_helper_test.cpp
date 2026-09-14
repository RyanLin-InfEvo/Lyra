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

bool test_quote_identifier() {
    std::cout << "Running test_quote_identifier..." << std::endl;

    // Test 1: Empty string
    if (quote_identifier("") != "\"\"") {
        std::cerr << "Test 1 failed: empty string" << std::endl;
        return false;
    }

    // Test 2: Standard identifiers
    if (quote_identifier("Album") != "\"Album\"") {
        std::cerr << "Test 2 failed: standard identifier 'Album'" << std::endl;
        return false;
    }
    if (quote_identifier("created_at") != "\"created_at\"") {
        std::cerr << "Test 2b failed: snake_case identifier 'created_at'" << std::endl;
        return false;
    }

    // Test 3: SQLite keywords
    if (quote_identifier("order") != "\"order\"") {
        std::cerr << "Test 3 failed: keyword 'order'" << std::endl;
        return false;
    }
    if (quote_identifier("group") != "\"group\"") {
        std::cerr << "Test 3b failed: keyword 'group'" << std::endl;
        return false;
    }
    if (quote_identifier("table") != "\"table\"") {
        std::cerr << "Test 3c failed: keyword 'table'" << std::endl;
        return false;
    }
    if (quote_identifier("select") != "\"select\"") {
        std::cerr << "Test 3d failed: keyword 'select'" << std::endl;
        return false;
    }

    // Test 4: Strings containing double quotes
    if (quote_identifier("my\"column") != "\"my\"\"column\"") {
        std::cerr << "Test 4 failed: string containing double quotes" << std::endl;
        return false;
    }
    if (quote_identifier("\"already_quoted\"") != "\"\"\"already_quoted\"\"\"") {
        std::cerr << "Test 4b failed: string with leading/trailing quotes" << std::endl;
        return false;
    }
    if (quote_identifier("\"") != "\"\"\"\"") {
        std::cerr << "Test 4c failed: single quote character" << std::endl;
        return false;
    }

    return true;
}

int main() {
    if (!test_escape_like_default_escape())
        return 1;
    if (!test_escape_like_custom_escape())
        return 1;
    if (!test_quote_identifier())
        return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
