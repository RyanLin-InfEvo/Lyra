// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/audio.dart';
import '../models/cas_object.dart';
import '../models/playlist.dart';
import '../models/source_data.dart';
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
    CasObject(
      hash: 'cda1b2c3d4e5f60718293a4b5c6d7e8f0123456789abcdef0123456789abcdef',
      sizeBytes: 76200000, // ~72.6 MB
      mimeType: 'audio/wav',
      createdAt: DateTime(2026, 1, 20, 11, 15),
      verified: true,
    ),
    CasObject(
      hash: '9f8e7d6c5b4a39281701f2e3d4c5b6a70123456789abcdef0123456789abcdef',
      sizeBytes: 312000000, // ~297.5 MB
      mimeType: 'audio/flac',
      createdAt: DateTime(2026, 1, 25, 14, 0),
      verified: true,
    ),
    CasObject(
      hash: 'b5a2c3d4e5f60718293a4b5c6d7e8f0123456789abcdef0123456789abcdef',
      sizeBytes: 17280000, // ~16.5 MB
      mimeType: 'audio/mpeg',
      createdAt: DateTime(2026, 1, 28, 16, 0),
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
  Future<Tag> createTag({
    required String name,
    String category = 'general',
  }) async {
    final tag = Tag(
      id: 'tag-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: category,
      createdAt: DateTime.now(),
    );
    _tags.add(tag);
    return tag;
  }

  @override
  Future<void> deleteTag(String tagId) async {
    _tags.removeWhere((t) => t.id == tagId);
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

  final Map<String, Audio> _audioDetails = {
    // Reference Track trk-001 (Hotel California) - Version 1 (Master 24/96 FLAC)
    '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069': Audio(
      pcmHash:
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      parentHash: '', // Master in Single-Level Star Topology
      qualityScore: 99,
      bitDepth: 24,
      sampleRate: 96000,
      channels: 2,
      durationMs: 432000.0,
      integratedLoudness: -14.2,
      truePeak: -0.5,
      assets: [
        Asset(
          fileHash:
              '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
          mimeType: 'audio/flac',
          assetType: 'audio',
          fileSize: 156824912,
          createdAt: DateTime(2026, 1, 15, 10, 30),
          verified: true,
        ),
      ],
    ),

    // Reference Track trk-001 - Version 2 (Derived 16/44.1 CD WAV)
    '7f83b16500000000000000000000000000000000000000000000000000004416': Audio(
      pcmHash:
          '7f83b16500000000000000000000000000000000000000000000000000004416',
      parentHash:
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069', // points to Master
      qualityScore: 92,
      bitDepth: 16,
      sampleRate: 44100,
      channels: 2,
      durationMs: 432000.0,
      integratedLoudness: -14.0,
      truePeak: -0.1,
      assets: [
        Asset(
          fileHash:
              'cda1b2c3d4e5f60718293a4b5c6d7e8f0123456789abcdef0123456789abcdef',
          mimeType: 'audio/wav',
          assetType: 'audio',
          fileSize: 76200000,
          createdAt: DateTime(2026, 1, 20, 11, 15),
          verified: true,
        ),
      ],
    ),

    // Reference Track trk-001 - Version 3 (Derived 24/192 Vinyl Rip FLAC)
    '7f83b16500000000000000000000000000000000000000000000000000019224': Audio(
      pcmHash:
          '7f83b16500000000000000000000000000000000000000000000000000019224',
      parentHash:
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069', // points to Master
      qualityScore: 98,
      bitDepth: 24,
      sampleRate: 192000,
      channels: 2,
      durationMs: 432100.0,
      integratedLoudness: -16.5,
      truePeak: -1.1,
      assets: [
        Asset(
          fileHash:
              '9f8e7d6c5b4a39281701f2e3d4c5b6a70123456789abcdef0123456789abcdef',
          mimeType: 'audio/flac',
          assetType: 'audio',
          fileSize: 312000000,
          createdAt: DateTime(2026, 1, 25, 14, 0),
          verified: true,
        ),
      ],
    ),

    // Reference Track trk-001 - Version 4 (Derived 16/44.1 MP3 Lossy)
    '7f83b16500000000000000000000000000000000000000000000000000000320': Audio(
      pcmHash:
          '7f83b16500000000000000000000000000000000000000000000000000000320',
      parentHash:
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069', // points to Master
      qualityScore: 78,
      bitDepth: 16,
      sampleRate: 44100,
      channels: 2,
      durationMs: 432000.0,
      integratedLoudness: -13.8,
      truePeak: -0.2,
      assets: [
        Asset(
          fileHash:
              'b5a2c3d4e5f60718293a4b5c6d7e8f0123456789abcdef0123456789abcdef',
          mimeType: 'audio/mpeg',
          assetType: 'audio',
          fileSize: 17280000,
          createdAt: DateTime(2026, 1, 28, 16, 0),
          verified: true,
        ),
      ],
    ),

    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855': Audio(
      pcmHash:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      parentHash: '',
      qualityScore: 98,
      bitDepth: 24,
      sampleRate: 192000,
      channels: 2,
      durationMs: 562000.0,
      integratedLoudness: -18.5,
      truePeak: -1.2,
      assets: [
        Asset(
          fileHash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          mimeType: 'audio/flac',
          assetType: 'audio',
          fileSize: 382910400,
          createdAt: DateTime(2026, 1, 16, 14, 20),
          verified: true,
        ),
      ],
    ),
    'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e': Audio(
      pcmHash:
          'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
      parentHash: '',
      qualityScore: 96,
      bitDepth: 24,
      sampleRate: 88200,
      channels: 2,
      durationMs: 544000.0,
      integratedLoudness: -11.8,
      truePeak: -0.1,
      assets: [
        Asset(
          fileHash:
              'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
          mimeType: 'audio/flac',
          assetType: 'audio',
          fileSize: 192840192,
          createdAt: DateTime(2026, 2, 1, 9, 12),
          verified: true,
        ),
      ],
    ),
    '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae': Audio(
      pcmHash:
          '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
      parentHash: '',
      qualityScore: 97,
      bitDepth: 24,
      sampleRate: 96000,
      channels: 2,
      durationMs: 413000.0,
      integratedLoudness: -13.6,
      truePeak: -0.3,
      assets: [
        Asset(
          fileHash:
              '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
          mimeType: 'audio/wav',
          assetType: 'audio',
          fileSize: 238192000,
          createdAt: DateTime(2026, 2, 5, 16, 45),
          verified: true,
        ),
      ],
    ),
    'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9': Audio(
      pcmHash:
          'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9',
      parentHash: '',
      qualityScore: 95,
      bitDepth: 24,
      sampleRate: 96000,
      channels: 2,
      durationMs: 1455000.0,
      integratedLoudness: -20.4,
      truePeak: -1.8,
      assets: [
        Asset(
          fileHash:
              'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9',
          mimeType: 'audio/flac',
          assetType: 'audio',
          fileSize: 524288000,
          createdAt: DateTime(2026, 2, 10, 11, 0),
          verified: true,
        ),
      ],
    ),
    'd2a5b672c22829af6ec173d5226b7ff33354972c50c4004383f80f6e5d439059': Audio(
      pcmHash:
          'd2a5b672c22829af6ec173d5226b7ff33354972c50c4004383f80f6e5d439059',
      parentHash: '',
      qualityScore: 99,
      bitDepth: 24,
      sampleRate: 96000,
      channels: 2,
      durationMs: 477000.0,
      integratedLoudness: -15.1,
      truePeak: -0.6,
      assets: [
        Asset(
          fileHash:
              'd2a5b672c22829af6ec173d5226b7ff33354972c50c4004383f80f6e5d439059',
          mimeType: 'audio/flac',
          assetType: 'audio',
          fileSize: 180000000,
          createdAt: DateTime(2026, 2, 12, 15, 30),
          verified: true,
        ),
      ],
    ),
    'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d': Audio(
      pcmHash:
          'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
      parentHash: '',
      qualityScore: 92,
      bitDepth: 16,
      sampleRate: 44100,
      channels: 2,
      durationMs: 418000.0,
      integratedLoudness: -16.0,
      truePeak: -0.8,
      assets: [
        Asset(
          fileHash:
              'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
          mimeType: 'audio/wav',
          assetType: 'audio',
          fileSize: 73700000,
          createdAt: DateTime(2026, 2, 15, 13, 0),
          verified: true,
        ),
      ],
    ),
    '8f434346648f6b96df89dda901c5176b10e6d83961dd3c1ac88b59b2dc327aa4': Audio(
      pcmHash:
          '8f434346648f6b96df89dda901c5176b10e6d83961dd3c1ac88b59b2dc327aa4',
      parentHash: '',
      qualityScore: 98,
      bitDepth: 24,
      sampleRate: 192000,
      channels: 2,
      durationMs: 337000.0,
      integratedLoudness: -19.2,
      truePeak: -1.4,
      assets: [
        Asset(
          fileHash:
              '8f434346648f6b96df89dda901c5176b10e6d83961dd3c1ac88b59b2dc327aa4',
          mimeType: 'audio/flac',
          assetType: 'audio',
          fileSize: 228000000,
          createdAt: DateTime(2026, 2, 16, 17, 45),
          verified: true,
        ),
      ],
    ),
  };

  final Map<String, SourceData> _sourceData = {
    '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069': SourceData(
      id: 'src-001',
      fileHash:
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      sourceType: 'cd_rip',
      originalPath:
          '/Volumes/MasterAudio/Eagles/HellFreezesOver/01_Hotel_California.flac',
      createdAt: DateTime(2026, 1, 15, 10, 30),
      note:
          'EAC Secure Mode (v1.6), AccurateRip confidence 28/28, Plextor Premium II',
    ),
    'cda1b2c3d4e5f60718293a4b5c6d7e8f0123456789abcdef0123456789abcdef': SourceData(
      id: 'src-001-cd',
      fileHash:
          'cda1b2c3d4e5f60718293a4b5c6d7e8f0123456789abcdef0123456789abcdef',
      sourceType: 'cd_rip',
      originalPath:
          '/Volumes/RedbookCD/Eagles/HellFreezesOver_CD/01_HotelCalifornia.wav',
      createdAt: DateTime(2026, 1, 20, 11, 15),
      note:
          'EAC Secure Mode (v1.6) AccurateRip confidence 28/28, Plextor Premium II CD-DA',
    ),
    '9f8e7d6c5b4a39281701f2e3d4c5b6a70123456789abcdef0123456789abcdef': SourceData(
      id: 'src-001-vinyl',
      fileHash:
          '9f8e7d6c5b4a39281701f2e3d4c5b6a70123456789abcdef0123456789abcdef',
      sourceType: 'vinyl_rip',
      originalPath:
          '/Volumes/VinylRip/Eagles/HellFreezesOver_LP/01_HotelCalifornia.flac',
      createdAt: DateTime(2026, 1, 25, 14, 0),
      note:
          'Technics SL-1200G + Audio-Technica ART9XI MC cartridge, RME ADI-2 Pro FS R 192kHz/24bit',
    ),
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855': SourceData(
      id: 'src-002',
      fileHash:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      sourceType: 'studio_master',
      originalPath:
          '/Volumes/StudioVault/MilesDavis/KindOfBlue_192k24b/01_SoWhat.flac',
      createdAt: DateTime(2026, 1, 16, 14, 20),
      note:
          'Columbia Legacy 192kHz/24bit Transfer from 3-track 1/2" original session tapes',
    ),
    'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e':
        SourceData(
          id: 'src-003',
          fileHash:
              'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
          sourceType: 'digital_download',
          originalPath: '/Volumes/Downloads/DaftPunk/RAM_Qobuz/03_Giorgio.flac',
          createdAt: DateTime(2026, 2, 1, 9, 12),
          note: 'Qobuz Hi-Res Master 24-Bit / 88.2 kHz Purchase',
        ),
    '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae': SourceData(
      id: 'src-004',
      fileHash:
          '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
      sourceType: 'vinyl_rip',
      originalPath:
          '/Volumes/VinylArchive/PinkFloyd/DSOTM_UK_1st_Press/04_Time.wav',
      createdAt: DateTime(2026, 2, 5, 16, 45),
      note: 'SME 30/2 + SME V + Koetsu Rosewood Signature, Lynx Hilo 24/96 PCM',
    ),
    'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9': SourceData(
      id: 'src-005',
      fileHash:
          'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9',
      sourceType: 'studio_master',
      originalPath:
          '/Volumes/ClassicalMaster/DG/Beethoven9_Karajan_1963/04_Presto.flac',
      createdAt: DateTime(2026, 2, 10, 11, 0),
      note: 'Deutsche Grammophon 24/96 Remaster from original analogue master',
    ),
    'd2a5b672c22829af6ec173d5226b7ff33354972c50c4004383f80f6e5d439059':
        SourceData(
          id: 'src-006',
          fileHash:
              'd2a5b672c22829af6ec173d5226b7ff33354972c50c4004383f80f6e5d439059',
          sourceType: 'digital_download',
          originalPath:
              '/Volumes/HiRes/SteelyDan/Aja_AcousticSounds/01_BlackCow.flac',
          createdAt: DateTime(2026, 2, 12, 15, 30),
          note: 'Acoustic Sounds / Analogue Productions Master',
        ),
    'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d':
        SourceData(
          id: 'src-007',
          fileHash:
              'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
          sourceType: 'cd_rip',
          originalPath:
              '/Volumes/Redbook/DireStraits/BrothersInArms_CD/01_SoFarAway.wav',
          createdAt: DateTime(2026, 2, 15, 13, 0),
          note: 'Vertigo original 1985 Redbook CD rip',
        ),
    '8f434346648f6b96df89dda901c5176b10e6d83961dd3c1ac88b59b2dc327aa4': SourceData(
      id: 'src-008',
      fileHash:
          '8f434346648f6b96df89dda901c5176b10e6d83961dd3c1ac88b59b2dc327aa4',
      sourceType: 'studio_master',
      originalPath:
          '/Volumes/StudioVault/MilesDavis/KindOfBlue_192k24b/03_BlueInGreen.flac',
      createdAt: DateTime(2026, 2, 16, 17, 45),
      note: 'Columbia Legacy 192kHz/24bit Transfer',
    ),
    'b5a2c3d4e5f60718293a4b5c6d7e8f0123456789abcdef0123456789abcdef': SourceData(
      id: 'src-001-mp3',
      fileHash:
          'b5a2c3d4e5f60718293a4b5c6d7e8f0123456789abcdef0123456789abcdef',
      sourceType: 'digital_download',
      originalPath:
          '/Volumes/Downloads/Eagles/HellFreezesOver/01_HotelCalifornia_320k.mp3',
      createdAt: DateTime(2026, 1, 28, 16, 0),
      note: 'LAME 3.100 -b 320 CBR stereo MP3 release',
    ),
  };

  @override
  Future<bool> verifyCasHash(String hash) async {
    return _casObjects.any((obj) => obj.hash == hash);
  }

  @override
  Future<Audio?> getAudioDetails(String pcmHash) async {
    if (_audioDetails.containsKey(pcmHash)) {
      return _audioDetails[pcmHash];
    }
    // Fallback synthesis if matching track exists
    for (final track in _tracks) {
      if (track.pcmHash == pcmHash) {
        return Audio(
          pcmHash: pcmHash,
          parentHash: '',
          qualityScore: (track.bitDepth != null && track.bitDepth! >= 24)
              ? 96
              : 85,
          bitDepth: track.bitDepth ?? 16,
          sampleRate: track.sampleRate ?? 44100,
          channels: 2,
          durationMs: (track.durationMs ?? 0).toDouble(),
          integratedLoudness: -14.0,
          truePeak: -0.5,
          assets: [
            Asset(
              fileHash: pcmHash,
              mimeType: 'audio/${(track.format ?? "flac").toLowerCase()}',
              assetType: 'audio',
              fileSize: 100000000,
              createdAt: DateTime(2026, 1, 1),
              verified: true,
            ),
          ],
        );
      }
    }
    return null;
  }

  @override
  Future<List<Audio>> getAudioVersions(String pcmHash) async {
    if (pcmHash.isEmpty) return [];

    Audio? audio = _audioDetails[pcmHash];
    audio ??= await getAudioDetails(pcmHash);
    if (audio == null) return [];

    // Single-Level Star Topology:
    // If parentHash is empty or equals pcmHash, this audio is the Master.
    // Otherwise, parentHash points directly to the Master.
    final masterHash =
        (audio.parentHash.isEmpty || audio.parentHash == audio.pcmHash)
        ? audio.pcmHash
        : audio.parentHash;

    final versions = <Audio>[];
    // Master is first in Star Topology list
    if (_audioDetails.containsKey(masterHash)) {
      versions.add(_audioDetails[masterHash]!);
    } else if (audio.pcmHash == masterHash) {
      versions.add(audio);
    }

    // All derived versions pointing to masterHash
    for (final candidate in _audioDetails.values) {
      if (candidate.pcmHash != masterHash &&
          candidate.parentHash == masterHash) {
        versions.add(candidate);
      }
    }

    if (versions.isEmpty) {
      versions.add(audio);
    }

    return versions;
  }

  @override
  Future<void> switchTrackAudio(String trackId, String newPcmHash) async {
    final index = _tracks.indexWhere((t) => t.id == trackId);
    if (index < 0) return;

    final oldTrack = _tracks[index];
    final audio = await getAudioDetails(newPcmHash);

    String? newFormat = oldTrack.format;
    if (audio != null && audio.assets.isNotEmpty) {
      final mime = audio.assets.first.mimeType.toLowerCase();
      if (mime.contains('flac')) {
        newFormat = 'FLAC';
      } else if (mime.contains('wav')) {
        newFormat = 'WAV';
      } else if (mime.contains('aac')) {
        newFormat = 'AAC';
      } else if (mime.contains('mp3') || mime.contains('mpeg')) {
        newFormat = 'MP3';
      }
    }

    _tracks[index] = oldTrack.copyWith(
      pcmHash: newPcmHash,
      bitDepth: audio?.bitDepth ?? oldTrack.bitDepth,
      sampleRate: audio?.sampleRate ?? oldTrack.sampleRate,
      format: newFormat,
    );
  }

  @override
  Future<SourceData?> getSourceData(String fileHash) async {
    if (_sourceData.containsKey(fileHash)) {
      return _sourceData[fileHash];
    }
    return null;
  }

  @override
  Future<Asset?> getAsset(String fileHash) async {
    for (final obj in _casObjects) {
      if (obj.fileHash == fileHash) {
        return obj;
      }
    }
    return null;
  }
}
