/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "lyra_plugin_api.h"
#include <atomic>
#include <cstdint>

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

    bool is_open() const { return m_open; }
    bool is_playing() const { return m_playing; }
    float get_volume() const { return m_volume; }
    uint64_t get_written_frames() const { return m_written_frames; }
    LyraAudioSpec get_spec() const { return m_spec; }

  private:
    bool m_open{false};
    bool m_playing{false};
    float m_volume{1.0f};
    LyraAudioSpec m_spec{};
    std::atomic<uint64_t> m_written_frames{0};
};

LyraAudioSink *create_null_audio_sink();
void destroy_null_audio_sink(LyraAudioSink *sink);

} // namespace lyra
