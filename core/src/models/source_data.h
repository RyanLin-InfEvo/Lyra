/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <string>

struct SourceData {
    std::string id;
    std::string file_hash;
    std::string source_type = "";
    std::string original_path = "";
    std::string created_at = "";
    std::string note = "";
};
