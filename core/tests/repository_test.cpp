/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/models/asset.h"
#include "../src/models/audio.h"
#include "../src/services/database_context.h"
#include "../src/services/repositories/sqlite/sqlite_album_repository.h"
#include "../src/services/repositories/sqlite/sqlite_artist_repository.h"
#include "../src/services/repositories/sqlite/sqlite_asset_repository.h"
#include "../src/services/repositories/sqlite/sqlite_audio_repository.h"
#include "../src/services/repositories/sqlite/sqlite_playlist_repository.h"
#include "../src/services/repositories/sqlite/sqlite_track_repository.h"
#include "../src/services/repositories/sqlite/sqlite_work_repository.h"
#include <cassert>
#include <filesystem>
#include <iostream>

using namespace lyra;

bool test_artist_get_by_name(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_artist_get_by_name..." << std::endl;
    SqliteArtistRepository repo(ctx);

    // 1. Get non-existent
    auto get_nonexistent = repo.get_by_name("NonExistent Artist");
    assert(get_nonexistent.has_value());
    assert(get_nonexistent.value().empty());

    // 2. Insert and get
    Artist artist;
    artist.id = "artist-id-123456";
    artist.name = "The Beatles";
    artist.musicbrainz_id = "mb-123";
    artist.ytm_id = "yt-123";
    artist.spotify_id = "sp-123";

    auto insert_res = repo.insert(artist);
    assert(insert_res.has_value());

    auto get_existent = repo.get_by_name("The Beatles");
    assert(get_existent.has_value());
    assert(get_existent.value().size() == 1);
    assert(get_existent.value()[0].id == artist.id);
    assert(get_existent.value()[0].name == artist.name);
    assert(get_existent.value()[0].musicbrainz_id == artist.musicbrainz_id);

    // 3. Case-insensitive get (SQLite '=' comparison on text is case-insensitive by default in many contexts, but let's see)
    auto get_case = repo.get_by_name("the beatles");
    assert(get_case.has_value());
    if (!get_case.value().empty()) {
        assert(get_case.value()[0].id == artist.id);
        std::cout << "Artist get_by_name case-insensitive match: SUCCESS" << std::endl;
    } else {
        std::cout << "Artist get_by_name case-insensitive match: NO MATCH (case-sensitive)" << std::endl;
    }

    return true;
}

bool test_album_get_by_title(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_album_get_by_title..." << std::endl;
    SqliteAlbumRepository repo(ctx);

    // 1. Get non-existent
    auto get_nonexistent = repo.get_by_title("NonExistent Album");
    assert(get_nonexistent.has_value());
    assert(get_nonexistent.value().empty());

    // 2. Insert and get
    Album album;
    album.id = "album-id-123456";
    album.title = "Abbey Road";
    album.release_year = 1969;
    album.release_month = 9;
    album.release_day = 26;

    auto insert_res = repo.insert(album);
    assert(insert_res.has_value());

    auto get_existent = repo.get_by_title("Abbey Road");
    assert(get_existent.has_value());
    assert(get_existent.value().size() == 1);
    assert(get_existent.value()[0].id == album.id);
    assert(get_existent.value()[0].title == album.title);
    assert(get_existent.value()[0].release_year == album.release_year);

    // 3. Case-insensitive get
    auto get_case = repo.get_by_title("abbey road");
    assert(get_case.has_value());
    if (!get_case.value().empty()) {
        assert(get_case.value()[0].id == album.id);
        std::cout << "Album get_by_title case-insensitive match: SUCCESS" << std::endl;
    } else {
        std::cout << "Album get_by_title case-insensitive match: NO MATCH (case-sensitive)" << std::endl;
    }

    return true;
}

bool test_track_get_by_title(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_track_get_by_title..." << std::endl;
    SqliteTrackRepository repo(ctx);

    // 1. Get non-existent
    auto get_nonexistent = repo.get_by_title("NonExistent Track");
    assert(get_nonexistent.has_value());
    assert(get_nonexistent.value().empty());

    // 2. Insert and get
    Track track;
    track.id = "track-id-123456";
    track.title = "Hey Jude";
    track.pcm_hash = "pcm-hash-heyjude";

    auto insert_res = repo.insert(track);
    assert(insert_res.has_value());

    auto get_existent = repo.get_by_title("Hey Jude");
    assert(get_existent.has_value());
    assert(get_existent.value().size() == 1);
    assert(get_existent.value()[0].id == track.id);
    assert(get_existent.value()[0].title == track.title);
    assert(get_existent.value()[0].pcm_hash == track.pcm_hash);

    return true;
}

bool test_work_get_by_title(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_work_get_by_title..." << std::endl;
    SqliteWorkRepository repo(ctx);

    // 1. Get non-existent
    auto get_nonexistent = repo.get_by_title("NonExistent Work");
    assert(get_nonexistent.has_value());
    assert(get_nonexistent.value().empty());

    // 2. Insert and get
    Work work;
    work.id = "work-id-123456";
    work.title = "Symphony No. 9";

    auto insert_res = repo.insert(work);
    assert(insert_res.has_value());

    auto get_existent = repo.get_by_title("Symphony No. 9");
    assert(get_existent.has_value());
    assert(get_existent.value().size() == 1);
    assert(get_existent.value()[0].id == work.id);
    assert(get_existent.value()[0].title == work.title);

    return true;
}

bool test_playlist_get_by_title(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_playlist_get_by_title..." << std::endl;
    SqlitePlaylistRepository repo(ctx);

    // 1. Get non-existent
    auto get_nonexistent = repo.get_by_title("NonExistent Playlist");
    assert(get_nonexistent.has_value());
    assert(get_nonexistent.value().empty());

    // 2. Insert and get
    Playlist playlist;
    playlist.id = "playlist-id-123456";
    playlist.title = "My Favorites";

    auto insert_res = repo.insert(playlist);
    assert(insert_res.has_value());

    auto get_existent = repo.get_by_title("My Favorites");
    assert(get_existent.has_value());
    assert(get_existent.value().size() == 1);
    assert(get_existent.value()[0].id == playlist.id);
    assert(get_existent.value()[0].title == playlist.title);

    return true;
}

bool test_track_album_relationships(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_track_album_relationships..." << std::endl;
    SqliteTrackRepository track_repo(ctx);
    SqliteAlbumRepository album_repo(ctx);

    // 1. Prepare data (Insert Track & Album)
    Track track;
    track.id = "track-id-rel-1";
    track.title = "Relationship Song";
    track.pcm_hash = "pcm-hash-rel-1";
    assert(track_repo.insert(track).has_value());

    Album album;
    album.id = "album-id-rel-1";
    album.title = "Relationship Album";
    assert(album_repo.insert(album).has_value());

    auto album_before = track_repo.get_album_id_by_track(track.id);
    assert(album_before.has_value() && !album_before.value().has_value());

    // 2. Test add_album success
    TrackAlbumParams params;
    params.track_id = track.id;
    params.album_id = album.id;
    params.position = 5;

    auto add_res = track_repo.add_album(params);
    if (!add_res.has_value()) {
        std::cerr << "add_album failed unexpectedly: " << add_res.error() << std::endl;
        return false;
    }

    auto album_after = track_repo.get_album_id_by_track(track.id);
    assert(album_after.has_value() && album_after.value().has_value() && album_after.value().value() == album.id);

    // Verify database record
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_query(db, "SELECT position FROM Track_Album WHERE track_id = ? AND album_id = ?");
        check_query.bind(1, track.id);
        check_query.bind(2, album.id);
        if (!check_query.executeStep()) {
            std::cerr << "Track_Album relation record not found in db" << std::endl;
            return false;
        }
        int pos = check_query.getColumn(0).getInt();
        if (pos != 5) {
            std::cerr << "Expected position 5, got " << pos << std::endl;
            return false;
        }
    }

    // 3. Test update_album success
    params.position = 10;
    auto update_res = track_repo.update_album(params);
    if (!update_res.has_value()) {
        std::cerr << "update_album failed unexpectedly: " << update_res.error() << std::endl;
        return false;
    }

    // Verify updated position
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_query(db, "SELECT position FROM Track_Album WHERE track_id = ? AND album_id = ?");
        check_query.bind(1, track.id);
        check_query.bind(2, album.id);
        if (!check_query.executeStep()) {
            std::cerr << "Track_Album relation record not found in db after update" << std::endl;
            return false;
        }
        int pos = check_query.getColumn(0).getInt();
        if (pos != 10) {
            std::cerr << "Expected updated position 10, got " << pos << std::endl;
            return false;
        }
    }

    // 4. Test remove_album success
    auto remove_res = track_repo.remove_album(track.id, album.id);
    if (!remove_res.has_value()) {
        std::cerr << "remove_album failed unexpectedly: " << remove_res.error() << std::endl;
        return false;
    }

    auto album_after_remove = track_repo.get_album_id_by_track(track.id);
    assert(album_after_remove.has_value() && !album_after_remove.value().has_value());

    // Verify relationship is removed
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_query(db, "SELECT position FROM Track_Album WHERE track_id = ? AND album_id = ?");
        check_query.bind(1, track.id);
        check_query.bind(2, album.id);
        if (check_query.executeStep()) {
            std::cerr << "Track_Album relation record still exists in db after removal" << std::endl;
            return false;
        }
    }

    // 5. Test exceptions & boundary cases
    // Case A: Target Track not found
    {
        TrackAlbumParams invalid_params;
        invalid_params.track_id = "nonexistent-track";
        invalid_params.album_id = album.id;
        invalid_params.position = 1;
        auto res = track_repo.add_album(invalid_params);
        if (res.has_value()) {
            std::cerr << "add_album succeeded unexpectedly for non-existent track" << std::endl;
            return false;
        }
        if (res.error().find("Target Track not found.") == std::string::npos) {
            std::cerr << "Expected error 'Target Track not found.', got: " << res.error() << std::endl;
            return false;
        }
    }

    // Case B: Target Album not found
    {
        TrackAlbumParams invalid_params;
        invalid_params.track_id = track.id;
        invalid_params.album_id = "nonexistent-album";
        invalid_params.position = 1;
        auto res = track_repo.add_album(invalid_params);
        if (res.has_value()) {
            std::cerr << "add_album succeeded unexpectedly for non-existent album" << std::endl;
            return false;
        }
        if (res.error().find("Target Album not found.") == std::string::npos) {
            std::cerr << "Expected error 'Target Album not found.', got: " << res.error() << std::endl;
            return false;
        }
    }

    // Case C: remove_album on non-existent relationship
    {
        auto res = track_repo.remove_album(track.id, album.id); // Already removed above
        if (res.has_value()) {
            std::cerr << "remove_album succeeded unexpectedly on non-existent relationship" << std::endl;
            return false;
        }
        if (res.error().find("Relation not found or already removed.") == std::string::npos) {
            std::cerr << "Expected error 'Relation not found or already removed.', got: " << res.error() << std::endl;
            return false;
        }
    }

    return true;
}

bool test_asset_repository_operations(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_asset_repository_operations..." << std::endl;
    SqliteAssetRepository repo(ctx);

    // 1. Prepare Audio and Asset data
    Audio audio1;
    audio1.pcm_hash = "pcm-hash-audio1";
    audio1.bit_depth = 16;
    audio1.sample_rate = 44100;
    audio1.channels = 2;
    audio1.duration = 180.5;

    Asset asset1;
    asset1.file_hash = "file-hash-asset1";
    asset1.mime_type = "audio/mpeg";
    asset1.asset_type = "source";
    asset1.file_size = 5000000;

    // 2. Test insert_asset_with_audio
    auto insert_res = repo.insert_asset_with_audio(asset1, audio1);
    if (!insert_res.has_value()) {
        std::cerr << "insert_asset_with_audio failed: " << insert_res.error() << std::endl;
        return false;
    }

    // Verify record in Asset
    auto get_asset_res = repo.get(asset1.file_hash);
    if (!get_asset_res.has_value()) {
        std::cerr << "Failed to get inserted asset: " << get_asset_res.error() << std::endl;
        return false;
    }
    if (get_asset_res.value().file_hash != asset1.file_hash || get_asset_res.value().file_size != asset1.file_size) {
        std::cerr << "Inserted asset mismatch" << std::endl;
        return false;
    }

    // 3. Audio maps to multiple Assets test
    Asset asset2;
    asset2.file_hash = "file-hash-asset2";
    asset2.mime_type = "audio/ogg";
    asset2.asset_type = "transcode";
    asset2.file_size = 3000000;

    auto insert_res2 = repo.insert_asset_with_audio(asset2, audio1); // associate with same audio1
    if (!insert_res2.has_value()) {
        std::cerr << "insert_asset_with_audio (asset2) failed: " << insert_res2.error() << std::endl;
        return false;
    }

    // Call get_assets_by_audio to check if both assets are returned
    auto assets_res = repo.get_assets_by_audio(audio1.pcm_hash);
    if (!assets_res.has_value()) {
        std::cerr << "get_assets_by_audio failed: " << assets_res.error() << std::endl;
        return false;
    }
    if (assets_res.value().size() != 2) {
        std::cerr << "Expected 2 assets, got " << assets_res.value().size() << std::endl;
        return false;
    }

    // Check if both file_hashes are in the list
    bool found_asset1 = false;
    bool found_asset2 = false;
    for (const auto &hash : assets_res.value()) {
        if (hash == asset1.file_hash) found_asset1 = true;
        if (hash == asset2.file_hash) found_asset2 = true;
    }
    if (!found_asset1 || !found_asset2) {
        std::cerr << "One or both assets not found in get_assets_by_audio result" << std::endl;
        return false;
    }

    // 4. Asset reverse query Audio test
    auto audios_res = repo.get_audio_by_asset(asset1.file_hash);
    if (!audios_res.has_value()) {
        std::cerr << "get_audio_by_asset failed: " << audios_res.error() << std::endl;
        return false;
    }
    if (audios_res.value().size() != 1 || audios_res.value()[0] != audio1.pcm_hash) {
        std::cerr << "Expected 1 audio with pcm_hash 'pcm-hash-audio1', got mismatch" << std::endl;
        return false;
    }

    // 5. Exception query test
    // Non-existent pcm_hash -> should return empty list
    auto empty_assets = repo.get_assets_by_audio("nonexistent-pcm");
    if (!empty_assets.has_value()) {
        std::cerr << "get_assets_by_audio for nonexistent pcm failed" << std::endl;
        return false;
    }
    if (!empty_assets.value().empty()) {
        std::cerr << "Expected empty assets list, got size: " << empty_assets.value().size() << std::endl;
        return false;
    }

    // Non-existent file_hash -> should return empty list
    auto empty_audios = repo.get_audio_by_asset("nonexistent-file");
    if (!empty_audios.has_value()) {
        std::cerr << "get_audio_by_asset for nonexistent file failed" << std::endl;
        return false;
    }
    if (!empty_audios.value().empty()) {
        std::cerr << "Expected empty audios list, got size: " << empty_audios.value().size() << std::endl;
        return false;
    }

    // Get non-existent asset -> should return unexpected
    auto nonexistent_asset = repo.get("nonexistent-file");
    if (nonexistent_asset.has_value()) {
        std::cerr << "Expected get for nonexistent asset to fail" << std::endl;
        return false;
    }

    return true;
}

bool test_audio_get_related_versions(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_audio_get_related_versions..." << std::endl;
    SqliteAudioRepository repo(ctx);

    // 1. Non-existent audio -> error
    auto err_res = repo.get_related_versions("non-existent-hash");
    assert(!err_res.has_value());
    assert(err_res.error() == "Audio not found.");

    // 2. Standalone audio (root with no parent and no children)
    Audio standalone;
    standalone.pcm_hash = "standalone-pcm";
    standalone.sample_rate = 44100;
    assert(repo.insert(standalone).has_value());

    auto standalone_res = repo.get_related_versions("standalone-pcm");
    assert(standalone_res.has_value());
    assert(standalone_res->size() == 1);
    assert((*standalone_res)[0].pcm_hash == "standalone-pcm");

    // 3. Audio family: root -> child1, child2
    Audio root_audio;
    root_audio.pcm_hash = "pcm-family-root";
    root_audio.sample_rate = 96000;
    root_audio.bit_depth = 24;
    assert(repo.insert(root_audio).has_value());

    Audio child1;
    child1.pcm_hash = "pcm-family-child-1";
    child1.parent_hash = "pcm-family-root";
    child1.sample_rate = 44100;
    child1.bit_depth = 16;
    assert(repo.insert(child1).has_value());

    Audio child2;
    child2.pcm_hash = "pcm-family-child-2";
    child2.parent_hash = "pcm-family-root";
    child2.sample_rate = 48000;
    child2.bit_depth = 16;
    assert(repo.insert(child2).has_value());

    // Query from child1 should return root and all children
    auto family_from_child1 = repo.get_related_versions("pcm-family-child-1");
    assert(family_from_child1.has_value());
    assert(family_from_child1->size() == 3);

    // Verify all 3 hashes are present
    std::vector<std::string> returned_hashes;
    for (const auto &a : family_from_child1.value()) {
        returned_hashes.push_back(a.pcm_hash);
    }
    assert(std::find(returned_hashes.begin(), returned_hashes.end(), "pcm-family-root") != returned_hashes.end());
    assert(std::find(returned_hashes.begin(), returned_hashes.end(), "pcm-family-child-1") != returned_hashes.end());
    assert(std::find(returned_hashes.begin(), returned_hashes.end(), "pcm-family-child-2") != returned_hashes.end());

    // Query from root
    auto family_from_root = repo.get_related_versions("pcm-family-root");
    assert(family_from_root.has_value());
    assert(family_from_root->size() == 3);

    // 4. Dangling parent_hash auto-healing (simulating corrupted / legacy imported data)
    ctx.get_db().exec("PRAGMA foreign_keys = OFF;");
    Audio dangling;
    dangling.pcm_hash = "pcm-dangling-child";
    dangling.parent_hash = "non-existent-master";
    dangling.sample_rate = 44100;
    dangling.bit_depth = 16;
    assert(repo.insert(dangling).has_value());
    ctx.get_db().exec("PRAGMA foreign_keys = ON;");

    // Verify parent_hash is set before healing
    auto dangling_before = repo.get("pcm-dangling-child");
    assert(dangling_before.has_value());
    assert(dangling_before->parent_hash == "non-existent-master");

    // get_related_versions should detect dangling parent, auto-heal DB record to NULL, and return as standalone root
    auto dangling_res = repo.get_related_versions("pcm-dangling-child");
    assert(dangling_res.has_value());
    assert(dangling_res->size() == 1);
    assert((*dangling_res)[0].pcm_hash == "pcm-dangling-child");

    // Verify in database that parent_hash is healed to NULL / empty
    auto dangling_after = repo.get("pcm-dangling-child");
    assert(dangling_after.has_value());
    assert(dangling_after->parent_hash.empty());

    return true;
}

int main() {
    std::string db_path = "test_repo.db";
    std::filesystem::remove(db_path);

    bool success = true;
    try {
        SqliteDatabaseContext ctx(db_path);
        if (!test_artist_get_by_name(ctx)) success = false;
        if (!test_album_get_by_title(ctx)) success = false;
        if (!test_track_get_by_title(ctx)) success = false;
        if (!test_work_get_by_title(ctx)) success = false;
        if (!test_playlist_get_by_title(ctx)) success = false;
        if (!test_track_album_relationships(ctx)) success = false;
        if (!test_asset_repository_operations(ctx)) success = false;
        if (!test_audio_get_related_versions(ctx)) success = false;
    } catch (const std::exception &e) {
        std::cerr << "Exception in repository tests: " << e.what() << std::endl;
        success = false;
    }

    std::filesystem::remove(db_path);
    if (success) {
        std::cout << "ALL_REPOSITORY_TESTS_PASSED" << std::endl;
        return 0;
    } else {
        std::cerr << "SOME REPOSITORY TESTS FAILED" << std::endl;
        return 1;
    }
}
