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

struct Image;

class IDatabaseContext;
class IAlbumRepository;
class IArtistRepository;
class IAssetRepository;
class IAudioRepository;
class IImageRepository;
class IPlaylistRepository;
class ITrackRepository;
class IWorkRepository;

class AlbumController;
class ArtistController;
class AssetController;
class AudioController;
class PlaylistController;
class TrackController;
class WorkController;

class AudioEngine;
class IngestionService;
class CoverArtService;
struct CoverResolutionResult;

class Router {
  public:
    explicit Router(const std::string &db_path);
    ~Router();

    json route(const json &request);
    void set_event_callback(std::function<void(const std::string &)> callback);
    AudioEngine &get_audio_engine();

  private:
    void init_handlers();

    // Handler Member Functions
    json handleCreateArtist(const json &p);
    json handleUpdateArtist(const json &p);
    json handleGetArtist(const json &p);
    json handleListArtists(const json &p);

    json handleCreateTrack(const json &p);
    json handleUpdateTrack(const json &p);
    json handleGetTrack(const json &p);
    json handleListTracks(const json &p);
    json handleImportTrack(const json &p);

    json handleCreateAlbum(const json &p);
    json handleUpdateAlbum(const json &p);
    json handleGetAlbum(const json &p);
    json handleListAlbums(const json &p);

    json handleCreateAsset(const json &p);
    json handleUpdateAsset(const json &p);
    json handleGetAsset(const json &p);
    json handleListAssets(const json &p);
    json handleIngestAsset(const json &p);
    json handleGetResourcePath(const json &p);

    json handleCreateAudio(const json &p);
    json handleUpdateAudio(const json &p);
    json handleGetAudio(const json &p);
    json handleListAudio(const json &p);

    json handleCreateWork(const json &p);
    json handleUpdateWork(const json &p);
    json handleGetWork(const json &p);
    json handleListWorks(const json &p);

    json handleAddTrackArtist(const json &p);
    json handleRemoveTrackArtist(const json &p);
    json handleUpdateTrackArtist(const json &p);

    json handleCreatePlaylist(const json &p);
    json handleUpdatePlaylist(const json &p);
    json handleGetPlaylist(const json &p);
    json handleListPlaylists(const json &p);
    json handleAddPlaylistTrack(const json &p);
    json handleRemovePlaylistTrack(const json &p);
    json handleGetPlaylistTracks(const json &p);

    json handleGetTracksByTitle(const json &p);
    json handleGetArtistsByName(const json &p);
    json handleGetAlbumsByTitle(const json &p);
    json handleGetWorksByTitle(const json &p);
    json handleGetPlaylistsByTitle(const json &p);

    json handleGetAlbumCover(const json &p);
    json handleGetTrackCover(const json &p);
    json handleGetArtistCover(const json &p);
    json handleGetPlaylistCover(const json &p);
    json handleGetEntityImages(const json &p);

    json build_image_response(const CoverResolutionResult &res);

    // Audio Engine Handlers
    json handleAudioPlay(const json &p);
    json handleAudioPause(const json &p);
    json handleAudioResume(const json &p);
    json handleAudioSeek(const json &p);
    json handleAudioStop(const json &p);
    json handleAudioSetVolume(const json &p);
    json handleAudioGetState(const json &p);
    json handleAudioCompareVersions(const json &p);
    json handleAudioGetWaveform(const json &p);
    json handleAudioListDevices(const json &p);
    json handleAudioSetOutputDevice(const json &p);
    json handleAudioQueueNext(const json &p);

    // Dependencies
    std::string m_storage_root;
    std::unique_ptr<IDatabaseContext> m_db_context;

    std::unique_ptr<IAlbumRepository> m_album_repo;
    std::unique_ptr<IArtistRepository> m_artist_repo;
    std::unique_ptr<IAssetRepository> m_asset_repo;
    std::unique_ptr<IAudioRepository> m_audio_repo;
    std::unique_ptr<IImageRepository> m_image_repo;
    std::unique_ptr<IPlaylistRepository> m_playlist_repo;
    std::unique_ptr<ITrackRepository> m_track_repo;
    std::unique_ptr<IWorkRepository> m_work_repo;

    std::unique_ptr<AlbumController> m_album_controller;
    std::unique_ptr<ArtistController> m_artist_controller;
    std::unique_ptr<AssetController> m_asset_controller;
    std::unique_ptr<AudioController> m_audio_controller;
    std::unique_ptr<PlaylistController> m_playlist_controller;
    std::unique_ptr<TrackController> m_track_controller;
    std::unique_ptr<WorkController> m_work_controller;
    std::unique_ptr<AudioEngine> m_audio_engine;
    std::unique_ptr<IngestionService> m_ingestion_service;
    std::unique_ptr<CoverArtService> m_cover_art_service;

    // Handler Mapping
    using Handler = std::function<json(const json &)>;
    std::unordered_map<std::string, Handler> m_handlers;
};

} // namespace lyra
