// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/cas_object.dart';
import '../models/playlist.dart';
import '../models/tag.dart';
import '../models/track.dart';
import '../models/work.dart';
import 'music_service.dart';

/// Mock implementation providing a rich audiophile catalog and CAS storage simulation.
class MockMusicService implements MusicService {
  final List<Track> _tracks = [
    const Track(
      id: 'trk-001',
      title: 'Hotel California (Live on MTV 1994)',
      artistName: 'Eagles',
      albumTitle: 'Hell Freezes Over',
      durationMs: 432000,
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
      pcmHash:
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      verified: true,
    ),
    const Track(
      id: 'trk-002',
      title: 'So What',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      durationMs: 562000,
      format: 'FLAC',
      sampleRate: 192000,
      bitDepth: 24,
      pcmHash:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      verified: true,
    ),
    const Track(
      id: 'trk-003',
      title: 'Giorgio by Moroder',
      artistName: 'Daft Punk',
      albumTitle: 'Random Access Memories',
      durationMs: 544000,
      format: 'FLAC',
      sampleRate: 88200,
      bitDepth: 24,
      pcmHash:
          'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
      verified: true,
    ),
    const Track(
      id: 'trk-004',
      title: 'Time',
      artistName: 'Pink Floyd',
      albumTitle: 'The Dark Side of the Moon',
      durationMs: 413000,
      format: 'WAV',
      sampleRate: 96000,
      bitDepth: 24,
      pcmHash:
          '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
      verified: true,
    ),
    const Track(
      id: 'trk-005',
      title: 'Symphony No. 9 in D Minor, Op. 125',
      artistName: 'Berliner Philharmoniker & Herbert von Karajan',
      albumTitle: 'Beethoven: 9 Symphonies',
      durationMs: 1455000,
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
      pcmHash:
          'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9',
      verified: true,
    ),
    const Track(
      id: 'trk-006',
      title: 'Aja',
      artistName: 'Steely Dan',
      albumTitle: 'Aja',
      durationMs: 477000,
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
      pcmHash:
          'd2a5b672c22829af6ec173d5226b7ff33354972c50c4004383f80f6e5d439059',
      verified: true,
    ),
    const Track(
      id: 'trk-007',
      title: 'Brothers in Arms',
      artistName: 'Dire Straits',
      albumTitle: 'Brothers in Arms',
      durationMs: 418000,
      format: 'WAV',
      sampleRate: 44100,
      bitDepth: 16,
      pcmHash:
          'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
      verified: true,
    ),
    const Track(
      id: 'trk-008',
      title: 'Blue in Green',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      durationMs: 337000,
      format: 'FLAC',
      sampleRate: 192000,
      bitDepth: 24,
      pcmHash:
          '8f434346648f6b96df89dda901c5176b10e6d83961dd3c1ac88b59b2dc327aa4',
      verified: true,
    ),
  ];

  final List<Work> _works = [
    const Work(
      id: 'wrk-001',
      title: 'Symphony No. 9 in D minor, Op. 125 "Choral"',
      compositionStartYear: 1822,
      compositionEndYear: 1824,
      iswc: 'T-070.240.123-1',
      musicbrainzId: '0c72e276-8080-4965-9856-11f4864cbf7d',
    ),
    const Work(
      id: 'wrk-002',
      title: 'So What',
      compositionStartYear: 1959,
      compositionEndYear: 1959,
      iswc: 'T-070.123.456-7',
      musicbrainzId: '8d264585-e11a-4c28-bb8e-b8d910b8cf89',
    ),
    const Work(
      id: 'wrk-003',
      title: 'Hotel California',
      compositionStartYear: 1976,
      compositionEndYear: 1976,
      iswc: 'T-070.789.012-3',
      musicbrainzId: '47d79b90-1cfa-4db8-b593-9c86950280eb',
    ),
    const Work(
      id: 'wrk-004',
      title: 'Giorgio by Moroder',
      compositionStartYear: 2013,
      compositionEndYear: 2013,
      iswc: 'T-070.345.678-9',
      musicbrainzId: '7689de78-3a81-424d-bfe3-94c6f3708e1f',
    ),
    const Work(
      id: 'wrk-005',
      title: 'Time',
      compositionStartYear: 1973,
      compositionEndYear: 1973,
      iswc: 'T-070.901.234-5',
      musicbrainzId: 'b94b0d87-6e42-491c-b633-4fecbb5770b5',
    ),
    const Work(
      id: 'wrk-006',
      title: 'Aja',
      compositionStartYear: 1977,
      compositionEndYear: 1977,
      iswc: 'T-070.567.890-1',
      musicbrainzId: 'cd0214db-0a4d-488f-a953-333e9d8e75db',
    ),
  ];

  final List<Artist> _artists = [
    const Artist(
      id: 'art-001',
      name: 'Miles Davis',
      role: 'Composer / Trumpet',
      musicbrainzId: '561d854a-6a28-4aa7-8c99-323e6ce46c2a',
      spotifyId: '0kbYTNQb4Pb1rYvBk69HG8',
    ),
    const Artist(
      id: 'art-002',
      name: 'Eagles',
      role: 'Rock Band',
      musicbrainzId: 'f4a31f0a-51dd-4fa7-986d-3095c40c5ed9',
      spotifyId: '0ECwFtbIWEVNwjlrfc6xoL',
    ),
    const Artist(
      id: 'art-003',
      name: 'Daft Punk',
      role: 'Electronic Duo',
      musicbrainzId: '056e4f3e-d505-4dad-8ec1-d04f521cbb56',
      spotifyId: '4tZwfgrHOc3mvqYxwDOiq0',
    ),
    const Artist(
      id: 'art-004',
      name: 'Pink Floyd',
      role: 'Progressive Rock',
      musicbrainzId: '83d91898-d30c-47c0-b424-9592e8b9b412',
      spotifyId: '0k17h0D3J5VfsdmQ1iZtE9',
    ),
    const Artist(
      id: 'art-005',
      name: 'Herbert von Karajan',
      role: 'Conductor',
      musicbrainzId: 'd2dda26a-9204-406a-a996-fb9d95d4293b',
    ),
    const Artist(
      id: 'art-006',
      name: 'Steely Dan',
      role: 'Jazz Rock Ensemble',
      musicbrainzId: '9b28a9b2-3850-4ff6-8b2b-4ec404b85c18',
    ),
    const Artist(
      id: 'art-007',
      name: 'Dire Straits',
      role: 'Rock Band',
      musicbrainzId: '614e3804-7d34-41d9-8777-7da44f627049',
    ),
  ];

  final List<Playlist> _playlists = [
    Playlist(
      id: 'pl-001',
      title: 'Audiophile Reference Master',
      description:
          'Bit-perfect 24-bit / 96-192 kHz acoustic reference recordings',
      trackIds: const ['trk-001', 'trk-002', 'trk-003', 'trk-006'],
      createdAt: DateTime(2026, 1, 10),
    ),
    Playlist(
      id: 'pl-002',
      title: 'Late Night Jazz',
      description: 'Modal and post-bop classics in ultra-high resolution',
      trackIds: const ['trk-002', 'trk-008'],
      createdAt: DateTime(2026, 1, 20),
    ),
    Playlist(
      id: 'pl-003',
      title: 'Hi-Res Direct Stream',
      description: 'DSD and master tape transfers without lossy compression',
      trackIds: const ['trk-004', 'trk-005', 'trk-007'],
      createdAt: DateTime(2026, 2, 1),
    ),
  ];

  final List<Tag> _tags = [
    const Tag(id: 'tag-001', name: 'Audiophile', category: 'quality'),
    const Tag(id: 'tag-002', name: 'Hi-Res', category: 'quality'),
    const Tag(id: 'tag-003', name: 'DSD', category: 'format'),
    const Tag(id: 'tag-004', name: 'Direct Stream', category: 'source'),
    const Tag(id: 'tag-005', name: 'Live Recording', category: 'type'),
    const Tag(id: 'tag-006', name: 'Reference Master', category: 'quality'),
  ];

  final List<Album> _albums = const [
    Album(
      id: 'alb-001',
      title: 'Kind of Blue',
      artist: 'Miles Davis',
      year: 1959,
      trackCount: 5,
      coverColor: Color(0xFF1E3A8A), // Deep Blue
      format: 'FLAC 24/192',
    ),
    Album(
      id: 'alb-002',
      title: 'Hell Freezes Over',
      artist: 'Eagles',
      year: 1994,
      trackCount: 15,
      coverColor: Color(0xFF78350F), // Warm Amber
      format: 'FLAC 24/96',
    ),
    Album(
      id: 'alb-003',
      title: 'The Dark Side of the Moon',
      artist: 'Pink Floyd',
      year: 1973,
      trackCount: 10,
      coverColor: Color(0xFF0F172A), // Slate Black
      format: 'WAV 24/96',
    ),
    Album(
      id: 'alb-004',
      title: 'Random Access Memories',
      artist: 'Daft Punk',
      year: 2013,
      trackCount: 13,
      coverColor: Color(0xFF475569), // Metallic Slate
      format: 'FLAC 24/88.2',
    ),
    Album(
      id: 'alb-005',
      title: 'Aja',
      artist: 'Steely Dan',
      year: 1977,
      trackCount: 7,
      coverColor: Color(0xFF14532D), // Deep Emerald
      format: 'FLAC 24/96',
    ),
    Album(
      id: 'alb-006',
      title: 'Beethoven: 9 Symphonies',
      artist: 'Berliner Philharmoniker',
      year: 1963,
      trackCount: 36,
      coverColor: Color(0xFF831843), // Crimson
      format: 'FLAC 24/96',
    ),
  ];

  final List<CasObject> _casObjects = [
    CasObject(
      hash: '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      sizeBytes: 156824912, // ~150 MB
      mimeType: 'audio/flac',
      createdAt: DateTime(2026, 1, 15, 10, 30),
      verified: true,
    ),
    CasObject(
      hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      sizeBytes: 382910400, // ~365 MB
      mimeType: 'audio/flac',
      createdAt: DateTime(2026, 1, 16, 14, 20),
      verified: true,
    ),
    CasObject(
      hash: 'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
      sizeBytes: 192840192, // ~184 MB
      mimeType: 'audio/flac',
      createdAt: DateTime(2026, 2, 1, 9, 12),
      verified: true,
    ),
    CasObject(
      hash: '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
      sizeBytes: 238192000, // ~227 MB
      mimeType: 'audio/wav',
      createdAt: DateTime(2026, 2, 5, 16, 45),
      verified: true,
    ),
    CasObject(
      hash: 'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9',
      sizeBytes: 524288000, // ~500 MB
      mimeType: 'audio/flac',
      createdAt: DateTime(2026, 2, 10, 11, 0),
      verified: true,
    ),
  ];

  @override
  Future<List<Track>> getTracks({String? query}) async {
    if (query == null || query.trim().isEmpty) {
      return List.unmodifiable(_tracks);
    }
    final q = query.toLowerCase().trim();
    return _tracks.where((t) {
      return t.displayTitle.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q) ||
          (t.format ?? '').toLowerCase().contains(q) ||
          t.casHash.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<Work>> getWorks({String? query}) async {
    if (query == null || query.trim().isEmpty) {
      return List.unmodifiable(_works);
    }
    final q = query.toLowerCase().trim();
    return _works.where((w) {
      return w.title.toLowerCase().contains(q) ||
          (w.iswc ?? '').toLowerCase().contains(q) ||
          (w.musicbrainzId ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<Album>> getAlbums({String? query}) async {
    if (query == null || query.trim().isEmpty) {
      return List.unmodifiable(_albums);
    }
    final q = query.toLowerCase().trim();
    return _albums.where((a) {
      return a.title.toLowerCase().contains(q) ||
          a.artist.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<Artist>> getArtists({String? query}) async {
    if (query == null || query.trim().isEmpty) {
      return List.unmodifiable(_artists);
    }
    final q = query.toLowerCase().trim();
    return _artists.where((a) {
      return a.name.toLowerCase().contains(q) ||
          (a.role ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<Playlist>> getPlaylists({String? query}) async {
    if (query == null || query.trim().isEmpty) {
      return List.unmodifiable(_playlists);
    }
    final q = query.toLowerCase().trim();
    return _playlists.where((p) {
      return p.title.toLowerCase().contains(q) ||
          (p.description ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<List<Tag>> getTags() async {
    return List.unmodifiable(_tags);
  }

  @override
  Future<Playlist> createPlaylist({
    required String title,
    String? description,
    List<String> trackIds = const [],
  }) async {
    final playlist = Playlist(
      id: 'pl-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      trackIds: trackIds,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _playlists.insert(0, playlist);
    return playlist;
  }

  @override
  Future<List<CasObject>> getCasObjects() async {
    return List.unmodifiable(_casObjects);
  }

  @override
  Future<Track> importTrack({
    required String title,
    required String artist,
    required String album,
    required String format,
    required int sampleRate,
    required int bitDepth,
    required String simulatedHash,
  }) async {
    final track = Track(
      id: 'trk-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artistName: artist,
      albumTitle: album,
      durationMs: 258000,
      format: format,
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      pcmHash: simulatedHash,
      verified: true,
    );

    _tracks.insert(0, track);
    _casObjects.insert(
      0,
      CasObject(
        hash: simulatedHash,
        sizeBytes: 85293000,
        mimeType: 'audio/${format.toLowerCase()}',
        createdAt: DateTime.now(),
        verified: true,
      ),
    );

    return track;
  }

  @override
  Future<bool> verifyCasHash(String hash) async {
    return _casObjects.any((obj) => obj.hash == hash);
  }
}
