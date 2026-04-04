/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <string>

namespace lyra {

struct Text {
    std::string text_hash;
    std::string file_hash;
    std::string language = "";
    std::string encoding = "utf-8";
    std::string format = "";
};

} // namespace lyra
