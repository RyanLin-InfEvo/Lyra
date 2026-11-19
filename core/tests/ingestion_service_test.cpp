/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/services/database_context.h"
#include "../src/services/ingestion_service.h"
#include "../src/services/repositories/sqlite/sqlite_album_repository.h"
#include "../src/services/repositories/sqlite/sqlite_artist_repository.h"
#include "../src/services/repositories/sqlite/sqlite_asset_repository.h"
#include "../src/services/repositories/sqlite/sqlite_audio_repository.h"
#include "../src/services/repositories/sqlite/sqlite_image_repository.h"
#include "../src/services/repositories/sqlite/sqlite_source_data_repository.h"
#include "../src/services/repositories/sqlite/sqlite_track_repository.h"
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

int main(int argc, char *argv[]) {
    std::string temp_dir = ".";
    if (argc > 1) {
        temp_dir = argv[1];
    }

    bool success = true;
    try {
        if (!test_ingest_asset_workflow(temp_dir)) success = false;
        if (!test_import_track_workflow(temp_dir)) success = false;
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
