/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/audio_decoder.h"
#include <cassert>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <vector>

using namespace lyra;

static bool generate_test_audio(const std::string &path, const std::string &codec, double duration = 1.0) {
    std::string cmd = "ffmpeg -y -v error -f lavfi -i 'sine=frequency=440:duration=" +
                      std::to_string(duration) + "' -c:a " + codec + " " + path;
    int ret = std::system(cmd.c_str());
    return (ret == 0 && std::filesystem::exists(path));
}

int main(int argc, char *argv[]) {
    std::cout << "[AudioDecoder Test] Starting multi-format decoding tests...\n";

    std::string base_dir = (argc > 1) ? argv[1] : ".";
    std::string wav_file = base_dir + "/temp_test.wav";
    std::string opus_file = base_dir + "/temp_test.opus";
    std::string ogg_file = base_dir + "/temp_test.ogg";
    std::string m4a_file = base_dir + "/temp_test.m4a";
    std::string flac_file = base_dir + "/temp_test.flac";
    std::string mp3_file = base_dir + "/temp_test.mp3";

    // 1. Invalid file handling
    {
        AudioDecoder dec;
        assert(!dec.is_open());
        assert(!dec.open(base_dir + "/non_existent_file.opus"));
        assert(!dec.is_open());
        std::cout << "  ✓ Invalid file handling passed.\n";
    }

    // 2. Test Opus decoding (.opus)
    {
        assert(generate_test_audio(opus_file, "libopus", 1.5));
        AudioDecoder dec;
        assert(dec.open(opus_file));
        assert(dec.is_open());
        assert(dec.get_sample_rate() > 0);
        assert(dec.get_channels() > 0);
        assert(dec.get_duration() >= 1.4);

        std::vector<float> buf(512 * dec.get_channels());
        uint64_t total_read = 0;
        while (true) {
            uint32_t read = dec.read_pcm_frames(buf.data(), 512);
            if (read == 0) break;
            total_read += read;
        }
        assert(total_read > 0);
        std::cout << "  ✓ Opus (.opus) decoding passed (read " << total_read << " frames).\n";

        // Seek test
        assert(dec.seek_seconds(0.5));
        assert(dec.read_pcm_frames(buf.data(), 256) > 0);
        std::cout << "  ✓ Opus seeking passed.\n";
        dec.close();
    }

    // 3. Test OGG Vorbis decoding (.ogg)
    {
        assert(generate_test_audio(ogg_file, "libvorbis", 1.0));
        AudioDecoder dec;
        assert(dec.open(ogg_file));
        assert(dec.is_open());
        assert(dec.get_sample_rate() > 0);

        std::vector<float> buf(512 * dec.get_channels());
        uint32_t read = dec.read_pcm_frames(buf.data(), 512);
        assert(read == 512);
        assert(dec.seek_seconds(0.3));
        assert(dec.read_pcm_frames(buf.data(), 128) > 0);
        std::cout << "  ✓ OGG Vorbis (.ogg) decoding and seek passed.\n";
        dec.close();
    }

    // 4. Test AAC / M4A decoding (.m4a)
    {
        assert(generate_test_audio(m4a_file, "aac", 1.0));
        AudioDecoder dec;
        assert(dec.open(m4a_file));
        assert(dec.is_open());
        assert(dec.get_sample_rate() > 0);

        std::vector<float> buf(512 * dec.get_channels());
        uint32_t read = dec.read_pcm_frames(buf.data(), 512);
        assert(read == 512);
        assert(dec.seek_seconds(0.4));
        assert(dec.read_pcm_frames(buf.data(), 128) > 0);
        std::cout << "  ✓ AAC (.m4a) decoding and seek passed.\n";
        dec.close();
    }

    // 5. Test FLAC decoding (.flac)
    {
        assert(generate_test_audio(flac_file, "flac", 1.0));
        AudioDecoder dec;
        assert(dec.open(flac_file));
        assert(dec.is_open());
        assert(dec.get_sample_rate() > 0);

        std::vector<float> buf(512 * dec.get_channels());
        uint32_t read = dec.read_pcm_frames(buf.data(), 512);
        assert(read == 512);
        assert(dec.seek_seconds(0.2));
        assert(dec.read_pcm_frames(buf.data(), 128) > 0);
        std::cout << "  ✓ FLAC (.flac) decoding and seek passed.\n";
        dec.close();
    }

    // 6. Test MP3 decoding (.mp3)
    {
        assert(generate_test_audio(mp3_file, "libmp3lame", 1.0));
        AudioDecoder dec;
        assert(dec.open(mp3_file));
        assert(dec.is_open());
        assert(dec.get_sample_rate() > 0);

        std::vector<float> buf(512 * dec.get_channels());
        uint32_t read = dec.read_pcm_frames(buf.data(), 512);
        assert(read == 512);
        assert(dec.seek_seconds(0.5));
        assert(dec.read_pcm_frames(buf.data(), 128) > 0);
        std::cout << "  ✓ MP3 (.mp3) decoding and seek passed.\n";
        dec.close();
    }

    // 7. Test WAV decoding (.wav)
    {
        assert(generate_test_audio(wav_file, "pcm_s16le", 1.0));
        AudioDecoder dec;
        assert(dec.open(wav_file));
        assert(dec.is_open());
        assert(dec.get_sample_rate() > 0);

        std::vector<float> buf(512 * dec.get_channels());
        uint32_t read = dec.read_pcm_frames(buf.data(), 512);
        assert(read == 512);
        assert(dec.seek_seconds(0.1));
        assert(dec.read_pcm_frames(buf.data(), 128) > 0);
        std::cout << "  ✓ WAV (.wav) decoding and seek passed.\n";
        dec.close();
    }

    // Clean up temporary files
    for (const auto &f : {wav_file, opus_file, ogg_file, m4a_file, flac_file, mp3_file}) {
        if (std::filesystem::exists(f)) {
            std::filesystem::remove(f);
        }
    }

    std::cout << "ALL_DECODER_TESTS_PASSED\n";
    return 0;
}
