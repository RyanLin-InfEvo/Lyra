/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <cstdint>
#include <memory>
#include <string>

namespace lyra {

class AudioDecoder {
  public:
    AudioDecoder();
    ~AudioDecoder();

    AudioDecoder(const AudioDecoder &) = delete;
    AudioDecoder &operator=(const AudioDecoder &) = delete;

    // Open an audio file. If target_sample_rate or target_channels is 0,
    // the source audio's native sample rate and channel count will be used.
    // Converted audio is interleaved 32-bit float (float32).
    bool open(const std::string &filepath, uint32_t target_sample_rate = 0, uint8_t target_channels = 0);

    // Read up to `max_frames` PCM frames (interleaved float32 samples).
    // `out_buffer` must have capacity of at least `max_frames * channels` floats.
    // Returns the number of frames actually read (0 indicates EOF or error).
    uint32_t read_pcm_frames(float *out_buffer, uint32_t max_frames);

    // Seek to target PCM frame index
    bool seek_frame(uint64_t target_frame);

    // Seek to target position in seconds
    bool seek_seconds(double seconds);

    // Close and release FFmpeg resources
    void close();

    bool is_open() const;
    uint32_t get_sample_rate() const;
    uint8_t get_channels() const;
    uint64_t get_total_frames() const;
    double get_duration() const;
    uint64_t get_current_frame() const;

  private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace lyra
