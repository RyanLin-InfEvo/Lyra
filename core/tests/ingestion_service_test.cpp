/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/services/configuration_service.h"
#include "../src/services/database_context.h"
#include "../src/services/ingestion_service.h"
#include "../src/services/repositories/sqlite/sqlite_album_repository.h"
#include "../src/services/repositories/sqlite/sqlite_artist_repository.h"
#include "../src/services/repositories/sqlite/sqlite_asset_repository.h"
#include "../src/services/repositories/sqlite/sqlite_audio_repository.h"
#include "../src/services/repositories/sqlite/sqlite_image_repository.h"
#include "../src/services/repositories/sqlite/sqlite_source_data_repository.h"
#include "../src/services/repositories/sqlite/sqlite_track_repository.h"
#include "../src/services/waveform_service.h"
#include "../src/utils/storage_helper.h"
#include <cassert>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using namespace lyra;

namespace {

void write_dummy_wav(const std::string &filepath, double duration = 1.0, int sample_rate = 44100, int channels = 2) {
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

} // namespace

bool test_ingest_asset_workflow(const std::string &temp_dir) {
    std::cout << "Running test_ingest_asset_workflow..." << std::endl;

    std::string db_path = (std::filesystem::path(temp_dir) / "test_ingest.db").string();
    SqliteDatabaseContext ctx(db_path);

    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);
    SqliteAudioRepository audio_repo(ctx);
    SqliteTrackRepository track_repo(ctx);
    SqliteImageRepository image_repo(ctx);
    SqliteSourceDataRepository source_data_repo(ctx);

    IngestionService service(ctx, asset_repo, audio_repo, artist_repo, album_repo, track_repo, temp_dir, &image_repo, &source_data_repo);

    std::string wav_path = (std::filesystem::path(temp_dir) / "test_ingest.wav").string();
    write_dummy_wav(wav_path, 1.0, 44100, 2);

    // 1. Ingest asset
    auto ingest_res = service.ingest_asset(wav_path);
    if (!ingest_res.has_value()) {
        std::cerr << "ingest_asset failed: " << ingest_res.error() << std::endl;
        return false;
    }

    std::string file_hash = ingest_res.value().asset.file_hash;
    std::string pcm_hash = ingest_res.value().metadata["pcm_hash"].get<std::string>();

    assert(!file_hash.empty());
    assert(!pcm_hash.empty());

    // 1b. Verify Source_Data auto-recorded
    auto sd_res = source_data_repo.get_by_asset(file_hash);
    if (!sd_res.has_value()) {
        std::cerr << "Expected Source_Data after ingest_asset: " << sd_res.error() << std::endl;
        return false;
    }
    assert(!sd_res.value().id.empty());
    assert(sd_res.value().file_hash == file_hash);
    assert(sd_res.value().source_type.empty());
    assert(sd_res.value().original_path == wav_path);
    assert(!sd_res.value().created_at.empty());

    // 2. Verify CAS file exists
    auto cas_path = utils::StorageHelper::resolve_cas_path(temp_dir, file_hash, ".wav");
    if (!std::filesystem::exists(cas_path)) {
        std::cerr << "CAS file not found at " << cas_path << std::endl;
        return false;
    }

    // 3. Verify deduplication (and no duplicate Source_Data created)
    auto dup_res = service.ingest_asset(wav_path);
    if (!dup_res.has_value()) {
        std::cerr << "Duplicate ingest_asset failed: " << dup_res.error() << std::endl;
        return false;
    }
    assert(dup_res.value().asset.file_hash == file_hash);
    assert(dup_res.value().metadata["pcm_hash"].get<std::string>() == pcm_hash);
    auto sd_list = source_data_repo.list_by_asset(file_hash);
    assert(sd_list.has_value() && sd_list.value().size() == 1);

    // 4. Non-existent file test
    auto non_existent_res = service.ingest_asset((std::filesystem::path(temp_dir) / "non_existent.wav").string());
    assert(!non_existent_res.has_value());

    return true;
}

bool test_import_track_workflow(const std::string &temp_dir) {
    std::cout << "Running test_import_track_workflow..." << std::endl;

    std::string db_path = (std::filesystem::path(temp_dir) / "test_import.db").string();
    SqliteDatabaseContext ctx(db_path);

    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);
    SqliteAudioRepository audio_repo(ctx);
    SqliteTrackRepository track_repo(ctx);
    SqliteImageRepository image_repo(ctx);
    SqliteSourceDataRepository source_data_repo(ctx);

    IngestionService service(ctx, asset_repo, audio_repo, artist_repo, album_repo, track_repo, temp_dir, &image_repo, &source_data_repo);

    std::string wav_path = (std::filesystem::path(temp_dir) / "my_track_song.wav").string();
    write_dummy_wav(wav_path, 1.5, 44100, 2);

    TrackImportRequest req;
    req.source_path = wav_path;

    auto import_res = service.import_track(req);
    if (!import_res.has_value()) {
        std::cerr << "import_track failed: " << import_res.error() << std::endl;
        return false;
    }

    const auto &val = import_res.value();
    assert(!val.track_id.empty());
    assert(!val.pcm_hash.empty());
    assert(val.title == "my_track_song");

    // Verify track in repository
    auto track_res = track_repo.get(val.track_id);
    if (!track_res.has_value()) {
        std::cerr << "Track not found in repo: " << track_res.error() << std::endl;
        return false;
    }
    assert(track_res.value().pcm_hash == val.pcm_hash);
    assert(track_res.value().title.value_or("") == "my_track_song");

    // Verify Source_Data auto-recorded for imported track's asset
    auto assets_res = asset_repo.get_assets_by_audio(val.pcm_hash);
    assert(assets_res.has_value() && !assets_res.value().empty());
    auto sd_res = source_data_repo.get_by_asset(assets_res.value()[0]);
    if (!sd_res.has_value()) {
        std::cerr << "Expected Source_Data after import_track: " << sd_res.error() << std::endl;
        return false;
    }
    assert(sd_res.value().source_type.empty());
    assert(sd_res.value().original_path == wav_path);
    assert(sd_res.value().note.empty());
    assert(!sd_res.value().created_at.empty());

    // Custom source_type & note via ingest_asset
    std::string cd_wav_path = (std::filesystem::path(temp_dir) / "cd_rip_song.wav").string();
    write_dummy_wav(cd_wav_path, 1.2, 44100, 2);
    auto custom_ingest_res = service.ingest_asset(cd_wav_path, "  CD RIP  ", "EAC v1.6 lossless rip");
    if (!custom_ingest_res.has_value()) {
        std::cerr << "Custom ingest_asset failed: " << custom_ingest_res.error() << std::endl;
        return false;
    }
    auto cd_sd_res = source_data_repo.get_by_asset(custom_ingest_res.value().asset.file_hash);
    assert(cd_sd_res.has_value());
    assert(cd_sd_res.value().source_type == "CD RIP");
    assert(cd_sd_res.value().note == "EAC v1.6 lossless rip");
    assert(cd_sd_res.value().original_path == cd_wav_path);

    // Blank source_type falls back to empty (stored as SQL NULL)
    std::string blank_wav_path = (std::filesystem::path(temp_dir) / "blank_source_type.wav").string();
    write_dummy_wav(blank_wav_path, 1.3, 44100, 2);
    auto blank_ingest_res = service.ingest_asset(blank_wav_path, "   ", "Fallback note");
    assert(blank_ingest_res.has_value());
    auto blank_sd_res = source_data_repo.get_by_asset(blank_ingest_res.value().asset.file_hash);
    assert(blank_sd_res.has_value());
    assert(blank_sd_res.value().source_type.empty());
    assert(blank_sd_res.value().note == "Fallback note");

    // Custom source_type & note via import_track
    std::string yt_wav_path = (std::filesystem::path(temp_dir) / "yt_music_song.wav").string();
    write_dummy_wav(yt_wav_path, 1.4, 44100, 2);
    TrackImportRequest custom_req;
    custom_req.source_path = yt_wav_path;
    custom_req.source_type = "YouTube Music";
    custom_req.note = "Downloaded via yt-dlp";
    auto custom_import_res = service.import_track(custom_req);
    assert(custom_import_res.has_value());
    auto yt_assets_res = asset_repo.get_assets_by_audio(custom_import_res.value().pcm_hash);
    assert(yt_assets_res.has_value() && !yt_assets_res.value().empty());
    auto yt_sd_res = source_data_repo.get_by_asset(yt_assets_res.value()[0]);
    assert(yt_sd_res.has_value());
    assert(yt_sd_res.value().source_type == "YouTube Music");
    assert(yt_sd_res.value().note == "Downloaded via yt-dlp");
    assert(yt_sd_res.value().original_path == yt_wav_path);

    return true;
}

bool test_ingestion_waveform_mode(const std::string &temp_dir) {
    std::cout << "Running test_ingestion_waveform_mode..." << std::endl;

    const std::filesystem::path root = std::filesystem::path(temp_dir) / "wf_mode_test";
    std::filesystem::remove_all(root);
    std::filesystem::create_directories(root);

    const std::string db_path = (root / "lyra.db").string();
    SqliteDatabaseContext ctx(db_path);
    ConfigurationService config_svc(ctx, root.string(), nullptr, db_path);

    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);
    SqliteAudioRepository audio_repo(ctx);
    SqliteTrackRepository track_repo(ctx);
    SqliteImageRepository image_repo(ctx);
    SqliteSourceDataRepository source_data_repo(ctx);

    IngestionService service(ctx,
                             asset_repo,
                             audio_repo,
                             artist_repo,
                             album_repo,
                             track_repo,
                             root.string(),
                             &image_repo,
                             &source_data_repo,
                             nullptr,
                             &config_svc);

    auto write_tone_wav = [](const std::string &filepath, int16_t sample_val) {
        std::ofstream out(filepath, std::ios::binary);
        const int sample_rate = 44100;
        const int channels = 2;
        const int num_frames = sample_rate / 2;
        const int num_samples = num_frames * channels;
        const int data_size = num_samples * 2;
        const uint32_t cs = static_cast<uint32_t>(36 + data_size);
        out.write("RIFF", 4);
        out.write(reinterpret_cast<const char *>(&cs), 4);
        out.write("WAVEfmt ", 8);
        uint32_t sub1 = 16;
        uint16_t fmt_tag = 1;
        uint16_t ch = channels;
        uint32_t sr = sample_rate;
        uint32_t br = sample_rate * channels * 2;
        uint16_t align = channels * 2;
        uint16_t bits = 16;
        out.write(reinterpret_cast<const char *>(&sub1), 4);
        out.write(reinterpret_cast<const char *>(&fmt_tag), 2);
        out.write(reinterpret_cast<const char *>(&ch), 2);
        out.write(reinterpret_cast<const char *>(&sr), 4);
        out.write(reinterpret_cast<const char *>(&br), 4);
        out.write(reinterpret_cast<const char *>(&align), 2);
        out.write(reinterpret_cast<const char *>(&bits), 2);
        out.write("data", 4);
        uint32_t ds = static_cast<uint32_t>(data_size);
        out.write(reinterpret_cast<const char *>(&ds), 4);
        std::vector<int16_t> samples(num_samples, sample_val);
        out.write(reinterpret_cast<const char *>(samples.data()), data_size);
    };

    // 1. fast mode skips waveform precomputation
    auto fast_res = config_svc.update_config(nlohmann::json{{"ingestion", {{"mode", "fast"}}}});
    assert(fast_res.has_value());

    std::string fast_asset_wav = (root / "fast_asset.wav").string();
    std::string fast_track_wav = (root / "fast_track.wav").string();
    write_tone_wav(fast_asset_wav, 1111);
    write_tone_wav(fast_track_wav, 2222);

    auto ingest_fast = service.ingest_asset(fast_asset_wav);
    assert(ingest_fast.has_value());
    std::string pcm_fast_asset = ingest_fast.value().metadata["pcm_hash"].get<std::string>();
    assert(!std::filesystem::exists(WaveformService::get_cache_path(root, pcm_fast_asset)));

    TrackImportRequest fast_req;
    fast_req.source_path = fast_track_wav;
    auto import_fast = service.import_track(fast_req);
    assert(import_fast.has_value());
    assert(!std::filesystem::exists(WaveformService::get_cache_path(root, import_fast.value().pcm_hash)));

    // 2. full mode precomputes waveform cache for both ingest_asset and import_track
    auto full_res = config_svc.update_config(nlohmann::json{{"ingestion", {{"mode", "full"}}}});
    assert(full_res.has_value());

    std::string full_asset_wav = (root / "full_asset.wav").string();
    std::string full_track_wav = (root / "full_track.wav").string();
    write_tone_wav(full_asset_wav, 3333);
    write_tone_wav(full_track_wav, 4444);

    auto ingest_full = service.ingest_asset(full_asset_wav);
    assert(ingest_full.has_value());
    std::string pcm_full_asset = ingest_full.value().metadata["pcm_hash"].get<std::string>();
    assert(std::filesystem::exists(WaveformService::get_cache_path(root, pcm_full_asset)));

    TrackImportRequest full_req;
    full_req.source_path = full_track_wav;
    auto import_full = service.import_track(full_req);
    assert(import_full.has_value());
    assert(std::filesystem::exists(WaveformService::get_cache_path(root, import_full.value().pcm_hash)));

    // 3. Corrupted waveform cache self-heals on re-ingest under full mode (MEDIUM-4)
    const auto full_cache_path = WaveformService::get_cache_path(root, pcm_full_asset);
    {
        std::ofstream corrupt_out(full_cache_path, std::ios::binary | std::ios::trunc);
        corrupt_out.write("BAD_DATA", 8);
    }
    assert(std::filesystem::file_size(full_cache_path) == 8);
    auto heal_res = service.ingest_asset(full_asset_wav);
    assert(heal_res.has_value());
    assert(std::filesystem::is_regular_file(full_cache_path));
    assert(std::filesystem::file_size(full_cache_path) == 12016);
    {
        std::ifstream magic_in(full_cache_path, std::ios::binary);
        char magic[4] = {};
        magic_in.read(magic, 4);
        assert(std::string(magic, 4) == "LWAV");
    }

    // 4. Dedup CAS target replaced with directory must not throw and falls back to source_path (MEDIUM-1)
    const std::string fast_file_hash = ingest_fast.value().asset.file_hash;
    const auto fast_cas_path = utils::StorageHelper::resolve_cas_path(root.string(), fast_file_hash, ".wav");
    std::filesystem::remove(fast_cas_path);
    std::filesystem::create_directories(fast_cas_path);
    const auto fast_cache_path = WaveformService::get_cache_path(root, pcm_fast_asset);
    std::filesystem::remove(fast_cache_path);

    auto dedup_dir_res = service.ingest_asset(fast_asset_wav);
    assert(dedup_dir_res.has_value());
    assert(std::filesystem::is_regular_file(fast_cache_path));
    assert(std::filesystem::file_size(fast_cache_path) == 12016);

    std::filesystem::remove_all(root);
    return true;
}

bool test_configuration_service_path_normalization() {
    std::cout << "Running test_configuration_service_path_normalization..." << std::endl;

    SqliteDatabaseContext mem_ctx(":memory:");

    ConfigurationService mem_cfg(mem_ctx, "", nullptr, ":memory:");
    assert(mem_cfg.get_storage_root().empty());
    assert(mem_cfg.get_database_path() == ":memory:");
    assert(mem_cfg.get_cas_objects_dir().empty());

    ConfigurationService empty_cfg(mem_ctx, "", nullptr, "");
    assert(empty_cfg.get_storage_root().empty());
    assert(empty_cfg.get_database_path().empty());
    assert(empty_cfg.get_cas_objects_dir().empty());

    ConfigurationService slash_cfg(mem_ctx, "/tmp/lyra/", nullptr, "/tmp/lyra//lyra.db");
    assert(slash_cfg.get_storage_root() == "/tmp/lyra");
    assert(slash_cfg.get_database_path() == "/tmp/lyra/lyra.db");
    assert(slash_cfg.get_cas_objects_dir() == "/tmp/lyra/objects");

    ConfigurationService root_cfg(mem_ctx, "/", nullptr, "/lyra.db");
    assert(root_cfg.get_storage_root() == "/");
    assert(root_cfg.get_database_path() == "/lyra.db");
    assert(root_cfg.get_cas_objects_dir() == "/objects");

    ConfigurationService dot_cfg(mem_ctx, ".", nullptr, "");
    assert(dot_cfg.get_storage_root() == ".");
    assert(dot_cfg.get_database_path() == "lyra.db");
    assert(dot_cfg.get_cas_objects_dir() == "objects");

    return true;
}

int main(int argc, char *argv[]) {
    std::string temp_dir = ".";
    if (argc > 1) {
        temp_dir = argv[1];
    }

    bool success = true;
    try {
        if (!test_ingest_asset_workflow(temp_dir)) success = false;
        if (!test_import_track_workflow(temp_dir)) success = false;
        if (!test_ingestion_waveform_mode(temp_dir)) success = false;
        if (!test_configuration_service_path_normalization()) success = false;
    } catch (const std::exception &e) {
        std::cerr << "Exception in IngestionService tests: " << e.what() << std::endl;
        success = false;
    }

    if (success) {
        std::cout << "ALL_INGESTION_SERVICE_TESTS_PASSED" << std::endl;
        return 0;
    } else {
        std::cerr << "SOME INGESTION SERVICE TESTS FAILED" << std::endl;
        return 1;
    }
}
