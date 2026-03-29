/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>

namespace utils {
template <typename... Args>
[[nodiscard]] constexpr bool any_has_value(const std::optional<Args> &...opts) noexcept {
    return (... || opts.has_value());
}
} // namespace utils

struct Track {
    std::string id;
    std::string pcm_hash;

    std::optional<std::string> work_id;
    std::optional<std::string> title;

    std::optional<uint16_t> recording_year;
    std::optional<uint8_t> recording_month;
    std::optional<uint8_t> recording_day;

    std::optional<std::string> recording_location;
    std::optional<uint32_t> duration; // A cached value from Audio, in milliseconds

    std::optional<std::string> isrc;
    std::optional<std::string> musicbrainz_id;
    std::optional<std::string> ytm_id;
    std::optional<std::string> spotify_id;
};

struct TrackUpdate {
    std::string id;
    std::optional<std::string> pcm_hash;

    std::optional<std::string> work_id;
    std::optional<std::string> title;

    std::optional<uint16_t> recording_year;
    std::optional<uint8_t> recording_month;
    std::optional<uint8_t> recording_day;

    std::optional<std::string> recording_location;
    std::optional<uint32_t> duration;

    std::optional<std::string> isrc;
    std::optional<std::string> musicbrainz_id;
    std::optional<std::string> ytm_id;
    std::optional<std::string> spotify_id;

    [[nodiscard]] bool has_updates() const noexcept {
        return utils::any_has_value(
            pcm_hash, work_id, title,
            recording_year, recording_month, recording_day, recording_location, duration,
            isrc, musicbrainz_id, ytm_id, spotify_id);
    }
};

struct TrackArtistInfo {
    std::string artist_id;
    std::string role; // main, featured, remixer, etc.
    int position;
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(Track, id, pcm_hash, work_id, title, recording_year, recording_month, recording_day, recording_location, duration, isrc, musicbrainz_id, ytm_id, spotify_id)
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE_WITH_DEFAULT(TrackUpdate, id, pcm_hash, work_id, title, recording_year, recording_month, recording_day, recording_location, duration, isrc, musicbrainz_id, ytm_id, spotify_id)
