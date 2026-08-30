// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/album.dart';
import '../../features/models/image_asset.dart';
import 'base_repository.dart';

/// Domain repository for album and release collection entities.
class AlbumRepository extends BaseRepository {
  AlbumRepository([super.bridge]);

  /// Lists albums with optional pagination and search filter.
  Future<List<Album>> listAlbums({
    int offset = 0,
    int limit = 50,
    String? search,
  }) async {
    final response = await bridge.executeCommand('ListAlbums', {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Album.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Retrieves an album entity by its unique [id].
  Future<Album> getAlbum(String id) async {
    final response = await bridge.executeCommand('GetAlbum', {'id': id});
    final data = unpackMap(response);
    return Album.fromJson(data);
  }

  /// Queries albums matching the specified [title].
  Future<List<Album>> getAlbumsByTitle(String title) async {
    final response = await bridge.executeCommand('GetAlbumsByTitle', {
      'title': title,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Album.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Creates a new album release entity.
  Future<Album> createAlbum(Album album) async {
    final response = await bridge.executeCommand('CreateAlbum', album.toJson());
    final data = unpackMap(response);
    return Album.fromJson(data);
  }

  /// Updates an existing album release entity.
  Future<Album> updateAlbum(Album album) async {
    final response = await bridge.executeCommand('UpdateAlbum', album.toJson());
    final data = unpackMap(response);
    return Album.fromJson(data);
  }

  /// Resolves the cover art image asset for the specified [albumId].
  Future<ImageAsset?> getAlbumCover(String albumId) async {
    try {
      final response = await bridge.executeCommand('GetAlbumCover', {
        'album_id': albumId,
      });
      final data = unpackMap(response);
      if (data.isEmpty) return null;
      return ImageAsset.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
