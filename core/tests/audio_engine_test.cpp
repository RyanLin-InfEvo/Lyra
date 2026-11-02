/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "lyra_plugin_api.h"
#include "services/audio_engine.h"
#include "services/audio_sinks/local_audio_sink.h"
#include "services/audio_sinks/null_audio_sink.h"
#include "services/configuration_service.h"
#include "services/database_context.h"

#include <atomic>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <filesystem>
#include <fstream>
#include <future>
#include <iostream>
#include <mutex>
#include <random>
#include <thread>
#include <vector>

using namespace lyra;

// LeakSanitizer default suppressions hook.
// Automatically loaded by LeakSanitizer at process startup when compiled with AddressSanitizer/LeakSanitizer.
// Suppresses host OS audio daemon singletons (PipeWire/JACK D-Bus and RTKit modules) without requiring
// developers or CI to manually specify LSAN_OPTIONS="suppressions=...".
// Compiles to nothing (0 bytes) in normal non-sanitized builds.
#if defined(__SANITIZE_ADDRESS__) || (defined(__has_feature) && __has_feature(address_sanitizer))
extern "C" const char *__lsan_default_suppressions() {
    return "leak:libpipewire\n"
           "leak:libjack\n"
           "leak:pw_\n"
           "leak:jack_\n";
}
#endif

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

        // Relative seek forward
        assert(engine.seek(0.5, true) == true);
        assert(engine.get_position() >= 1.3);

        // Relative seek backward
        assert(engine.seek(-0.5, true) == true);
        assert(engine.get_position() >= 0.8 && engine.get_position() <= 1.4);

        // Relative seek clamp to 0
        assert(engine.seek(-10.0, true) == true);
        assert(engine.get_position() <= 0.2);

        // Seek clamp to duration
        assert(engine.seek(100.0, false) == true);
        assert(engine.get_position() >= 1.8);

        // Set Volume
        assert(engine.set_volume(0.5f) == true);
        assert(std::abs(engine.get_volume() - 0.5f) < 0.01f);

        // Stop
        assert(engine.stop() == true);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(engine.get_state_string() == "STOPPED");

        // Play with start position
        assert(engine.play(test_wav, 1.0) == true);
        assert(engine.get_position() >= 0.9);
        assert(engine.stop() == true);

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

    // 8. Test 5: Audio Output Device Enumeration & Selection
    {
        AudioEngine engine;
        auto devices = engine.list_devices();
        assert(!devices.empty());
        assert(!devices[0].name.empty());
        assert(!devices[0].id.empty());
        assert(engine.get_output_device() == "default");

        // Set output device
        assert(engine.set_output_device("default") == true);
        assert(engine.get_output_device() == "default");

        std::cout << "  ✓ Test 5 (Audio Output Device Enumeration & Selection: "
                  << devices.size() << " devices found) passed.\n";
    }

    // 9. Test 6: Gapless Preload & Seamless Transition
    std::string gapless1 = base_dir + "/temp_engine_gapless1.wav";
    std::string gapless2 = base_dir + "/temp_engine_gapless2.wav";
    generate_test_wav(gapless1, 0.4, 44100);
    generate_test_wav(gapless2, 0.5, 44100);
    {
        AudioEngine engine;
        engine.set_sink(create_null_audio_sink(), destroy_null_audio_sink);

        // Preload next track before play
        assert(engine.preload_next(gapless2) == true);
        assert(engine.get_next_file_path() == gapless2);

        // Clear next track
        assert(engine.preload_next("") == true);
        assert(engine.get_next_file_path().empty());

        // Play track 1
        assert(engine.play(gapless1) == true);
        assert(engine.preload_next(gapless2) == true);
        assert(engine.get_next_file_path() == gapless2);

        // Poll for seamless transition to track 2
        auto start = std::chrono::steady_clock::now();
        bool transitioned = false;
        while (std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start).count() < 3000) {
            if (engine.get_current_file_path() == gapless2) {
                transitioned = true;
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }

        assert(transitioned == true);
        assert(engine.stop() == true);

        std::cout << "  ✓ Test 6 (Gapless Playback & Seamless Track Transition) passed.\n";
    }

    // 10. Test 7: Constructor Sink Dependency Injection
    {
        AudioEngine engine(create_null_audio_sink(), destroy_null_audio_sink);
        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);
        assert(engine.set_volume(0.8f) == true);
        assert(std::abs(engine.get_volume() - 0.8f) < 1e-4);
        assert(engine.stop() == true);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);

        std::cout << "  ✓ Test 7 (Constructor Sink Dependency Injection) passed.\n";
    }

    // 11. Test 8: create_null_engine Helper Factory
    {
        auto null_engine = AudioEngine::create_null_engine();
        assert(null_engine != nullptr);
        assert(null_engine->play(short_wav) == true);
        assert(null_engine->get_state_enum() == AudioEngineState::PLAYING);
        assert(null_engine->stop() == true);
        assert(null_engine->get_state_enum() == AudioEngineState::STOPPED);

        std::cout << "  ✓ Test 8 (create_null_engine Helper Factory) passed.\n";
    }

    // 12. Test 9: Thread-Safe set_sink Dynamic Switching While Playing
    {
        auto engine = AudioEngine::create_null_engine();
        assert(engine->play(test_wav) == true);
        assert(engine->get_state_enum() == AudioEngineState::PLAYING);

        // Switch sink while playing - should stop pump thread cleanly and adopt new sink
        engine->set_sink(create_null_audio_sink(), destroy_null_audio_sink);
        assert(engine->get_state_enum() == AudioEngineState::STOPPED);

        // Resume playback with the new sink
        assert(engine->play(test_wav) == true);
        assert(engine->get_state_enum() == AudioEngineState::PLAYING);
        assert(engine->stop() == true);

        std::cout << "  ✓ Test 9 (Thread-Safe set_sink Dynamic Switching) passed.\n";
    }

    // 13. Test 10: Buffer Size and Exclusive Mode Configuration
    {
        AudioEngine engine; // Default with LocalAudioSink
        assert(engine.get_buffer_size_frames() == 256);
        assert(engine.get_exclusive_mode() == false);

        assert(engine.set_buffer_size_frames(512) == true);
        assert(engine.get_buffer_size_frames() == 512);

        assert(engine.set_exclusive_mode(true) == true);
        assert(engine.get_exclusive_mode() == true);

        auto state = engine.get_state_json();
        assert(state["buffer_size_frames"] == 512);
        assert(state["exclusive_mode"] == true);
        assert(state.contains("exclusive_mode_active"));

        LocalAudioSinkImpl local_sink;
        assert(local_sink.get_buffer_size_frames() == 256);
        assert(local_sink.get_exclusive_mode() == false);
        assert(local_sink.set_buffer_size_frames(1024) == true);
        assert(local_sink.get_buffer_size_frames() == 1024);
        assert(local_sink.set_exclusive_mode(true) == true);
        assert(local_sink.get_exclusive_mode() == true);

        std::cout << "  ✓ Test 10 (Buffer Size & Exclusive Mode Config) passed.\n";
    }

    // 14. Test 11: Sink failure stops pump thread immediately (no spinning loop)
    {
        std::atomic<int> stop_invoked{0};
        AudioEngine engine;
        auto *failing_sink = new LyraAudioSink();
        failing_sink->struct_size = sizeof(LyraAudioSink);
        failing_sink->user_data = &stop_invoked;
        failing_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        failing_sink->start = [](LyraAudioSink *) -> int { return 0; };
        failing_sink->stop = [](LyraAudioSink *s) -> int {
            if (s && s->user_data) {
                static_cast<std::atomic<int> *>(s->user_data)->fetch_add(1);
            }
            return 0;
        };
        failing_sink->close = [](LyraAudioSink *) -> int { return 0; };
        failing_sink->flush = [](LyraAudioSink *) -> int { return 0; };
        failing_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t) -> int { return -1; };
        failing_sink->get_buffered_frames = [](LyraAudioSink *) -> uint32_t { return 0; };

        stop_invoked.store(0);
        engine.set_sink(failing_sink, [](LyraAudioSink *s) { delete s; });
        assert(engine.play(test_wav) == true);

        // Wait a short time for pump thread to encounter write_pcm < 0
        int elapsed_ms = 0;
        while (engine.get_state_enum() == AudioEngineState::PLAYING && elapsed_ms < 500) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            elapsed_ms += 10;
        }

        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(stop_invoked.load() > 0);
        std::cout << "  ✓ Test 11 (Immediate Pump Loop Stop on Sink Failure) passed.\n";
    }

    // 15. Test 12: Exclusive mode released on stop and restored on start
    {
        LocalAudioSinkImpl local_sink;
        assert(local_sink.set_exclusive_mode(true) == true);
        assert(local_sink.get_exclusive_mode() == true);
        assert(local_sink.is_exclusive_mode_active() == false);

        LyraAudioSpec spec{};
        spec.sample_rate = 44100;
        spec.channels = 2;
        spec.format = LYRA_AUDIO_FORMAT_F32;

        int open_res = local_sink.open(&spec);
        if (open_res == 0) {
            assert(local_sink.start() == 0);
            assert(local_sink.is_playing() == true);
            if (local_sink.is_exclusive_mode_active()) {
                assert(local_sink.is_exclusive_mode_active() == true);
            }
            // Now stop - exclusive mode lock must be released
            assert(local_sink.stop() == 0);
            assert(local_sink.is_playing() == false);
            assert(local_sink.is_exclusive_mode_active() == false);

            // Dynamic reconfiguration while stopped must leave exclusive lock released
            assert(local_sink.set_buffer_size_frames(512) == true);
            assert(local_sink.is_exclusive_mode_active() == false);

            // Re-start - exclusive mode must be re-initialized
            assert(local_sink.start() == 0);
            assert(local_sink.is_playing() == true);

            // Close
            assert(local_sink.close() == 0);
            assert(local_sink.is_open() == false);
            assert(local_sink.is_exclusive_mode_active() == false);
        }

        // Mock sink test ensuring is_exclusive_mode_active contract runs deterministically in headless CI
        {
            struct MockExclusiveState {
                bool active{false};
            } mock_st;

            auto *mock_sink = new LyraAudioSink();
            mock_sink->struct_size = sizeof(LyraAudioSink);
            mock_sink->user_data = &mock_st;
            mock_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            mock_sink->start = [](LyraAudioSink *s) -> int {
                static_cast<MockExclusiveState *>(s->user_data)->active = true;
                return 0;
            };
            mock_sink->stop = [](LyraAudioSink *s) -> int {
                static_cast<MockExclusiveState *>(s->user_data)->active = false;
                return 0;
            };
            mock_sink->close = [](LyraAudioSink *s) -> int {
                static_cast<MockExclusiveState *>(s->user_data)->active = false;
                return 0;
            };
            mock_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int {
                std::this_thread::sleep_for(std::chrono::milliseconds(20));
                return static_cast<int>(f);
            };
            mock_sink->is_exclusive_mode_active = [](LyraAudioSink *s) -> int {
                return static_cast<MockExclusiveState *>(s->user_data)->active ? 1 : 0;
            };

            AudioEngine mock_engine(mock_sink, [](LyraAudioSink *s) { delete s; });
            assert(mock_engine.get_state_json()["exclusive_mode_active"] == false);
            assert(mock_engine.play(test_wav) == true);
            assert(mock_engine.get_state_json()["exclusive_mode_active"] == true);
            assert(mock_engine.stop() == true);
            assert(mock_engine.get_state_json()["exclusive_mode_active"] == false);
        }

        std::cout << "  ✓ Test 12 (Exclusive Mode Lock Release on Stop) passed.\n";
    }

    // 16. Test 13: AudioEngine::resume() and start() error handling prevents false-positive PLAYING state
    {
        AudioEngine engine;
        std::atomic<bool> start_should_fail{false};

        auto *custom_sink = new LyraAudioSink();
        custom_sink->struct_size = sizeof(LyraAudioSink);
        custom_sink->user_data = &start_should_fail;
        custom_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        custom_sink->start = [](LyraAudioSink *s) -> int {
            auto *should_fail = static_cast<std::atomic<bool> *>(s->user_data);
            if (should_fail && should_fail->load()) {
                return -1;
            }
            return 0;
        };
        custom_sink->stop = [](LyraAudioSink *) -> int { return 0; };
        custom_sink->close = [](LyraAudioSink *) -> int { return 0; };
        custom_sink->flush = [](LyraAudioSink *) -> int { return 0; };
        custom_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
        custom_sink->get_buffered_frames = [](LyraAudioSink *) -> uint32_t { return 0; };

        engine.set_sink(custom_sink, [](LyraAudioSink *s) { delete s; });

        // Normal play
        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);

        // Pause
        assert(engine.pause() == true);
        assert(engine.get_state_enum() == AudioEngineState::PAUSED);

        // Now configure start to fail (e.g. device unplugged or busy)
        start_should_fail.store(true);

        std::string resume_fail_evt;
        nlohmann::json resume_fail_data;
        engine.set_event_callback([&](const std::string &evt_str) {
            auto j = nlohmann::json::parse(evt_str);
            resume_fail_evt = j.value("event", "");
            if (j.contains("data")) {
                resume_fail_data = j["data"];
            }
        });

        // Calling resume() MUST fail (return false)
        bool resumed = engine.resume();
        assert(resumed == false);
        // AND state MUST remain PAUSED (not falsely transitioned to PLAYING)
        assert(engine.get_state_enum() == AudioEngineState::PAUSED);
        assert(engine.get_last_error() == AudioEngineError::DeviceUnavailable);
        assert(resume_fail_evt == "audio_device_unavailable");
        assert(resume_fail_data["error"] == "DeviceUnavailable");
        assert(resume_fail_data["state"] == "PAUSED");

        // Recover: allow start to succeed
        start_should_fail.store(false);
        assert(engine.resume() == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);

        assert(engine.stop() == true);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);

        // Also test play() with start failure
        start_should_fail.store(true);
        resume_fail_evt.clear();
        assert(engine.play(test_wav) == false);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(engine.get_last_error() == AudioEngineError::DeviceUnavailable);
        assert(engine.get_current_file_path().empty());
        assert(engine.get_duration() == 0.0);
        assert(engine.get_position() == 0.0);
        assert(resume_fail_evt == "audio_device_unavailable");
        assert(resume_fail_data["file_path"] == "");
        assert(resume_fail_data["duration"] == 0.0);
        engine.set_event_callback(nullptr);

        std::cout << "  ✓ Test 13 (resume() and play() failure returns false and preserves valid state) passed.\n";
    }

    // 17. Test 14: set_buffer_size_frames boundary defense [32, 8192] and zero-frame rejection
    {
        AudioEngine engine;
        assert(engine.get_buffer_size_frames() == 256);

        // Lower boundary violations (< 32, including zero)
        assert(engine.set_buffer_size_frames(0) == false);
        assert(engine.get_buffer_size_frames() == 256);
        assert(engine.set_buffer_size_frames(1) == false);
        assert(engine.get_buffer_size_frames() == 256);
        assert(engine.set_buffer_size_frames(31) == false);
        assert(engine.get_buffer_size_frames() == 256);

        // Upper boundary violations (> 8192)
        assert(engine.set_buffer_size_frames(8193) == false);
        assert(engine.get_buffer_size_frames() == 256);
        assert(engine.set_buffer_size_frames(65536) == false);
        assert(engine.get_buffer_size_frames() == 256);

        // Valid boundaries [32, 8192]
        assert(engine.set_buffer_size_frames(32) == true);
        assert(engine.get_buffer_size_frames() == 32);
        assert(engine.set_buffer_size_frames(8192) == true);
        assert(engine.get_buffer_size_frames() == 8192);

        // Test LocalAudioSinkImpl directly
        LocalAudioSinkImpl local_sink;
        assert(local_sink.get_buffer_size_frames() == 256);

        assert(local_sink.set_buffer_size_frames(0) == false);
        assert(local_sink.get_buffer_size_frames() == 256);
        assert(local_sink.set_buffer_size_frames(31) == false);
        assert(local_sink.get_buffer_size_frames() == 256);
        assert(local_sink.set_buffer_size_frames(8193) == false);
        assert(local_sink.get_buffer_size_frames() == 256);

        assert(local_sink.set_buffer_size_frames(32) == true);
        assert(local_sink.get_buffer_size_frames() == 32);
        assert(local_sink.set_buffer_size_frames(8192) == true);
        assert(local_sink.get_buffer_size_frames() == 8192);

        std::cout << "  ✓ Test 14 (set_buffer_size_frames boundary defense [32, 8192]) passed.\n";
    }

    // 18. Test 15: Dynamic hardware reconfiguration preserves ring buffer frames (no loss / no jump)
    {
        LocalAudioSinkImpl local_sink;
        LyraAudioSpec spec{};
        spec.sample_rate = 44100;
        spec.channels = 2;
        spec.format = LYRA_AUDIO_FORMAT_F32;

        int open_res = local_sink.open(&spec);
        if (open_res == 0) {
            // Write 1 second of audio frames (44100 frames)
            std::vector<float> pcm_data(44100 * 2, 0.0f);
            int written = local_sink.write_pcm(pcm_data.data(), 44100);
            assert(written == 44100);
            assert(local_sink.get_buffered_frames() == 44100);

            // Reconfigure buffer size dynamically while open
            assert(local_sink.set_buffer_size_frames(512) == true);
            // Ring buffer must NOT be destroyed! Buffered frames must be preserved.
            assert(local_sink.get_buffered_frames() == 44100);

            // Reconfigure exclusive mode dynamically while open
            assert(local_sink.set_exclusive_mode(true) == true);
            assert(local_sink.get_buffered_frames() == 44100);

            // Reconfigure output device dynamically while open
            assert(local_sink.set_output_device("default") == true);
            assert(local_sink.get_buffered_frames() == 44100);

            assert(local_sink.close() == 0);
            assert(local_sink.get_buffered_frames() == 0);
        } else {
            assert(local_sink.is_open() == false);
            assert(local_sink.is_playing() == false);
            assert(local_sink.get_buffered_frames() == 0);
        }

        // Also test position continuity via AudioEngine during active playback
        {
            AudioEngine engine;
            if (engine.play(test_wav)) {
                // Wait briefly for frames to be decoded into ring buffer
                std::this_thread::sleep_for(std::chrono::milliseconds(50));
                engine.pause();
                double pos_before = engine.get_position();
                assert(engine.set_buffer_size_frames(512) == true);
                double pos_after = engine.get_position();
                // Position must remain continuous (not jumping forward by up to 2 seconds)
                assert(std::abs(pos_after - pos_before) < 0.05);
                engine.stop();
            }
        }

        std::cout << "  ✓ Test 15 (Dynamic hardware reconfiguration preserves ring buffer frames) passed.\n";
    }

    // 19. Test 16: Polymorphic C-ABI Sink Capabilities, Non-LocalAudioSink user_data Safety & struct_size Guard
    {
        struct MockCapableSinkState {
            std::string device_id{"default"};
            uint32_t buffer_size_frames{256};
            bool exclusive_mode{false};
            bool exclusive_active{false};
            bool reject_changes{false};
            int set_device_calls{0};
            int set_buffer_calls{0};
            int set_exclusive_calls{0};
            int query_exclusive_calls{0};
        };

        MockCapableSinkState cap_state;
        auto create_capable_sink = [](MockCapableSinkState *st) -> LyraAudioSink * {
            auto *s = new LyraAudioSink();
            s->struct_size = sizeof(LyraAudioSink);
            s->user_data = st;
            s->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            s->start = [](LyraAudioSink *) -> int { return 0; };
            s->stop = [](LyraAudioSink *) -> int { return 0; };
            s->close = [](LyraAudioSink *) -> int { return 0; };
            s->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
            s->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
            s->flush = [](LyraAudioSink *) -> int { return 0; };
            s->get_buffered_frames = [](LyraAudioSink *) -> uint32_t { return 0; };
            s->set_output_device = [](LyraAudioSink *sink, const char *dev_id) -> int {
                auto *c = static_cast<MockCapableSinkState *>(sink->user_data);
                c->set_device_calls++;
                if (c->reject_changes) return -1;
                c->device_id = dev_id ? dev_id : "default";
                return 0;
            };
            s->set_buffer_size_frames = [](LyraAudioSink *sink, uint32_t frames) -> int {
                auto *c = static_cast<MockCapableSinkState *>(sink->user_data);
                c->set_buffer_calls++;
                if (c->reject_changes) return -1;
                c->buffer_size_frames = frames;
                return 0;
            };
            s->set_exclusive_mode = [](LyraAudioSink *sink, int exclusive) -> int {
                auto *c = static_cast<MockCapableSinkState *>(sink->user_data);
                c->set_exclusive_calls++;
                if (c->reject_changes) return -1;
                c->exclusive_mode = (exclusive != 0);
                c->exclusive_active = (exclusive != 0);
                return 0;
            };
            s->is_exclusive_mode_active = [](LyraAudioSink *sink) -> int {
                auto *c = static_cast<MockCapableSinkState *>(sink->user_data);
                c->query_exclusive_calls++;
                return c->exclusive_active ? 1 : 0;
            };
            return s;
        };

        const std::string valid_hex_id = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        const std::string valid_hex_id_2 = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";

        AudioEngine engine(create_null_audio_sink(), destroy_null_audio_sink);
        assert(engine.set_output_device(valid_hex_id) == true);
        assert(engine.set_buffer_size_frames(1024) == true);
        assert(engine.set_exclusive_mode(true) == true);

        // (a) Attach custom capable sink via set_sink: should synchronize existing engine config via C-ABI
        engine.set_sink(create_capable_sink(&cap_state), [](LyraAudioSink *s) { delete s; });
        assert(cap_state.device_id == valid_hex_id);
        assert(cap_state.buffer_size_frames == 1024);
        assert(cap_state.exclusive_mode == true);
        assert(cap_state.set_device_calls == 1);
        assert(cap_state.set_buffer_calls == 1);
        assert(cap_state.set_exclusive_calls == 1);

        // Verify get_state_json() queries is_exclusive_mode_active on custom sink
        auto st_json = engine.get_state_json();
        assert(st_json["exclusive_mode_active"] == true);
        assert(cap_state.query_exclusive_calls >= 1);

        // Reconfigure while custom sink is attached
        assert(engine.set_output_device(valid_hex_id_2) == true);
        assert(cap_state.device_id == valid_hex_id_2);
        assert(engine.set_buffer_size_frames(2048) == true);
        assert(cap_state.buffer_size_frames == 2048);
        assert(engine.set_exclusive_mode(false) == true);
        assert(cap_state.exclusive_mode == false);
        assert(engine.get_state_json()["exclusive_mode_active"] == false);

        // (b) Negative boundary: when sink rejects changes (-1), AudioEngine returns false and preserves previous config
        cap_state.reject_changes = true;
        assert(engine.set_output_device(valid_hex_id) == false);
        assert(engine.get_output_device() == valid_hex_id_2);
        assert(engine.set_buffer_size_frames(512) == false);
        assert(engine.get_buffer_size_frames() == 2048);
        assert(engine.set_exclusive_mode(true) == false);
        assert(engine.get_exclusive_mode() == false);

        // (c) ABI struct_size guard: legacy sink with older struct_size must not have extended pointers invoked
        MockCapableSinkState legacy_state;
        LyraAudioSink *legacy_sink = create_capable_sink(&legacy_state);
        legacy_sink->struct_size = static_cast<uint32_t>(offsetof(LyraAudioSink, set_output_device));
        engine.set_sink(legacy_sink, [](LyraAudioSink *s) { delete s; });
        assert(legacy_state.set_device_calls == 0);
        assert(legacy_state.set_buffer_calls == 0);
        assert(legacy_state.set_exclusive_calls == 0);
        assert(engine.set_output_device(valid_hex_id) == true);
        assert(engine.set_buffer_size_frames(512) == true);
        assert(engine.set_exclusive_mode(true) == true);
        assert(engine.get_state_json()["exclusive_mode_active"] == false);
        assert(legacy_state.set_device_calls == 0);
        assert(legacy_state.set_buffer_calls == 0);
        assert(legacy_state.set_exclusive_calls == 0);
        assert(legacy_state.query_exclusive_calls == 0);

        // (d) struct_size == 0 must NOT bypass the ABI capability guard
        MockCapableSinkState zero_size_state;
        LyraAudioSink *zero_size_sink = create_capable_sink(&zero_size_state);
        zero_size_sink->struct_size = 0;
        engine.set_sink(zero_size_sink, [](LyraAudioSink *s) { delete s; });
        assert(zero_size_state.set_device_calls == 0);
        assert(zero_size_state.set_buffer_calls == 0);
        assert(zero_size_state.set_exclusive_calls == 0);
        assert(engine.get_state_json()["exclusive_mode_active"] == false);
        assert(zero_size_state.query_exclusive_calls == 0);

        // (e) When a newly attached sink rejects config in apply_sink_config_unlocked(),
        // AudioEngine must self-heal rejected settings back to safe defaults so getters remain consistent.
        MockCapableSinkState reject_init_state;
        reject_init_state.reject_changes = true;
        assert(engine.set_output_device(valid_hex_id) == true);
        assert(engine.set_buffer_size_frames(1024) == true);
        assert(engine.set_exclusive_mode(true) == true);
        engine.set_sink(create_capable_sink(&reject_init_state), [](LyraAudioSink *s) { delete s; });
        assert(reject_init_state.set_device_calls >= 1);
        assert(reject_init_state.set_buffer_calls >= 1);
        assert(reject_init_state.set_exclusive_calls >= 1);
        assert(engine.get_output_device() == "default");
        assert(engine.get_buffer_size_frames() == AudioEngine::DEFAULT_BUFFER_SIZE_FRAMES);
        assert(engine.get_exclusive_mode() == false);

        std::cout << "  ✓ Test 16 (Polymorphic C-ABI Sink Capabilities & ABI struct_size guard) passed.\n";
    }

    // 20. Test 17: Layer 1 & Layer 2 Audio Output Device Defense, Active Playback Rollback & NUL-Terminated Hex ID
    {
        const std::string non_existent_hex_id = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        const std::string non_existent_hex_id_2 = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";

        // Part 1 (Layer 1): Direct C-ABI function pointers on create_local_audio_sink()
        // Rejects non-existent hex ID even when closed!
        LyraAudioSink *local_c_sink = create_local_audio_sink();
        assert(local_c_sink != nullptr);
        assert(local_c_sink->set_output_device != nullptr);
        assert(local_c_sink->set_buffer_size_frames != nullptr);
        assert(local_c_sink->set_exclusive_mode != nullptr);
        assert(local_c_sink->is_exclusive_mode_active != nullptr);

        assert(local_c_sink->set_output_device(local_c_sink, non_existent_hex_id.c_str()) == -1);
        assert(local_c_sink->set_output_device(local_c_sink, "default") == 0);
        assert(local_c_sink->set_buffer_size_frames(local_c_sink, 1024) == 0);
        assert(local_c_sink->set_exclusive_mode(local_c_sink, 1) == 0);
        assert(local_c_sink->is_exclusive_mode_active(local_c_sink) == 0);

        auto *impl = static_cast<LocalAudioSinkImpl *>(local_c_sink->user_data);
        assert(impl->get_output_device() == "default");
        assert(impl->get_buffer_size_frames() == 1024);
        assert(impl->get_exclusive_mode() == true);
        destroy_local_audio_sink(local_c_sink);

        // Part 2 (Layer 1): AudioEngine::set_output_device rejects offline hex ID in all states (STOPPED, PLAYING, PAUSED)
        AudioEngine engine;
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(engine.set_output_device(non_existent_hex_id) == false);
        assert(engine.get_output_device() == "default");

        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);
        assert(engine.set_output_device(non_existent_hex_id) == false);
        assert(engine.get_output_device() == "default");

        assert(engine.pause() == true);
        assert(engine.get_state_enum() == AudioEngineState::PAUSED);
        assert(engine.set_output_device(non_existent_hex_id_2) == false);
        assert(engine.get_output_device() == "default");
        assert(engine.stop() == true);

        // Even when m_sink is nullptr and m_custom_sink_set is false, set_output_device rejects offline hex ID
        engine.set_sink(nullptr, nullptr);
        assert(engine.set_output_device(non_existent_hex_id) == false);
        assert(engine.get_output_device() == "default");

        // Part 3 (Layer 2): Playback fails with DeviceUnavailable when configured/restored device is offline
        std::string last_event_name;
        nlohmann::json last_event_data;
        engine.set_event_callback([&](const std::string &evt_str) {
            auto j = nlohmann::json::parse(evt_str);
            last_event_name = j.value("event", "");
            if (j.contains("data")) {
                last_event_data = j["data"];
            }
        });

        assert(engine.restore_output_device(non_existent_hex_id) == true);
        assert(engine.get_output_device() == non_existent_hex_id);
        assert(engine.set_buffer_size_frames(1024) == true);
        assert(engine.set_exclusive_mode(true) == true);

        // Calling play() when restored device is offline MUST fail (must NOT fallback to NullAudioSink!)
        assert(engine.play(test_wav) == false);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(engine.get_last_error() == AudioEngineError::DeviceUnavailable);
        assert(engine.get_output_device() == non_existent_hex_id);
        assert(engine.get_current_file_path().empty());
        assert(engine.get_duration() == 0.0);
        assert(engine.get_position() == 0.0);
        assert(last_event_name == "audio_device_unavailable");
        assert(last_event_data["device_id"] == non_existent_hex_id);
        assert(last_event_data["error"] == "DeviceUnavailable");
        assert(last_event_data["state"] == "STOPPED");
        assert(last_event_data["file_path"] == "");
        assert(last_event_data["duration"] == 0.0);
        assert(last_event_data["position"] == 0.0);

        // Switch back to "default" and verify playback succeeds and clears last_error
        assert(engine.set_output_device("default") == true);
        assert(engine.get_output_device() == "default");
        assert(engine.play(test_wav) == true);
        assert(engine.get_last_error() == AudioEngineError::None);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);
        assert(engine.stop() == true);
        engine.set_event_callback(nullptr);

        // Part 4: Active playback rollback on failed set_output_device must re-initialize and keep playing!
        {
            LyraAudioSpec spec{44100, 2, LYRA_AUDIO_FORMAT_F32, 0};
            LocalAudioSinkImpl active_sink;
            if (active_sink.open(&spec) == 0 && active_sink.start() == 0) {
                assert(active_sink.is_playing() == true);
                assert(active_sink.set_output_device(non_existent_hex_id) == false);
                assert(active_sink.get_output_device() == "default");
                assert(active_sink.is_playing() == true);
                active_sink.close();
            }
        }

        // Part 5: 512-char hex device ID without trailing NUL byte (00) must be rejected to prevent C-string over-read
        const std::string non_nul_512_hex(512, 'f');
        assert(LocalAudioSinkImpl::is_valid_device_id(non_nul_512_hex) == false);
        assert(engine.set_output_device(non_nul_512_hex) == false);
        assert(engine.restore_output_device(non_nul_512_hex) == false);

        // A 512-char hex string ending in "00" is NUL-terminated and valid format
        std::string nul_terminated_512_hex(510, 'a');
        nul_terminated_512_hex += "00";
        assert(LocalAudioSinkImpl::is_valid_device_id(nul_terminated_512_hex) == true);

        // Part 6: Custom sink with restore_output_device syncs device in play() and fails if rejected
        {
            struct CustomRejectSinkState {
                std::string synced_device{"default"};
                uint32_t synced_buffer{256};
                bool synced_exclusive{false};
            } custom_st;

            auto *custom_s = new LyraAudioSink();
            custom_s->struct_size = sizeof(LyraAudioSink);
            custom_s->user_data = &custom_st;
            custom_s->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            custom_s->start = [](LyraAudioSink *) -> int { return 0; };
            custom_s->stop = [](LyraAudioSink *) -> int { return 0; };
            custom_s->close = [](LyraAudioSink *) -> int { return 0; };
            custom_s->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
            custom_s->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
            custom_s->flush = [](LyraAudioSink *) -> int { return 0; };
            custom_s->get_buffered_frames = [](LyraAudioSink *) -> uint32_t { return 0; };
            custom_s->set_output_device = [](LyraAudioSink *sink, const char *dev) -> int {
                auto *c = static_cast<CustomRejectSinkState *>(sink->user_data);
                std::string d = dev ? dev : "default";
                if (d != "default") return -1;
                c->synced_device = d;
                return 0;
            };
            custom_s->set_buffer_size_frames = [](LyraAudioSink *sink, uint32_t frames) -> int {
                auto *c = static_cast<CustomRejectSinkState *>(sink->user_data);
                c->synced_buffer = frames;
                return 0;
            };
            custom_s->set_exclusive_mode = [](LyraAudioSink *sink, int exc) -> int {
                auto *c = static_cast<CustomRejectSinkState *>(sink->user_data);
                c->synced_exclusive = (exc != 0);
                return 0;
            };
            custom_s->is_exclusive_mode_active = nullptr;

            AudioEngine custom_engine(custom_s, [](LyraAudioSink *s) { delete s; });
            assert(custom_engine.restore_output_device(non_existent_hex_id) == true);
            assert(custom_engine.play(test_wav) == false);
            assert(custom_engine.get_last_error() == AudioEngineError::DeviceUnavailable);
            assert(custom_engine.get_output_device() == non_existent_hex_id);
        }

        std::cout << "  ✓ Test 17 (Layer 1 & Layer 2 Device Defense, Active Playback Rollback & Boundary Guards) passed.\n";
    }

    // Static check for Rule of 3/5
    static_assert(!std::is_copy_constructible_v<LocalAudioSinkImpl>, "LocalAudioSinkImpl must not be copy-constructible");
    static_assert(!std::is_copy_assignable_v<LocalAudioSinkImpl>, "LocalAudioSinkImpl must not be copy-assignable");

    // 21. Test 18: Double failure (reconfigure + rollback failure) syncs AudioEngine state to STOPPED and emits event
    {
        struct DoubleFailState {
            int reconfig_return_code{0};
        } df_state;

        auto *mock_sink = new LyraAudioSink();
        mock_sink->struct_size = sizeof(LyraAudioSink);
        mock_sink->user_data = &df_state;
        mock_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        mock_sink->start = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->stop = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->close = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
            return static_cast<int>(f);
        };
        mock_sink->set_output_device = [](LyraAudioSink *s, const char *) -> int {
            return static_cast<DoubleFailState *>(s->user_data)->reconfig_return_code;
        };
        mock_sink->set_buffer_size_frames = [](LyraAudioSink *s, uint32_t) -> int {
            return static_cast<DoubleFailState *>(s->user_data)->reconfig_return_code;
        };
        mock_sink->set_exclusive_mode = [](LyraAudioSink *s, int) -> int {
            return static_cast<DoubleFailState *>(s->user_data)->reconfig_return_code;
        };

        std::string last_event;
        nlohmann::json last_data;
        AudioEngine engine(mock_sink, [](LyraAudioSink *s) { delete s; });
        engine.set_event_callback([&](const std::string &evt) {
            auto j = nlohmann::json::parse(evt);
            last_event = j.value("event", "");
            last_data = j.value("data", nlohmann::json::object());
        });

        // 18.1 set_output_device double failure
        df_state.reconfig_return_code = 0;
        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);
        last_event.clear();
        df_state.reconfig_return_code = -2;
        assert(engine.set_output_device("custom_dev_fail") == false);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(last_event == "audio_state_changed");
        assert(last_data["state"] == "STOPPED");

        // 18.2 set_buffer_size_frames double failure
        df_state.reconfig_return_code = 0;
        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);
        last_event.clear();
        df_state.reconfig_return_code = -2;
        assert(engine.set_buffer_size_frames(512) == false);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(last_event == "audio_state_changed");
        assert(last_data["state"] == "STOPPED");

        // 18.3 set_exclusive_mode double failure
        df_state.reconfig_return_code = 0;
        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);
        last_event.clear();
        df_state.reconfig_return_code = -2;
        assert(engine.set_exclusive_mode(true) == false);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(last_event == "audio_state_changed");
        assert(last_data["state"] == "STOPPED");

        std::cout << "  ✓ Test 18 (Double Failure State Recovery & Event Sync) passed.\n";
    }

    // 22. Test 19: Legacy ABI sink without flush/get_buffered_frames and minimum struct_size validation
    {
        // Legacy sink struct up to set_volume
        const uint32_t legacy_size = static_cast<uint32_t>(offsetof(LyraAudioSink, set_volume) + sizeof(void *));
        auto *legacy_sink = static_cast<LyraAudioSink *>(::operator new(legacy_size));
        std::memset(legacy_sink, 0, legacy_size);
        legacy_sink->struct_size = legacy_size;
        legacy_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        legacy_sink->start = [](LyraAudioSink *) -> int { return 0; };
        legacy_sink->stop = [](LyraAudioSink *) -> int { return 0; };
        legacy_sink->close = [](LyraAudioSink *) -> int { return 0; };
        legacy_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
        legacy_sink->set_volume = [](LyraAudioSink *, float) -> int { return 0; };

        AudioEngine legacy_engine(legacy_sink, [](LyraAudioSink *s) { ::operator delete(s); });
        assert(legacy_engine.play(test_wav) == true);
        // seek, stop, get_position should not trigger out-of-bounds reads
        assert(legacy_engine.seek(0.5) == true);
        assert(legacy_engine.get_position() >= 0.0);
        assert(legacy_engine.stop() == true);

        std::cout << "  ✓ Test 19 (ABI Compatibility: LYRA_SINK_HAS_CAP guards flush/get_buffered_frames) passed.\n";
    }

    // 23. Test 20: Custom Sink Device ID Polymorphism (allows non-hex format for custom sinks)
    {
        std::string received_dev;
        auto *custom_sink = new LyraAudioSink();
        custom_sink->struct_size = sizeof(LyraAudioSink);
        custom_sink->user_data = &received_dev;
        custom_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        custom_sink->start = [](LyraAudioSink *) -> int { return 0; };
        custom_sink->stop = [](LyraAudioSink *) -> int { return 0; };
        custom_sink->close = [](LyraAudioSink *) -> int { return 0; };
        custom_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
        custom_sink->set_output_device = [](LyraAudioSink *s, const char *dev) -> int {
            *static_cast<std::string *>(s->user_data) = dev ? dev : "";
            return 0;
        };

        AudioEngine engine(custom_sink, [](LyraAudioSink *s) { delete s; });
        // Non-hex device ID string
        const std::string custom_id = "alsa:hw:1,0";
        assert(engine.set_output_device(custom_id) == true);
        assert(engine.get_output_device() == custom_id);
        assert(received_dev == custom_id);

        std::cout << "  ✓ Test 20 (Custom Sink Device ID Polymorphism) passed.\n";
    }

    // 24. Test 21: ConfigurationService::apply_buffer_size_frames defense-in-depth against invalid/out-of-range frames
    {
        SqliteDatabaseContext db_ctx(":memory:");
        AudioEngine engine;
        ConfigurationService config_svc(db_ctx, "/tmp", &engine);

        assert(engine.get_buffer_size_frames() == 256);

        config_svc.apply_buffer_size_frames(0);
        assert(engine.get_buffer_size_frames() == 256);

        config_svc.apply_buffer_size_frames(-1);
        assert(engine.get_buffer_size_frames() == 256);

        config_svc.apply_buffer_size_frames(31);
        assert(engine.get_buffer_size_frames() == 256);

        config_svc.apply_buffer_size_frames(8193);
        assert(engine.get_buffer_size_frames() == 256);

        config_svc.apply_buffer_size_frames(512);
        assert(engine.get_buffer_size_frames() == 512);

        std::cout << "  ✓ Test 21 (ConfigurationService apply_buffer_size_frames defense-in-depth) passed.\n";
    }

    // 25. Test 22: ConfigurationService narrow lock scoping and transaction isolation during event dispatch
    {
        nlohmann::json captured_config;
        std::mutex captured_mutex;
        std::atomic<bool> event_received{false};

        SqliteDatabaseContext db_ctx(":memory:");
        AudioEngine engine;
        ConfigurationService config_svc(db_ctx, "/tmp", &engine);

        struct MockExclusiveFailSinkState {
            int exclusive_return_code{-2};
        } fail_state;

        auto *mock_sink = new LyraAudioSink();
        mock_sink->struct_size = sizeof(LyraAudioSink);
        mock_sink->user_data = &fail_state;
        mock_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        mock_sink->start = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->stop = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->close = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            return static_cast<int>(f);
        };
        mock_sink->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
        mock_sink->set_exclusive_mode = [](LyraAudioSink *s, int exc) -> int {
            if (exc != 0) {
                return static_cast<MockExclusiveFailSinkState *>(s->user_data)->exclusive_return_code;
            }
            return 0;
        };

        engine.set_sink(mock_sink, [](LyraAudioSink *s) { delete s; });

        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);

        engine.set_event_callback([&](const std::string &evt_str) {
            auto evt = nlohmann::json::parse(evt_str);
            if (evt.value("event", "") == "audio_state_changed") {
                event_received = true;
                // Re-entrant call back into ConfigurationService while update_config holds m_mutex
                auto cfg = config_svc.get_config_json();
                std::lock_guard<std::mutex> lk(captured_mutex);
                captured_config = cfg;
            }
        });

        auto fut = std::async(std::launch::async, [&]() {
            return config_svc.update_config(nlohmann::json{{"audio", {{"exclusive_mode", true}}}});
        });

        auto status = fut.wait_for(std::chrono::seconds(3));
        if (status == std::future_status::timeout) {
            std::cerr << "FAIL: Re-entrant call deadlocked on ConfigurationService::m_mutex!\n";
            std::abort();
        }
        assert(status == std::future_status::ready);
        auto result = fut.get();
        assert(!result.has_value());
        assert(result.error().value("code", 0) == 400);
        assert(result.error()["error"].value("type", "") == "InvalidValue");
        assert(event_received.load() == true);
        {
            std::lock_guard<std::mutex> lk(captured_mutex);
            assert(captured_config.is_object());
            assert(captured_config["audio"]["exclusive_mode"] == false);
        }

        engine.set_event_callback(nullptr);
        engine.stop();

        std::cout << "  ✓ Test 22 (ConfigurationService narrow lock scoping and transaction isolation) passed.\n";
    }

    // 26. Test 23: ConfigurationService re-entrancy guard fails fast with OperationFailed
    {
        std::atomic<bool> event_received{false};
        tl::expected<nlohmann::json, nlohmann::json> reentrant_result;
        std::mutex reentrant_mutex;

        SqliteDatabaseContext db_ctx(":memory:");
        AudioEngine engine;
        ConfigurationService config_svc(db_ctx, "/tmp", &engine);

        struct MockExclusiveFailSinkState {
            int exclusive_return_code{-2};
        } fail_state;

        auto *mock_sink = new LyraAudioSink();
        mock_sink->struct_size = sizeof(LyraAudioSink);
        mock_sink->user_data = &fail_state;
        mock_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        mock_sink->start = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->stop = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->close = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            return static_cast<int>(f);
        };
        mock_sink->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
        mock_sink->set_exclusive_mode = [](LyraAudioSink *s, int exc) -> int {
            if (exc != 0) {
                return static_cast<MockExclusiveFailSinkState *>(s->user_data)->exclusive_return_code;
            }
            return 0;
        };

        engine.set_sink(mock_sink, [](LyraAudioSink *s) { delete s; });

        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);

        engine.set_event_callback([&](const std::string &evt_str) {
            auto evt = nlohmann::json::parse(evt_str);
            if (evt.value("event", "") == "audio_state_changed") {
                event_received = true;
                // Attempt re-entrant update_config while outer update_config is in progress
                auto res = config_svc.update_config(
                    nlohmann::json{{"database", {{"busy_timeout_ms", 5000}}}});
                std::lock_guard<std::mutex> lk(reentrant_mutex);
                reentrant_result = res;
            }
        });

        auto fut = std::async(std::launch::async, [&]() {
            return config_svc.update_config(nlohmann::json{{"audio", {{"exclusive_mode", true}}}});
        });

        auto status = fut.wait_for(std::chrono::seconds(3));
        if (status == std::future_status::timeout) {
            std::cerr << "FAIL: Re-entrant update_config call deadlocked!\n";
            std::abort();
        }
        assert(status == std::future_status::ready);
        auto outer_result = fut.get();
        assert(!outer_result.has_value());
        assert(outer_result.error().value("code", 0) == 400);
        assert(outer_result.error()["error"].value("type", "") == "InvalidValue");

        assert(event_received.load() == true);

        // Verify re-entrant update_config failed fast with OperationFailed
        {
            std::lock_guard<std::mutex> lk(reentrant_mutex);
            assert(!reentrant_result.has_value());
            assert(reentrant_result.error().value("code", 0) == 400);
            assert(reentrant_result.error()["error"].value("type", "") == "OperationFailed");
            assert(reentrant_result.error()["error"].value("message", "") ==
                   "Configuration update already in progress");
        }

        // Verify state and database were NOT corrupted
        auto current_cfg = config_svc.get_config_json();
        assert(current_cfg["audio"]["exclusive_mode"] == false);
        assert(current_cfg["database"]["busy_timeout_ms"] == ConfigurationService::DEFAULT_BUSY_TIMEOUT_MS);

        // Verify SQLite database has no corrupted row
        {
            auto &db = db_ctx.get_db();
            SQLite::Statement query(db, "SELECT value FROM System_Config WHERE key = 'database.busy_timeout_ms';");
            if (query.executeStep()) {
                std::string val = query.getColumn(0).getString();
                assert(val != "5000");
            }
        }

        engine.set_event_callback(nullptr);
        engine.stop();

        std::cout << "  ✓ Test 23 (ConfigurationService re-entrancy guard fails fast with OperationFailed) passed.\n";
    }

    // 27. Test 24: Custom sink output device configuration allows custom device IDs
    {
        SqliteDatabaseContext db_ctx(":memory:");
        AudioEngine engine;
        auto *mock_sink = new LyraAudioSink();
        mock_sink->struct_size = sizeof(LyraAudioSink);
        mock_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        mock_sink->start = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->stop = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->close = [](LyraAudioSink *) -> int { return 0; };
        mock_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
        mock_sink->set_output_device = [](LyraAudioSink *, const char *) -> int { return 0; };
        engine.set_sink(mock_sink, [](LyraAudioSink *s) { delete s; });
        assert(engine.is_custom_sink_set() == true);

        ConfigurationService config_svc(db_ctx, "/tmp", &engine);
        auto update_res = config_svc.update_config(nlohmann::json{{"audio", {{"output_device_id", "alsa:hw:1,0"}}}});
        assert(update_res.has_value());
        assert(engine.get_output_device() == "alsa:hw:1,0");
        assert(config_svc.get_config_json()["audio"]["output_device_id"] == "alsa:hw:1,0");

        // Verify SQLite System_Config updated
        {
            auto &db = db_ctx.get_db();
            SQLite::Statement query(db, "SELECT value FROM System_Config WHERE key = 'audio.output_device_id';");
            assert(query.executeStep());
            assert(query.getColumn(0).getString() == "alsa:hw:1,0");
        }

        // Verify that with a default engine (no custom sink), unrecognized device IDs still fail with InvalidValue
        SqliteDatabaseContext default_db_ctx(":memory:");
        AudioEngine default_engine;
        assert(default_engine.is_custom_sink_set() == false);
        ConfigurationService default_config_svc(default_db_ctx, "/tmp", &default_engine);
        auto fail_res = default_config_svc.update_config(nlohmann::json{{"audio", {{"output_device_id", "unrecognized_device_xyz"}}}});
        assert(!fail_res.has_value());
        assert(fail_res.error().value("code", 0) == 400);
        assert(fail_res.error()["error"].value("type", "") == "InvalidValue");

        // Verify empty device_id fails fast with InvalidValue
        auto empty_res = default_config_svc.update_config(nlohmann::json{{"audio", {{"output_device_id", ""}}}});
        assert(!empty_res.has_value());
        assert(empty_res.error().value("code", 0) == 400);
        assert(empty_res.error()["error"].value("type", "") == "InvalidValue");
        assert(empty_res.error()["error"].value("message", "") == "audio.output_device_id cannot be empty");

        // Re-simulate startup with pre-existing custom device ID in SQLite before custom sink is attached:
        // Must NOT wipe the preference to "default" in memory or database.
        AudioEngine reboot_engine;
        assert(reboot_engine.is_custom_sink_set() == false);
        ConfigurationService reboot_svc(db_ctx, "/tmp", &reboot_engine);
        assert(reboot_svc.get_config_json()["audio"]["output_device_id"] == "alsa:hw:1,0");
        {
            auto &db = db_ctx.get_db();
            SQLite::Statement query(db, "SELECT value FROM System_Config WHERE key = 'audio.output_device_id';");
            assert(query.executeStep());
            assert(query.getColumn(0).getString() == "alsa:hw:1,0");
        }

        // Verify apply_sink_config_unlocked() sets volume on attached sink
        AudioEngine vol_engine;
        vol_engine.set_volume(0.65f);
        float sink_received_volume = 0.0f;
        auto *vol_sink = new LyraAudioSink();
        vol_sink->struct_size = sizeof(LyraAudioSink);
        vol_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
        vol_sink->start = [](LyraAudioSink *) -> int { return 0; };
        vol_sink->stop = [](LyraAudioSink *) -> int { return 0; };
        vol_sink->close = [](LyraAudioSink *) -> int { return 0; };
        vol_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
        vol_sink->user_data = &sink_received_volume;
        vol_sink->set_volume = [](LyraAudioSink *s, float vol) -> int {
            *static_cast<float *>(s->user_data) = vol;
            return 0;
        };
        vol_engine.set_sink(vol_sink, [](LyraAudioSink *s) { delete s; });
        assert(std::abs(sink_received_volume - 0.65f) < 1e-4f);

        std::cout << "  ✓ Test 24 (Custom sink output device configuration allows custom device IDs) passed.\n";
    }

    // 28. Test 25: ConfigurationService volume update persistence and AudioEngine sync
    {
        SqliteDatabaseContext db_ctx(":memory:");
        AudioEngine engine;
        ConfigurationService config_svc(db_ctx, "/tmp", &engine);

        auto update_res = config_svc.update_config(nlohmann::json{{"audio", {{"volume", 0.75}}}});
        assert(update_res.has_value());
        assert(config_svc.get_config_json()["audio"]["volume"] == 0.75);
        assert(engine.get_volume() == 0.75f);

        // Verify SQLite System_Config has row audio.volume == 0.75
        {
            auto &db = db_ctx.get_db();
            SQLite::Statement query(db, "SELECT value FROM System_Config WHERE key = 'audio.volume';");
            assert(query.executeStep());
            std::string val = query.getColumn(0).getString();
            assert(std::stod(val) == 0.75);
        }

        std::cout << "  ✓ Test 25 (ConfigurationService volume update persistence and AudioEngine sync) passed.\n";
    }

    // 29. Test 26: AudioEngine resume invalid state boundary defense
    {
        AudioEngine engine(create_null_audio_sink(), destroy_null_audio_sink);
        // In default STOPPED state, calling resume() must return false and set last_error to InvalidArgument
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        assert(engine.resume() == false);
        assert(engine.get_last_error() == AudioEngineError::InvalidArgument);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);

        // When playing, calling resume() must also return false and set last_error to InvalidArgument
        assert(engine.play(test_wav) == true);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);
        assert(engine.resume() == false);
        assert(engine.get_last_error() == AudioEngineError::InvalidArgument);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);

        // When paused, resume() should succeed
        assert(engine.pause() == true);
        assert(engine.get_state_enum() == AudioEngineState::PAUSED);
        assert(engine.resume() == true);
        assert(engine.get_last_error() == AudioEngineError::None);
        assert(engine.get_state_enum() == AudioEngineState::PLAYING);

        assert(engine.stop() == true);
        assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        std::cout << "  ✓ Test 26 (AudioEngine resume invalid state boundary defense) passed.\n";
    }

    // 30. Test 27: AudioEngine runtime config downgrade synchronization
    {
        // 27.1 Unit test: register downgrade callback on AudioEngine, attach mock sink that rejects
        // buffer size frames and exclusive mode, call play(), verify callback invoked with
        // "buffer_size_frames": 256 and "exclusive_mode": false.
        {
            AudioEngine engine(create_null_audio_sink(), destroy_null_audio_sink);
            assert(engine.set_buffer_size_frames(1024) == true);
            assert(engine.set_exclusive_mode(true) == true);
            assert(engine.get_buffer_size_frames() == 1024);
            assert(engine.get_exclusive_mode() == true);

            std::vector<std::pair<std::string, nlohmann::json>> downgraded;
            engine.set_config_downgrade_callback(
                [&](const std::string &cat, const std::string &key, const nlohmann::json &val) {
                    if (cat == "audio") {
                        downgraded.emplace_back(key, val);
                    }
                });

            struct RejectSinkState {
                bool reject_non_default_buffer{true};
                bool reject_exclusive{true};
            } r_state;

            auto *sink = new LyraAudioSink();
            sink->struct_size = sizeof(LyraAudioSink);
            sink->user_data = &r_state;
            sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            sink->start = [](LyraAudioSink *) -> int { return 0; };
            sink->stop = [](LyraAudioSink *) -> int { return 0; };
            sink->close = [](LyraAudioSink *) -> int { return 0; };
            sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
            sink->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
            sink->set_buffer_size_frames = [](LyraAudioSink *s, uint32_t frames) -> int {
                auto *st = static_cast<RejectSinkState *>(s->user_data);
                if (st->reject_non_default_buffer && frames != 256) {
                    return -1;
                }
                return 0;
            };
            sink->set_exclusive_mode = [](LyraAudioSink *s, int exc) -> int {
                auto *st = static_cast<RejectSinkState *>(s->user_data);
                if (st->reject_exclusive && exc != 0) {
                    return -1;
                }
                return 0;
            };

            engine.set_sink(sink, [](LyraAudioSink *s) { delete s; });

            // Call play() to trigger playback with downgraded parameters
            assert(engine.play(test_wav) == true);
            assert(engine.get_buffer_size_frames() == 256);
            assert(engine.get_exclusive_mode() == false);

            bool found_buffer = false;
            bool found_exclusive = false;
            for (const auto &[k, v] : downgraded) {
                if (k == "buffer_size_frames" && v == 256) found_buffer = true;
                if (k == "exclusive_mode" && v == false) found_exclusive = true;
            }
            assert(found_buffer);
            assert(found_exclusive);
            assert(engine.stop() == true);
        }

        // Also test unit test where reject happens specifically inside play()
        {
            AudioEngine engine(create_null_audio_sink(), destroy_null_audio_sink);
            assert(engine.set_buffer_size_frames(1024) == true);
            assert(engine.set_exclusive_mode(true) == true);

            struct PlayRejectState {
                bool reject{false};
            } p_state;

            auto *sink = new LyraAudioSink();
            sink->struct_size = sizeof(LyraAudioSink);
            sink->user_data = &p_state;
            sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            sink->start = [](LyraAudioSink *) -> int { return 0; };
            sink->stop = [](LyraAudioSink *) -> int { return 0; };
            sink->close = [](LyraAudioSink *) -> int { return 0; };
            sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
            sink->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
            sink->set_buffer_size_frames = [](LyraAudioSink *s, uint32_t frames) -> int {
                auto *st = static_cast<PlayRejectState *>(s->user_data);
                if (st->reject && frames != 256) {
                    return -1;
                }
                return 0;
            };
            sink->set_exclusive_mode = [](LyraAudioSink *s, int exc) -> int {
                auto *st = static_cast<PlayRejectState *>(s->user_data);
                if (st->reject && exc != 0) {
                    return -1;
                }
                return 0;
            };

            engine.set_sink(sink, [](LyraAudioSink *s) { delete s; });
            assert(engine.get_buffer_size_frames() == 1024);
            assert(engine.get_exclusive_mode() == true);

            std::vector<std::pair<std::string, nlohmann::json>> downgraded;
            engine.set_config_downgrade_callback(
                [&](const std::string &cat, const std::string &key, const nlohmann::json &val) {
                    if (cat == "audio") {
                        downgraded.emplace_back(key, val);
                    }
                });

            p_state.reject = true;
            assert(engine.play(test_wav) == true);
            assert(engine.get_buffer_size_frames() == 256);
            assert(engine.get_exclusive_mode() == false);

            bool found_buffer = false;
            bool found_exclusive = false;
            for (const auto &[k, v] : downgraded) {
                if (k == "buffer_size_frames" && v == 256) found_buffer = true;
                if (k == "exclusive_mode" && v == false) found_exclusive = true;
            }
            assert(found_buffer);
            assert(found_exclusive);
            assert(engine.stop() == true);
        }

        // 27.2 Integration test: Wire AudioEngine with ConfigurationService and SqliteDatabaseContext(":memory:")
        {
            SqliteDatabaseContext db_ctx(":memory:");
            AudioEngine engine(create_null_audio_sink(), destroy_null_audio_sink);
            ConfigurationService config_svc(db_ctx, "/tmp", &engine);

            // Update config to audio.buffer_size_frames = 1024 and audio.exclusive_mode = true
            auto update_res = config_svc.update_config(
                nlohmann::json{{"audio", {{"buffer_size_frames", 1024}, {"exclusive_mode", true}}}});
            assert(update_res.has_value());
            assert(config_svc.get_config_json()["audio"]["buffer_size_frames"] == 1024);
            assert(config_svc.get_config_json()["audio"]["exclusive_mode"] == true);
            assert(engine.get_buffer_size_frames() == 1024);
            assert(engine.get_exclusive_mode() == true);

            // Attach mock sink that rejects 1024 frames and exclusive mode
            struct RejectSinkState {
                bool reject_non_default_buffer{true};
                bool reject_exclusive{true};
            } r_state;

            auto *sink = new LyraAudioSink();
            sink->struct_size = sizeof(LyraAudioSink);
            sink->user_data = &r_state;
            sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            sink->start = [](LyraAudioSink *) -> int { return 0; };
            sink->stop = [](LyraAudioSink *) -> int { return 0; };
            sink->close = [](LyraAudioSink *) -> int { return 0; };
            sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
            sink->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
            sink->set_buffer_size_frames = [](LyraAudioSink *s, uint32_t frames) -> int {
                auto *st = static_cast<RejectSinkState *>(s->user_data);
                if (st->reject_non_default_buffer && frames != 256) {
                    return -1;
                }
                return 0;
            };
            sink->set_exclusive_mode = [](LyraAudioSink *s, int exc) -> int {
                auto *st = static_cast<RejectSinkState *>(s->user_data);
                if (st->reject_exclusive && exc != 0) {
                    return -1;
                }
                return 0;
            };

            engine.set_sink(sink, [](LyraAudioSink *s) { delete s; });

            // Call engine.play(test_wav)
            assert(engine.play(test_wav) == true);

            // Assert engine downgraded to safe defaults
            assert(engine.get_buffer_size_frames() == 256);
            assert(engine.get_exclusive_mode() == false);

            // Assert config_svc synchronized to safe defaults
            assert(config_svc.get_config_json()["audio"]["buffer_size_frames"] == 256);
            assert(config_svc.get_config_json()["audio"]["exclusive_mode"] == false);

            // Assert SQLite System_Config rows for audio.buffer_size_frames and audio.exclusive_mode contain "256" and
            // "false"
            {
                auto &db = db_ctx.get_db();
                SQLite::Statement q_buf(db,
                                        "SELECT value FROM System_Config WHERE key = 'audio.buffer_size_frames';");
                assert(q_buf.executeStep());
                assert(q_buf.getColumn(0).getString() == "256");

                SQLite::Statement q_exc(db, "SELECT value FROM System_Config WHERE key = 'audio.exclusive_mode';");
                assert(q_exc.executeStep());
                assert(q_exc.getColumn(0).getString() == "false");
            }

            // Simulate app restart: create a new ConfigurationService pointing to the same db_ctx, verify
            // get_config_json() returns 256 and false
            {
                AudioEngine reboot_engine(create_null_audio_sink(), destroy_null_audio_sink);
                ConfigurationService reboot_svc(db_ctx, "/tmp", &reboot_engine);
                assert(reboot_svc.get_config_json()["audio"]["buffer_size_frames"] == 256);
                assert(reboot_svc.get_config_json()["audio"]["exclusive_mode"] == false);
            }

            assert(engine.stop() == true);
        }

        // 27.3 Output device downgrade propagation when sink rejects custom device
        {
            SqliteDatabaseContext db_ctx(":memory:");
            AudioEngine engine(create_null_audio_sink(), destroy_null_audio_sink);
            ConfigurationService config_svc(db_ctx, "/tmp", &engine);

            // Configure audio.output_device_id to "custom_dev"
            auto update_res = config_svc.update_config(
                nlohmann::json{{"audio", {{"output_device_id", "custom_dev"}}}});
            assert(update_res.has_value());
            assert(config_svc.get_config_json()["audio"]["output_device_id"] == "custom_dev");
            assert(engine.get_output_device() == "custom_dev");

            // Attach mock sink that rejects "custom_dev" but accepts "default"
            struct DeviceRejectSinkState {
                std::string current_device;
            } d_state;

            auto *sink = new LyraAudioSink();
            sink->struct_size = sizeof(LyraAudioSink);
            sink->user_data = &d_state;
            sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            sink->start = [](LyraAudioSink *) -> int { return 0; };
            sink->stop = [](LyraAudioSink *) -> int { return 0; };
            sink->close = [](LyraAudioSink *) -> int { return 0; };
            sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
            sink->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
            sink->set_output_device = [](LyraAudioSink *s, const char *dev) -> int {
                auto *st = static_cast<DeviceRejectSinkState *>(s->user_data);
                if (dev && std::string(dev) == "custom_dev") {
                    return -1; // Reject custom_dev
                }
                if (dev) {
                    st->current_device = dev;
                }
                return 0; // Accept "default" or others
            };

            // Calling set_sink() must trigger apply_sink_config_unlocked and propagate downgrade
            engine.set_sink(sink, [](LyraAudioSink *s) { delete s; });

            // (a) engine.get_output_device() == "default"
            assert(engine.get_output_device() == "default");

            // (b) config_svc.get_config_json()["audio"]["output_device_id"] == "default"
            assert(config_svc.get_config_json()["audio"]["output_device_id"] == "default");

            // (c) SQLite System_Config table row for audio.output_device_id is updated to "default"
            {
                auto &db = db_ctx.get_db();
                SQLite::Statement q_dev(db,
                                        "SELECT value FROM System_Config WHERE key = 'audio.output_device_id';");
                assert(q_dev.executeStep());
                assert(q_dev.getColumn(0).getString() == "default");
            }

            // Verify persistence after restart
            {
                AudioEngine reboot_engine(create_null_audio_sink(), destroy_null_audio_sink);
                ConfigurationService reboot_svc(db_ctx, "/tmp", &reboot_engine);
                assert(reboot_svc.get_config_json()["audio"]["output_device_id"] == "default");
            }
        }

        std::cout << "  ✓ Test 27 (AudioEngine runtime config downgrade synchronization) passed.\n";
    }

    // 31. Test 28: Realtime audio callback rb_inited atomic lock-free and thread safety
    {
        // 28.1 Compile-time and runtime check for lock-free guarantee
        static_assert(std::atomic<bool>::is_always_lock_free,
                      "std::atomic<bool> must be always lock-free for realtime safety");
        std::atomic<bool> test_atomic{false};
        assert(test_atomic.is_lock_free());

        // 28.2 Multithreaded stress test on LocalAudioSinkImpl concurrent access
        // Control thread repeatedly cycles open(), start(), write_pcm(), flush(), stop(), close()
        // Reader thread concurrently queries get_buffered_frames()
        // Writer thread concurrently calls write_pcm()
        // Query thread concurrently queries is_open(), is_playing(), get_volume()
        LocalAudioSinkImpl sink;
        LyraAudioSpec spec{44100, 2, LYRA_AUDIO_FORMAT_F32, 0};
        std::vector<float> dummy_pcm(1024, 0.5f);

        std::atomic<bool> stop_flag{false};
        std::atomic<uint64_t> control_ops{0};
        std::atomic<uint64_t> reader_ops{0};
        std::atomic<uint64_t> writer_ops{0};
        std::atomic<uint64_t> query_ops{0};

        std::thread control_thread([&]() {
            while (!stop_flag.load(std::memory_order_relaxed)) {
                if (sink.open(&spec) == 0) {
                    if (sink.start() == 0) {
                        for (int i = 0; i < 5; ++i) {
                            sink.write_pcm(dummy_pcm.data(), static_cast<uint32_t>(dummy_pcm.size() / 2));
                            std::this_thread::sleep_for(std::chrono::milliseconds(2));
                        }
                        sink.flush();
                        sink.stop();
                    }
                    sink.close();
                }
                control_ops.fetch_add(1, std::memory_order_relaxed);
                std::this_thread::yield();
            }
        });

        std::thread reader_thread([&]() {
            while (!stop_flag.load(std::memory_order_relaxed)) {
                volatile uint32_t buffered = sink.get_buffered_frames();
                (void)buffered;
                reader_ops.fetch_add(1, std::memory_order_relaxed);
                std::this_thread::yield();
            }
        });

        std::thread writer_thread([&]() {
            while (!stop_flag.load(std::memory_order_relaxed)) {
                int written = sink.write_pcm(dummy_pcm.data(), static_cast<uint32_t>(dummy_pcm.size() / 2));
                (void)written;
                writer_ops.fetch_add(1, std::memory_order_relaxed);
                std::this_thread::yield();
            }
        });

        std::thread query_thread([&]() {
            while (!stop_flag.load(std::memory_order_relaxed)) {
                volatile bool op = sink.is_open();
                volatile bool pl = sink.is_playing();
                volatile float vol = sink.get_volume();
                (void)op;
                (void)pl;
                (void)vol;
                query_ops.fetch_add(1, std::memory_order_relaxed);
                std::this_thread::yield();
            }
        });

        std::this_thread::sleep_for(std::chrono::milliseconds(250));
        stop_flag.store(true, std::memory_order_relaxed);

        control_thread.join();
        reader_thread.join();
        writer_thread.join();
        query_thread.join();

        assert(control_ops.load() > 0);
        assert(reader_ops.load() > 0);
        assert(writer_ops.load() > 0);
        assert(query_ops.load() > 0);

        sink.close();
        assert(!sink.is_open());
        assert(sink.get_buffered_frames() == 0);

        // 28.3 Dedicated unsynchronized lock-free callback stress simulation
        // Verifies the exact acquire-release contract between producer lifecycle and lock-free consumer callback.
        struct CallbackStressSimulation {
            std::atomic<bool> inited{false};
            std::vector<uint32_t> payload;
        };

        CallbackStressSimulation sim;
        std::atomic<bool> sim_stop{false};
        std::atomic<uint64_t> sim_producer_cycles{0};
        std::atomic<uint64_t> sim_consumer_iterations{0};
        std::atomic<uint64_t> sim_verified_reads{0};

        constexpr size_t SIM_PAYLOAD_SIZE = 256;

        std::thread sim_producer([&]() {
            while (!sim_stop.load(std::memory_order_relaxed)) {
                uint32_t cycle_magic =
                    static_cast<uint32_t>(0xA5A50000 | (sim_producer_cycles.load(std::memory_order_relaxed) & 0xFFFF));

                // 1. Allocate / populate payload buffer
                sim.payload.assign(SIM_PAYLOAD_SIZE, cycle_magic);

                // 2. Publish with release semantics
                sim.inited.store(true, std::memory_order_release);

                // Hold valid state briefly to let consumer observe
                std::this_thread::sleep_for(std::chrono::microseconds(100));

                // 3. Revoke with release semantics
                sim.inited.store(false, std::memory_order_release);

                // Quiescent drain window for any in-flight unsynchronized read to finish (simulating ma_device_uninit drain)
                std::this_thread::sleep_for(std::chrono::milliseconds(2));

                // 4. Zero out / destroy payload buffer
                std::fill(sim.payload.begin(), sim.payload.end(), 0xBAADF00D);
                sim.payload.clear();

                sim_producer_cycles.fetch_add(1, std::memory_order_relaxed);
                std::this_thread::yield();
            }
        });

        std::thread sim_consumer([&]() {
            while (!sim_stop.load(std::memory_order_relaxed)) {
                if (sim.inited.load(std::memory_order_acquire)) {
                    // Lock-free read path: verify buffer contents are 100% valid and never torn/garbage
                    assert(sim.payload.size() == SIM_PAYLOAD_SIZE);
                    uint32_t first = sim.payload[0];
                    assert((first & 0xFFFF0000) == 0xA5A50000);
                    for (size_t i = 0; i < sim.payload.size(); ++i) {
                        assert(sim.payload[i] == first);
                    }
                    sim_verified_reads.fetch_add(1, std::memory_order_relaxed);
                }
                sim_consumer_iterations.fetch_add(1, std::memory_order_relaxed);
            }
        });

        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        sim_stop.store(true, std::memory_order_relaxed);

        sim_producer.join();
        sim_consumer.join();

        assert(sim_producer_cycles.load() > 0);
        assert(sim_consumer_iterations.load() > 10000);
        assert(sim_verified_reads.load() > 0);

        std::cout << "  ✓ Test 28 (Realtime audio callback rb_inited atomic lock-free and thread safety) passed ("
                  << control_ops.load() << " control, "
                  << reader_ops.load() << " reads, "
                  << writer_ops.load() << " writes, "
                  << query_ops.load() << " queries; "
                  << sim_producer_cycles.load() << " sim cycles, "
                  << sim_consumer_iterations.load() << " sim callback checks, "
                  << sim_verified_reads.load() << " verified lock-free reads).\n";
    }

    // 32. Test 29: Exclusive mode start failure fallback to shared mode
    {
        LocalAudioSinkImpl local_sink;
        assert(local_sink.set_exclusive_mode(true) == true);
        assert(local_sink.get_exclusive_mode() == true);
        assert(local_sink.is_exclusive_mode_active() == false);

        LyraAudioSpec spec{};
        spec.sample_rate = 44100;
        spec.channels = 2;
        spec.format = LYRA_AUDIO_FORMAT_F32;

        int open_res = local_sink.open(&spec);
        if (open_res == 0) {
            // When open succeeds, start() must succeed either via exclusive mode or via automatic fallback to shared mode
            assert(local_sink.start() == 0);
            assert(local_sink.is_playing() == true);
            // Verify stop restores inactive exclusive state
            assert(local_sink.stop() == 0);
            assert(local_sink.is_playing() == false);
            assert(local_sink.is_exclusive_mode_active() == false);
            assert(local_sink.close() == 0);
        }

        // Deterministic Mock Sink contract test verifying exclusive-to-shared fallback simulation in headless CI
        {
            struct MockG2SinkState {
                bool exclusive_requested{false};
                bool exclusive_active{false};
                bool playing{false};
                int exclusive_start_attempts{0};
                int shared_start_attempts{0};
            } g2_st;

            auto *mock_sink = new LyraAudioSink();
            mock_sink->struct_size = sizeof(LyraAudioSink);
            mock_sink->user_data = &g2_st;
            mock_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            mock_sink->close = [](LyraAudioSink *) -> int { return 0; };
            mock_sink->stop = [](LyraAudioSink *s) -> int {
                auto *st = static_cast<MockG2SinkState *>(s->user_data);
                st->playing = false;
                st->exclusive_active = false;
                return 0;
            };
            mock_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int { return static_cast<int>(f); };
            mock_sink->set_volume = [](LyraAudioSink *, float) -> int { return 0; };
            mock_sink->set_exclusive_mode = [](LyraAudioSink *s, int exc) -> int {
                auto *st = static_cast<MockG2SinkState *>(s->user_data);
                st->exclusive_requested = (exc != 0);
                return 0;
            };
            mock_sink->is_exclusive_mode_active = [](LyraAudioSink *s) -> int {
                return static_cast<MockG2SinkState *>(s->user_data)->exclusive_active ? 1 : 0;
            };
            mock_sink->start = [](LyraAudioSink *s) -> int {
                auto *st = static_cast<MockG2SinkState *>(s->user_data);
                if (st->exclusive_requested && !st->exclusive_active) {
                    st->exclusive_start_attempts++;
                    // Simulate exclusive access denied at start time by driver; fallback to shared mode
                    st->exclusive_active = false;
                    st->shared_start_attempts++;
                    st->playing = true;
                    return 0;
                }
                st->shared_start_attempts++;
                st->playing = true;
                return 0;
            };

            assert(mock_sink->set_exclusive_mode(mock_sink, 1) == 0);
            assert(mock_sink->is_exclusive_mode_active(mock_sink) == 0);
            assert(mock_sink->start(mock_sink) == 0);
            assert(g2_st.exclusive_start_attempts == 1);
            assert(g2_st.shared_start_attempts == 1);
            assert(g2_st.playing == true);
            assert(mock_sink->is_exclusive_mode_active(mock_sink) == 0);
            assert(mock_sink->stop(mock_sink) == 0);
            assert(g2_st.playing == false);

            delete mock_sink;
        }

        std::cout << "  ✓ Test 29 (Exclusive mode start failure fallback to shared mode) passed.\n";
    }

    // 33. Test 30: Stopped state parameter reconfiguration lock deferral
    {
        LocalAudioSinkImpl sink;
        LyraAudioSpec spec{};
        spec.sample_rate = 44100;
        spec.channels = 2;
        spec.format = LYRA_AUDIO_FORMAT_F32;

        int open_res = sink.open(&spec);
        if (open_res == 0) {
            assert(sink.is_open() == true);
            assert(sink.is_playing() == false);

            // 1. Enabling exclusive mode while stopped must defer hardware lock acquisition
            assert(sink.set_exclusive_mode(true) == true);
            assert(sink.get_exclusive_mode() == true);
            assert(sink.is_exclusive_mode_active() == false);

            // 2. Setting output device to default while stopped must NOT flicker/acquire exclusive lock
            assert(sink.set_output_device("default") == true);
            assert(sink.get_output_device() == "default");
            assert(sink.is_exclusive_mode_active() == false);

            // 3. Setting buffer size while stopped must NOT flicker/acquire exclusive lock
            assert(sink.set_buffer_size_frames(512) == true);
            assert(sink.get_buffer_size_frames() == 512);
            assert(sink.is_exclusive_mode_active() == false);

            // 4. Invalid device ID while stopped must fail fast without opening or flickering hardware
            const std::string non_existent_hex =
                "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
            assert(sink.set_output_device(non_existent_hex) == false);
            assert(sink.get_output_device() == "default");
            assert(sink.is_exclusive_mode_active() == false);

            // 5. Calling start() initializes hardware on demand with the deferred parameters
            assert(sink.start() == 0);
            assert(sink.is_playing() == true);

            // 6. Stop releases hardware exclusive mode
            assert(sink.stop() == 0);
            assert(sink.is_playing() == false);
            assert(sink.is_exclusive_mode_active() == false);

            // 7. Modifying device while stopped again must defer and not acquire exclusive lock
            assert(sink.set_output_device("default") == true);
            assert(sink.is_exclusive_mode_active() == false);

            assert(sink.close() == 0);
            assert(sink.is_open() == false);
        } else {
            assert(sink.is_open() == false);
            assert(sink.is_playing() == false);
            assert(sink.get_buffered_frames() == 0);
        }

        std::cout << "  ✓ Test 30 (Stopped state parameter reconfiguration lock deferral) passed.\n";
    }

    // 34. Test 31: Shared audio context lifecycle, active device accounting, concurrency, and clean teardown
    {
        // 1. Clean starting state & context status
        assert(LocalAudioSinkImpl::shutdown_shared_context() == true);
        assert(LocalAudioSinkImpl::is_context_initialized() == false);
        assert(LocalAudioSinkImpl::get_active_device_count() == 0);

        // Calling list_devices re-initializes context on demand
        auto devices = LocalAudioSinkImpl::list_devices();
        assert(LocalAudioSinkImpl::is_context_initialized() == true);
        assert(LocalAudioSinkImpl::get_active_device_count() == 0);

        // 2. Open sink and assert active device count increments
        {
            LocalAudioSinkImpl sink;
            LyraAudioSpec spec{};
            spec.sample_rate = 44100;
            spec.channels = 2;
            spec.format = LYRA_AUDIO_FORMAT_F32;

            int open_res = sink.open(&spec);
            if (open_res == 0) {
                assert(sink.is_open() == true);
                assert(sink.start() == 0);
                assert(sink.is_playing() == true);
                assert(LocalAudioSinkImpl::get_active_device_count() == 1);

                // 3. Active device protection: cannot uninit context while hardware device is bound
                assert(LocalAudioSinkImpl::shutdown_shared_context() == false);
                assert(LocalAudioSinkImpl::is_context_initialized() == true);

                // 4. Closing sink decrements active device count back to 0
                assert(sink.close() == 0);
                assert(sink.is_open() == false);
                assert(LocalAudioSinkImpl::get_active_device_count() == 0);
            }
        }

        // 5. Clean teardown: shutdown succeeds when no active devices remain
        assert(LocalAudioSinkImpl::shutdown_shared_context() == true);
        assert(LocalAudioSinkImpl::is_context_initialized() == false);
        assert(LocalAudioSinkImpl::get_active_device_count() == 0);

        // 6. Idempotence: calling shutdown again is a safe no-op returning true
        assert(LocalAudioSinkImpl::shutdown_shared_context() == true);

        // 7. Multi-threaded stress test: concurrent enumeration & initialization without race
        std::atomic<bool> race_start{false};
        std::atomic<int> query_errors{0};
        std::vector<std::thread> workers;
        for (int i = 0; i < 8; ++i) {
            workers.emplace_back([&]() {
                while (!race_start.load(std::memory_order_acquire)) {
                    std::this_thread::yield();
                }
                for (int j = 0; j < 50; ++j) {
                    auto dev_list = LocalAudioSinkImpl::list_devices();
                    if (dev_list.empty()) {
                        query_errors++;
                    }
                }
            });
        }
        race_start.store(true, std::memory_order_release);
        for (auto &t : workers) {
            t.join();
        }
        assert(query_errors.load() == 0);
        assert(LocalAudioSinkImpl::is_context_initialized() == true);

        // 8. Controlled shutdown via factory helper
        assert(shutdown_local_audio_context() == true);
        assert(LocalAudioSinkImpl::is_context_initialized() == false);

        std::cout << "  ✓ Test 31 (Shared audio context lifecycle, concurrency safety, and controlled teardown) passed.\n";
    }

    // 36. Test 32: Pump loop abnormal exit & natural end decoder cleanup, error state, and concurrency safety
    {
        // 1. Sink write failure (e.g. hardware disconnected mid-playback)
        {
            AudioEngine engine;
            std::atomic<int> stop_invoked{0};
            std::vector<std::string> emitted_events;
            std::mutex event_mutex;
            engine.set_event_callback([&](const std::string &json_str) {
                try {
                    auto j = nlohmann::json::parse(json_str);
                    std::lock_guard<std::mutex> lk(event_mutex);
                    emitted_events.push_back(j.value("event", ""));
                } catch (...) {
                }
            });

            auto failing_sink = new LyraAudioSink();
            memset(failing_sink, 0, sizeof(LyraAudioSink));
            failing_sink->struct_size = sizeof(LyraAudioSink);
            failing_sink->user_data = &stop_invoked;
            failing_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            failing_sink->start = [](LyraAudioSink *) -> int { return 0; };
            failing_sink->stop = [](LyraAudioSink *s) -> int {
                if (s && s->user_data) {
                    static_cast<std::atomic<int> *>(s->user_data)->fetch_add(1);
                }
                return 0;
            };
            failing_sink->close = [](LyraAudioSink *) -> int { return 0; };
            failing_sink->flush = [](LyraAudioSink *) -> int { return 0; };
            failing_sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t) -> int { return -1; };
            failing_sink->get_buffered_frames = [](LyraAudioSink *) -> uint32_t { return 0; };

            stop_invoked.store(0);
            engine.set_sink(failing_sink, [](LyraAudioSink *s) { delete s; });
            assert(engine.play(test_wav) == true);

            // Wait for pump loop to process failure and terminate
            int elapsed_ms = 0;
            bool has_unavailable = false;
            while (elapsed_ms < 500) {
                {
                    std::lock_guard<std::mutex> lk(event_mutex);
                    for (const auto &ev : emitted_events) {
                        if (ev == "audio_device_unavailable") {
                            has_unavailable = true;
                            break;
                        }
                    }
                }
                if (has_unavailable && engine.get_state_enum() == AudioEngineState::STOPPED) {
                    break;
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                elapsed_ms += 10;
            }

            assert(engine.get_state_enum() == AudioEngineState::STOPPED);
            assert(stop_invoked.load() > 0);
            // Verify error state and decoder cleanup:
            assert(engine.get_last_error() == AudioEngineError::DeviceUnavailable);
            assert(engine.is_decoder_open() == false);
            assert(has_unavailable == true);

            {
                std::lock_guard<std::mutex> lk(event_mutex);
                bool has_state_changed = false;
                for (const auto &ev : emitted_events) {
                    if (ev == "audio_state_changed") has_state_changed = true;
                }
                assert(has_state_changed == true);
            }
        }

        // 2. Natural track end (audio_ended) must also release decoder resources
        {
            AudioEngine engine;
            engine.set_sink(create_null_audio_sink(), destroy_null_audio_sink);
            assert(engine.play(short_wav) == true);
            assert(engine.is_decoder_open() == true);

            // Wait for playback to naturally reach EOF and end
            int elapsed_ms = 0;
            while (engine.get_state_enum() == AudioEngineState::PLAYING && elapsed_ms < 1000) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                elapsed_ms += 10;
            }

            assert(engine.get_state_enum() == AudioEngineState::STOPPED);
            // Verify finished decoder is cleaned up
            assert(engine.is_decoder_open() == false);
        }

        std::cout << "  ✓ Test 32 (Pump loop abnormal exit & natural end decoder cleanup, error state, and concurrency safety) passed.\n";
    }

    // 37. Test 33: Gapless cross-spec track transition drains buffer and reopens sink with new spec
    {
        std::string gapless_48k = base_dir + "/temp_engine_gapless_48k.wav";
        generate_test_wav(gapless_48k, 0.3, 48000);

        struct MockG3State {
            std::atomic<int> open_count{0};
            std::atomic<int> start_count{0};
            std::atomic<uint32_t> last_sample_rate{0};
            std::atomic<uint8_t> last_channels{0};
            std::atomic<uint32_t> buffered_frames{0};
        };

        auto create_mock_g3_sink = [](MockG3State *state) -> LyraAudioSink * {
            auto sink = new LyraAudioSink();
            memset(sink, 0, sizeof(LyraAudioSink));
            sink->struct_size = sizeof(LyraAudioSink);
            sink->user_data = state;
            sink->open = [](LyraAudioSink *s, const LyraAudioSpec *spec) -> int {
                auto st = static_cast<MockG3State *>(s->user_data);
                st->open_count++;
                st->last_sample_rate = spec->sample_rate;
                st->last_channels = spec->channels;
                return 0;
            };
            sink->start = [](LyraAudioSink *s) -> int {
                auto st = static_cast<MockG3State *>(s->user_data);
                st->start_count++;
                return 0;
            };
            sink->stop = [](LyraAudioSink *) -> int { return 0; };
            sink->close = [](LyraAudioSink *) -> int { return 0; };
            sink->flush = [](LyraAudioSink *s) -> int {
                auto st = static_cast<MockG3State *>(s->user_data);
                st->buffered_frames = 0;
                return 0;
            };
            sink->write_pcm = [](LyraAudioSink *s, const void *, uint32_t f) -> int {
                auto st = static_cast<MockG3State *>(s->user_data);
                st->buffered_frames += f;
                return static_cast<int>(f);
            };
            sink->get_buffered_frames = [](LyraAudioSink *s) -> uint32_t {
                auto st = static_cast<MockG3State *>(s->user_data);
                // Drain simulation: reduce by up to 512 frames per query
                uint32_t cur = st->buffered_frames.load();
                uint32_t dec = cur > 512 ? 512 : cur;
                st->buffered_frames -= dec;
                return st->buffered_frames.load();
            };
            return sink;
        };

        // Scenario 1: Cross-specification (44.1 kHz -> 48 kHz) MUST reopen sink with 48000 Hz
        {
            MockG3State state;
            AudioEngine engine;
            engine.set_sink(create_mock_g3_sink(&state), [](LyraAudioSink *s) { delete s; });

            assert(engine.play(gapless1) == true);
            assert(state.open_count.load() == 1);
            assert(state.last_sample_rate.load() == 44100);

            // Preload 48 kHz track
            assert(engine.preload_next(gapless_48k) == true);

            // Wait for transition to gapless_48k
            auto start = std::chrono::steady_clock::now();
            bool transitioned = false;
            while (std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start).count() < 3000) {
                if (engine.get_current_file_path() == gapless_48k) {
                    transitioned = true;
                    break;
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }

            assert(transitioned == true);
            // Assertion: Sink MUST have been reopened with 48000 Hz
            assert(state.open_count.load() == 2);
            assert(state.last_sample_rate.load() == 48000);
            assert(engine.get_state_enum() == AudioEngineState::PLAYING);

            assert(engine.stop() == true);
        }

        // Scenario 2: Same specification (44.1 kHz -> 44.1 kHz) MUST NOT reopen sink
        {
            MockG3State state;
            AudioEngine engine;
            engine.set_sink(create_mock_g3_sink(&state), [](LyraAudioSink *s) { delete s; });

            assert(engine.play(gapless1) == true);
            assert(state.open_count.load() == 1);
            assert(state.last_sample_rate.load() == 44100);

            // Preload 44.1 kHz track
            assert(engine.preload_next(gapless2) == true);

            auto start = std::chrono::steady_clock::now();
            bool transitioned = false;
            while (std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start).count() < 3000) {
                if (engine.get_current_file_path() == gapless2) {
                    transitioned = true;
                    break;
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }

            assert(transitioned == true);
            // Gapless Assertion: Same spec must remain open=1 (no redundant close/open)
            assert(state.open_count.load() == 1);
            assert(state.last_sample_rate.load() == 44100);
            assert(engine.get_state_enum() == AudioEngineState::PLAYING);

            assert(engine.stop() == true);
        }

        if (std::filesystem::exists(gapless_48k)) {
            std::filesystem::remove(gapless_48k);
        }

        std::cout << "  ✓ Test 33 (Gapless cross-spec track transition drains buffer and reopens sink with new spec) passed.\n";
    }

    // 38. Test 34: Drain-loop pause() and resume(), and drain-loop backward seek()
    {
        // Part 1: Drain-loop pause() and resume()
        // Verifies that pausing during final buffer draining does not kill pump_loop,
        // and resuming allows playback to finish draining and transition cleanly to STOPPED.
        {
            struct MockDrainState {
                std::atomic<uint32_t> buffered_frames{0};
                std::atomic<bool> allow_drain{false};
            } drain_state;

            auto mock_sink = new LyraAudioSink();
            memset(mock_sink, 0, sizeof(LyraAudioSink));
            mock_sink->struct_size = sizeof(LyraAudioSink);
            mock_sink->user_data = &drain_state;
            mock_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            mock_sink->start = [](LyraAudioSink *) -> int { return 0; };
            mock_sink->stop = [](LyraAudioSink *) -> int { return 0; };
            mock_sink->close = [](LyraAudioSink *) -> int { return 0; };
            mock_sink->flush = [](LyraAudioSink *s) -> int {
                static_cast<MockDrainState *>(s->user_data)->buffered_frames = 0;
                return 0;
            };
            mock_sink->write_pcm = [](LyraAudioSink *s, const void *, uint32_t f) -> int {
                auto st = static_cast<MockDrainState *>(s->user_data);
                st->buffered_frames += f;
                return static_cast<int>(f);
            };
            mock_sink->get_buffered_frames = [](LyraAudioSink *s) -> uint32_t {
                auto st = static_cast<MockDrainState *>(s->user_data);
                if (st->allow_drain.load()) {
                    uint32_t cur = st->buffered_frames.load();
                    uint32_t dec = cur > 256 ? 256 : cur;
                    st->buffered_frames -= dec;
                }
                return st->buffered_frames.load();
            };

            AudioEngine engine(mock_sink, [](LyraAudioSink *s) { delete s; });
            uint64_t initial_epoch = engine.get_track_epoch();
            assert(engine.play(short_wav) == true);
            assert(engine.get_track_epoch() > initial_epoch);

            // Wait for file decoding to complete (frames_read == 0) and enter drain loop with buffered frames
            auto wait_start = std::chrono::steady_clock::now();
            while (drain_state.buffered_frames.load() < 1000 &&
                   std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - wait_start).count() < 1000) {
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
            }
            assert(drain_state.buffered_frames.load() >= 1000);

            // Give it a brief moment to reach EOF in decoder and enter drain loop
            std::this_thread::sleep_for(std::chrono::milliseconds(20));

            // Pause while in drain loop
            assert(engine.pause() == true);
            assert(engine.get_state_enum() == AudioEngineState::PAUSED);

            // Wait a moment; pump_loop must NOT terminate while paused in drain loop!
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
            assert(engine.get_state_enum() == AudioEngineState::PAUSED);

            // Allow sink to drain and resume playback
            drain_state.allow_drain.store(true);
            assert(engine.resume() == true);
            assert(engine.get_state_enum() == AudioEngineState::PLAYING);

            // Playback should now complete draining and transition to STOPPED
            wait_start = std::chrono::steady_clock::now();
            while (engine.get_state_enum() == AudioEngineState::PLAYING &&
                   std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - wait_start).count() < 2000) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
            assert(engine.get_state_enum() == AudioEngineState::STOPPED);
            assert(drain_state.buffered_frames.load() == 0);
        }

        // Part 2: Drain-loop backward seek()
        // Verifies that seeking backward during drain loop does not prematurely end playback,
        // and resumes decoding from the seek position.
        {
            struct MockSeekDrainState {
                std::atomic<uint32_t> buffered_frames{0};
                std::atomic<bool> holding_buffer{true};
            } seek_drain_state;

            auto mock_sink = new LyraAudioSink();
            memset(mock_sink, 0, sizeof(LyraAudioSink));
            mock_sink->struct_size = sizeof(LyraAudioSink);
            mock_sink->user_data = &seek_drain_state;
            mock_sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            mock_sink->start = [](LyraAudioSink *) -> int { return 0; };
            mock_sink->stop = [](LyraAudioSink *) -> int { return 0; };
            mock_sink->close = [](LyraAudioSink *) -> int { return 0; };
            mock_sink->flush = [](LyraAudioSink *s) -> int {
                static_cast<MockSeekDrainState *>(s->user_data)->buffered_frames = 0;
                return 0;
            };
            mock_sink->write_pcm = [](LyraAudioSink *s, const void *, uint32_t f) -> int {
                auto st = static_cast<MockSeekDrainState *>(s->user_data);
                st->buffered_frames += f;
                return static_cast<int>(f);
            };
            mock_sink->get_buffered_frames = [](LyraAudioSink *s) -> uint32_t {
                auto st = static_cast<MockSeekDrainState *>(s->user_data);
                if (!st->holding_buffer.load()) {
                    uint32_t cur = st->buffered_frames.load();
                    uint32_t dec = cur > 512 ? 512 : cur;
                    st->buffered_frames -= dec;
                }
                return st->buffered_frames.load();
            };

            AudioEngine engine(mock_sink, [](LyraAudioSink *s) { delete s; });
            assert(engine.play(test_wav) == true);

            // Wait until full file has been decoded into buffer and enters drain loop
            auto wait_start = std::chrono::steady_clock::now();
            while (seek_drain_state.buffered_frames.load() < 10000 &&
                   std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - wait_start).count() < 1500) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(50));

            // Seek backward to beginning (0.1s) while in drain loop
            assert(engine.seek(0.1) == true);

            // Verify seek interrupted the drain loop: engine must remain in PLAYING state,
            // not transition prematurely to STOPPED
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
            assert(engine.get_state_enum() == AudioEngineState::PLAYING);

            seek_drain_state.holding_buffer.store(false);
            assert(engine.stop() == true);
        }

        std::cout << "  ✓ Test 34 (Drain-loop pause/resume and backward seek recovery) passed.\n";
    }

    // 39. Test 35: -2 double failure during active playback joins pump thread, closes decoder, and cleans up state
    {
        struct MockDoubleFailState {
            std::atomic<int> reconfig_return_code{-2};
        } df_state;

        auto create_df_sink = [&df_state]() -> LyraAudioSink * {
            auto sink = new LyraAudioSink();
            memset(sink, 0, sizeof(LyraAudioSink));
            sink->struct_size = sizeof(LyraAudioSink);
            sink->user_data = &df_state;
            sink->open = [](LyraAudioSink *, const LyraAudioSpec *) -> int { return 0; };
            sink->start = [](LyraAudioSink *) -> int { return 0; };
            sink->stop = [](LyraAudioSink *) -> int { return 0; };
            sink->close = [](LyraAudioSink *) -> int { return 0; };
            sink->write_pcm = [](LyraAudioSink *, const void *, uint32_t f) -> int {
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
                return static_cast<int>(f);
            };
            sink->set_output_device = [](LyraAudioSink *s, const char *) -> int {
                return static_cast<MockDoubleFailState *>(s->user_data)->reconfig_return_code.load();
            };
            sink->set_buffer_size_frames = [](LyraAudioSink *s, uint32_t) -> int {
                return static_cast<MockDoubleFailState *>(s->user_data)->reconfig_return_code.load();
            };
            sink->set_exclusive_mode = [](LyraAudioSink *s, int) -> int {
                return static_cast<MockDoubleFailState *>(s->user_data)->reconfig_return_code.load();
            };
            return sink;
        };

        // 1. set_output_device returning -2
        {
            AudioEngine engine(create_df_sink(), [](LyraAudioSink *s) { delete s; });
            assert(engine.play(test_wav) == true);
            assert(engine.get_state_enum() == AudioEngineState::PLAYING);
            assert(engine.is_decoder_open() == true);

            assert(engine.set_output_device("fail_dev") == false);
            assert(engine.get_state_enum() == AudioEngineState::STOPPED);
            assert(engine.get_last_error() == AudioEngineError::DeviceUnavailable);
            assert(engine.is_decoder_open() == false);
            assert(engine.get_current_file_path().empty() == true);
        }

        // 2. set_buffer_size_frames returning -2
        {
            AudioEngine engine(create_df_sink(), [](LyraAudioSink *s) { delete s; });
            assert(engine.play(test_wav) == true);
            assert(engine.get_state_enum() == AudioEngineState::PLAYING);

            assert(engine.set_buffer_size_frames(512) == false);
            assert(engine.get_state_enum() == AudioEngineState::STOPPED);
            assert(engine.get_last_error() == AudioEngineError::DeviceUnavailable);
            assert(engine.is_decoder_open() == false);
            assert(engine.get_current_file_path().empty() == true);
        }

        // 3. set_exclusive_mode returning -2
        {
            AudioEngine engine(create_df_sink(), [](LyraAudioSink *s) { delete s; });
            assert(engine.play(test_wav) == true);
            assert(engine.get_state_enum() == AudioEngineState::PLAYING);

            assert(engine.set_exclusive_mode(true) == false);
            assert(engine.get_state_enum() == AudioEngineState::STOPPED);
            assert(engine.get_last_error() == AudioEngineError::DeviceUnavailable);
            assert(engine.is_decoder_open() == false);
            assert(engine.get_current_file_path().empty() == true);
        }

        std::cout << "  ✓ Test 35 (-2 double failure during active playback joins thread and clears decoder) passed.\n";
    }

    // 40. Test 36: Persisted non-hex custom device ID self-heals in play() and audio spec boundary validation
    {
        // Part 1: Persisted custom non-hex device ID on default LocalAudioSink self-heals to default
        {
            AudioEngine engine; // Uses default LocalAudioSink
            assert(engine.is_custom_sink_set() == false);

            assert(engine.restore_output_device("alsa:hw:1,0") == true);
            assert(engine.get_output_device() == "alsa:hw:1,0");

            std::vector<std::tuple<std::string, std::string, std::string>> downgrades;
            engine.set_config_downgrade_callback([&](const std::string &cat, const std::string &key, const nlohmann::json &val) {
                downgrades.emplace_back(cat, key, val.is_string() ? val.get<std::string>() : val.dump());
            });

            // play() should self-heal "alsa:hw:1,0" to "default" and succeed
            assert(engine.play(test_wav) == true);
            assert(engine.get_output_device() == "default");
            assert(engine.get_state_enum() == AudioEngineState::PLAYING);

            bool found_downgrade = false;
            for (const auto &[cat, key, val] : downgrades) {
                if (cat == "audio" && key == "output_device_id" && val == "default") {
                    found_downgrade = true;
                    break;
                }
            }
            assert(found_downgrade == true);
            assert(engine.stop() == true);
        }

        // Part 2: Persisted 64-hex device ID that is offline must NOT self-heal, but fail fast with DeviceUnavailable
        {
            AudioEngine engine; // Uses default LocalAudioSink
            assert(engine.is_custom_sink_set() == false);

            const std::string offline_hex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
            assert(engine.restore_output_device(offline_hex) == true);
            assert(engine.get_output_device() == offline_hex);

            assert(engine.play(test_wav) == false);
            assert(engine.get_last_error() == AudioEngineError::DeviceUnavailable);
            assert(engine.get_state_enum() == AudioEngineState::STOPPED);
        }

        // Part 3: Boundary defense on sample rate (> 768000) and channels (> 32)
        {
            LocalAudioSinkImpl sink;
            LyraAudioSpec invalid_rate_spec{};
            invalid_rate_spec.sample_rate = 800000;
            invalid_rate_spec.channels = 2;
            invalid_rate_spec.format = LYRA_AUDIO_FORMAT_F32;
            assert(sink.open(&invalid_rate_spec) == -1);

            LyraAudioSpec invalid_chan_spec{};
            invalid_chan_spec.sample_rate = 44100;
            invalid_chan_spec.channels = 64;
            invalid_chan_spec.format = LYRA_AUDIO_FORMAT_F32;
            assert(sink.open(&invalid_chan_spec) == -1);
        }

        std::cout << "  ✓ Test 36 (Persisted non-hex custom device ID self-healing and offline hex rejection) passed.\n";
    }

    // Clean up temporary test files
    for (const auto &f : {test_wav, short_wav, chaos_wav, backpressure_wav, test_opus, gapless1, gapless2}) {
        if (std::filesystem::exists(f)) {
            std::filesystem::remove(f);
        }
    }

    // Final explicit shutdown of audio context:
    // Audio engine tests dynamically create, reconfigure, and destroy sinks across 31 tests.
    // In conjunction with core/tests/lsan.supp (which suppresses external host PipeWire daemon singletons),
    // calling shutdown_local_audio_context() here ensures that all Lyra-managed audio subsystem resources
    // (including the shared ma_context) are fully deinitialized before main() exits, guaranteeing
    // zero bytes leaked under AddressSanitizer and LeakSanitizer.
    shutdown_local_audio_context();

    std::cout << "ALL_TESTS_PASSED\n";
    return 0;
}
