/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#define MINIAUDIO_IMPLEMENTATION
#include "extern/miniaudio.h"

#include "services/audio_sinks/local_audio_sink.h"
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <iostream>

namespace lyra {

struct LocalAudioSinkImpl::InternalState {
    ma_device device{};
    ma_pcm_rb ring_buffer{};
    bool device_inited{false};
    bool rb_inited{false};
    std::optional<ma_device_id> target_device_id{std::nullopt};
    std::string target_device_id_str{"default"};
};

namespace {

std::string device_id_to_hex(const ma_device_id &id) {
    const uint8_t *bytes = reinterpret_cast<const uint8_t *>(&id);
    std::string hex;
    hex.reserve(sizeof(ma_device_id) * 2);
    const char hex_chars[] = "0123456789abcdef";
    for (size_t i = 0; i < sizeof(ma_device_id); ++i) {
        hex.push_back(hex_chars[(bytes[i] >> 4) & 0x0F]);
        hex.push_back(hex_chars[bytes[i] & 0x0F]);
    }
    return hex;
}

bool hex_to_device_id(const std::string &hex, ma_device_id &id) {
    if (hex.length() != sizeof(ma_device_id) * 2) return false;
    uint8_t *bytes = reinterpret_cast<uint8_t *>(&id);
    for (size_t i = 0; i < sizeof(ma_device_id); ++i) {
        char h1 = hex[i * 2];
        char h2 = hex[i * 2 + 1];
        auto char_to_nibble = [](char c) -> int {
            if (c >= '0' && c <= '9') return c - '0';
            if (c >= 'a' && c <= 'f') return c - 'a' + 10;
            if (c >= 'A' && c <= 'F') return c - 'A' + 10;
            return -1;
        };
        int n1 = char_to_nibble(h1);
        int n2 = char_to_nibble(h2);
        if (n1 < 0 || n2 < 0) return false;
        bytes[i] = static_cast<uint8_t>((n1 << 4) | n2);
    }
    return true;
}

ma_format lyra_format_to_ma(uint8_t format) {
    switch (format) {
        case LYRA_AUDIO_FORMAT_F32:
            return ma_format_f32;
        case LYRA_AUDIO_FORMAT_S16:
            return ma_format_s16;
        case LYRA_AUDIO_FORMAT_S24:
            return ma_format_s24;
        case LYRA_AUDIO_FORMAT_S32:
            return ma_format_s32;
        default:
            return ma_format_f32;
    }
}

void ma_data_callback(ma_device *pDevice, void *pOutput, const void *pInput, ma_uint32 frameCount) {
    (void)pInput;
    auto *state = static_cast<LocalAudioSinkImpl::InternalState *>(pDevice->pUserData);
    if (!state || !state->rb_inited) {
        std::memset(pOutput, 0, frameCount * ma_get_bytes_per_frame(pDevice->playback.format, pDevice->playback.channels));
        return;
    }

    size_t bpf = ma_get_bytes_per_frame(pDevice->playback.format, pDevice->playback.channels);
    uint8_t *outBytes = static_cast<uint8_t *>(pOutput);
    ma_uint32 framesRemaining = frameCount;

    while (framesRemaining > 0) {
        ma_uint32 framesToRead = framesRemaining;
        void *pBufferOut = nullptr;

        ma_result result = ma_pcm_rb_acquire_read(&state->ring_buffer, &framesToRead, &pBufferOut);
        if (result != MA_SUCCESS || framesToRead == 0) {
            // Fill rest with silence if ring buffer is empty
            std::memset(outBytes, 0, framesRemaining * bpf);
            break;
        }

        std::memcpy(outBytes, pBufferOut, framesToRead * bpf);
        ma_pcm_rb_commit_read(&state->ring_buffer, framesToRead);

        outBytes += (framesToRead * bpf);
        framesRemaining -= framesToRead;
    }
}

std::mutex g_context_mutex;
ma_context g_shared_context;
bool g_shared_context_inited = false;

ma_context *get_shared_ma_context() {
    std::lock_guard<std::mutex> lock(g_context_mutex);
    if (!g_shared_context_inited) {
        if (ma_context_init(NULL, 0, NULL, &g_shared_context) == MA_SUCCESS) {
            g_shared_context_inited = true;
        } else {
            return nullptr;
        }
    }
    return &g_shared_context;
}

} // namespace

LocalAudioSinkImpl::LocalAudioSinkImpl() : m_state(new InternalState()) {}

LocalAudioSinkImpl::~LocalAudioSinkImpl() {
    close();
    delete m_state;
}

int LocalAudioSinkImpl::open(const LyraAudioSpec *spec) {
    if (!spec) return -1;

    ma_format format = lyra_format_to_ma(spec->format);
    uint32_t channels = spec->channels == 0 ? 2 : spec->channels;
    uint32_t sample_rate = spec->sample_rate == 0 ? 44100 : spec->sample_rate;

    if (m_open && m_state->device_inited && m_state->rb_inited &&
        m_spec.sample_rate == sample_rate &&
        m_spec.channels == channels &&
        m_spec.format == spec->format) {
        // Reuse initialized device and clear buffer
        flush();
        return 0;
    }

    if (m_open) close();

    m_spec = *spec;
    m_spec.channels = static_cast<uint8_t>(channels);
    m_spec.sample_rate = sample_rate;

    // Buffer 2 seconds worth of frames in ring buffer
    ma_uint32 rb_capacity = sample_rate * 2;
    ma_result result = ma_pcm_rb_init(format, channels, rb_capacity, NULL, NULL, &m_state->ring_buffer);
    if (result != MA_SUCCESS) {
        return -1;
    }
    m_state->rb_inited = true;

    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format = format;
    config.playback.channels = channels;
    config.sampleRate = sample_rate;
    config.dataCallback = ma_data_callback;
    config.pUserData = m_state;
    if (m_state->target_device_id.has_value()) {
        config.playback.pDeviceID = &(*m_state->target_device_id);
    }

    ma_context *ctx = get_shared_ma_context();
    result = ma_device_init(ctx, &config, &m_state->device);
    if (result != MA_SUCCESS) {
        ma_pcm_rb_uninit(&m_state->ring_buffer);
        m_state->rb_inited = false;
        return -1;
    }
    m_state->device_inited = true;
    m_open = true;

    set_volume(m_volume);
    return 0;
}

int LocalAudioSinkImpl::start() {
    if (!m_open) return -1;
    if (m_state->device_inited) {
        ma_result result = ma_device_start(&m_state->device);
        if (result != MA_SUCCESS) return -1;
    }
    m_playing = true;
    return 0;
}

int LocalAudioSinkImpl::stop() {
    if (m_state->device_inited && m_playing) {
        ma_device_stop(&m_state->device);
    }
    m_playing = false;
    return 0;
}

int LocalAudioSinkImpl::close() {
    stop();
    if (m_state->device_inited) {
        ma_device_uninit(&m_state->device);
        m_state->device_inited = false;
    }
    if (m_state->rb_inited) {
        ma_pcm_rb_uninit(&m_state->ring_buffer);
        m_state->rb_inited = false;
    }
    m_open = false;
    return 0;
}

int LocalAudioSinkImpl::flush() {
    if (m_state && m_state->rb_inited) {
        ma_pcm_rb_reset(&m_state->ring_buffer);
    }
    return 0;
}

uint32_t LocalAudioSinkImpl::get_buffered_frames() const {
    if (!m_open || !m_state || !m_state->rb_inited || !m_state->device_inited) return 0;
    return ma_pcm_rb_available_read(&m_state->ring_buffer);
}

int LocalAudioSinkImpl::write_pcm(const void *pcm_data, uint32_t frame_count) {
    if (!m_open || !m_state->rb_inited || !pcm_data) return -1;

    size_t bpf = ma_get_bytes_per_frame(lyra_format_to_ma(m_spec.format), m_spec.channels == 0 ? 2 : m_spec.channels);
    const uint8_t *inBytes = static_cast<const uint8_t *>(pcm_data);
    ma_uint32 framesRemaining = frame_count;
    ma_uint32 totalWritten = 0;

    while (framesRemaining > 0) {
        ma_uint32 framesToWrite = framesRemaining;
        void *pBufferIn = nullptr;

        ma_result result = ma_pcm_rb_acquire_write(&m_state->ring_buffer, &framesToWrite, &pBufferIn);
        if (result != MA_SUCCESS || framesToWrite == 0) {
            break;
        }

        std::memcpy(pBufferIn, inBytes, framesToWrite * bpf);
        ma_pcm_rb_commit_write(&m_state->ring_buffer, framesToWrite);

        inBytes += (framesToWrite * bpf);
        framesRemaining -= framesToWrite;
        totalWritten += framesToWrite;
    }

    return static_cast<int>(totalWritten);
}

int LocalAudioSinkImpl::set_volume(float volume) {
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;
    m_volume = volume;
    if (m_state->device_inited) {
        ma_device_set_master_volume(&m_state->device, volume);
    }
    return 0;
}

bool LocalAudioSinkImpl::set_output_device(const std::string &device_id) {
    if (device_id == "default" || device_id.empty()) {
        m_state->target_device_id = std::nullopt;
        m_state->target_device_id_str = "default";
    } else {
        ma_device_id id{};
        if (!hex_to_device_id(device_id, id)) {
            return false;
        }
        m_state->target_device_id = id;
        m_state->target_device_id_str = device_id;
    }

    if (m_open) {
        bool was_playing = m_playing;
        LyraAudioSpec saved_spec = m_spec;
        close();
        if (open(&saved_spec) != 0) {
            return false;
        }
        if (was_playing) {
            start();
        }
    }
    return true;
}

std::string LocalAudioSinkImpl::get_output_device() const {
    return m_state ? m_state->target_device_id_str : "default";
}

std::vector<AudioDeviceInfo> LocalAudioSinkImpl::list_devices() {
    std::vector<AudioDeviceInfo> devices;
    ma_context *context = get_shared_ma_context();
    if (!context) {
        // Fallback default device
        devices.push_back({"default", "Default Audio Device", true, 1, 2, 44100, 192000});
        return devices;
    }

    ma_device_info *pPlaybackDeviceInfos = nullptr;
    ma_uint32 playbackDeviceCount = 0;
    ma_device_info *pCaptureDeviceInfos = nullptr;
    ma_uint32 captureDeviceCount = 0;

    std::lock_guard<std::mutex> lock(g_context_mutex);
    if (ma_context_get_devices(context, &pPlaybackDeviceInfos, &playbackDeviceCount,
                               &pCaptureDeviceInfos, &captureDeviceCount) == MA_SUCCESS) {
        for (ma_uint32 i = 0; i < playbackDeviceCount; ++i) {
            AudioDeviceInfo info;
            info.id = device_id_to_hex(pPlaybackDeviceInfos[i].id);
            info.name = pPlaybackDeviceInfos[i].name;
            info.is_default = (pPlaybackDeviceInfos[i].isDefault != 0);

            ma_device_info fullInfo{};
            if (ma_context_get_device_info(context, ma_device_type_playback, &pPlaybackDeviceInfos[i].id, &fullInfo) == MA_SUCCESS) {
                if (fullInfo.nativeDataFormatCount > 0) {
                    int min_ch = 8;
                    int max_ch = 1;
                    int min_sr = 192000;
                    int max_sr = 44100;
                    bool has_valid_format = false;
                    for (ma_uint32 f = 0; f < fullInfo.nativeDataFormatCount; ++f) {
                        int ch = fullInfo.nativeDataFormats[f].channels;
                        int sr = fullInfo.nativeDataFormats[f].sampleRate;
                        if (ch > 0) {
                            min_ch = std::min(min_ch, ch);
                            max_ch = std::max(max_ch, ch);
                            has_valid_format = true;
                        }
                        if (sr > 0) {
                            min_sr = std::min(min_sr, sr);
                            max_sr = std::max(max_sr, sr);
                            has_valid_format = true;
                        }
                    }
                    if (has_valid_format) {
                        info.min_channels = min_ch;
                        info.max_channels = max_ch;
                        info.min_sample_rate = min_sr;
                        info.max_sample_rate = max_sr;
                    }
                }
            }
            devices.push_back(std::move(info));
        }
    }

    if (devices.empty()) {
        devices.push_back({"default", "Default Audio Device", true, 1, 2, 44100, 192000});
    }

    return devices;
}

bool LocalAudioSinkImpl::is_valid_device_id(const std::string &device_id) {
    if (device_id == "default" || device_id.empty()) {
        return true;
    }
    ma_device_id id{};
    return hex_to_device_id(device_id, id);
}

namespace {
int local_sink_open(LyraAudioSink *sink, const LyraAudioSpec *spec) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->open(spec);
}

int local_sink_start(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->start();
}

int local_sink_stop(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->stop();
}

int local_sink_close(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->close();
}

int local_sink_flush(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->flush();
}

uint32_t local_sink_get_buffered_frames(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return 0;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->get_buffered_frames();
}

int local_sink_write_pcm(LyraAudioSink *sink, const void *pcm_data, uint32_t frame_count) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->write_pcm(pcm_data, frame_count);
}

int local_sink_set_volume(LyraAudioSink *sink, float volume) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->set_volume(volume);
}
} // namespace

LyraAudioSink *create_local_audio_sink() {
    auto *impl = new LocalAudioSinkImpl();
    auto *sink = new LyraAudioSink();
    sink->struct_size = sizeof(LyraAudioSink);
    sink->user_data = impl;
    sink->open = local_sink_open;
    sink->start = local_sink_start;
    sink->stop = local_sink_stop;
    sink->close = local_sink_close;
    sink->write_pcm = local_sink_write_pcm;
    sink->set_volume = local_sink_set_volume;
    sink->flush = local_sink_flush;
    sink->get_buffered_frames = local_sink_get_buffered_frames;
    return sink;
}

void destroy_local_audio_sink(LyraAudioSink *sink) {
    if (!sink) return;
    if (sink->user_data) {
        delete static_cast<LocalAudioSinkImpl *>(sink->user_data);
        sink->user_data = nullptr;
    }
    delete sink;
}

} // namespace lyra
