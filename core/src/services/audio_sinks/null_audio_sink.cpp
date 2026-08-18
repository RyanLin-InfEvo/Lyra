/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_sinks/null_audio_sink.h"
#include <cstdlib>
#include <cstring>

namespace lyra {

NullAudioSinkImpl::NullAudioSinkImpl() = default;
NullAudioSinkImpl::~NullAudioSinkImpl() = default;

int NullAudioSinkImpl::open(const LyraAudioSpec *spec) {
    if (!spec) return -1;
    m_spec = *spec;
    m_open = true;
    m_written_frames = 0;
    return 0;
}

int NullAudioSinkImpl::start() {
    if (!m_open) return -1;
    m_playing = true;
    return 0;
}

int NullAudioSinkImpl::stop() {
    m_playing = false;
    return 0;
}

int NullAudioSinkImpl::close() {
    m_open = false;
    m_playing = false;
    return 0;
}

int NullAudioSinkImpl::write_pcm(const void *pcm_data, uint32_t frame_count) {
    (void)pcm_data;
    if (!m_open) return -1;
    m_written_frames += frame_count;
    return static_cast<int>(frame_count);
}

int NullAudioSinkImpl::set_volume(float volume) {
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;
    m_volume = volume;
    return 0;
}

namespace {
int null_sink_open(LyraAudioSink *sink, const LyraAudioSpec *spec) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<NullAudioSinkImpl *>(sink->user_data)->open(spec);
}

int null_sink_start(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<NullAudioSinkImpl *>(sink->user_data)->start();
}

int null_sink_stop(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<NullAudioSinkImpl *>(sink->user_data)->stop();
}

int null_sink_close(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<NullAudioSinkImpl *>(sink->user_data)->close();
}

int null_sink_write_pcm(LyraAudioSink *sink, const void *pcm_data, uint32_t frame_count) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<NullAudioSinkImpl *>(sink->user_data)->write_pcm(pcm_data, frame_count);
}

int null_sink_set_volume(LyraAudioSink *sink, float volume) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<NullAudioSinkImpl *>(sink->user_data)->set_volume(volume);
}

int null_sink_flush(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return -1;
    return static_cast<NullAudioSinkImpl *>(sink->user_data)->flush();
}

uint32_t null_sink_get_buffered_frames(LyraAudioSink *sink) {
    if (!sink || !sink->user_data) return 0;
    return static_cast<NullAudioSinkImpl *>(sink->user_data)->get_buffered_frames();
}
} // namespace

LyraAudioSink *create_null_audio_sink() {
    auto *impl = new NullAudioSinkImpl();
    auto *sink = new LyraAudioSink();
    sink->struct_size = sizeof(LyraAudioSink);
    sink->user_data = impl;
    sink->open = null_sink_open;
    sink->start = null_sink_start;
    sink->stop = null_sink_stop;
    sink->close = null_sink_close;
    sink->write_pcm = null_sink_write_pcm;
    sink->set_volume = null_sink_set_volume;
    sink->flush = null_sink_flush;
    sink->get_buffered_frames = null_sink_get_buffered_frames;
    return sink;
}

void destroy_null_audio_sink(LyraAudioSink *sink) {
    if (!sink) return;
    if (sink->user_data) {
        delete static_cast<NullAudioSinkImpl *>(sink->user_data);
        sink->user_data = nullptr;
    }
    delete sink;
}

} // namespace lyra
