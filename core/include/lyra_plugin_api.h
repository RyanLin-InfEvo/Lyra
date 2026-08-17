/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#ifndef LYRA_PLUGIN_API_H
#define LYRA_PLUGIN_API_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Audio sample format enum
typedef enum LyraAudioFormat {
    LYRA_AUDIO_FORMAT_UNKNOWN = 0,
    LYRA_AUDIO_FORMAT_F32 = 1,
    LYRA_AUDIO_FORMAT_S16 = 2,
    LYRA_AUDIO_FORMAT_S24 = 3,
    LYRA_AUDIO_FORMAT_S32 = 4
} LyraAudioFormat;

// Audio specification struct
typedef struct LyraAudioSpec {
    uint32_t sample_rate;
    uint8_t channels;
    uint8_t format;
    uint16_t reserved; // Explicit padding & future expansion
} LyraAudioSpec;

// C-ABI Audio Sink Interface
typedef struct LyraAudioSink {
    uint32_t struct_size; // ABI versioning guard: sizeof(LyraAudioSink)
    void *user_data;

    // Open sink with audio specification
    int (*open)(struct LyraAudioSink *sink, const LyraAudioSpec *spec);

    // Start audio playback
    int (*start)(struct LyraAudioSink *sink);

    // Stop audio playback
    int (*stop)(struct LyraAudioSink *sink);

    // Close audio sink and release resources
    int (*close)(struct LyraAudioSink *sink);

    // Write raw PCM frames to sink
    // Returns frame count written or negative error code
    int (*write_pcm)(struct LyraAudioSink *sink, const void *pcm_data, uint32_t frame_count);

    // Set output volume (0.0f to 1.0f)
    int (*set_volume)(struct LyraAudioSink *sink, float volume);
} LyraAudioSink;

#ifdef __cplusplus
}
#endif

#endif // LYRA_PLUGIN_API_H
