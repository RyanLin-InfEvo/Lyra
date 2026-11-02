/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include <dlfcn.h>
// Suppress dlclose for audio backend drivers (libpulse, libasound, pipewire-pulse).
// Audio driver backends spawn background daemon/event-loop threads (e.g. pw-miniaudio,
// DBus listeners). Unmapping the .text segment via dlclose while threads are terminating or
// waking from epoll_wait causes SIGSEGV on Linux under AddressSanitizer and multithreaded runs.
// Retaining the shared library mapping until process termination is safe and causes zero heap leaks.
#if defined(__unix__) || defined(__linux__)
#undef dlclose
#define dlclose(handle) ((int)0)
#endif

#define MINIAUDIO_IMPLEMENTATION
#include "extern/miniaudio.h"

#if defined(__unix__) || defined(__linux__)
#undef dlclose
#endif

#include "services/audio_sinks/local_audio_sink.h"
#include <algorithm>
#include <atomic>
#include <cstdlib>
#include <cstring>
#include <iostream>

namespace lyra {

struct LocalAudioSinkImpl::InternalState {
    ma_device device{};
    ma_pcm_rb ring_buffer{};
    ma_context *context{nullptr};
    bool device_inited{false};
    std::atomic<bool> rb_inited{false};
    std::optional<ma_device_id> target_device_id{std::nullopt};
    std::string target_device_id_str{"default"};
    uint32_t buffer_size_frames{DEFAULT_BUFFER_SIZE_FRAMES};
    bool exclusive_mode{false};
    bool exclusive_active{false};
    std::string active_device_id_str{"default"};
    uint32_t active_buffer_size_frames{DEFAULT_BUFFER_SIZE_FRAMES};
    bool active_exclusive_mode{false};
};

static_assert(std::atomic<bool>::is_always_lock_free,
              "atomic<bool> must be lock-free for realtime audio callback safety");
static_assert(std::is_same_v<decltype(LocalAudioSinkImpl::InternalState::rb_inited), std::atomic<bool>>,
              "LocalAudioSinkImpl::InternalState::rb_inited must be std::atomic<bool>");

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
    if (hex.length() != sizeof(ma_device_id) * 2 && hex.length() != 64) return false;
    std::memset(&id, 0, sizeof(ma_device_id));
    uint8_t *bytes = reinterpret_cast<uint8_t *>(&id);
    size_t byte_count = hex.length() / 2;
    for (size_t i = 0; i < byte_count; ++i) {
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
    if (bytes[sizeof(ma_device_id) - 1] != 0) return false;
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
    if (!state || !state->rb_inited.load(std::memory_order_acquire)) {
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
ma_context g_shared_context{};
bool g_shared_context_inited = false;
std::atomic<int> g_active_device_count{0};

ma_context *get_shared_ma_context() {
    // TODO(hotplug): Register OS/backend-level device topology listener (WASAPI IMMNotificationClient, CoreAudio kAudioHardwarePropertyDevices, PulseAudio/PipeWire subscription, or udev) to detect device plug/unplug while idle and notify AudioEngine.
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
    if (m_state) {
        cleanup_failed_device_unlocked();
        m_state->context = nullptr;
    }
    delete m_state;
}

// Cleans up any partially-initialized backend device state when ma_device_init fails.
//
// Root Cause / Upstream Miniaudio Behavior:
// During ma_device_init, the backend initialization callback (onDeviceInit) executes first.
// For backends like JACK, ma_device_init__jack allocates internal playback and capture buffers
// (e.g. pDevice->jack.pIntermediaryBufferPlayback, 16 KB). If subsequent validation checks fail
// (e.g. ma_device_post_init fails due to offline/invalid device IDs, unsupported formats, or
// lack of physical JACK ports in headless CI environments), ma_device_init calls ma_device_uninit(pDevice).
//
// However, ma_device_uninit begins with:
//     if (!ma_device__is_initialized(pDevice)) return;
// Since the device state is only promoted to ma_device_state_stopped/started at the very end
// of ma_device_init, pDevice->state is still 0 (ma_device_state_uninitialized).
// Consequently, ma_device_uninit early-returns immediately WITHOUT calling onDeviceUninit!
//
// This leaves any buffers allocated during onDeviceInit permanently leaked on the heap.
// By explicitly invoking onDeviceUninit and zeroing the structure, we ensure all intermediate
// backend allocations are 100% freed across all initialization failures and fallback retries.
void LocalAudioSinkImpl::cleanup_failed_device_unlocked() {
    if (m_state) {
        if (m_state->device.pContext && m_state->device.pContext->callbacks.onDeviceUninit) {
            m_state->device.pContext->callbacks.onDeviceUninit(&m_state->device);
        }
        std::memset(&m_state->device, 0, sizeof(m_state->device));
    }
}

void LocalAudioSinkImpl::uninit_device_internal_unlocked() {
    if (m_state && m_state->device_inited) {
        ma_device_uninit(&m_state->device);
        m_state->device_inited = false;
        std::memset(&m_state->device, 0, sizeof(m_state->device));
        g_active_device_count.fetch_sub(1, std::memory_order_release);
    }
}

bool LocalAudioSinkImpl::init_device_unlocked(bool force_shared) {
    if (!m_state) return false;
    uninit_device_internal_unlocked();

    if (!m_state->context) {
        m_state->context = get_shared_ma_context();
        if (!m_state->context) return false;
    }


    // setup config
    ma_format format = lyra_format_to_ma(m_spec.format);
    uint32_t channels = m_spec.channels == 0 ? 2 : m_spec.channels;
    uint32_t sample_rate = m_spec.sample_rate == 0 ? 44100 : m_spec.sample_rate;

    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format = format;
    config.playback.channels = channels;
    config.sampleRate = sample_rate;
    config.periodSizeInFrames = m_state->buffer_size_frames;
    config.dataCallback = ma_data_callback;
    // TODO(hotplug): Wire config.notificationCallback (ma_device_notification_type_stopped / rerouted) to detect mid-playback hardware disconnection and notify AudioEngine to halt playback and refresh the UI device list.
    config.pUserData = m_state;
    if (m_state->target_device_id.has_value()) {
        if (!is_device_available(m_state->target_device_id_str)) {
            m_state->exclusive_active = false;
            return false;
        }
        config.playback.pDeviceID = &(*m_state->target_device_id);
    }

    // exclusive mode
    m_state->exclusive_active = false;
    bool try_exclusive = m_state->exclusive_mode && !force_shared;
    if (try_exclusive) {
        config.playback.shareMode = ma_share_mode_exclusive;
    } else {
        config.playback.shareMode = ma_share_mode_shared;
    }

    ma_result result = ma_device_init(m_state->context, &config, &m_state->device);
    if (result != MA_SUCCESS && try_exclusive) {
        // Exclusive mode failed: clean up partial state to prevent upstream miniaudio leak before fallback retry
        cleanup_failed_device_unlocked();
        // fail and request exclusive mode -> fallback to share mode
        config.playback.shareMode = ma_share_mode_shared;
        result = ma_device_init(m_state->context, &config, &m_state->device);
    }

    if (result != MA_SUCCESS) {
        // Device init failed completely: clean up partial state to prevent upstream miniaudio leak
        cleanup_failed_device_unlocked();
        // fail with share mode -> return FAIL, END
        m_state->exclusive_active = false;
        return false;
    }


    m_state->exclusive_active = (config.playback.shareMode == ma_share_mode_exclusive);
    m_state->device_inited = true;
    g_active_device_count.fetch_add(1, std::memory_order_release);
    m_state->active_device_id_str = m_state->target_device_id_str;
    m_state->active_buffer_size_frames = m_state->buffer_size_frames;
    m_state->active_exclusive_mode = m_state->exclusive_active;

    ma_device_set_master_volume(&m_state->device, m_volume);
    return true;
}

bool LocalAudioSinkImpl::reconfigure_device_unlocked(bool defer_if_stopped) {
    if (!m_state) return false;
    if (!m_open) return true;

    bool was_playing = m_playing;
    if (defer_if_stopped && !was_playing) {
        uninit_device_internal_unlocked();
        m_state->exclusive_active = false;
        return true;
    }

    if (was_playing && m_state->device_inited) {
        ma_device_stop(&m_state->device);
    }

    if (!init_device_unlocked()) {
        m_playing = false;
        return false;
    }

    if (was_playing) {
        if (start() != 0) {
            m_playing = false;
            return false;
        }
    } else {
        stop();
    }
    return true;
}


int LocalAudioSinkImpl::open(const LyraAudioSpec *spec) {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (!spec) return -1;
    if (spec->sample_rate > 768000 || spec->channels > 32) return -1;

    ma_format format = lyra_format_to_ma(spec->format);
    uint32_t channels = spec->channels == 0 ? 2 : spec->channels;
    uint32_t sample_rate = spec->sample_rate == 0 ? 44100 : spec->sample_rate;

    if (m_open && m_state->device_inited && m_state->rb_inited.load(std::memory_order_acquire) &&
        m_spec.sample_rate == sample_rate &&
        m_spec.channels == channels &&
        m_spec.format == spec->format &&
        m_state->active_device_id_str == m_state->target_device_id_str &&
        m_state->active_buffer_size_frames == m_state->buffer_size_frames &&
        m_state->active_exclusive_mode == m_state->exclusive_mode) {
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
    m_state->rb_inited.store(true, std::memory_order_release);

    if (!init_device_unlocked()) {
        m_state->rb_inited.store(false, std::memory_order_release);
        ma_pcm_rb_uninit(&m_state->ring_buffer);
        return -1;
    }

    m_open = true;
    return 0;
}

int LocalAudioSinkImpl::start() {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (!m_open) return -1;
    if (!m_state->device_inited) {     // not inited
        if (!init_device_unlocked()) { // try to init now
            return -1;
        }
    }
    if (m_state->device_inited) {
        ma_result result = ma_device_start(&m_state->device);
        if (result != MA_SUCCESS) {
            if (m_state->exclusive_active) {
                // Exclusive mode start failure fallback to shared mode
                uninit_device_internal_unlocked();
                m_state->exclusive_active = false;

                if (init_device_unlocked(true /* force_shared */)) {
                    result = ma_device_start(&m_state->device);
                    if (result == MA_SUCCESS) {
                        m_playing = true;
                        return 0;
                    }
                    uninit_device_internal_unlocked();
                }
            }
            return -1;
        }
    }
    m_playing = true;
    return 0;
}

int LocalAudioSinkImpl::stop() {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (m_state->device_inited && m_playing) {
        ma_device_stop(&m_state->device);
    }
    m_playing = false;
    if (m_state->exclusive_active) {
        uninit_device_internal_unlocked();
        m_state->exclusive_active = false;
    }
    return 0;
}

int LocalAudioSinkImpl::close() {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    stop();
    uninit_device_internal_unlocked();
    if (m_state->rb_inited.load(std::memory_order_acquire)) {
        m_state->rb_inited.store(false, std::memory_order_release);
        ma_pcm_rb_uninit(&m_state->ring_buffer);
    }
    m_state->exclusive_active = false;
    m_open = false;
    return 0;
}

int LocalAudioSinkImpl::flush() {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (m_state && m_state->rb_inited.load(std::memory_order_acquire)) {
        if (m_state->device_inited && m_playing) {
            ma_device_stop(&m_state->device);
            ma_pcm_rb_reset(&m_state->ring_buffer);
            ma_device_start(&m_state->device);
        } else {
            ma_pcm_rb_reset(&m_state->ring_buffer);
        }
    }
    return 0;
}

uint32_t LocalAudioSinkImpl::get_buffered_frames() const {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (!m_open || !m_state || !m_state->rb_inited.load(std::memory_order_acquire)) return 0;
    return ma_pcm_rb_available_read(&m_state->ring_buffer);
}

int LocalAudioSinkImpl::write_pcm(const void *pcm_data, uint32_t frame_count) {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (!m_open || !m_state || !m_state->rb_inited.load(std::memory_order_acquire) || !pcm_data) return -1;

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
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;
    m_volume = volume;
    if (m_state->device_inited) {
        ma_device_set_master_volume(&m_state->device, volume);
    }
    return 0;
}

bool LocalAudioSinkImpl::set_output_device(const std::string &device_id) {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (!m_state) return false;

    const std::string normalized_id = (device_id.empty() ? "default" : device_id);
    if (m_state->target_device_id_str == normalized_id) {
        return true;
    }

    std::optional<ma_device_id> new_id = std::nullopt;
    if (normalized_id != "default") {
        ma_device_id id{};
        if (!hex_to_device_id(normalized_id, id)) {
            return false;
        }
        if (!is_device_available(normalized_id)) {
            return false;
        }
        new_id = id;
    }

    auto old_id = m_state->target_device_id;
    auto old_str = m_state->target_device_id_str;

    m_state->target_device_id = new_id;
    m_state->target_device_id_str = normalized_id;

    if (m_open) {
        bool was_playing = m_playing;
        if (!reconfigure_device_unlocked(true)) { // if fail
            m_state->target_device_id = old_id;   // fallback
            m_state->target_device_id_str = old_str;
            m_playing = was_playing;
            bool rollback_ok = reconfigure_device_unlocked(!was_playing);
            if (!rollback_ok) {
                m_playing = false;
            }
            return false;
        }
    }
    return true;
}

std::string LocalAudioSinkImpl::get_output_device() const {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    return m_state ? m_state->target_device_id_str : "default";
}

bool LocalAudioSinkImpl::set_buffer_size_frames(uint32_t frames) {
    if (frames < MIN_BUFFER_SIZE_FRAMES || frames > MAX_BUFFER_SIZE_FRAMES) {
        return false;
    }
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (!m_state) {
        return false;
    }
    if (m_state->buffer_size_frames == frames) {
        return true;
    }
    uint32_t old_frames = m_state->buffer_size_frames;
    m_state->buffer_size_frames = frames;
    if (m_open) {
        bool was_playing = m_playing;
        if (!reconfigure_device_unlocked(true)) {
            m_state->buffer_size_frames = old_frames;
            m_playing = was_playing;
            bool rollback_ok = reconfigure_device_unlocked(!was_playing);
            if (!rollback_ok) {
                m_playing = false;
            }
            return false;
        }
    }
    return true;
}

uint32_t LocalAudioSinkImpl::get_buffer_size_frames() const {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    return m_state ? m_state->buffer_size_frames : DEFAULT_BUFFER_SIZE_FRAMES;
}

bool LocalAudioSinkImpl::set_exclusive_mode(bool exclusive) {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    if (!m_state) {
        return false;
    }
    if (m_state->exclusive_mode == exclusive) {
        return true;
    }
    bool old_mode = m_state->exclusive_mode;
    m_state->exclusive_mode = exclusive;
    if (m_open) {
        bool was_playing = m_playing;
        if (!reconfigure_device_unlocked(true)) {
            m_state->exclusive_mode = old_mode;
            m_playing = was_playing;
            bool rollback_ok = reconfigure_device_unlocked(!was_playing);
            if (!rollback_ok) {
                m_playing = false;
            }
            return false;
        }
    }
    return true;
}

bool LocalAudioSinkImpl::get_exclusive_mode() const {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    return m_state ? m_state->exclusive_mode : false;
}

bool LocalAudioSinkImpl::is_exclusive_mode_active() const {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    return m_state ? m_state->exclusive_active : false;
}

bool LocalAudioSinkImpl::is_open() const {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    return m_open;
}

bool LocalAudioSinkImpl::is_playing() const {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    return m_playing;
}

float LocalAudioSinkImpl::get_volume() const {
    std::lock_guard<std::recursive_mutex> lock(m_sink_mutex);
    return m_volume;
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
                    bool has_valid_format = false;
                    int min_ch = 0, max_ch = 0;
                    int min_sr = 0, max_sr = 0;
                    for (ma_uint32 f = 0; f < fullInfo.nativeDataFormatCount; ++f) {
                        int ch = fullInfo.nativeDataFormats[f].channels;
                        int sr = fullInfo.nativeDataFormats[f].sampleRate;
                        if (ch <= 0 || sr <= 0) continue;
                        if (!has_valid_format) {
                            min_ch = max_ch = ch;
                            min_sr = max_sr = sr;
                            has_valid_format = true;
                        } else {
                            min_ch = std::min(min_ch, ch);
                            max_ch = std::max(max_ch, ch);
                            min_sr = std::min(min_sr, sr);
                            max_sr = std::max(max_sr, sr);
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

bool LocalAudioSinkImpl::is_device_available(const std::string &device_id) {
    if (device_id.empty() || device_id == "default") {
        return true;
    }
    ma_device_id target_id{};
    if (!hex_to_device_id(device_id, target_id)) {
        return false;
    }
    const std::string canonical_hex = device_id_to_hex(target_id);
    const auto devices = list_devices();
    for (const auto &d : devices) {
        if (d.id == canonical_hex || d.id == device_id) {
            return true;
        }
    }
    return false;
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

int local_sink_set_output_device(LyraAudioSink *sink, const char *device_id) {
    if (!sink || !sink->user_data) return -1;
    std::string id_str = device_id ? device_id : "default";
    auto *impl = static_cast<LocalAudioSinkImpl *>(sink->user_data);
    bool was_playing = impl->is_playing();
    if (!impl->set_output_device(id_str)) {
        return (was_playing && !impl->is_playing()) ? -2 : -1;
    }
    return 0;
}

int local_sink_set_buffer_size_frames(LyraAudioSink *sink, uint32_t frames) {
    if (!sink || !sink->user_data) return -1;
    auto *impl = static_cast<LocalAudioSinkImpl *>(sink->user_data);
    bool was_playing = impl->is_playing();
    if (!impl->set_buffer_size_frames(frames)) {
        return (was_playing && !impl->is_playing()) ? -2 : -1;
    }
    return 0;
}

int local_sink_set_exclusive_mode(LyraAudioSink *sink, int exclusive) {
    if (!sink || !sink->user_data) return -1;
    auto *impl = static_cast<LocalAudioSinkImpl *>(sink->user_data);
    bool was_playing = impl->is_playing();
    if (!impl->set_exclusive_mode(exclusive != 0)) {
        return (was_playing && !impl->is_playing()) ? -2 : -1;
    }
    return 0;
}

int local_sink_is_exclusive_mode_active(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return 0;
    return static_cast<LocalAudioSinkImpl *>(sink->user_data)->is_exclusive_mode_active() ? 1 : 0;
}
} // namespace

LyraAudioSink *create_local_audio_sink() {
    auto *impl = new LocalAudioSinkImpl();
    auto *sink = new LyraAudioSink();
    sink->struct_size = sizeof(LyraAudioSink);
    sink->user_data = impl; // The impl for other functions
    sink->open = local_sink_open;
    sink->start = local_sink_start;
    sink->stop = local_sink_stop;
    sink->close = local_sink_close;
    sink->write_pcm = local_sink_write_pcm;
    sink->set_volume = local_sink_set_volume;
    sink->flush = local_sink_flush;
    sink->get_buffered_frames = local_sink_get_buffered_frames;
    sink->set_output_device = local_sink_set_output_device;
    sink->set_buffer_size_frames = local_sink_set_buffer_size_frames;
    sink->set_exclusive_mode = local_sink_set_exclusive_mode;
    sink->is_exclusive_mode_active = local_sink_is_exclusive_mode_active;
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

std::vector<AudioDeviceInfo> list_local_audio_devices() {
    return LocalAudioSinkImpl::list_devices();
}

bool is_valid_audio_device_id(const std::string &device_id) {
    return LocalAudioSinkImpl::is_valid_device_id(device_id);
}

bool is_audio_device_available(const std::string &device_id) {
    return LocalAudioSinkImpl::is_device_available(device_id);
}

bool LocalAudioSinkImpl::shutdown_shared_context() {
    std::lock_guard<std::mutex> lock(g_context_mutex);
    if (!g_shared_context_inited) {
        return true;
    }
    if (g_active_device_count.load(std::memory_order_acquire) > 0) {
        return false;
    }
    ma_result res = ma_context_uninit(&g_shared_context);
    if (res == MA_SUCCESS) {
        g_shared_context_inited = false;
        return true;
    }
    return false;
}

bool LocalAudioSinkImpl::is_context_initialized() {
    std::lock_guard<std::mutex> lock(g_context_mutex);
    return g_shared_context_inited;
}

int LocalAudioSinkImpl::get_active_device_count() {
    return g_active_device_count.load(std::memory_order_acquire);
}

bool shutdown_local_audio_context() {
    return LocalAudioSinkImpl::shutdown_shared_context();
}

} // namespace lyra
