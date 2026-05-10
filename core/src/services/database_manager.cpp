// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include <SQLiteCpp/SQLiteCpp.h>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <optional>
#include <queue>
#include <string>
#include <vector>

#include "../models/relation_types.h"
#include "../utils/sqlite_helper.h"
#include "database_manager.h"

namespace lyra {

namespace {

/**
 * @brief A simple thread-safe connection pool for SQLite read-only operations.
 */
class ConnectionPool {
  public:
    ConnectionPool(const std::string &db_path, size_t pool_size) : path(db_path) {
        for (size_t i = 0; i < pool_size; ++i) {
            auto conn = std::make_unique<SQLite::Database>(path, SQLite::OPEN_READONLY);
            // Optimization: Read-only connections don't strictly need WAL pragma
            // but foreign keys are good practice.
            conn->exec("PRAGMA foreign_keys=ON;");
            pool.push(std::move(conn));
        }
    }

    std::unique_ptr<SQLite::Database> acquire() {
        std::unique_lock<std::mutex> lock(mutex);
        // TODO: In a high-concurrency server environment, consider using wait_for() 
        // with a timeout to prevent potential deadlocks if the pool is exhausted 
        // and a thread holds a resource while waiting for another.
        condition.wait(lock, [this] { return !pool.empty(); });
        auto conn = std::move(pool.front());
        pool.pop();
        return conn;
    }

    void release(std::unique_ptr<SQLite::Database> conn) {
        if (!conn) {
            return; // Best Practice: Prevent pool contamination with nullptr
        }
        std::lock_guard<std::mutex> lock(mutex);
        pool.push(std::move(conn));
        condition.notify_one();
    }

  private:
    std::string path;
    std::queue<std::unique_ptr<SQLite::Database>> pool;
    std::mutex mutex;
    std::condition_variable condition;
};

/**
 * @brief RAII guard to safely acquire and release a connection from the pool.
 */
class ConnectionGuard {
  public:
    explicit ConnectionGuard(ConnectionPool &p) : pool(p), conn(pool.acquire()) {}
    ~ConnectionGuard() { pool.release(std::move(conn)); }

    // Best Practice: Explicitly delete copy and move to prevent resource leakage or double release
    ConnectionGuard(const ConnectionGuard &) = delete;
    ConnectionGuard &operator=(const ConnectionGuard &) = delete;
    ConnectionGuard(ConnectionGuard &&) = delete;
    ConnectionGuard &operator=(ConnectionGuard &&) = delete;

    SQLite::Database &get() { return *conn; }

  private:
    ConnectionPool &pool;
    std::unique_ptr<SQLite::Database> conn;
};

} // namespace

static std::unique_ptr<SQLite::Database> write_db;
static std::mutex write_mutex;

static std::unique_ptr<ConnectionPool> read_pool;

void DatabaseManager::init_database(const std::string &db_path) {
    std::lock_guard<std::mutex> lock(write_mutex);

    // TODO: SQLite fundamentally serializes writes at the database file level.
    // If high-volume concurrent writes become a bottleneck in the future,
    // consider migrating to a client-server database like PostgreSQL.

    // open write connection
    write_db =
        std::make_unique<SQLite::Database>(db_path, SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);

    // enable WAL mode and foreign key support
    write_db->exec("PRAGMA journal_mode=WAL;");
    write_db->exec("PRAGMA foreign_keys=ON;");

    // Initialize Read Connection Pool
    // Best Practice: Use hardware concurrency to adapt to different environments.
    // Ensure at least 2 connections (one for background tasks if needed).
    unsigned int n = std::thread::hardware_concurrency();
    size_t pool_size = (n > 0) ? n : 4;
    read_pool = std::make_unique<ConnectionPool>(db_path, pool_size);

    // create Entity table
    write_db->exec(R"(
        CREATE TABLE IF NOT EXISTS Entity (
          id TEXT NOT NULL,
          entity_type TEXT NULL CHECK( entity_type IN ('track', 'album', 'artist', 'work', 'playlist', 'tag') ),
          created_at TEXT DEFAULT (datetime('now')),
          updated_at TEXT DEFAULT (datetime('now')),
          PRIMARY KEY (id)
        );
    )");

    // create Artist table (it is bound to Entity table)
    write_db->exec(R"(
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
    write_db->exec(R"(
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

    write_db->exec(R"(
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

    // create Album table
    write_db->exec(R"(
        CREATE TABLE IF NOT EXISTS Album (
          id TEXT NOT NULL,
          title TEXT NOT NULL,
          release_year INTEGER NULL DEFAULT NULL,
          release_month INTEGER NULL DEFAULT NULL,
          release_day INTEGER NULL DEFAULT NULL,
          PRIMARY KEY (id),
          CONSTRAINT fk_Album_Entity
            FOREIGN KEY (id)
            REFERENCES Entity (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
        );
    )");

    // create Work table
    write_db->exec(R"(
        CREATE TABLE IF NOT EXISTS Work (
          id TEXT NOT NULL,
          title TEXT NOT NULL,
          composition_start_year INTEGER NULL DEFAULT NULL,
          composition_end_year INTEGER NULL DEFAULT NULL,
          composition_date_text TEXT NULL DEFAULT NULL,
          iswc TEXT NULL DEFAULT NULL UNIQUE,
          musicbrainz_id TEXT NULL DEFAULT NULL,
          PRIMARY KEY (id),
          CONSTRAINT fk_Work_Entity
            FOREIGN KEY (id)
            REFERENCES Entity (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
          CHECK (composition_start_year <= composition_end_year)
        );
    )");

    write_db->exec("CREATE INDEX IF NOT EXISTS idx_Work_iswc ON Work (iswc);");
    write_db->exec("CREATE INDEX IF NOT EXISTS idx_Work_musicbrainz_id ON Work (musicbrainz_id);");

    // create Playlist table
    write_db->exec(R"(
        CREATE TABLE IF NOT EXISTS Playlist (
          id TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT NULL DEFAULT NULL,
          PRIMARY KEY (id),
          CONSTRAINT fk_Playlist_Entity
            FOREIGN KEY (id)
            REFERENCES Entity (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
        );
    )");

    // create Playlist_Track table
    write_db->exec(R"(
        CREATE TABLE IF NOT EXISTS Playlist_Track (
          playlist_id TEXT NOT NULL,
          track_id TEXT NOT NULL,
          position INTEGER NULL DEFAULT NULL,
          PRIMARY KEY (playlist_id, track_id),
          CONSTRAINT fk_PlaylistTrack_Playlist
            FOREIGN KEY (playlist_id)
            REFERENCES Playlist (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE,
          CONSTRAINT fk_PlaylistTrack_Track
            FOREIGN KEY (track_id)
            REFERENCES Track (id)
            ON DELETE CASCADE
            ON UPDATE CASCADE
        );
    )");
}

// Insert artist into database table Artist, Entity
// Return nullopt or error message(string)
std::optional<std::string> DatabaseManager::insert_artist(const Artist &artist) {
    std::lock_guard<std::mutex> lock(write_mutex);

    try {
        SQLite::Transaction transaction(*write_db);

        // insert into Entity table
        SQLite::Statement query1(*write_db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'artist', datetime('now'), datetime('now'))");
        query1.bind(1, artist.id);
        query1.exec();

        // insert into Artist table
        SQLite::Statement query2(*write_db, "INSERT INTO Artist (id, name, musicbrainz_id, "
                                      "spotify_id, ytm_id) VALUES (?, ?, ?, ?, ?)");

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
    std::lock_guard<std::mutex> lock(write_mutex);
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
        SQLite::Transaction transaction(*write_db);
        SQLite::Statement query(*write_db, sql);

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
            return "Artist ID not found.";
        }

        // Update successful, sync Entity updated_at
        SQLite::Statement update_entity(
            *write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
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
    ConnectionGuard guard(*read_pool);
    auto &db = guard.get();

    SQLite::Statement query(db, "SELECT * FROM Artist WHERE id = ?");

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
// Return nullopt or error message(string)
std::optional<std::string> DatabaseManager::insert_track(const Track &track) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        // Insert into Entity table
        SQLite::Statement query1(*write_db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'track', datetime('now'), datetime('now'))");
        query1.bind(1, track.id);
        query1.exec();

        // Insert into Track table
        SQLite::Statement query2(*write_db,
                                 "INSERT INTO Track (id, work_id, pcm_hash, title, recording_year, "
                                 "recording_month, recording_day, recording_location, duration, "
                                 "isrc, musicbrainz_id, ytm_id, spotify_id) "
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
    ConnectionGuard guard(*read_pool);
    auto &db = guard.get();

    SQLite::Statement query(db, "SELECT * FROM Track WHERE id = ?");
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
        track.recording_location =
            SqliteHelper::get_optional<std::string>(query, "recording_location");
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
    std::lock_guard<std::mutex> lock(write_mutex);
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

        SQLite::Transaction transaction(*write_db);
        SQLite::Statement query(*write_db, sql);

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
            return "Track ID not found.";

        SQLite::Statement update_entity(
            *write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

// Insert album into database
std::optional<std::string> DatabaseManager::insert_album(const Album &album) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        // Insert into Entity table
        SQLite::Statement query1(*write_db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'album', datetime('now'), datetime('now'))");
        query1.bind(1, album.id);
        query1.exec();

        // Insert into Album table
        SQLite::Statement query2(*write_db,
                                 "INSERT INTO Album (id, title, release_year, release_month, release_day) "
                                 "VALUES (?, ?, ?, ?, ?)");

        auto bind_opt = [&query2](int index, const auto &val) {
            if (val) {
                query2.bind(index, *val);
            } else {
                query2.bind(index);
            }
        };

        query2.bind(1, album.id);
        query2.bind(2, album.title);
        bind_opt(3, album.release_year);
        bind_opt(4, album.release_month);
        bind_opt(5, album.release_day);

        query2.exec();
        transaction.commit();

    } catch (const std::exception &e) {
        return e.what();
    }

    return std::nullopt;
}

// Get album from database
std::optional<Album> DatabaseManager::get_album(const std::string &album_id) {
    ConnectionGuard guard(*read_pool);
    auto &db = guard.get();

    SQLite::Statement query(db, "SELECT * FROM Album WHERE id = ?");
    query.bind(1, album_id);

    if (query.executeStep()) {
        Album album;

        album.id = query.getColumn("id").getString();
        album.title = query.getColumn("title").getString();

        album.release_year = SqliteHelper::get_optional<int>(query, "release_year");
        album.release_month = SqliteHelper::get_optional<int>(query, "release_month");
        album.release_day = SqliteHelper::get_optional<int>(query, "release_day");

        return album;
    }

    return std::nullopt;
}

// update album
std::optional<std::string> DatabaseManager::update_album(const AlbumUpdate &data) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        std::string sql = "UPDATE Album SET ";
        std::vector<std::string> fields;
        fields.reserve(4);

        if (data.title)
            fields.emplace_back("title = ?");
        if (data.release_year)
            fields.emplace_back("release_year = ?");
        if (data.release_month)
            fields.emplace_back("release_month = ?");
        if (data.release_day)
            fields.emplace_back("release_day = ?");

        if (fields.empty())
            return std::nullopt;

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1)
                sql += ", ";
        }
        sql += " WHERE id = ?";

        SQLite::Transaction transaction(*write_db);
        SQLite::Statement query(*write_db, sql);

        int bind_idx = 1;
        if (data.title)
            query.bind(bind_idx++, *data.title);
        if (data.release_year)
            query.bind(bind_idx++, *data.release_year);
        if (data.release_month)
            query.bind(bind_idx++, *data.release_month);
        if (data.release_day)
            query.bind(bind_idx++, *data.release_day);

        query.bind(bind_idx, data.id);

        int affected_rows = query.exec();
        if (affected_rows == 0)
            return "Album ID not found.";

        SQLite::Statement update_entity(
            *write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

// Insert work into database
std::optional<std::string> DatabaseManager::insert_work(const Work &work) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        // Insert into Entity table
        SQLite::Statement query1(*write_db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'work', datetime('now'), datetime('now'))");
        query1.bind(1, work.id);
        query1.exec();

        // Insert into Work table
        SQLite::Statement query2(*write_db, "INSERT INTO Work (id, title, composition_start_year, "
                                      "composition_end_year, composition_date_text, iswc, "
                                      "musicbrainz_id) VALUES (?, ?, ?, ?, ?, ?, ?)");

        auto bind_opt = [&query2](int index, const auto &val) {
            if (val) {
                query2.bind(index, *val);
            } else {
                query2.bind(index);
            }
        };

        query2.bind(1, work.id);
        query2.bind(2, work.title);
        bind_opt(3, work.composition_start_year);
        bind_opt(4, work.composition_end_year);
        bind_opt(5, work.composition_date_text);
        bind_opt(6, work.iswc);
        bind_opt(7, work.musicbrainz_id);

        query2.exec();
        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

// Get work from database
std::optional<Work> DatabaseManager::get_work(const std::string &work_id) {
    ConnectionGuard guard(*read_pool);
    auto &db = guard.get();

    SQLite::Statement query(db, "SELECT * FROM Work WHERE id = ?");
    query.bind(1, work_id);

    if (query.executeStep()) {
        Work work;
        work.id = query.getColumn("id").getString();
        work.title = query.getColumn("title").getString();
        work.composition_start_year =
            SqliteHelper::get_optional<int>(query, "composition_start_year");
        work.composition_end_year = SqliteHelper::get_optional<int>(query, "composition_end_year");
        work.composition_date_text =
            SqliteHelper::get_optional<std::string>(query, "composition_date_text");
        work.iswc = SqliteHelper::get_optional<std::string>(query, "iswc");
        work.musicbrainz_id = SqliteHelper::get_optional<std::string>(query, "musicbrainz_id");
        return work;
    }
    return std::nullopt;
}

// update work
std::optional<std::string> DatabaseManager::update_work(const WorkUpdate &data) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        std::string sql = "UPDATE Work SET ";
        std::vector<std::string> fields;
        fields.reserve(6);

        if (data.title)
            fields.emplace_back("title = ?");
        if (data.composition_start_year)
            fields.emplace_back("composition_start_year = ?");
        if (data.composition_end_year)
            fields.emplace_back("composition_end_year = ?");
        if (data.composition_date_text)
            fields.emplace_back("composition_date_text = ?");
        if (data.iswc)
            fields.emplace_back("iswc = ?");
        if (data.musicbrainz_id)
            fields.emplace_back("musicbrainz_id = ?");

        if (fields.empty())
            return std::nullopt;

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1)
                sql += ", ";
        }
        sql += " WHERE id = ?";

        SQLite::Transaction transaction(*write_db);
        SQLite::Statement query(*write_db, sql);

        int bind_idx = 1;
        if (data.title)
            query.bind(bind_idx++, *data.title);
        if (data.composition_start_year)
            query.bind(bind_idx++, *data.composition_start_year);
        if (data.composition_end_year)
            query.bind(bind_idx++, *data.composition_end_year);
        if (data.composition_date_text)
            query.bind(bind_idx++, *data.composition_date_text);
        if (data.iswc)
            query.bind(bind_idx++, *data.iswc);
        if (data.musicbrainz_id)
            query.bind(bind_idx++, *data.musicbrainz_id);

        query.bind(bind_idx, data.id);

        int affected_rows = query.exec();
        if (affected_rows == 0)
            return "Work ID not found.";

        SQLite::Statement update_entity(
            *write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::add_track_artist(const TrackArtistParams &params) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        // Poko-Yoke: Check if Track exists
        SQLite::Statement check_track(*write_db, "SELECT 1 FROM Track WHERE id = ?");
        check_track.bindNoCopy(1, params.track_id);
        if (!check_track.executeStep()) {
            return "Target Track not found.";
        }

        // Poko-Yoke: Check if Artist exists
        SQLite::Statement check_artist(*write_db, "SELECT 1 FROM Artist WHERE id = ?");
        check_artist.bindNoCopy(1, params.artist_id);
        if (!check_artist.executeStep()) {
            return "Target Artist not found.";
        }

        // Insert or Replace (Upsert)
        SQLite::Statement query(*write_db, "INSERT OR REPLACE INTO Track_Artist (track_id, "
                                     "artist_id, role, position) VALUES (?, ?, ?, ?)");
        query.bindNoCopy(1, params.track_id);
        query.bindNoCopy(2, params.artist_id);
        if (params.role) {
            query.bindNoCopy(3, ArtistRoleMapper::to_string(*params.role));
        } else {
            query.bind(3); // Bind NULL
        }

        if (params.position) {
            query.bind(4, *params.position);
        } else {
            query.bind(4); // Bind NULL
        }

        query.exec();

        // Update Entity timestamp
        SQLite::Statement update_entity(
            *write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bindNoCopy(1, params.track_id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::remove_track_artist(const std::string& track_id,
                                                                const std::string& artist_id) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        SQLite::Statement query(*write_db,
                                "DELETE FROM Track_Artist WHERE track_id = ? AND artist_id = ?");
        query.bindNoCopy(1, track_id);
        query.bindNoCopy(2, artist_id);

        int affected_rows = query.exec();
        if (affected_rows == 0) {
            return "Relation not found or already removed.";
        }

        // Update Entity timestamp
        SQLite::Statement update_entity(
            *write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bindNoCopy(1, track_id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::update_track_artist(const TrackArtistParams &params) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        SQLite::Statement query(*write_db, "UPDATE Track_Artist SET role = COALESCE(?, role), "
                                     "position = COALESCE(?, position) WHERE track_id = ? AND "
                                     "artist_id = ?");

        if (params.role) {
            query.bindNoCopy(1, ArtistRoleMapper::to_string(*params.role));
        } else {
            query.bind(1);
        }

        if (params.position) {
            query.bind(2, *params.position);
        } else {
            query.bind(2);
        }

        query.bindNoCopy(3, params.track_id);
        query.bindNoCopy(4, params.artist_id);

        int affected_rows = query.exec();
        if (affected_rows == 0) {
            return "Relation not found. Cannot update.";
        }

        SQLite::Statement update_entity(
            *write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bindNoCopy(1, params.track_id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::insert_playlist(const Playlist &playlist) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        // Insert into Entity table
        SQLite::Statement query1(*write_db,
                                 "INSERT INTO Entity (id, entity_type, created_at, updated_at) "
                                 "VALUES (?, 'playlist', datetime('now'), datetime('now'))");
        query1.bind(1, playlist.id);
        query1.exec();

        // Insert into Playlist table
        SQLite::Statement query2(*write_db, "INSERT INTO Playlist (id, title, description) VALUES (?, ?, ?)");
        query2.bind(1, playlist.id);
        query2.bind(2, playlist.title);
        if (playlist.description) {
            query2.bind(3, *playlist.description);
        } else {
            query2.bind(3);
        }

        query2.exec();
        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<Playlist> DatabaseManager::get_playlist(const std::string &playlist_id) {
    ConnectionGuard guard(*read_pool);
    auto &db = guard.get();

    SQLite::Statement query(db, "SELECT * FROM Playlist WHERE id = ?");
    query.bind(1, playlist_id);

    if (query.executeStep()) {
        Playlist playlist;
        playlist.id = query.getColumn("id").getString();
        playlist.title = query.getColumn("title").getString();
        playlist.description = SqliteHelper::get_optional<std::string>(query, "description");
        return playlist;
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::update_playlist(const PlaylistUpdate &data) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        std::string sql = "UPDATE Playlist SET ";
        std::vector<std::string> fields;
        fields.reserve(2);

        if (data.title)
            fields.emplace_back("title = ?");
        if (data.description)
            fields.emplace_back("description = ?");

        if (fields.empty())
            return std::nullopt;

        for (size_t i = 0; i < fields.size(); ++i) {
            sql += fields[i];
            if (i < fields.size() - 1)
                sql += ", ";
        }
        sql += " WHERE id = ?";

        SQLite::Transaction transaction(*write_db);
        SQLite::Statement query(*write_db, sql);

        int bind_idx = 1;
        if (data.title)
            query.bind(bind_idx++, *data.title);
        if (data.description)
            query.bind(bind_idx++, *data.description);

        query.bind(bind_idx, data.id);

        int affected_rows = query.exec();
        if (affected_rows == 0)
            return "Playlist ID not found.";

        SQLite::Statement update_entity(
            *write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, data.id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::add_playlist_track(const std::string &playlist_id,
                                                               const std::string &track_id,
                                                               std::optional<int> position) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        // Check if playlist exists
        SQLite::Statement check_playlist(*write_db, "SELECT 1 FROM Playlist WHERE id = ?");
        check_playlist.bind(1, playlist_id);
        if (!check_playlist.executeStep()) {
            return "Playlist ID not found.";
        }

        // Check if track exists
        SQLite::Statement check_track(*write_db, "SELECT 1 FROM Track WHERE id = ?");
        check_track.bind(1, track_id);
        if (!check_track.executeStep()) {
            return "Track ID not found.";
        }

        // Insert or Replace into Playlist_Track
        SQLite::Statement query(*write_db, "INSERT OR REPLACE INTO Playlist_Track (playlist_id, track_id, position) VALUES (?, ?, ?)");
        query.bind(1, playlist_id);
        query.bind(2, track_id);
        if (position) {
            query.bind(3, *position);
        } else {
            query.bind(3);
        }

        query.exec();

        // Update Playlist timestamp
        SQLite::Statement update_entity(*write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, playlist_id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::optional<std::string> DatabaseManager::remove_playlist_track(const std::string &playlist_id,
                                                                  const std::string &track_id) {
    std::lock_guard<std::mutex> lock(write_mutex);
    try {
        SQLite::Transaction transaction(*write_db);

        SQLite::Statement query(*write_db, "DELETE FROM Playlist_Track WHERE playlist_id = ? AND track_id = ?");
        query.bind(1, playlist_id);
        query.bind(2, track_id);

        int affected_rows = query.exec();
        if (affected_rows == 0) {
            return "Track not found in playlist.";
        }

        // Update Playlist timestamp
        SQLite::Statement update_entity(*write_db, "UPDATE Entity SET updated_at = datetime('now') WHERE id = ?");
        update_entity.bind(1, playlist_id);
        update_entity.exec();

        transaction.commit();
    } catch (const std::exception &e) {
        return e.what();
    }
    return std::nullopt;
}

std::vector<std::string> DatabaseManager::get_playlist_tracks(const std::string &playlist_id) {
    ConnectionGuard guard(*read_pool);
    auto &db = guard.get();

    std::vector<std::string> track_ids;
    try {
        SQLite::Statement query(db, "SELECT track_id FROM Playlist_Track WHERE playlist_id = ? ORDER BY position ASC, track_id ASC");
        query.bind(1, playlist_id);

        while (query.executeStep()) {
            track_ids.push_back(query.getColumn(0).getString());
        }
    } catch (const std::exception &e) {
        // Log error or handle it as needed
    }
    return track_ids;
}

} // namespace lyra
