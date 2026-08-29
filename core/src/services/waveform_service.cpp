/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/waveform_service.h"
#include "services/audio_decoder.h"
#include "utils/uuid_generator.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <filesystem>
#include <fmt/core.h>
#include <fstream>
#include <vector>

namespace lyra {

// ============================================================================
// Binary Cache File Format (LWAV Specification)
// ============================================================================
// Binary layout:
//   [WaveformHeader (16 bytes)]
//   [WaveformPointRecord (12 bytes) * points]
//
// Strict 1-byte packing guarantees consistent memory layout across platforms
// and compilers without unexpected structure padding.
#pragma pack(push, 1)
struct WaveformHeader {
    char magic[4];     // Magic identifier: "LWAV"
    uint32_t version;  // Format version (currently 1)
    uint32_t points;   // Number of waveform points stored (e.g., 1000)
    uint32_t reserved; // Reserved for future extensions / alignment (set to 0)
};

struct WaveformPointRecord {
    float min; // Peak negative amplitude: [-1.0f, 0.0f]
    float max; // Peak positive amplitude: [0.0f, 1.0f]
    float rms; // Root-mean-square energy: [0.0f, 1.0f]
};
#pragma pack(pop)

// Compile-time verification of binary structure sizes
static_assert(sizeof(WaveformHeader) == 16, "WaveformHeader must be 16 bytes");
static_assert(sizeof(WaveformPointRecord) == 12, "WaveformPointRecord must be 12 bytes");

std::filesystem::path WaveformService::get_cache_path(
    const std::filesystem::path &storage_root, const std::string &pcm_hash) {
    return storage_root / ".cache" / "waveforms" / (pcm_hash + ".bin");
}

WaveformData WaveformService::extract_from_pcm(
    const float *samples, uint64_t total_frames, uint8_t channels, uint32_t points) {
    WaveformData result;
    result.points = points;

    if (points == 0) {
        return result;
    }

    // Fast-path for empty or invalid input: return zero-filled data
    if (samples == nullptr || total_frames == 0 || channels == 0) {
        result.peaks.assign(points, {0.0f, 0.0f});
        result.rms.assign(points, 0.0f);
        return result;
    }

    result.peaks.resize(points);
    result.rms.resize(points);

    // Partition the total audio frames into N equal-sized buckets (time slices)
    for (uint32_t i = 0; i < points; ++i) {
        uint64_t start_frame = (static_cast<uint64_t>(i) * total_frames) / points;
        uint64_t end_frame = (static_cast<uint64_t>(i + 1) * total_frames) / points;
        if (end_frame <= start_frame) {
            end_frame = std::min(start_frame + 1, total_frames);
        }

        float min_val = 0.0f;
        float max_val = 0.0f;
        double sum_sq = 0.0;
        uint64_t count = 0;

        for (uint64_t f = start_frame; f < end_frame && f < total_frames; ++f) { // frames
            for (uint8_t c = 0; c < channels; ++c) {                             // channels
                float s = samples[f * static_cast<uint64_t>(channels) + c];
                // Filter out non-finite samples (NaN / Inf) caused by decoding errors
                if (std::isnan(s) || std::isinf(s)) {
                    continue;
                }
                s = std::clamp(s, -1.0f, 1.0f);
                min_val = std::min(min_val, s);
                max_val = std::max(max_val, s);
                sum_sq += static_cast<double>(s) * s;
                count++;
            }
        }

        // Compute RMS energy and store normalized peak range
        if (count > 0) {
            float rms_val = static_cast<float>(std::sqrt(sum_sq / count));
            result.peaks[i] = {std::clamp(min_val, -1.0f, 0.0f), std::clamp(max_val, 0.0f, 1.0f)};
            result.rms[i] = std::clamp(rms_val, 0.0f, 1.0f);
        } else {
            result.peaks[i] = {0.0f, 0.0f};
            result.rms[i] = 0.0f;
        }
    }

    return result;
}

tl::expected<WaveformData, std::string> WaveformService::extract_from_file(
    const std::filesystem::path &filepath, uint32_t points) {
    if (!std::filesystem::exists(filepath)) {
        return tl::make_unexpected("Audio file not found: " + filepath.string());
    }

    AudioDecoder decoder;
    if (!decoder.open(filepath.string())) {
        return tl::make_unexpected("Failed to open audio file: " + filepath.string());
    }

    uint8_t channels = decoder.get_channels();
    if (channels == 0) {
        return tl::make_unexpected("Audio file has 0 channels: " + filepath.string());
    }

    // Decode audio stream in fixed-size chunk buffers to avoid large heap spikes
    std::vector<float> pcm_data;
    constexpr uint32_t CHUNK_FRAMES = 16384;
    std::vector<float> chunk(CHUNK_FRAMES * static_cast<size_t>(channels));

    while (true) {
        uint32_t frames_read = decoder.read_pcm_frames(chunk.data(), CHUNK_FRAMES);
        if (frames_read == 0) {
            break;
        }
        pcm_data.insert(pcm_data.end(), chunk.begin(), chunk.begin() + (frames_read * static_cast<size_t>(channels)));
    }

    uint64_t total_frames = pcm_data.size() / channels;
    WaveformData result = extract_from_pcm(pcm_data.data(), total_frames, channels, points);
    return result;
}

tl::expected<void, std::string> WaveformService::save_to_cache(
    const std::filesystem::path &storage_root, const std::string &pcm_hash, const WaveformData &data) {
    if (pcm_hash.empty()) {
        return tl::make_unexpected("pcm_hash cannot be empty");
    }
    if (data.points == 0 || data.peaks.size() != data.points || data.rms.size() != data.points) {
        return tl::make_unexpected("Invalid waveform data points count or size mismatch");
    }

    auto cache_dir = storage_root / ".cache" / "waveforms";
    std::error_code ec;
    std::filesystem::create_directories(cache_dir, ec);
    if (ec) {
        return tl::make_unexpected("Failed to create waveform cache directory: " + ec.message());
    }

    auto target_file = get_cache_path(storage_root, pcm_hash);
    // Write to a temporary file first, then atomically rename to avoid partial/corrupt writes
    auto tmp_file = cache_dir / (pcm_hash + "." + UuidGenerator::generate_v4() + ".tmp");

    {
        std::ofstream out(tmp_file, std::ios::binary | std::ios::trunc);
        if (!out.is_open()) {
            return tl::make_unexpected("Failed to open temp cache file for writing: " + tmp_file.string());
        }

        // 1. Serialize 16-byte header
        WaveformHeader header;
        std::memcpy(header.magic, "LWAV", 4);
        header.version = 1;
        header.points = data.points;
        header.reserved = 0;

        out.write(reinterpret_cast<const char *>(&header), sizeof(header));

        // 2. Serialize continuous array of point records
        std::vector<WaveformPointRecord> records(data.points);
        for (uint32_t i = 0; i < data.points; ++i) {
            records[i].min = data.peaks[i].first;
            records[i].max = data.peaks[i].second;
            records[i].rms = data.rms[i];
        }

        out.write(
            reinterpret_cast<const char *>(records.data()),
            static_cast<std::streamsize>(records.size() * sizeof(WaveformPointRecord)));
        out.flush();

        if (!out.good()) {
            out.close();
            std::filesystem::remove(tmp_file, ec);
            return tl::make_unexpected("Failed to write waveform data to temp file: " + tmp_file.string());
        }
    }

    // Atomically move temporary cache file to final destination
    std::filesystem::rename(tmp_file, target_file, ec);
    if (ec) {
        std::filesystem::remove(tmp_file, ec);
        return tl::make_unexpected("Failed to atomically rename cache file: " + ec.message());
    }

    return {};
}

tl::expected<WaveformData, std::string> WaveformService::load_from_cache(
    const std::filesystem::path &storage_root, const std::string &pcm_hash) {
    if (pcm_hash.empty()) {
        return tl::make_unexpected("pcm_hash cannot be empty");
    }

    auto cache_file = get_cache_path(storage_root, pcm_hash);
    if (!std::filesystem::exists(cache_file)) {
        return tl::make_unexpected("Cache file not found: " + cache_file.string());
    }

    std::error_code ec;
    auto file_size = std::filesystem::file_size(cache_file, ec);
    if (ec) {
        return tl::make_unexpected("Failed to get cache file size: " + ec.message());
    }

    // Defensive check: ensure file is at least large enough to contain the header
    if (file_size < sizeof(WaveformHeader)) {
        return tl::make_unexpected("Corrupted cache file (file too small for header)");
    }

    std::ifstream in(cache_file, std::ios::binary);
    if (!in.is_open()) {
        return tl::make_unexpected("Failed to open cache file: " + cache_file.string());
    }

    // 1. Read and validate 16-byte header
    WaveformHeader header;
    in.read(reinterpret_cast<char *>(&header), sizeof(header));
    if (!in.good()) {
        return tl::make_unexpected("Failed to read cache header");
    }

    if (std::memcmp(header.magic, "LWAV", 4) != 0) {
        return tl::make_unexpected("Corrupted cache file (invalid magic header)");
    }

    if (header.version != 1) {
        return tl::make_unexpected(
            "Corrupted cache file (unsupported version: " + std::to_string(header.version) + ")");
    }

    if (header.points == 0) {
        return tl::make_unexpected("Corrupted cache file (zero points count)");
    }

    // Verify exact file size matches: sizeof(Header) + points * sizeof(Record)
    uintmax_t expected_size =
        sizeof(WaveformHeader) + static_cast<uintmax_t>(header.points) * sizeof(WaveformPointRecord);
    if (file_size != expected_size) {
        return tl::make_unexpected(
            "Corrupted cache file (size mismatch: expected " + std::to_string(expected_size) +
            " bytes, got " + std::to_string(file_size) + " bytes)");
    }

    // 2. Read point records payload
    std::vector<WaveformPointRecord> records(header.points);
    in.read(
        reinterpret_cast<char *>(records.data()),
        static_cast<std::streamsize>(records.size() * sizeof(WaveformPointRecord)));
    if (!in.good()) {
        return tl::make_unexpected("Failed to read waveform points data");
    }

    WaveformData data;
    data.pcm_hash = pcm_hash;
    data.points = header.points;
    data.peaks.resize(header.points);
    data.rms.resize(header.points);

    // 3. Validate numerical integrity and clamp values within safe display ranges
    for (uint32_t i = 0; i < header.points; ++i) {
        float min_val = records[i].min;
        float max_val = records[i].max;
        float rms_val = records[i].rms;

        if (std::isnan(min_val) || std::isinf(min_val) || std::isnan(max_val) || std::isinf(max_val) ||
            std::isnan(rms_val) || std::isinf(rms_val)) {
            return tl::make_unexpected(
                "Corrupted cache file (NaN/Inf values detected at point " + std::to_string(i) + ")");
        }

        if (min_val > 0.001f || max_val < -0.001f || min_val > max_val || rms_val < -0.001f ||
            rms_val > 1.001f) {
            return tl::make_unexpected(
                "Corrupted cache file (abnormal out-of-range values detected at point " +
                std::to_string(i) + ")");
        }

        data.peaks[i] = {std::clamp(min_val, -1.0f, 0.0f), std::clamp(max_val, 0.0f, 1.0f)};
        data.rms[i] = std::clamp(rms_val, 0.0f, 1.0f);
    }

    return data;
}

WaveformData WaveformService::resample_waveform(const WaveformData &source, uint32_t target_points) {
    // Return early if no resampling is needed or source/target has zero points
    if (source.points == target_points || target_points == 0 || source.points == 0) {
        WaveformData copy = source;
        copy.points = target_points;
        if (target_points == 0) {
            copy.peaks.clear();
            copy.rms.clear();
        } else if (source.points == 0) {
            copy.peaks.assign(target_points, {0.0f, 0.0f});
            copy.rms.assign(target_points, 0.0f);
        }
        return copy;
    }

    WaveformData result;
    result.pcm_hash = source.pcm_hash;
    result.points = target_points;
    result.peaks.resize(target_points);
    result.rms.resize(target_points);

    if (target_points < source.points) {
        // Downsampling: Preserve peaks (extremums) and RMS energy across source buckets
        for (uint32_t j = 0; j < target_points; ++j) {
            size_t start_idx = (static_cast<size_t>(j) * source.points) / target_points;
            size_t end_idx = (static_cast<size_t>(j + 1) * source.points) / target_points;
            if (end_idx <= start_idx) {
                end_idx = std::min(start_idx + 1, static_cast<size_t>(source.points));
            }

            float min_val = 0.0f;
            float max_val = 0.0f;
            double sum_rms_sq = 0.0;
            size_t count = 0;

            for (size_t k = start_idx; k < end_idx; ++k) {
                min_val = std::min(min_val, source.peaks[k].first);
                max_val = std::max(max_val, source.peaks[k].second);
                sum_rms_sq += static_cast<double>(source.rms[k]) * source.rms[k];
                count++;
            }

            float rms_val = (count > 0) ? static_cast<float>(std::sqrt(sum_rms_sq / count)) : 0.0f;
            result.peaks[j] = {std::clamp(min_val, -1.0f, 0.0f), std::clamp(max_val, 0.0f, 1.0f)};
            result.rms[j] = std::clamp(rms_val, 0.0f, 1.0f);
        }
    } else {
        // Upsampling: Linear interpolation between adjacent points
        for (uint32_t j = 0; j < target_points; ++j) {
            double src_pos = static_cast<double>(j) * (source.points - 1) /
                             (target_points > 1 ? target_points - 1 : 1);
            size_t idx0 = static_cast<size_t>(std::floor(src_pos));
            size_t idx1 = std::min(idx0 + 1, static_cast<size_t>(source.points - 1));
            double frac = src_pos - idx0;

            float min_val = static_cast<float>(
                (1.0 - frac) * source.peaks[idx0].first + frac * source.peaks[idx1].first);
            float max_val = static_cast<float>(
                (1.0 - frac) * source.peaks[idx0].second + frac * source.peaks[idx1].second);
            float rms_val =
                static_cast<float>((1.0 - frac) * source.rms[idx0] + frac * source.rms[idx1]);

            result.peaks[j] = {std::clamp(min_val, -1.0f, 0.0f), std::clamp(max_val, 0.0f, 1.0f)};
            result.rms[j] = std::clamp(rms_val, 0.0f, 1.0f);
        }
    }

    return result;
}

tl::expected<WaveformData, std::string> WaveformService::get_or_compute_waveform(
    const std::filesystem::path &storage_root,
    const std::string &pcm_hash,
    const std::filesystem::path &audio_file_path,
    uint32_t target_points) {
    if (pcm_hash.empty()) {
        return tl::make_unexpected("pcm_hash cannot be empty");
    }

    auto cache_file = get_cache_path(storage_root, pcm_hash);
    bool cache_loaded = false;
    WaveformData base_data;

    // Step 1: Attempt to load from disk cache
    if (std::filesystem::exists(cache_file)) {
        auto load_res = load_from_cache(storage_root, pcm_hash);
        if (load_res.has_value() && load_res->points == BASE_POINTS) {
            base_data = std::move(load_res.value());
            cache_loaded = true;
        } else {
            // Self-healing: If cache is corrupted or point count mismatches, purge it
            std::string reason = load_res.has_value() ? "Mismatched points" : load_res.error();
            fmt::print(
                stderr,
                "[Warning] Corrupted or invalid waveform cache detected for '{}': {}. Self-healing...\n",
                pcm_hash,
                reason);
            std::error_code ec;
            std::filesystem::remove(cache_file, ec);
        }
    }

    // Step 2: Compute base waveform (1000 points) from raw audio file on cache miss
    if (!cache_loaded) {
        if (!std::filesystem::exists(audio_file_path)) {
            return tl::make_unexpected("Audio file not found: " + audio_file_path.string());
        }

        auto extract_res = extract_from_file(audio_file_path, BASE_POINTS);
        if (!extract_res.has_value()) {
            return tl::make_unexpected(extract_res.error());
        }

        base_data = std::move(extract_res.value());
        base_data.pcm_hash = pcm_hash;

        // Persist computed base waveform to cache for future requests
        auto save_res = save_to_cache(storage_root, pcm_hash, base_data);
        if (!save_res.has_value()) {
            fmt::print(
                stderr,
                "[Warning] Failed to save waveform cache for '{}': {}\n",
                pcm_hash,
                save_res.error());
        }
    }

    // Step 3: Resample to the requested target points (e.g., 300 for UI widget)
    if (target_points == BASE_POINTS) {
        return base_data;
    }
    return resample_waveform(base_data, target_points);
}

} // namespace lyra
