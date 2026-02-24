#pragma once
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

using json = nlohmann::json;

// define json field type
enum class JsonFieldType { String, Number, Boolean, Array, Object, UUID };

enum class StringFormat { Any, UUID };

// define validation rule
struct ValidationRule {
    std::string key;
    JsonFieldType expected_type;
    bool is_required = true; // default is required

    StringFormat string_format = StringFormat::Any;
    std::optional<size_t> min_length = std::nullopt;
    std::optional<size_t> max_length = std::nullopt;

    std::vector<ValidationRule> children = {}; // for nested objects
};

class JsonValidator {
public:
    // batch validation function
    static std::optional<json> validate(const json &params,
                                      const std::vector<ValidationRule> &rules,
                                      const std::string &parent_path = "");

private:
    // helper function: generate unified error json
    static json make_error(const std::string &message);

    // helper function: check if string is valid uuid
    static bool is_valid_uuid(const std::string &str);
};