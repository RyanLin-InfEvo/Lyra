/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <nlohmann/json.hpp>
#include <string>

namespace lyra {

struct SourceData {
    std::string id;
    std::string file_hash;
    std::string source_type = "";
    std::string original_path = "";
    std::string created_at = "";
    std::string note = "";
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(SourceData, id, file_hash, source_type, original_path, created_at, note)

} // namespace lyra
