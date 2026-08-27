/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "../src/utils/sqlite_helper.h"
#include "../src/utils/sqlite_mappers.h"
#include <SQLiteCpp/SQLiteCpp.h>
#include <cassert>
#include <iostream>
#include <string>

using namespace lyra;

bool test_fetch_one_and_fetch_all_with_lambda() {
    std::cout << "Running test_fetch_one_and_fetch_all_with_lambda..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT);");
    db.exec("INSERT INTO Test VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie');");

    // Test fetch_one existing
    {
        SQLite::Statement query(db, "SELECT id, name FROM Test WHERE id = 2");
        auto result = SqliteHelper::fetch_one(query, [](SQLite::Statement &q) {
            return std::make_pair(q.getColumn(0).getInt(), q.getColumn(1).getString());
        });
        if (!result.has_value() || result->first != 2 || result->second != "Bob") {
            std::cerr << "fetch_one existing row failed!" << std::endl;
            return false;
        }
    }

    // Test fetch_one non-existing
    {
        SQLite::Statement query(db, "SELECT id, name FROM Test WHERE id = 999");
        auto result = SqliteHelper::fetch_one(query, [](SQLite::Statement &q) {
            return q.getColumn(1).getString();
        });
        if (result.has_value()) {
            std::cerr << "fetch_one non-existing row should return nullopt!" << std::endl;
            return false;
        }
    }

    // Test fetch_all multiple rows
    {
        SQLite::Statement query(db, "SELECT name FROM Test ORDER BY id ASC");
        auto names = SqliteHelper::fetch_all(query, [](SQLite::Statement &q) { return q.getColumn(0).getString(); }, 3);
        if (names.size() != 3 || names[0] != "Alice" || names[1] != "Bob" || names[2] != "Charlie") {
            std::cerr << "fetch_all multiple rows failed!" << std::endl;
            return false;
        }
    }

    // Test fetch_all zero rows
    {
        SQLite::Statement query(db, "SELECT name FROM Test WHERE id > 100");
        auto names = SqliteHelper::fetch_all(query, [](SQLite::Statement &q) {
            return q.getColumn(0).getString();
        });
        if (!names.empty()) {
            std::cerr << "fetch_all zero rows should return empty vector!" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_asset_mapper() {
    std::cout << "Running test_asset_mapper..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Asset (file_hash TEXT PRIMARY KEY, mime_type TEXT, asset_type TEXT, file_size INTEGER, created_at TEXT);");
    db.exec("INSERT INTO Asset VALUES ('hash123', 'audio/flac', 'audio', 1048576, '2026-01-01 00:00:00');");
    db.exec("INSERT INTO Asset VALUES ('hash456', NULL, NULL, NULL, NULL);");

    // Fetch full Asset
    {
        SQLite::Statement query(db, "SELECT * FROM Asset WHERE file_hash = 'hash123'");
        auto asset = SqliteHelper::fetch_one(query, SqliteMappers::map_asset);
        if (!asset || asset->file_hash != "hash123" || asset->mime_type != "audio/flac" ||
            asset->asset_type != "audio" || asset->file_size != 1048576 || asset->created_at != "2026-01-01 00:00:00") {
            std::cerr << "test_asset_mapper failed for full asset!" << std::endl;
            return false;
        }
    }

    // Fetch Asset with NULL fields
    {
        SQLite::Statement query(db, "SELECT * FROM Asset WHERE file_hash = 'hash456'");
        auto asset = SqliteHelper::fetch_one<Asset>(query);
        if (!asset || asset->file_hash != "hash456" || asset->mime_type != "" ||
            asset->asset_type != "" || asset->file_size != 0 || asset->created_at != "") {
            std::cerr << "test_asset_mapper failed for null fields asset!" << std::endl;
            return false;
        }
    }

    // Fetch all assets
    {
        SQLite::Statement query(db, "SELECT * FROM Asset ORDER BY file_hash ASC");
        auto assets = SqliteHelper::fetch_all<Asset>(query, 2);
        if (assets.size() != 2 || assets[0].file_hash != "hash123" || assets[1].file_hash != "hash456") {
            std::cerr << "test_asset_mapper fetch_all failed!" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_audio_mapper() {
    std::cout << "Running test_audio_mapper..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Audio (pcm_hash TEXT PRIMARY KEY, parent_hash TEXT, quality_score INTEGER, bit_depth INTEGER, sample_rate INTEGER, channels INTEGER, duration REAL, integrated_loudness REAL, true_peak REAL);");
    db.exec("INSERT INTO Audio VALUES ('pcm1', 'parent1', 95, 24, 96000, 2, 180.5, -14.2, -0.5);");
    db.exec("INSERT INTO Audio VALUES ('pcm2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);");

    // Full audio
    {
        SQLite::Statement query(db, "SELECT * FROM Audio WHERE pcm_hash = 'pcm1'");
        auto audio = SqliteHelper::fetch_one(query, SqliteMappers::map_audio);
        if (!audio || audio->pcm_hash != "pcm1" || audio->parent_hash != "parent1" ||
            audio->quality_score != 95 || audio->bit_depth != 24 || audio->sample_rate != 96000 ||
            audio->channels != 2 || audio->duration != 180.5 || audio->integrated_loudness != -14.2 ||
            audio->true_peak != -0.5) {
            std::cerr << "test_audio_mapper failed for full audio!" << std::endl;
            return false;
        }
    }

    // Null audio
    {
        SQLite::Statement query(db, "SELECT * FROM Audio WHERE pcm_hash = 'pcm2'");
        auto audio = SqliteHelper::fetch_one<Audio>(query);
        if (!audio || audio->pcm_hash != "pcm2" || audio->parent_hash != "" ||
            audio->quality_score != 0 || audio->bit_depth != 0 || audio->sample_rate != 0 ||
            audio->channels != 0 || audio->duration != 0.0 || audio->integrated_loudness != 0.0 ||
            audio->true_peak != 0.0) {
            std::cerr << "test_audio_mapper failed for null fields audio!" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_track_mapper() {
    std::cout << "Running test_track_mapper..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Track (id TEXT PRIMARY KEY, work_id TEXT, pcm_hash TEXT, title TEXT, recording_year INTEGER, recording_month INTEGER, recording_day INTEGER, recording_location TEXT, duration INTEGER, isrc TEXT, musicbrainz_id TEXT, ytm_id TEXT, spotify_id TEXT);");
    db.exec("INSERT INTO Track VALUES ('t1', 'w1', 'pcm1', 'Track Title', 2026, 8, 26, 'Tokyo', 240000, 'ISRC123', 'mbid123', 'ytm123', 'spot123');");
    db.exec("INSERT INTO Track VALUES ('t2', NULL, 'pcm2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);");

    // Full Track
    {
        SQLite::Statement query(db, "SELECT * FROM Track WHERE id = 't1'");
        auto track = SqliteHelper::fetch_one(query, SqliteMappers::map_track);
        if (!track || track->id != "t1" || track->work_id != "w1" || track->pcm_hash != "pcm1" ||
            track->title != "Track Title" || track->recording_year != 2026 || track->recording_month != 8 ||
            track->recording_day != 26 || track->recording_location != "Tokyo" || track->duration != 240000 ||
            track->isrc != "ISRC123" || track->musicbrainz_id != "mbid123" || track->ytm_id != "ytm123" ||
            track->spotify_id != "spot123") {
            std::cerr << "test_track_mapper failed for full track!" << std::endl;
            return false;
        }
    }

    // Null Track
    {
        SQLite::Statement query(db, "SELECT * FROM Track WHERE id = 't2'");
        auto track = SqliteHelper::fetch_one<Track>(query);
        if (!track || track->id != "t2" || track->pcm_hash != "pcm2" || track->work_id.has_value() ||
            track->title.has_value() || track->recording_year.has_value() || track->recording_month.has_value() ||
            track->recording_day.has_value() || track->recording_location.has_value() || track->duration.has_value() ||
            track->isrc.has_value() || track->musicbrainz_id.has_value() || track->ytm_id.has_value() ||
            track->spotify_id.has_value()) {
            std::cerr << "test_track_mapper failed for null fields track!" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_album_mapper() {
    std::cout << "Running test_album_mapper..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Album (id TEXT PRIMARY KEY, title TEXT, release_year INTEGER, release_month INTEGER, release_day INTEGER);");
    db.exec("INSERT INTO Album VALUES ('alb1', 'Album 1', 2024, 5, 20);");
    db.exec("INSERT INTO Album VALUES ('alb2', 'Album 2', NULL, NULL, NULL);");

    // Full Album
    {
        SQLite::Statement query(db, "SELECT * FROM Album WHERE id = 'alb1'");
        auto album = SqliteHelper::fetch_one(query, SqliteMappers::map_album);
        if (!album || album->id != "alb1" || album->title != "Album 1" ||
            album->release_year != 2024 || album->release_month != 5 || album->release_day != 20) {
            std::cerr << "test_album_mapper failed for full album!" << std::endl;
            return false;
        }
    }

    // Null release date Album
    {
        SQLite::Statement query(db, "SELECT * FROM Album WHERE id = 'alb2'");
        auto album = SqliteHelper::fetch_one<Album>(query);
        if (!album || album->id != "alb2" || album->title != "Album 2" ||
            album->release_year.has_value() || album->release_month.has_value() || album->release_day.has_value()) {
            std::cerr << "test_album_mapper failed for null date album!" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_artist_mapper() {
    std::cout << "Running test_artist_mapper..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Artist (id TEXT PRIMARY KEY, name TEXT, musicbrainz_id TEXT, spotify_id TEXT, ytm_id TEXT);");
    db.exec("INSERT INTO Artist VALUES ('art1', 'Artist Name', 'mb1', 'sp1', 'yt1');");
    db.exec("INSERT INTO Artist VALUES ('art2', 'Artist 2', NULL, NULL, NULL);");

    // Full Artist
    {
        SQLite::Statement query(db, "SELECT * FROM Artist WHERE id = 'art1'");
        auto artist = SqliteHelper::fetch_one(query, SqliteMappers::map_artist);
        if (!artist || artist->id != "art1" || artist->name != "Artist Name" ||
            artist->musicbrainz_id != "mb1" || artist->spotify_id != "sp1" || artist->ytm_id != "yt1") {
            std::cerr << "test_artist_mapper failed for full artist!" << std::endl;
            return false;
        }
    }

    // Null fields Artist
    {
        SQLite::Statement query(db, "SELECT * FROM Artist WHERE id = 'art2'");
        auto artist = SqliteHelper::fetch_one<Artist>(query);
        if (!artist || artist->id != "art2" || artist->name != "Artist 2" ||
            artist->musicbrainz_id.has_value() || artist->spotify_id.has_value() || artist->ytm_id.has_value()) {
            std::cerr << "test_artist_mapper failed for null artist!" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_work_mapper() {
    std::cout << "Running test_work_mapper..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Work (id TEXT PRIMARY KEY, title TEXT, composition_start_year INTEGER, composition_end_year INTEGER, composition_date_text TEXT, iswc TEXT, musicbrainz_id TEXT);");
    db.exec("INSERT INTO Work VALUES ('w1', 'Symphony No. 5', 1804, 1808, '1804-1808', 'T-000000001-0', 'mbw1');");
    db.exec("INSERT INTO Work VALUES ('w2', 'Untitled Work', NULL, NULL, NULL, NULL, NULL);");

    // Full Work
    {
        SQLite::Statement query(db, "SELECT * FROM Work WHERE id = 'w1'");
        auto work = SqliteHelper::fetch_one(query, SqliteMappers::map_work);
        if (!work || work->id != "w1" || work->title != "Symphony No. 5" ||
            work->composition_start_year != 1804 || work->composition_end_year != 1808 ||
            work->composition_date_text != "1804-1808" || work->iswc != "T-000000001-0" ||
            work->musicbrainz_id != "mbw1") {
            std::cerr << "test_work_mapper failed for full work!" << std::endl;
            return false;
        }
    }

    // Null Work
    {
        SQLite::Statement query(db, "SELECT * FROM Work WHERE id = 'w2'");
        auto work = SqliteHelper::fetch_one<Work>(query);
        if (!work || work->id != "w2" || work->title != "Untitled Work" ||
            work->composition_start_year.has_value() || work->composition_end_year.has_value() ||
            work->composition_date_text.has_value() || work->iswc.has_value() ||
            work->musicbrainz_id.has_value()) {
            std::cerr << "test_work_mapper failed for null work!" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_playlist_mapper() {
    std::cout << "Running test_playlist_mapper..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Playlist (id TEXT PRIMARY KEY, title TEXT, description TEXT);");
    db.exec("INSERT INTO Playlist VALUES ('pl1', 'My Playlist', 'Cool tracks');");
    db.exec("INSERT INTO Playlist VALUES ('pl2', 'Empty Desc Playlist', NULL);");

    // Full Playlist
    {
        SQLite::Statement query(db, "SELECT * FROM Playlist WHERE id = 'pl1'");
        auto pl = SqliteHelper::fetch_one(query, SqliteMappers::map_playlist);
        if (!pl || pl->id != "pl1" || pl->title != "My Playlist" || pl->description != "Cool tracks") {
            std::cerr << "test_playlist_mapper failed for full playlist!" << std::endl;
            return false;
        }
    }

    // Null desc Playlist
    {
        SQLite::Statement query(db, "SELECT * FROM Playlist WHERE id = 'pl2'");
        auto pl = SqliteHelper::fetch_one<Playlist>(query);
        if (!pl || pl->id != "pl2" || pl->title != "Empty Desc Playlist" || pl->description.has_value()) {
            std::cerr << "test_playlist_mapper failed for null desc playlist!" << std::endl;
            return false;
        }
    }

    return true;
}

bool test_image_mapper() {
    std::cout << "Running test_image_mapper..." << std::endl;

    SQLite::Database db(":memory:", SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
    db.exec("CREATE TABLE Image (image_hash TEXT PRIMARY KEY, file_hash TEXT, width INTEGER, height INTEGER, dominant_color TEXT);");
    db.exec("CREATE TABLE Entity_Images (entity_id TEXT, image_hash TEXT, role TEXT);");
    db.exec("INSERT INTO Image VALUES ('img1', 'fhash1', 500, 500, '#FFFFFF');");
    db.exec("INSERT INTO Image VALUES ('img2', 'fhash2', NULL, NULL, NULL);");
    db.exec("INSERT INTO Entity_Images VALUES ('alb1', 'img1', 'front');");

    // Image without role column
    {
        SQLite::Statement query(db, "SELECT * FROM Image WHERE image_hash = 'img1'");
        auto img = SqliteHelper::fetch_one(query, SqliteMappers::map_image);
        if (!img || img->image_hash != "img1" || img->file_hash != "fhash1" ||
            img->width != 500 || img->height != 500 || img->dominant_color != "#FFFFFF" ||
            img->role.has_value()) {
            std::cerr << "test_image_mapper without role failed!" << std::endl;
            return false;
        }
    }

    // Image with role column in join
    {
        SQLite::Statement query(db, "SELECT i.*, ei.role FROM Image i JOIN Entity_Images ei ON i.image_hash = ei.image_hash WHERE i.image_hash = 'img1'");
        auto img = SqliteHelper::fetch_one(query, SqliteMappers::map_image);
        if (!img || img->image_hash != "img1" || img->file_hash != "fhash1" ||
            img->width != 500 || img->height != 500 || img->dominant_color != "#FFFFFF" ||
            img->role != "front") {
            std::cerr << "test_image_mapper with role failed!" << std::endl;
            return false;
        }
    }

    // Image with null fields
    {
        SQLite::Statement query(db, "SELECT * FROM Image WHERE image_hash = 'img2'");
        auto img = SqliteHelper::fetch_one<Image>(query);
        if (!img || img->image_hash != "img2" || img->file_hash != "fhash2" ||
            img->width != 0 || img->height != 0 || img->dominant_color != "" ||
            img->role.has_value()) {
            std::cerr << "test_image_mapper with null fields failed!" << std::endl;
            return false;
        }
    }

    return true;
}

int main() {
    if (!test_fetch_one_and_fetch_all_with_lambda()) return 1;
    if (!test_asset_mapper()) return 1;
    if (!test_audio_mapper()) return 1;
    if (!test_track_mapper()) return 1;
    if (!test_album_mapper()) return 1;
    if (!test_artist_mapper()) return 1;
    if (!test_work_mapper()) return 1;
    if (!test_playlist_mapper()) return 1;
    if (!test_image_mapper()) return 1;

    std::cout << "ALL_TESTS_PASSED" << std::endl;
    return 0;
}
