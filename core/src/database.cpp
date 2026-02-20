#include "database.h"
#include <SQLiteCpp/SQLiteCpp.h>
#include <memory>

static std::unique_ptr<SQLite::Database> db;

void init_database(const std::string &db_path) {
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
}

void insert_artist(const std::string &uuid, const std::string &name) {

  SQLite::Transaction transaction(*db);

  // insert into Entity table
  SQLite::Statement query1(
      *db, "INSERT INTO Entity (id, entity_type) VALUES (?, 'artist')");
  query1.bind(1, uuid);
  query1.exec();

  // insert into Artist table
  SQLite::Statement query2(*db, "INSERT INTO Artist (id, name) VALUES (?, ?)");
  query2.bind(1, uuid);
  query2.bind(2, name);
  query2.exec();

  transaction.commit();
}