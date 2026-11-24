/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/json_helper.h"
#include "../src/utils/json_validator.h"
#include <cassert>
#include <cstdint>
#include <iostream>
#include <limits>
#include <string>
#include <type_traits>
#include <utility>
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

    // Case 9: uint64_t::max wraparound on Year, Month, Day must return OutOfRange (Audit Finding 1)
    const uint64_t u64_max = std::numeric_limits<uint64_t>::max();
    std::vector<ValidationRule> year_rules = {{"year", Type::Year, true}};
    struct U64Case {
        json payload;
        std::vector<ValidationRule> rules;
        const char *expected_msg;
    };
    for (const auto &[payload, active_rules, expected_msg] : {
             U64Case{json{{"year", u64_max}}, year_rules, "reasonable year range"},
             U64Case{json{{"month", u64_max}, {"day", 15}}, rules, "reasonable month range"},
             U64Case{json{{"month", 6}, {"day", u64_max}}, rules, "reasonable day range"},
         }) {
        auto err_u64 = JsonValidator::validate(payload, active_rules);
        if (!err_u64.has_value() || err_u64->value("code", 0) != 400 ||
            !err_u64->contains("error") || !(*err_u64)["error"].is_object() ||
            (*err_u64)["error"].value("type", "") != "OutOfRange" ||
            (*err_u64)["error"].value("message", "").find(expected_msg) == std::string::npos) {
            std::cerr << "test_month_and_day Case 9 (uint64_t::max) failed: "
                      << (err_u64 ? err_u64->dump() : "success") << std::endl;
            return false;
        }
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

bool test_allow_empty() {
    std::cout << "Running test_allow_empty..." << std::endl;

    auto assert_error = [](const std::optional<json> &err, const std::string &expected_type,
                           const std::string &expected_msg_substr, const std::string &label) -> bool {
        if (!err.has_value()) {
            std::cerr << "FAILED (" << label << "): expected error " << expected_type << ", got success" << std::endl;
            return false;
        }
        if (err->value("code", 0) != 400) {
            std::cerr << "FAILED (" << label << "): expected code 400, got " << err->dump() << std::endl;
            return false;
        }
        if (!err->contains("error") || !(*err)["error"].is_object() ||
            (*err)["error"].value("type", "") != expected_type ||
            (*err)["error"].value("message", "").find(expected_msg_substr) == std::string::npos) {
            std::cerr << "FAILED (" << label << "): expected " << expected_type
                      << " containing '" << expected_msg_substr << "', got " << err->dump() << std::endl;
            return false;
        }
        return true;
    };

    // 1. Default (allow_empty = false) rejects "" across Any, SingleLineText, MultilineText, UUID
    for (const auto fmt : {StringFormat::Any, StringFormat::SingleLineText, StringFormat::MultilineText, StringFormat::UUID}) {
        std::vector<ValidationRule> rules = {{"val", Type::String, false, fmt}};
        if (!assert_error(JsonValidator::validate(json{{"val", ""}}, rules), "InvalidValue", "should not be empty", "default_reject_empty")) {
            return false;
        }
    }

    // 2. allow_empty = true allows "" for Any, SingleLineText, MultilineText, UUID, and with min_length set
    for (const auto fmt : {StringFormat::Any, StringFormat::SingleLineText, StringFormat::MultilineText, StringFormat::UUID}) {
        std::vector<ValidationRule> rules = {
            {.key = "val", .expected_type = Type::String, .is_required = false, .string_format = fmt, .min_length = 3, .max_length = 40, .allow_empty = true}};
        auto err = JsonValidator::validate(json{{"val", ""}}, rules);
        if (err.has_value()) {
            std::cerr << "allow_empty=true unexpectedly rejected empty string: " << err->dump() << std::endl;
            return false;
        }
    }

    // 3. allow_empty = true still rejects non-empty invalid strings and wrong JSON types
    std::vector<ValidationRule> single_rule = {
        {.key = "val", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .min_length = 3, .max_length = 5, .allow_empty = true}};
    if (!assert_error(JsonValidator::validate(json{{"val", "a\nb"}}, single_rule), "InvalidValue", "must be valid UTF-8 without control characters", "allow_empty_single_newline")) return false;
    if (!assert_error(JsonValidator::validate(json{{"val", "a\xFF"
                                                           "b"}},
                                              single_rule),
                      "InvalidValue", "must be valid UTF-8 without control characters", "allow_empty_single_utf8")) return false;
    if (!assert_error(JsonValidator::validate(json{{"val", "ab"}}, single_rule), "InvalidValue", "is too short", "allow_empty_single_min_len")) return false;
    if (!assert_error(JsonValidator::validate(json{{"val", "abcdef"}}, single_rule), "InvalidValue", "is too long", "allow_empty_single_max_len")) return false;
    for (const json &wrong : {json(123), json(true), json::array(), json::object()}) {
        if (!assert_error(JsonValidator::validate(json{{"val", wrong}}, single_rule), "InvalidValue", "is not a expected type", "allow_empty_wrong_type")) {
            return false;
        }
    }

    std::vector<ValidationRule> multi_rule = {
        {.key = "val", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::MultilineText, .allow_empty = true}};
    if (JsonValidator::validate(json{{"val", "ok\n\t\r"}}, multi_rule).has_value()) {
        std::cerr << "allow_empty MultilineText rejected valid multiline string" << std::endl;
        return false;
    }
    if (!assert_error(JsonValidator::validate(json{{"val", "a\x1b"
                                                           "b"}},
                                              multi_rule),
                      "InvalidValue", "must be valid UTF-8 without control characters other than tab, LF, or CR", "allow_empty_multi_esc")) return false;

    std::vector<ValidationRule> uuid_rule = {
        {.key = "val", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::UUID, .allow_empty = true}};
    if (!assert_error(JsonValidator::validate(json{{"val", "not-a-uuid"}}, uuid_rule), "InvalidValue", "is not a vaild UUID", "allow_empty_bad_uuid")) return false;
    if (JsonValidator::validate(json{{"val", "00000000-0000-0000-0000-000000000000"}}, uuid_rule).has_value()) {
        std::cerr << "allow_empty UUID rejected valid UUID" << std::endl;
        return false;
    }

    // 4. is_required = true + allow_empty = true accepts "" but rejects missing key and null with MissingParameter
    std::vector<ValidationRule> req_empty_rule = {
        {.key = "val", .expected_type = Type::String, .is_required = true, .string_format = StringFormat::SingleLineText, .allow_empty = true}};
    if (JsonValidator::validate(json{{"val", ""}}, req_empty_rule).has_value()) {
        std::cerr << "required + allow_empty rejected empty string" << std::endl;
        return false;
    }
    if (!assert_error(JsonValidator::validate(json::object(), req_empty_rule), "MissingParameter", "Missing required field", "req_allow_empty_missing")) return false;
    if (!assert_error(JsonValidator::validate(json{{"val", nullptr}}, req_empty_rule), "MissingParameter", "Missing required field", "req_allow_empty_null")) return false;

    // 5. Nested children rules with allow_empty = true / false
    std::vector<ValidationRule> nested_rules = {
        {"meta", Type::Object, true, StringFormat::Any, std::nullopt, std::nullopt, {
                                                                                        {.key = "opt_empty", .expected_type = Type::String, .is_required = false, .string_format = StringFormat::SingleLineText, .allow_empty = true},
                                                                                        {.key = "req_non_empty", .expected_type = Type::String, .is_required = true, .string_format = StringFormat::SingleLineText, .allow_empty = false},
                                                                                    }}};
    if (JsonValidator::validate(json{{"meta", {{"opt_empty", ""}, {"req_non_empty", "ok"}}}}, nested_rules).has_value()) {
        std::cerr << "nested allow_empty=true rejected empty child string" << std::endl;
        return false;
    }
    if (!assert_error(JsonValidator::validate(json{{"meta", {{"opt_empty", ""}, {"req_non_empty", ""}}}}, nested_rules),
                      "InvalidValue", "should not be empty", "nested_allow_empty_false")) {
        return false;
    }

    // 6. allow_empty = false combined with min_length = 0 still rejects ""
    std::vector<ValidationRule> min0_rule = {
        {.key = "val", .expected_type = Type::String, .is_required = true, .string_format = StringFormat::Any, .min_length = 0, .allow_empty = false}};
    if (!assert_error(JsonValidator::validate(json{{"val", ""}}, min0_rule), "InvalidValue", "should not be empty", "min0_allow_empty_false")) {
        return false;
    }

    return true;
}

template <typename J>
concept CanCallFindValue = requires(J &&j) {
    JsonHelper::find_value(static_cast<J &&>(j), "a");
};

bool test_json_helper() {
    std::cout << "Running test_json_helper..." << std::endl;

    json obj = {{"s", "hello"}, {"n", 42}, {"b", true}, {"null_k", nullptr}, {"fallback", "mp3"}};

    // find_value & has_value
    const json *s_ptr = JsonHelper::find_value(obj, "s");
    if (!s_ptr || s_ptr->get<std::string>() != "hello") {
        std::cerr << "find_value failed for valid string key" << std::endl;
        return false;
    }
    if (JsonHelper::find_value(obj, "null_k") != nullptr || JsonHelper::has_value(obj, "null_k")) {
        std::cerr << "find_value/has_value returned truthy for null key" << std::endl;
        return false;
    }
    if (JsonHelper::find_value(obj, "missing") != nullptr || JsonHelper::has_value(obj, "missing")) {
        std::cerr << "find_value/has_value returned truthy for missing key" << std::endl;
        return false;
    }
    if (!JsonHelper::has_value(obj, "n")) {
        std::cerr << "has_value returned false for integer key" << std::endl;
        return false;
    }

    // get_optional & get_safe
    if (JsonHelper::get_optional<std::string>(obj, "s") != std::optional<std::string>{"hello"}) return false;
    if (JsonHelper::get_optional<std::string>(obj, "null_k").has_value()) return false;
    if (JsonHelper::get_optional<std::string>(obj, "missing").has_value()) return false;
    if (JsonHelper::get_safe<int>(obj, "n", -1) != 42) return false;
    if (JsonHelper::get_safe<int>(obj, "null_k", -1) != -1) return false;
    if (JsonHelper::get_safe<std::string>(obj, "missing", "def") != "def") return false;

    // get_first_optional priority & null fallback
    if (JsonHelper::get_first_optional<std::string>(obj, {"s", "fallback"}) != std::optional<std::string>{"hello"}) return false;
    if (JsonHelper::get_first_optional<std::string>(obj, {"null_k", "missing", "fallback"}) != std::optional<std::string>{"mp3"}) return false;
    if (JsonHelper::get_first_optional<std::string>(obj, {"null_k", "missing"}).has_value()) return false;
    json empty_str_obj = {{"primary", ""}, {"fallback", "mp3"}};
    if (JsonHelper::get_first_optional<std::string>(empty_str_obj, {"primary", "fallback"}) != std::optional<std::string>{""}) return false;
    if (JsonHelper::get_first_optional<std::string>(obj, {}).has_value()) return false;

    // Non-object JSON types must never throw and must return nullptr/false/nullopt/default
    for (const json &non_obj : {json::array({1, 2}), json(nullptr), json(123), json("str")}) {
        if (JsonHelper::find_value(non_obj, "s") != nullptr) return false;
        if (JsonHelper::has_value(non_obj, "s")) return false;
        if (JsonHelper::get_optional<std::string>(non_obj, "s").has_value()) return false;
        if (JsonHelper::get_safe<std::string>(non_obj, "s", "fallback") != "fallback") return false;
        if (JsonHelper::get_first_optional<std::string>(non_obj, {"s", "fallback"}).has_value()) return false;
    }

    // try_get_int64: signed/unsigned conversions without uint64_t wraparound
    if (JsonHelper::try_get_int64(json(int64_t{-1})) != std::optional<int64_t>{-1}) return false;
    if (JsonHelper::try_get_int64(json(std::numeric_limits<int64_t>::min())) != std::optional<int64_t>{std::numeric_limits<int64_t>::min()}) return false;
    if (JsonHelper::try_get_int64(json(uint64_t{0})) != std::optional<int64_t>{0}) return false;
    constexpr uint64_t u_i64_max = static_cast<uint64_t>(std::numeric_limits<int64_t>::max());
    if (JsonHelper::try_get_int64(json(u_i64_max)) != std::optional<int64_t>{std::numeric_limits<int64_t>::max()}) return false;
    if (JsonHelper::try_get_int64(json(u_i64_max + 1ULL)).has_value()) return false;
    if (JsonHelper::try_get_int64(json(std::numeric_limits<uint64_t>::max())).has_value()) return false;
    for (const json &non_int : {json(true), json(1.5), json("123")}) {
        if (JsonHelper::try_get_int64(non_int).has_value()) return false;
    }

    // assign_if_present: both T& and std::optional<T>& overloads
    {
        std::string dst_str = "keep";
        JsonHelper::assign_if_present(dst_str, obj, "s");
        if (dst_str != "hello") return false;
        JsonHelper::assign_if_present(dst_str, json{{"s", ""}}, "s");
        if (!dst_str.empty()) return false;
        dst_str = "preserved";
        JsonHelper::assign_if_present(dst_str, obj, "missing");
        JsonHelper::assign_if_present(dst_str, obj, "null_k");
        JsonHelper::assign_if_present(dst_str, json::array({1, 2}), "s");
        if (dst_str != "preserved") return false;

        std::optional<int> dst_opt = 7;
        JsonHelper::assign_if_present(dst_opt, obj, "missing");
        JsonHelper::assign_if_present(dst_opt, obj, "null_k");
        JsonHelper::assign_if_present(dst_opt, json(123), "n");
        if (dst_opt != std::optional<int>{7}) return false;
        JsonHelper::assign_if_present(dst_opt, obj, "n");
        if (dst_opt != std::optional<int>{42}) return false;

        std::optional<int> empty_opt = std::nullopt;
        JsonHelper::assign_if_present(empty_opt, obj, "missing");
        JsonHelper::assign_if_present(empty_opt, obj, "null_k");
        JsonHelper::assign_if_present(empty_opt, json::array({1, 2}), "n");
        if (empty_opt.has_value()) return false;
        JsonHelper::assign_if_present(empty_opt, obj, "n");
        if (empty_opt != std::optional<int>{42}) return false;
    }

    // Compile-time check: rvalue find_value overload must be deleted to prevent dangling pointers
    static_assert(CanCallFindValue<const json &>, "find_value must accept const json lvalues");
    static_assert(CanCallFindValue<json &>, "find_value must accept non-const json lvalues");
    static_assert(!CanCallFindValue<json>, "find_value must reject rvalue json temporaries");
    static_assert(!CanCallFindValue<const json &&>, "find_value must reject const rvalue json temporaries");

    return true;
}

bool test_numeric_bounds() {
    std::cout << "Running test_numeric_bounds..." << std::endl;

    auto assert_err = [](const std::optional<json> &err, const std::string &expected_type,
                         const std::string &expected_msg_substr, const std::string &label) -> bool {
        if (!err.has_value() || err->value("code", 0) != 400 ||
            !err->contains("error") || !(*err)["error"].is_object() ||
            (*err)["error"].value("type", "") != expected_type ||
            (*err)["error"].value("message", "").find(expected_msg_substr) == std::string::npos) {
            std::cerr << "FAILED (" << label << "): expected " << expected_type
                      << " containing '" << expected_msg_substr << "', got "
                      << (err ? err->dump() : "success") << std::endl;
            return false;
        }
        return true;
    };

    constexpr uint64_t u_i64_max_plus_1 = static_cast<uint64_t>(std::numeric_limits<int64_t>::max()) + 1ULL;
    constexpr uint64_t u64_max = std::numeric_limits<uint64_t>::max();

    // 1. Integer rules with min_int & max_int (including UINT32_MAX, INT_MIN..INT_MAX, and missing/null)
    std::vector<ValidationRule> uint32_rule = {
        {.key = "dur", .expected_type = Type::Integer, .is_required = false, .min_int = 0, .max_int = std::numeric_limits<uint32_t>::max()}};
    for (const json &valid_p : {
             json::object(),
             json{{"dur", nullptr}},
             json{{"dur", 0}},
             json{{"dur", static_cast<int64_t>(std::numeric_limits<uint32_t>::max())}},
         }) {
        if (auto err = JsonValidator::validate(valid_p, uint32_rule)) {
            std::cerr << "uint32_rule rejected valid input: " << err->dump() << std::endl;
            return false;
        }
    }
    if (!assert_err(JsonValidator::validate(json{{"dur", -1}}, uint32_rule), "OutOfRange", "must be >=", "uint32_neg")) return false;
    if (!assert_err(JsonValidator::validate(json{{"dur", int64_t{4294967296LL}}}, uint32_rule), "OutOfRange", "must be <=", "uint32_above")) return false;
    if (!assert_err(JsonValidator::validate(json{{"dur", u_i64_max_plus_1}}, uint32_rule), "OutOfRange", "must be <=", "uint32_i64_overflow")) return false;
    if (!assert_err(JsonValidator::validate(json{{"dur", u64_max}}, uint32_rule), "OutOfRange", "must be <=", "uint32_u64max")) return false;
    if (!assert_err(JsonValidator::validate(json{{"dur", "10"}}, uint32_rule), "InvalidValue", "is not a expected type", "uint32_str")) return false;
    for (const double flt : {0.0, 1.5, 3.0}) {
        if (!assert_err(JsonValidator::validate(json{{"dur", flt}}, uint32_rule), "InvalidValue", "is not a expected type", "uint32_float")) return false;
    }

    std::vector<ValidationRule> int_rule = {
        {.key = "pos", .expected_type = Type::Integer, .is_required = false, .min_int = std::numeric_limits<int>::min(), .max_int = std::numeric_limits<int>::max()}};
    if (JsonValidator::validate(json{{"pos", std::numeric_limits<int>::min()}}, int_rule).has_value()) return false;
    if (JsonValidator::validate(json{{"pos", std::numeric_limits<int>::max()}}, int_rule).has_value()) return false;
    if (!assert_err(JsonValidator::validate(json{{"pos", int64_t{-2147483649LL}}}, int_rule), "OutOfRange", "must be >=", "int_below_min")) return false;
    if (!assert_err(JsonValidator::validate(json{{"pos", std::numeric_limits<int64_t>::min()}}, int_rule), "OutOfRange", "must be >=", "int_i64min")) return false;
    if (!assert_err(JsonValidator::validate(json{{"pos", int64_t{2147483648LL}}}, int_rule), "OutOfRange", "must be <=", "int_above_max")) return false;
    if (!assert_err(JsonValidator::validate(json{{"pos", u_i64_max_plus_1}}, int_rule), "OutOfRange", "must be <=", "int_i64_overflow")) return false;
    if (!assert_err(JsonValidator::validate(json{{"pos", u64_max}}, int_rule), "OutOfRange", "must be <=", "int_u64max")) return false;

    // 2. Integer rule with only min_int set, only max_int set, and unbounded (no min/max)
    std::vector<ValidationRule> min_only_rule = {
        {.key = "val", .expected_type = Type::Integer, .is_required = true, .min_int = 0}};
    if (JsonValidator::validate(json{{"val", 0}}, min_only_rule).has_value()) return false;
    if (JsonValidator::validate(json{{"val", std::numeric_limits<int64_t>::max()}}, min_only_rule).has_value()) return false;
    if (!assert_err(JsonValidator::validate(json{{"val", u_i64_max_plus_1}}, min_only_rule), "OutOfRange", "exceeds maximum 64-bit signed integer", "min_only_i64_overflow")) return false;
    if (!assert_err(JsonValidator::validate(json{{"val", u64_max}}, min_only_rule), "OutOfRange", "exceeds maximum 64-bit signed integer", "min_only_u64max")) return false;
    if (!assert_err(JsonValidator::validate(json{{"val", -1}}, min_only_rule), "OutOfRange", "must be >=", "min_only_neg")) return false;

    std::vector<ValidationRule> max_only_rule = {
        {.key = "val", .expected_type = Type::Integer, .is_required = true, .max_int = 100}};
    if (JsonValidator::validate(json{{"val", std::numeric_limits<int64_t>::min()}}, max_only_rule).has_value()) return false;
    if (JsonValidator::validate(json{{"val", 100}}, max_only_rule).has_value()) return false;
    if (!assert_err(JsonValidator::validate(json{{"val", 101}}, max_only_rule), "OutOfRange", "must be <= 100", "max_only_above")) return false;
    if (!assert_err(JsonValidator::validate(json{{"val", u_i64_max_plus_1}}, max_only_rule), "OutOfRange", "must be <= 100", "max_only_i64_overflow")) return false;
    if (!assert_err(JsonValidator::validate(json{{"val", u64_max}}, max_only_rule), "OutOfRange", "must be <= 100", "max_only_u64max")) return false;

    std::vector<ValidationRule> unbounded_int_rule = {{"count", Type::Integer, true}};
    if (JsonValidator::validate(json{{"count", std::numeric_limits<int64_t>::min()}}, unbounded_int_rule).has_value()) return false;
    if (JsonValidator::validate(json{{"count", std::numeric_limits<int64_t>::max()}}, unbounded_int_rule).has_value()) return false;
    if (!assert_err(JsonValidator::validate(json{{"count", u_i64_max_plus_1}}, unbounded_int_rule), "OutOfRange", "exceeds maximum 64-bit signed integer", "unbounded_i64_overflow")) return false;
    if (!assert_err(JsonValidator::validate(json{{"count", u64_max}}, unbounded_int_rule), "OutOfRange", "exceeds maximum 64-bit signed integer", "unbounded_u64max")) return false;

    // 3. Nested object error path for Integer and Number bounds
    std::vector<ValidationRule> nested_int = {
        {"cfg", Type::Object, true, StringFormat::Any, std::nullopt, std::nullopt, {{.key = "rate", .expected_type = Type::Integer, .is_required = true, .min_int = 1, .max_int = 100}}}};
    if (!assert_err(JsonValidator::validate(json{{"cfg", {{"rate", u64_max}}}}, nested_int), "OutOfRange", "cfg.rate", "nested_rate_path")) return false;

    std::vector<ValidationRule> nested_num = {
        {"cfg", Type::Object, true, StringFormat::Any, std::nullopt, std::nullopt, {{.key = "vol", .expected_type = Type::Number, .is_required = true, .min_number = 0.0, .max_number = 1.0}}}};
    if (!assert_err(JsonValidator::validate(json{{"cfg", {{"vol", 1.5}}}}, nested_num), "OutOfRange", "cfg.vol", "nested_vol_path")) return false;

    // 4. Number finiteness, min_number-only, max_number-only, bounded, and NaN rule bounds
    std::vector<ValidationRule> unbounded_num = {{"gain", Type::Number, false}};
    if (JsonValidator::validate(json{{"gain", -14.5}}, unbounded_num).has_value()) return false;
    if (JsonValidator::validate(json{{"gain", 0}}, unbounded_num).has_value()) return false;

    std::vector<ValidationRule> bounded_num = {
        {.key = "vol", .expected_type = Type::Number, .is_required = false, .min_number = 0.0, .max_number = 100.0}};
    for (const json &valid_n : {json{{"vol", 0.0}}, json{{"vol", -0.0}}, json{{"vol", 0}}, json{{"vol", 100.0}}}) {
        if (JsonValidator::validate(valid_n, bounded_num).has_value()) return false;
    }
    if (!assert_err(JsonValidator::validate(json{{"vol", -0.1}}, bounded_num), "OutOfRange", "must be >= 0", "num_below_min")) return false;
    if (!assert_err(JsonValidator::validate(json{{"vol", 100.1}}, bounded_num), "OutOfRange", "must be <= 100", "num_above_max")) return false;

    std::vector<ValidationRule> min_num_only = {
        {.key = "dur", .expected_type = Type::Number, .is_required = true, .min_number = 0.0}};
    if (JsonValidator::validate(json{{"dur", 0.0}}, min_num_only).has_value()) return false;
    if (JsonValidator::validate(json{{"dur", u64_max}}, min_num_only).has_value()) return false;
    if (!assert_err(JsonValidator::validate(json{{"dur", -0.1}}, min_num_only), "OutOfRange", "must be >= 0", "min_num_neg")) return false;
    if (!assert_err(JsonValidator::validate(json{{"dur", std::numeric_limits<int64_t>::min()}}, min_num_only), "OutOfRange", "must be >= 0", "min_num_i64min")) return false;

    std::vector<ValidationRule> max_num_only = {
        {.key = "pct", .expected_type = Type::Number, .is_required = true, .max_number = 100.0}};
    if (JsonValidator::validate(json{{"pct", std::numeric_limits<int64_t>::min()}}, max_num_only).has_value()) return false;
    if (JsonValidator::validate(json{{"pct", 100.0}}, max_num_only).has_value()) return false;
    if (!assert_err(JsonValidator::validate(json{{"pct", 100.1}}, max_num_only), "OutOfRange", "must be <= 100", "max_num_above")) return false;
    if (!assert_err(JsonValidator::validate(json{{"pct", u64_max}}, max_num_only), "OutOfRange", "must be <= 100", "max_num_u64max")) return false;

    for (const double bad_d : {std::numeric_limits<double>::infinity(),
                               -std::numeric_limits<double>::infinity(),
                               std::numeric_limits<double>::quiet_NaN()}) {
        if (!assert_err(JsonValidator::validate(json{{"gain", bad_d}}, unbounded_num), "InvalidValue", "must be a finite number", "unbounded_nonfinite")) return false;
        if (!assert_err(JsonValidator::validate(json{{"vol", bad_d}}, bounded_num), "InvalidValue", "must be a finite number", "bounded_nonfinite")) return false;
    }

    std::vector<ValidationRule> nan_min_rule = {
        {.key = "x", .expected_type = Type::Number, .is_required = true, .min_number = std::numeric_limits<double>::quiet_NaN()}};
    std::vector<ValidationRule> nan_max_rule = {
        {.key = "x", .expected_type = Type::Number, .is_required = true, .max_number = std::numeric_limits<double>::quiet_NaN()}};
    if (!assert_err(JsonValidator::validate(json{{"x", 1.0}}, nan_min_rule), "OutOfRange", "must be >=", "nan_min_rule")) return false;
    if (!assert_err(JsonValidator::validate(json{{"x", 1.0}}, nan_max_rule), "OutOfRange", "must be <=", "nan_max_rule")) return false;

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
    if (!test_allow_empty()) return 1;
    if (!test_json_helper()) return 1;
    if (!test_numeric_bounds()) return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
