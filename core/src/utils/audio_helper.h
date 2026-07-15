/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <string>
#include <vector>
#include <optional>
#include <cstdint>
#include <tl/expected.hpp>

namespace lyra {
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

class AudioHelper {
public:
    static tl::expected<std::string, std::string> calculate_pcm_hash(const std::string& filepath);
    static tl::expected<MediaMetadata, std::string> extract_metadata(const std::string& filepath);
    static tl::expected<std::vector<uint8_t>, std::string> extract_cover_art(const std::string& filepath);
    static tl::expected<void, std::string> extract_cover_art_to_file(const std::string& filepath, const std::string& output_image_path);
};

} // namespace utils
} // namespace lyra
