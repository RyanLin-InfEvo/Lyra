// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/models/models.dart';

void main() {
  group('Work Model (Tier 1)', () {
    test('instantiates correctly and supports value equality', () {
      const work1 = Work(
        id: 'wrk-001',
        title: 'Symphony No. 5 in C Minor, Op. 67',
        compositionStartYear: 1804,
        compositionEndYear: 1808,
        compositionDateText: '1804–1808',
        iswc: 'T-000.000.001-0',
        musicbrainzId: 'mb-wrk-001',
      );

      const work2 = Work(
        id: 'wrk-001',
        title: 'Symphony No. 5 in C Minor, Op. 67',
        compositionStartYear: 1804,
        compositionEndYear: 1808,
        compositionDateText: '1804–1808',
        iswc: 'T-000.000.001-0',
        musicbrainzId: 'mb-wrk-001',
      );

      expect(work1, equals(work2));
      expect(work1.hashCode, equals(work2.hashCode));
      expect(work1.toString(), contains('wrk-001'));
    });

    test('serializes to and from JSON', () {
      final json = {
        'id': 'wrk-002',
        'title': 'Für Elise',
        'composition_start_year': 1810,
        'composition_end_year': 1810,
        'composition_date_text': '27 April 1810',
        'iswc': 'T-000.000.002-1',
        'musicbrainz_id': 'mb-wrk-002',
      };

      final work = Work.fromJson(json);
      expect(work.id, 'wrk-002');
      expect(work.title, 'Für Elise');
      expect(work.compositionStartYear, 1810);
      expect(work.compositionEndYear, 1810);
      expect(work.compositionDateText, '27 April 1810');
      expect(work.iswc, 'T-000.000.002-1');
      expect(work.musicbrainzId, 'mb-wrk-002');

      final serialized = work.toJson();
      expect(serialized['id'], 'wrk-002');
      expect(serialized['title'], 'Für Elise');
      expect(serialized['composition_start_year'], 1810);
      expect(serialized['iswc'], 'T-000.000.002-1');
    });

    test('supports copyWith', () {
      const work = Work(id: 'wrk-001', title: 'Original Title');

      final updated = work.copyWith(
        title: 'New Title',
        compositionStartYear: 1900,
      );

      expect(updated.id, 'wrk-001');
      expect(updated.title, 'New Title');
      expect(updated.compositionStartYear, 1900);
      expect(work.title, 'Original Title');
    });
  });

  group('Track Model (Tier 2)', () {
    test('instantiates correctly with 4-tier audio fields and getters', () {
      const track = Track(
        id: 'trk-001',
        pcmHash:
            '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
        workId: 'wrk-001',
        title: 'Hotel California',
        artistName: 'Eagles',
        albumTitle: 'Hell Freezes Over',
        recordingYear: 1994,
        recordingMonth: 4,
        recordingDay: 25,
        recordingLocation: 'Warner Bros. Studios, Burbank, CA',
        durationMs: 432000,
        isrc: 'USPR39400001',
        musicbrainzId: 'mb-trk-001',
        spotifyId: 'sp-trk-001',
        ytmId: 'yt-trk-001',
        format: 'FLAC',
        sampleRate: 96000,
        bitDepth: 24,
        verified: true,
      );

      expect(track.id, 'trk-001');
      expect(track.displayTitle, 'Hotel California');
      expect(track.artist, 'Eagles');
      expect(track.album, 'Hell Freezes Over');
      expect(track.duration, const Duration(minutes: 7, seconds: 12));
      expect(track.formattedDuration, '7:12');
      expect(track.formattedQuality, '24-bit/96kHz');
      expect(track.casHash, track.pcmHash);
      expect(track.shortCasHash, '7f83b1...9069');
      expect(track.verified, isTrue);
    });

    test('supports Track.legacy factory constructor', () {
      final track = Track.legacy(
        id: 'trk-legacy',
        casHash: 'abcdef1234567890abcdef1234567890abcdef1234567890',
        title: 'Legacy Song',
        artist: 'Legacy Artist',
        album: 'Legacy Album',
        duration: const Duration(minutes: 3, seconds: 45),
        sampleRate: 44100,
        bitDepth: 16,
      );

      expect(track.pcmHash, 'abcdef1234567890abcdef1234567890abcdef1234567890');
      expect(track.artistName, 'Legacy Artist');
      expect(track.albumTitle, 'Legacy Album');
      expect(track.durationMs, 225000);
      expect(track.formattedDuration, '3:45');
      expect(track.formattedQuality, '16-bit/44.1kHz');
    });

    test('serializes to and from JSON', () {
      final json = {
        'id': 'trk-002',
        'pcm_hash': 'hash123',
        'work_id': 'wrk-002',
        'title': 'So What',
        'artist_name': 'Miles Davis',
        'album_title': 'Kind of Blue',
        'duration': 562000,
        'recording_year': 1959,
        'format': 'FLAC',
        'sample_rate': 192000,
        'bit_depth': 24,
        'verified': true,
      };

      final track = Track.fromJson(json);
      expect(track.id, 'trk-002');
      expect(track.pcmHash, 'hash123');
      expect(track.workId, 'wrk-002');
      expect(track.title, 'So What');
      expect(track.artistName, 'Miles Davis');
      expect(track.albumTitle, 'Kind of Blue');
      expect(track.durationMs, 562000);
      expect(track.recordingYear, 1959);

      final serialized = track.toJson();
      expect(serialized['id'], 'trk-002');
      expect(serialized['pcm_hash'], 'hash123');
      expect(serialized['artist_name'], 'Miles Davis');
    });

    test('supports copyWith', () {
      const track = Track(
        id: 'trk-001',
        title: 'Original Title',
        artistName: 'Artist 1',
      );

      final updated = track.copyWith(
        title: 'Updated Title',
        albumTitle: 'New Album',
      );

      expect(updated.id, 'trk-001');
      expect(updated.title, 'Updated Title');
      expect(updated.artistName, 'Artist 1');
      expect(updated.albumTitle, 'New Album');
    });
  });

  group('Audio Model (Tier 3)', () {
    test('instantiates correctly with acoustic audio metrics', () {
      const audio = Audio(
        pcmHash:
            '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
        parentHash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        qualityScore: 98,
        bitDepth: 24,
        sampleRate: 96000,
        channels: 2,
        durationMs: 432000.0,
        integratedLoudness: -14.2,
        truePeak: -0.8,
      );

      expect(audio.pcmHash, contains('7f83b1'));
      expect(audio.parentHash, contains('e3b0c4'));
      expect(audio.qualityScore, 98);
      expect(audio.bitDepth, 24);
      expect(audio.sampleRate, 96000);
      expect(audio.channels, 2);
      expect(audio.durationMs, 432000.0);
      expect(audio.integratedLoudness, -14.2);
      expect(audio.truePeak, -0.8);
      expect(audio.duration, const Duration(minutes: 7, seconds: 12));
      expect(audio.formattedDuration, '7:12');
      expect(audio.formattedQuality, '24-bit/96kHz');
      expect(audio.shortPcmHash, '7f83b1...9069');
    });

    test('serializes to and from JSON', () {
      final json = {
        'pcm_hash': 'pcm-hash-abc',
        'parent_hash': 'parent-hash-xyz',
        'quality_score': 95,
        'bit_depth': 16,
        'sample_rate': 44100,
        'channels': 2,
        'duration_ms': 210000.0,
        'integrated_loudness': -16.5,
        'true_peak': -1.2,
      };

      final audio = Audio.fromJson(json);
      expect(audio.pcmHash, 'pcm-hash-abc');
      expect(audio.parentHash, 'parent-hash-xyz');
      expect(audio.qualityScore, 95);
      expect(audio.bitDepth, 16);
      expect(audio.sampleRate, 44100);
      expect(audio.channels, 2);
      expect(audio.durationMs, 210000.0);
      expect(audio.integratedLoudness, -16.5);
      expect(audio.truePeak, -1.2);

      final serialized = audio.toJson();
      expect(serialized['pcm_hash'], 'pcm-hash-abc');
      expect(serialized['quality_score'], 95);
    });

    test('supports copyWith', () {
      const audio = Audio(pcmHash: 'hash-1', qualityScore: 80);
      final updated = audio.copyWith(qualityScore: 99, sampleRate: 192000);

      expect(updated.pcmHash, 'hash-1');
      expect(updated.qualityScore, 99);
      expect(updated.sampleRate, 192000);
    });
  });

  group('Asset Model (Tier 4) & CasObject Compatibility', () {
    test('instantiates correctly and calculates formattedSize', () {
      final now = DateTime(2026, 2, 26, 12, 0);
      final asset = Asset(
        fileHash:
            '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
        mimeType: 'audio/flac',
        assetType: 'audio',
        fileSize: 156824912,
        createdAt: now,
        verified: true,
      );

      expect(asset.fileHash, contains('7f83b1'));
      expect(asset.hash, asset.fileHash);
      expect(asset.sizeBytes, 156824912);
      expect(asset.formattedSize, '149.6 MB');
      expect(asset.shortHash, '7f83b165...6d9069');
      expect(asset.shortFileHash, asset.shortHash);
      expect(asset.verified, isTrue);
    });

    test('CasObject extends Asset and works polymorphically', () {
      final now = DateTime(2026, 1, 15, 10, 30);
      final casObj = CasObject(
        hash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        sizeBytes: 382910400,
        mimeType: 'audio/flac',
        createdAt: now,
        verified: true,
      );

      expect(casObj, isA<Asset>());
      expect(casObj.fileHash, casObj.hash);
      expect(casObj.fileSize, 382910400);
      expect(casObj.formattedSize, '365.2 MB');
      expect(casObj.shortHash, 'e3b0c442...52b855');
    });

    test('serializes to and from JSON', () {
      final now = DateTime.parse('2026-03-01T15:00:00.000Z');
      final json = {
        'file_hash': 'asset-hash-123',
        'mime_type': 'audio/wav',
        'asset_type': 'audio',
        'file_size': 52428800,
        'created_at': now.toIso8601String(),
        'verified': true,
      };

      final asset = Asset.fromJson(json);
      expect(asset.fileHash, 'asset-hash-123');
      expect(asset.mimeType, 'audio/wav');
      expect(asset.fileSize, 52428800);
      expect(asset.createdAt, now);
      expect(asset.verified, isTrue);

      final serialized = asset.toJson();
      expect(serialized['file_hash'], 'asset-hash-123');
      expect(serialized['file_size'], 52428800);
    });

    test('supports copyWith', () {
      final asset = Asset(
        fileHash: 'hash-1',
        createdAt: DateTime.now(),
        fileSize: 100,
      );
      final updated = asset.copyWith(fileSize: 200, mimeType: 'audio/flac');

      expect(updated.fileHash, 'hash-1');
      expect(updated.fileSize, 200);
      expect(updated.mimeType, 'audio/flac');
    });
  });

  group('Artist Model', () {
    test('instantiates correctly and supports value equality', () {
      const artist1 = Artist(
        id: 'art-001',
        name: 'Miles Davis',
        musicbrainzId: 'mb-art-001',
        role: 'main',
        spotifyId: 'sp-art-001',
        ytmId: 'yt-art-001',
      );

      const artist2 = Artist(
        id: 'art-001',
        name: 'Miles Davis',
        musicbrainzId: 'mb-art-001',
        role: 'main',
        spotifyId: 'sp-art-001',
        ytmId: 'yt-art-001',
      );

      expect(artist1, equals(artist2));
      expect(artist1.hashCode, equals(artist2.hashCode));
      expect(artist1.displayName, 'Miles Davis');
      expect(artist1.hasExternalIds, isTrue);
      expect(artist1.toString(), contains('art-001'));
    });

    test('displayName fallbacks to Unknown Artist for empty names', () {
      const emptyArtist = Artist(id: 'art-none', name: '');
      expect(emptyArtist.displayName, 'Unknown Artist');
      expect(emptyArtist.hasExternalIds, isFalse);
    });

    test('serializes to and from JSON', () {
      final json = {
        'id': 'art-002',
        'name': 'Pink Floyd',
        'musicbrainz_id': 'mb-pf-002',
        'role': 'featured',
        'spotify_id': 'sp-pf-002',
        'ytm_id': 'yt-pf-002',
      };

      final artist = Artist.fromJson(json);
      expect(artist.id, 'art-002');
      expect(artist.name, 'Pink Floyd');
      expect(artist.musicbrainzId, 'mb-pf-002');
      expect(artist.role, 'featured');
      expect(artist.spotifyId, 'sp-pf-002');
      expect(artist.ytmId, 'yt-pf-002');

      final serialized = artist.toJson();
      expect(serialized['id'], 'art-002');
      expect(serialized['name'], 'Pink Floyd');
      expect(serialized['musicbrainz_id'], 'mb-pf-002');
      expect(serialized['role'], 'featured');
      expect(serialized['spotify_id'], 'sp-pf-002');
      expect(serialized['ytm_id'], 'yt-pf-002');
    });

    test('supports copyWith', () {
      const artist = Artist(id: 'art-001', name: 'Original');
      final updated = artist.copyWith(name: 'Updated', role: 'producer');

      expect(updated.id, 'art-001');
      expect(updated.name, 'Updated');
      expect(updated.role, 'producer');
    });
  });

  group('Album Model', () {
    test(
      'instantiates with full C++ aligned metadata and backward compatible properties',
      () {
        const album = Album(
          id: 'alb-001',
          title: 'Kind of Blue',
          releaseYear: 1959,
          releaseMonth: 8,
          releaseDay: 17,
          artistName: 'Miles Davis',
          coverArtHash: 'cov-hash-001',
          totalTracks: 5,
          totalDiscs: 1,
          coverColor: Color(0xFF1E3A8A),
          format: 'FLAC 24/192',
        );

        expect(album.id, 'alb-001');
        expect(album.title, 'Kind of Blue');
        expect(album.displayTitle, 'Kind of Blue');
        expect(album.releaseYear, 1959);
        expect(album.releaseMonth, 8);
        expect(album.releaseDay, 17);
        expect(album.formattedReleaseDate, '1959-08-17');
        expect(album.artistName, 'Miles Davis');
        expect(album.artist, 'Miles Davis');
        expect(album.displayArtist, 'Miles Davis');
        expect(album.year, 1959);
        expect(album.totalTracks, 5);
        expect(album.trackCount, 5);
        expect(album.totalDiscs, 1);
        expect(album.coverArtHash, 'cov-hash-001');
        expect(album.coverColor, const Color(0xFF1E3A8A));
        expect(album.format, 'FLAC 24/192');
        expect(album.toString(), contains('alb-001'));
      },
    );

    test('supports legacy parameter names in constructor', () {
      const legacyAlbum = Album(
        id: 'alb-legacy',
        title: 'Hell Freezes Over',
        artist: 'Eagles',
        year: 1994,
        trackCount: 15,
        coverColor: Color(0xFF78350F),
        format: 'FLAC 24/96',
      );

      expect(legacyAlbum.artist, 'Eagles');
      expect(legacyAlbum.artistName, 'Eagles');
      expect(legacyAlbum.year, 1994);
      expect(legacyAlbum.releaseYear, 1994);
      expect(legacyAlbum.trackCount, 15);
      expect(legacyAlbum.totalTracks, 15);
      expect(legacyAlbum.formattedReleaseDate, '1994');
    });

    test(
      'serializes to and from JSON with snake_case and camelCase compatibility',
      () {
        final json = {
          'id': 'alb-002',
          'title': 'Aja',
          'release_year': 1977,
          'release_month': 9,
          'release_day': 23,
          'artist_name': 'Steely Dan',
          'cover_art_hash': 'cov-aja-123',
          'total_tracks': 7,
          'total_discs': 1,
          'format': 'FLAC 24/96',
          'cover_color': '#14532D',
        };

        final album = Album.fromJson(json);
        expect(album.id, 'alb-002');
        expect(album.title, 'Aja');
        expect(album.releaseYear, 1977);
        expect(album.releaseMonth, 9);
        expect(album.releaseDay, 23);
        expect(album.artistName, 'Steely Dan');
        expect(album.coverArtHash, 'cov-aja-123');
        expect(album.totalTracks, 7);
        expect(album.totalDiscs, 1);
        expect(album.coverColor, const Color(0xFF14532D));

        final serialized = album.toJson();
        expect(serialized['id'], 'alb-002');
        expect(serialized['title'], 'Aja');
        expect(serialized['release_year'], 1977);
        expect(serialized['artist_name'], 'Steely Dan');
        expect(serialized['cover_art_hash'], 'cov-aja-123');
        expect(serialized['total_tracks'], 7);
      },
    );

    test('supports copyWith and value equality', () {
      const album1 = Album(id: 'alb-1', title: 'Title 1', releaseYear: 2000);
      const album2 = Album(id: 'alb-1', title: 'Title 1', releaseYear: 2000);
      expect(album1, equals(album2));
      expect(album1.hashCode, equals(album2.hashCode));

      final updated = album1.copyWith(
        title: 'Title 2',
        artistName: 'New Artist',
        totalTracks: 12,
      );
      expect(updated.id, 'alb-1');
      expect(updated.title, 'Title 2');
      expect(updated.artistName, 'New Artist');
      expect(updated.totalTracks, 12);
      expect(updated.releaseYear, 2000);
    });
  });

  group('Playlist Model', () {
    test('instantiates correctly with trackIds and getters', () {
      final now = DateTime(2026, 3, 1, 10, 0);
      final playlist = Playlist(
        id: 'ply-001',
        title: 'Audiophile Master Test',
        description: 'Selected FLAC reference tracks for soundstage testing.',
        trackIds: const ['trk-001', 'trk-002', 'trk-003'],
        createdAt: now,
        updatedAt: now,
        coverArtHash: 'cov-ply-001',
      );

      expect(playlist.id, 'ply-001');
      expect(playlist.title, 'Audiophile Master Test');
      expect(playlist.displayTitle, 'Audiophile Master Test');
      expect(playlist.description, contains('soundstage'));
      expect(playlist.trackCount, 3);
      expect(playlist.isEmpty, isFalse);
      expect(playlist.isNotEmpty, isTrue);
      expect(playlist.coverArtHash, 'cov-ply-001');
      expect(playlist.toString(), contains('ply-001'));
    });

    test('serializes to and from JSON', () {
      final now = DateTime.parse('2026-03-01T12:00:00.000Z');
      final json = {
        'id': 'ply-002',
        'title': 'Late Night Jazz',
        'description': 'Calm acoustic jazz.',
        'track_ids': ['trk-101', 'trk-102'],
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'cover_art_hash': 'cov-jazz',
      };

      final playlist = Playlist.fromJson(json);
      expect(playlist.id, 'ply-002');
      expect(playlist.title, 'Late Night Jazz');
      expect(playlist.trackIds, ['trk-101', 'trk-102']);
      expect(playlist.trackCount, 2);
      expect(playlist.createdAt, now);
      expect(playlist.coverArtHash, 'cov-jazz');

      final serialized = playlist.toJson();
      expect(serialized['id'], 'ply-002');
      expect(serialized['title'], 'Late Night Jazz');
      expect(serialized['track_ids'], ['trk-101', 'trk-102']);
    });

    test('supports copyWith and list value equality', () {
      final playlist1 = Playlist(
        id: 'ply-1',
        title: 'P1',
        trackIds: const ['t1', 't2'],
      );
      final playlist2 = Playlist(
        id: 'ply-1',
        title: 'P1',
        trackIds: const ['t1', 't2'],
      );
      expect(playlist1, equals(playlist2));
      expect(playlist1.hashCode, equals(playlist2.hashCode));

      final updated = playlist1.copyWith(
        title: 'P2',
        trackIds: const ['t1', 't2', 't3'],
      );
      expect(updated.title, 'P2');
      expect(updated.trackCount, 3);
      expect(playlist1.trackCount, 2);
    });
  });

  group('SourceData Model', () {
    test('instantiates correctly and provides getters', () {
      final now = DateTime(2026, 2, 20, 14, 30);
      final source = SourceData(
        id: 'src-001',
        fileHash:
            '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
        sourceType: 'cd_rip',
        originalPath: '/mnt/storage/rips/kind_of_blue/01_so_what.flac',
        createdAt: now,
        note: 'AccurateRip confidence 42, EAC secure mode.',
      );

      expect(source.id, 'src-001');
      expect(source.sourceType, 'cd_rip');
      expect(source.originalPath, contains('kind_of_blue'));
      expect(source.shortFileHash, '7f83b165...6d9069');
      expect(source.hasNote, isTrue);
      expect(source.toString(), contains('src-001'));
    });

    test('serializes to and from JSON', () {
      final now = DateTime.parse('2026-02-20T14:30:00.000Z');
      final json = {
        'id': 'src-002',
        'file_hash': 'hash-src-002',
        'source_type': 'vinyl_rip',
        'original_path': '/vinyl/dark_side_2496.wav',
        'created_at': now.toIso8601String(),
        'note': 'Technics SL-1200GR + Ortofon 2M Black',
      };

      final source = SourceData.fromJson(json);
      expect(source.id, 'src-002');
      expect(source.fileHash, 'hash-src-002');
      expect(source.sourceType, 'vinyl_rip');
      expect(source.originalPath, '/vinyl/dark_side_2496.wav');
      expect(source.createdAt, now);
      expect(source.note, contains('Technics'));

      final serialized = source.toJson();
      expect(serialized['id'], 'src-002');
      expect(serialized['file_hash'], 'hash-src-002');
      expect(serialized['source_type'], 'vinyl_rip');
    });

    test('supports copyWith and value equality', () {
      final now = DateTime.now();
      final s1 = SourceData(id: 's1', fileHash: 'h1', createdAt: now);
      final s2 = SourceData(id: 's1', fileHash: 'h1', createdAt: now);
      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));

      final updated = s1.copyWith(note: 'New Note', sourceType: 'web');
      expect(updated.note, 'New Note');
      expect(updated.sourceType, 'web');
      expect(s1.note, '');
    });
  });

  group('Tag Model', () {
    test('instantiates correctly and provides getters', () {
      final now = DateTime(2026, 1, 10);
      final tag = Tag(
        id: 'tag-001',
        name: 'Audiophile Master',
        category: 'quality',
        createdAt: now,
      );

      expect(tag.id, 'tag-001');
      expect(tag.name, 'Audiophile Master');
      expect(tag.displayName, 'Audiophile Master');
      expect(tag.category, 'quality');
      expect(tag.displayCategory, 'quality');
      expect(tag.createdAt, now);
      expect(tag.toString(), contains('tag-001'));
    });

    test('displayName fallbacks to Untitled Tag for empty name', () {
      const tag = Tag(id: 'tag-empty', name: '', category: '');
      expect(tag.displayName, 'Untitled Tag');
      expect(tag.displayCategory, 'general');
    });

    test('serializes to and from JSON', () {
      final now = DateTime.parse('2026-01-10T00:00:00.000Z');
      final json = {
        'id': 'tag-002',
        'name': 'DSD Native',
        'category': 'format',
        'created_at': now.toIso8601String(),
      };

      final tag = Tag.fromJson(json);
      expect(tag.id, 'tag-002');
      expect(tag.name, 'DSD Native');
      expect(tag.category, 'format');
      expect(tag.createdAt, now);

      final serialized = tag.toJson();
      expect(serialized['id'], 'tag-002');
      expect(serialized['name'], 'DSD Native');
      expect(serialized['category'], 'format');
    });

    test('supports copyWith and value equality', () {
      const t1 = Tag(id: 't1', name: 'Jazz', category: 'genre');
      const t2 = Tag(id: 't1', name: 'Jazz', category: 'genre');
      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));

      final updated = t1.copyWith(name: 'Modal Jazz');
      expect(updated.id, 't1');
      expect(updated.name, 'Modal Jazz');
      expect(updated.category, 'genre');
    });
  });

  group('ImageAsset Model', () {
    test('instantiates correctly and calculates image metrics', () {
      const image = ImageAsset(
        imageHash: 'img-7f83b1657ff1',
        fileHash: 'e3b0c44298fc1c149afbf4c8',
        width: 1400,
        height: 1400,
        dominantColor: '#1E3A8A',
        role: 'front',
        mimeType: 'image/jpeg',
        fileSize: 482012,
      );

      expect(image.imageHash, 'img-7f83b1657ff1');
      expect(image.fileHash, 'e3b0c44298fc1c149afbf4c8');
      expect(image.width, 1400);
      expect(image.height, 1400);
      expect(image.aspectRatio, 1.0);
      expect(image.isSquare, isTrue);
      expect(image.role, 'front');
      expect(image.mimeType, 'image/jpeg');
      expect(image.fileSize, 482012);
      expect(image.parsedDominantColor, const Color(0xFF1E3A8A));
      expect(image.shortImageHash, 'img-7f...7ff1');
      expect(image.shortFileHash, 'e3b0c4...f4c8');
      expect(image.toString(), contains('img-7f83b1657ff1'));
    });

    test('parses irregular dominantColor strings safely', () {
      const img1 = ImageAsset(
        imageHash: 'h1',
        fileHash: 'f1',
        dominantColor: 'FF123456',
      );
      expect(img1.parsedDominantColor, const Color(0xFF123456));

      const img2 = ImageAsset(
        imageHash: 'h2',
        fileHash: 'f2',
        dominantColor: '',
      );
      expect(img2.parsedDominantColor, isNull);
    });

    test('serializes to and from JSON', () {
      final json = {
        'image_hash': 'img-hash-1',
        'file_hash': 'file-hash-1',
        'width': 1920,
        'height': 1080,
        'dominant_color': '#0F172A',
        'role': 'back',
        'mime_type': 'image/png',
        'file_size': 1204800,
      };

      final image = ImageAsset.fromJson(json);
      expect(image.imageHash, 'img-hash-1');
      expect(image.fileHash, 'file-hash-1');
      expect(image.width, 1920);
      expect(image.height, 1080);
      expect(image.aspectRatio, closeTo(1.777, 0.001));
      expect(image.isSquare, isFalse);
      expect(image.dominantColor, '#0F172A');
      expect(image.role, 'back');
      expect(image.mimeType, 'image/png');
      expect(image.fileSize, 1204800);

      final serialized = image.toJson();
      expect(serialized['image_hash'], 'img-hash-1');
      expect(serialized['width'], 1920);
      expect(serialized['role'], 'back');
    });

    test('supports copyWith and value equality', () {
      const img1 = ImageAsset(
        imageHash: 'h1',
        fileHash: 'f1',
        width: 500,
        height: 500,
      );
      const img2 = ImageAsset(
        imageHash: 'h1',
        fileHash: 'f1',
        width: 500,
        height: 500,
      );
      expect(img1, equals(img2));
      expect(img1.hashCode, equals(img2.hashCode));

      final updated = img1.copyWith(
        dominantColor: '#FFFFFF',
        role: 'artist_avatar',
      );
      expect(updated.imageHash, 'h1');
      expect(updated.dominantColor, '#FFFFFF');
      expect(updated.role, 'artist_avatar');
    });
  });
}
