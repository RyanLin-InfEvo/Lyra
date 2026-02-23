#include <SQLiteCpp/SQLiteCpp.h>
#include <memory>
#include <optional>
#include <string>

#include "../models/artist.h"
#include "database.h"

static std::unique_ptr<SQLite::Database> db;

void Database::init_database(const std::string &db_path) {
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
          description TEXT NULL DEFAULT NULL,
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
}

// Insert artist into database
bool Database::insert_artist(const Artist &artist) {

  SQLite::Transaction transaction(*db);

  // insert into Entity table
  SQLite::Statement query1(
      *db, "INSERT INTO Entity (id, entity_type) VALUES (?, 'artist')");
  query1.bind(1, artist.id);
  query1.exec();

  // insert into Artist table
  SQLite::Statement query2(
      *db, "INSERT INTO Artist (id, name, description) VALUES (?, ?, ?)");
  query2.bind(1, artist.id);
  query2.bind(2, artist.name);
  query2.bind(3, artist.description);
  query2.exec();

  transaction.commit();

  return 1;
}

// Get artist from database
std::optional<Artist> Database::get_artist(const std::string &artist_id) {

  SQLite::Statement query(*db, "SELECT a.id, a.name, a.description "
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
    artist.description = query.getColumn("description").isNull()
                             ? ""
                             : query.getColumn("description").getString();

    return artist;
  }

  // if no artist found, return nullopt
  return std::nullopt;
}