// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "../models/relation_types.h"
#include "../utils/sqlite_helper.h"
#include "database_manager.h"
namespace lyra {

static std::unique_ptr<SQLite::Database> db;

void DatabaseManager::init_database(const std::string &db_path) {
    // open database file. If lyra.db does not exist, create it automatically
    // (OPEN_CREATE)
    db = std::make_unique<SQLite::Database>(db_path, SQLite::OPEN_READWRITE |
                                                         SQLite::OPEN_CREATE);

    // enable WAL mode and foreign key support
    db->exec("PRAGMA journal_mode=WAL;");
    db->exec("PRAGMA foreign_keys=ON;");

    // create Entity table
    db->exec(R"(
        CREATE TABLE IF NOT EXISTS Entity (
          id TEXT NOT NULL,
          entity_type TEXT NULL CHECK( entity_type IN ('track', 'album', 'artist', 'work', 'playlist', 'tag') ),
          created_at TEXT DEFAULT (datetime('now')),
          updated_at TEXT DEFAULT (datetime('now')),
          PRIMARY KEY (id)
        );
    )");

    // create Artist table (it is bound to Entity table)
    db->exec(R"(
        CREATE TABLE IF NOT EXISTS Artist (
          id TEXT NOT NULL,
          name TEXT NOT NULL,
          musicbrainz_id TEXT NULL DEFAULT NULL,
          spotify_id TEXT NULL DEFAULT NULL,
          ytm_id TEXT NULL DEFAULT NULL,
          PRIMARY KEY (id),
          CONSTRAINT fk_Artist_Entity
            FOREIGN KEY (id)
            REFERENCES Entity (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
        );
    )");

    // create Track table
    db->exec(R"(
        CREATE TABLE IF NOT EXISTS Track (
          id TEXT NOT NULL UNIQUE,
          work_id TEXT NULL DEFAULT NULL,
          pcm_hash TEXT NOT NULL,
          title TEXT NULL DEFAULT NULL,
          recording_year INTEGER NULL DEFAULT NULL,
          recording_month INTEGER NULL DEFAULT NULL,
          recording_day INTEGER NULL DEFAULT NULL,
          recording_location TEXT NULL DEFAULT NULL,
          duration INTEGER NULL DEFAULT NULL,
          isrc TEXT NULL DEFAULT NULL,
          musicbrainz_id TEXT NULL DEFAULT NULL,
          ytm_id TEXT NULL DEFAULT NULL,
          spotify_id TEXT NULL DEFAULT NULL,
          PRIMARY KEY (id),
          CONSTRAINT fk_Track_Entity
            FOREIGN KEY (id)
            REFERENCES Entity (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
        );
    )");

    db->exec(R"(
        CREATE TABLE IF NOT EXISTS Track_Artist (
          track_id TEXT NOT NULL,
          artist_id TEXT NOT NULL,
          role TEXT NULL DEFAULT NULL CHECK( role IN ('main', 'featured', 'remixer', 'producer', 'conductor', 'performer', 'engineer') ),
          position INTEGER NULL DEFAULT NULL,
          PRIMARY KEY (track_id, artist_id),
          CONSTRAINT fk_TrackArtist_Track
            FOREIGN KEY (track_id)
            REFERENCES Track (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
          CONSTRAINT fk_TrackArtist_Artist
            FOREIGN KEY (artist_id)
            REFERENCES Artist (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
        );
    )");
}

// Insert artist into database table Artist, Entity
std::optional<std::string> DatabaseManager::insert_artist(const Artist &artist) {

    try {
        SQLite::Transaction transaction(*db);

        // insert into Entity table
        SQLite::Statement query1(
            *db, "INSERT INTO Entity (id, entity_type, created_at, updated_at) VALUES (?, 'artist', datetime('now'), datetime('now'))");
        query1.bind(1, artist.id);
        query1.exec();

        // insert into Artist table
        SQLite::Statement query2(
            *db, "INSERT INTO Artist (id, name, musicbrainz_id, spotify_id, ytm_id) VALUES (?, ?, ?, ?, ?)");

        auto bind_opt = [&query2](int index, const auto &val) {
            if (val) {
                query2.bind(index, *val);
            } else {
                query2.bind(index);
            }
        };

        query2.bind(1, artist.id);
        query2.bind(2, artist.name);
        bind_opt(3, artist.musicbrainz_id);
        bind_opt(4, artist.spotify_id);
        bind_opt(5, artist.ytm_id);

        query2.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }

    return std::nullopt;
}

// update artist
std::optional<std::string> DatabaseManager::update_artist(const ArtistUpdate &data) {
    try {
        // Build Dynamic SQL Query
        std::string sql = "UPDATE Artist SET ";
        std::vector<std::string> fields;

        fields.reserve(4);

        if (data.name)
            fields.emplace_back("name = ?");
        if (data.musicbrainz_id)
            fields.emplace_back("musicbrainz_id = ?");
        if (data.ytm_id)
            fields.emplace_back("ytm_id = ?");
        if (data.spotify_id)
            fields.emplace_back("spotify_id = ?");

        if (fields.empty())
            return std::nullopt; // Poka-yoke : preventing nothing to update

        // Join fields (e.g., "name = ?, musicbrainz_id = ?")
        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1)
                sql += ", ";
        }

        sql += " WHERE id = ?";

        // Execute Transaction
        SQLite::Transaction transaction(*db);
        SQLite::Statement query(*db, sql);

        // Execute binding
        int bind_idx = 1;
        if (data.name)
            query.bind(bind_idx++, *data.name);
        if (data.musicbrainz_id)
            query.bind(bind_idx++, *data.musicbrainz_id);
        if (data.ytm_id)
            query.bind(bind_idx++, *data.ytm_id);
        if (data.spotify_id)
            query.bind(bind_idx++, *data.spotify_id);

        query.bind(bind_idx, data.id); // Bind the WHERE clause id

        // Check affected rows
        int affected_rows = query.exec();
        if (affected_rows == 0) {
            // Rollback is automatic if not committed
            return "Artist ID not found or no changes made.";
        }

        // Update successful, sync Entity updated_at
        SQLite::Statement update_entity(
            *db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }

    return std::nullopt;
}

// Get artist from database
std::optional<Artist> DatabaseManager::get_artist(const std::string &artist_id) {

    SQLite::Statement query(*db, "SELECT * FROM Artist WHERE id = ?");

    query.bind(1, artist_id);

    // if artist found, return a Artist object
    if (query.executeStep()) {
        Artist artist;

        // Fill the Artist object with data from the database
        // If use getColumn("name"), time complexity is O(n)
        // If use getColumn(1), time complexity is O(1)
        artist.id = query.getColumn("id").getString();
        artist.name = query.getColumn("name").getString();

        artist.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
        artist.ytm_id = SqliteHelper::get_optional<std::string>(query, "ytm_id");
        artist.spotify_id = SqliteHelper::get_optional<std::string>(query, "spotify_id");

        return artist;
    }

    // if no artist found, return nullopt
    return std::nullopt;
}

// Insert track into database
std::optional<std::string> DatabaseManager::insert_track(const Track &track) {
    try {
        SQLite::Transaction transaction(*db);

        // Insert into Entity table
        SQLite::Statement query1(*db, "INSERT INTO Entity (id, entity_type, created_at, updated_at) VALUES (?, 'track', datetime('now'), datetime('now'))");
        query1.bind(1, track.id);
        query1.exec();

        // Insert into Track table
        SQLite::Statement query2(
            *db,
            "INSERT INTO Track (id, work_id, pcm_hash, title, recording_year, recording_month, recording_day, recording_location, duration, isrc, musicbrainz_id, ytm_id, spotify_id) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

        // --- Create Lambda helper function ---
        // Bind optional value (store as NULL if no value)
        auto bind_opt = [&query2](int index, const auto &val) {
            if (val) {
                query2.bind(index, *val);
            } else {
                query2.bind(index);
            }
        };

        // Execute binding
        query2.bind(1, track.id);       // NOT NULL
        bind_opt(2, track.work_id);     // optional
        query2.bind(3, track.pcm_hash); // NOT NULL
        bind_opt(4, track.title);       // optional
        bind_opt(5, track.recording_year);
        bind_opt(6, track.recording_month);
        bind_opt(7, track.recording_day);
        bind_opt(8, track.recording_location);
        bind_opt(9, track.duration);
        bind_opt(10, track.isrc);
        bind_opt(11, track.musicbrainz_id);
        bind_opt(12, track.ytm_id);
        bind_opt(13, track.spotify_id);

        query2.exec();
        transaction.commit();

    } catch (const std::exception &e) {
        return e.what();
    }

    return std::nullopt;
}

// Get track from database
std::optional<Track> DatabaseManager::get_track(const std::string &track_id) {
    SQLite::Statement query(*db, "SELECT * FROM Track WHERE id = ?");
    query.bind(1, track_id);

    if (query.executeStep()) {
        Track track;

        // If use getColumn("name"), time complexity is O(n). Optimizable if needed.
        track.id = query.getColumn("id").getString();
        track.pcm_hash = query.getColumn("pcm_hash").getString();

        track.work_id = SqliteHelper::get_optional<std::string>(query, "work_id");
        track.title = SqliteHelper::get_optional<std::string>(query, "title");
        track.recording_year = SqliteHelper::get_optional<int>(query, "recording_year");
        track.recording_month = SqliteHelper::get_optional<int>(query, "recording_month");
        track.recording_day = SqliteHelper::get_optional<int>(query, "recording_day");
        track.recording_location = SqliteHelper::get_optional<std::string>(query, "recording_location");
        track.duration = SqliteHelper::get_optional<int>(query, "duration");
        track.isrc = SqliteHelper::get_optional<std::string>(query, "isrc");
        track.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
        track.ytm_id = SqliteHelper::get_optional<std::string>(query, "ytm_id");
        track.spotify_id = SqliteHelper::get_optional<std::string>(query, "spotify_id");

        return track;
    }

    return std::nullopt;
}

// update track
std::optional<std::string> DatabaseManager::update_track(const TrackUpdate &data) {
    try {
        std::string sql = "UPDATE Track SET ";
        std::vector<std::string> fields;
        fields.reserve(12);

        if (data.work_id)
            fields.emplace_back("work_id = ?");
        if (data.pcm_hash)
            fields.emplace_back("pcm_hash = ?");
        if (data.title)
            fields.emplace_back("title = ?");
        if (data.recording_year)
            fields.emplace_back("recording_year = ?");
        if (data.recording_month)
            fields.emplace_back("recording_month = ?");
        if (data.recording_day)
            fields.emplace_back("recording_day = ?");
        if (data.recording_location)
            fields.emplace_back("recording_location = ?");
        if (data.duration)
            fields.emplace_back("duration = ?");
        if (data.isrc)
            fields.emplace_back("isrc = ?");
        if (data.musicbrainz_id)
            fields.emplace_back("musicbrainz_id = ?");
        if (data.ytm_id)
            fields.emplace_back("ytm_id = ?");
        if (data.spotify_id)
            fields.emplace_back("spotify_id = ?");

        if (fields.empty())
            return std::nullopt;

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1)
                sql += ", ";
        }
        sql += " WHERE id = ?";

        SQLite::Transaction transaction(*db);
        SQLite::Statement query(*db, sql);

        int bind_idx = 1;
        if (data.work_id)
            query.bind(bind_idx++, *data.work_id);
        if (data.pcm_hash)
            query.bind(bind_idx++, *data.pcm_hash);
        if (data.title)
            query.bind(bind_idx++, *data.title);
        if (data.recording_year)
            query.bind(bind_idx++, *data.recording_year);
        if (data.recording_month)
            query.bind(bind_idx++, *data.recording_month);
        if (data.recording_day)
            query.bind(bind_idx++, *data.recording_day);
        if (data.recording_location)
            query.bind(bind_idx++, *data.recording_location);
        if (data.duration)
            query.bind(bind_idx++, *data.duration);
        if (data.isrc)
            query.bind(bind_idx++, *data.isrc);
        if (data.musicbrainz_id)
            query.bind(bind_idx++, *data.musicbrainz_id);
        if (data.ytm_id)
            query.bind(bind_idx++, *data.ytm_id);
        if (data.spotify_id)
            query.bind(bind_idx++, *data.spotify_id);

        query.bind(bind_idx, data.id);

        int affected_rows = query.exec();
        if (affected_rows == 0)
            return "Track ID not found or no changes made.";

        SQLite::Statement update_entity(*db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::add_track_artist(const TrackArtistParams &params) {
    try {
        SQLite::Transaction transaction(*db);

        // SQLiteCpp bind must use std::string ensure Null-terminated
        const std::string track_id_str(params.track_id);
        const std::string artist_id_str(params.artist_id);

        // Poko-Yoke: Check if Track exists
        SQLite::Statement check_track(*db, "SELECT 1 FROM Track WHERE id = ?");
        check_track.bind(1, track_id_str);
        if (!check_track.executeStep()) {
            return "Target Track not found.";
        }

        // Poko-Yoke: Check if Artist exists
        SQLite::Statement check_artist(*db, "SELECT 1 FROM Artist WHERE id = ?");
        check_artist.bind(1, artist_id_str);
        if (!check_artist.executeStep()) {
            return "Target Artist not found.";
        }

        // Insert or Replace (Upsert)
        SQLite::Statement query(*db, "INSERT OR REPLACE INTO Track_Artist (track_id, artist_id, role, position) VALUES (?, ?, ?, ?)");
        query.bind(1, track_id_str);
        query.bind(2, artist_id_str);
        query.bind(3, std::string(ArtistRoleMapper::to_string(params.role)));

        if (params.position) {
            query.bind(4, *params.position);
        } else {
            query.bind(4); // Bind NULL
        }

        query.exec();

        // Update Entity timestamp
        SQLite::Statement update_entity(*db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, track_id_str);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::remove_track_artist(std::string_view track_id, std::string_view artist_id) {
    try {
        SQLite::Transaction transaction(*db);

        const std::string track_id_str(track_id);
        const std::string artist_id_str(artist_id);

        SQLite::Statement query(*db, "DELETE FROM Track_Artist WHERE track_id = ? AND artist_id = ?");
        query.bind(1, track_id_str);
        query.bind(2, artist_id_str);

        int affected_rows = query.exec();
        if (affected_rows == 0) {
            return "Relation not found or already removed.";
        }

        // Update Entity timestamp
        SQLite::Statement update_entity(*db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, track_id_str);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::update_track_artist(const TrackArtistParams &params) {
    try {
        SQLite::Transaction transaction(*db);

        const std::string track_id_str(params.track_id);
        const std::string artist_id_str(params.artist_id);

        SQLite::Statement query(*db, "UPDATE Track_Artist SET role = ?, position = COALESCE(?, position) WHERE track_id = ? AND artist_id = ?");
        query.bind(1, std::string(ArtistRoleMapper::to_string(params.role)));

        if (params.position) {
            query.bind(2, *params.position);
        } else {
            query.bind(2);
        }

        query.bind(3, track_id_str);
        query.bind(4, artist_id_str);

        int affected_rows = query.exec();
        if (affected_rows == 0) {
            return "Relation not found. Cannot update.";
        }

        SQLite::Statement update_entity(*db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, track_id_str);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

} // namespace lyra
