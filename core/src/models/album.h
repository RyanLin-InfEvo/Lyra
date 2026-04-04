/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <string>

namespace lyra {

struct Album {
    std::string id;
    std::string title;
    int release_year = 0;
    int release_month = 0;
    int release_day = 0;
};

} // namespace lyra
