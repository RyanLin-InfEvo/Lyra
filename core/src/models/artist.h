/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <string>

struct Artist {
    std::string id;
    std::string name;
    std::string musicbrainz_id;
    std::string ytm_id;
    std::string spotify_id;
};
