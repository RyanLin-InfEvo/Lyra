// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/track.dart';
import 'base_repository.dart';

/// Domain repository for track recording entities (Tier 2).
class TrackRepository extends BaseRepository {
  TrackRepository([super.bridge]);

  /// Lists audio tracks with optional pagination and search query filter.
  Future<List<Track>> listTracks({
    int offset = 0,
    int limit = 50,
    String? search,
  }) async {
    final response = await bridge.executeCommand('ListTracks', {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Track.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// Retrieves a track entity by its unique [id].
  Future<Track> getTrack(String id) async {
    final response = await bridge.executeCommand('GetTrack', {'id': id});
    final data = unpackMap(response);
    return Track.fromJson(data);
  }

  /// Queries audio tracks matching the specified [title].
  Future<List<Track>> getTracksByTitle(String title) async {
    final response = await bridge.executeCommand('GetTracksByTitle', {
      'title': title,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Track.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// Registers and creates a new track metadata record.
  Future<Track> createTrack(Track track) async {
    final response = await bridge.executeCommand('CreateTrack', track.toJson());
    final data = unpackMap(response);
    return Track.fromJson(data);
  }

  /// Updates an existing track metadata record.
  Future<Track> updateTrack(Track track) async {
    final response = await bridge.executeCommand('UpdateTrack', track.toJson());
    final data = unpackMap(response);
    return Track.fromJson(data);
  }

  /// Ingests and decodes an audio file from [sourcePath] into the Lyra CAS library.
  Future<Track> importTrack(String sourcePath) async {
    final response = await bridge.executeCommand('ImportTrack', {
      'source_path': sourcePath,
    });
    final data = unpackMap(response);
    return Track.fromJson(data);
  }
}
