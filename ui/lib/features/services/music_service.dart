// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../models/album.dart';
import '../models/cas_object.dart';
import '../models/track.dart';

/// Abstract service interface for music catalog, CAS storage, and playback metadata.
abstract class MusicService {
  /// Fetch all tracks, optionally filtered by search query.
  Future<List<Track>> getTracks({String? query});

  /// Fetch all albums, optionally filtered by search query.
  Future<List<Album>> getAlbums({String? query});

  /// Fetch low-level CAS storage objects.
  Future<List<CasObject>> getCasObjects();

  /// Ingest and import a new track into CAS storage.
  Future<Track> importTrack({
    required String title,
    required String artist,
    required String album,
    required String format,
    required int sampleRate,
    required int bitDepth,
    required String simulatedHash,
  });

  /// Verify CAS hash integrity on the server/storage engine.
  Future<bool> verifyCasHash(String hash);
}
