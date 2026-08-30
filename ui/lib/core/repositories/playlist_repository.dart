// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/image_asset.dart';
import '../../features/models/playlist.dart';
import 'base_repository.dart';

/// Domain repository for user playlist and collection entities.
class PlaylistRepository extends BaseRepository {
  PlaylistRepository([super.bridge]);

  /// Lists playlists with optional pagination and search filter.
  Future<List<Playlist>> listPlaylists({
    int offset = 0,
    int limit = 50,
    String? search,
  }) async {
    final response = await bridge.executeCommand('ListPlaylists', {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Playlist.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Retrieves a playlist entity by its unique [id].
  Future<Playlist> getPlaylist(String id) async {
    final response = await bridge.executeCommand('GetPlaylist', {'id': id});
    final data = unpackMap(response);
    return Playlist.fromJson(data);
  }

  /// Queries playlists matching the specified [title].
  Future<List<Playlist>> getPlaylistsByTitle(String title) async {
    final response = await bridge.executeCommand('GetPlaylistsByTitle', {
      'title': title,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Playlist.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Creates a new playlist entity.
  Future<Playlist> createPlaylist(Playlist playlist) async {
    final response = await bridge.executeCommand(
      'CreatePlaylist',
      playlist.toJson(),
    );
    final data = unpackMap(response);
    return Playlist.fromJson(data);
  }

  /// Updates an existing playlist entity.
  Future<Playlist> updatePlaylist(Playlist playlist) async {
    final response = await bridge.executeCommand(
      'UpdatePlaylist',
      playlist.toJson(),
    );
    final data = unpackMap(response);
    return Playlist.fromJson(data);
  }

  /// Adds a track to the specified playlist.
  Future<void> addPlaylistTrack(
    String playlistId,
    String trackId, {
    int? position,
  }) async {
    await bridge.executeCommand('AddPlaylistTrack', {
      'playlist_id': playlistId,
      'track_id': trackId,
      'position': ?position,
    });
  }

  /// Removes a track from the specified playlist.
  Future<void> removePlaylistTrack(String playlistId, String trackId) async {
    await bridge.executeCommand('RemovePlaylistTrack', {
      'playlist_id': playlistId,
      'track_id': trackId,
    });
  }

  /// Retrieves ordered list of track IDs for the specified [playlistId].
  Future<List<String>> getPlaylistTracks(String playlistId) async {
    final response = await bridge.executeCommand('GetPlaylistTracks', {
      'playlist_id': playlistId,
    });
    final items = unpackList(response);
    return items
        .where((item) => item != null)
        .map((item) {
          if (item is String) return item;
          if (item is Map) {
            final id = item['track_id'] ?? item['id'];
            return id?.toString() ?? '';
          }
          return item.toString();
        })
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Resolves the cover art image asset for the specified [playlistId].
  Future<ImageAsset?> getPlaylistCover(String playlistId) async {
    try {
      final response = await bridge.executeCommand('GetPlaylistCover', {
        'playlist_id': playlistId,
      });
      final data = unpackMap(response);
      if (data.isEmpty) return null;
      return ImageAsset.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
