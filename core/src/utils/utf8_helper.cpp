/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "utf8_helper.h"

#include <cstddef>
#include <cstdint>

namespace lyra::utils {

bool is_valid_utf8(std::string_view bytes) {
    const size_t n = bytes.size();
    size_t i = 0;
    while (i < n) {
        const uint8_t b0 = static_cast<uint8_t>(bytes[i]);
        if (b0 == 0x00) { // U+0000, NUL
            return false;
        }
        if (b0 <= 0x7F) { // 0x7F = 0111 1111 = 127 = 1-byte, ASCII (below 128)
            ++i;
            continue;
        }
        if (b0 >= 0xC2 && b0 <= 0xDF) { // 2-byte
            if (i + 1 >= n) return false;
            const uint8_t b1 = static_cast<uint8_t>(bytes[i + 1]);
            if ((b1 & 0xC0) != 0x80) return false; // (b1 AND 1100 0000) != 1000 0000, b1 should be 10xx xxxx
            i += 2;
            continue;
        }
        if (b0 >= 0xE0 && b0 <= 0xEF) { // 3-byte
            if (i + 2 >= n) return false;
            const uint8_t b1 = static_cast<uint8_t>(bytes[i + 1]);
            const uint8_t b2 = static_cast<uint8_t>(bytes[i + 2]);
            if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80) return false; // (b1/b2 AND 1100 0000) != 1000 0000
            if (b0 == 0xE0 && b1 < 0xA0) return false;
            if (b0 == 0xED && b1 > 0x9F) return false;
            i += 3;
            continue;
        }
        if (b0 >= 0xF0 && b0 <= 0xF4) { // 4-byte
            if (i + 3 >= n) return false;
            const uint8_t b1 = static_cast<uint8_t>(bytes[i + 1]);
            const uint8_t b2 = static_cast<uint8_t>(bytes[i + 2]);
            const uint8_t b3 = static_cast<uint8_t>(bytes[i + 3]);
            if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80) {
                return false;
            }
            if (b0 == 0xF0 && b1 < 0x90) return false;
            if (b0 == 0xF4 && b1 > 0x8F) return false;
            i += 4;
            continue;
        }
        return false;
    }
    return true;
}

bool contains_control_chars(std::string_view utf8, bool allow_multiline_whitespace) {
    for (size_t i = 0; i < utf8.size(); ++i) {
        const uint8_t b0 = static_cast<uint8_t>(utf8[i]);
        if (b0 < 0x20 || b0 == 0x7F) { // ASCII C0 control characters and DEL
            if (allow_multiline_whitespace && (b0 == '\t' || b0 == '\n' || b0 == '\r')) {
                continue;
            }
            return true;
        }
        // Unicode C1 control characters: U+0080..U+009F -> UTF-8 0xC2 0x80..0x9F
        if (b0 == 0xC2 && i + 1 < utf8.size()) {
            const uint8_t b1 = static_cast<uint8_t>(utf8[i + 1]);
            if (b1 >= 0x80 && b1 <= 0x9F) {
                return true;
            }
            if ((b1 & 0xC0) == 0x80) {
                ++i;
            }
        }
    }
    return false;
}

} // namespace lyra::utils
