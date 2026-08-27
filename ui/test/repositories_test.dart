// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:ui/core/ffi/ffi.dart';
import 'package:ui/core/repositories/repositories.dart';
import 'package:ui/features/models/models.dart';

void main() {
  late LyraNativeBridge bridge;

  setUp(() async {
    bridge = LyraNativeBridge();
    await bridge.initialize(forceMock: true);
    LyraNativeBridge.setInstance(bridge);
  });

  tearDown(() async {
    await bridge.dispose();
  });

  group('WorkRepository', () {
    late WorkRepository repo;

    setUp(() {
      repo = WorkRepository(bridge);
    });

    test('listWorks retrieves mock work entities', () async {
      final works = await repo.listWorks(offset: 0, limit: 10);
      expect(works, isNotEmpty);
      expect(works.first.id, equals('wrk-001'));
      expect(works.first.title, contains('Symphony No. 5'));
      expect(works.first.compositionStartYear, equals(1804));
      expect(works.first.compositionEndYear, equals(1808));
    });

    test('getWork retrieves single work by id', () async {
      final work = await repo.getWork('wrk-002');
      expect(work.id, equals('wrk-002'));
      expect(work.title, equals('Hotel California'));
      expect(work.compositionStartYear, equals(1976));
    });

    test('getWorksByTitle queries works by matching title', () async {
      final works = await repo.getWorksByTitle('Symphony No. 5 in C minor');
      expect(works, isNotEmpty);
      expect(works.first.title, contains('Symphony No. 5'));
    });

    test(
      'createWork sends serialized payload and parses created entity',
      () async {
        const newWork = Work(
          id: 'wrk-new-001',
          title: 'Clair de Lune',
          compositionStartYear: 1890,
          compositionEndYear: 1905,
        );
        final created = await repo.createWork(newWork);
        expect(created.id, equals('wrk-new-001'));
        expect(created.title, equals('Clair de Lune'));
        expect(created.compositionStartYear, equals(1890));
      },
    );

    test(
      'updateWork sends update payload and returns updated entity',
      () async {
        const update = Work(
          id: 'wrk-001',
          title: 'Symphony No. 5 in C minor (Revised)',
        );
        final updated = await repo.updateWork(update);
        expect(updated.id, equals('wrk-001'));
        expect(updated.title, equals('Symphony No. 5 in C minor (Revised)'));
      },
    );
  });

  group('TrackRepository', () {
    late TrackRepository repo;

    setUp(() {
      repo = TrackRepository(bridge);
    });

    test('listTracks retrieves list of mock tracks', () async {
      final tracks = await repo.listTracks(offset: 0, limit: 10);
      expect(tracks.length, greaterThanOrEqualTo(2));
      expect(tracks.first.id, equals('trk-001'));
      expect(tracks.first.title, contains('Hotel California'));
      expect(tracks.first.artist, equals('Eagles'));
      expect(tracks.first.sampleRate, equals(96000));
      expect(tracks.first.bitDepth, equals(24));
    });

    test('getTrack retrieves single track by id', () async {
      final track = await repo.getTrack('trk-001');
      expect(track.id, equals('trk-001'));
      expect(track.title, contains('Hotel California'));
      expect(track.durationMs, equals(432000));
      expect(track.verified, isTrue);
    });

    test('getTracksByTitle queries tracks by title', () async {
      final tracks = await repo.getTracksByTitle('Hotel California');
      expect(tracks, isNotEmpty);
      expect(tracks.first.title, contains('Hotel California'));
    });

    test('createTrack sends track payload and returns created track', () async {
      const newTrack = Track(
        id: 'trk-new-001',
        title: 'Take Five',
        pcmHash: 'pcm_hash_take_five',
        durationMs: 324000,
      );
      final created = await repo.createTrack(newTrack);
      expect(created.id, equals('trk-new-001'));
      expect(created.title, equals('Take Five'));
    });

    test('updateTrack sends updated track fields', () async {
      const updatedTrack = Track(
        id: 'trk-001',
        title: 'Hotel California (2024 Remaster)',
      );
      final updated = await repo.updateTrack(updatedTrack);
      expect(updated.id, equals('trk-001'));
      expect(updated.title, equals('Hotel California (2024 Remaster)'));
    });

    test('importTrack ingests file and returns parsed track entity', () async {
      final imported = await repo.importTrack('/music/lossless/Track01.flac');
      expect(imported.id, startsWith('trk-imported-'));
      expect(imported.title, equals('Track01'));
      expect(imported.pcmHash, startsWith('mock_pcm_'));
    });
  });

  group('AlbumRepository', () {
    late AlbumRepository repo;

    setUp(() {
      repo = AlbumRepository(bridge);
    });

    test('listAlbums retrieves mock albums', () async {
      final albums = await repo.listAlbums();
      expect(albums.length, greaterThanOrEqualTo(2));
      expect(albums.first.title, equals('Kind of Blue'));
      expect(albums.first.artist, equals('Miles Davis'));
      expect(albums.first.releaseYear, equals(1959));
    });

    test('getAlbum retrieves album by id', () async {
      final album = await repo.getAlbum('alb-002');
      expect(album.id, equals('alb-002'));
      expect(album.title, equals('Hell Freezes Over'));
      expect(album.artist, equals('Eagles'));
      expect(album.releaseYear, equals(1994));
    });

    test('getAlbumsByTitle queries albums by title', () async {
      final albums = await repo.getAlbumsByTitle('Kind of Blue');
      expect(albums, isNotEmpty);
      expect(albums.first.title, equals('Kind of Blue'));
    });

    test(
      'createAlbum sends album payload and returns created entity',
      () async {
        const newAlbum = Album(
          id: 'alb-new-001',
          title: 'A Love Supreme',
          artist: 'John Coltrane',
          releaseYear: 1965,
        );
        final created = await repo.createAlbum(newAlbum);
        expect(created.id, equals('alb-new-001'));
        expect(created.title, equals('A Love Supreme'));
      },
    );

    test('updateAlbum updates album metadata', () async {
      const update = Album(
        id: 'alb-001',
        title: 'Kind of Blue (50th Anniversary)',
      );
      final updated = await repo.updateAlbum(update);
      expect(updated.id, equals('alb-001'));
      expect(updated.title, equals('Kind of Blue (50th Anniversary)'));
    });

    test('getAlbumCover retrieves ImageAsset for album cover', () async {
      final cover = await repo.getAlbumCover('alb-001');
      expect(cover, isNotNull);
      expect(cover!.imageHash, equals('img-cover-alb-001'));
      expect(cover.width, equals(1000));
      expect(cover.height, equals(1000));
      expect(cover.dominantColor, equals('#1E293B'));
    });
  });

  group('ArtistRepository', () {
    late ArtistRepository repo;

    setUp(() {
      repo = ArtistRepository(bridge);
    });

    test('listArtists retrieves mock artists', () async {
      final artists = await repo.listArtists();
      expect(artists.length, greaterThanOrEqualTo(2));
      expect(artists.first.name, equals('Miles Davis'));
    });

    test('getArtist retrieves artist by id', () async {
      final artist = await repo.getArtist('art-002');
      expect(artist.id, equals('art-002'));
      expect(artist.name, equals('Eagles'));
    });

    test('getArtistsByName queries artists by name', () async {
      final artists = await repo.getArtistsByName('Miles Davis');
      expect(artists, isNotEmpty);
      expect(artists.first.name, equals('Miles Davis'));
    });

    test('createArtist creates new artist record', () async {
      const newArtist = Artist(
        id: 'art-new-001',
        name: 'Bill Evans',
        role: 'pianist',
      );
      final created = await repo.createArtist(newArtist);
      expect(created.id, equals('art-new-001'));
      expect(created.name, equals('Bill Evans'));
    });

    test('updateArtist updates existing artist', () async {
      const update = Artist(id: 'art-001', name: 'Miles Dewey Davis III');
      final updated = await repo.updateArtist(update);
      expect(updated.id, equals('art-001'));
      expect(updated.name, equals('Miles Dewey Davis III'));
    });

    test('getArtistCover retrieves ImageAsset for artist avatar', () async {
      final cover = await repo.getArtistCover('art-001');
      expect(cover, isNotNull);
      expect(cover!.imageHash, equals('img-art-art-001'));
      expect(cover.role, equals('artist_avatar'));
    });
  });

  group('PlaylistRepository', () {
    late PlaylistRepository repo;

    setUp(() {
      repo = PlaylistRepository(bridge);
    });

    test('listPlaylists retrieves mock playlists', () async {
      final playlists = await repo.listPlaylists();
      expect(playlists, isNotEmpty);
      expect(playlists.first.title, equals('Audiophile Reference'));
      expect(playlists.first.trackIds, containsAll(['trk-001', 'trk-002']));
    });

    test('getPlaylist retrieves playlist by id', () async {
      final playlist = await repo.getPlaylist('pl-001');
      expect(playlist.id, equals('pl-001'));
      expect(playlist.title, equals('Audiophile Reference'));
      expect(playlist.trackCount, equals(2));
    });

    test('getPlaylistsByTitle queries playlists by title', () async {
      final playlists = await repo.getPlaylistsByTitle('Audiophile Reference');
      expect(playlists, isNotEmpty);
      expect(playlists.first.title, equals('Audiophile Reference'));
    });

    test('createPlaylist creates new playlist entity', () async {
      const newPlaylist = Playlist(
        id: 'pl-new-001',
        title: 'Hi-Res Acoustic Sessions',
        description: 'Selected acoustic recordings',
      );
      final created = await repo.createPlaylist(newPlaylist);
      expect(created.id, equals('pl-new-001'));
      expect(created.title, equals('Hi-Res Acoustic Sessions'));
    });

    test('updatePlaylist updates playlist fields', () async {
      const update = Playlist(id: 'pl-001', title: 'Master Reference Tracks');
      final updated = await repo.updatePlaylist(update);
      expect(updated.id, equals('pl-001'));
      expect(updated.title, equals('Master Reference Tracks'));
    });

    test('addPlaylistTrack and removePlaylistTrack execute cleanly', () async {
      await expectLater(
        repo.addPlaylistTrack('pl-001', 'trk-003', position: 2),
        completes,
      );
      await expectLater(
        repo.removePlaylistTrack('pl-001', 'trk-003'),
        completes,
      );
    });

    test('getPlaylistTracks returns track IDs', () async {
      final tracks = await repo.getPlaylistTracks('pl-001');
      expect(tracks, equals(['trk-001', 'trk-002']));
    });

    test('getPlaylistCover retrieves ImageAsset for playlist', () async {
      final cover = await repo.getPlaylistCover('pl-001');
      expect(cover, isNotNull);
      expect(cover!.imageHash, equals('img-pl-pl-001'));
      expect(cover.width, equals(600));
    });
  });

  group('AssetRepository', () {
    late AssetRepository repo;

    setUp(() {
      repo = AssetRepository(bridge);
    });

    test('listAssets retrieves mock CAS file assets', () async {
      final assets = await repo.listAssets();
      expect(assets, isNotEmpty);
      expect(assets.first.mimeType, equals('audio/flac'));
      expect(assets.first.fileSize, equals(45218900));
      expect(assets.first.verified, isTrue);
    });

    test('getAsset retrieves asset by file hash', () async {
      final asset = await repo.getAsset(
        '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      );
      expect(asset.fileHash, startsWith('7f83b165'));
      expect(asset.assetType, equals('audio'));
    });

    test('createAsset and updateAsset handle asset entities', () async {
      final newAsset = Asset(
        fileHash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        mimeType: 'audio/wav',
        assetType: 'audio',
        fileSize: 52000000,
        createdAt: DateTime(2026, 1, 1),
      );
      final created = await repo.createAsset(newAsset);
      expect(
        created.fileHash,
        equals(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
      );

      final updated = await repo.updateAsset(newAsset);
      expect(
        updated.fileHash,
        equals(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
      );
    });

    test('getResourcePath resolves track, audio, and file paths', () async {
      final trackPath = await repo.getResourcePath('track', 'trk-001');
      expect(trackPath, contains('/storage/cas/'));

      final audioPath = await repo.getResourcePath('audio', 'mock_pcm_hash');
      expect(audioPath, contains('/storage/cas/'));

      final filePath = await repo.getResourcePath('file', 'mock_file_hash');
      expect(filePath, contains('/storage/cas/'));
    });
  });

  group('AudioRepository', () {
    late AudioRepository repo;

    setUp(() {
      repo = AudioRepository(bridge);
    });

    test('listAudio retrieves decoded audio stream entities', () async {
      final audios = await repo.listAudio();
      expect(audios, isNotEmpty);
      expect(audios.first.sampleRate, equals(96000));
      expect(audios.first.bitDepth, equals(24));
      expect(audios.first.channels, equals(2));
      expect(audios.first.integratedLoudness, equals(-14.2));
    });

    test('getAudio retrieves audio stream by pcm hash', () async {
      final audio = await repo.getAudio(
        '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      );
      expect(audio.pcmHash, startsWith('7f83b165'));
      expect(audio.qualityScore, equals(98));
      expect(audio.truePeak, equals(-0.5));
    });

    test('createAudio and updateAudio handle audio entities', () async {
      const newAudio = Audio(
        pcmHash: 'pcm_stream_001',
        bitDepth: 24,
        sampleRate: 192000,
        channels: 2,
        qualityScore: 99,
      );
      final created = await repo.createAudio(newAudio);
      expect(created.pcmHash, equals('pcm_stream_001'));

      final updated = await repo.updateAudio(newAudio);
      expect(updated.pcmHash, equals('pcm_stream_001'));
    });
  });

  group('TagRepository', () {
    late TagRepository repo;

    setUp(() {
      repo = TagRepository(bridge);
    });

    test('listTags retrieves mock tags with filters', () async {
      final tags = await repo.listTags(category: 'quality');
      expect(tags.length, greaterThanOrEqualTo(2));
      expect(tags.first.name, equals('Audiophile Master'));
      expect(tags.first.category, equals('quality'));
    });

    test('createTag registers new tag', () async {
      const newTag = Tag(
        id: 'tag-new-001',
        name: 'DSD Remaster',
        category: 'source',
      );
      final created = await repo.createTag(newTag);
      expect(created.id, equals('tag-new-001'));
      expect(created.name, equals('DSD Remaster'));
      expect(created.category, equals('source'));
    });

    test('assignTag and removeTag execute successfully', () async {
      await expectLater(
        repo.assignTag(
          entityId: 'trk-001',
          tagId: 'tag-001',
          entityType: 'track',
        ),
        completes,
      );
      await expectLater(
        repo.removeTag(
          entityId: 'trk-001',
          tagId: 'tag-001',
          entityType: 'track',
        ),
        completes,
      );
    });

    test('getEntityTags retrieves tags assigned to entity', () async {
      final entityTags = await repo.getEntityTags(
        'trk-001',
        entityType: 'track',
      );
      expect(entityTags, isNotEmpty);
      expect(entityTags.first.name, equals('Audiophile Master'));
    });
  });

  group('SourceDataRepository', () {
    late SourceDataRepository repo;

    setUp(() {
      repo = SourceDataRepository(bridge);
    });

    test('getSourceDataByAssetHash retrieves provenance source data', () async {
      final source = await repo.getSourceDataByAssetHash(
        '7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069',
      );
      expect(source, isNotNull);
      expect(source!.sourceType, equals('cd_rip'));
      expect(source.originalPath, equals('/media/cdrom/track01.wav'));
      expect(source.note, contains('EAC AccurateRip'));
    });

    test('createSourceData registers source metadata', () async {
      final newSource = SourceData(
        id: 'src-new-001',
        fileHash: 'hash-abc',
        sourceType: 'vinyl_rip',
        originalPath: '/rips/album.flac',
        createdAt: DateTime(2026, 1, 1),
        note: 'Technics SL-1200MK7 + Nagaoka MP-500',
      );
      final created = await repo.createSourceData(newSource);
      expect(created.id, equals('src-new-001'));
      expect(created.sourceType, equals('vinyl_rip'));
      expect(created.note, contains('Nagaoka'));
    });
  });

  group('Repository Error Handling & Default Bridge', () {
    test('BaseRepository uses LyraNativeBridge.instance by default', () {
      final defaultRepo = WorkRepository();
      expect(identical(defaultRepo.bridge, LyraNativeBridge.instance), isTrue);
    });

    test(
      'BaseRepository throws LyraBridgeException on error response code',
      () async {
        bridge.registerMockHandler(
          'GetWork',
          (params) async => {
            'code': 404,
            'status': 'error',
            'error': {'message': 'Work not found with id wrk-invalid'},
          },
        );

        final repo = WorkRepository(bridge);
        expect(
          () => repo.getWork('wrk-invalid'),
          throwsA(
            isA<LyraBridgeException>().having(
              (e) => e.code,
              'code',
              equals(404),
            ),
          ),
        );
      },
    );
  });
}
