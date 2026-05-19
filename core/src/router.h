/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <memory>
#include <nlohmann/json.hpp>
#include <string>

namespace lyra {

using json = nlohmann::json;

class IDatabaseContext;
class IAlbumRepository;
class IArtistRepository;
class IPlaylistRepository;
class ITrackRepository;
class IWorkRepository;

class AlbumController;
class ArtistController;
class PlaylistController;
class TrackController;
class WorkController;

class Router {
  public:
    explicit Router(const std::string &db_path);
    ~Router();

    json route(const json &request);

  private:
    std::unique_ptr<IDatabaseContext> m_db_context;

    std::unique_ptr<IAlbumRepository> m_album_repo;
    std::unique_ptr<IArtistRepository> m_artist_repo;
    std::unique_ptr<IPlaylistRepository> m_playlist_repo;
    std::unique_ptr<ITrackRepository> m_track_repo;
    std::unique_ptr<IWorkRepository> m_work_repo;

    std::unique_ptr<AlbumController> m_album_controller;
    std::unique_ptr<ArtistController> m_artist_controller;
    std::unique_ptr<PlaylistController> m_playlist_controller;
    std::unique_ptr<TrackController> m_track_controller;
    std::unique_ptr<WorkController> m_work_controller;
};

} // namespace lyra
