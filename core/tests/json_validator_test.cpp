/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/json_validator.h"
#include <cassert>
#include <iostream>
#include <string>
#include <vector>

using namespace lyra;
using Type = JsonFieldType;

bool test_boolean() {
    std::cout << "Running test_boolean..." << std::endl;

    // Rule: is_active is required Boolean
    std::vector<ValidationRule> rules = {
        {"is_active", Type::Boolean, true}};

    // Case 1: Valid boolean (true)
    json params1 = {{"is_active", true}};
    auto err1 = JsonValidator::validate(params1, rules);
    if (err1.has_value()) {
        std::cerr << "test_boolean Case 1 failed: " << err1.value().dump() << std::endl;
        return false;
    }

    // Case 2: Valid boolean (false)
    json params2 = {{"is_active", false}};
    auto err2 = JsonValidator::validate(params2, rules);
    if (err2.has_value()) {
        std::cerr << "test_boolean Case 2 failed: " << err2.value().dump() << std::endl;
        return false;
    }

    // Case 3: Invalid type (String instead of Boolean)
    json params3 = {{"is_active", "true"}};
    auto err3 = JsonValidator::validate(params3, rules);
    if (!err3.has_value()) {
        std::cerr << "test_boolean Case 3 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 4: Missing required field
    json params4 = json::object();
    auto err4 = JsonValidator::validate(params4, rules);
    if (!err4.has_value()) {
        std::cerr << "test_boolean Case 4 failed: expected error, got success" << std::endl;
        return false;
    }

    return true;
}

bool test_array() {
    std::cout << "Running test_array..." << std::endl;

    // Rule: tags is optional Array
    std::vector<ValidationRule> rules = {
        {"tags", Type::Array, false}};

    // Case 1: Valid array
    json params1 = {{"tags", {"rock", "pop"}}};
    auto err1 = JsonValidator::validate(params1, rules);
    if (err1.has_value()) {
        std::cerr << "test_array Case 1 failed: " << err1.value().dump() << std::endl;
        return false;
    }

    // Case 2: Empty array
    json params2 = {{"tags", json::array()}};
    auto err2 = JsonValidator::validate(params2, rules);
    if (err2.has_value()) {
        std::cerr << "test_array Case 2 failed: " << err2.value().dump() << std::endl;
        return false;
    }

    // Case 3: Missing optional field (should pass)
    json params3 = json::object();
    auto err3 = JsonValidator::validate(params3, rules);
    if (err3.has_value()) {
        std::cerr << "test_array Case 3 failed: " << err3.value().dump() << std::endl;
        return false;
    }

    // Case 4: Invalid type (Object instead of Array)
    json params4 = {{"tags", {{"key", "value"}}}};
    auto err4 = JsonValidator::validate(params4, rules);
    if (!err4.has_value()) {
        std::cerr << "test_array Case 4 failed: expected error, got success" << std::endl;
        return false;
    }

    return true;
}

bool test_nested_object() {
    std::cout << "Running test_nested_object..." << std::endl;

    // Rule: meta is required Object, containing required child author (String)
    std::vector<ValidationRule> rules = {
        {"meta", Type::Object, true, StringFormat::Any, std::nullopt, std::nullopt, {{"author", Type::String, true}}}};

    // Case 1: Valid nested object
    json params1 = {{"meta", {{"author", "John Doe"}}}};
    auto err1 = JsonValidator::validate(params1, rules);
    if (err1.has_value()) {
        std::cerr << "test_nested_object Case 1 failed: " << err1.value().dump() << std::endl;
        return false;
    }

    // Case 2: Nested object with missing required child field
    json params2 = {{"meta", json::object()}};
    auto err2 = JsonValidator::validate(params2, rules);
    if (!err2.has_value()) {
        std::cerr << "test_nested_object Case 2 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 3: Nested object with invalid child field type
    json params3 = {{"meta", {{"author", 123}}}};
    auto err3 = JsonValidator::validate(params3, rules);
    if (!err3.has_value()) {
        std::cerr << "test_nested_object Case 3 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 4: Invalid type for meta itself (String instead of Object)
    json params4 = {{"meta", "John Doe"}};
    auto err4 = JsonValidator::validate(params4, rules);
    if (!err4.has_value()) {
        std::cerr << "test_nested_object Case 4 failed: expected error, got success" << std::endl;
        return false;
    }

    return true;
}

bool test_string_length_limits() {
    std::cout << "Running test_string_length_limits..." << std::endl;

    // Rule: code is required String, min_length 3, max_length 6
    std::vector<ValidationRule> rules = {
        {"code", Type::String, true, StringFormat::Any, 3, 6}};

    // Case 1: Valid length (5 characters)
    json params1 = {{"code", "ABCDE"}};
    auto err1 = JsonValidator::validate(params1, rules);
    if (err1.has_value()) {
        std::cerr << "test_string_length_limits Case 1 failed: " << err1.value().dump() << std::endl;
        return false;
    }

    // Case 2: Exact minimum (3 characters)
    json params2 = {{"code", "ABC"}};
    auto err2 = JsonValidator::validate(params2, rules);
    if (err2.has_value()) {
        std::cerr << "test_string_length_limits Case 2 failed: " << err2.value().dump() << std::endl;
        return false;
    }

    // Case 3: Exact maximum (6 characters)
    json params3 = {{"code", "ABCDEF"}};
    auto err3 = JsonValidator::validate(params3, rules);
    if (err3.has_value()) {
        std::cerr << "test_string_length_limits Case 3 failed: " << err3.value().dump() << std::endl;
        return false;
    }

    // Case 4: Too short (2 characters)
    json params4 = {{"code", "AB"}};
    auto err4 = JsonValidator::validate(params4, rules);
    if (!err4.has_value()) {
        std::cerr << "test_string_length_limits Case 4 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 5: Too long (7 characters)
    json params5 = {{"code", "ABCDEFG"}};
    auto err5 = JsonValidator::validate(params5, rules);
    if (!err5.has_value()) {
        std::cerr << "test_string_length_limits Case 5 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 6: Empty string (should fail)
    json params6 = {{"code", ""}};
    auto err6 = JsonValidator::validate(params6, rules);
    if (!err6.has_value()) {
        std::cerr << "test_string_length_limits Case 6 failed: expected error, got success" << std::endl;
        return false;
    }

    return true;
}

bool test_number() {
    std::cout << "Running test_number..." << std::endl;

    // Rule: value is required Number (Double/Float/Int)
    std::vector<ValidationRule> rules = {
        {"value", Type::Number, true}};

    // Case 1: Valid number (double)
    json params1 = {{"value", 3.14}};
    auto err1 = JsonValidator::validate(params1, rules);
    if (err1.has_value()) {
        std::cerr << "test_number Case 1 failed: " << err1.value().dump() << std::endl;
        return false;
    }

    // Case 2: Valid number (integer is also a valid number)
    json params2 = {{"value", 42}};
    auto err2 = JsonValidator::validate(params2, rules);
    if (err2.has_value()) {
        std::cerr << "test_number Case 2 failed: " << err2.value().dump() << std::endl;
        return false;
    }

    // Case 3: Invalid type (String instead of Number)
    json params3 = {{"value", "3.14"}};
    auto err3 = JsonValidator::validate(params3, rules);
    if (!err3.has_value()) {
        std::cerr << "test_number Case 3 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 4: Invalid type (Boolean instead of Number)
    json params4 = {{"value", true}};
    auto err4 = JsonValidator::validate(params4, rules);
    if (!err4.has_value()) {
        std::cerr << "test_number Case 4 failed: expected error, got success" << std::endl;
        return false;
    }

    return true;
}

bool test_invalid_json_format() {
    std::cout << "Running test_invalid_json_format..." << std::endl;

    // Params is not an object
    json params = json::array({1, 2, 3});
    std::vector<ValidationRule> rules = {
        {"key", Type::String, true}};

    auto err = JsonValidator::validate(params, rules);
    if (!err.has_value()) {
        std::cerr << "test_invalid_json_format failed: expected error for non-object parameters" << std::endl;
        return false;
    }

    return true;
}

int main() {
    if (!test_boolean()) return 1;
    if (!test_array()) return 1;
    if (!test_nested_object()) return 1;
    if (!test_string_length_limits()) return 1;
    if (!test_number()) return 1;
    if (!test_invalid_json_format()) return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
