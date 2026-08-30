// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/artist.dart';
import '../../features/models/image_asset.dart';
import 'base_repository.dart';

/// Domain repository for musical artist and performer entities.
class ArtistRepository extends BaseRepository {
  ArtistRepository([super.bridge]);

  /// Lists artists with optional pagination and search filter.
  Future<List<Artist>> listArtists({
    int offset = 0,
    int limit = 50,
    String? search,
  }) async {
    final response = await bridge.executeCommand('ListArtists', {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Artist.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Retrieves an artist entity by its unique [id].
  Future<Artist> getArtist(String id) async {
    final response = await bridge.executeCommand('GetArtist', {'id': id});
    final data = unpackMap(response);
    return Artist.fromJson(data);
  }

  /// Queries artists matching the specified [name].
  Future<List<Artist>> getArtistsByName(String name) async {
    final response = await bridge.executeCommand('GetArtistsByName', {
      'name': name,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Artist.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Creates a new artist entity.
  Future<Artist> createArtist(Artist artist) async {
    final response = await bridge.executeCommand(
      'CreateArtist',
      artist.toJson(),
    );
    final data = unpackMap(response);
    return Artist.fromJson(data);
  }

  /// Updates an existing artist entity.
  Future<Artist> updateArtist(Artist artist) async {
    final response = await bridge.executeCommand(
      'UpdateArtist',
      artist.toJson(),
    );
    final data = unpackMap(response);
    return Artist.fromJson(data);
  }

  /// Resolves the avatar / imagery asset for the specified [artistId].
  Future<ImageAsset?> getArtistCover(String artistId) async {
    try {
      final response = await bridge.executeCommand('GetArtistCover', {
        'artist_id': artistId,
      });
      final data = unpackMap(response);
      if (data.isEmpty) return null;
      return ImageAsset.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
