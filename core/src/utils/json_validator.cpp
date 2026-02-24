#include "json_validator.h"
#include <regex>

bool JsonValidator::is_valid_uuid(const std::string &str) {
  static const std::regex uuid_regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-"
                                     "F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$");
  return std::regex_match(str, uuid_regex);
}

// Add parent_path to report the exact layer of error, e.g., "move.track_uuid"
std::optional<json>
JsonValidator::validate(const json &params,
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
      return make_error("Missing required field: '" + current_path + "'");
    }

    // Check: if field exists, and also if type is correct
    if (exists) {
      bool type_valid = false;

      switch (rule.expected_type) {
      case JsonFieldType::String:
        type_valid = params[rule.key].is_string();
        break;
      case JsonFieldType::UUID:
        type_valid = params[rule.key].is_string();
        break;
      case JsonFieldType::Number:
        type_valid = params[rule.key].is_number();
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

      // If is string, check length and uuid format
      if (rule.expected_type == JsonFieldType::String) {

        // Get string value
        std::string str_val = params[rule.key].get<std::string>();

        // Check length
        if (rule.min_length.has_value() &&
            str_val.length() < rule.min_length.value()) {
          return make_error("Field '" + current_path +
                            "' is too short. Min length is " +
                            std::to_string(rule.min_length.value()));
        }
        if (rule.max_length.has_value() &&
            str_val.length() > rule.max_length.value()) {
          return make_error("Field '" + current_path +
                            "' is too long. Max length is " +
                            std::to_string(rule.max_length.value()));
        }

        // Check UUID format
        if (rule.string_format == StringFormat::UUID) {
          if (!is_valid_uuid(str_val)) {
            return make_error("Field '" + current_path +
                              "' must be a valid UUID");
          }
        }
      }

      if (!type_valid) {
        return make_error("Invalid type for field: '" + current_path + "'");
      }

      // Check: if string is empty
      if (rule.expected_type == JsonFieldType::String &&
          params[rule.key].get<std::string>().empty()) {
        return make_error("Field '" + current_path +
                          "' cannot be empty string");
      }

      // Check: if object is not empty, and also if children is not empty
      if (rule.expected_type == JsonFieldType::Object &&
          !rule.children.empty()) {

        // Pass the inner json object and child rules to validate again
        auto nested_err =
            validate(params[rule.key], rule.children, current_path);

        if (nested_err)
          return nested_err; // If there is an error in the inner layer, return
                             // it directly
      }
    }
  }

  return std::nullopt;
}

json JsonValidator::make_error(const std::string &message) {
  json error_res;
  error_res["code"] = 400;
  error_res["error"]["type"] = "ValidationError";
  error_res["error"]["message"] = message;
  return error_res;
}
