/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <cstdint>
#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <vector>

namespace lyra {

using json = nlohmann::json;

// define json field type
enum class JsonFieldType { String,
                           Number,
                           Integer,
                           Year,
                           Month,
                           Day,
                           Boolean,
                           Array,
                           Object };

enum class StringFormat { Any,
                          UUID,
                          SingleLineText,
                          MultilineText }; // ISWC, musicbrainz_id etc

// define validation rule
struct ValidationRule {
    std::string key;
    JsonFieldType expected_type;
    bool is_required = true; // default is required

    StringFormat string_format = StringFormat::Any;
    std::optional<size_t> min_length = std::nullopt;
    std::optional<size_t> max_length = std::nullopt;

    std::vector<ValidationRule> children = {};       // for nested objects
    bool allow_empty = false;                        // only applicable to JsonFieldType::String
    std::optional<int64_t> min_int = std::nullopt;   // only applicable to JsonFieldType::Integer
    std::optional<int64_t> max_int = std::nullopt;   // only applicable to JsonFieldType::Integer
    std::optional<double> min_number = std::nullopt; // only applicable to JsonFieldType::Number
    std::optional<double> max_number = std::nullopt; // only applicable to JsonFieldType::Number
};

class JsonValidator {
  public:
    // batch validation function
    static std::optional<json> validate(const json &params,
                                        const std::vector<ValidationRule> &rules,
                                        const std::string &parent_path = "");

  private:
    // helper function: check if string is valid uuid
    static bool is_valid_uuid(const std::string &str);
};

} // namespace lyra
