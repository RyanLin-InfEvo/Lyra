/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <optional>
#include <string>

struct Track {
    std::string id;
    std::string pcm_hash;
    std::optional<std::string> work_id;
    std::optional<std::string> title;
    std::optional<int> recording_year;
    std::optional<int> recording_month;
    std::optional<int> recording_day;
    std::optional<std::string> recording_location;
    std::optional<int> duration; // A cached value from Audio, in milliseconds
    std::optional<std::string> isrc;
    std::optional<std::string> musicbrainz_id;
    std::optional<std::string> ytm_id;
    std::optional<std::string> spotify_id;
};

struct TrackUpdate {
    std::string id;
    std::optional<std::string> work_id;
    std::optional<std::string> pcm_hash;
    std::optional<std::string> title;
    std::optional<int> recording_year;
    std::optional<int> recording_month;
    std::optional<int> recording_day;
    std::optional<std::string> recording_location;
    std::optional<int> duration;
    std::optional<std::string> isrc;
    std::optional<std::string> musicbrainz_id;
    std::optional<std::string> ytm_id;
    std::optional<std::string> spotify_id;

    bool has_updates() const {
        return work_id.has_value() || pcm_hash.has_value() || title.has_value() ||
               recording_year.has_value() || recording_month.has_value() || recording_day.has_value() ||
               recording_location.has_value() || duration.has_value() || isrc.has_value() ||
               musicbrainz_id.has_value() || ytm_id.has_value() || spotify_id.has_value();
    }
};
