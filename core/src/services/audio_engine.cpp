/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_engine.h"
#include "services/audio_sinks/local_audio_sink.h"
#include "services/audio_sinks/null_audio_sink.h"

#include <chrono>
#include <cmath>
#include <iostream>
#include <vector>

namespace lyra {

AudioEngine::AudioEngine() {
    // Default to LocalAudioSink for hardware audio output; fallback to NullAudioSink on open if unavailable
    m_sink = create_local_audio_sink();
    m_sink_deleter = destroy_local_audio_sink;
}

AudioEngine::~AudioEngine() {
    stop();
    if (m_sink && m_sink->close) {
        m_sink->close(m_sink);
    }
    if (m_sink && m_sink_deleter) {
        m_sink_deleter(m_sink);
        m_sink = nullptr;
    }
}

void AudioEngine::set_sink(LyraAudioSink *sink, SinkDeleter deleter) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    if (m_state != AudioEngineState::STOPPED) {
        // Stop before changing sink
        if (m_sink && m_sink->stop) {
            m_sink->stop(m_sink);
        }
        if (m_sink && m_sink->close) {
            m_sink->close(m_sink);
        }
    }
    if (m_sink && m_sink_deleter) {
        m_sink_deleter(m_sink);
    }
    m_sink = sink;
    m_sink_deleter = deleter;
    m_custom_sink_set = (sink != nullptr);
    m_sink_is_fallback = false;
}

void AudioEngine::set_event_callback(EventCallbackFunc callback) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_event_callback = std::move(callback);
}

void AudioEngine::close_decoder_unlocked() {
    if (m_decoder) {
        m_decoder->close();
        m_decoder.reset();
    }
}

bool AudioEngine::play(const std::string &file_path) {
    stop(); // Ensure clean state before starting new playback

    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);

        auto decoder = std::make_unique<AudioDecoder>();
        if (!decoder->open(file_path)) {
            return false;
        }

        m_sample_rate = decoder->get_sample_rate();
        m_channels = decoder->get_channels();
        m_total_frames = decoder->get_total_frames();
        m_current_frame = 0;
        m_current_file_path = file_path;
        m_decoder = std::move(decoder);

        // If no sink or sink is a fallback NullAudioSink (and not explicitly set by set_sink), try to create/use LocalAudioSink
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

            int open_res = -1;
            if (m_sink->open) {
                open_res = m_sink->open(m_sink, &spec);
            }
            if (open_res != 0 && !m_custom_sink_set) {
                // If opening sink fails (e.g. LocalAudioSink on headless environment), graceful fallback to NullAudioSink
                if (m_sink_deleter) m_sink_deleter(m_sink);
                m_sink = create_null_audio_sink();
                m_sink_deleter = destroy_null_audio_sink;
                m_sink_is_fallback = true;
                if (m_sink->open) m_sink->open(m_sink, &spec);
            }

            if (m_sink->set_volume) {
                m_sink->set_volume(m_sink, m_volume);
            }
            if (m_sink->start) {
                m_sink->start(m_sink);
            }
        }

        m_state = AudioEngineState::PLAYING;
        m_pump_running = true;
        m_pump_thread = std::thread(&AudioEngine::pump_loop, this);
    }

    emit_state_event("audio_state_changed");
    return true;
}

bool AudioEngine::pause() {
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (m_state != AudioEngineState::PLAYING) return false;

        m_state = AudioEngineState::PAUSED;
        if (m_sink && m_sink->stop) {
            m_sink->stop(m_sink);
        }
    }
    emit_state_event("audio_state_changed");
    return true;
}

bool AudioEngine::resume() {
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (m_state != AudioEngineState::PAUSED) return false;

        m_state = AudioEngineState::PLAYING;
        if (m_sink && m_sink->start) {
            m_sink->start(m_sink);
        }
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
        if (m_sink) {
            if (m_sink->flush) m_sink->flush(m_sink);
            if (m_sink->stop) m_sink->stop(m_sink);
        }
        close_decoder_unlocked();
        m_current_frame = 0;
        m_current_file_path.clear();
    }

    emit_state_event("audio_state_changed");
    return true;
}

bool AudioEngine::seek(double position_seconds) {
    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);
        if (!m_decoder || !m_decoder->is_open()) return false;

        if (position_seconds < 0.0) position_seconds = 0.0;
        double dur = get_duration();
        if (dur > 0.0 && position_seconds > dur) {
            position_seconds = dur;
        }

        if (!m_decoder->seek_seconds(position_seconds)) {
            return false;
        }
        m_current_frame = m_decoder->get_current_frame();
        m_seek_epoch++;
        if (m_sink && m_sink->flush) {
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
        if (m_sink && m_sink->set_volume) {
            m_sink->set_volume(m_sink, volume);
        }
    }
    emit_state_event("audio_volume_changed");
    return true;
}

AudioEngineState AudioEngine::get_state_enum() const {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    return m_state;
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
    uint32_t buffered = (m_sink && m_sink->get_buffered_frames) ? m_sink->get_buffered_frames(m_sink) : 0;
    uint64_t played = (current > buffered) ? (current - buffered) : 0;
    return static_cast<double>(played) / static_cast<double>(m_sample_rate);
}

double AudioEngine::get_duration() const {
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
    j["position"] = get_position();
    j["duration"] = get_duration();
    j["volume"] = m_volume;
    return j;
}

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

    cb(event.dump());
}

void AudioEngine::pump_loop() {
    const uint32_t chunk_frames = 512;
    std::vector<float> buffer(chunk_frames * m_channels);

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
                frames_read = m_decoder->read_pcm_frames(buffer.data(), chunk_frames);
                chunk_epoch = m_seek_epoch; // Record the seek epoch when this chunk decoded
            }
        } // LOCK END

        if (is_paused) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20)); // There will be a MAX delay of 20ms
            continue;
        }

        if (frames_read == 0) {
            // EOF reached or decode error:
            // If sink has pending buffered frames, wait for buffer to drain to hardware output
            while (m_pump_running) {
                {
                    std::lock_guard<std::recursive_mutex> lock(m_mutex);
                    if (m_state != AudioEngineState::PLAYING) break;
                    if (!m_sink || !m_sink->get_buffered_frames) break;
                    uint32_t remaining = m_sink->get_buffered_frames(m_sink);
                    if (remaining == 0) break;
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }

            {
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_pump_running && m_state == AudioEngineState::PLAYING) {
                    m_state = AudioEngineState::STOPPED;
                    m_pump_running = false;
                    if (m_sink && m_sink->stop) m_sink->stop(m_sink);
                    emit_state_event("audio_ended");
                }
            }
            break;
        }

        // Natural Backpressure !
        uint32_t frames_written_total = 0; // The frames successfully written into the sink
        while (frames_written_total < frames_read && m_pump_running) {

            { // LOCK
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_state != AudioEngineState::PLAYING || m_seek_epoch != chunk_epoch) {
                    // A New seek happened or status changed, abandon this chunk
                    break;
                }
            } // LOCK END

            const float *src = buffer.data() + (frames_written_total * m_channels);
            uint32_t to_write = frames_read - frames_written_total;

            if (!m_sink || !m_sink->write_pcm) break;
            int written = m_sink->write_pcm(m_sink, src, to_write);

            if (written > 0) {
                frames_written_total += static_cast<uint32_t>(written);
                // LOCK and update m_current_frame
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_seek_epoch == chunk_epoch) { // If m_seek_epoch remains unchanged
                    m_current_frame += written;
                }
            } else if (written < 0) {
                // Sink error, or the device disconnected
                break;
            } else {
                // written == 0, Buffer IS Full
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
            }
        }
    }
}

} // namespace lyra
