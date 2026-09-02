// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../models/album.dart';
import '../models/artist.dart';
import '../models/audio.dart';
import '../models/cas_object.dart';
import '../models/playlist.dart';
import '../models/source_data.dart';
import '../models/tag.dart';
import '../models/track.dart';
import '../models/work.dart';

/// Abstract service interface for music catalog, CAS storage, and playback metadata.
abstract class MusicService {
  /// Fetch all tracks, optionally filtered by search query.
  Future<List<Track>> getTracks({String? query});

  /// Fetch all musical composition works (Tier 1), optionally filtered.
  Future<List<Work>> getWorks({String? query});

  /// Fetch all albums, optionally filtered by search query.
  Future<List<Album>> getAlbums({String? query});

  /// Fetch all artists, optionally filtered by search query.
  Future<List<Artist>> getArtists({String? query});

  /// Fetch all playlists, optionally filtered by search query.
  Future<List<Playlist>> getPlaylists({String? query});

  /// Fetch catalog tags for quick library filtering.
  Future<List<Tag>> getTags();

  /// Create a new tag entity.
  Future<Tag> createTag({required String name, String category = 'general'});

  /// Delete a tag entity by ID.
  Future<void> deleteTag(String tagId);

  /// Create a new user or smart playlist.
  Future<Playlist> createPlaylist({
    required String title,
    String? description,
    List<String> trackIds = const [],
  });

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

  /// Fetch acoustic specifications (Tier 3) for a given decoded PCM hash.
  Future<Audio?> getAudioDetails(String pcmHash);

  /// Fetch source provenance and notarization record for a given physical file hash.
  Future<SourceData?> getSourceData(String fileHash);

  /// Fetch physical file asset (Tier 4) for a given file hash.
  Future<Asset?> getAsset(String fileHash);

  /// Fetch all Audio versions associated with a given PCM stream hash (Single-Level Star Topology).
  Future<List<Audio>> getAudioVersions(String pcmHash);

  /// Switch the active Audio version for a given track in the catalog.
  Future<void> switchTrackAudio(String trackId, String newPcmHash);
}
