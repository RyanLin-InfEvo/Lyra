/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <optional>
#include <string>

#include "../models/artist.h"
#include "../models/track.h"

class DatabaseManager {
  public:
    // initialize database
    static void init_database(const std::string &db_path);

    // insert artist into database
    static std::optional<std::string> insert_artist(const Artist &artist);

    // update artist
    static std::optional<std::string> update_artist(const ArtistUpdate &update_data);

    // get a artist from database
    static std::optional<Artist> get_artist(const std::string &artist_id);

    // insert track into database
    static std::optional<std::string> insert_track(const Track &track);

    // get a track from database
    static std::optional<Track> get_track(const std::string &track_id);
};
