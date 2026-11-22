/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <string_view>

namespace lyra::utils {

// Validates that bytes form well-formed UTF-8 (RFC 3629) without embedded NUL (0x00).
bool is_valid_utf8(std::string_view bytes);

// Checks whether a UTF-8 string contains C0 (U+0000..U+001F), DEL (U+007F),
// or C1 (U+0080..U+009F) control characters. When allow_multiline_whitespace is true,
// '\t', '\n', and '\r' are permitted.
// Precondition: callers must validate utf8 with is_valid_utf8() first; overlong UTF-8
// encodings are rejected by is_valid_utf8(), not decoded here.
bool contains_control_chars(std::string_view utf8, bool allow_multiline_whitespace = false);

} // namespace lyra::utils
