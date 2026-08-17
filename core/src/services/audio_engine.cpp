/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_engine.h"
#include "extern/miniaudio.h"
#include "services/audio_sinks/null_audio_sink.h"

#include <chrono>
#include <cmath>
#include <iostream>
#include <vector>

namespace lyra {


AudioEngine::AudioEngine() {
    // Default to NullAudioSink for safe headless operation
    m_sink = create_null_audio_sink();
    m_sink_deleter = destroy_null_audio_sink;
}

AudioEngine::~AudioEngine() {
    stop();
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
}

void AudioEngine::set_event_callback(EventCallbackFunc callback) {
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_event_callback = std::move(callback);
}

void AudioEngine::close_decoder_unlocked() {
    if (m_decoder_initialized && m_decoder_ptr) {
        auto *decoder = static_cast<ma_decoder *>(m_decoder_ptr);
        ma_decoder_uninit(decoder);
        delete decoder;
        m_decoder_ptr = nullptr;
        m_decoder_initialized = false;
    }
}

bool AudioEngine::play(const std::string &file_path) {
    stop(); // Ensure clean state before starting new playback

    {
        std::lock_guard<std::recursive_mutex> lock(m_mutex);

        auto *decoder = new ma_decoder();
        ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 0, 0);
        ma_result result = ma_decoder_init_file(file_path.c_str(), &config, decoder);
        if (result != MA_SUCCESS) {
            delete decoder;
            return false;
        }

        m_decoder_ptr = decoder;
        m_decoder_initialized = true;
        m_sample_rate = decoder->outputSampleRate;
        m_channels = static_cast<uint8_t>(decoder->outputChannels);

        ma_uint64 length_frames = 0;
        if (ma_decoder_get_length_in_pcm_frames(decoder, &length_frames) == MA_SUCCESS) {
            m_total_frames = length_frames;
        } else {
            m_total_frames = 0;
        }

        m_current_frame = 0;
        m_current_file_path = file_path;

        if (m_sink) {
            LyraAudioSpec spec{};
            spec.sample_rate = m_sample_rate;
            spec.channels = m_channels;
            spec.format = LYRA_AUDIO_FORMAT_F32;

            if (m_sink->open) {
                m_sink->open(m_sink, &spec);
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
            if (m_sink->stop) m_sink->stop(m_sink);
            if (m_sink->close) m_sink->close(m_sink);
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
        if (!m_decoder_initialized || !m_decoder_ptr) return false;

        if (position_seconds < 0.0) position_seconds = 0.0;
        ma_uint64 target_frame = static_cast<ma_uint64>(position_seconds * m_sample_rate);
        if (m_total_frames > 0 && target_frame > m_total_frames) {
            target_frame = m_total_frames;
        }

        auto *decoder = static_cast<ma_decoder *>(m_decoder_ptr);
        ma_result result = ma_decoder_seek_to_pcm_frame(decoder, target_frame);
        if (result != MA_SUCCESS) {
            return false;
        }
        m_current_frame = target_frame;
        m_seek_epoch++;
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
    if (m_sample_rate == 0) return 0.0;
    return static_cast<double>(m_current_frame.load()) / static_cast<double>(m_sample_rate);
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

        ma_uint64 frames_read = 0;
        ma_result result = MA_SUCCESS;
        bool is_paused = false;
        uint64_t chunk_epoch = 0;
        { // LOCK
            std::lock_guard<std::recursive_mutex> lock(m_mutex);

            if (m_state == AudioEngineState::PAUSED) {
                // PAUSED, sleep outside the lock for 20ms Than directly get out of the lock
                is_paused = true;
            } else if (m_state != AudioEngineState::PLAYING || !m_decoder_ptr || !m_pump_running) {
                // STOPED or encouner some error
                break;
            }

            auto *decoder = static_cast<ma_decoder *>(m_decoder_ptr);
            result = ma_decoder_read_pcm_frames(decoder, buffer.data(), chunk_frames, &frames_read);
            chunk_epoch = m_seek_epoch; // Record the seek epoch when this chunck decoded
        } // LOCK END

        if (is_paused) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20)); // There will be a MAX delay of 20ms
            continue;
        }

        if (result != MA_SUCCESS || frames_read == 0) {
            // EOF reached or decode error
            {
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                m_state = AudioEngineState::STOPPED;
                m_pump_running = false;
                if (m_sink && m_sink->stop) m_sink->stop(m_sink);
            }
            emit_state_event("audio_ended");
            break;
        }


        // Natural Backpressure !
        uint32_t frames_written_total = 0; // The frames successfuly written in to the sink
        while (frames_written_total < frames_read && m_pump_running) {

            { // LOCK
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_state != AudioEngineState::PLAYING || m_seek_epoch != chunk_epoch) {
                    // A New seek happen or status changes, abandon this chunk
                    break;
                }
            } // LOCK END

            const float *src = buffer.data() + (frames_written_total * m_channels);
            uint32_t to_write = static_cast<uint32_t>(frames_read) - frames_written_total;

            if (!m_sink || !m_sink->write_pcm) break;
            int written = m_sink->write_pcm(m_sink, src, to_write);

            if (written > 0) {
                frames_written_total += static_cast<uint32_t>(written);
                // LOCK and update m_current_frame
                std::lock_guard<std::recursive_mutex> lock(m_mutex);
                if (m_seek_epoch == chunk_epoch) { // If m_seek_epoch remains unchange
                    m_current_frame += written;
                }
            } else if (written < 0) {
                // Sink error, or the device
                break;
            } else {
                // written == 0, Buffer IS Full
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
            }
        }
    }
}

} // namespace lyra
