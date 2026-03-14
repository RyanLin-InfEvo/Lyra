/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once
#include <optional>
#include <string>

struct Artist {
    std::string id;
    std::string name;
    std::optional<std::string> musicbrainz_id;
    std::optional<std::string> ytm_id;
    std::optional<std::string> spotify_id;
};

struct ArtistUpdate {
    std::string id;
    std::optional<std::string> name;
    std::optional<std::string> musicbrainz_id;
    std::optional<std::string> ytm_id;
    std::optional<std::string> spotify_id;

    bool has_updates() const {
        return name.has_value() ||
               musicbrainz_id.has_value() ||
               ytm_id.has_value() ||
               spotify_id.has_value();
    }
};
