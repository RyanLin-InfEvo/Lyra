// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../features/models/audio.dart';
import '../models/waveform_data.dart';

/// Abstract contract interface for Audio stream metadata and waveform repositories.
abstract class IAudioRepository {
  /// Lists decoded audio streams with optional pagination and search filter.
  Future<List<Audio>> listAudio({
    int offset = 0,
    int limit = 50,
    String? search,
  });

  /// Retrieves a decoded audio stream entity by its unique [pcmHash].
  Future<Audio> getAudio(String pcmHash);

  /// Registers a new decoded audio stream metadata entry.
  Future<Audio> createAudio(Audio audio);

  /// Updates an existing decoded audio stream metadata entry.
  Future<Audio> updateAudio(Audio audio);

  /// Retrieves downsampled or cached waveform visualization points for a track or PCM stream.
  Future<WaveformData> getWaveform(String trackIdOrPcmHash, {int points = 120});
}
