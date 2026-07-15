/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/services/database_context.h"
#include "../src/services/repositories/sqlite/sqlite_album_repository.h"
#include "../src/services/repositories/sqlite/sqlite_artist_repository.h"
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
