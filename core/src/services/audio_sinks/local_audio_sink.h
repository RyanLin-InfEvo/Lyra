/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "lyra_plugin_api.h"
#include "services/audio_device_info.h"
#include "services/audio_sinks/audio_sink_factory.h"
#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

namespace lyra {

class LocalAudioSinkImpl {
  public:
    struct InternalState;
    LocalAudioSinkImpl();
    ~LocalAudioSinkImpl();

    LocalAudioSinkImpl(const LocalAudioSinkImpl &) = delete;
    LocalAudioSinkImpl &operator=(const LocalAudioSinkImpl &) = delete;

    // General LyraAudioSink ->

    int open(const LyraAudioSpec *spec);
    int start();
    int stop();
    int close();
    int write_pcm(const void *pcm_data, uint32_t frame_count);
    int set_volume(float volume);
    int flush();
    uint32_t get_buffered_frames() const;

    // Only for LocalAudioSink ->

    bool set_output_device(const std::string &device_id);
    std::string get_output_device() const;
    static std::vector<AudioDeviceInfo> list_devices();
    static bool is_valid_device_id(const std::string &device_id);
    static bool is_device_available(const std::string &device_id);

    // Shared miniaudio context lifecycle management
    static bool shutdown_shared_context();
    static bool is_context_initialized(); // basically build for testing
    static int get_active_device_count(); // basically build for testing

    static constexpr uint32_t DEFAULT_BUFFER_SIZE_FRAMES = lyra::DEFAULT_BUFFER_SIZE_FRAMES;
    static constexpr uint32_t MIN_BUFFER_SIZE_FRAMES = lyra::MIN_BUFFER_SIZE_FRAMES;
    static constexpr uint32_t MAX_BUFFER_SIZE_FRAMES = lyra::MAX_BUFFER_SIZE_FRAMES;

    bool set_buffer_size_frames(uint32_t frames);
    uint32_t get_buffer_size_frames() const;

    bool set_exclusive_mode(bool exclusive);
    bool get_exclusive_mode() const;
    bool is_exclusive_mode_active() const;

    bool is_open() const;
    bool is_playing() const;
    float get_volume() const;

  private:
    bool init_device_unlocked(bool force_shared = false);
    bool reconfigure_device_unlocked(bool defer_if_stopped = false);
    void uninit_device_internal_unlocked();
    void cleanup_failed_device_unlocked();

    mutable std::recursive_mutex m_sink_mutex;
    InternalState *m_state{nullptr};

    bool m_open{false};
    bool m_playing{false};
    float m_volume{1.0f};
    LyraAudioSpec m_spec{};
};

} // namespace lyra
