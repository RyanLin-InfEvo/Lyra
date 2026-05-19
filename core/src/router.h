/*
 * SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#pragma once

#include <functional>
#include <memory>
#include <nlohmann/json.hpp>
#include <string>
#include <unordered_map>

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
    void init_handlers();

    // Handler Member Functions
    json handleCreateArtist(const json &p);
    json handleUpdateArtist(const json &p);
    json handleGetArtist(const json &p);

    json handleCreateTrack(const json &p);
    json handleUpdateTrack(const json &p);
    json handleGetTrack(const json &p);

    json handleCreateAlbum(const json &p);
    json handleUpdateAlbum(const json &p);
    json handleGetAlbum(const json &p);

    json handleCreateWork(const json &p);
    json handleUpdateWork(const json &p);
    json handleGetWork(const json &p);

    json handleAddTrackArtist(const json &p);
    json handleRemoveTrackArtist(const json &p);
    json handleUpdateTrackArtist(const json &p);

    json handleCreatePlaylist(const json &p);
    json handleUpdatePlaylist(const json &p);
    json handleGetPlaylist(const json &p);
    json handleAddPlaylistTrack(const json &p);
    json handleRemovePlaylistTrack(const json &p);
    json handleGetPlaylistTracks(const json &p);

    // Dependencies
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

    // Handler Mapping
    using Handler = std::function<json(const json &)>;
    std::unordered_map<std::string, Handler> m_handlers;
};

} // namespace lyra
