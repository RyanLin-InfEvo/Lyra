/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <optional>
#include <string>

#include "../models/artist.h"

class DatabaseManager {
  public:
    // initialize database
    static void init_database(const std::string &db_path);

    // insert artist into database
    static std::optional<std::string> insert_artist(const Artist &artist);

    // get a artist from database
    static std::optional<Artist> get_artist(const std::string &artist_id);
};
