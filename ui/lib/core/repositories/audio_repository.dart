// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/audio.dart';
import '../models/waveform_data.dart';
import 'base_repository.dart';
import 'i_audio_repository.dart';

/// Domain repository for decoded PCM audio stream entities (Tier 3).
class AudioRepository extends BaseRepository implements IAudioRepository {
  AudioRepository([super.bridge]);

  /// Lists decoded audio streams with optional pagination and search filter.
  @override
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
        .map((item) => Audio.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Retrieves a decoded audio stream entity by its unique [pcmHash].
  @override
  Future<Audio> getAudio(String pcmHash) async {
    final response = await bridge.executeCommand('GetAudio', {
      'pcm_hash': pcmHash,
    });
    final data = unpackMap(response);
    return Audio.fromJson(data);
  }

  /// Registers a new decoded audio stream metadata entry.
  @override
  Future<Audio> createAudio(Audio audio) async {
    final response = await bridge.executeCommand('CreateAudio', audio.toJson());
    final data = unpackMap(response);
    return Audio.fromJson(data);
  }

  /// Updates an existing decoded audio stream metadata entry.
  @override
  Future<Audio> updateAudio(Audio audio) async {
    final response = await bridge.executeCommand('UpdateAudio', audio.toJson());
    final data = unpackMap(response);
    return Audio.fromJson(data);
  }

  /// Retrieves downsampled or cached waveform visualization points for a track or PCM stream.
  @override
  Future<WaveformData> getWaveform(
    String trackIdOrPcmHash, {
    int points = 120,
  }) async {
    final bool isPcmHash =
        trackIdOrPcmHash.startsWith('pcm') ||
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(trackIdOrPcmHash);
    final response = await bridge.executeCommand('audio.get_waveform', {
      isPcmHash ? 'pcm_hash' : 'track_id': trackIdOrPcmHash,
      'points': points,
    });
    final data = unpackMap(response);
    return WaveformData.fromJson(data);
  }
}
