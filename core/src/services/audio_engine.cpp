/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_engine.h"
#include "services/audio_sinks/audio_sink_factory.h"

#include <chrono>
#include <cmath>
#include <cstddef>
#include <iostream>
#include <vector>

/**
 * @brief Checks if a LyraAudioSink instance supports a specific capability/callback.
 *
 * Provides backward-compatible C-ABI versioning and capability detection:
 * 1. Verifies the sink pointer is not null.
 * 2. Bounds check: Verifies that the sink's allocated struct_size covers the
 *    requested member (preventing out-of-bounds reads on older struct versions).
 * 3. Null check: Ensures the function pointer itself is implemented and not null.
 */
#define LYRA_SINK_HAS_CAP(sink, member)                                                                        \
    ((sink) != nullptr &&                                                                                      \
     (sink)->struct_size >= static_cast<uint32_t>(offsetof(LyraAudioSink, member) + sizeof((sink)->member)) && \
     (sink)->member != nullptr)

namespace lyra {

void AudioEngine::apply_sink_config_unlocked() {
    std::vector<DowngradeItem> ignored;
    apply_sink_config_unlocked(ignored);
}

void AudioEngine::apply_sink_config_unlocked(std::vector<DowngradeItem> &downgrades) {
    if (!m_sink) return;
    if (LYRA_SINK_HAS_CAP(m_sink, set_output_device)) {
        if (m_sink->set_output_device(m_sink, m_current_device_id.c_str()) != 0) {
            if (m_current_device_id != "default") {
                m_current_device_id = "default";
                m_sink->set_output_device(m_sink, "default");
                downgrades.push_back({"audio", "output_device_id", "default"});
            }
        }
    }
    if (LYRA_SINK_HAS_CAP(m_sink, set_buffer_size_frames)) {
        if (m_sink->set_buffer_size_frames(m_sink, m_buffer_size_frames) != 0) {
            if (m_buffer_size_frames != DEFAULT_BUFFER_SIZE_FRAMES) {
                m_buffer_size_frames = DEFAULT_BUFFER_SIZE_FRAMES;
                m_sink->set_buffer_size_frames(m_sink, DEFAULT_BUFFER_SIZE_FRAMES);
                downgrades.push_back({"audio", "buffer_size_frames", static_cast<int>(DEFAULT_BUFFER_SIZE_FRAMES)});
            }
        }
    }
    if (LYRA_SINK_HAS_CAP(m_sink, set_exclusive_mode)) {
        if (m_sink->set_exclusive_mode(m_sink, m_exclusive_mode ? 1 : 0) != 0) {
            if (m_exclusive_mode) {
                m_exclusive_mode = false;
                m_sink->set_exclusive_mode(m_sink, 0);
                downgrades.push_back({"audio", "exclusive_mode", false});
            }
        }
    }
    if (LYRA_SINK_HAS_CAP(m_sink, set_volume)) {
        m_sink->set_volume(m_sink, m_volume);
    }
}

AudioEngine::AudioEngine(LyraAudioSink *sink, SinkDeleter deleter) {
    if (sink) {
        m_sink = sink;
        m_sink_deleter = deleter;
        m_custom_sink_set = true;
        m_sink_is_fallback = false;
    } else {
        // Default to LocalAudioSink for hardware audio output; fallback to NullAudioSink on open if unavailable
        m_sink = create_local_audio_sink();
        m_sink_deleter = destroy_local_audio_sink;
        m_custom_sink_set = false;
        m_sink_is_fallback = false;
    }
    apply_sink_config_unlocked();
}

std::unique_ptr<AudioEngine> AudioEngine::create_null_engine() {
    return std::make_unique<AudioEngine>(create_null_audio_sink(), destroy_null_audio_sink);
}

AudioEngine::~AudioEngine() {
    stop();
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    cleanup_retired_sinks_unlocked();
    if (LYRA_SINK_HAS_CAP(m_sink, close)) {
        m_sink->close(m_sink);
    }
    if (m_sink && m_sink_deleter) {
        m_sink_deleter(m_sink);
        m_sink = nullptr;
    }
}

void AudioEngine::set_sink(LyraAudioSink *sink, SinkDeleter deleter) {
    // Stop playback and join the background pump thread outside the mutex lock
    // to prevent deadlock and ensure no concurrent write_pcm access during sink teardown.
    stop();

    std::vector<DowngradeItem> pending_downgrades;
    ConfigDowngradeCallback cb;
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        cleanup_retired_sinks_unlocked();
        // Close the existing audio device/backend if the C-ABI close callback is provided.
        if (LYRA_SINK_HAS_CAP(m_sink, close)) {
            m_sink->close(m_sink);
        }
        // Destroy and free the existing sink resource via its registered deleter,
        // then reset the pointer to null to avoid dangling references.
        if (m_sink && m_sink_deleter) {
            m_sink_deleter(m_sink);
            m_sink = nullptr;
        }

        m_sink = sink;
        m_sink_deleter = deleter;
        // Mark as custom sink to prevent play() from replacing it with the default local sink.
        m_custom_sink_set = (sink != nullptr);
        m_sink_is_fallback = false;
        apply_sink_config_unlocked(pending_downgrades);
        cb = m_config_downgrade_callback;
    }

    if (cb) {
        // TODO(ui-event): Emit a dedicated event (e.g. "audio_config_downgraded" or include structured JSON payload) so that the UI layer / frontend can receive proactive notifications and inform the user when hardware negotiation triggers parameter fallback (e.g. exclusive mode or buffer size unsupported).
        for (const auto &item : pending_downgrades) {
            cb(item.category, item.key, item.value);
        }
    }
}

void AudioEngine::set_config_downgrade_callback(ConfigDowngradeCallback callback) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_config_downgrade_callback = std::move(callback);
}

void AudioEngine::set_event_callback(EventCallbackFunc callback) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_event_callback = std::move(callback);
}

void AudioEngine::cleanup_retired_sinks_unlocked() {
    for (auto &[old_sink, old_deleter] : m_retired_sinks) {
        if (old_sink) {
            if (LYRA_SINK_HAS_CAP(old_sink, close)) old_sink->close(old_sink);
            if (old_deleter) old_deleter(old_sink);
        }
    }
    m_retired_sinks.clear();
}

void AudioEngine::close_decoder_unlocked() {
    if (m_decoder) {
        m_decoder->close();
        m_decoder.reset();
    }
}

bool AudioEngine::play(const std::string &file_path, double start_position_seconds) {
    stop(); // Ensure clean state before starting new playback

    bool device_unavailable = false;
    std::vector<DowngradeItem> pending_downgrades;
    ConfigDowngradeCallback cb;
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        m_last_error = AudioEngineError::None;

        if (file_path.empty()) {
            m_last_error = AudioEngineError::InvalidArgument;
            return false;
        }

        auto decoder = std::make_unique<AudioDecoder>();
        if (!decoder->open(file_path)) {
            m_last_error = AudioEngineError::DecoderFailure;
            return false;
        }

        m_sample_rate = decoder->get_sample_rate();
        m_channels = decoder->get_channels();
        m_total_frames = decoder->get_total_frames();
        m_current_frame = 0;
        m_current_file_path = file_path;
        m_decoder = std::move(decoder);
        m_track_epoch.fetch_add(1, std::memory_order_release);

        if (start_position_seconds > 0.0) {
            double target = start_position_seconds;
            if (target < 0.0) target = 0.0;
            double dur = get_duration();
            if (dur > 0.0 && target > dur) {
                target = dur;
            }
            if (m_decoder->seek_seconds(target)) {
                m_current_frame = m_decoder->get_current_frame();
            }
        }

        // If no sink or sink is a fallback NullAudioSink (and not explicitly set by set_sink),
        // try to create/use LocalAudioSink
        if (!m_custom_sink_set && (!m_sink || m_sink_is_fallback)) {
            if (m_sink && m_sink_deleter) {
                m_sink_deleter(m_sink);
            }
            m_sink = create_local_audio_sink();
            m_sink_deleter = destroy_local_audio_sink;
            m_sink_is_fallback = false;
        }

        if (m_sink) {
            LyraAudioSpec spec{};
            spec.sample_rate = m_sample_rate;
            spec.channels = m_channels;
            spec.format = LYRA_AUDIO_FORMAT_F32;

            bool device_sync_ok = true;
            if (LYRA_SINK_HAS_CAP(m_sink, set_buffer_size_frames)) {
                if (m_sink->set_buffer_size_frames(m_sink, m_buffer_size_frames) != 0) {
                    if (m_buffer_size_frames != DEFAULT_BUFFER_SIZE_FRAMES) {
                        m_buffer_size_frames = DEFAULT_BUFFER_SIZE_FRAMES;
                        m_sink->set_buffer_size_frames(m_sink, DEFAULT_BUFFER_SIZE_FRAMES);
                        pending_downgrades.push_back(
                            {"audio", "buffer_size_frames", static_cast<int>(DEFAULT_BUFFER_SIZE_FRAMES)});
                    }
                }
            }
            if (LYRA_SINK_HAS_CAP(m_sink, set_exclusive_mode)) {
                if (m_sink->set_exclusive_mode(m_sink, m_exclusive_mode ? 1 : 0) != 0) {
                    if (m_exclusive_mode) {
                        m_exclusive_mode = false;
                        m_sink->set_exclusive_mode(m_sink, 0);
                        pending_downgrades.push_back({"audio", "exclusive_mode", false});
                    }
                }
            }
            if (LYRA_SINK_HAS_CAP(m_sink, set_output_device)) {
                if (m_sink->set_output_device(m_sink, m_current_device_id.c_str()) != 0) {
                    if (!m_custom_sink_set && !is_valid_audio_device_id(m_current_device_id)) {
                        m_current_device_id = "default";
                        m_sink->set_output_device(m_sink, "default");
                        pending_downgrades.push_back({"audio", "output_device_id", "default"});
                    } else if (m_current_device_id != "default") {
                        device_sync_ok = false;
                    }
                }
            }

            int open_res = -1;
            if (device_sync_ok && LYRA_SINK_HAS_CAP(m_sink, open)) {
                open_res = m_sink->open(m_sink, &spec);
            }
            if (open_res != 0) {
                if (!m_custom_sink_set && m_current_device_id == "default") {
                    // If opening default sink fails (e.g. LocalAudioSink on headless environment), fallback to NullAudioSink
                    if (m_sink_deleter) m_sink_deleter(m_sink);
                    m_sink = create_null_audio_sink();
                    m_sink_deleter = destroy_null_audio_sink;
                    m_sink_is_fallback = true;
                    if (LYRA_SINK_HAS_CAP(m_sink, open)) open_res = m_sink->open(m_sink, &spec);
                }
                if (open_res != 0) {
                    close_decoder_unlocked();
                    m_current_file_path.clear();
                    m_total_frames = 0;
                    m_current_frame = 0;
                    m_state = AudioEngineState::STOPPED;
                    m_last_error = AudioEngineError::DeviceUnavailable;
                    device_unavailable = true;
                }
            }

            if (!device_unavailable && open_res == 0) {
                if (LYRA_SINK_HAS_CAP(m_sink, set_volume)) {
                    m_sink->set_volume(m_sink, m_volume);
                }
                if (LYRA_SINK_HAS_CAP(m_sink, start)) {
                    int start_res = m_sink->start(m_sink);
                    if (start_res != 0 && !m_custom_sink_set && !m_sink_is_fallback &&
                        m_current_device_id == "default") {
                        // If start fails on default primary sink, attempt fallback to NullAudioSink
                        if (m_sink_deleter) m_sink_deleter(m_sink);
                        m_sink = create_null_audio_sink();
                        m_sink_deleter = destroy_null_audio_sink;
                        m_sink_is_fallback = true;
                        if (LYRA_SINK_HAS_CAP(m_sink, open)) m_sink->open(m_sink, &spec);
                        if (LYRA_SINK_HAS_CAP(m_sink, set_volume)) m_sink->set_volume(m_sink, m_volume);
                        if (LYRA_SINK_HAS_CAP(m_sink, start)) start_res = m_sink->start(m_sink);
                    }
                    if (start_res != 0) {
                        close_decoder_unlocked();
                        m_current_file_path.clear();
                        m_total_frames = 0;
                        m_current_frame = 0;
                        m_state = AudioEngineState::STOPPED;
                        m_last_error = AudioEngineError::DeviceUnavailable;
                        device_unavailable = true;
                    }
                }
            }
        }

        if (m_last_error != AudioEngineError::None) {
            // Release lock before emitting event if device_unavailable
        } else {
            m_state = AudioEngineState::PLAYING;
            m_pump_running = true;
            m_pump_thread = std::thread(&AudioEngine::pump_loop, this);
        }
        cb = m_config_downgrade_callback;
    }

    if (cb) {
        // TODO(ui-event): Emit a dedicated event (e.g. "audio_config_downgraded" or include structured JSON payload) so that the UI layer / frontend can receive proactive notifications and inform the user when hardware negotiation triggers parameter fallback (e.g. exclusive mode or buffer size unsupported).
        for (const auto &item : pending_downgrades) {
            cb(item.category, item.key, item.value);
        }
    }

    if (device_unavailable) {
        emit_state_event("audio_device_unavailable");
        return false;
    }
    if (get_last_error() != AudioEngineError::None) {
        return false;
    }

    emit_state_event("audio_state_changed");
    return true;
}

bool AudioEngine::pause() {
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (m_state != AudioEngineState::PLAYING) return false;

        m_state = AudioEngineState::PAUSED;
        if (LYRA_SINK_HAS_CAP(m_sink, stop)) {
            m_sink->stop(m_sink);
        }
    }
    emit_state_event("audio_state_changed");
    return true;
}

bool AudioEngine::resume() {
    bool device_unavailable = false;
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (m_state != AudioEngineState::PAUSED) {
            m_last_error = AudioEngineError::InvalidArgument;
            return false;
        }

        if (LYRA_SINK_HAS_CAP(m_sink, start) && m_sink->start(m_sink) != 0) { // If m_sink->start(m_sink) fails
            m_last_error = AudioEngineError::DeviceUnavailable;
            device_unavailable = true;
        } else {
            m_last_error = AudioEngineError::None;
            m_state = AudioEngineState::PLAYING;
        }
    }
    if (device_unavailable) {
        emit_state_event("audio_device_unavailable");
        return false;
    }
    emit_state_event("audio_state_changed");
    return true;
}

bool AudioEngine::stop() {
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        m_state = AudioEngineState::STOPPED;
        m_pump_running = false;
    }

    if (m_pump_thread.joinable()) {
        m_pump_thread.join();
    }

    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        cleanup_retired_sinks_unlocked();
        if (m_sink) {
            if (LYRA_SINK_HAS_CAP(m_sink, flush)) m_sink->flush(m_sink);
            if (LYRA_SINK_HAS_CAP(m_sink, stop)) m_sink->stop(m_sink);
        }
        close_decoder_unlocked();
        m_next_decoder.reset();
        m_next_file_path.clear();
        m_current_frame = 0;
        m_current_file_path.clear();
    }

    emit_state_event("audio_state_changed");
    return true;
}

bool AudioEngine::preload_next(const std::string &file_path) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (file_path.empty()) {
        m_next_decoder.reset();
        m_next_file_path.clear();
        return true;
    }

    auto next_dec = std::make_unique<AudioDecoder>();
    if (!next_dec->open(file_path)) {
        return false;
    }

    m_next_decoder = std::move(next_dec);
    m_next_file_path = file_path;
    return true;
}

std::string AudioEngine::get_next_file_path() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_next_file_path;
}

// TODO(hotplug): Subscribe to sink/backend device hotplug notifications and emit "audio_devices_changed" / "audio_device_disconnected" events so the UI can dynamically update its device list.
std::vector<AudioDeviceInfo> AudioEngine::list_devices() const {
    return list_local_audio_devices();
}

bool AudioEngine::set_output_device(const std::string &device_id) {
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (!m_pump_running) {
            cleanup_retired_sinks_unlocked();
        }
    }
    bool state_changed_to_stopped = false;
    bool should_fail = false;
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (!m_custom_sink_set && !is_valid_audio_device_id(device_id)) {
            return false;
        }
        if (m_custom_sink_set && device_id.empty()) {
            return false;
        }
        const std::string normalized_id = device_id.empty() ? "default" : device_id;
        if (!m_custom_sink_set && normalized_id != "default" &&
            (m_sink_is_fallback || !LYRA_SINK_HAS_CAP(m_sink, set_output_device)) &&
            !is_audio_device_available(normalized_id)) {
            return false;
        }
        if (m_sink_is_fallback && !m_custom_sink_set &&
            (m_state == AudioEngineState::PLAYING || m_state == AudioEngineState::PAUSED)) {
            LyraAudioSink *candidate = create_local_audio_sink();
            if (!candidate) {
                if (normalized_id == "default") {
                    m_current_device_id = "default";
                    return true;
                }
                return false;
            }
            if (LYRA_SINK_HAS_CAP(candidate, set_output_device)) {
                if (candidate->set_output_device(candidate, normalized_id.c_str()) != 0) {
                    destroy_local_audio_sink(candidate);
                    if (normalized_id == "default") {
                        m_current_device_id = "default";
                        return true;
                    }
                    return false;
                }
            }
            if (LYRA_SINK_HAS_CAP(candidate, set_buffer_size_frames)) {
                candidate->set_buffer_size_frames(candidate, m_buffer_size_frames);
            }
            if (LYRA_SINK_HAS_CAP(candidate, set_exclusive_mode)) {
                candidate->set_exclusive_mode(candidate, m_exclusive_mode ? 1 : 0);
            }
            LyraAudioSpec spec{};
            spec.sample_rate = m_sample_rate;
            spec.channels = m_channels;
            spec.format = LYRA_AUDIO_FORMAT_F32;
            if (!LYRA_SINK_HAS_CAP(candidate, open) || candidate->open(candidate, &spec) != 0) {
                destroy_local_audio_sink(candidate);
                if (normalized_id == "default") {
                    m_current_device_id = "default";
                    return true;
                }
                return false;
            }
            if (LYRA_SINK_HAS_CAP(candidate, set_volume)) {
                candidate->set_volume(candidate, m_volume);
            }
            if (m_state == AudioEngineState::PLAYING) {
                if (LYRA_SINK_HAS_CAP(candidate, start) && candidate->start(candidate) != 0) {
                    if (LYRA_SINK_HAS_CAP(candidate, close)) candidate->close(candidate);
                    destroy_local_audio_sink(candidate);
                    if (normalized_id == "default") {
                        m_current_device_id = "default";
                        return true;
                    }
                    return false;
                }
            }
            if (m_sink) {
                if (LYRA_SINK_HAS_CAP(m_sink, stop)) m_sink->stop(m_sink);
                m_retired_sinks.emplace_back(m_sink, m_sink_deleter);
            }
            m_sink = candidate;
            m_sink_deleter = destroy_local_audio_sink;
            m_sink_is_fallback = false;
            m_current_device_id = normalized_id;
            return true;
        }
        if (LYRA_SINK_HAS_CAP(m_sink, set_output_device)) {
            int res = m_sink->set_output_device(m_sink, normalized_id.c_str());
            if (res != 0) {
                if (res == -2 && m_state == AudioEngineState::PLAYING) {
                    m_state = AudioEngineState::STOPPED;
                    m_pump_running = false;
                    m_last_error = AudioEngineError::DeviceUnavailable;
                    close_decoder_unlocked();
                    m_next_decoder.reset();
                    m_next_file_path.clear();
                    m_current_frame = 0;
                    m_current_file_path.clear();
                    state_changed_to_stopped = true;
                }
                should_fail = true;
            }
        }
        if (!should_fail) {
            m_current_device_id = normalized_id;
        }
    }
    if (state_changed_to_stopped) {
        if (m_pump_thread.joinable()) {
            m_pump_thread.join();
        }
        emit_state_event("audio_state_changed");
    }
    if (should_fail) {
        return false;
    }
    return true;
}

bool AudioEngine::restore_output_device(const std::string &device_id) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (device_id.empty() || device_id.size() >= 512) {
        return false;
    }
    const std::string normalized_id = device_id;
    m_current_device_id = normalized_id;
    if (m_sink && LYRA_SINK_HAS_CAP(m_sink, set_output_device)) {
        m_sink->set_output_device(m_sink, normalized_id.c_str());
    }
    return true;
}

std::string AudioEngine::get_output_device() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_current_device_id;
}

bool AudioEngine::set_buffer_size_frames(uint32_t frames) {
    if (frames < MIN_BUFFER_SIZE_FRAMES || frames > MAX_BUFFER_SIZE_FRAMES) {
        return false;
    }
    bool state_changed_to_stopped = false;
    bool should_fail = false;
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (LYRA_SINK_HAS_CAP(m_sink, set_buffer_size_frames)) {
            int res = m_sink->set_buffer_size_frames(m_sink, frames);
            if (res != 0) {
                if (res == -2 && m_state == AudioEngineState::PLAYING) {
                    m_state = AudioEngineState::STOPPED;
                    m_pump_running = false;
                    m_last_error = AudioEngineError::DeviceUnavailable;
                    close_decoder_unlocked();
                    m_next_decoder.reset();
                    m_next_file_path.clear();
                    m_current_frame = 0;
                    m_current_file_path.clear();
                    state_changed_to_stopped = true;
                }
                should_fail = true;
            }
        }
        if (!should_fail) {
            m_buffer_size_frames = frames;
        }
    }
    if (state_changed_to_stopped) {
        if (m_pump_thread.joinable()) {
            m_pump_thread.join();
        }
        emit_state_event("audio_state_changed");
    }
    if (should_fail) {
        return false;
    }
    return true;
}

uint32_t AudioEngine::get_buffer_size_frames() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_buffer_size_frames;
}

bool AudioEngine::set_exclusive_mode(bool exclusive) {
    bool state_changed_to_stopped = false;
    bool should_fail = false;
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (LYRA_SINK_HAS_CAP(m_sink, set_exclusive_mode)) {
            int res = m_sink->set_exclusive_mode(m_sink, exclusive ? 1 : 0);
            if (res != 0) {
                if (res == -2 && m_state == AudioEngineState::PLAYING) {
                    m_state = AudioEngineState::STOPPED;
                    m_pump_running = false;
                    m_last_error = AudioEngineError::DeviceUnavailable;
                    close_decoder_unlocked();
                    m_next_decoder.reset();
                    m_next_file_path.clear();
                    m_current_frame = 0;
                    m_current_file_path.clear();
                    state_changed_to_stopped = true;
                }
                should_fail = true;
            }
        }
        if (!should_fail) {
            m_exclusive_mode = exclusive;
        }
    }
    if (state_changed_to_stopped) {
        if (m_pump_thread.joinable()) {
            m_pump_thread.join();
        }
        emit_state_event("audio_state_changed");
    }
    if (should_fail) {
        return false;
    }
    return true;
}

bool AudioEngine::get_exclusive_mode() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_exclusive_mode;
}

bool AudioEngine::seek(double position_seconds, bool relative) {
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (!m_decoder || !m_decoder->is_open()) return false;

        double target_pos = relative ? (get_position() + position_seconds) : position_seconds;
        if (target_pos < 0.0) target_pos = 0.0;
        double dur = get_duration();
        if (dur > 0.0 && target_pos > dur) {
            target_pos = dur;
        }

        if (!m_decoder->seek_seconds(target_pos)) {
            return false;
        }
        m_current_frame = m_decoder->get_current_frame();
        m_seek_epoch++;
        if (LYRA_SINK_HAS_CAP(m_sink, flush)) {
            m_sink->flush(m_sink);
        }
    }
    emit_state_event("audio_seek");
    return true;
}

bool AudioEngine::set_volume(float volume) {
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (volume < 0.0f) volume = 0.0f;
        if (volume > 1.0f) volume = 1.0f;
        m_volume = volume;
        if (LYRA_SINK_HAS_CAP(m_sink, set_volume)) {
            m_sink->set_volume(m_sink, volume);
        }
    }
    emit_state_event("audio_volume_changed");
    return true;
}

bool AudioEngine::is_custom_sink_set() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_custom_sink_set;
}

AudioEngineState AudioEngine::get_state_enum() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_state;
}

AudioEngineError AudioEngine::get_last_error() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_last_error;
}

std::string AudioEngine::get_state_string() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    switch (m_state) {
        case AudioEngineState::PLAYING:
            return "PLAYING";
        case AudioEngineState::PAUSED:
            return "PAUSED";
        case AudioEngineState::STOPPED:
        default:
            return "STOPPED";
    }
}

double AudioEngine::get_position() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (m_sample_rate == 0) return 0.0;
    uint64_t current = m_current_frame.load();
    uint32_t buffered = LYRA_SINK_HAS_CAP(m_sink, get_buffered_frames) ? m_sink->get_buffered_frames(m_sink) : 0;
    uint64_t played = (current > buffered) ? (current - buffered) : 0;
    return static_cast<double>(played) / static_cast<double>(m_sample_rate);
}

double AudioEngine::get_duration() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (m_sample_rate == 0) return 0.0;
    return static_cast<double>(m_total_frames) / static_cast<double>(m_sample_rate);
}

float AudioEngine::get_volume() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_volume;
}

std::string AudioEngine::get_current_file_path() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_current_file_path;
}

bool AudioEngine::is_decoder_open() const { // basically build for testing
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_decoder != nullptr && m_decoder->is_open();
}

nlohmann::json AudioEngine::get_state_json() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    nlohmann::json j;
    switch (m_state) {
        case AudioEngineState::PLAYING:
            j["state"] = "PLAYING";
            break;
        case AudioEngineState::PAUSED:
            j["state"] = "PAUSED";
            break;
        case AudioEngineState::STOPPED:
        default:
            j["state"] = "STOPPED";
            break;
    }
    j["file_path"] = m_current_file_path;
    j["next_file_path"] = m_next_file_path;
    j["device_id"] = m_current_device_id;
    j["position"] = get_position();
    j["duration"] = get_duration();
    j["volume"] = m_volume;
    j["buffer_size_frames"] = m_buffer_size_frames;
    j["exclusive_mode"] = m_exclusive_mode;
    bool exclusive_active = false;
    if (LYRA_SINK_HAS_CAP(m_sink, is_exclusive_mode_active)) {
        exclusive_active = (m_sink->is_exclusive_mode_active(m_sink) != 0);
    }
    j["exclusive_mode_active"] = exclusive_active;
    return j;
}

// TODO(hotplug): Subscribe to sink/backend device hotplug notifications and emit "audio_devices_changed" / "audio_device_disconnected" events so the UI can dynamically update its device list.
void AudioEngine::emit_state_event(const std::string &event_name) {
    EventCallbackFunc cb;
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (!m_event_callback) return;
        cb = m_event_callback;
    }

    nlohmann::json event;
    event["event"] = event_name;
    event["data"] = get_state_json();
    if (event_name == "audio_device_unavailable") {
        event["data"]["error"] = "DeviceUnavailable";
    }

    cb(event.dump());
}

void AudioEngine::pump_loop() {
    const uint32_t chunk_frames = 512;
    uint8_t current_channels = 2;
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        current_channels = m_channels > 0 ? m_channels : 2;
    }
    std::vector<float> buffer(chunk_frames * current_channels);

    while (m_pump_running) {

        uint32_t frames_read = 0;
        bool is_paused = false;
        uint64_t chunk_epoch = 0;
        { // LOCK
            std::lock_guard<std::recursive_mutex> lock(m_mutex);

            if (m_state == AudioEngineState::PAUSED) {
                // PAUSED, sleep outside the lock for 20ms then continue
                is_paused = true;
            } else if (m_state != AudioEngineState::PLAYING || !m_decoder || !m_pump_running) {
                // STOPPED or encountered error
                break;
            } else {
                current_channels = m_channels > 0 ? m_channels : 2;
                if (buffer.size() < chunk_frames * current_channels) {
                    buffer.resize(chunk_frames * current_channels);
                }
                frames_read = m_decoder->read_pcm_frames(buffer.data(), chunk_frames); // Amount of frames reads in this pump
                chunk_epoch = m_seek_epoch;                                            // Record the seek epoch when this chunk decoded
            }
        } // LOCK END

        if (is_paused) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20)); // There will be a MAX delay of 20ms for resuming
            continue;
        }

        if (frames_read == 0) {
            // Check if we've reached the end of the track
            // <- OR ->
            // DUE TO some error that caused decoder reads 0 frame in this pump
            bool has_next = false;
            bool should_fail = false;
            bool spec_changed = false;
            bool seek_interrupted = false;
            uint32_t next_sample_rate = 0;
            uint8_t next_channels = 0;

            {
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_seek_epoch != chunk_epoch) {
                    seek_interrupted = true;
                } else if (m_next_decoder && m_next_decoder->is_open()) { // If next decoder is ready
                    next_sample_rate = m_next_decoder->get_sample_rate();
                    next_channels = m_next_decoder->get_channels();
                    if (next_sample_rate != m_sample_rate || next_channels != m_channels) {
                        spec_changed = true;
                    } else {
                        // Same spec: seamless gapless transition without drain or reopen
                        m_decoder = std::move(m_next_decoder);
                        m_track_epoch.fetch_add(1, std::memory_order_release);
                        m_current_file_path = m_next_file_path;
                        m_next_file_path.clear();
                        m_total_frames = m_decoder->get_total_frames();
                        m_current_frame = 0;
                        m_seek_epoch++;
                        has_next = true;
                        if (buffer.size() < chunk_frames * m_channels) {
                            buffer.resize(chunk_frames * m_channels);
                        }
                    }
                }
            }

            if (seek_interrupted) {
                continue;
            }

            if (has_next) {
                emit_state_event("audio_track_changed");
                continue;
            }

            // Either no next track yet, OR next track has a different audio spec.
            // In both cases, we must drain the current sink buffer to hardware output.
            uint32_t last_remaining = 0;
            int stall_count = 0;
            while (m_pump_running) {
                bool is_drain_paused = false;
                {
                    std::lock_guard<std::recursive_mutex> lock(m_mutex);
                    if (m_seek_epoch != chunk_epoch) {
                        seek_interrupted = true;
                        break;
                    }

                    if (m_state == AudioEngineState::PAUSED) {
                        is_drain_paused = true;
                    } else if (m_state != AudioEngineState::PLAYING || !m_pump_running) {
                        break;
                    } else {
                        // If a next track was preloaded during draining, check if spec changed
                        if (!spec_changed && m_next_decoder && m_next_decoder->is_open()) {
                            next_sample_rate = m_next_decoder->get_sample_rate();
                            next_channels = m_next_decoder->get_channels();
                            if (next_sample_rate == m_sample_rate && next_channels == m_channels) {
                                // Same spec arrived late: can immediately resume writing to remaining buffer
                                m_decoder = std::move(m_next_decoder);
                                m_track_epoch.fetch_add(1, std::memory_order_release);
                                m_current_file_path = m_next_file_path;
                                m_next_file_path.clear();
                                m_total_frames = m_decoder->get_total_frames();
                                m_current_frame = 0;
                                m_seek_epoch++;
                                has_next = true;
                                if (buffer.size() < chunk_frames * m_channels) {
                                    buffer.resize(chunk_frames * m_channels);
                                }
                                break;
                            } else {
                                spec_changed = true;
                            }
                        }

                        if (!LYRA_SINK_HAS_CAP(m_sink, get_buffered_frames)) break;
                        uint32_t remaining = m_sink->get_buffered_frames(m_sink);
                        if (remaining == 0) break;
                        if (remaining == last_remaining) {
                            stall_count++;
                            if (stall_count > 100) { // 500ms without progress, hardware stopped consuming
                                break;
                            }
                        } else {
                            stall_count = 0;
                            last_remaining = remaining;
                        }
                    }
                }

                if (is_drain_paused) {
                    stall_count = 0;
                    std::this_thread::sleep_for(std::chrono::milliseconds(20));
                    continue;
                }

                if (seek_interrupted || has_next) {
                    break;
                }

                std::this_thread::sleep_for(std::chrono::milliseconds(5));
            }

            if (seek_interrupted) {
                continue;
            }

            if (has_next) {
                emit_state_event("audio_track_changed");
                continue;
            }

            // If we drained for a cross-spec next track (or one arrived during drain):
            {
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_seek_epoch != chunk_epoch) {
                    seek_interrupted = true;
                } else if (m_pump_running && m_state == AudioEngineState::PLAYING && m_next_decoder &&
                           m_next_decoder->is_open()) {
                    m_decoder = std::move(m_next_decoder);
                    m_track_epoch.fetch_add(1, std::memory_order_release);
                    m_current_file_path = m_next_file_path;
                    m_next_file_path.clear();
                    m_sample_rate = m_decoder->get_sample_rate();
                    m_channels = m_decoder->get_channels();
                    m_total_frames = m_decoder->get_total_frames();
                    m_current_frame = 0;
                    m_seek_epoch++;
                    if (buffer.size() < chunk_frames * m_channels) {
                        buffer.resize(chunk_frames * m_channels);
                    }

                    LyraAudioSpec new_spec{};
                    new_spec.sample_rate = m_sample_rate;
                    new_spec.channels = m_channels;
                    new_spec.format = LYRA_AUDIO_FORMAT_F32;

                    int open_res = (LYRA_SINK_HAS_CAP(m_sink, open)) ? m_sink->open(m_sink, &new_spec) : -1;
                    if (open_res != 0) {
                        m_pump_running = false;
                        m_state = AudioEngineState::STOPPED;
                        m_last_error = AudioEngineError::DeviceUnavailable;
                        close_decoder_unlocked();
                        if (LYRA_SINK_HAS_CAP(m_sink, stop)) m_sink->stop(m_sink);
                        cleanup_retired_sinks_unlocked();
                        should_fail = true;
                    } else {
                        if (LYRA_SINK_HAS_CAP(m_sink, set_volume)) {
                            m_sink->set_volume(m_sink, m_volume);
                        }
                        int start_res = (LYRA_SINK_HAS_CAP(m_sink, start)) ? m_sink->start(m_sink) : 0;
                        if (start_res != 0) {
                            m_pump_running = false;
                            m_state = AudioEngineState::STOPPED;
                            m_last_error = AudioEngineError::DeviceUnavailable;
                            close_decoder_unlocked();
                            if (LYRA_SINK_HAS_CAP(m_sink, stop)) m_sink->stop(m_sink);
                            cleanup_retired_sinks_unlocked();
                            should_fail = true;
                        } else {
                            has_next = true;
                        }
                    }
                }
            }

            if (seek_interrupted) {
                continue;
            }

            if (should_fail) {
                emit_state_event("audio_device_unavailable");
                emit_state_event("audio_state_changed");
                break;
            }

            if (has_next) {
                emit_state_event("audio_track_changed");
                continue;
            }

            bool should_emit_ended = false;
            {
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_seek_epoch != chunk_epoch) {
                    seek_interrupted = true;
                } else if (m_pump_running && m_state == AudioEngineState::PLAYING) {
                    m_state = AudioEngineState::STOPPED;
                    m_pump_running = false;
                    if (LYRA_SINK_HAS_CAP(m_sink, stop)) m_sink->stop(m_sink);
                    close_decoder_unlocked();
                    cleanup_retired_sinks_unlocked();
                    should_emit_ended = true;
                }
            }

            if (seek_interrupted) {
                continue;
            }

            if (should_emit_ended) {
                emit_state_event("audio_ended");
            }
            break;
        } // END OF <-` if (frames_read == 0){} `->

        // Natural Backpressure !
        uint32_t frames_written_total = 0; // The frames successfully written into the sink
        while (frames_written_total < frames_read && m_pump_running) {
            LyraAudioSink *sink = nullptr;
            { // LOCK
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_state != AudioEngineState::PLAYING || m_seek_epoch != chunk_epoch) {
                    // A New seek happened or status changed, abandon this chunk
                    break;
                }
                sink = m_sink;
            } // LOCK END

            const float *src = buffer.data() + (frames_written_total * current_channels);
            uint32_t to_write = frames_read - frames_written_total;

            if (!LYRA_SINK_HAS_CAP(sink, write_pcm)) { // `sink` or `sink->write_pcm` broken
                bool should_emit_events = false;
                {
                    std::lock_guard<std::recursive_mutex> lock(m_mutex);
                    m_pump_running = false;
                    m_state = AudioEngineState::STOPPED;
                    m_last_error = AudioEngineError::DeviceUnavailable;
                    close_decoder_unlocked();
                    cleanup_retired_sinks_unlocked();
                    if (LYRA_SINK_HAS_CAP(m_sink, stop)) {
                        m_sink->stop(m_sink);
                    }
                    should_emit_events = true;
                }
                if (should_emit_events) {
                    emit_state_event("audio_device_unavailable");
                    emit_state_event("audio_state_changed");
                }
                break;
            }
            int written = sink->write_pcm(sink, src, to_write);

            if (written > 0) {
                frames_written_total += static_cast<uint32_t>(written);
                // LOCK and update m_current_frame
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_seek_epoch == chunk_epoch) { // If m_seek_epoch remains unchanged
                    m_current_frame += written;
                }
            } else if (written < 0) {
                // Sink error, or the device disconnected
                bool should_emit_events = false;
                {
                    std::lock_guard<std::recursive_mutex> lock(m_mutex);
                    m_pump_running = false;
                    m_state = AudioEngineState::STOPPED;
                    m_last_error = AudioEngineError::DeviceUnavailable;
                    close_decoder_unlocked();
                    cleanup_retired_sinks_unlocked();
                    if (LYRA_SINK_HAS_CAP(m_sink, stop)) {
                        m_sink->stop(m_sink);
                    }
                    should_emit_events = true;
                }
                if (should_emit_events) {
                    emit_state_event("audio_device_unavailable");
                    emit_state_event("audio_state_changed");
                }
                break;
            } else {
                // written == 0, Buffer IS Full
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
            }
        }

        if (!m_pump_running) {
            break;
        }
    }

    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        cleanup_retired_sinks_unlocked();
    }
}

} // namespace lyra
