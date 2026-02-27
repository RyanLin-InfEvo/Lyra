/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <string>

struct Asset {
    std::string file_hash;
    std::string mime_type = "";
    std::string asset_type = "";
    int file_size = 0;
    std::string created_at = "";
};
