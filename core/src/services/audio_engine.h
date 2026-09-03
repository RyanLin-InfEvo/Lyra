/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "lyra_plugin_api.h"
#include "services/audio_decoder.h"
#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>
#include <string>
#include <thread>
#include <vector>

namespace lyra {

struct AudioDeviceInfo {
    std::string id;
    std::string name;
    bool is_default{false};
    int min_channels{1};
    int max_channels{2};
    int min_sample_rate{44100};
    int max_sample_rate{192000};
};

inline void to_json(nlohmann::json &j, const AudioDeviceInfo &info) {
    j = nlohmann::json{
        {"id", info.id},
        {"name", info.name},
        {"is_default", info.is_default},
        {"min_channels", info.min_channels},
        {"max_channels", info.max_channels},
        {"min_sample_rate", info.min_sample_rate},
        {"max_sample_rate", info.max_sample_rate}};
}

inline void from_json(const nlohmann::json &j, AudioDeviceInfo &info) {
    if (j.contains("id")) info.id = j["id"].get<std::string>();
    if (j.contains("name")) info.name = j["name"].get<std::string>();
    if (j.contains("is_default")) info.is_default = j["is_default"].get<bool>();
    if (j.contains("min_channels")) info.min_channels = j["min_channels"].get<int>();
    if (j.contains("max_channels")) info.max_channels = j["max_channels"].get<int>();
    if (j.contains("min_sample_rate")) info.min_sample_rate = j["min_sample_rate"].get<int>();
    if (j.contains("max_sample_rate")) info.max_sample_rate = j["max_sample_rate"].get<int>();
}

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
    bool play(const std::string &file_path, double start_position_seconds = 0.0);
    bool pause();
    bool resume();
    bool stop();
    bool seek(double position_seconds, bool relative = false);
    bool set_volume(float volume);

    // Gapless playback & preloading
    bool preload_next(const std::string &file_path);
    std::string get_next_file_path() const;

    // Device management
    std::vector<AudioDeviceInfo> list_devices() const;
    bool set_output_device(const std::string &device_id);
    std::string get_output_device() const;

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
    bool m_sink_is_fallback{false};
    bool m_custom_sink_set{false};
    std::string m_current_device_id{"default"};

    mutable std::recursive_mutex m_mutex;
    AudioEngineState m_state{AudioEngineState::STOPPED};
    float m_volume{1.0f};
    std::string m_current_file_path;

    // Universal Audio Decoder (FFmpeg backend)
    std::unique_ptr<AudioDecoder> m_decoder;
    std::unique_ptr<AudioDecoder> m_next_decoder;
    std::string m_next_file_path;
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
