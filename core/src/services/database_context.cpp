// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
//
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "database_context.h"
#include <unordered_map>

namespace lyra {

SqliteDatabaseContext::SqliteDatabaseContext(const std::string &db_path)
    : m_db_path(db_path) {
    init_schema();
}

SQLite::Database &SqliteDatabaseContext::get_db() {
    thread_local std::unordered_map<std::string, std::unique_ptr<SQLite::Database>> tl_conns;
    auto &db_ptr = tl_conns[m_db_path];

    if (!db_ptr) {
        db_ptr = std::make_unique<SQLite::Database>(m_db_path, SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE);
        db_ptr->exec("PRAGMA journal_mode=WAL;");
        db_ptr->exec("PRAGMA foreign_keys=ON;");
        db_ptr->setBusyTimeout(5000);
    }
    return *db_ptr;
}

void SqliteDatabaseContext::init_schema() {
    auto &m_db = get_db();

    m_db.exec(R"(
        CREATE TABLE IF NOT EXISTS Asset (
          file_hash TEXT NOT NULL,
          mime_type TEXT NULL DEFAULT NULL,
          asset_type TEXT NULL DEFAULT NULL,
          file_size INTEGER NULL DEFAULT NULL,
          created_at TEXT DEFAULT (datetime('now')),
          PRIMARY KEY (file_hash)
        );
    )");

    m_db.exec(R"(
        CREATE TABLE IF NOT EXISTS Audio (
          pcm_hash TEXT NOT NULL,
          parent_hash TEXT NULL DEFAULT NULL,
          quality_score INTEGER NULL DEFAULT NULL,
          bit_depth INTEGER NULL DEFAULT NULL,
          sample_rate INTEGER NULL DEFAULT NULL,
          channels INTEGER NULL DEFAULT NULL,
          duration REAL NULL DEFAULT NULL,
          integrated_loudness REAL NULL DEFAULT NULL,
          true_peak REAL NULL DEFAULT NULL,
          PRIMARY KEY (pcm_hash),
          CONSTRAINT fk_Audio_Parent
            FOREIGN KEY (parent_hash)
            REFERENCES Audio (pcm_hash)
            ON DELETE SET NULL
            ON UPDATE CASCADE
        );
    )");

    m_db.exec(R"(
        CREATE TABLE IF NOT EXISTS Entity (
          id TEXT NOT NULL,
          entity_type TEXT NULL CHECK( entity_type IN ('track', 'album', 'artist', 'work', 'playlist', 'tag') ),
          created_at TEXT DEFAULT (datetime('now')),
          updated_at TEXT DEFAULT (datetime('now')),
          PRIMARY KEY (id)
        );
    )");

    m_db.exec(R"(
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

    m_db.exec(R"(
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
            ON UPDATE CASCADE,
          CONSTRAINT fk_Track_Work
            FOREIGN KEY (work_id)
            REFERENCES Work (id)
            ON DELETE SET NULL
            ON UPDATE CASCADE
        );
    )");

    m_db.exec(R"(
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

    m_db.exec(R"(
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

    m_db.exec(R"(
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

    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Work_iswc ON Work (iswc);");
    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Work_musicbrainz_id ON Work (musicbrainz_id);");

    m_db.exec(R"(
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

    m_db.exec(R"(
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

    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Artist_name ON Artist (name);");
    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Album_title ON Album (title);");
    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Playlist_title ON Playlist (title);");
    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Track_title ON Track (title);");
    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Work_title ON Work (title);");
    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Audio_parent_hash ON Audio (parent_hash);");
    m_db.exec("CREATE INDEX IF NOT EXISTS idx_Asset_asset_type ON Asset (asset_type);");
}

std::unique_ptr<ITransaction> SqliteDatabaseContext::begin_transaction() {
    thread_local std::unordered_map<std::string, int> tl_depths;
    int &depth = tl_depths[m_db_path];
    return std::make_unique<SqliteTransaction>(get_db(), depth);
}

} // namespace lyra
