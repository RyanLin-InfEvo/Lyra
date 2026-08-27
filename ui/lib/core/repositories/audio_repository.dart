// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/audio.dart';
import 'base_repository.dart';

/// Domain repository for decoded PCM audio stream entities (Tier 3).
class AudioRepository extends BaseRepository {
  AudioRepository([super.bridge]);

  /// Lists decoded audio streams with optional pagination and search filter.
  Future<List<Audio>> listAudio({
    int offset = 0,
    int limit = 50,
    String? search,
  }) async {
    final response = await bridge.executeCommand('ListAudio', {
      'offset': offset,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final items = unpackList(response);
    return items
        .whereType<Map>()
        .map((item) => Audio.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// Retrieves a decoded audio stream entity by its unique [pcmHash].
  Future<Audio> getAudio(String pcmHash) async {
    final response = await bridge.executeCommand('GetAudio', {
      'pcm_hash': pcmHash,
    });
    final data = unpackMap(response);
    return Audio.fromJson(data);
  }

  /// Registers a new decoded audio stream metadata entry.
  Future<Audio> createAudio(Audio audio) async {
    final response = await bridge.executeCommand('CreateAudio', audio.toJson());
    final data = unpackMap(response);
    return Audio.fromJson(data);
  }

  /// Updates an existing decoded audio stream metadata entry.
  Future<Audio> updateAudio(Audio audio) async {
    final response = await bridge.executeCommand('UpdateAudio', audio.toJson());
    final data = unpackMap(response);
    return Audio.fromJson(data);
  }
}
