// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <nlohmann/json.hpp>
#include <optional>
#include <regex>
#include <string>
#include <vector>

#include "json_validator.h"
#include "make_error.h"

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
                std::string str_val = params[rule.key].get<std::string>();

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

                // Check string format : UUID
                if (rule.string_format == StringFormat::UUID) {
                    if (!is_valid_uuid(str_val)) {
                        return ApiResponse::error({ErrorType::InvalidValue,
                                                   "Value of key '" + current_path + "' is not a vaild UUID."});
                    }
                }
            } // TODO: If min_length.has_value() or max_length.has_value() but rule.expected_type != JsonFieldType::String, return error

            // Special check for "Year"
            if (rule.expected_type == JsonFieldType::Year) {
                int64_t year_val = params[rule.key].get<int64_t>();
                if (year_val < 1 || year_val > 3000) {
                    return ApiResponse::error({ErrorType::OutOfRange,
                                               "Value of key '" + current_path + "' is out of reasonable year range (1-3000)."});
                }
            }



            // Check: if string is empty
            if (rule.expected_type == JsonFieldType::String && params[rule.key].get<std::string>().empty()) {
                return ApiResponse::error({ErrorType::InvalidValue,
                                           "Value of key '" + current_path + "' should not be empty."});
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
