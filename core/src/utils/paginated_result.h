/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <vector>
#include <nlohmann/json.hpp>

namespace lyra {

template <typename T>
struct PaginatedResult {
    std::vector<T> items;
    int total;
    int offset;
    int limit;
};

template <typename T>
void to_json(nlohmann::json& j, const PaginatedResult<T>& p) {
    j = nlohmann::json{
        {"items", p.items},
        {"total", p.total},
        {"offset", p.offset},
        {"limit", p.limit}   
    };
}

} // namespace lyra
