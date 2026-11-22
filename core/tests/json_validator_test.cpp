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

bool test_month_and_day() {
    std::cout << "Running test_month_and_day..." << std::endl;

    std::vector<ValidationRule> rules = {
        {"month", Type::Month, true},
        {"day", Type::Day, true}};

    // Case 1: Valid Month and Day (e.g. 12 and 31)
    json params1 = {{"month", 12}, {"day", 31}};
    auto err1 = JsonValidator::validate(params1, rules);
    if (err1.has_value()) {
        std::cerr << "test_month_and_day Case 1 failed: " << err1.value().dump() << std::endl;
        return false;
    }

    // Case 2: Valid Month and Day (e.g. 1 and 1)
    json params2 = {{"month", 1}, {"day", 1}};
    auto err2 = JsonValidator::validate(params2, rules);
    if (err2.has_value()) {
        std::cerr << "test_month_and_day Case 2 failed: " << err2.value().dump() << std::endl;
        return false;
    }

    // Case 3: Invalid Month (0)
    json params3 = {{"month", 0}, {"day", 15}};
    auto err3 = JsonValidator::validate(params3, rules);
    if (!err3.has_value()) {
        std::cerr << "test_month_and_day Case 3 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 4: Invalid Month (13)
    json params4 = {{"month", 13}, {"day", 15}};
    auto err4 = JsonValidator::validate(params4, rules);
    if (!err4.has_value()) {
        std::cerr << "test_month_and_day Case 4 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 5: Invalid Day (0)
    json params5 = {{"month", 6}, {"day", 0}};
    auto err5 = JsonValidator::validate(params5, rules);
    if (!err5.has_value()) {
        std::cerr << "test_month_and_day Case 5 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 6: Invalid Day (32)
    json params6 = {{"month", 6}, {"day", 32}};
    auto err6 = JsonValidator::validate(params6, rules);
    if (!err6.has_value()) {
        std::cerr << "test_month_and_day Case 6 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 7: Invalid Month Type (Double)
    json params7 = {{"month", 6.5}, {"day", 15}};
    auto err7 = JsonValidator::validate(params7, rules);
    if (!err7.has_value()) {
        std::cerr << "test_month_and_day Case 7 failed: expected error, got success" << std::endl;
        return false;
    }

    // Case 8: Invalid Day Type (String)
    json params8 = {{"month", 6}, {"day", "15"}};
    auto err8 = JsonValidator::validate(params8, rules);
    if (!err8.has_value()) {
        std::cerr << "test_month_and_day Case 8 failed: expected error, got success" << std::endl;
        return false;
    }

    return true;
}

bool test_string_format_utf8_and_control_chars() {
    std::cout << "Running test_string_format_utf8_and_control_chars..." << std::endl;

    auto assert_invalid_value = [](const std::optional<json> &err, const std::string &label) -> bool {
        if (!err.has_value()) {
            std::cerr << "FAILED (" << label << "): expected error, got success" << std::endl;
            return false;
        }
        if (err->value("code", 0) != 400) {
            std::cerr << "FAILED (" << label << "): expected code 400, got " << err->dump() << std::endl;
            return false;
        }
        if (!err->contains("error") || !(*err)["error"].is_object() ||
            (*err)["error"].value("type", "") != "InvalidValue") {
            std::cerr << "FAILED (" << label << "): expected InvalidValue, got " << err->dump() << std::endl;
            return false;
        }
        return true;
    };

    // 1. StringFormat::SingleLineText
    std::vector<ValidationRule> single_rules = {
        {"label", Type::String, true, StringFormat::SingleLineText}};
    for (const std::string &valid : {
             std::string("zh-TW"),
             std::string("繁體中文 🎵"),
             std::string("\xC2\xA0"),
             std::string("\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7\xE2\x80\x8D\xF0\x9F\x91\xA6"),
         }) {
        json p = {{"label", valid}};
        auto err = JsonValidator::validate(p, single_rules);
        if (err.has_value()) {
            std::cerr << "SingleLineText rejected valid input: " << err->dump() << std::endl;
            return false;
        }
    }
    const std::vector<std::pair<std::string, std::string>> bad_single = {
        {"NUL", std::string("a\0b", 3)},
        {"tab", "a\tb"},
        {"LF", "a\nb"},
        {"CR", "a\rb"},
        {"SOH", "a\x01"
                "b"},
        {"ESC", "a\x1b"
                "b"},
        {"DEL", "a\x7f"
                "b"},
        {"C1_0080", "a\xC2\x80"
                    "b"},
        {"C1_0085", "a\xC2\x85"
                    "b"},
        {"C1_009F", "a\xC2\x9F"
                    "b"},
        {"invalid_byte", "\xFF"},
        {"overlong_3byte", "\xE0\x9F\xBF"},
        {"surrogate", "\xED\xA0\x80"},
        {"above_max_codepoint", "\xF4\x90\x80\x80"},
        {"truncated_3byte", "\xE0\xA0"},
    };
    for (const auto &[name, val] : bad_single) {
        json p = {{"label", val}};
        if (!assert_invalid_value(JsonValidator::validate(p, single_rules), "SingleLineText/" + name)) {
            return false;
        }
    }

    // 2. StringFormat::MultilineText
    std::vector<ValidationRule> multi_rules = {
        {"body", Type::String, true, StringFormat::MultilineText}};
    for (const std::string &valid : {
             std::string("line1\tword\nline2\r\nline3\rline4"),
             std::string("\xEF\xBB\xBF\xC2\xA0\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9"),
         }) {
        json p = {{"body", valid}};
        auto err = JsonValidator::validate(p, multi_rules);
        if (err.has_value()) {
            std::cerr << "MultilineText rejected valid input: " << err->dump() << std::endl;
            return false;
        }
    }
    const std::vector<std::pair<std::string, std::string>> bad_multi = {
        {"NUL", std::string("a\0b", 3)},
        {"SOH", "a\x01"
                "b"},
        {"VT", "a\x0b"
               "b"},
        {"FF", "a\x0c"
               "b"},
        {"ESC", "a\x1b"
                "b"},
        {"DEL", "a\x7f"
                "b"},
        {"C1_0080", "a\xC2\x80"
                    "b"},
        {"C1_0085", "a\xC2\x85"
                    "b"},
        {"C1_0092", "a\xC2\x92"
                    "b"},
        {"C1_009F", "a\xC2\x9F"
                    "b"},
        {"invalid_byte", "\xFF"},
        {"truncated_3byte", "\xE0\xA0"},
    };
    for (const auto &[name, val] : bad_multi) {
        json p = {{"body", val}};
        if (!assert_invalid_value(JsonValidator::validate(p, multi_rules), "MultilineText/" + name)) {
            return false;
        }
    }

    // 3. Empty string rejected for SingleLineText and MultilineText
    if (!assert_invalid_value(JsonValidator::validate(json{{"label", ""}}, single_rules), "SingleLineText/empty")) {
        return false;
    }
    if (!assert_invalid_value(JsonValidator::validate(json{{"body", ""}}, multi_rules), "MultilineText/empty")) {
        return false;
    }

    // 4. Wrong JSON types rejected safely (type_valid before get_ref)
    for (const json &wrong : {json(123), json(true), json::array(), json::object()}) {
        if (!assert_invalid_value(JsonValidator::validate(json{{"label", wrong}}, single_rules),
                                  "SingleLineText/wrong_type")) {
            return false;
        }
        if (!assert_invalid_value(JsonValidator::validate(json{{"body", wrong}}, multi_rules),
                                  "MultilineText/wrong_type")) {
            return false;
        }
    }

    // 5. Combined min_length / max_length with SingleLineText and MultilineText
    std::vector<ValidationRule> bounded_single = {
        {"label", Type::String, true, StringFormat::SingleLineText, 2, 5}};
    if (JsonValidator::validate(json{{"label", "ok"}}, bounded_single).has_value()) {
        std::cerr << "Bounded SingleLineText rejected valid input" << std::endl;
        return false;
    }
    if (!assert_invalid_value(JsonValidator::validate(json{{"label", "a"}}, bounded_single),
                              "BoundedSingle/too_short")) {
        return false;
    }
    if (!assert_invalid_value(JsonValidator::validate(json{{"label", "a\x1b"
                                                                     "b"}},
                                                      bounded_single),
                              "BoundedSingle/control_char")) {
        return false;
    }
    std::vector<ValidationRule> bounded_multi = {
        {"body", Type::String, true, StringFormat::MultilineText, 3, 10}};
    if (JsonValidator::validate(json{{"body", "a\nb\tc"}}, bounded_multi).has_value()) {
        std::cerr << "Bounded MultilineText rejected valid input" << std::endl;
        return false;
    }
    if (!assert_invalid_value(JsonValidator::validate(json{{"body", "01234567890"}}, bounded_multi),
                              "BoundedMulti/too_long")) {
        return false;
    }
    if (!assert_invalid_value(JsonValidator::validate(json{{"body", "a\x0b"
                                                                    "bc"}},
                                                      bounded_multi),
                              "BoundedMulti/control_char")) {
        return false;
    }

    // 6. StringFormat::Any remains unchanged (non-breaking for endpoints outside this commit)
    std::vector<ValidationRule> any_rules = {{"raw", Type::String, true, StringFormat::Any}};
    for (const std::string &legacy : {std::string("a\nb"), std::string("a\x1b"
                                                                       "b")}) {
        json p = {{"raw", legacy}};
        if (JsonValidator::validate(p, any_rules).has_value()) {
            std::cerr << "StringFormat::Any behavior unexpectedly changed" << std::endl;
            return false;
        }
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
    if (!test_month_and_day()) return 1;
    if (!test_string_format_utf8_and_control_chars()) return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
