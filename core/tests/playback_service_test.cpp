/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "services/database_context.h"
#include "services/playback_service.h"
#include "services/repositories/sqlite/sqlite_asset_repository.h"
#include "services/repositories/sqlite/sqlite_audio_repository.h"
#include "services/repositories/sqlite/sqlite_track_repository.h"
#include "utils/storage_helper.h"
#include <cassert>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

using namespace lyra;

namespace {

void write_dummy_wav(const std::string &filepath, double duration = 1.0, int sample_rate = 44100, int channels = 2) {
    std::filesystem::create_directories(std::filesystem::path(filepath).parent_path());
    std::ofstream out(filepath, std::ios::binary);
    int num_samples = static_cast<int>(duration * sample_rate * channels);
    int byte_rate = sample_rate * channels * 2;
    int data_size = num_samples * 2;
    int chunk_size = 36 + data_size;

    out.write("RIFF", 4);
    uint32_t cs = chunk_size;
    out.write(reinterpret_cast<const char *>(&cs), 4);
    out.write("WAVE", 4);
    out.write("fmt ", 4);
    uint32_t sub1 = 16;
    out.write(reinterpret_cast<const char *>(&sub1), 4);
    uint16_t fmt_tag = 1; // PCM
    out.write(reinterpret_cast<const char *>(&fmt_tag), 2);
    uint16_t num_ch = static_cast<uint16_t>(channels);
    out.write(reinterpret_cast<const char *>(&num_ch), 2);
    uint32_t sr = static_cast<uint32_t>(sample_rate);
    out.write(reinterpret_cast<const char *>(&sr), 4);
    uint32_t br = static_cast<uint32_t>(byte_rate);
    out.write(reinterpret_cast<const char *>(&br), 4);
    uint16_t block_align = static_cast<uint16_t>(channels * 2);
    out.write(reinterpret_cast<const char *>(&block_align), 2);
    uint16_t bits = 16;
    out.write(reinterpret_cast<const char *>(&bits), 2);
    out.write("data", 4);
    uint32_t ds = static_cast<uint32_t>(data_size);
    out.write(reinterpret_cast<const char *>(&ds), 4);

    std::vector<int16_t> samples(num_samples, 0);
    out.write(reinterpret_cast<const char *>(samples.data()), data_size);
    out.close();
}

struct TestContext {
    std::string temp_dir;
    std::string db_path;
    std::unique_ptr<SqliteDatabaseContext> db_context;
    std::unique_ptr<SqliteTrackRepository> track_repo;
    std::unique_ptr<SqliteAudioRepository> audio_repo;
    std::unique_ptr<SqliteAssetRepository> asset_repo;
    std::unique_ptr<AudioEngine> null_engine;
    std::unique_ptr<PlaybackService> service;

    TestContext(const std::string &base_dir, const std::string &sub_dir) {
        temp_dir = (std::filesystem::path(base_dir) / sub_dir).string();
        std::filesystem::create_directories(temp_dir);
        db_path = (std::filesystem::path(temp_dir) / "test.db").string();
        db_context = std::make_unique<SqliteDatabaseContext>(db_path);
        track_repo = std::make_unique<SqliteTrackRepository>(*db_context);
        audio_repo = std::make_unique<SqliteAudioRepository>(*db_context);
        asset_repo = std::make_unique<SqliteAssetRepository>(*db_context);
        null_engine = AudioEngine::create_null_engine();
        service = std::make_unique<PlaybackService>(
            temp_dir,
            *null_engine,
            *track_repo,
            *audio_repo,
            *asset_repo);
    }
};

} // namespace

void test_direct_file_playback(const std::string &base_dir) {
    std::cout << "[Test A] Direct file playback..." << std::endl;
    TestContext ctx(base_dir, "test_a");

    std::string wav_path = (std::filesystem::path(ctx.temp_dir) / "direct.wav").string();
    write_dummy_wav(wav_path, 1.0, 44100, 2);

    auto target = PlaybackTarget::from_file(wav_path);
    auto res = ctx.service->resolve(target);
    assert(res.has_value());
    assert(res->file_path == wav_path);
    assert(res->format == "wav");
    assert(res->file_size > 0);
    assert(res->is_lossless == true);

    auto play_res = ctx.service->play(target);
    assert(play_res.has_value());
    assert(ctx.service->get_state() == AudioEngineState::PLAYING);
    assert(ctx.service->get_current_file_path() == wav_path);
    assert(ctx.service->get_current_resolved().has_value());
    assert(ctx.service->get_current_resolved()->file_path == wav_path);

    assert(ctx.service->stop() == true);
    assert(ctx.service->get_state() == AudioEngineState::STOPPED);
    assert(!ctx.service->get_current_resolved().has_value());
}

void test_asset_resolution_and_cas_discovery(const std::string &base_dir) {
    std::cout << "[Test B] Asset target resolution & CAS path discovery..." << std::endl;
    TestContext ctx(base_dir, "test_b");

    std::string file_hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    std::string pcm_hash = "pcm_hash_asset_test_001";

    auto cas_dir = utils::StorageHelper::resolve_cas_dir(ctx.temp_dir, file_hash);
    std::filesystem::create_directories(cas_dir);
    std::string cas_file = (cas_dir / (file_hash + ".wav")).string();
    write_dummy_wav(cas_file, 1.0, 44100, 2);

    Audio audio;
    audio.pcm_hash = pcm_hash;
    audio.bit_depth = 16;
    audio.sample_rate = 44100;
    audio.channels = 2;
    audio.duration = 1.0;
    auto a_res = ctx.audio_repo->insert(audio);
    assert(a_res.has_value());

    Asset asset;
    asset.file_hash = file_hash;
    asset.mime_type = "audio/wav";
    asset.asset_type = "audio";
    asset.file_size = static_cast<int64_t>(std::filesystem::file_size(cas_file));
    auto as_res = ctx.asset_repo->insert_asset_with_audio(asset, audio);
    assert(as_res.has_value());

    auto target = PlaybackTarget::from_asset(file_hash);
    auto res = ctx.service->resolve(target);
    assert(res.has_value());
    assert(res->file_hash == file_hash);
    assert(res->pcm_hash == pcm_hash);
    assert(res->sample_rate == 44100);
    assert(res->bit_depth == 16);
    assert(res->channels == 2);
    assert(res->file_path == cas_file);
    assert(res->is_lossless == true);

    auto play_res = ctx.service->play(target);
    assert(play_res.has_value());
    assert(ctx.service->get_state() == AudioEngineState::PLAYING);
    assert(ctx.service->stop() == true);
}

void test_audio_format_preference_scoring(const std::string &base_dir) {
    std::cout << "[Test C] Audio target with multiple assets and format preference scoring (+1000 bonus)..." << std::endl;
    TestContext ctx(base_dir, "test_c");

    std::string pcm_hash = "pcm_multi_asset_001";
    std::string flac_hash = "1111111111111111111111111111111111111111111111111111111111111111";
    std::string mp3_hash = "2222222222222222222222222222222222222222222222222222222222222222";

    Audio audio;
    audio.pcm_hash = pcm_hash;
    audio.bit_depth = 24;
    audio.sample_rate = 96000;
    audio.channels = 2;
    audio.duration = 2.0;
    auto a_res = ctx.audio_repo->insert(audio);
    assert(a_res.has_value());

    // Create physical files
    auto dir1 = utils::StorageHelper::resolve_cas_dir(ctx.temp_dir, flac_hash);
    std::filesystem::create_directories(dir1);
    std::string path1 = (dir1 / (flac_hash + ".flac")).string();
    write_dummy_wav(path1, 2.0, 96000, 2);

    auto dir2 = utils::StorageHelper::resolve_cas_dir(ctx.temp_dir, mp3_hash);
    std::filesystem::create_directories(dir2);
    std::string path2 = (dir2 / (mp3_hash + ".mp3")).string();
    write_dummy_wav(path2, 2.0, 44100, 2);

    Asset flac_asset;
    flac_asset.file_hash = flac_hash;
    flac_asset.mime_type = "audio/flac";
    flac_asset.asset_type = "audio";
    flac_asset.file_size = 5000000;
    assert(ctx.asset_repo->insert_asset_with_audio(flac_asset, audio).has_value());

    Asset mp3_asset;
    mp3_asset.file_hash = mp3_hash;
    mp3_asset.mime_type = "audio/mpeg";
    mp3_asset.asset_type = "audio";
    mp3_asset.file_size = 1000000;
    assert(ctx.asset_repo->insert_asset_with_audio(mp3_asset, audio).has_value());

    // Default: without preference, lossless FLAC wins
    auto target = PlaybackTarget::from_audio(pcm_hash);
    auto res_default = ctx.service->resolve(target);
    assert(res_default.has_value());
    assert(res_default->file_hash == flac_hash);
    assert(res_default->is_lossless == true);

    // With preferred format "mp3": MP3 receives +1000 bonus and wins
    PlaybackOptions opts;
    opts.preferred_format = "mp3";
    auto res_pref = ctx.service->resolve(target, opts);
    assert(res_pref.has_value());
    assert(res_pref->file_hash == mp3_hash);
}

void test_track_star_topology_and_master_resolution(const std::string &base_dir) {
    std::cout << "[Test D] Track target with Star Topology version family and recommended master resolution..." << std::endl;
    TestContext ctx(base_dir, "test_d");

    std::string master_pcm = "pcm_master_96k";
    std::string secondary_pcm = "pcm_secondary_44k";
    std::string master_file = "3333333333333333333333333333333333333333333333333333333333333333";
    std::string secondary_file = "4444444444444444444444444444444444444444444444444444444444444444";

    // Master Audio: 24-bit 96kHz
    Audio master_audio;
    master_audio.pcm_hash = master_pcm;
    master_audio.bit_depth = 24;
    master_audio.sample_rate = 96000;
    master_audio.channels = 2;
    master_audio.duration = 3.0;
    master_audio.parent_hash = "";
    assert(ctx.audio_repo->insert(master_audio).has_value());

    // Secondary Audio: 16-bit 44.1kHz, parent points to master
    Audio sec_audio;
    sec_audio.pcm_hash = secondary_pcm;
    sec_audio.bit_depth = 16;
    sec_audio.sample_rate = 44100;
    sec_audio.channels = 2;
    sec_audio.duration = 3.0;
    sec_audio.parent_hash = master_pcm;
    assert(ctx.audio_repo->insert(sec_audio).has_value());

    // Write physical files
    auto dir_m = utils::StorageHelper::resolve_cas_dir(ctx.temp_dir, master_file);
    std::filesystem::create_directories(dir_m);
    write_dummy_wav((dir_m / (master_file + ".flac")).string(), 3.0, 96000, 2);

    Asset asset_m;
    asset_m.file_hash = master_file;
    asset_m.mime_type = "audio/flac";
    asset_m.asset_type = "audio";
    asset_m.file_size = 10000000;
    assert(ctx.asset_repo->insert_asset_with_audio(asset_m, master_audio).has_value());

    auto dir_s = utils::StorageHelper::resolve_cas_dir(ctx.temp_dir, secondary_file);
    std::filesystem::create_directories(dir_s);
    write_dummy_wav((dir_s / (secondary_file + ".flac")).string(), 3.0, 44100, 2);

    Asset asset_s;
    asset_s.file_hash = secondary_file;
    asset_s.mime_type = "audio/flac";
    asset_s.asset_type = "audio";
    asset_s.file_size = 5000000;
    assert(ctx.asset_repo->insert_asset_with_audio(asset_s, sec_audio).has_value());

    // Track references the secondary audio
    Track track;
    track.id = "track-star-test-01";
    track.title = "Star Topology Track";
    track.pcm_hash = secondary_pcm;
    assert(ctx.track_repo->insert(track).has_value());

    // Case 1: unpinned (pin_version = false) -> resolves to higher-quality recommended master (master_pcm)
    auto target = PlaybackTarget::from_track(track.id);
    auto res_unpinned = ctx.service->resolve(target);
    assert(res_unpinned.has_value());
    assert(res_unpinned->track_id == track.id);
    assert(res_unpinned->pcm_hash == master_pcm);
    assert(res_unpinned->file_hash == master_file);

    // Case 2: pinned (pin_version = true) -> resolves strictly to track.pcm_hash (secondary_pcm)
    PlaybackOptions pin_opts;
    pin_opts.pin_version = true;
    auto res_pinned = ctx.service->resolve(target, pin_opts);
    assert(res_pinned.has_value());
    assert(res_pinned->track_id == track.id);
    assert(res_pinned->pcm_hash == secondary_pcm);
    assert(res_pinned->file_hash == secondary_file);

    // Case 3: unpinned fallback when master file is missing on disk -> falls back to next best candidate (secondary_pcm)
    std::string master_disk_path = (dir_m / (master_file + ".flac")).string();
    std::filesystem::remove(master_disk_path);
    auto res_fallback = ctx.service->resolve(target);
    assert(res_fallback.has_value());
    assert(res_fallback->track_id == track.id);
    assert(res_fallback->pcm_hash == secondary_pcm);
    assert(res_fallback->file_hash == secondary_file);

    // Case 4: when all version candidates are missing on disk -> fails cleanly
    std::string secondary_disk_path = (dir_s / (secondary_file + ".flac")).string();
    std::filesystem::remove(secondary_disk_path);
    auto res_all_missing = ctx.service->resolve(target);
    assert(!res_all_missing.has_value());
    assert(res_all_missing.error().code == PlaybackErrorCode::CasObjectMissing);
}

void test_missing_cas_file_error_handling(const std::string &base_dir) {
    std::cout << "[Test E] Missing CAS file on disk error handling (CasObjectMissing / AssetNotFound)..." << std::endl;
    TestContext ctx(base_dir, "test_e");

    std::string missing_hash = "5555555555555555555555555555555555555555555555555555555555555555";
    std::string missing_pcm = "pcm_missing_cas_001";

    Audio audio;
    audio.pcm_hash = missing_pcm;
    audio.bit_depth = 16;
    audio.sample_rate = 44100;
    audio.channels = 2;
    audio.duration = 1.0;
    assert(ctx.audio_repo->insert(audio).has_value());

    // Insert Asset record into DB, but DO NOT create physical file
    Asset asset;
    asset.file_hash = missing_hash;
    asset.mime_type = "audio/wav";
    asset.asset_type = "audio";
    asset.file_size = 50000;
    assert(ctx.asset_repo->insert_asset_with_audio(asset, audio).has_value());

    // 1. Asset target missing CAS file
    auto res_asset = ctx.service->resolve(PlaybackTarget::from_asset(missing_hash));
    assert(!res_asset.has_value());
    assert(res_asset.error().code == PlaybackErrorCode::CasObjectMissing);
    assert(res_asset.error().message.find("not found in storage") != std::string::npos);

    // 2. Audio target missing all CAS files
    auto res_audio = ctx.service->resolve(PlaybackTarget::from_audio(missing_pcm));
    assert(!res_audio.has_value());
    assert(res_audio.error().code == PlaybackErrorCode::CasObjectMissing);
    assert(res_audio.error().message == "Asset not found on disk");

    // 3. InvalidParameter for malformed file_hash format (e.g. not 64 hex characters)
    auto res_invalid = ctx.service->resolve(PlaybackTarget::from_asset("non_existent_hash"));
    assert(!res_invalid.has_value());
    assert(res_invalid.error().code == PlaybackErrorCode::InvalidParameter);
    assert(res_invalid.error().message.find("Invalid file hash format") != std::string::npos);

    // 4. TargetNotFound for non-existent target in DB with valid 64-hex hash
    std::string non_existent_64hex = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    auto res_notfound = ctx.service->resolve(PlaybackTarget::from_asset(non_existent_64hex));
    assert(!res_notfound.has_value());
    assert(res_notfound.error().code == PlaybackErrorCode::TargetNotFound);
}

void test_version_comparison(const std::string &base_dir) {
    std::cout << "[Test F] Version comparison (compare_versions)..." << std::endl;
    TestContext ctx(base_dir, "test_f");

    std::string master_pcm = "pcm_cmp_master";
    std::string secondary_pcm = "pcm_cmp_sec";

    Audio master_audio;
    master_audio.pcm_hash = master_pcm;
    master_audio.bit_depth = 24;
    master_audio.sample_rate = 96000;
    master_audio.channels = 2;
    master_audio.duration = 2.0;
    assert(ctx.audio_repo->insert(master_audio).has_value());

    Audio sec_audio;
    sec_audio.pcm_hash = secondary_pcm;
    sec_audio.bit_depth = 16;
    sec_audio.sample_rate = 44100;
    sec_audio.channels = 2;
    sec_audio.duration = 2.0;
    sec_audio.parent_hash = master_pcm;
    assert(ctx.audio_repo->insert(sec_audio).has_value());

    Track track;
    track.id = "track-cmp-01";
    track.title = "Comparison Track";
    track.pcm_hash = secondary_pcm;
    assert(ctx.track_repo->insert(track).has_value());

    // 1. Compare via Track target
    auto cmp_track = ctx.service->compare_versions(PlaybackTarget::from_track(track.id));
    assert(cmp_track.has_value());
    assert(cmp_track->recommended_master == master_pcm);
    assert(cmp_track->versions.size() == 2);
    assert(cmp_track->versions[0].pcm_hash == master_pcm);
    assert(cmp_track->versions[1].pcm_hash == secondary_pcm);

    // 2. Compare via explicit pcm_hashes
    auto cmp_hashes = ctx.service->compare_versions(std::vector<std::string>{secondary_pcm, master_pcm});
    assert(cmp_hashes.has_value());
    assert(cmp_hashes->recommended_master == master_pcm);
    assert(cmp_hashes->versions.size() == 2);
    assert(cmp_hashes->versions[0].pcm_hash == master_pcm);
}

void test_transport_controls(const std::string &base_dir) {
    std::cout << "[Test G] Transport controls (play, pause, seek, stop)..." << std::endl;
    TestContext ctx(base_dir, "test_g");

    std::string wav1 = (std::filesystem::path(ctx.temp_dir) / "transport1.wav").string();
    write_dummy_wav(wav1, 3.0, 44100, 2);

    std::string wav2 = (std::filesystem::path(ctx.temp_dir) / "transport2.wav").string();
    write_dummy_wav(wav2, 3.0, 44100, 2);

    // Initial state
    assert(ctx.service->get_state() == AudioEngineState::STOPPED);
    assert(ctx.service->get_state_string() == "STOPPED");

    // Play
    auto play_res = ctx.service->play(PlaybackTarget::from_file(wav1));
    assert(play_res.has_value());
    assert(ctx.service->get_state() == AudioEngineState::PLAYING);
    assert(ctx.service->get_state_string() == "PLAYING");

    // Pause & Resume
    assert(ctx.service->pause() == true);
    assert(ctx.service->get_state() == AudioEngineState::PAUSED);
    assert(ctx.service->get_state_string() == "PAUSED");

    assert(ctx.service->resume() == true);
    assert(ctx.service->get_state() == AudioEngineState::PLAYING);

    // Seek
    assert(ctx.service->seek(0.5, false) == true);

    // Volume
    assert(ctx.service->set_volume(0.65f) == true);
    assert(std::abs(ctx.service->get_volume() - 0.65f) < 0.01f);

    // Preload next
    auto preload_res = ctx.service->preload_next(PlaybackTarget::from_file(wav2));
    assert(preload_res.has_value());
    assert(ctx.service->get_audio_engine().get_next_file_path() == wav2);
    // Still playing wav1
    assert(ctx.service->get_current_resolved().has_value());
    assert(ctx.service->get_current_resolved()->file_path == wav1);

    // Simulate gapless advance: engine switches to wav2
    ctx.service->get_audio_engine().play(wav2);
    assert(ctx.service->get_current_file_path() == wav2);
    // get_current_resolved() should promote m_next_resolved to m_current_resolved
    auto promoted = ctx.service->get_current_resolved();
    assert(promoted.has_value());
    assert(promoted->file_path == wav2);

    // Preload again, then test clear_preload_next
    assert(ctx.service->preload_next(PlaybackTarget::from_file(wav1)).has_value());
    assert(ctx.service->clear_preload_next() == true);
    assert(ctx.service->get_audio_engine().get_next_file_path().empty());

    // Desync test: if engine switches to an unknown file path not tracked
    ctx.service->get_audio_engine().play((std::filesystem::path(ctx.temp_dir) / "unknown.wav").string());
    assert(!ctx.service->get_current_resolved().has_value());

    // Stop
    assert(ctx.service->stop() == true);
    assert(ctx.service->get_state() == AudioEngineState::STOPPED);
    assert(!ctx.service->get_current_resolved().has_value());
}

void test_seamless_promotion_and_preload_reset(const std::string &base_dir) {
    std::cout << "[Test H] Seamless transition promotion in preload_next and unconditional preload reset in play()..." << std::endl;
    TestContext ctx(base_dir, "test_h");

    std::string wav1 = (std::filesystem::path(ctx.temp_dir) / "track1.wav").string();
    write_dummy_wav(wav1, 2.0, 44100, 2);
    std::string wav2 = (std::filesystem::path(ctx.temp_dir) / "track2.wav").string();
    write_dummy_wav(wav2, 2.0, 44100, 2);
    std::string wav3 = (std::filesystem::path(ctx.temp_dir) / "track3.wav").string();
    write_dummy_wav(wav3, 2.0, 44100, 2);

    // 1. Play wav1
    auto play1_res = ctx.service->play(PlaybackTarget::from_file(wav1));
    assert(play1_res.has_value());
    assert(ctx.service->get_current_resolved().has_value());
    assert(ctx.service->get_current_resolved()->file_path == wav1);

    // 2. Preload wav2
    auto preload_res = ctx.service->preload_next(PlaybackTarget::from_file(wav2));
    assert(preload_res.has_value());
    assert(ctx.service->get_audio_engine().get_next_file_path() == wav2);

    // 3. Audio engine seamlessly switches to wav2 (simulating track end advance)
    ctx.service->get_audio_engine().play(wav2);
    assert(ctx.service->get_audio_engine().get_current_file_path() == wav2);

    // 4. Client preloads wav3 WITHOUT calling get_current_resolved() first
    // preload_next() must promote m_next_resolved (wav2) to m_current_resolved before setting wav3
    auto preload3_res = ctx.service->preload_next(PlaybackTarget::from_file(wav3));
    assert(preload3_res.has_value());
    assert(ctx.service->get_audio_engine().get_next_file_path() == wav3);

    // Verify m_current_resolved is now wav2 (was promoted) rather than losing track and returning nullopt
    auto current_res = ctx.service->get_current_resolved();
    assert(current_res.has_value());
    assert(current_res->file_path == wav2);

    // 5. Unconditional reset of preloaded next in play()
    // Currently, next is wav3. Calling play(wav1) must reset m_next_resolved and engine next decoder
    auto play_again = ctx.service->play(PlaybackTarget::from_file(wav1));
    assert(play_again.has_value());
    assert(ctx.service->get_current_resolved().has_value());
    assert(ctx.service->get_current_resolved()->file_path == wav1);
    assert(ctx.service->get_audio_engine().get_next_file_path().empty());

    // Stop
    assert(ctx.service->stop() == true);
    assert(!ctx.service->get_current_resolved().has_value());

    // 6. Test directory check in resolve_direct_file (!is_regular_file)
    auto dir_target = PlaybackTarget::from_file(ctx.temp_dir);
    auto dir_res = ctx.service->resolve(dir_target);
    assert(!dir_res.has_value());
    assert(dir_res.error().code == PlaybackErrorCode::CasObjectMissing);

    // 7. Test get_output_device forwarding
    assert(ctx.service->get_output_device() == ctx.service->get_audio_engine().get_output_device());
}

int main(int argc, char *argv[]) {
    std::string temp_dir;
    bool created_temp = false;
    if (argc > 1) {
        temp_dir = argv[1];
    } else {
        temp_dir = (std::filesystem::temp_directory_path() / "lyra_playback_service_test").string();
        std::filesystem::create_directories(temp_dir);
        created_temp = true;
    }

    try {
        test_direct_file_playback(temp_dir);
        test_asset_resolution_and_cas_discovery(temp_dir);
        test_audio_format_preference_scoring(temp_dir);
        test_track_star_topology_and_master_resolution(temp_dir);
        test_missing_cas_file_error_handling(temp_dir);
        test_version_comparison(temp_dir);
        test_transport_controls(temp_dir);
        test_seamless_promotion_and_preload_reset(temp_dir);
    } catch (const std::exception &e) {
        std::cerr << "Exception in PlaybackService tests: " << e.what() << std::endl;
        if (created_temp) {
            std::error_code ec;
            std::filesystem::remove_all(temp_dir, ec);
        }
        return 1;
    }

    if (created_temp) {
        std::error_code ec;
        std::filesystem::remove_all(temp_dir, ec);
    }

    std::cout << "ALL_PLAYBACK_SERVICE_TESTS_PASSED" << std::endl;
    return 0;
}
