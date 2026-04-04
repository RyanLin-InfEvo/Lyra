/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <string>

namespace lyra {

struct Tag {
    std::string id;
    std::string name = "";
    std::string category = "";
};

} // namespace lyra
