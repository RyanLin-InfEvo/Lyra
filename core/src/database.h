#pragma once

#include <optional>
#include <string>

#include "models/artist.h"

class Database {
public:
  // initialize database
  static void init_database(const std::string &db_path);

  // insert artist into database
  static bool insert_artist(const Artist &artist);

  // get a artist from database
  static std::optional<Artist> get_artist(const std::string &artist_id);
};
