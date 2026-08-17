/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "lyra_plugin_api.h"
#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>
#include <string>
#include <thread>

namespace lyra {

enum class AudioEngineState {
    STOPPED,
    PLAYING,
    PAUSED
};

using EventCallbackFunc = std::function<void(const std::string &json_event)>;
using SinkDeleter = void (*)(LyraAudioSink *);

class AudioEngine {
  public:
    AudioEngine();
    ~AudioEngine();

    // Prevent copying
    AudioEngine(const AudioEngine &) = delete;
    AudioEngine &operator=(const AudioEngine &) = delete;

    // Set custom C-ABI audio sink (takes ownership or uses custom deleter)
    void set_sink(LyraAudioSink *sink, SinkDeleter deleter = nullptr);

    // Set event callback
    void set_event_callback(EventCallbackFunc callback);

    // Control operations
    bool play(const std::string &file_path);
    bool pause();
    bool resume();
    bool stop();
    bool seek(double position_seconds);
    bool set_volume(float volume);

    // Query operations
    AudioEngineState get_state_enum() const;
    std::string get_state_string() const;
    double get_position() const;
    double get_duration() const;
    float get_volume() const;
    std::string get_current_file_path() const;

    nlohmann::json get_state_json() const;

  private:
    void pump_loop();
    void emit_state_event(const std::string &event_name = "audio_state_changed");
    void close_decoder_unlocked();

    LyraAudioSink *m_sink{nullptr};
    void (*m_sink_deleter)(LyraAudioSink *){nullptr};

    mutable std::recursive_mutex m_mutex;
    AudioEngineState m_state{AudioEngineState::STOPPED};
    float m_volume{1.0f};
    std::string m_current_file_path;

    // miniaudio decoder handle (void* to avoid exposing miniaudio.h in public header)
    void *m_decoder_ptr{nullptr};
    bool m_decoder_initialized{false};
    uint32_t m_sample_rate{44100};
    uint8_t m_channels{2};
    uint64_t m_total_frames{0};
    std::atomic<uint64_t> m_current_frame{0};
    uint64_t m_seek_epoch{0};

    // Worker pump thread
    std::thread m_pump_thread;
    std::atomic<bool> m_pump_running{false};

    EventCallbackFunc m_event_callback;
};

} // namespace lyra
