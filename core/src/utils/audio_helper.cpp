/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "audio_helper.h"
#include "process_runner.h"
#include "sha256.h"
#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <nlohmann/json.hpp>
#include <sstream>

namespace lyra {
namespace utils {

namespace {

std::optional<double> get_json_double(const nlohmann::json &j, const std::string &key) {
    if (!j.is_object() || !j.contains(key) || j[key].is_null()) {
        return std::nullopt;
    }
    if (j[key].is_number()) {
        return j[key].get<double>();
    }
    if (j[key].is_string()) {
        try {
            return std::stod(j[key].get<std::string>());
        } catch (...) {
            return std::nullopt;
        }
    }
    return std::nullopt;
}

std::optional<int> get_json_int(const nlohmann::json &j, const std::string &key) {
    if (!j.is_object() || !j.contains(key) || j[key].is_null()) {
        return std::nullopt;
    }
    if (j[key].is_number()) {
        return j[key].get<int>();
    }
    if (j[key].is_string()) {
        try {
            return std::stoi(j[key].get<std::string>());
        } catch (...) {
            return std::nullopt;
        }
    }
    return std::nullopt;
}

std::optional<std::string> get_json_string(const nlohmann::json &j, const std::string &key) {
    if (!j.is_object() || !j.contains(key) || j[key].is_null()) {
        return std::nullopt;
    }
    if (j[key].is_string()) {
        return j[key].get<std::string>();
    }
    return std::nullopt;
}

std::optional<std::string> get_tag_case_insensitive(const nlohmann::json &tags_obj, const std::string &target_key) {
    if (!tags_obj.is_object()) {
        return std::nullopt;
    }
    for (auto it = tags_obj.begin(); it != tags_obj.end(); ++it) {
        std::string key = it.key();
        std::transform(key.begin(), key.end(), key.begin(), [](unsigned char c) {
            return std::tolower(c);
        });
        if (key == target_key) {
            if (it.value().is_string()) {
                return it.value().get<std::string>();
            } else if (it.value().is_number()) {
                return it.value().dump();
            }
        }
    }
    return std::nullopt;
}

std::optional<std::string> get_tag(const nlohmann::json &json_data, const std::string &tag_name) {
    // 1. Search Format tags
    if (json_data.contains("format") && json_data["format"].is_object()) {
        const auto &fmt = json_data["format"];
        if (fmt.contains("tags") && fmt["tags"].is_object()) {
            auto val = get_tag_case_insensitive(fmt["tags"], tag_name);
            if (val) return val;
        }
    }
    // 2. Search Stream tags (only audio streams)
    if (json_data.contains("streams") && json_data["streams"].is_array()) {
        for (const auto &stream : json_data["streams"]) {
            auto codec_type = get_json_string(stream, "codec_type");
            if (codec_type && *codec_type == "audio") {
                if (stream.contains("tags") && stream["tags"].is_object()) {
                    auto val = get_tag_case_insensitive(stream["tags"], tag_name);
                    if (val) return val;
                }
            }
        }
    }
    return std::nullopt;
}

} // namespace

tl::expected<std::string, std::string> AudioHelper::calculate_pcm_hash(const std::string &filepath) {
    Sha256 sha;
    auto callback = [&sha](const uint8_t *data, size_t size) {
        sha.update(data, size);
    };

    std::vector<std::string> args = {
        "ffmpeg", "-v", "error", "-i", filepath, "-f", "s32le", "-acodec", "pcm_s32le", "-"};

    auto result = ProcessRunner::run(args, callback, 0);
    if (!result) {
        return tl::unexpected("Process execution failed: " + result.error());
    }

    if (result.value() != 0) {
        return tl::unexpected("ffmpeg exited with code: " + std::to_string(result.value()));
    }

    return sha.finalize();
}

tl::expected<MediaMetadata, std::string> AudioHelper::extract_metadata(const std::string &filepath) {
    std::string json_str;
    auto callback = [&json_str](const uint8_t *data, size_t size) {
        json_str.append(reinterpret_cast<const char *>(data), size);
    };

    std::vector<std::string> args = {
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration,tags",
        "-show_entries", "format_tags",
        "-show_entries", "stream=sample_rate,channels,duration,disposition,width,height,codec_name,codec_type,tags:disposition=attached_pic",
        "-show_entries", "stream_tags",
        "-of", "json", filepath};

    // Limit to 2MB as per instructions
    auto result = ProcessRunner::run(args, callback, 2 * 1024 * 1024);
    if (!result) {
        return tl::unexpected("Process execution failed: " + result.error());
    }

    if (result.value() != 0) {
        return tl::unexpected("ffprobe exited with code: " + std::to_string(result.value()));
    }

    nlohmann::json json_data;
    try {
        json_data = nlohmann::json::parse(json_str);
    } catch (const std::exception &e) {
        return tl::unexpected("Failed to parse JSON: " + std::string(e.what()));
    }

    MediaMetadata metadata;
    double audio_duration = 0.0;
    bool has_audio_duration = false;

    if (json_data.contains("streams") && json_data["streams"].is_array()) {
        for (const auto &stream : json_data["streams"]) {
            auto codec_type = get_json_string(stream, "codec_type");
            if (!codec_type)
                continue;

            if (*codec_type == "audio") {
                auto sr = get_json_int(stream, "sample_rate");
                if (sr)
                    metadata.sample_rate = *sr;
                auto ch = get_json_int(stream, "channels");
                if (ch)
                    metadata.channels = *ch;
                auto dur = get_json_double(stream, "duration");
                if (dur) {
                    audio_duration = *dur;
                    has_audio_duration = true;
                }
            } else if (*codec_type == "video") {
                bool is_attached_pic = false;
                if (stream.contains("disposition") && stream["disposition"].is_object()) {
                    auto disp = stream["disposition"];
                    auto attached = get_json_int(disp, "attached_pic");
                    if (attached && *attached == 1) {
                        is_attached_pic = true;
                        metadata.has_cover_art = true;
                    }
                }
                if (!is_attached_pic) {
                    auto w = get_json_int(stream, "width");
                    if (w)
                        metadata.video_width = *w;
                    auto h = get_json_int(stream, "height");
                    if (h)
                        metadata.video_height = *h;
                    auto codec = get_json_string(stream, "codec_name");
                    if (codec)
                        metadata.video_codec = *codec;
                }
            }
        }
    }

    if (has_audio_duration) {
        metadata.duration = audio_duration;
    } else if (json_data.contains("format") && json_data["format"].is_object()) {
        auto fmt_dur = get_json_double(json_data["format"], "duration");
        if (fmt_dur) {
            metadata.duration = *fmt_dur;
        }
    }

    metadata.title = get_tag(json_data, "title");
    metadata.artist = get_tag(json_data, "artist");
    metadata.album = get_tag(json_data, "album");
    metadata.date = get_tag(json_data, "date");
    metadata.track = get_tag(json_data, "track");

    return metadata;
}

tl::expected<std::vector<uint8_t>, std::string> AudioHelper::extract_cover_art(const std::string &filepath) {
    auto meta_res = extract_metadata(filepath);
    if (!meta_res) {
        return tl::unexpected("Metadata extraction failed: " + meta_res.error());
    }

    const auto &meta = meta_res.value();
    std::vector<std::string> args;

    if (meta.video_width.has_value() && meta.video_height.has_value()) {
        double seek_time = (meta.duration > 2.0) ? 2.0 : 0.0;
        std::stringstream ss;
        ss << std::fixed << std::setprecision(6) << seek_time;
        args = {"ffmpeg", "-v", "error", "-ss", ss.str(), "-i", filepath, "-an", "-vframes", "1", "-f", "image2pipe", "-"};
    } else if (meta.has_cover_art) {
        args = {"ffmpeg", "-v", "error", "-i", filepath, "-an", "-c:v", "copy", "-f", "image2pipe", "-"};
    } else {
        return tl::unexpected("No cover art or video stream found");
    }

    std::vector<uint8_t> buffer;
    auto callback = [&buffer](const uint8_t *data, size_t size) {
        buffer.insert(buffer.end(), data, data + size);
    };

    // Limit output to 10MB
    auto result = ProcessRunner::run(args, callback, 10 * 1024 * 1024);
    if (!result) {
        return tl::unexpected("Process execution failed: " + result.error());
    }

    if (result.value() != 0) {
        return tl::unexpected("ffmpeg exited with code: " + std::to_string(result.value()));
    }

    return buffer;
}

tl::expected<void, std::string> AudioHelper::extract_cover_art_to_file(const std::string &filepath, const std::string &output_image_path) {
    auto meta_res = extract_metadata(filepath);
    if (!meta_res) {
        return tl::unexpected("Metadata extraction failed: " + meta_res.error());
    }

    const auto &meta = meta_res.value();
    std::vector<std::string> args;

    if (meta.video_width.has_value() && meta.video_height.has_value()) {
        double seek_time = (meta.duration > 2.0) ? 2.0 : 0.0;
        std::stringstream ss;
        ss << std::fixed << std::setprecision(6) << seek_time;
        args = {"ffmpeg", "-v", "error", "-ss", ss.str(), "-i", filepath, "-an", "-vframes", "1", "-f", "image2pipe", "-"};
    } else if (meta.has_cover_art) {
        args = {"ffmpeg", "-v", "error", "-i", filepath, "-an", "-c:v", "copy", "-f", "image2pipe", "-"};
    } else {
        return tl::unexpected("No cover art or video stream found");
    }

    std::ofstream out(output_image_path, std::ios::binary);
    if (!out) {
        return tl::unexpected("Failed to open output image file for writing");
    }

    auto callback = [&out](const uint8_t *data, size_t size) {
        out.write(reinterpret_cast<const char *>(data), size);
    };

    // Limit to 10MB to prevent disk exhaustion DoS
    auto result = ProcessRunner::run(args, callback, 10 * 1024 * 1024);
    out.close();

    if (!result) {
        std::filesystem::remove(output_image_path);
        return tl::unexpected("Process execution failed or output limit exceeded: " + result.error());
    }

    if (result.value() != 0) {
        std::filesystem::remove(output_image_path);
        return tl::unexpected("ffmpeg exited with code: " + std::to_string(result.value()));
    }

    return {};
}

} // namespace utils
} // namespace lyra
