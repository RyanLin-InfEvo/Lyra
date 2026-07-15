/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/audio_helper.h"
#include <cassert>
#include <iostream>
#include <string>
#include <vector>
#include <fstream>
#include <cmath>
#include <cstdio>
#include <cstdlib>

using namespace lyra::utils;

void setup_fixtures() {
    std::cout << "Setting up test fixtures using ffmpeg..." << std::endl;
    // Generate wav/flac files with identical content (44.1kHz, 2 channels, 2 seconds)
    int r1 = std::system("ffmpeg -y -f lavfi -i sine=frequency=1000:duration=2:sample_rate=44100 -ac 2 test_44k_stereo.wav > /dev/null 2>&1");
    int r2 = std::system("ffmpeg -y -i test_44k_stereo.wav test_44k_stereo.flac > /dev/null 2>&1");
    
    // Generate different formats/qualities (48kHz, mono)
    int r3 = std::system("ffmpeg -y -f lavfi -i sine=frequency=1000:duration=2:sample_rate=48000 -ac 2 test_48k_stereo.wav > /dev/null 2>&1");
    int r4 = std::system("ffmpeg -y -f lavfi -i sine=frequency=1000:duration=2:sample_rate=44100 -ac 1 test_44k_mono.wav > /dev/null 2>&1");
    
    // Generate a cover image
    int r5 = std::system("ffmpeg -y -f lavfi -i color=c=blue:s=100x100:d=1 -vframes 1 cover.jpg > /dev/null 2>&1");
    
    // Generate an MP3 with the cover image attached (ID3v2) and tags
    int r6 = std::system("ffmpeg -y -i test_44k_stereo.wav -i cover.jpg -map 0:a -map 1:v -c:a libmp3lame -c:v copy -id3v2_version 3 -metadata:s:v title=\"Album cover\" -metadata:s:v comment=\"Cover (front)\" -metadata title=\"Test Title\" -metadata artist=\"Test Artist\" -metadata album=\"Test Album\" -metadata date=\"2026\" -metadata track=\"3\" test_with_cover.mp3 > /dev/null 2>&1");

    // Generate a video file (3 seconds duration, width 320, height 240, h264)
    int r7 = std::system("ffmpeg -y -f lavfi -i sine=frequency=1000:duration=3 -f lavfi -i color=c=red:s=320x240:duration=3 -c:a aac -c:v libx264 -pix_fmt yuv420p test_video.mp4 > /dev/null 2>&1");

    (void)r1; (void)r2; (void)r3; (void)r4; (void)r5; (void)r6; (void)r7;
}

void cleanup_fixtures() {
    std::cout << "Cleaning up test fixtures..." << std::endl;
    std::remove("test_44k_stereo.wav");
    std::remove("test_44k_stereo.flac");
    std::remove("test_48k_stereo.wav");
    std::remove("test_44k_mono.wav");
    std::remove("cover.jpg");
    std::remove("test_with_cover.mp3");
    std::remove("test_video.mp4");
    std::remove("extracted_cover.jpg");
}

bool test_pcm_hash_format_independence_and_difference() {
    std::cout << "Running test_pcm_hash_format_independence_and_difference..." << std::endl;

    auto res_wav = AudioHelper::calculate_pcm_hash("test_44k_stereo.wav");
    auto res_flac = AudioHelper::calculate_pcm_hash("test_44k_stereo.flac");
    auto res_48k = AudioHelper::calculate_pcm_hash("test_48k_stereo.wav");
    auto res_mono = AudioHelper::calculate_pcm_hash("test_44k_mono.wav");

    if (!res_wav) {
        std::cerr << "Failed to calculate WAV hash: " << res_wav.error() << std::endl;
        return false;
    }
    if (!res_flac) {
        std::cerr << "Failed to calculate FLAC hash: " << res_flac.error() << std::endl;
        return false;
    }
    if (!res_48k) {
        std::cerr << "Failed to calculate 48kHz WAV hash: " << res_48k.error() << std::endl;
        return false;
    }
    if (!res_mono) {
        std::cerr << "Failed to calculate mono WAV hash: " << res_mono.error() << std::endl;
        return false;
    }

    std::cout << "WAV PCM hash:  " << res_wav.value() << std::endl;
    std::cout << "FLAC PCM hash: " << res_flac.value() << std::endl;
    std::cout << "48k PCM hash:  " << res_48k.value() << std::endl;
    std::cout << "Mono PCM hash: " << res_mono.value() << std::endl;

    // Lossless WAV and FLAC must yield identical PCM hashes
    if (res_wav.value() != res_flac.value()) {
        std::cerr << "Error: Lossless formats (WAV/FLAC) did not produce the same PCM hash!" << std::endl;
        return false;
    }

    // Different sample rate must yield different PCM hash
    if (res_wav.value() == res_48k.value()) {
        std::cerr << "Error: 44.1kHz and 48kHz audio produced the same PCM hash!" << std::endl;
        return false;
    }

    // Different channel configuration must yield different PCM hash
    if (res_wav.value() == res_mono.value()) {
        std::cerr << "Error: Stereo and Mono audio produced the same PCM hash!" << std::endl;
        return false;
    }

    return true;
}

bool test_extract_metadata() {
    std::cout << "Running test_extract_metadata..." << std::endl;

    // 1. WAV file metadata
    auto meta_wav = AudioHelper::extract_metadata("test_44k_stereo.wav");
    if (!meta_wav) {
        std::cerr << "Failed to extract WAV metadata: " << meta_wav.error() << std::endl;
        return false;
    }
    if (std::abs(meta_wav->duration - 2.0) > 0.1) {
        std::cerr << "WAV: Expected duration ~2.0, got " << meta_wav->duration << std::endl;
        return false;
    }
    if (meta_wav->sample_rate != 44100) {
        std::cerr << "WAV: Expected sample rate 44100, got " << meta_wav->sample_rate << std::endl;
        return false;
    }
    if (meta_wav->channels != 2) {
        std::cerr << "WAV: Expected 2 channels, got " << meta_wav->channels << std::endl;
        return false;
    }
    if (meta_wav->has_cover_art) {
        std::cerr << "WAV: Expected no cover art, but has_cover_art is true" << std::endl;
        return false;
    }

    // 2. MP3 file with cover art
    auto meta_mp3 = AudioHelper::extract_metadata("test_with_cover.mp3");
    if (!meta_mp3) {
        std::cerr << "Failed to extract MP3 metadata: " << meta_mp3.error() << std::endl;
        return false;
    }
    if (!meta_mp3->has_cover_art) {
        std::cerr << "MP3: Expected has_cover_art to be true" << std::endl;
        return false;
    }
    if (!meta_mp3->title.has_value() || meta_mp3->title.value() != "Test Title") {
        std::cerr << "MP3: Expected title 'Test Title', got " << (meta_mp3->title ? meta_mp3->title.value() : "none") << std::endl;
        return false;
    }
    if (!meta_mp3->artist.has_value() || meta_mp3->artist.value() != "Test Artist") {
        std::cerr << "MP3: Expected artist 'Test Artist', got " << (meta_mp3->artist ? meta_mp3->artist.value() : "none") << std::endl;
        return false;
    }
    if (!meta_mp3->album.has_value() || meta_mp3->album.value() != "Test Album") {
        std::cerr << "MP3: Expected album 'Test Album', got " << (meta_mp3->album ? meta_mp3->album.value() : "none") << std::endl;
        return false;
    }
    if (!meta_mp3->date.has_value() || meta_mp3->date.value() != "2026") {
        std::cerr << "MP3: Expected date '2026', got " << (meta_mp3->date ? meta_mp3->date.value() : "none") << std::endl;
        return false;
    }
    if (!meta_mp3->track.has_value() || meta_mp3->track.value() != "3") {
        std::cerr << "MP3: Expected track '3', got " << (meta_mp3->track ? meta_mp3->track.value() : "none") << std::endl;
        return false;
    }

    // 3. MP4 video file
    auto meta_video = AudioHelper::extract_metadata("test_video.mp4");
    if (!meta_video) {
        std::cerr << "Failed to extract MP4 metadata: " << meta_video.error() << std::endl;
        return false;
    }
    if (std::abs(meta_video->duration - 3.0) > 0.1) {
        std::cerr << "MP4: Expected duration ~3.0, got " << meta_video->duration << std::endl;
        return false;
    }
    if (!meta_video->video_width.has_value() || meta_video->video_width.value() != 320) {
        std::cerr << "MP4: Expected video width 320, got " 
                  << (meta_video->video_width ? std::to_string(meta_video->video_width.value()) : "none") << std::endl;
        return false;
    }
    if (!meta_video->video_height.has_value() || meta_video->video_height.value() != 240) {
        std::cerr << "MP4: Expected video height 240, got " 
                  << (meta_video->video_height ? std::to_string(meta_video->video_height.value()) : "none") << std::endl;
        return false;
    }
    if (!meta_video->video_codec.has_value() || (meta_video->video_codec.value() != "h264" && meta_video->video_codec.value().find("264") == std::string::npos)) {
        std::cerr << "MP4: Expected video codec h264, got " 
                  << (meta_video->video_codec ? meta_video->video_codec.value() : "none") << std::endl;
        return false;
    }

    return true;
}

bool test_extract_cover_art_to_memory() {
    std::cout << "Running test_extract_cover_art_to_memory..." << std::endl;

    auto cover_mp3 = AudioHelper::extract_cover_art("test_with_cover.mp3");
    if (!cover_mp3) {
        std::cerr << "Failed to extract MP3 cover art: " << cover_mp3.error() << std::endl;
        return false;
    }
    if (cover_mp3->empty()) {
        std::cerr << "MP3 cover art is empty" << std::endl;
        return false;
    }
    std::cout << "Extracted MP3 cover art size: " << cover_mp3->size() << " bytes" << std::endl;
    return true;
}

bool test_extract_cover_art_to_file() {
    std::cout << "Running test_extract_cover_art_to_file..." << std::endl;

    auto res_to_file = AudioHelper::extract_cover_art_to_file("test_with_cover.mp3", "extracted_cover.jpg");
    if (!res_to_file) {
        std::cerr << "Failed to extract MP3 cover art to file: " << res_to_file.error() << std::endl;
        return false;
    }

    std::ifstream check_file("extracted_cover.jpg", std::ios::binary);
    if (!check_file.is_open()) {
        std::cerr << "Failed to open extracted cover image file" << std::endl;
        return false;
    }
    check_file.seekg(0, std::ios::end);
    size_t file_size = check_file.tellg();
    check_file.close();

    if (file_size == 0) {
        std::cerr << "Extracted cover file is empty" << std::endl;
        return false;
    }
    std::cout << "Extracted cover file size: " << file_size << " bytes" << std::endl;
    std::remove("extracted_cover.jpg");
    return true;
}

bool test_extract_cover_art_to_file_failure_cleanup() {
    std::cout << "Running test_extract_cover_art_to_file_failure_cleanup..." << std::endl;

    std::remove("extracted_cover_failed.jpg"); // ensure clean slate
    auto res_failed = AudioHelper::extract_cover_art_to_file("test_44k_stereo.wav", "extracted_cover_failed.jpg");
    if (res_failed) {
        std::cerr << "Expected failure for WAV file, but got success" << std::endl;
        std::remove("extracted_cover_failed.jpg");
        return false;
    }

    // Verify file does not exist
    std::ifstream check_failed_file("extracted_cover_failed.jpg");
    if (check_failed_file.good()) {
        std::cerr << "Error: File 'extracted_cover_failed.jpg' was created/not deleted on failure!" << std::endl;
        check_failed_file.close();
        std::remove("extracted_cover_failed.jpg");
        return false;
    }
    return true;
}

bool test_extract_cover_art_to_file_invalid_path() {
    std::cout << "Running test_extract_cover_art_to_file_invalid_path..." << std::endl;

    auto res_invalid_path = AudioHelper::extract_cover_art_to_file("test_with_cover.mp3", "/nonexistent_directory_123/cover.jpg");
    if (res_invalid_path) {
        std::cerr << "Expected failure for invalid output path, but got success" << std::endl;
        return false;
    }
    if (res_invalid_path.error().find("Failed to open output image file") == std::string::npos) {
        std::cerr << "Expected open file error, got: " << res_invalid_path.error() << std::endl;
        return false;
    }
    return true;
}

bool test_extract_video_thumbnail() {
    std::cout << "Running test_extract_video_thumbnail..." << std::endl;

    auto cover_video = AudioHelper::extract_cover_art("test_video.mp4");
    if (!cover_video) {
        std::cerr << "Failed to extract video cover art (thumbnail): " << cover_video.error() << std::endl;
        return false;
    }
    if (cover_video->empty()) {
        std::cerr << "Video cover art is empty" << std::endl;
        return false;
    }
    std::cout << "Extracted video thumbnail size: " << cover_video->size() << " bytes" << std::endl;
    return true;
}

bool test_extract_cover_art_from_wav_failure() {
    std::cout << "Running test_extract_cover_art_from_wav_failure..." << std::endl;

    auto cover_wav = AudioHelper::extract_cover_art("test_44k_stereo.wav");
    if (cover_wav) {
        std::cerr << "Expected error extracting cover art from WAV, but succeeded!" << std::endl;
        return false;
    }
    std::cout << "Got expected error on WAV: " << cover_wav.error() << std::endl;
    return true;
}

int main() {
    setup_fixtures();

    bool success = true;
    try {
        if (!test_pcm_hash_format_independence_and_difference()) success = false;
        if (!test_extract_metadata()) success = false;
        if (!test_extract_cover_art_to_memory()) success = false;
        if (!test_extract_cover_art_to_file()) success = false;
        if (!test_extract_cover_art_to_file_failure_cleanup()) success = false;
        if (!test_extract_cover_art_to_file_invalid_path()) success = false;
        if (!test_extract_video_thumbnail()) success = false;
        if (!test_extract_cover_art_from_wav_failure()) success = false;
    } catch (const std::exception& e) {
        std::cerr << "Exception caught during tests: " << e.what() << std::endl;
        success = false;
    }

    cleanup_fixtures();

    if (success) {
        std::cout << "ALL_TESTS_PASSED" << std::endl;
        return 0;
    } else {
        std::cerr << "SOME TESTS FAILED" << std::endl;
        return 1;
    }
}
