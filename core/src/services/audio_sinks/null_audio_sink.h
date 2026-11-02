/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "lyra_plugin_api.h"
#include "services/audio_sinks/audio_sink_factory.h"
#include <atomic>
#include <cstdint>
#include <mutex>

namespace lyra {

class NullAudioSinkImpl {
  public:
    NullAudioSinkImpl();
    ~NullAudioSinkImpl();

    int open(const LyraAudioSpec *spec);
    int start();
    int stop();
    int close();
    int write_pcm(const void *pcm_data, uint32_t frame_count);
    int set_volume(float volume);
    int flush() { return 0; }
    uint32_t get_buffered_frames() const { return 0; }

    bool is_open() const { return m_open.load(); }
    bool is_playing() const { return m_playing.load(); }
    float get_volume() const { return m_volume.load(); }
    uint64_t get_written_frames() const { return m_written_frames.load(); }
    LyraAudioSpec get_spec() const {
        std::lock_guard<std::mutex> lock(m_spec_mutex);
        return m_spec;
    }

  private:
    std::atomic<bool> m_open{false};
    std::atomic<bool> m_playing{false};
    std::atomic<float> m_volume{1.0f};
    std::atomic<uint32_t> m_sample_rate{0};
    mutable std::mutex m_spec_mutex;
    LyraAudioSpec m_spec{};
    std::atomic<uint64_t> m_written_frames{0};
};

} // namespace lyra
