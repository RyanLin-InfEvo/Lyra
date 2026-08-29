/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/waveform_service.h"

#include <cassert>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <thread>
#include <vector>

using namespace lyra;

static bool generate_test_audio(const std::string &path, double duration = 1.0) {
    std::string cmd = "ffmpeg -y -v error -f lavfi -i 'sine=frequency=440:duration=" +
                      std::to_string(duration) + "' -c:a pcm_s16le " + path;
    int ret = std::system(cmd.c_str());
    return (ret == 0 && std::filesystem::exists(path));
}

int main(int argc, char *argv[]) {
    std::cout << "[WaveformService Test] Starting comprehensive unit tests...\n";

    std::string base_dir = (argc > 1) ? argv[1] : ".";
    std::filesystem::path storage_root = std::filesystem::path(base_dir) / "test_waveform_storage";
    std::filesystem::create_directories(storage_root);

    std::string test_wav = (storage_root / "test_sine.wav").string();
    assert(generate_test_audio(test_wav, 1.0));

    // 1. Synthetic sine wave (440Hz, min ~ -1.0, max ~ 1.0, RMS ~ 0.707)
    {
        constexpr uint32_t sample_rate = 44100;
        constexpr uint64_t total_frames = 44100; // 1 second
        std::vector<float> sine_samples(total_frames);
        for (uint64_t t = 0; t < total_frames; ++t) {
            sine_samples[t] = static_cast<float>(std::sin(2.0 * M_PI * 440.0 * t / sample_rate));
        }

        auto wf = WaveformService::extract_from_pcm(sine_samples.data(), total_frames, 1, 100);
        assert(wf.points == 100);
        assert(wf.peaks.size() == 100);
        assert(wf.rms.size() == 100);

        for (uint32_t i = 0; i < 100; ++i) {
            assert(wf.peaks[i].first <= -0.90f);
            assert(wf.peaks[i].second >= 0.90f);
            assert(std::abs(wf.rms[i] - 0.7071f) < 0.05f);
        }
        std::cout << "  ✓ 1. Synthetic sine wave extraction passed.\n";
    }

    // 2. Silence (0.0) and DC offset
    {
        constexpr uint64_t total_frames = 1000;

        // Silence
        std::vector<float> silence(total_frames, 0.0f);
        auto wf_silence = WaveformService::extract_from_pcm(silence.data(), total_frames, 1, 10);
        for (uint32_t i = 0; i < 10; ++i) {
            assert(wf_silence.peaks[i].first == 0.0f);
            assert(wf_silence.peaks[i].second == 0.0f);
            assert(wf_silence.rms[i] == 0.0f);
        }

        // Positive DC offset (+0.5)
        std::vector<float> dc_pos(total_frames, 0.5f);
        auto wf_dc_pos = WaveformService::extract_from_pcm(dc_pos.data(), total_frames, 1, 10);
        for (uint32_t i = 0; i < 10; ++i) {
            assert(wf_dc_pos.peaks[i].first == 0.0f);
            assert(std::abs(wf_dc_pos.peaks[i].second - 0.5f) < 1e-5f);
            assert(std::abs(wf_dc_pos.rms[i] - 0.5f) < 1e-5f);
        }

        // Negative DC offset (-0.5)
        std::vector<float> dc_neg(total_frames, -0.5f);
        auto wf_dc_neg = WaveformService::extract_from_pcm(dc_neg.data(), total_frames, 1, 10);
        for (uint32_t i = 0; i < 10; ++i) {
            assert(std::abs(wf_dc_neg.peaks[i].first - (-0.5f)) < 1e-5f);
            assert(wf_dc_neg.peaks[i].second == 0.0f);
            assert(std::abs(wf_dc_neg.rms[i] - 0.5f) < 1e-5f);
        }
        std::cout << "  ✓ 2. Silence and DC offset tests passed.\n";
    }

    // 3. Left/right stereo channel peak preservation
    {
        constexpr uint64_t total_frames = 1000;
        std::vector<float> stereo(total_frames * 2);
        for (uint64_t f = 0; f < total_frames; ++f) {
            stereo[f * 2 + 0] = 0.8f;  // Left: +0.8
            stereo[f * 2 + 1] = -0.7f; // Right: -0.7
        }

        auto wf_stereo = WaveformService::extract_from_pcm(stereo.data(), total_frames, 2, 20);
        for (uint32_t i = 0; i < 20; ++i) {
            assert(std::abs(wf_stereo.peaks[i].first - (-0.7f)) < 1e-5f);
            assert(std::abs(wf_stereo.peaks[i].second - 0.8f) < 1e-5f);
            // RMS of {0.8, -0.7} = sqrt((0.64 + 0.49)/2) = sqrt(0.565) ≈ 0.75166
            assert(std::abs(wf_stereo.rms[i] - 0.75166f) < 1e-3f);
        }
        std::cout << "  ✓ 3. Stereo channel peak preservation passed.\n";
    }

    // 4. Downsampling peak preservation
    {
        WaveformData src;
        src.pcm_hash = "test-downsample";
        src.points = 1000;
        src.peaks.assign(1000, {-0.1f, 0.1f});
        src.rms.assign(1000, 0.05f);

        // Inject sharp spike at index 450
        src.peaks[450] = {-0.98f, 0.92f};
        src.rms[450] = 0.85f;

        // Downsample to 300 points
        auto res300 = WaveformService::resample_waveform(src, 300);
        assert(res300.points == 300);
        uint32_t spike_idx_300 = 450 * 300 / 1000; // 135
        assert(res300.peaks[spike_idx_300].first <= -0.98f);
        assert(res300.peaks[spike_idx_300].second >= 0.92f);

        // Downsample to 100 points
        auto res100 = WaveformService::resample_waveform(src, 100);
        assert(res100.points == 100);
        uint32_t spike_idx_100 = 450 * 100 / 1000; // 45
        assert(res100.peaks[spike_idx_100].first <= -0.98f);
        assert(res100.peaks[spike_idx_100].second >= 0.92f);

        std::cout << "  ✓ 4. Downsampling peak preservation passed.\n";
    }

    // 5. Cache save and binary header / size validation
    {
        WaveformData sample_data;
        sample_data.pcm_hash = "pcm-cache-test-1";
        sample_data.points = 1000;
        sample_data.peaks.resize(1000);
        sample_data.rms.resize(1000);
        for (uint32_t i = 0; i < 1000; ++i) {
            sample_data.peaks[i] = {-static_cast<float>(i) / 1000.0f, static_cast<float>(i) / 1000.0f};
            sample_data.rms[i] = static_cast<float>(i) / 1000.0f;
        }

        auto save_res = WaveformService::save_to_cache(storage_root, sample_data.pcm_hash, sample_data);
        assert(save_res.has_value());

        auto cache_path = WaveformService::get_cache_path(storage_root, sample_data.pcm_hash);
        assert(std::filesystem::exists(cache_path));

        uintmax_t expected_size = 16 + 1000 * 12; // 12016 bytes
        assert(std::filesystem::file_size(cache_path) == expected_size);

        std::ifstream in(cache_path, std::ios::binary);
        char magic[4];
        uint32_t version = 0, points = 0, reserved = 0;
        in.read(magic, 4);
        in.read(reinterpret_cast<char *>(&version), 4);
        in.read(reinterpret_cast<char *>(&points), 4);
        in.read(reinterpret_cast<char *>(&reserved), 4);

        assert(std::memcmp(magic, "LWAV", 4) == 0);
        assert(version == 1);
        assert(points == 1000);
        assert(reserved == 0);

        std::cout << "  ✓ 5. Binary cache format and size validation passed.\n";
    }

    // 6. Cache hit read consistency
    {
        auto load_res = WaveformService::load_from_cache(storage_root, "pcm-cache-test-1");
        assert(load_res.has_value());
        const auto &loaded = load_res.value();
        assert(loaded.pcm_hash == "pcm-cache-test-1");
        assert(loaded.points == 1000);
        assert(loaded.peaks.size() == 1000);
        assert(loaded.rms.size() == 1000);

        for (uint32_t i = 0; i < 1000; ++i) {
            float expected_val = static_cast<float>(i) / 1000.0f;
            assert(std::abs(loaded.peaks[i].first - (-expected_val)) < 1e-5f);
            assert(std::abs(loaded.peaks[i].second - expected_val) < 1e-5f);
            assert(std::abs(loaded.rms[i] - expected_val) < 1e-5f);
        }
        std::cout << "  ✓ 6. Cache read consistency passed.\n";
    }

    // 7. Corrupted cache self-healing tests
    {
        // 7a. Corrupt magic
        std::string pcm_corrupt_magic = "pcm-corrupt-magic";
        auto bad_magic_file = WaveformService::get_cache_path(storage_root, pcm_corrupt_magic);
        std::filesystem::create_directories(bad_magic_file.parent_path());
        {
            std::ofstream out(bad_magic_file, std::ios::binary);
            out.write("XXXX", 4);
            uint32_t v = 1, p = 1000, r = 0;
            out.write(reinterpret_cast<char *>(&v), 4);
            out.write(reinterpret_cast<char *>(&p), 4);
            out.write(reinterpret_cast<char *>(&r), 4);
            std::vector<float> dummy(3000, 0.0f);
            out.write(reinterpret_cast<char *>(dummy.data()), dummy.size() * sizeof(float));
        }

        auto healed_res_1 = WaveformService::get_or_compute_waveform(
            storage_root, pcm_corrupt_magic, test_wav, 300);
        assert(healed_res_1.has_value());
        assert(healed_res_1->points == 300);
        // Verify cache file was self-healed to valid LWAV format
        auto reload_1 = WaveformService::load_from_cache(storage_root, pcm_corrupt_magic);
        assert(reload_1.has_value());
        assert(reload_1->points == 1000);

        // 7b. Truncated file
        std::string pcm_corrupt_trunc = "pcm-corrupt-trunc";
        auto bad_trunc_file = WaveformService::get_cache_path(storage_root, pcm_corrupt_trunc);
        {
            std::ofstream out(bad_trunc_file, std::ios::binary);
            out.write("LWAV", 4);
            uint32_t v = 1, p = 1000, r = 0;
            out.write(reinterpret_cast<char *>(&v), 4);
            out.write(reinterpret_cast<char *>(&p), 4);
            out.write(reinterpret_cast<char *>(&r), 4);
            // Write only 10 floats instead of 3000
            std::vector<float> dummy(10, 0.0f);
            out.write(reinterpret_cast<char *>(dummy.data()), dummy.size() * sizeof(float));
        }

        auto healed_res_2 = WaveformService::get_or_compute_waveform(
            storage_root, pcm_corrupt_trunc, test_wav, 300);
        assert(healed_res_2.has_value());
        assert(healed_res_2->points == 300);
        auto reload_2 = WaveformService::load_from_cache(storage_root, pcm_corrupt_trunc);
        assert(reload_2.has_value());
        assert(reload_2->points == 1000);

        // 7c. NaN corruption
        std::string pcm_corrupt_nan = "pcm-corrupt-nan";
        auto bad_nan_file = WaveformService::get_cache_path(storage_root, pcm_corrupt_nan);
        {
            std::ofstream out(bad_nan_file, std::ios::binary);
            out.write("LWAV", 4);
            uint32_t v = 1, p = 1000, r = 0;
            out.write(reinterpret_cast<char *>(&v), 4);
            out.write(reinterpret_cast<char *>(&p), 4);
            out.write(reinterpret_cast<char *>(&r), 4);
            std::vector<float> dummy(3000, 0.0f);
            dummy[10] = std::nanf("");
            out.write(reinterpret_cast<char *>(dummy.data()), dummy.size() * sizeof(float));
        }

        auto healed_res_3 = WaveformService::get_or_compute_waveform(
            storage_root, pcm_corrupt_nan, test_wav, 300);
        assert(healed_res_3.has_value());
        assert(healed_res_3->points == 300);
        auto reload_3 = WaveformService::load_from_cache(storage_root, pcm_corrupt_nan);
        assert(reload_3.has_value());
        assert(reload_3->points == 1000);

        std::cout << "  ✓ 7. Self-healing on corrupted cache passed.\n";
    }

    // 8. Multi-threaded concurrent read/write test
    {
        constexpr int num_threads = 8;
        constexpr int iterations = 10;
        std::vector<std::thread> workers;
        std::string concurrent_hash = "pcm-concurrent-test";

        for (int t = 0; t < num_threads; ++t) {
            workers.emplace_back([&, t]() {
                for (int it = 0; it < iterations; ++it) {
                    auto wf = WaveformService::get_or_compute_waveform(
                        storage_root, concurrent_hash, test_wav, 300 + (t * 10));
                    assert(wf.has_value());
                    assert(wf->points == static_cast<uint32_t>(300 + (t * 10)));
                }
            });
        }

        for (auto &w : workers) {
            w.join();
        }
        std::cout << "  ✓ 8. Multi-threaded concurrency passed.\n";
    }

    // Clean up
    std::filesystem::remove_all(storage_root);

    std::cout << "ALL_WAVEFORM_TESTS_PASSED\n";
    return 0;
}
