/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

namespace lyra {

struct Text {
    std::string text_hash;
    std::string file_hash;
    std::string language = "";
    std::string encoding = "utf-8";
    std::string format = "";
    std::optional<std::string> role = std::nullopt;
};

inline void to_json(nlohmann::json &j, const Text &t) {
    j = nlohmann::json{
        {"text_hash", t.text_hash},
        {"file_hash", t.file_hash},
        {"language", t.language},
        {"encoding", t.encoding},
        {"format", t.format},
    };
    if (t.role.has_value()) {
        j["role"] = *t.role;
    } else {
        j["role"] = nullptr;
    }
}

} // namespace lyra
