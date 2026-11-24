// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <cmath>
#include <fmt/core.h>
#include <nlohmann/json.hpp>
#include <optional>
#include <regex>
#include <string>
#include <vector>

#include "json_helper.h"
#include "json_validator.h"
#include "make_error.h"
#include "utf8_helper.h"

namespace lyra {

bool JsonValidator::is_valid_uuid(const std::string &str) {
    static const std::regex uuid_regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-"
                                       "F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$");
    return std::regex_match(str, uuid_regex);
}

// Add parent_path to report the exact layer of error, e.g., "move.track_uuid"
std::optional<json> JsonValidator::validate(const json &params,
                                            const std::vector<ValidationRule> &rules,
                                            const std::string &parent_path) {

    // Guard: params must be a JSON object. Non-object types (null, array,
    // number, string) would cause contains() to silently return false or throw
    // type_error depending on nlohmann version, producing misleading errors.
    if (!params.is_object()) {
        std::string context = parent_path.empty() ? "params" : parent_path;
        return ApiResponse::error(
            {ErrorType::InvalidCommandFormat,
             "'" + context + "' must be a JSON object, got " + params.type_name()});
    }

    for (const auto &rule : rules) {
        // Calculate the full path of the current field (to generate friendly error
        // messages)
        std::string current_path =
            parent_path.empty() ? rule.key : parent_path + "." + rule.key;

        bool exists = params.contains(rule.key) && !params[rule.key].is_null();

        // Check: if required field exists
        if (rule.is_required && !exists) {
            return ApiResponse::error({ErrorType::MissingParameter, "Missing required field: '" + current_path + "'"});
        }

        // Check: if field exists, and also if type is matching to expected_type
        if (exists) {
            bool type_valid = false;

            switch (rule.expected_type) {
                case JsonFieldType::String:
                    type_valid = params[rule.key].is_string();
                    break;
                case JsonFieldType::Number:
                    type_valid = params[rule.key].is_number();
                    break;
                case JsonFieldType::Integer:
                case JsonFieldType::Year:
                case JsonFieldType::Month:
                case JsonFieldType::Day:
                    type_valid = params[rule.key].is_number_integer();
                    break;
                case JsonFieldType::Boolean:
                    type_valid = params[rule.key].is_boolean();
                    break;
                case JsonFieldType::Array:
                    type_valid = params[rule.key].is_array();
                    break;
                case JsonFieldType::Object:
                    type_valid = params[rule.key].is_object();
                    break;
            }

            // `type_valid` == false, the value of `params[rule.key]` is not matching any expected types
            if (!type_valid) {
                return ApiResponse::error({ErrorType::InvalidValue,
                                           "Value of key '" + current_path + "' is not a expected type."});
            }

            // Special check for "String"
            if (rule.expected_type == JsonFieldType::String) {

                // Get string value
                const std::string &str_val = params[rule.key].get_ref<const std::string &>();

                // allow string empty ?
                if (str_val.empty()) {
                    if (!rule.allow_empty) {
                        return ApiResponse::error({ErrorType::InvalidValue,
                                                   "Value of key '" + current_path + "' should not be empty."});
                    }
                    continue;
                }

                // Check length if
                // 1. too short
                if (rule.min_length.has_value() && str_val.length() < rule.min_length.value()) {
                    return ApiResponse::error({ErrorType::InvalidValue,
                                               "Value of key '" + current_path + "' is too short. Min length is " + std::to_string(rule.min_length.value())});
                }
                // 2. too long
                if (rule.max_length.has_value() && str_val.length() > rule.max_length.value()) {
                    return ApiResponse::error({ErrorType::InvalidValue,
                                               "Value of key '" + current_path + "' is too long. Max length is " + std::to_string(rule.max_length.value())});
                }

                // Check string format
                if (rule.string_format == StringFormat::UUID) {
                    if (!is_valid_uuid(str_val)) {
                        return ApiResponse::error({ErrorType::InvalidValue,
                                                   "Value of key '" + current_path + "' is not a vaild UUID."});
                    }
                } else if (rule.string_format == StringFormat::SingleLineText) {
                    if (!utils::is_valid_utf8(str_val) || utils::contains_control_chars(str_val, false)) {
                        return ApiResponse::error({ErrorType::InvalidValue,
                                                   "Value of key '" + current_path + "' must be valid UTF-8 without control characters."});
                    }
                } else if (rule.string_format == StringFormat::MultilineText) {
                    if (!utils::is_valid_utf8(str_val) || utils::contains_control_chars(str_val, true)) {
                        return ApiResponse::error({ErrorType::InvalidValue,
                                                   "Value of key '" + current_path + "' must be valid UTF-8 without control characters other than tab, LF, or CR."});
                    }
                }
            } // TODO: If min_length.has_value() or max_length.has_value() but rule.expected_type != JsonFieldType::String, return error

            // Special check for "Integer" overflow & bounds (with uint64_t > INT64_MAX overflow protection)
            if (rule.expected_type == JsonFieldType::Integer) {
                auto int_val = JsonHelper::try_get_int64(params[rule.key]);
                if (!int_val) {
                    if (rule.max_int.has_value()) {
                        return ApiResponse::error(
                            {ErrorType::OutOfRange,
                             fmt::format("Value of key '{}' is out of range (must be <= {}).",
                                         current_path, *rule.max_int)});
                    }
                    return ApiResponse::error(
                        {ErrorType::OutOfRange,
                         fmt::format("Value of key '{}' is out of range (exceeds maximum 64-bit signed integer).",
                                     current_path)});
                }
                if (rule.min_int.has_value() && *int_val < *rule.min_int) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange,
                         fmt::format("Value of key '{}' is out of range (must be >= {}).",
                                     current_path, *rule.min_int)});
                }
                if (rule.max_int.has_value() && *int_val > *rule.max_int) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange,
                         fmt::format("Value of key '{}' is out of range (must be <= {}).",
                                     current_path, *rule.max_int)});
                }
            }

            // Special check for "Number" finiteness and bounds
            if (rule.expected_type == JsonFieldType::Number) {
                const double num_val = params[rule.key].get<double>();
                if (!std::isfinite(num_val)) {
                    return ApiResponse::error(
                        {ErrorType::InvalidValue,
                         "Value of key '" + current_path + "' must be a finite number."});
                }
                if (rule.min_number.has_value() && !(num_val >= *rule.min_number)) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange,
                         fmt::format("Value of key '{}' is out of range (must be >= {}).",
                                     current_path, *rule.min_number)});
                }
                if (rule.max_number.has_value() && !(num_val <= *rule.max_number)) {
                    return ApiResponse::error(
                        {ErrorType::OutOfRange,
                         fmt::format("Value of key '{}' is out of range (must be <= {}).",
                                     current_path, *rule.max_number)});
                }
            }

            // Special check for "Year"
            if (rule.expected_type == JsonFieldType::Year) {
                auto year_val = JsonHelper::try_get_int64(params[rule.key]);
                if (!year_val || *year_val < 1 || *year_val > 3000) {
                    return ApiResponse::error({ErrorType::OutOfRange,
                                               "Value of key '" + current_path + "' is out of reasonable year range (1-3000)."});
                }
            }

            // Special check for "Month"
            if (rule.expected_type == JsonFieldType::Month) {
                auto month_val = JsonHelper::try_get_int64(params[rule.key]);
                if (!month_val || *month_val < 1 || *month_val > 12) {
                    return ApiResponse::error({ErrorType::OutOfRange,
                                               "Value of key '" + current_path + "' is out of reasonable month range (1-12)."});
                }
            }

            // Special check for "Day"
            if (rule.expected_type == JsonFieldType::Day) {
                auto day_val = JsonHelper::try_get_int64(params[rule.key]);
                if (!day_val || *day_val < 1 || *day_val > 31) {
                    return ApiResponse::error({ErrorType::OutOfRange,
                                               "Value of key '" + current_path + "' is out of reasonable day range (1-31)."});
                }
            }

            // Check: if object is not empty, and also if children is not empty
            if (rule.expected_type == JsonFieldType::Object && !rule.children.empty()) {

                // Pass the inner json object and child rules to validate again
                auto nested_err =
                    validate(params[rule.key], rule.children, current_path);

                if (nested_err)
                    return nested_err; // If there is an error in the inner layer, return it directly upword
            }
        }
    }

    return std::nullopt;
}

} // namespace lyra
