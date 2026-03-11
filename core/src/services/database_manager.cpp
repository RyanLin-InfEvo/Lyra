// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "database_manager.h"
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
          entity_type TEXT NULL CHECK( entity_type IN ('track', 'album', 'artist', 'work', 'playlist') ),
          created_at TEXT NULL,
          updated_at TEXT NULL,
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
          id TEXT NOT NULL,
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
          PRIMARY KEY (id, pcm_hash),
          CONSTRAINT fk_Track_Entity
            FOREIGN KEY (id)
            REFERENCES Entity (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
        );
    )");
}

// Insert artist into database
std::optional<std::string> DatabaseManager::insert_artist(const Artist &artist) {

    try {
        SQLite::Transaction transaction(*db);

        // insert into Entity table
        SQLite::Statement query1(
            *db, "INSERT INTO Entity (id, entity_type) VALUES (?, 'artist')");
        query1.bind(1, artist.id);
        query1.exec();

        // insert into Artist table
        SQLite::Statement query2(
            *db, "INSERT INTO Artist (id, name) VALUES (?, ?)");
        query2.bind(1, artist.id);
        query2.bind(2, artist.name);
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

    SQLite::Statement query(*db, "SELECT a.id, a.name "
                                 "FROM Artist a "
                                 "WHERE a.id = ?");

    query.bind(1, artist_id);

    // if artist found, return a Artist object
    if (query.executeStep()) {
        Artist artist;

        // Fill the Artist object with data from the database
        // If use getColumn("name"), time complexity is O(n)
        // If use getColumn(1), time complexity is O(1)
        artist.id = query.getColumn("id").getString();
        artist.name = query.getColumn("name").getString();

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
        SQLite::Statement query1(*db, "INSERT INTO Entity (id, entity_type) VALUES (?, 'track')");
        query1.bind(1, track.id);
        query1.exec();

        // Insert into Track table
        SQLite::Statement query2(
            *db,
            "INSERT INTO Track (id, work_id, pcm_hash, title, recording_year, recording_month, recording_day, recording_location, duration, isrc, musicbrainz_id, ytm_id, spotify_id) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

        // --- Create Lambda helper functions ---
        // Bind optional string (store as NULL if empty string)
        auto bind_opt_str = [&query2](int index, const std::string &val) {
            if (val.empty()) {
                query2.bind(index);
            } else {
                query2.bind(index, val);
            }
        };

        // Bind optional integer (store as NULL if 0)
        auto bind_opt_int = [&query2](int index, int val) {
            if (val == 0) {
                query2.bind(index);
            } else {
                query2.bind(index, val);
            }
        };

        // Execute binding
        query2.bind(1, track.id);                  // NOT NULL
        bind_opt_str(2, track.work_id);            // optional
        query2.bind(3, track.pcm_hash);            // NOT NULL
        bind_opt_str(4, track.title);              // optional
        bind_opt_int(5, track.recording_year);     // optional
        bind_opt_int(6, track.recording_month);    // optional
        bind_opt_int(7, track.recording_day);      // optional
        bind_opt_str(8, track.recording_location); // optional
        bind_opt_str(9, track.isrc);               // optional
        bind_opt_str(10, track.spotify_id);        // optional

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

        if (!query.getColumn("work_id").isNull())
            track.work_id = query.getColumn("work_id").getString();
        track.pcm_hash = query.getColumn("pcm_hash").getString();
        if (!query.getColumn("title").isNull())
            track.title = query.getColumn("title").getString();
        if (!query.getColumn("recording_year").isNull())
            track.recording_year = query.getColumn("recording_year").getInt();
        if (!query.getColumn("recording_month").isNull())
            track.recording_month = query.getColumn("recording_month").getInt();
        if (!query.getColumn("recording_day").isNull())
            track.recording_day = query.getColumn("recording_day").getInt();
        if (!query.getColumn("recording_location").isNull())
            track.recording_location = query.getColumn("recording_location").getString();
        if (!query.getColumn("duration").isNull())
            track.duration = query.getColumn("duration").getInt();
        if (!query.getColumn("isrc").isNull())
            track.isrc = query.getColumn("isrc").getString();
        if (!query.getColumn("musicbrainz_id").isNull())
            track.musicbrainz_id = query.getColumn("musicbrainz_id").getString();
        if (!query.getColumn("ytm_id").isNull())
            track.ytm_id = query.getColumn("ytm_id").getString();
        if (!query.getColumn("spotify_id").isNull())
            track.spotify_id = query.getColumn("spotify_id").getString();

        return track;
    }

    return std::nullopt;
}
