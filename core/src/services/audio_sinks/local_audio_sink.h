/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "lyra_plugin_api.h"
#include "services/audio_engine.h"
#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

namespace lyra {

class LocalAudioSinkImpl {
  public:
    struct InternalState;
    LocalAudioSinkImpl();
    ~LocalAudioSinkImpl();

    int open(const LyraAudioSpec *spec);
    int start();
    int stop();
    int close();
    int write_pcm(const void *pcm_data, uint32_t frame_count);
    int set_volume(float volume);
    int flush();
    uint32_t get_buffered_frames() const;

    bool set_output_device(const std::string &device_id);
    std::string get_output_device() const;
    static std::vector<AudioDeviceInfo> list_devices();
    static bool is_valid_device_id(const std::string &device_id);

    bool is_open() const { return m_open; }
    bool is_playing() const { return m_playing; }
    float get_volume() const { return m_volume; }

  private:
    InternalState *m_state{nullptr};

    bool m_open{false};
    bool m_playing{false};
    float m_volume{1.0f};
    LyraAudioSpec m_spec{};
};

LyraAudioSink *create_local_audio_sink();
void destroy_local_audio_sink(LyraAudioSink *sink);

} // namespace lyra
