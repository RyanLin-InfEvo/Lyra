/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_decoder.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>
}

#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>

namespace lyra {

struct AudioDecoder::Impl {
    AVFormatContext *fmt_ctx{nullptr};
    AVCodecContext *codec_ctx{nullptr};
    SwrContext *swr_ctx{nullptr};
    AVPacket *packet{nullptr};
    AVFrame *frame{nullptr};

    int audio_stream_idx{-1};
    uint32_t sample_rate{0};
    uint8_t channels{0};
    uint64_t total_frames{0};
    double duration{0.0};
    uint64_t current_frame{0};

    bool eof_reached{false};
    std::vector<float> fifo_buffer;
    size_t fifo_read_offset{0};

    ~Impl() {
        cleanup();
    }

    void cleanup() {
        if (frame) {
            av_frame_free(&frame);
            frame = nullptr;
        }
        if (packet) {
            av_packet_free(&packet);
            packet = nullptr;
        }
        if (swr_ctx) {
            swr_free(&swr_ctx);
            swr_ctx = nullptr;
        }
        if (codec_ctx) {
            avcodec_free_context(&codec_ctx);
            codec_ctx = nullptr;
        }
        if (fmt_ctx) {
            avformat_close_input(&fmt_ctx);
            fmt_ctx = nullptr;
        }
        audio_stream_idx = -1;
        sample_rate = 0;
        channels = 0;
        total_frames = 0;
        duration = 0.0;
        current_frame = 0;
        eof_reached = false;
        fifo_buffer.clear();
        fifo_read_offset = 0;
    }
};

AudioDecoder::AudioDecoder() : m_impl(std::make_unique<Impl>()) {}

AudioDecoder::~AudioDecoder() = default;

void AudioDecoder::close() {
    if (m_impl) {
        m_impl->cleanup();
    }
}

bool AudioDecoder::is_open() const {
    return m_impl && m_impl->fmt_ctx != nullptr && m_impl->codec_ctx != nullptr;
}

uint32_t AudioDecoder::get_sample_rate() const {
    return m_impl ? m_impl->sample_rate : 0;
}

uint8_t AudioDecoder::get_channels() const {
    return m_impl ? m_impl->channels : 0;
}

uint64_t AudioDecoder::get_total_frames() const {
    return m_impl ? m_impl->total_frames : 0;
}

double AudioDecoder::get_duration() const {
    return m_impl ? m_impl->duration : 0.0;
}

uint64_t AudioDecoder::get_current_frame() const {
    return m_impl ? m_impl->current_frame : 0;
}

bool AudioDecoder::open(const std::string &filepath, uint32_t target_sample_rate, uint8_t target_channels) {
    close();

    int ret = avformat_open_input(&m_impl->fmt_ctx, filepath.c_str(), nullptr, nullptr);
    if (ret < 0 || !m_impl->fmt_ctx) {
        close();
        return false;
    }

    ret = avformat_find_stream_info(m_impl->fmt_ctx, nullptr);
    if (ret < 0) {
        close();
        return false;
    }

    const AVCodec *codec = nullptr;
    int stream_idx = av_find_best_stream(m_impl->fmt_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0);
    if (stream_idx < 0 || !codec) {
        close();
        return false;
    }

    m_impl->audio_stream_idx = stream_idx;
    AVStream *stream = m_impl->fmt_ctx->streams[stream_idx];

    m_impl->codec_ctx = avcodec_alloc_context3(codec);
    if (!m_impl->codec_ctx) {
        close();
        return false;
    }

    ret = avcodec_parameters_to_context(m_impl->codec_ctx, stream->codecpar);
    if (ret < 0) {
        close();
        return false;
    }

    ret = avcodec_open2(m_impl->codec_ctx, codec, nullptr);
    if (ret < 0) {
        close();
        return false;
    }

    m_impl->packet = av_packet_alloc();
    m_impl->frame = av_frame_alloc();
    if (!m_impl->packet || !m_impl->frame) {
        close();
        return false;
    }

    int src_channels = m_impl->codec_ctx->ch_layout.nb_channels;
    if (src_channels <= 0) src_channels = 2;

    m_impl->channels = (target_channels > 0) ? target_channels : static_cast<uint8_t>(src_channels);
    m_impl->sample_rate = (target_sample_rate > 0) ? target_sample_rate : static_cast<uint32_t>(m_impl->codec_ctx->sample_rate);
    if (m_impl->sample_rate == 0) m_impl->sample_rate = 44100;
    if (m_impl->channels == 0) m_impl->channels = 2;

    if (stream->duration != AV_NOPTS_VALUE && stream->duration > 0) {
        m_impl->duration = static_cast<double>(stream->duration) * av_q2d(stream->time_base);
    } else if (m_impl->fmt_ctx->duration != AV_NOPTS_VALUE && m_impl->fmt_ctx->duration > 0) {
        m_impl->duration = static_cast<double>(m_impl->fmt_ctx->duration) / static_cast<double>(AV_TIME_BASE);
    } else {
        m_impl->duration = 0.0;
    }
    m_impl->total_frames = static_cast<uint64_t>(std::round(m_impl->duration * m_impl->sample_rate));

    AVChannelLayout in_ch_layout{};
    av_channel_layout_copy(&in_ch_layout, &m_impl->codec_ctx->ch_layout);
    if (in_ch_layout.nb_channels <= 0) {
        av_channel_layout_default(&in_ch_layout, src_channels);
    }

    AVChannelLayout out_ch_layout{};
    av_channel_layout_default(&out_ch_layout, m_impl->channels);

    ret = swr_alloc_set_opts2(
        &m_impl->swr_ctx,
        &out_ch_layout,
        AV_SAMPLE_FMT_FLT,
        static_cast<int>(m_impl->sample_rate),
        &in_ch_layout,
        m_impl->codec_ctx->sample_fmt,
        m_impl->codec_ctx->sample_rate,
        0,
        nullptr);

    av_channel_layout_uninit(&in_ch_layout);
    av_channel_layout_uninit(&out_ch_layout);

    if (ret < 0 || !m_impl->swr_ctx || swr_init(m_impl->swr_ctx) < 0) {
        close();
        return false;
    }

    m_impl->current_frame = 0;
    m_impl->eof_reached = false;
    m_impl->fifo_buffer.clear();
    m_impl->fifo_read_offset = 0;

    return true;
}

uint32_t AudioDecoder::read_pcm_frames(float *out_buffer, uint32_t max_frames) {
    if (!is_open() || !out_buffer || max_frames == 0) {
        return 0;
    }

    uint8_t channels = m_impl->channels;

    while (!m_impl->eof_reached) {
        size_t avail_samples = m_impl->fifo_buffer.size() - m_impl->fifo_read_offset;
        if (avail_samples >= static_cast<size_t>(max_frames) * channels) {
            break;
        }

        int ret = av_read_frame(m_impl->fmt_ctx, m_impl->packet);
        if (ret < 0) {
            // End of stream or error - flush decoder
            avcodec_send_packet(m_impl->codec_ctx, nullptr);
            while (true) {
                int r = avcodec_receive_frame(m_impl->codec_ctx, m_impl->frame);
                if (r < 0) break;

                int64_t delay = swr_get_delay(m_impl->swr_ctx, m_impl->codec_ctx->sample_rate);
                int max_out_samples = static_cast<int>(av_rescale_rnd(
                    delay + m_impl->frame->nb_samples,
                    m_impl->sample_rate,
                    m_impl->codec_ctx->sample_rate,
                    AV_ROUND_UP));
                if (max_out_samples < 128) max_out_samples = 128;
                std::vector<float> converted(max_out_samples * channels);
                uint8_t *out_data[1] = {reinterpret_cast<uint8_t *>(converted.data())};

                int out_samples = swr_convert(
                    m_impl->swr_ctx,
                    out_data,
                    max_out_samples,
                    const_cast<const uint8_t **>(m_impl->frame->data),
                    m_impl->frame->nb_samples);

                if (out_samples > 0) {
                    m_impl->fifo_buffer.insert(
                        m_impl->fifo_buffer.end(),
                        converted.begin(),
                        converted.begin() + (out_samples * channels));
                }
                av_frame_unref(m_impl->frame);
            }

            // Flush resampler
            int64_t remaining_delay = swr_get_delay(m_impl->swr_ctx, m_impl->codec_ctx->sample_rate);
            int max_flush_samples = static_cast<int>(av_rescale_rnd(
                remaining_delay,
                m_impl->sample_rate,
                m_impl->codec_ctx->sample_rate,
                AV_ROUND_UP));
            if (max_flush_samples > 0) {
                std::vector<float> converted(max_flush_samples * channels);
                uint8_t *out_data[1] = {reinterpret_cast<uint8_t *>(converted.data())};
                int out_samples = swr_convert(
                    m_impl->swr_ctx,
                    out_data,
                    max_flush_samples,
                    nullptr,
                    0);
                if (out_samples > 0) {
                    m_impl->fifo_buffer.insert(
                        m_impl->fifo_buffer.end(),
                        converted.begin(),
                        converted.begin() + (out_samples * channels));
                }
            }

            m_impl->eof_reached = true;
            break;
        }

        if (m_impl->packet->stream_index == m_impl->audio_stream_idx) {
            int send_ret = avcodec_send_packet(m_impl->codec_ctx, m_impl->packet);
            if (send_ret >= 0) {
                while (true) {
                    int recv_ret = avcodec_receive_frame(m_impl->codec_ctx, m_impl->frame);
                    if (recv_ret == AVERROR(EAGAIN) || recv_ret == AVERROR_EOF) {
                        break;
                    }
                    if (recv_ret < 0) {
                        break;
                    }

                    int64_t delay = swr_get_delay(m_impl->swr_ctx, m_impl->codec_ctx->sample_rate);
                    int max_out_samples = static_cast<int>(av_rescale_rnd(
                        delay + m_impl->frame->nb_samples,
                        m_impl->sample_rate,
                        m_impl->codec_ctx->sample_rate,
                        AV_ROUND_UP));
                    if (max_out_samples < 128) max_out_samples = 128;
                    std::vector<float> converted(max_out_samples * channels);
                    uint8_t *out_data[1] = {reinterpret_cast<uint8_t *>(converted.data())};

                    int out_samples = swr_convert(
                        m_impl->swr_ctx,
                        out_data,
                        max_out_samples,
                        const_cast<const uint8_t **>(m_impl->frame->data),
                        m_impl->frame->nb_samples);

                    if (out_samples > 0) {
                        m_impl->fifo_buffer.insert(
                            m_impl->fifo_buffer.end(),
                            converted.begin(),
                            converted.begin() + (out_samples * channels));
                    }
                    av_frame_unref(m_impl->frame);
                }
            }
        }
        av_packet_unref(m_impl->packet);
    }

    size_t avail_samples = m_impl->fifo_buffer.size() - m_impl->fifo_read_offset;
    uint32_t avail_frames = static_cast<uint32_t>(avail_samples / channels);
    uint32_t to_copy_frames = std::min(max_frames, avail_frames);

    if (to_copy_frames > 0) {
        std::memcpy(
            out_buffer,
            m_impl->fifo_buffer.data() + m_impl->fifo_read_offset,
            to_copy_frames * channels * sizeof(float));
        m_impl->fifo_read_offset += to_copy_frames * channels;
        m_impl->current_frame += to_copy_frames;
    }

    if (m_impl->fifo_read_offset >= m_impl->fifo_buffer.size()) {
        m_impl->fifo_buffer.clear();
        m_impl->fifo_read_offset = 0;
    } else if (m_impl->fifo_read_offset > 16384) {
        m_impl->fifo_buffer.erase(
            m_impl->fifo_buffer.begin(),
            m_impl->fifo_buffer.begin() + m_impl->fifo_read_offset);
        m_impl->fifo_read_offset = 0;
    }

    return to_copy_frames;
}

bool AudioDecoder::seek_seconds(double seconds) {
    if (!is_open() || m_impl->audio_stream_idx < 0) {
        return false;
    }

    if (seconds < 0.0) seconds = 0.0;
    if (m_impl->duration > 0.0 && seconds > m_impl->duration) {
        seconds = m_impl->duration;
    }

    AVStream *stream = m_impl->fmt_ctx->streams[m_impl->audio_stream_idx];
    int64_t ts = static_cast<int64_t>(seconds / av_q2d(stream->time_base));
    if (stream->start_time != AV_NOPTS_VALUE) {
        ts += stream->start_time;
    }

    int ret = av_seek_frame(m_impl->fmt_ctx, m_impl->audio_stream_idx, ts, AVSEEK_FLAG_BACKWARD);
    if (ret < 0) {
        ret = avformat_seek_file(m_impl->fmt_ctx, m_impl->audio_stream_idx, INT64_MIN, ts, ts, 0);
    }
    if (ret < 0) {
        ret = av_seek_frame(m_impl->fmt_ctx, -1, static_cast<int64_t>(seconds * AV_TIME_BASE), AVSEEK_FLAG_BACKWARD);
    }

    avcodec_flush_buffers(m_impl->codec_ctx);
    if (m_impl->packet) av_packet_unref(m_impl->packet);
    if (m_impl->frame) av_frame_unref(m_impl->frame);

    swr_init(m_impl->swr_ctx);

    m_impl->fifo_buffer.clear();
    m_impl->fifo_read_offset = 0;
    m_impl->eof_reached = false;
    m_impl->current_frame = static_cast<uint64_t>(seconds * m_impl->sample_rate);

    return true;
}

bool AudioDecoder::seek_frame(uint64_t target_frame) {
    if (!is_open() || m_impl->sample_rate == 0) return false;
    double seconds = static_cast<double>(target_frame) / static_cast<double>(m_impl->sample_rate);
    return seek_seconds(seconds);
}

} // namespace lyra
