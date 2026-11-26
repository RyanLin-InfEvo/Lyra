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

    // Query from child1 should return root and all children (Master first)
    auto family_from_child1 = repo.get_related_versions("pcm-family-child-1");
    assert(family_from_child1.has_value());
    assert(family_from_child1->size() == 3);
    assert((*family_from_child1)[0].pcm_hash == "pcm-family-root");

    // Verify all 3 hashes are present
    std::vector<std::string> returned_hashes;
    for (const auto &a : family_from_child1.value()) {
        returned_hashes.push_back(a.pcm_hash);
    }
    assert(std::find(returned_hashes.begin(), returned_hashes.end(), "pcm-family-root") != returned_hashes.end());
    assert(std::find(returned_hashes.begin(), returned_hashes.end(), "pcm-family-child-1") != returned_hashes.end());
    assert(std::find(returned_hashes.begin(), returned_hashes.end(), "pcm-family-child-2") != returned_hashes.end());

    // Query from root (attach two assets in reverse hash order -> verify deterministic file_hash ASC)
    SqliteAssetRepository asset_repo(ctx);
    Asset asset_z{"file-z-asset", "audio/mpeg", "audio", 8000000, ""};
    Asset asset_a{"file-a-asset", "audio/flac", "audio", 40000000, ""};
    assert(asset_repo.insert_asset_with_audio(asset_z, root_audio).has_value());
    assert(asset_repo.insert_asset_with_audio(asset_a, root_audio).has_value());

    auto family_from_root = repo.get_related_versions("pcm-family-root");
    assert(family_from_root.has_value());
    assert(family_from_root->size() == 3);
    assert((*family_from_root)[0].pcm_hash == "pcm-family-root");
    assert((*family_from_root)[0].assets.size() == 2);
    assert((*family_from_root)[0].assets[0].file_hash == "file-a-asset");
    assert((*family_from_root)[0].assets[1].file_hash == "file-z-asset");

    // Verify get_related_versions propagates DB errors instead of returning false "Audio not found."
    {
        const std::string err_db_path = "test_repo_audio_err.db";
        std::filesystem::remove(err_db_path);
        {
            SqliteDatabaseContext err_ctx(err_db_path);
            SqliteAudioRepository err_audio_repo(err_ctx);
            Audio a;
            a.pcm_hash = "pcm-err-check";
            assert(err_audio_repo.insert(a).has_value());
            err_ctx.get_db().exec("DROP TABLE Audio_Asset;");
            auto db_err_res = err_audio_repo.get_related_versions("pcm-err-check");
            assert(!db_err_res.has_value());
            assert(db_err_res.error() != "Audio not found.");
        }
        std::filesystem::remove(err_db_path);
    }

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

bool test_sqlite_update_builder(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_sqlite_update_builder..." << std::endl;

    // 1. Empty builder
    SqliteUpdateBuilder empty_builder("Album", "test-id-1");
    assert(empty_builder.empty());
    assert(empty_builder.build_sql().empty());
    assert(empty_builder.execute(ctx.get_db()).has_value());

    // 2. Chaining with optionals
    SqliteUpdateBuilder builder("Album", "test-id-2");
    std::optional<std::string> title = "Test Album";
    std::optional<uint16_t> year = 2026;
    std::optional<uint8_t> month = std::nullopt;

    builder.set("title", title)
        .set("release_year", year)
        .set("release_month", month);

    assert(!builder.empty());
    assert(builder.size() == 2);
    assert(builder.build_sql() == "UPDATE \"Album\" SET \"title\" = ?, \"release_year\" = ? WHERE \"id\" = ?");

    // 3. Execution on non-existent record
    auto exec_res = builder.execute(ctx.get_db());
    assert(!exec_res.has_value());
    assert(exec_res.error() == "Album ID not found.");

    // 4. Custom not found message
    builder.set_not_found_message("Custom not found");
    auto custom_res = builder.execute(ctx.get_db());
    assert(!custom_res.has_value());
    assert(custom_res.error() == "Custom not found");

    // 5. Quoted identifiers & SQLite reserved keyword handling
    SqliteUpdateBuilder keyword_builder("order", "item-1", "group");
    keyword_builder.set("index", std::string("first"));
    assert(keyword_builder.build_sql() == "UPDATE \"order\" SET \"index\" = ? WHERE \"group\" = ?");

    // 6. Embedded double quote escaping
    SqliteUpdateBuilder quote_escape_builder("weird\"table", "id-1");
    quote_escape_builder.set("col\"name", 123);
    assert(quote_escape_builder.build_sql() == "UPDATE \"weird\"\"table\" SET \"col\"\"name\" = ? WHERE \"id\" = ?");

    // 7. Safety error when executing without a WHERE clause
    SqliteUpdateBuilder no_where_builder("Album");
    no_where_builder.set("title", std::string("Unsafe Update"));
    auto no_where_res = no_where_builder.execute(ctx.get_db());
    assert(!no_where_res.has_value());
    assert(no_where_res.error() == "Safety Error: Refusing to execute UPDATE without a WHERE clause.");

    // 8. Dangling pointer prevention: passing temporary string / string_view
    {
        SqliteAlbumRepository repo(ctx);
        Album album_temp;
        album_temp.id = "album-temp-str-test";
        album_temp.title = "Original Title";
        assert(repo.insert(album_temp).has_value());

        SqliteUpdateBuilder temp_builder("Album", "album-temp-str-test");
        {
            auto make_temp = []() { return std::string("Updated Via Temporary String"); };
            // Pass string_view of temporary string that will be destroyed after this statement
            temp_builder.set("title", std::string_view(make_temp()));
        }

        // Execute against DB after the temporary objects in the inner scope have been destroyed.
        // If the lambda closure captured by pointer/reference or dangling string_view, this would read invalid memory.
        auto temp_res = temp_builder.execute(ctx.get_db());
        assert(temp_res.has_value());

        auto get_res = repo.get("album-temp-str-test");
        assert(get_res.has_value());
        assert(get_res->title == "Updated Via Temporary String");

        // Also test optional with temporary string_view
        SqliteUpdateBuilder temp_opt_builder("Album", "album-temp-str-test");
        {
            auto make_temp = []() { return std::string("Updated Via Temp Optional"); };
            temp_opt_builder.set("title", std::optional<std::string_view>(make_temp()));
        }
        auto opt_res = temp_opt_builder.execute(ctx.get_db());
        assert(opt_res.has_value());

        auto get_opt_res = repo.get("album-temp-str-test");
        assert(get_opt_res.has_value());
        assert(get_opt_res->title == "Updated Via Temp Optional");
    }

    // 9. set_null method
    {
        SqliteUpdateBuilder null_sql_builder("Track", "track-null-1");
        null_sql_builder.set("title", std::string("Track Title")).set_null("recording_location");
        assert(null_sql_builder.build_sql() ==
               "UPDATE \"Track\" SET \"title\" = ?, \"recording_location\" = NULL WHERE \"id\" = ?");

        SqliteTrackRepository track_repo(ctx);
        Track track_null;
        track_null.id = "track-null-test";
        track_null.pcm_hash = "pcm-hash-null-test";
        track_null.title = "Null Test Title";
        track_null.recording_location = "Tokyo Studio";
        assert(track_repo.insert(track_null).has_value());

        SqliteUpdateBuilder null_exec_builder("Track", track_null.id);
        null_exec_builder.set_null("recording_location");
        auto null_exec_res = null_exec_builder.execute(ctx.get_db());
        assert(null_exec_res.has_value());

        auto get_res = track_repo.get(track_null.id);
        assert(get_res.has_value());
        assert(!get_res->recording_location.has_value());
    }

    return true;
}

bool test_entity_repository_crud(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_entity_repository_crud..." << std::endl;
    SqliteAlbumRepository repo(ctx);

    // 1. Insert
    Album album;
    album.id = "album-crud-1";
    album.title = "CRUD Album 1";
    album.release_year = 2020;
    assert(repo.insert(album).has_value());

    // Verify Entity table
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_entity(db, "SELECT entity_type, created_at, updated_at FROM Entity WHERE id = ?");
        check_entity.bind(1, album.id);
        assert(check_entity.executeStep());
        assert(std::string(check_entity.getColumn(0).getText()) == "album");
        assert(std::string(check_entity.getColumn(1).getText()).size() > 0);
    }

    // 2. Get
    auto get_res = repo.get(album.id);
    assert(get_res.has_value());
    assert(get_res->id == album.id);
    assert(get_res->title == "CRUD Album 1");
    assert(get_res->release_year == 2020);

    // Get non-existent
    auto get_non = repo.get("non-existent-id");
    assert(!get_non.has_value());
    assert(get_non.error() == "Album not found.");

    // 3. Update
    AlbumUpdate update_data;
    update_data.id = album.id;
    update_data.title = "CRUD Album Updated";
    update_data.release_year = 2021;
    assert(repo.update(update_data).has_value());

    auto get_updated = repo.get(album.id);
    assert(get_updated.has_value());
    assert(get_updated->title == "CRUD Album Updated");
    assert(get_updated->release_year == 2021);

    // Update non-existent
    AlbumUpdate unexist_update;
    unexist_update.id = "non-existent-id";
    unexist_update.title = "Should Fail";
    auto update_err = repo.update(unexist_update);
    assert(!update_err.has_value());
    assert(update_err.error() == "Album ID not found.");

    // Empty update on non-existent ID
    AlbumUpdate empty_unexist_update;
    empty_unexist_update.id = "non-existent-id";
    auto empty_unexist_res = repo.update(empty_unexist_update);
    assert(!empty_unexist_res.has_value());
    assert(empty_unexist_res.error() == "Album ID not found.");

    // Empty update on existing ID
    AlbumUpdate empty_exist_update;
    empty_exist_update.id = album.id;
    auto empty_exist_res = repo.update(empty_exist_update);
    assert(empty_exist_res.has_value());

    // 4. List and search
    Album album2;
    album2.id = "album-crud-2";
    album2.title = "Another CRUD Album";
    album2.release_year = 2021;
    assert(repo.insert(album2).has_value());

    auto list_all = repo.list(0, 10, std::nullopt);
    assert(list_all.has_value());
    assert(list_all->total >= 2);

    auto list_search = repo.list(0, 10, "Another");
    assert(list_search.has_value());
    assert(list_search->total == 1);
    assert(list_search->items[0].id == "album-crud-2");

    // 5. get_one_by_field
    auto one_found = repo.get_one_by_field("title", std::string("Another CRUD Album"));
    assert(one_found.has_value());
    assert(one_found->has_value());
    assert(one_found->value().id == "album-crud-2");

    auto one_not_found = repo.get_one_by_field("title", std::string("Nonexistent Title"));
    assert(one_not_found.has_value());
    assert(!one_not_found->has_value());

    // 6. get_by_field with custom ordering
    Album album3;
    album3.id = "album-crud-3";
    album3.title = "Zebra Album";
    album3.release_year = 2021;
    assert(repo.insert(album3).has_value());

    auto field_asc = repo.get_by_field("release_year", 2021, "title", true);
    assert(field_asc.has_value());
    assert(field_asc->size() >= 3);
    // "Another CRUD Album" < "CRUD Album Updated" < "Zebra Album"
    assert(field_asc->front().title == "Another CRUD Album");
    assert(field_asc->back().title == "Zebra Album");

    auto field_desc = repo.get_by_field("release_year", 2021, "title", false);
    assert(field_desc.has_value());
    assert(field_desc->size() >= 3);
    assert(field_desc->front().title == "Zebra Album");
    assert(field_desc->back().title == "Another CRUD Album");

    // 7. touch_entity
    assert(repo.touch_entity(album.id).has_value());
    auto touch_nonexistent = repo.touch_entity("non-existent-album-id");
    assert(!touch_nonexistent.has_value());
    assert(touch_nonexistent.error() == "Album with ID 'non-existent-album-id' not found.");

    return true;
}

bool test_database_triggers_updated_at(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_database_triggers_updated_at..." << std::endl;
    auto &db = ctx.get_db();

    // Verify triggers on Album, Artist, Track, Work, Playlist
    // By updating concrete tables with raw SQL and checking Entity.updated_at
    const std::vector<std::pair<std::string, std::string>> tests = {
        {"Album", "album-id-123456"},
        {"Artist", "artist-id-123456"},
        {"Track", "track-id-123456"},
        {"Work", "work-id-123456"},
        {"Playlist", "playlist-id-123456"},
    };

    for (const auto &[table, id] : tests) {
        // Set Entity.updated_at to a fixed past time
        {
            SQLite::Statement reset_stmt(db, "UPDATE Entity SET updated_at = '2000-01-01 00:00:00' WHERE id = ?");
            reset_stmt.bind(1, id);
            reset_stmt.exec();
        }

        // Verify it was reset
        {
            SQLite::Statement check_stmt(db, "SELECT updated_at FROM Entity WHERE id = ?");
            check_stmt.bind(1, id);
            assert(check_stmt.executeStep());
            assert(std::string(check_stmt.getColumn(0).getText()) == "2000-01-01 00:00:00");
        }

        // Direct SQL update on concrete table to trigger AFTER UPDATE
        {
            std::string update_sql;
            if (table == "Artist") {
                update_sql = "UPDATE Artist SET name = name || '_trg' WHERE id = ?";
            } else {
                update_sql = "UPDATE " + table + " SET title = title || '_trg' WHERE id = ?";
            }
            SQLite::Statement trigger_update(db, update_sql);
            trigger_update.bind(1, id);
            int rows = trigger_update.exec();
            assert(rows == 1);
        }

        // Verify Entity.updated_at was updated by the trigger (no longer 2000-01-01)
        {
            SQLite::Statement check_stmt(db, "SELECT updated_at FROM Entity WHERE id = ?");
            check_stmt.bind(1, id);
            assert(check_stmt.executeStep());
            std::string updated_at = check_stmt.getColumn(0).getText();
            assert(updated_at != "2000-01-01 00:00:00");
            std::cout << "Trigger for " << table << " successfully updated Entity.updated_at to " << updated_at << std::endl;
        }
    }

    return true;
}

bool test_artist_repository_crud(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_artist_repository_crud..." << std::endl;
    SqliteArtistRepository repo(ctx);

    // 1. Insert
    Artist artist;
    artist.id = "artist-crud-1";
    artist.name = "Queen";
    artist.musicbrainz_id = "mb-queen-1";
    artist.spotify_id = "sp-queen-1";
    artist.ytm_id = "yt-queen-1";
    assert(repo.insert(artist).has_value());

    // Verify Entity table
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_entity(db, "SELECT entity_type, created_at, updated_at FROM Entity WHERE id = ?");
        check_entity.bind(1, artist.id);
        assert(check_entity.executeStep());
        assert(std::string(check_entity.getColumn(0).getText()) == "artist");
        assert(std::string(check_entity.getColumn(1).getText()).size() > 0);
    }

    // 2. Get
    auto get_res = repo.get(artist.id);
    assert(get_res.has_value());
    assert(get_res->id == artist.id);
    assert(get_res->name == "Queen");
    assert(get_res->musicbrainz_id == "mb-queen-1");
    assert(get_res->spotify_id == "sp-queen-1");
    assert(get_res->ytm_id == "yt-queen-1");

    // Get non-existent
    auto get_non = repo.get("non-existent-artist-id");
    assert(!get_non.has_value());
    assert(get_non.error() == "Artist not found.");

    // 3. Update
    ArtistUpdate update_data;
    update_data.id = artist.id;
    update_data.name = "Queen Band";
    update_data.spotify_id = "sp-queen-updated";
    assert(repo.update(update_data).has_value());

    auto get_updated = repo.get(artist.id);
    assert(get_updated.has_value());
    assert(get_updated->name == "Queen Band");
    assert(get_updated->spotify_id == "sp-queen-updated");
    assert(get_updated->musicbrainz_id == "mb-queen-1");

    // Update non-existent
    ArtistUpdate unexist_update;
    unexist_update.id = "non-existent-artist-id";
    unexist_update.name = "Should Fail";
    auto update_err = repo.update(unexist_update);
    assert(!update_err.has_value());
    assert(update_err.error() == "Artist ID not found.");

    // Empty update on non-existent ID
    ArtistUpdate empty_unexist_update;
    empty_unexist_update.id = "non-existent-artist-id";
    auto empty_unexist_res = repo.update(empty_unexist_update);
    assert(!empty_unexist_res.has_value());
    assert(empty_unexist_res.error() == "Artist ID not found.");

    // Empty update on existing ID
    ArtistUpdate empty_exist_update;
    empty_exist_update.id = artist.id;
    auto empty_exist_res = repo.update(empty_exist_update);
    assert(empty_exist_res.has_value());

    // 4. get_one_by_field
    auto one_found = repo.get_one_by_field("name", std::string("Queen Band"));
    assert(one_found.has_value());
    assert(one_found->has_value());
    assert(one_found->value().id == artist.id);

    auto one_not_found = repo.get_one_by_field("name", std::string("Unknown Artist"));
    assert(one_not_found.has_value());
    assert(!one_not_found->has_value());

    // 5. List and search
    Artist artist2;
    artist2.id = "artist-crud-2";
    artist2.name = "Queen Latifah";
    assert(repo.insert(artist2).has_value());

    auto list_all = repo.list(0, 10, std::nullopt);
    assert(list_all.has_value());
    assert(list_all->total >= 2);

    auto list_search = repo.list(0, 10, "Latifah");
    assert(list_search.has_value());
    assert(list_search->total == 1);
    assert(list_search->items[0].id == "artist-crud-2");

    // 6. touch_entity
    assert(repo.touch_entity(artist.id).has_value());

    return true;
}

bool test_entity_rollback_on_insert_failure(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_entity_rollback_on_insert_failure..." << std::endl;

    // Case 1: Concrete table constraint failure (e.g. duplicate primary key in Album)
    {
        SqliteAlbumRepository repo(ctx);

        // Directly insert an Album row with foreign keys temporarily off, so Album has the row but Entity does not
        ctx.get_db().exec("PRAGMA foreign_keys = OFF;");
        ctx.get_db().exec("INSERT INTO Album (id, title) VALUES ('dup-album-id', 'Direct Insert');");
        ctx.get_db().exec("PRAGMA foreign_keys = ON;");

        // Verify Entity does NOT have this ID initially
        {
            SQLite::Statement check(ctx.get_db(), "SELECT COUNT(*) FROM Entity WHERE id = 'dup-album-id'");
            assert(check.executeStep() && check.getColumn(0).getInt() == 0);
        }

        // Attempt to insert via repository.
        // Entity insert will succeed, but concrete Album do_insert will throw SQLite::Exception (UNIQUE constraint failed: Album.id)
        Album dup_album;
        dup_album.id = "dup-album-id";
        dup_album.title = "Repo Insert";
        auto insert_res = repo.insert(dup_album);
        assert(!insert_res.has_value());

        // Crucial check: Entity row must have been rolled back and NOT exist
        {
            SQLite::Statement check(ctx.get_db(), "SELECT COUNT(*) FROM Entity WHERE id = 'dup-album-id'");
            assert(check.executeStep());
            int entity_count = check.getColumn(0).getInt();
            assert(entity_count == 0);
        }

        // Clean up direct insert
        ctx.get_db().exec("PRAGMA foreign_keys = OFF;");
        ctx.get_db().exec("DELETE FROM Album WHERE id = 'dup-album-id';");
        ctx.get_db().exec("PRAGMA foreign_keys = ON;");
    }

    // Case 2: Subclass do_insert returns tl::unexpected error
    {
        class FailingEntityRepo : public SqliteEntityRepository<Album, AlbumUpdate> {
          public:
            explicit FailingEntityRepo(IDatabaseContext &c)
                : SqliteEntityRepository(c, "Album", "album", "title") {}

          protected:
            tl::expected<void, std::string> do_insert(SQLite::Database &, const Album &) override {
                return tl::unexpected("simulated do_insert failure");
            }
            void build_update(SqliteUpdateBuilder &, const AlbumUpdate &) const override {}
        };

        FailingEntityRepo failing_repo(ctx);
        Album failing_album;
        failing_album.id = "failing-album-id";
        failing_album.title = "Failing Album";

        auto res = failing_repo.insert(failing_album);
        assert(!res.has_value());
        assert(res.error() == "simulated do_insert failure");

        // Crucial check: Entity row must have been rolled back and NOT exist
        {
            SQLite::Statement check(ctx.get_db(), "SELECT COUNT(*) FROM Entity WHERE id = 'failing-album-id'");
            assert(check.executeStep());
            int entity_count = check.getColumn(0).getInt();
            assert(entity_count == 0);
        }
    }

    return true;
}

bool test_work_repository_crud(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_work_repository_crud..." << std::endl;
    SqliteWorkRepository repo(ctx);

    // 1. Insert
    Work work;
    work.id = "work-crud-1";
    work.title = "Moonlight Sonata";
    work.composition_start_year = 1801;
    work.composition_end_year = 1802;
    work.composition_date_text = "1801-1802";
    work.iswc = "T-000.000.001-Z";
    work.musicbrainz_id = "mb-work-123";
    assert(repo.insert(work).has_value());

    // Verify Entity table
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_entity(db, "SELECT entity_type, created_at, updated_at FROM Entity WHERE id = ?");
        check_entity.bind(1, work.id);
        assert(check_entity.executeStep());
        assert(std::string(check_entity.getColumn(0).getText()) == "work");
        assert(std::string(check_entity.getColumn(1).getText()).size() > 0);
    }

    // 2. Get
    auto get_res = repo.get(work.id);
    assert(get_res.has_value());
    assert(get_res->id == work.id);
    assert(get_res->title == "Moonlight Sonata");
    assert(get_res->composition_start_year == 1801);
    assert(get_res->composition_end_year == 1802);
    assert(get_res->composition_date_text == "1801-1802");
    assert(get_res->iswc == "T-000.000.001-Z");
    assert(get_res->musicbrainz_id == "mb-work-123");

    // Get non-existent
    auto get_non = repo.get("non-existent-work-id");
    assert(!get_non.has_value());
    assert(get_non.error() == "Work not found.");

    // 3. Update
    WorkUpdate update_data;
    update_data.id = work.id;
    update_data.title = "Piano Sonata No. 14";
    update_data.composition_end_year = 1801;
    update_data.iswc = "T-000.000.002-Z";
    assert(repo.update(update_data).has_value());

    auto get_updated = repo.get(work.id);
    assert(get_updated.has_value());
    assert(get_updated->title == "Piano Sonata No. 14");
    assert(get_updated->composition_start_year == 1801);
    assert(get_updated->composition_end_year == 1801);
    assert(get_updated->iswc == "T-000.000.002-Z");
    assert(get_updated->musicbrainz_id == "mb-work-123");

    // Update non-existent
    WorkUpdate unexist_update;
    unexist_update.id = "non-existent-work-id";
    unexist_update.title = "Should Fail";
    auto update_err = repo.update(unexist_update);
    assert(!update_err.has_value());
    assert(update_err.error() == "Work ID not found.");

    // Empty update on non-existent ID
    WorkUpdate empty_unexist_update;
    empty_unexist_update.id = "non-existent-work-id";
    auto empty_unexist_res = repo.update(empty_unexist_update);
    assert(!empty_unexist_res.has_value());
    assert(empty_unexist_res.error() == "Work ID not found.");

    // Empty update on existing ID
    WorkUpdate empty_exist_update;
    empty_exist_update.id = work.id;
    auto empty_exist_res = repo.update(empty_exist_update);
    assert(empty_exist_res.has_value());

    // 4. get_one_by_field / get_by_iswc / get_by_musicbrainz_id via IWorkRepository&
    IWorkRepository &iwork_repo = repo;
    auto iswc_found = iwork_repo.get_by_iswc("T-000.000.002-Z");
    assert(iswc_found.has_value());
    assert(iswc_found->has_value());
    assert(iswc_found->value().id == work.id);

    auto iswc_not_found = iwork_repo.get_by_iswc("non-existent-iswc");
    assert(iswc_not_found.has_value());
    assert(!iswc_not_found->has_value());

    auto mb_found = iwork_repo.get_by_musicbrainz_id("mb-work-123");
    assert(mb_found.has_value());
    assert(mb_found->size() == 1);
    assert(mb_found->front().id == work.id);

    auto mb_not_found = iwork_repo.get_by_musicbrainz_id("non-existent-mb");
    assert(mb_not_found.has_value());
    assert(mb_not_found->empty());

    // 5. List and search
    Work work2;
    work2.id = "work-crud-2";
    work2.title = "Symphony No. 5";
    work2.iswc = "T-000.000.005-Z";
    assert(repo.insert(work2).has_value());

    auto list_all = repo.list(0, 10, std::nullopt);
    assert(list_all.has_value());
    assert(list_all->total >= 2);

    auto list_search = repo.list(0, 10, "Sonata");
    assert(list_search.has_value());
    assert(list_search->total == 1);
    assert(list_search->items[0].id == "work-crud-1");

    // 6. touch_entity
    assert(repo.touch_entity(work.id).has_value());
    auto touch_unexist = repo.touch_entity("non-existent-work-id");
    assert(!touch_unexist.has_value());
    assert(touch_unexist.error() == "Work with ID 'non-existent-work-id' not found.");

    return true;
}

bool test_track_repository_crud(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_track_repository_crud..." << std::endl;
    SqliteTrackRepository repo(ctx);
    SqliteArtistRepository artist_repo(ctx);

    // 1. Insert
    Track track;
    track.id = "track-crud-1";
    track.pcm_hash = "pcm-crud-1-hash";
    track.work_id = "work-crud-1";
    track.title = "Piano Sonata No. 14: Adagio sostenuto";
    track.recording_year = 2021;
    track.recording_month = 5;
    track.recording_day = 12;
    track.recording_location = "Vienna Concert Hall";
    track.duration = 320000;
    track.isrc = "US-ABC-21-00001";
    track.musicbrainz_id = "mb-track-1";
    track.ytm_id = "yt-track-1";
    track.spotify_id = "sp-track-1";
    assert(repo.insert(track).has_value());

    // Verify Entity table
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_entity(db, "SELECT entity_type, created_at, updated_at FROM Entity WHERE id = ?");
        check_entity.bind(1, track.id);
        assert(check_entity.executeStep());
        assert(std::string(check_entity.getColumn(0).getText()) == "track");
        assert(std::string(check_entity.getColumn(1).getText()).size() > 0);
    }

    // 2. Get
    auto get_res = repo.get(track.id);
    assert(get_res.has_value());
    assert(get_res->id == track.id);
    assert(get_res->pcm_hash == "pcm-crud-1-hash");
    assert(get_res->work_id == "work-crud-1");
    assert(get_res->title == "Piano Sonata No. 14: Adagio sostenuto");
    assert(get_res->recording_year == 2021);
    assert(get_res->recording_month == 5);
    assert(get_res->recording_day == 12);
    assert(get_res->recording_location == "Vienna Concert Hall");
    assert(get_res->duration == 320000);
    assert(get_res->isrc == "US-ABC-21-00001");
    assert(get_res->musicbrainz_id == "mb-track-1");
    assert(get_res->ytm_id == "yt-track-1");
    assert(get_res->spotify_id == "sp-track-1");

    // Get non-existent
    auto get_non = repo.get("non-existent-track-id");
    assert(!get_non.has_value());
    assert(get_non.error() == "Track not found.");

    // 3. Update
    TrackUpdate update_data;
    update_data.id = track.id;
    update_data.title = "Adagio sostenuto (Remastered)";
    update_data.duration = 321500;
    update_data.spotify_id = "sp-track-updated";
    assert(repo.update(update_data).has_value());

    auto get_updated = repo.get(track.id);
    assert(get_updated.has_value());
    assert(get_updated->title == "Adagio sostenuto (Remastered)");
    assert(get_updated->duration == 321500);
    assert(get_updated->spotify_id == "sp-track-updated");
    assert(get_updated->pcm_hash == "pcm-crud-1-hash");
    assert(get_updated->recording_year == 2021);

    // Update non-existent
    TrackUpdate unexist_update;
    unexist_update.id = "non-existent-track-id";
    unexist_update.title = "Should Fail";
    auto update_err = repo.update(unexist_update);
    assert(!update_err.has_value());
    assert(update_err.error() == "Track ID not found.");

    // Empty update on non-existent ID
    TrackUpdate empty_unexist_update;
    empty_unexist_update.id = "non-existent-track-id";
    auto empty_unexist_res = repo.update(empty_unexist_update);
    assert(!empty_unexist_res.has_value());
    assert(empty_unexist_res.error() == "Track ID not found.");

    // Empty update on existing ID
    TrackUpdate empty_exist_update;
    empty_exist_update.id = track.id;
    auto empty_exist_res = repo.update(empty_exist_update);
    assert(empty_exist_res.has_value());

    // 4. get_by_pcm_hash
    auto pcm_found = repo.get_by_pcm_hash("pcm-crud-1-hash");
    assert(pcm_found.has_value());
    assert(pcm_found->size() == 1);
    assert(pcm_found->front().id == track.id);

    auto pcm_not_found = repo.get_by_pcm_hash("pcm-unknown");
    assert(pcm_not_found.has_value());
    assert(pcm_not_found->empty());

    // 5. List and search
    Track track2;
    track2.id = "track-crud-2";
    track2.pcm_hash = "pcm-crud-2-hash";
    track2.title = "Für Elise";
    assert(repo.insert(track2).has_value());

    auto list_all = repo.list(0, 10, std::nullopt);
    assert(list_all.has_value());
    assert(list_all->total >= 2);

    auto list_search = repo.list(0, 10, "Remastered");
    assert(list_search.has_value());
    assert(list_search->total == 1);
    assert(list_search->items[0].id == "track-crud-1");

    // 6. Track-Artist Relations (add_artist, update_artist, remove_artist)
    Artist artist;
    artist.id = "artist-track-rel-1";
    artist.name = "Ludwig van Beethoven";
    assert(artist_repo.insert(artist).has_value());

    // Test add_artist
    TrackArtistParams artist_params;
    artist_params.track_id = track.id;
    artist_params.artist_id = artist.id;
    artist_params.role = ArtistRole::Main;
    artist_params.position = 1;
    auto add_art_res = repo.add_artist(artist_params);
    assert(add_art_res.has_value());

    // Verify DB
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_ta(db, "SELECT role, position FROM Track_Artist WHERE track_id = ? AND artist_id = ?");
        check_ta.bind(1, track.id);
        check_ta.bind(2, artist.id);
        assert(check_ta.executeStep());
        assert(std::string(check_ta.getColumn(0).getText()) == "main");
        assert(check_ta.getColumn(1).getInt() == 1);
    }

    // Test update_artist
    artist_params.role = ArtistRole::Performer;
    artist_params.position = 3;
    auto upd_art_res = repo.update_artist(artist_params);
    assert(upd_art_res.has_value());

    {
        auto &db = ctx.get_db();
        SQLite::Statement check_ta(db, "SELECT role, position FROM Track_Artist WHERE track_id = ? AND artist_id = ?");
        check_ta.bind(1, track.id);
        check_ta.bind(2, artist.id);
        assert(check_ta.executeStep());
        assert(std::string(check_ta.getColumn(0).getText()) == "performer");
        assert(check_ta.getColumn(1).getInt() == 3);
    }

    // Test remove_artist
    auto rem_art_res = repo.remove_artist(track.id, artist.id);
    assert(rem_art_res.has_value());

    // Second remove should fail
    auto rem_again = repo.remove_artist(track.id, artist.id);
    assert(!rem_again.has_value());
    assert(rem_again.error() == "Relation not found or already removed.");

    // Add artist with invalid track/artist
    TrackArtistParams bad_track_params = artist_params;
    bad_track_params.track_id = "non-existent-track";
    assert(!repo.add_artist(bad_track_params).has_value());

    TrackArtistParams bad_artist_params = artist_params;
    bad_artist_params.artist_id = "non-existent-artist";
    assert(!repo.add_artist(bad_artist_params).has_value());

    // 7. Track-Album foreign key validation
    TrackAlbumParams bad_album_params;
    bad_album_params.track_id = track.id;
    bad_album_params.album_id = "non-existent-album";
    assert(!repo.add_album(bad_album_params).has_value());

    // 8. touch_entity
    assert(repo.touch_entity(track.id).has_value());
    auto touch_unexist = repo.touch_entity("non-existent-track-id");
    assert(!touch_unexist.has_value());
    assert(touch_unexist.error() == "Track with ID 'non-existent-track-id' not found.");

    return true;
}

bool test_playlist_repository_crud(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_playlist_repository_crud..." << std::endl;
    SqlitePlaylistRepository repo(ctx);
    SqliteTrackRepository track_repo(ctx);

    // 1. Insert
    Playlist playlist;
    playlist.id = "playlist-crud-1";
    playlist.title = "Classical Masterpieces";
    playlist.description = "Essential classical music tracks";
    assert(repo.insert(playlist).has_value());

    // Verify Entity table
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_entity(db, "SELECT entity_type, created_at, updated_at FROM Entity WHERE id = ?");
        check_entity.bind(1, playlist.id);
        assert(check_entity.executeStep());
        assert(std::string(check_entity.getColumn(0).getText()) == "playlist");
        assert(std::string(check_entity.getColumn(1).getText()).size() > 0);
    }

    // 2. Get
    auto get_res = repo.get(playlist.id);
    assert(get_res.has_value());
    assert(get_res->id == playlist.id);
    assert(get_res->title == "Classical Masterpieces");
    assert(get_res->description == "Essential classical music tracks");

    // Get non-existent
    auto get_non = repo.get("non-existent-playlist-id");
    assert(!get_non.has_value());
    assert(get_non.error() == "Playlist not found.");

    // 3. Update
    PlaylistUpdate update_data;
    update_data.id = playlist.id;
    update_data.title = "Top Classical Tracks";
    update_data.description = "Updated description";
    assert(repo.update(update_data).has_value());

    auto get_updated = repo.get(playlist.id);
    assert(get_updated.has_value());
    assert(get_updated->title == "Top Classical Tracks");
    assert(get_updated->description == "Updated description");

    // Update non-existent
    PlaylistUpdate unexist_update;
    unexist_update.id = "non-existent-playlist-id";
    unexist_update.title = "Should Fail";
    auto update_err = repo.update(unexist_update);
    assert(!update_err.has_value());
    assert(update_err.error() == "Playlist ID not found.");

    // Empty update on non-existent ID
    PlaylistUpdate empty_unexist_update;
    empty_unexist_update.id = "non-existent-playlist-id";
    auto empty_unexist_res = repo.update(empty_unexist_update);
    assert(!empty_unexist_res.has_value());
    assert(empty_unexist_res.error() == "Playlist ID not found.");

    // Empty update on existing ID
    PlaylistUpdate empty_exist_update;
    empty_exist_update.id = playlist.id;
    auto empty_exist_res = repo.update(empty_exist_update);
    assert(empty_exist_res.has_value());

    // 4. List and search
    Playlist playlist2;
    playlist2.id = "playlist-crud-2";
    playlist2.title = "Jazz Essentials";
    playlist2.description = "Smooth jazz collection";
    assert(repo.insert(playlist2).has_value());

    auto list_all = repo.list(0, 10, std::nullopt);
    assert(list_all.has_value());
    assert(list_all->total >= 2);

    auto list_search = repo.list(0, 10, "Jazz");
    assert(list_search.has_value());
    assert(list_search->total == 1);
    assert(list_search->items[0].id == "playlist-crud-2");

    // 5. Relations: add_track, remove_track, get_tracks, get_first_track_id
    Track pl_track1;
    pl_track1.id = "track-pl-1";
    pl_track1.pcm_hash = "pcm-pl-1";
    pl_track1.title = "Track One";
    assert(track_repo.insert(pl_track1).has_value());

    Track pl_track2;
    pl_track2.id = "track-pl-2";
    pl_track2.pcm_hash = "pcm-pl-2";
    pl_track2.title = "Track Two";
    assert(track_repo.insert(pl_track2).has_value());

    // Initially empty
    auto first_empty = repo.get_first_track_id(playlist.id);
    assert(!first_empty.has_value());
    assert(first_empty.error() == "Playlist is empty.");

    // Add tracks with explicit position ordering
    assert(repo.add_track(playlist.id, pl_track1.id, 2).has_value());
    assert(repo.add_track(playlist.id, pl_track2.id, 1).has_value());

    auto tracks_res = repo.get_tracks(playlist.id);
    assert(tracks_res.has_value());
    assert(tracks_res->size() == 2);
    assert((*tracks_res)[0] == pl_track2.id); // position 1 comes first
    assert((*tracks_res)[1] == pl_track1.id); // position 2 comes second

    auto first_found = repo.get_first_track_id(playlist.id);
    assert(first_found.has_value());
    assert(*first_found == pl_track2.id);

    // Remove track
    assert(repo.remove_track(playlist.id, pl_track2.id).has_value());
    auto tracks_after = repo.get_tracks(playlist.id);
    assert(tracks_after.has_value());
    assert(tracks_after->size() == 1);
    assert((*tracks_after)[0] == pl_track1.id);

    // Removing already removed track fails
    auto rem_again = repo.remove_track(playlist.id, pl_track2.id);
    assert(!rem_again.has_value());
    assert(rem_again.error() == "Track not found in playlist.");

    // Relation error handling
    assert(!repo.add_track("non-existent-pl", pl_track1.id, 1).has_value());
    assert(!repo.add_track(playlist.id, "non-existent-track", 1).has_value());

    // 6. touch_entity
    assert(repo.touch_entity(playlist.id).has_value());
    auto touch_unexist = repo.touch_entity("non-existent-pl-id");
    assert(!touch_unexist.has_value());
    assert(touch_unexist.error() == "Playlist with ID 'non-existent-pl-id' not found.");

    return true;
}

bool test_track_hydration_and_relations(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_track_hydration_and_relations..." << std::endl;
    SqliteTrackRepository track_repo(ctx);
    SqliteAlbumRepository album_repo(ctx);
    SqliteArtistRepository artist_repo(ctx);
    SqliteWorkRepository work_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);

    Work work;
    work.id = "work-hyd-1";
    work.title = "Goldberg Variations";
    assert(work_repo.insert(work).has_value());

    Artist main_artist;
    main_artist.id = "artist-hyd-main";
    main_artist.name = "Glenn Gould";
    assert(artist_repo.insert(main_artist).has_value());

    Artist feat_artist;
    feat_artist.id = "artist-hyd-feat";
    feat_artist.name = "Featured Soloist";
    assert(artist_repo.insert(feat_artist).has_value());

    Artist empty_artist;
    empty_artist.id = "artist-hyd-empty";
    empty_artist.name = "Silent Artist";
    assert(artist_repo.insert(empty_artist).has_value());

    Album album1;
    album1.id = "album-hyd-1";
    album1.title = "1981 Studio Recording";
    album1.release_year = 1981;
    assert(album_repo.insert(album1).has_value());

    Album album2;
    album2.id = "album-hyd-2";
    album2.title = "Complete Box Set";
    album2.release_year = 2002;
    assert(album_repo.insert(album2).has_value());

    Album empty_album;
    empty_album.id = "album-hyd-empty";
    empty_album.title = "Empty Album";
    assert(album_repo.insert(empty_album).has_value());

    Audio audio_hires;
    audio_hires.pcm_hash = "pcm-hyd-hires";
    audio_hires.bit_depth = 24;
    audio_hires.sample_rate = 96000;
    audio_hires.channels = 2;
    audio_hires.duration = 190.0;

    Asset asset_mp3;
    asset_mp3.file_hash = "file-hyd-mp3";
    asset_mp3.mime_type = "audio/mpeg";
    asset_mp3.asset_type = "audio";
    asset_mp3.file_size = 50000000; // Larger than FLAC to genuinely prove lossless priority
    assert(asset_repo.insert_asset_with_audio(asset_mp3, audio_hires).has_value());

    Asset asset_wavpack;
    asset_wavpack.file_hash = "file-hyd-wavpack";
    asset_wavpack.mime_type = "audio/wavpack";
    asset_wavpack.asset_type = "audio";
    asset_wavpack.file_size = 60000000;
    assert(asset_repo.insert_asset_with_audio(asset_wavpack, audio_hires).has_value());

    Asset asset_param_wav;
    asset_param_wav.file_hash = "file-hyd-param-wav";
    asset_param_wav.mime_type = "audio/mpeg; comment=wav";
    asset_param_wav.asset_type = "audio";
    asset_param_wav.file_size = 70000000;
    assert(asset_repo.insert_asset_with_audio(asset_param_wav, audio_hires).has_value());

    Asset asset_flac;
    asset_flac.file_hash = "file-hyd-flac";
    asset_flac.mime_type = "audio/flac";
    asset_flac.asset_type = "audio";
    asset_flac.file_size = 10000000;
    assert(asset_repo.insert_asset_with_audio(asset_flac, audio_hires).has_value());

    Audio audio_aif;
    audio_aif.pcm_hash = "pcm-hyd-aif";
    audio_aif.bit_depth = 16;
    audio_aif.sample_rate = 44100;
    Asset asset_aif_mp3{"file-aif-mp3", "audio/mpeg", "audio", 20000000, ""};
    Asset asset_aif{"file-aif-src", "audio/aif", "audio", 5000000, ""};
    assert(asset_repo.insert_asset_with_audio(asset_aif_mp3, audio_aif).has_value());
    assert(asset_repo.insert_asset_with_audio(asset_aif, audio_aif).has_value());

    Audio audio_zero;
    audio_zero.pcm_hash = "pcm-hyd-zero";
    audio_zero.bit_depth = 0;
    audio_zero.sample_rate = 0;
    Asset asset_octet;
    asset_octet.file_hash = "file-hyd-octet";
    asset_octet.mime_type = "audio/octet-stream";
    asset_octet.asset_type = "audio";
    assert(asset_repo.insert_asset_with_audio(asset_octet, audio_zero).has_value());

    // Track 1: full relations, including multiple artists/albums/assets (no row multiplication!)
    Track t1;
    t1.id = "track-hyd-1";
    t1.pcm_hash = audio_hires.pcm_hash;
    t1.work_id = work.id;
    t1.title = "Aria Hydrated";
    assert(track_repo.insert(t1).has_value());
    assert(track_repo.add_artist({t1.id, feat_artist.id, ArtistRole::Featured, 1}).has_value());
    assert(track_repo.add_artist({t1.id, main_artist.id, ArtistRole::Main, 2}).has_value());
    assert(track_repo.add_album({t1.id, album1.id, 1}).has_value());
    assert(track_repo.add_album({t1.id, album2.id, 7}).has_value());

    // Track 2: NULL position in album1, shared main_artist
    Track t2;
    t2.id = "track-hyd-2";
    t2.pcm_hash = audio_zero.pcm_hash;
    t2.title = "Variation NULL Pos";
    assert(track_repo.insert(t2).has_value());
    assert(track_repo.add_artist({t2.id, main_artist.id, ArtistRole::Main, 1}).has_value());
    assert(track_repo.add_album({t2.id, album1.id, std::nullopt}).has_value());

    // Track 3: completely unlinked (NULL relations)
    Track t3;
    t3.id = "track-hyd-3";
    t3.pcm_hash = "pcm-hyd-missing";
    t3.title = "Orphan Hydrated";
    assert(track_repo.insert(t3).has_value());

    // Track 4: audio/aif lossless selection over larger MP3
    Track t_aif;
    t_aif.id = "track-hyd-aif";
    t_aif.pcm_hash = audio_aif.pcm_hash;
    t_aif.title = "AIF Lossless Priority";
    assert(track_repo.insert(t_aif).has_value());
    auto got_aif = track_repo.get(t_aif.id);
    assert(got_aif.has_value() && got_aif->format == "AIFF");

    // Verify get() hydration + lossless asset preference + main artist role priority
    auto got1 = track_repo.get(t1.id);
    assert(got1.has_value());
    assert(got1->artist_name == "Glenn Gould");
    assert(got1->album_title == "1981 Studio Recording");
    assert(got1->work_title == "Goldberg Variations");
    assert(got1->format == "FLAC");
    assert(got1->sample_rate == 96000);
    assert(got1->bit_depth == 24);
    assert(got1->track_number == 1);

    // Verify zero audio specs and audio/octet-stream stay nullopt
    auto got2 = track_repo.get(t2.id);
    assert(got2.has_value());
    assert(got2->artist_name == "Glenn Gould");
    assert(got2->album_title == "1981 Studio Recording");
    assert(!got2->work_title.has_value());
    assert(!got2->format.has_value());
    assert(!got2->sample_rate.has_value());
    assert(!got2->bit_depth.has_value());
    assert(!got2->track_number.has_value());

    // Verify NULL relations
    auto got3 = track_repo.get(t3.id);
    assert(got3.has_value());
    assert(!got3->artist_name.has_value());
    assert(!got3->album_title.has_value());
    assert(!got3->work_title.has_value());
    assert(!got3->format.has_value());
    assert(!got3->sample_rate.has_value());
    assert(!got3->bit_depth.has_value());
    assert(!got3->track_number.has_value());

    // Verify list() does not multiply rows on multi-artist / multi-album / multi-asset tracks
    auto list_res = track_repo.list(0, 10, std::string("Hydrated"));
    assert(list_res.has_value());
    assert(list_res->total == 2);
    assert(list_res->items.size() == 2);
    assert(list_res->items[0].id == t1.id);
    assert(list_res->items[0].format == "FLAC");
    assert(list_res->items[1].id == t3.id);
    assert(!list_res->items[1].artist_name.has_value());

    // Verify get_by_title and get_by_pcm_hash return hydrated fields
    auto by_title = track_repo.get_by_title("Aria Hydrated");
    assert(by_title.has_value() && by_title->size() == 1);
    assert(by_title->front().artist_name == "Glenn Gould");
    assert(by_title->front().work_title == "Goldberg Variations");

    auto by_pcm = track_repo.get_by_pcm_hash(audio_hires.pcm_hash);
    assert(by_pcm.has_value() && by_pcm->size() == 1);
    assert(by_pcm->front().format == "FLAC");

    // Verify get_by_album ordering (position ASC, NULL last) and album anchoring
    auto alb1_tracks = track_repo.get_by_album(album1.id);
    assert(alb1_tracks.has_value() && alb1_tracks->size() == 2);
    assert((*alb1_tracks)[0].id == t1.id);
    assert((*alb1_tracks)[0].album_title == "1981 Studio Recording");
    assert((*alb1_tracks)[0].track_number == 1);
    assert((*alb1_tracks)[1].id == t2.id);
    assert(!(*alb1_tracks)[1].track_number.has_value());

    auto alb2_tracks = track_repo.get_by_album(album2.id);
    assert(alb2_tracks.has_value() && alb2_tracks->size() == 1);
    assert((*alb2_tracks)[0].album_title == "Complete Box Set");
    assert((*alb2_tracks)[0].track_number == 7);

    auto empty_alb_tracks = track_repo.get_by_album(empty_album.id);
    assert(empty_alb_tracks.has_value() && empty_alb_tracks->empty());

    auto missing_alb_tracks = track_repo.get_by_album("nonexistent-album");
    assert(!missing_alb_tracks.has_value() && missing_alb_tracks.error() == "Album not found.");

    // Verify get_by_artist (for main and featured artists)
    auto main_tracks = track_repo.get_by_artist(main_artist.id);
    assert(main_tracks.has_value() && main_tracks->size() == 2);
    assert((*main_tracks)[0].id == t1.id);
    assert((*main_tracks)[1].id == t2.id);

    auto feat_tracks = track_repo.get_by_artist(feat_artist.id);
    assert(feat_tracks.has_value() && feat_tracks->size() == 1);
    assert((*feat_tracks)[0].id == t1.id);
    assert((*feat_tracks)[0].artist_name == "Glenn Gould");

    auto empty_art_tracks = track_repo.get_by_artist(empty_artist.id);
    assert(empty_art_tracks.has_value() && empty_art_tracks->empty());

    auto missing_art_tracks = track_repo.get_by_artist("nonexistent-artist");
    assert(!missing_art_tracks.has_value() && missing_art_tracks.error() == "Artist not found.");

    // Verify AlbumRepository::get_by_artist deduplication & ordering (year DESC, NULL last)
    Album album_null_year;
    album_null_year.id = "album-hyd-null-year";
    album_null_year.title = "Unreleased Session";
    assert(album_repo.insert(album_null_year).has_value());
    assert(track_repo.add_album({t2.id, album_null_year.id, 1}).has_value());

    auto art_albums = album_repo.get_by_artist(main_artist.id);
    assert(art_albums.has_value() && art_albums->size() == 3);
    assert((*art_albums)[0].id == album2.id);
    assert((*art_albums)[1].id == album1.id);
    assert((*art_albums)[2].id == album_null_year.id);

    auto empty_art_albums = album_repo.get_by_artist(empty_artist.id);
    assert(empty_art_albums.has_value() && empty_art_albums->empty());

    auto missing_art_albums = album_repo.get_by_artist("nonexistent-artist");
    assert(!missing_art_albums.has_value() && missing_art_albums.error() == "Artist not found.");

    return true;
}

bool test_hydration_lossless_ranking_symmetry(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_hydration_lossless_ranking_symmetry..." << std::endl;
    SqliteTrackRepository track_repo(ctx);
    SqliteAssetRepository asset_repo(ctx);

    // Case 1: Large decoys (lossy, non-audio, ';'-param-only, bare lossy, invalid whitespace)
    // must NOT outrank a smaller genuine lossless asset.
    Audio audio_fp;
    audio_fp.pcm_hash = "pcm-sym-fp";
    audio_fp.bit_depth = 24;
    audio_fp.sample_rate = 96000;
    audio_fp.channels = 2;
    audio_fp.duration = 120.0;

    Asset decoy_mpeg{"sym_mpeg.flac", "audio/mpeg", "audio", 50000000, ""};
    Asset decoy_img{"sym_img.flac", "image/png", "image", 60000000, ""};
    Asset decoy_semi{"sym_semi_noext", "; filename=demo.flac", "audio", 70000000, ""};
    Asset decoy_dotmp3{"sym_dotmp3.flac", ".mp3", "audio", 80000000, ""};
    Asset decoy_badspace{"sym_badspace.flac", "audio/ flac", "audio", 90000000, ""};
    Asset real_flac{"sym_real_flac", "audio/flac", "audio", 10000000, ""};

    assert(asset_repo.insert_asset_with_audio(decoy_mpeg, audio_fp).has_value());
    assert(asset_repo.insert_asset_with_audio(decoy_img, audio_fp).has_value());
    assert(asset_repo.insert_asset_with_audio(decoy_semi, audio_fp).has_value());
    assert(asset_repo.insert_asset_with_audio(decoy_dotmp3, audio_fp).has_value());
    assert(asset_repo.insert_asset_with_audio(decoy_badspace, audio_fp).has_value());
    assert(asset_repo.insert_asset_with_audio(real_flac, audio_fp).has_value());

    Track t_fp;
    t_fp.id = "track-sym-fp";
    t_fp.pcm_hash = audio_fp.pcm_hash;
    t_fp.title = "Symmetry Case 1";
    assert(track_repo.insert(t_fp).has_value());
    auto got_fp = track_repo.get(t_fp.id);
    assert(got_fp.has_value() && got_fp->format == "FLAC");

    // Case 2: Bare lossless MIME with ';' params beats larger MP3.
    Audio audio_bare_semi;
    audio_bare_semi.pcm_hash = "pcm-sym-bare-semi";
    audio_bare_semi.bit_depth = 16;
    audio_bare_semi.sample_rate = 44100;
    Asset bare_mp3_big{"sym_bare_mp3", "audio/mpeg", "audio", 50000000, ""};
    Asset bare_semi_flac{"sym_bare_semi", "track.flac; path=a/b", "audio", 5000000, ""};
    assert(asset_repo.insert_asset_with_audio(bare_mp3_big, audio_bare_semi).has_value());
    assert(asset_repo.insert_asset_with_audio(bare_semi_flac, audio_bare_semi).has_value());

    Track t_bare_semi;
    t_bare_semi.id = "track-sym-bare-semi";
    t_bare_semi.pcm_hash = audio_bare_semi.pcm_hash;
    t_bare_semi.title = "Symmetry Case 2";
    assert(track_repo.insert(t_bare_semi).has_value());
    auto got_bare_semi = track_repo.get(t_bare_semi.id);
    assert(got_bare_semi.has_value() && got_bare_semi->format == "FLAC");

    // Case 3a: Whitespace (\t) padded lossless MIME beats larger MP3.
    Audio audio_tab;
    audio_tab.pcm_hash = "pcm-sym-tab";
    audio_tab.bit_depth = 16;
    audio_tab.sample_rate = 44100;
    assert(asset_repo.insert_asset_with_audio(Asset{"sym_tab_mp3", "audio/mpeg", "audio", 50000000, ""}, audio_tab)
               .has_value());
    assert(asset_repo
               .insert_asset_with_audio(Asset{"sym_tab_flac", "\taudio/flac\t; codecs=flac", "audio", 5000000, ""},
                                        audio_tab)
               .has_value());

    Track t_tab;
    t_tab.id = "track-sym-tab";
    t_tab.pcm_hash = audio_tab.pcm_hash;
    t_tab.title = "Symmetry Case 3a";
    assert(track_repo.insert(t_tab).has_value());
    auto got_tab = track_repo.get(t_tab.id);
    assert(got_tab.has_value() && got_tab->format == "FLAC");

    // Case 3b: audio/x-octet-stream + newline-padded .flac hash beats larger MP3.
    Audio audio_xoct;
    audio_xoct.pcm_hash = "pcm-sym-xoct";
    audio_xoct.bit_depth = 16;
    audio_xoct.sample_rate = 44100;
    assert(asset_repo.insert_asset_with_audio(Asset{"sym_xoct_mp3", "audio/mpeg", "audio", 50000000, ""}, audio_xoct)
               .has_value());
    assert(asset_repo
               .insert_asset_with_audio(Asset{"sym_xoct.flac\n", "audio/x-octet-stream", "audio", 5000000, ""},
                                        audio_xoct)
               .has_value());

    Track t_xoct;
    t_xoct.id = "track-sym-xoct";
    t_xoct.pcm_hash = audio_xoct.pcm_hash;
    t_xoct.title = "Symmetry Case 3b";
    assert(track_repo.insert(t_xoct).has_value());
    auto got_xoct = track_repo.get(t_xoct.id);
    assert(got_xoct.has_value() && got_xoct->format == "FLAC");

    // Case 3c: audio/x-aif beats larger MP3.
    Audio audio_xaif;
    audio_xaif.pcm_hash = "pcm-sym-xaif";
    audio_xaif.bit_depth = 16;
    audio_xaif.sample_rate = 44100;
    assert(asset_repo.insert_asset_with_audio(Asset{"sym_xaif_mp3", "audio/mpeg", "audio", 50000000, ""}, audio_xaif)
               .has_value());
    assert(
        asset_repo.insert_asset_with_audio(Asset{"sym_xaif_src", "audio/x-aif", "audio", 5000000, ""}, audio_xaif)
            .has_value());

    Track t_xaif;
    t_xaif.id = "track-sym-xaif";
    t_xaif.pcm_hash = audio_xaif.pcm_hash;
    t_xaif.title = "Symmetry Case 3c";
    assert(track_repo.insert(t_xaif).has_value());
    auto got_xaif = track_repo.get(t_xaif.id);
    assert(got_xaif.has_value() && got_xaif->format == "AIFF");

    return true;
}

bool test_playlist_delete_and_reorder(SqliteDatabaseContext &ctx) {
    std::cout << "Running test_playlist_delete_and_reorder..." << std::endl;
    SqlitePlaylistRepository repo(ctx);
    SqliteTrackRepository track_repo(ctx);

    Track ta{"track-reord-a", "pcm-reord-a", std::nullopt, "Song A"};
    Track tb{"track-reord-b", "pcm-reord-b", std::nullopt, "Song B"};
    Track tc{"track-reord-c", "pcm-reord-c", std::nullopt, "Song C"};
    assert(track_repo.insert(ta).has_value());
    assert(track_repo.insert(tb).has_value());
    assert(track_repo.insert(tc).has_value());

    Playlist pl;
    pl.id = "playlist-reord-1";
    pl.title = "Reorder Test";
    assert(repo.insert(pl).has_value());

    // Empty playlist reorder -> Index out of range.
    auto empty_reord = repo.reorder_tracks(pl.id, 0, 0);
    assert(!empty_reord.has_value());
    assert(empty_reord.error() == "Index out of range.");

    assert(repo.add_track(pl.id, ta.id, 0).has_value());
    assert(repo.add_track(pl.id, tb.id, 1).has_value());
    assert(repo.add_track(pl.id, tc.id, 2).has_value());

    // Move forward: 0 -> 2 => [B, C, A]
    auto fwd = repo.reorder_tracks(pl.id, 0, 2);
    assert(fwd.has_value());
    assert((*fwd) == (std::vector<std::string>{tb.id, tc.id, ta.id}));
    assert(repo.get_tracks(pl.id).value() == (*fwd));

    // Move backward: 2 -> 0 => [A, B, C]
    auto bwd = repo.reorder_tracks(pl.id, 2, 0);
    assert(bwd.has_value());
    assert((*bwd) == (std::vector<std::string>{ta.id, tb.id, tc.id}));
    assert(repo.get_tracks(pl.id).value() == (*bwd));

    // No-op: 1 -> 1
    auto noop = repo.reorder_tracks(pl.id, 1, 1);
    assert(noop.has_value());
    assert((*noop) == (std::vector<std::string>{ta.id, tb.id, tc.id}));

    // Out of bounds checks leave order untouched
    for (auto [o, n] : std::vector<std::pair<int, int>>{{-1, 0}, {0, -1}, {3, 0}, {0, 3}}) {
        auto bad = repo.reorder_tracks(pl.id, o, n);
        assert(!bad.has_value());
        assert(bad.error() == "Index out of range.");
        assert(repo.get_tracks(pl.id).value() == (std::vector<std::string>{ta.id, tb.id, tc.id}));
    }

    // Atomic transaction rollback test via SQLite BEFORE UPDATE trigger
    {
        auto &db = ctx.get_db();
        db.exec(
            "CREATE TRIGGER trg_test_fail_reorder BEFORE UPDATE ON Playlist_Track "
            "WHEN NEW.track_id = 'track-reord-a' "
            "BEGIN SELECT RAISE(ABORT, 'simulated mid-reorder failure'); END;");

        auto failed_reorder = repo.reorder_tracks(pl.id, 0, 2);
        db.exec("DROP TRIGGER IF EXISTS trg_test_fail_reorder;");

        assert(!failed_reorder.has_value());
        // Verify all positions rolled back intact to [0, 1, 2] for [A, B, C]
        assert(repo.get_tracks(pl.id).value() == (std::vector<std::string>{ta.id, tb.id, tc.id}));
        SQLite::Statement pos_stmt(
            db, "SELECT track_id, position FROM Playlist_Track WHERE playlist_id = ? ORDER BY position ASC");
        pos_stmt.bind(1, pl.id);
        std::vector<std::pair<std::string, int>> rows;
        while (pos_stmt.executeStep()) {
            rows.emplace_back(pos_stmt.getColumn(0).getString(), pos_stmt.getColumn(1).getInt());
        }
        pos_stmt.reset();
        assert(rows.size() == 3);
        assert(rows[0] == std::make_pair(ta.id, 0));
        assert(rows[1] == std::make_pair(tb.id, 1));
        assert(rows[2] == std::make_pair(tc.id, 2));
    }

    // Passing a Track ID to delete_playlist / reorder_tracks must fail with Playlist not found and not delete Track
    auto del_track_as_pl = repo.delete_playlist(ta.id);
    assert(!del_track_as_pl.has_value());
    assert(del_track_as_pl.error() == "Playlist not found.");
    assert(track_repo.get(ta.id).has_value());

    auto reord_missing = repo.reorder_tracks("nonexistent-playlist", 0, 1);
    assert(!reord_missing.has_value());
    assert(reord_missing.error() == "Playlist not found.");

    // Delete playlist atomically removes Playlist_Track, Playlist, and Entity while keeping Tracks
    assert(repo.delete_playlist(pl.id).has_value());
    assert(!repo.get(pl.id).has_value());
    assert(repo.get_tracks(pl.id).value().empty());
    {
        auto &db = ctx.get_db();
        SQLite::Statement check_ent(db, "SELECT 1 FROM Entity WHERE id = ?");
        check_ent.bind(1, pl.id);
        assert(!check_ent.executeStep());
        check_ent.reset();
    }
    assert(track_repo.get(ta.id).has_value());
    assert(track_repo.get(tb.id).has_value());
    assert(track_repo.get(tc.id).has_value());

    auto del_again = repo.delete_playlist(pl.id);
    assert(!del_again.has_value());
    assert(del_again.error() == "Playlist not found.");

    // NULL-position ordering & reorder: NULL position sorts LAST (not first)
    Playlist pl_null;
    pl_null.id = "playlist-null-pos";
    pl_null.title = "Null Pos Playlist";
    assert(repo.insert(pl_null).has_value());
    assert(repo.add_track(pl_null.id, ta.id, 0).has_value());
    assert(repo.add_track(pl_null.id, tb.id, 1).has_value());
    assert(repo.add_track(pl_null.id, tc.id, std::nullopt).has_value());

    auto null_tracks = repo.get_tracks(pl_null.id);
    assert(null_tracks.has_value());
    assert((*null_tracks) == (std::vector<std::string>{ta.id, tb.id, tc.id}));

    auto first_non_null = repo.get_first_track_id(pl_null.id);
    assert(first_non_null.has_value() && *first_non_null == ta.id);

    auto reord_null = repo.reorder_tracks(pl_null.id, 2, 0);
    assert(reord_null.has_value());
    assert((*reord_null) == (std::vector<std::string>{tc.id, ta.id, tb.id}));
    assert(repo.get_tracks(pl_null.id).value() == (*reord_null));

    // All-NULL positions: deterministic tie-breaking on track_id ASC in get_first_track_id
    Playlist pl_all_null;
    pl_all_null.id = "playlist-all-null-pos";
    pl_all_null.title = "All Null Pos Playlist";
    assert(repo.insert(pl_all_null).has_value());
    assert(repo.add_track(pl_all_null.id, tb.id, std::nullopt).has_value());
    assert(repo.add_track(pl_all_null.id, ta.id, std::nullopt).has_value());
    auto first_tie = repo.get_first_track_id(pl_all_null.id);
    assert(first_tie.has_value() && *first_tie == ta.id);

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
        if (!test_sqlite_update_builder(ctx)) success = false;
        if (!test_entity_repository_crud(ctx)) success = false;
        if (!test_artist_repository_crud(ctx)) success = false;
        if (!test_work_repository_crud(ctx)) success = false;
        if (!test_track_repository_crud(ctx)) success = false;
        if (!test_playlist_repository_crud(ctx)) success = false;
        if (!test_track_hydration_and_relations(ctx)) success = false;
        if (!test_hydration_lossless_ranking_symmetry(ctx)) success = false;
        if (!test_playlist_delete_and_reorder(ctx)) success = false;
        if (!test_entity_rollback_on_insert_failure(ctx)) success = false;
        if (!test_database_triggers_updated_at(ctx)) success = false;
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
