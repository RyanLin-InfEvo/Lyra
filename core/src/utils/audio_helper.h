/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <tl/expected.hpp>
#include <vector>

namespace lyra {

struct Audio;
struct Asset;

namespace utils {

struct MediaMetadata {
    double duration = 0.0;
    int sample_rate = 0;
    int channels = 0;
    bool has_cover_art = false;
    std::optional<int> video_width;
    std::optional<int> video_height;
    std::optional<std::string> video_codec;
    std::optional<std::string> title;
    std::optional<std::string> artist;
    std::optional<std::string> album;
    std::optional<std::string> date;
    std::optional<std::string> track;
};

struct AudioQualityInfo {
    int quality_score = 0;
    bool is_lossless = false;
    std::string format;
    int64_t file_size = 0;
};

class AudioHelper {
  public:
    static tl::expected<std::string, std::string> calculate_pcm_hash(const std::string &filepath);
    static tl::expected<MediaMetadata, std::string> extract_metadata(const std::string &filepath);
    static tl::expected<std::vector<uint8_t>, std::string> extract_cover_art(const std::string &filepath);
    static tl::expected<void, std::string> extract_cover_art_to_file(const std::string &filepath, const std::string &output_image_path);
    static AudioQualityInfo evaluate_quality(const Audio &audio);
    static AudioQualityInfo evaluate_quality(const Audio &audio, const Asset &asset);
    static bool matches_format(const Asset &asset, const std::string &preferred_format);
};

} // namespace utils

using utils::AudioQualityInfo;

} // namespace lyra
