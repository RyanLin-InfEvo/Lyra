// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../models/album.dart';
import '../models/cas_object.dart';
import '../models/track.dart';
import 'music_service.dart';

/// Mock implementation providing a rich audiophile catalog and CAS storage simulation.
class MockMusicService implements MusicService {
  final List<Track> _tracks = [
    const Track(
      id: 'trk-001',
      title: 'Hotel California (Live on MTV 1994)',
      artist: 'Eagles',
      album: 'Hell Freezes Over',
      duration: Duration(minutes: 7, seconds: 12),
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
      casHash:
          '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      verified: true,
    ),
    const Track(
      id: 'trk-002',
      title: 'So What',
      artist: 'Miles Davis',
      album: 'Kind of Blue',
      duration: Duration(minutes: 9, seconds: 22),
      format: 'FLAC',
      sampleRate: 192000,
      bitDepth: 24,
      casHash:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      verified: true,
    ),
    const Track(
      id: 'trk-003',
      title: 'Giorgio by Moroder',
      artist: 'Daft Punk',
      album: 'Random Access Memories',
      duration: Duration(minutes: 9, seconds: 4),
      format: 'FLAC',
      sampleRate: 88200,
      bitDepth: 24,
      casHash:
          'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
      verified: true,
    ),
    const Track(
      id: 'trk-004',
      title: 'Time',
      artist: 'Pink Floyd',
      album: 'The Dark Side of the Moon',
      duration: Duration(minutes: 6, seconds: 53),
      format: 'WAV',
      sampleRate: 96000,
      bitDepth: 24,
      casHash:
          '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
      verified: true,
    ),
    const Track(
      id: 'trk-005',
      title: 'Symphony No. 9 in D Minor, Op. 125',
      artist: 'Berliner Philharmoniker & Herbert von Karajan',
      album: 'Beethoven: 9 Symphonies',
      duration: Duration(minutes: 24, seconds: 15),
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
      casHash:
          'fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9',
      verified: true,
    ),
    const Track(
      id: 'trk-006',
      title: 'Aja',
      artist: 'Steely Dan',
      album: 'Aja',
      duration: Duration(minutes: 7, seconds: 57),
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
      casHash:
          'd2a5b672c22829af6ec173d5226b7ff33354972c50c4004383f80f6e5d439059',
      verified: true,
    ),
    const Track(
      id: 'trk-007',
      title: 'Brothers in Arms',
      artist: 'Dire Straits',
      album: 'Brothers in Arms',
      duration: Duration(minutes: 6, seconds: 58),
      format: 'WAV',
      sampleRate: 44100,
      bitDepth: 16,
      casHash:
          'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
      verified: true,
    ),
    const Track(
      id: 'trk-008',
      title: 'Blue in Green',
      artist: 'Miles Davis',
      album: 'Kind of Blue',
      duration: Duration(minutes: 5, seconds: 37),
      format: 'FLAC',
      sampleRate: 192000,
      bitDepth: 24,
      casHash:
          '8f434346648f6b96df89dda901c5176b10e6d83961dd3c1ac88b59b2dc327aa4',
      verified: true,
    ),
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
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q) ||
          t.format.toLowerCase().contains(q) ||
          t.casHash.toLowerCase().contains(q);
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
      artist: artist,
      album: album,
      duration: const Duration(minutes: 4, seconds: 18),
      format: format,
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      casHash: simulatedHash,
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
