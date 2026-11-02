/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include "lyra_plugin_api.h"
#include "services/audio_decoder.h"
#include "services/audio_device_info.h"
#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>
#include <string>
#include <thread>
#include <vector>

namespace lyra {

enum class AudioEngineState {
    STOPPED,
    PLAYING,
    PAUSED
};

enum class AudioEngineError {
    None,
    InvalidArgument,
    DecoderFailure,
    DeviceUnavailable
};

using EventCallbackFunc = std::function<void(const std::string &json_event)>;
using SinkDeleter = void (*)(LyraAudioSink *);
using ConfigDowngradeCallback =
    std::function<void(const std::string &category, const std::string &key, const nlohmann::json &value)>;

class AudioEngine {
  public:
    explicit AudioEngine(LyraAudioSink *sink = nullptr, SinkDeleter deleter = nullptr);
    ~AudioEngine();

    // Prevent copying
    AudioEngine(const AudioEngine &) = delete;
    AudioEngine &operator=(const AudioEngine &) = delete;

    // Helper factory to create AudioEngine with null sink (headless / test-friendly)
    static std::unique_ptr<AudioEngine> create_null_engine();

    // Set custom C-ABI audio sink (takes ownership or uses custom deleter)
    void set_sink(LyraAudioSink *sink, SinkDeleter deleter = nullptr);

    // Set event callback
    void set_event_callback(EventCallbackFunc callback);

    // Downgrade notification callback (Dependency Inversion)
    // TODO(ui-event): Emit a dedicated event (e.g. "audio_config_downgraded" or include structured JSON payload) so that the UI layer / frontend can receive proactive notifications and inform the user when hardware negotiation triggers parameter fallback (e.g. exclusive mode or buffer size unsupported).
    void set_config_downgrade_callback(ConfigDowngradeCallback callback);

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
    // TODO(hotplug): Subscribe to sink/backend device hotplug notifications and emit "audio_devices_changed" / "audio_device_disconnected" events so the UI can dynamically update its device list.
    std::vector<AudioDeviceInfo> list_devices() const;
    bool set_output_device(const std::string &device_id);
    bool restore_output_device(const std::string &device_id);
    std::string get_output_device() const;

    // Buffer size & Exclusive mode
    static constexpr uint32_t DEFAULT_BUFFER_SIZE_FRAMES = lyra::DEFAULT_BUFFER_SIZE_FRAMES;
    static constexpr uint32_t MIN_BUFFER_SIZE_FRAMES = lyra::MIN_BUFFER_SIZE_FRAMES;
    static constexpr uint32_t MAX_BUFFER_SIZE_FRAMES = lyra::MAX_BUFFER_SIZE_FRAMES;

    bool set_buffer_size_frames(uint32_t frames);
    uint32_t get_buffer_size_frames() const;
    bool set_exclusive_mode(bool exclusive);
    bool get_exclusive_mode() const;

    // Query operations
    bool is_custom_sink_set() const;
    AudioEngineState get_state_enum() const;
    AudioEngineError get_last_error() const;
    std::string get_state_string() const;
    double get_position() const;
    double get_duration() const;
    float get_volume() const;
    std::string get_current_file_path() const;
    bool is_decoder_open() const; // basically build for testing
    uint64_t get_track_epoch() const { return m_track_epoch.load(std::memory_order_acquire); }

    nlohmann::json get_state_json() const;

  private:
    struct DowngradeItem {
        std::string category;
        std::string key;
        nlohmann::json value;
    };

    void pump_loop();
    void emit_state_event(const std::string &event_name = "audio_state_changed");
    void close_decoder_unlocked();
    void cleanup_retired_sinks_unlocked();
    void apply_sink_config_unlocked();
    void apply_sink_config_unlocked(std::vector<DowngradeItem> &downgrades);

    LyraAudioSink *m_sink{nullptr};
    void (*m_sink_deleter)(LyraAudioSink *){nullptr};
    std::vector<std::pair<LyraAudioSink *, SinkDeleter>> m_retired_sinks;
    bool m_sink_is_fallback{false};
    bool m_custom_sink_set{false};
    std::string m_current_device_id{"default"};
    uint32_t m_buffer_size_frames{DEFAULT_BUFFER_SIZE_FRAMES};
    bool m_exclusive_mode{false};

    mutable std::recursive_mutex m_mutex;
    AudioEngineState m_state{AudioEngineState::STOPPED};
    AudioEngineError m_last_error{AudioEngineError::None};
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
    std::atomic<uint64_t> m_track_epoch{0};

    // Worker pump thread
    std::thread m_pump_thread;
    std::atomic<bool> m_pump_running{false};

    EventCallbackFunc m_event_callback;
    ConfigDowngradeCallback m_config_downgrade_callback;
};

} // namespace lyra
