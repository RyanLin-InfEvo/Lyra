/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "audio_helper.h"
#include "../models/audio.h"
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

// extract metadata from media file using ffprobe
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

    // Limit output size to 2MB
    auto result = ProcessRunner::run(args, callback, 2 * 1024 * 1024);
    if (!result)
        return tl::unexpected("Process execution failed: " + result.error());

    if (result.value() != 0)
        return tl::unexpected("ffprobe exited with code: " + std::to_string(result.value()));

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

namespace {

bool ends_with_case_insensitive(std::string_view str, std::string_view suffix) {
    if (str.length() < suffix.length()) return false;
    auto str_suffix = str.substr(str.length() - suffix.length());
    return std::equal(str_suffix.begin(), str_suffix.end(), suffix.begin(), suffix.end(),
                      [](char a, char b) {
                          return std::tolower(static_cast<unsigned char>(a)) ==
                                 std::tolower(static_cast<unsigned char>(b));
                      });
}

bool contains_case_insensitive(std::string_view str, std::string_view sub) {
    if (sub.empty()) return true;
    if (str.length() < sub.length()) return false;
    auto it = std::search(
        str.begin(), str.end(),
        sub.begin(), sub.end(),
        [](char a, char b) {
            return std::tolower(static_cast<unsigned char>(a)) ==
                   std::tolower(static_cast<unsigned char>(b));
        });
    return it != str.end();
}

bool is_asset_lossless(const Asset &asset) {
    const std::string &mime = asset.mime_type;
    const std::string &hash = asset.file_hash;

    if (contains_case_insensitive(mime, "audio/flac") ||
        contains_case_insensitive(mime, "audio/x-wav") ||
        contains_case_insensitive(mime, "audio/wav") ||
        contains_case_insensitive(mime, "audio/alac") ||
        contains_case_insensitive(mime, "audio/aiff") ||
        contains_case_insensitive(mime, "audio/x-aiff")) {
        return true;
    }

    if (ends_with_case_insensitive(mime, ".flac") || ends_with_case_insensitive(hash, ".flac") ||
        ends_with_case_insensitive(mime, ".wav") || ends_with_case_insensitive(hash, ".wav") ||
        ends_with_case_insensitive(mime, ".alac") || ends_with_case_insensitive(hash, ".alac") ||
        ends_with_case_insensitive(mime, ".aiff") || ends_with_case_insensitive(hash, ".aiff") ||
        ends_with_case_insensitive(mime, ".aif") || ends_with_case_insensitive(hash, ".aif")) {
        return true;
    }

    return false;
}

std::string detect_asset_codec(const Asset *asset, bool is_lossless) {
    if (asset) {
        const std::string &mime = asset->mime_type;
        const std::string &hash = asset->file_hash;

        if (contains_case_insensitive(mime, "audio/flac") || ends_with_case_insensitive(mime, ".flac") || ends_with_case_insensitive(hash, ".flac")) {
            return "FLAC";
        }
        if (contains_case_insensitive(mime, "audio/mp3") || contains_case_insensitive(mime, "audio/mpeg") || ends_with_case_insensitive(mime, ".mp3") || ends_with_case_insensitive(hash, ".mp3")) {
            return "MP3";
        }
        if (contains_case_insensitive(mime, "audio/wav") || contains_case_insensitive(mime, "audio/x-wav") || ends_with_case_insensitive(mime, ".wav") || ends_with_case_insensitive(hash, ".wav")) {
            return "WAV";
        }
        if (contains_case_insensitive(mime, "audio/alac") || ends_with_case_insensitive(mime, ".alac") || ends_with_case_insensitive(hash, ".alac")) {
            return "ALAC";
        }
        if (contains_case_insensitive(mime, "audio/aiff") || contains_case_insensitive(mime, "audio/x-aiff") ||
            ends_with_case_insensitive(mime, ".aiff") || ends_with_case_insensitive(hash, ".aiff") ||
            ends_with_case_insensitive(mime, ".aif") || ends_with_case_insensitive(hash, ".aif")) {
            return "AIFF";
        }
        if (contains_case_insensitive(mime, "audio/aac") || contains_case_insensitive(mime, "audio/mp4") || contains_case_insensitive(mime, "audio/m4a") ||
            ends_with_case_insensitive(mime, ".aac") || ends_with_case_insensitive(hash, ".aac") ||
            ends_with_case_insensitive(mime, ".m4a") || ends_with_case_insensitive(hash, ".m4a")) {
            return "AAC";
        }
        if (contains_case_insensitive(mime, "audio/ogg") || contains_case_insensitive(mime, "audio/vorbis") ||
            ends_with_case_insensitive(mime, ".ogg") || ends_with_case_insensitive(hash, ".ogg")) {
            return "OGG";
        }
        if (contains_case_insensitive(mime, "audio/opus") || ends_with_case_insensitive(mime, ".opus") || ends_with_case_insensitive(hash, ".opus")) {
            return "OPUS";
        }
    }
    return is_lossless ? "FLAC" : "MP3";
}

} // namespace

AudioQualityInfo AudioHelper::evaluate_quality(const Audio &audio, const Asset &asset) {
    // 1. Bit Depth Score (0~25)
    int bit_depth_score = 0;
    if (audio.bit_depth >= 24) {
        bit_depth_score = 25;
    } else if (audio.bit_depth >= 16) {
        bit_depth_score = 18;
    } else {
        bit_depth_score = 8;
    }

    // 2. Sample Rate Score (0~25)
    int sample_rate_score = 0;
    if (audio.sample_rate >= 192000) {
        sample_rate_score = 25;
    } else if (audio.sample_rate >= 96000) {
        sample_rate_score = 22;
    } else if (audio.sample_rate >= 88200) {
        sample_rate_score = 20;
    } else if (audio.sample_rate >= 48000) {
        sample_rate_score = 16;
    } else if (audio.sample_rate >= 44100) {
        sample_rate_score = 15;
    } else {
        sample_rate_score = 10;
    }

    int resolution_score = bit_depth_score + sample_rate_score;

    // 3. Lossless / Bitrate Score (0~45)
    bool is_lossless = is_asset_lossless(asset);
    int lossless_bitrate_score = 0;
    if (is_lossless) {
        lossless_bitrate_score = 45;
    } else {
        double bitrate = 0.0;
        if (audio.duration > 0.0 && asset.file_size > 0) {
            bitrate = (static_cast<double>(asset.file_size) * 8.0) / audio.duration;
        }
        if (bitrate >= 320000.0) {
            lossless_bitrate_score = 30;
        } else if (bitrate >= 256000.0) {
            lossless_bitrate_score = 25;
        } else if (bitrate >= 192000.0) {
            lossless_bitrate_score = 18;
        } else if (bitrate >= 128000.0) {
            lossless_bitrate_score = 10;
        } else {
            lossless_bitrate_score = 5;
        }
    }

    // 4. Channels Score (0~5)
    int channels_score = 0;
    if (audio.channels >= 2) {
        channels_score = 5;
    } else if (audio.channels == 1) {
        channels_score = 2;
    } else {
        channels_score = 0;
    }

    int total_quality_score = resolution_score + lossless_bitrate_score + channels_score;

    // 5. Format string formatting
    std::string codec = detect_asset_codec(&asset, is_lossless);

    int bit_depth = audio.bit_depth > 0 ? audio.bit_depth : 16;
    std::string bit_depth_str = std::to_string(bit_depth) + "-bit";

    int sample_rate = audio.sample_rate > 0 ? audio.sample_rate : 44100;
    std::string sample_rate_str;
    if (sample_rate % 1000 == 0) {
        sample_rate_str = std::to_string(sample_rate / 1000) + "kHz";
    } else {
        std::ostringstream ss;
        ss << (sample_rate / 1000.0) << "kHz";
        sample_rate_str = ss.str();
    }

    std::string format_str = codec + " " + bit_depth_str + " / " + sample_rate_str;

    AudioQualityInfo result;
    result.quality_score = total_quality_score;
    result.is_lossless = is_lossless;
    result.format = format_str;
    result.file_size = asset.file_size;

    return result;
}

AudioQualityInfo AudioHelper::evaluate_quality(const Audio &audio) {
    if (audio.assets.empty()) {
        Asset default_asset;
        return evaluate_quality(audio, default_asset);
    }

    const Asset *primary_asset = nullptr;
    bool any_lossless = false;

    for (const auto &asset : audio.assets) {
        bool current_lossless = is_asset_lossless(asset);
        if (current_lossless) {
            any_lossless = true;
        }

        if (!primary_asset) {
            primary_asset = &asset;
            continue;
        }

        bool primary_is_lossless = is_asset_lossless(*primary_asset);
        if (current_lossless && !primary_is_lossless) {
            primary_asset = &asset;
        } else if (current_lossless == primary_is_lossless) {
            if (asset.file_size > primary_asset->file_size) {
                primary_asset = &asset;
            }
        }
    }

    auto qinfo = evaluate_quality(audio, *primary_asset);
    if (any_lossless) {
        qinfo.is_lossless = true;
    }
    return qinfo;
}

bool AudioHelper::matches_format(const Asset &asset, const std::string &preferred_format) {
    if (preferred_format.empty()) {
        return false;
    }
    std::string fmt = preferred_format;
    std::transform(fmt.begin(), fmt.end(), fmt.begin(), [](unsigned char c) {
        return std::tolower(c);
    });
    if (!fmt.empty() && fmt.front() == '.') {
        fmt.erase(0, 1);
    }
    if (fmt.rfind("audio/", 0) == 0) {
        fmt.erase(0, 6);
    }
    if (fmt.rfind("x-", 0) == 0) {
        fmt.erase(0, 2);
    }

    const std::string &mime = asset.mime_type;
    const std::string &hash = asset.file_hash;

    if (fmt == "flac") {
        return contains_case_insensitive(mime, "audio/flac") ||
               ends_with_case_insensitive(mime, ".flac") ||
               ends_with_case_insensitive(hash, ".flac");
    }
    if (fmt == "wav") {
        return contains_case_insensitive(mime, "audio/wav") ||
               contains_case_insensitive(mime, "audio/x-wav") ||
               ends_with_case_insensitive(mime, ".wav") ||
               ends_with_case_insensitive(hash, ".wav");
    }
    if (fmt == "mp3" || fmt == "mpeg") {
        return contains_case_insensitive(mime, "audio/mp3") ||
               contains_case_insensitive(mime, "audio/mpeg") ||
               ends_with_case_insensitive(mime, ".mp3") ||
               ends_with_case_insensitive(hash, ".mp3");
    }
    if (fmt == "alac") {
        return contains_case_insensitive(mime, "audio/alac") ||
               ends_with_case_insensitive(mime, ".alac") ||
               ends_with_case_insensitive(hash, ".alac");
    }
    if (fmt == "aiff" || fmt == "aif") {
        return contains_case_insensitive(mime, "audio/aiff") ||
               contains_case_insensitive(mime, "audio/x-aiff") ||
               ends_with_case_insensitive(mime, ".aiff") ||
               ends_with_case_insensitive(hash, ".aiff") ||
               ends_with_case_insensitive(mime, ".aif") ||
               ends_with_case_insensitive(hash, ".aif");
    }
    if (fmt == "ogg" || fmt == "vorbis") {
        return contains_case_insensitive(mime, "audio/ogg") ||
               contains_case_insensitive(mime, "audio/vorbis") ||
               ends_with_case_insensitive(mime, ".ogg") ||
               ends_with_case_insensitive(hash, ".ogg");
    }
    if (fmt == "m4a") {
        return contains_case_insensitive(mime, "audio/m4a") ||
               contains_case_insensitive(mime, "audio/mp4") ||
               ends_with_case_insensitive(mime, ".m4a") ||
               ends_with_case_insensitive(hash, ".m4a");
    }
    if (fmt == "aac") {
        return contains_case_insensitive(mime, "audio/aac") ||
               contains_case_insensitive(mime, "audio/m4a") ||
               contains_case_insensitive(mime, "audio/mp4") ||
               ends_with_case_insensitive(mime, ".aac") ||
               ends_with_case_insensitive(hash, ".aac") ||
               ends_with_case_insensitive(mime, ".m4a") ||
               ends_with_case_insensitive(hash, ".m4a");
    }

    return contains_case_insensitive(mime, fmt) ||
           ends_with_case_insensitive(mime, "." + fmt) ||
           ends_with_case_insensitive(hash, "." + fmt);
}

} // namespace utils
} // namespace lyra
