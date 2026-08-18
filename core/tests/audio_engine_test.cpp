/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "lyra_plugin_api.h"
#include "services/audio_engine.h"
#include "services/audio_sinks/local_audio_sink.h"
#include "services/audio_sinks/null_audio_sink.h"

#include <atomic>
#include <cassert>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <mutex>
#include <random>
#include <thread>
#include <vector>

using namespace lyra;

static void generate_test_wav(const std::string &path, double duration_sec = 2.0, uint32_t sample_rate = 44100) {
    std::ofstream out(path, std::ios::binary);
    uint16_t num_channels = 1;
    uint16_t bits_per_sample = 16;
    uint32_t num_samples = static_cast<uint32_t>(sample_rate * duration_sec);
    uint32_t data_size = num_samples * num_channels * (bits_per_sample / 8);
    uint32_t chunk_size = 36 + data_size;

    out.write("RIFF", 4);
    out.write(reinterpret_cast<const char *>(&chunk_size), 4);
    out.write("WAVE", 4);
    out.write("fmt ", 4);

    uint32_t subchunk1_size = 16;
    uint16_t audio_format = 1; // PCM
    uint32_t byte_rate = sample_rate * num_channels * (bits_per_sample / 8);
    uint16_t block_align = num_channels * (bits_per_sample / 8);

    out.write(reinterpret_cast<const char *>(&subchunk1_size), 4);
    out.write(reinterpret_cast<const char *>(&audio_format), 2);
    out.write(reinterpret_cast<const char *>(&num_channels), 2);
    out.write(reinterpret_cast<const char *>(&sample_rate), 4);
    out.write(reinterpret_cast<const char *>(&byte_rate), 4);
    out.write(reinterpret_cast<const char *>(&block_align), 2);
    out.write(reinterpret_cast<const char *>(&bits_per_sample), 2);
    out.write("data", 4);
    out.write(reinterpret_cast<const char *>(&data_size), 4);

    std::vector<int16_t> pcm(num_samples);
    for (size_t i = 0; i < num_samples; ++i) {
        pcm[i] = static_cast<int16_t>(20000.0 * std::sin(2.0 * 3.1415926535 * 440.0 * i / sample_rate));
    }
    out.write(reinterpret_cast<const char *>(pcm.data()), data_size);
    out.close();
}

// Custom Mock Backpressure Sink to verify frame accounting and backpressure
struct MockBackpressureState {
    std::atomic<uint64_t> total_frames_written{0};
    std::atomic<int> backpressure_countdown{2};
    std::atomic<uint32_t> max_chunk_frames{128};
    std::vector<float> captured_samples;
    std::mutex lock;
    LyraAudioSpec spec{};
};

static int mock_open(LyraAudioSink *sink, const LyraAudioSpec *spec) {
    if (!sink || !sink->user_data || !spec) return -1;
    auto *st = static_cast<MockBackpressureState *>(sink->user_data);
    st->spec = *spec;
    return 0;
}

static int mock_start(LyraAudioSink *sink) {
    (void)sink;
    return 0;
}

static int mock_stop(LyraAudioSink *sink) {
    (void)sink;
    return 0;
}

static int mock_close(LyraAudioSink *sink) {
    (void)sink;
    return 0;
}

static int mock_set_volume(LyraAudioSink *sink, float volume) {
    (void)sink;
    (void)volume;
    return 0;
}

static int mock_write_pcm(LyraAudioSink *sink, const void *pcm_data, uint32_t frame_count) {
    if (!sink || !sink->user_data) return -1;
    auto *st = static_cast<MockBackpressureState *>(sink->user_data);

    // Simulate buffer full on countdown > 0
    int current_cd = st->backpressure_countdown.load();
    if (current_cd > 0) {
        st->backpressure_countdown.fetch_sub(1);
        return 0; // Backpressure: 0 frames written
    }

    st->backpressure_countdown.store(2); // Reset countdown for periodic backpressure
    uint32_t to_write = std::min(frame_count, st->max_chunk_frames.load());
    if (to_write > 0 && pcm_data) {
        const float *src = static_cast<const float *>(pcm_data);
        uint8_t channels = st->spec.channels > 0 ? st->spec.channels : 1;
        std::lock_guard<std::mutex> lk(st->lock);
        st->captured_samples.insert(st->captured_samples.end(), src, src + (to_write * channels));
        st->total_frames_written += to_write;
    }
    return static_cast<int>(to_write);
}

static LyraAudioSink *create_mock_backpressure_sink(MockBackpressureState *state) {
    auto *sink = new LyraAudioSink();
    sink->struct_size = sizeof(LyraAudioSink);
    sink->user_data = state;
    sink->open = mock_open;
    sink->start = mock_start;
    sink->stop = mock_stop;
    sink->close = mock_close;
    sink->write_pcm = mock_write_pcm;
    sink->set_volume = mock_set_volume;
    sink->flush = nullptr;
    sink->get_buffered_frames = nullptr;
    return sink;
}

static void destroy_mock_backpressure_sink(LyraAudioSink *sink) {
    delete sink;
}

int main(int argc, char *argv[]) {
    std::cout << "[AudioEngine Test] Running C++ Audio Engine unit tests...\n";

    std::string base_dir = (argc > 1) ? argv[1] : ".";
    std::string test_wav = base_dir + "/temp_audio_engine_test.wav";
    std::string short_wav = base_dir + "/temp_short_test.wav";
    std::string chaos_wav = base_dir + "/temp_chaos_test.wav";
    std::string backpressure_wav = base_dir + "/temp_backpressure_test.wav";

    // 1. Test NullAudioSink
    {
        LyraAudioSink *null_sink = create_null_audio_sink();
        assert(null_sink != nullptr);
        assert(null_sink->struct_size == sizeof(LyraAudioSink));

        LyraAudioSpec spec{44100, 2, LYRA_AUDIO_FORMAT_F32, 0};
        assert(null_sink->open(null_sink, &spec) == 0);
        assert(null_sink->start(null_sink) == 0);
        assert(null_sink->set_volume(null_sink, 0.8f) == 0);

        float buf[1024] = {0};
        int written = null_sink->write_pcm(null_sink, buf, 512);
        assert(written == 512);
        assert(null_sink->flush != nullptr && null_sink->flush(null_sink) == 0);
        assert(null_sink->get_buffered_frames != nullptr && null_sink->get_buffered_frames(null_sink) == 0);

        assert(null_sink->stop(null_sink) == 0);
        assert(null_sink->close(null_sink) == 0);

        destroy_null_audio_sink(null_sink);
        std::cout << "  ✓ NullAudioSink C-ABI test passed.\n";
    }

    // 2. Test LocalAudioSink creation and safe destruction
    {
        LyraAudioSink *local_sink = create_local_audio_sink();
        assert(local_sink != nullptr);
        assert(local_sink->struct_size == sizeof(LyraAudioSink));
        assert(local_sink->flush != nullptr);
        assert(local_sink->get_buffered_frames != nullptr);
        LyraAudioSpec spec{44100, 2, LYRA_AUDIO_FORMAT_F32, 0};
        int res = local_sink->open(local_sink, &spec);
        (void)res; // res may be 0 or -1 depending on host sound device availability
        destroy_local_audio_sink(local_sink);
        std::cout << "  ✓ LocalAudioSink creation test passed.\n";
    }

    // 3. Test AudioEngine State Machine & File Playback with MockSink
    generate_test_wav(test_wav, 2.0);

    {
        bool event_received = false;
        std::string last_event_name;
        AudioEngine engine;
        MockBackpressureState bp_state;
        engine.set_sink(create_mock_backpressure_sink(&bp_state), destroy_mock_backpressure_sink);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);

        engine.set_event_callback([&](const std::string &evt_str) {
            event_received = true;
            auto j = nlohmann::json::parse(evt_str);
            if (j.contains("event")) {
                last_event_name = j["event"];
            }
        });

        // Play WAV file
        bool play_res = engine.play(test_wav);
        assert(play_res == true);
        assert(event_received == true);

        // Pause
        assert(engine.pause() == true);
        assert(engine.get_state_enum() == AudioEngineState::PAUSED);
        assert(engine.get_state_string() == "PAUSED");

        // Resume
        assert(engine.resume() == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);

        // Seek
        assert(engine.seek(1.0) == true);
        assert(engine.get_position() >= 0.9);

        // Set Volume
        assert(engine.set_volume(0.5f) == true);
        assert(std::abs(engine.get_volume() - 0.5f) < 0.01f);

        // Stop
        assert(engine.stop() == true);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(engine.get_state_string() == "STOPPED");

        engine.set_event_callback(nullptr);
        std::cout << "  ✓ AudioEngine state machine and file playback test passed.\n";
    }

    // 4. Test 1: Replay after EOF / Thread lifecycle
    generate_test_wav(short_wav, 0.2); // ~8820 frames (~0.2 sec)

    {
        std::atomic<bool> ended_event_received{false};
        AudioEngine engine;
        engine.set_sink(create_null_audio_sink(), destroy_null_audio_sink);
        engine.set_event_callback([&](const std::string &evt_str) {
            auto j = nlohmann::json::parse(evt_str);
            if (j.value("event", "") == "audio_ended") {
                ended_event_received = true;
            }
        });

        // Play short stream to EOF
        assert(engine.play(short_wav) == true);

        auto start = std::chrono::steady_clock::now();
        while (engine.get_state_enum() != AudioEngineState::STOPPED) {
            auto now = std::chrono::steady_clock::now();
            if (std::chrono::duration_cast<std::chrono::seconds>(now - start).count() > 3) {
                std::cerr << "Timeout waiting for short stream EOF!\n";
                assert(false);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
        }

        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(ended_event_received.load() == true);

        // Replay immediately after EOF - MUST NOT CRASH with std::terminate
        assert(engine.play(short_wav) == true);

        // Wait for EOF or stop
        auto start2 = std::chrono::steady_clock::now();
        while (engine.get_state_enum() != AudioEngineState::STOPPED) {
            auto now = std::chrono::steady_clock::now();
            if (std::chrono::duration_cast<std::chrono::seconds>(now - start2).count() > 3) {
                std::cerr << "Timeout waiting for short stream EOF replay!\n";
                assert(false);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
        }
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);

        // Rapid replay cycles (play / stop)
        for (int i = 0; i < 5; ++i) {
            assert(engine.play(short_wav) == true);
            assert(engine.stop() == true);
            assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        }

        engine.set_event_callback(nullptr);
        std::cout << "  ✓ Test 1 (Replay after EOF / Thread lifecycle) passed.\n";
    }

    // 5. Test 2: Concurrent Seek, Volume & Position / Decoder Safety
    generate_test_wav(chaos_wav, 3.0); // 3 seconds

    {
        AudioEngine engine;
        engine.set_sink(create_null_audio_sink(), destroy_null_audio_sink);
        assert(engine.play(chaos_wav) == true);

        std::atomic<bool> keep_running{true};
        std::atomic<uint64_t> seek_count{0};
        std::atomic<uint64_t> query_count{0};

        // Thread 1: Rapid Seek
        std::thread seeker([&]() {
            std::mt19937 rng(42);
            std::uniform_real_distribution<double> dist(0.0, 3.0);
            while (keep_running) {
                double target = dist(rng);
                engine.seek(target);
                seek_count++;
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
            }
        });

        // Thread 2: Rapid Getters
        std::thread getter([&]() {
            while (keep_running) {
                double pos = engine.get_position();
                (void)pos;
                double dur = engine.get_duration();
                (void)dur;
                auto j = engine.get_state_json();
                (void)j;
                std::string s = engine.get_state_string();
                (void)s;
                query_count++;
                std::this_thread::sleep_for(std::chrono::microseconds(500));
            }
        });

        // Thread 3: Volume and Pause/Resume changes
        std::thread controller([&]() {
            float v = 0.1f;
            while (keep_running) {
                engine.set_volume(v);
                v += 0.1f;
                if (v > 1.0f) v = 0.1f;
                engine.pause();
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
                engine.resume();
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
            }
        });

        // Thread 4: Concurrent Callback Swapping
        std::thread callback_swapper([&]() {
            int counter = 0;
            while (keep_running) {
                if (counter % 2 == 0) {
                    engine.set_event_callback([&](const std::string &) {});
                } else {
                    engine.set_event_callback(nullptr);
                }
                counter++;
                std::this_thread::sleep_for(std::chrono::milliseconds(3));
            }
        });

        // Run concurrent chaos test for 300ms
        std::this_thread::sleep_for(std::chrono::milliseconds(300));
        keep_running = false;

        seeker.join();
        getter.join();
        controller.join();
        callback_swapper.join();

        assert(engine.stop() == true);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        engine.set_event_callback(nullptr);

        std::cout << "  ✓ Test 2 (Concurrent Seek & Decoder safety: " << seek_count.load()
                  << " seeks, " << query_count.load() << " queries) passed.\n";
    }

    // 6. Test 3: Sink Backpressure & Accurate Frame Accounting
    uint32_t bp_sample_rate = 44100;
    double bp_duration = 0.5; // exactly 22050 frames
    uint64_t expected_total_frames = static_cast<uint64_t>(bp_sample_rate * bp_duration);
    generate_test_wav(backpressure_wav, bp_duration, bp_sample_rate);

    {
        MockBackpressureState bp_state;
        AudioEngine engine;
        LyraAudioSink *mock_sink = create_mock_backpressure_sink(&bp_state);
        engine.set_sink(mock_sink, destroy_mock_backpressure_sink);

        assert(engine.play(backpressure_wav) == true);

        auto start = std::chrono::steady_clock::now();
        while (engine.get_state_enum() != AudioEngineState::STOPPED) {
            auto now = std::chrono::steady_clock::now();
            if (std::chrono::duration_cast<std::chrono::seconds>(now - start).count() > 5) {
                std::cerr << "Timeout waiting for backpressure test completion!\n";
                assert(false);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }

        // Verify accurate frame accounting with backpressure
        assert(bp_state.total_frames_written.load() == expected_total_frames);
        assert(bp_state.captured_samples.size() == expected_total_frames);

        assert(engine.stop() == true);
        engine.set_event_callback(nullptr);

        std::cout << "  ✓ Test 3 (Sink Backpressure & Accurate Frame Accounting: "
                  << bp_state.total_frames_written.load() << " frames written) passed.\n";
    }

    // 7. Test 4: Opus File Playback via AudioEngine
    std::string test_opus = base_dir + "/temp_engine_test.opus";
    {
        std::string cmd = "ffmpeg -y -v error -f lavfi -i 'sine=frequency=440:duration=1.0' -c:a libopus " + test_opus;
        int r = std::system(cmd.c_str());
        assert(r == 0);

        AudioEngine engine;
        engine.set_sink(create_null_audio_sink(), destroy_null_audio_sink);
        assert(engine.play(test_opus) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);
        assert(engine.get_duration() >= 0.9);
        assert(engine.seek(0.5) == true);
        assert(engine.stop() == true);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);

        std::cout << "  ✓ Test 4 (Opus playback via AudioEngine) passed.\n";
    }

    // Clean up temporary test files
    for (const auto &f : {test_wav, short_wav, chaos_wav, backpressure_wav, test_opus}) {
        if (std::filesystem::exists(f)) {
            std::filesystem::remove(f);
        }
    }

    std::cout << "ALL_TESTS_PASSED\n";
    return 0;
}
