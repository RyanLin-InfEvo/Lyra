/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <tl/expected.hpp>
#include <utility>
#include <vector>

namespace lyra {

struct WaveformData {
    std::string pcm_hash;
    uint32_t points{0};
    std::vector<std::pair<float, float>> peaks; // [min, max] Range (min <= 0.0, max >= 0.0)
    std::vector<float> rms;                     // RMS (0.0 ~ 1.0)
};

class WaveformService {
  public:
    static constexpr uint32_t BASE_POINTS = 1000;

    // Extract waveform points directly from raw interleaved Float32 PCM samples
    static WaveformData extract_from_pcm(
        const float *samples, uint64_t total_frames, uint8_t channels, uint32_t points);

    // Decode audio file via AudioDecoder to Float32 PCM and extract waveform
    static tl::expected<WaveformData, std::string> extract_from_file(
        const std::filesystem::path &filepath, uint32_t points = BASE_POINTS);

    // Save waveform data to disk using Plan B binary cache specification (LWAV)
    static tl::expected<void, std::string> save_to_cache(
        const std::filesystem::path &storage_root, const std::string &pcm_hash, const WaveformData &data);

    // Load waveform data from disk cache and validate binary structure & values
    static tl::expected<WaveformData, std::string> load_from_cache(
        const std::filesystem::path &storage_root, const std::string &pcm_hash);

    // Resample waveform data to target points using bucket peak-preservation (downsampling) or interpolation
    static WaveformData resample_waveform(const WaveformData &source, uint32_t target_points);

    // Retrieve from cache or compute from audio file with self-healing fallback
    static tl::expected<WaveformData, std::string> get_or_compute_waveform(
        const std::filesystem::path &storage_root,
        const std::string &pcm_hash,
        const std::filesystem::path &audio_file_path,
        uint32_t target_points = 300);

    // Helper to resolve cache file path
    static std::filesystem::path get_cache_path(
        const std::filesystem::path &storage_root, const std::string &pcm_hash);
};

} // namespace lyra
