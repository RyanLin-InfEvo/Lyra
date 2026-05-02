/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <optional>
#include <string>

#include "../models/artist.h"
#include "../models/playlist.h"
#include "../models/relation_types.h"
#include "../models/track.h"
#include "../models/work.h"

namespace lyra {

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

    // update track
    static std::optional<std::string> update_track(const TrackUpdate &update_data);

    // insert work into database
    static std::optional<std::string> insert_work(const Work &work);

    // get a work from database
    static std::optional<Work> get_work(const std::string &work_id);

    // update work
    static std::optional<std::string> update_work(const WorkUpdate &update_data);

    // insert playlist into database
    static std::optional<std::string> insert_playlist(const Playlist &playlist);

    // get a playlist from database
    static std::optional<Playlist> get_playlist(const std::string &playlist_id);

    // update playlist
    static std::optional<std::string> update_playlist(const PlaylistUpdate &update_data);

    static std::optional<std::string> add_track_artist(const TrackArtistParams &params);

    static std::optional<std::string> remove_track_artist(const std::string_view track_id, const std::string_view artist_id);

    static std::optional<std::string> update_track_artist(const TrackArtistParams &params);

    static std::optional<std::string> add_playlist_track(const std::string &playlist_id, const std::string &track_id, std::optional<int> position = std::nullopt);

    static std::optional<std::string> remove_playlist_track(const std::string &playlist_id, const std::string &track_id);

    static std::vector<std::string> get_playlist_tracks(const std::string &playlist_id);
};

} // namespace lyra
