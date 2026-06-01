/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "sqlite_helper.h"

namespace lyra {
namespace SqliteHelper {

std::string escape_like(const std::string& input, char escape_char) {
    std::string result;
    result.reserve(input.size());
    for (char c : input) {
        if (c == escape_char) {
            result.push_back(escape_char);
            result.push_back(escape_char);
        } else if (c == '%' || c == '_') {
            result.push_back(escape_char);
            result.push_back(c);
        } else {
            result.push_back(c);
        }
    }
    return result;
}

} // namespace SqliteHelper
} // namespace lyra
