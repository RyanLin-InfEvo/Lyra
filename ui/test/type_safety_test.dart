// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:ui/core/ffi/lyra_native_bridge.dart';
import 'package:ui/core/repositories/album_repository.dart';
import 'package:ui/core/repositories/artist_repository.dart';
import 'package:ui/core/repositories/asset_repository.dart';
import 'package:ui/core/repositories/audio_repository.dart';
import 'package:ui/core/repositories/playlist_repository.dart';
import 'package:ui/core/repositories/source_data_repository.dart';
import 'package:ui/core/repositories/tag_repository.dart';
import 'package:ui/core/repositories/track_repository.dart';
import 'package:ui/core/repositories/work_repository.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/models/album.dart';
import 'package:ui/features/models/artist.dart';
import 'package:ui/features/models/audio.dart';
import 'package:ui/features/models/cas_object.dart';
import 'package:ui/features/models/image_asset.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/source_data.dart';
import 'package:ui/features/models/tag.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/models/work.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/services/music_service.dart';
import 'package:ui/features/shell/app_shell.dart';
import 'package:ui/features/shell/sidebar.dart';

Widget buildTestApp({MusicService? musicService}) {
  final service = musicService ?? MockMusicService();
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: LyraThemeTokens.dark(),
        themeModeNotifier: themeModeNotifier,
        child: AppShell(musicService: service),
      ),
    ),
  );
}

class EmptyMusicService implements MusicService {
  @override
  Future<List<Track>> getTracks({String? query}) async => [];

  @override
  Future<List<Work>> getWorks({String? query}) async => [];

  @override
  Future<List<Album>> getAlbums({String? query}) async => [];

  @override
  Future<List<Artist>> getArtists({String? query}) async => [];

  @override
  Future<List<Playlist>> getPlaylists({String? query}) async => [];

  @override
  Future<List<Tag>> getTags() async => [];

  @override
  Future<Tag> createTag({
    required String name,
    String category = 'general',
  }) async {
    return Tag(id: 'tag-test', name: name, category: category);
  }

  @override
  Future<void> deleteTag(String tagId) async {}

  @override
  Future<Playlist> createPlaylist({
    required String title,
    String? description,
    List<String> trackIds = const [],
  }) async {
    return Playlist(
      id: 'pl-test-new',
      title: title,
      description: description,
      trackIds: trackIds,
    );
  }

  @override
  Future<List<CasObject>> getCasObjects() async => [];

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
    return Track(
      id: 'trk-test-imported',
      title: title,
      artistName: artist,
      albumTitle: album,
      format: format,
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      pcmHash: simulatedHash,
    );
  }

  @override
  Future<bool> verifyCasHash(String hash) async => true;

  @override
  Future<Audio?> getAudioDetails(String pcmHash) async => null;

  @override
  Future<SourceData?> getSourceData(String fileHash) async => null;

  @override
  Future<Asset?> getAsset(String fileHash) async => null;

  @override
  Future<List<Audio>> getAudioVersions(String pcmHash) async => [];

  @override
  Future<void> switchTrackAudio(String trackId, String newPcmHash) async {}
}

void main() {
  group('Model Deserialization & Null Safety Tests', () {
    test(
      'Playlist.fromJson handles nulls, int IDs, and diverse structures',
      () {
        // Completely empty map
        final p1 = Playlist.fromJson({});
        expect(p1.id, '');
        expect(p1.title, '');
        expect(p1.description, isNull);
        expect(p1.trackIds, isEmpty);
        expect(p1.trackCount, 0);
        expect(p1.displayTitle, 'Untitled Playlist');

        // Integer id, integer title, tracks list with map items
        final p2 = Playlist.fromJson({
          'id': 12345,
          'title': 9999,
          'description': 'Description text',
          'tracks': [
            {'id': 'trk-1'},
            {'track_id': 'trk-2'},
            'trk-3',
            null,
          ],
          'created_at': '2026-01-01T00:00:00.000Z',
          'cover_art_hash': 445566,
        });
        expect(p2.id, '12345');
        expect(p2.title, '9999');
        expect(p2.description, 'Description text');
        expect(p2.trackIds, equals(['trk-1', 'trk-2', 'trk-3']));
        expect(p2.coverArtHash, '445566');
      },
    );

    test('Track.fromJson handles nulls, doubles, integer booleans', () {
      final t1 = Track.fromJson({});
      expect(t1.id, '');
      expect(t1.pcmHash, '');
      expect(t1.title, isNull);
      expect(t1.displayTitle, 'Untitled Track');
      expect(t1.artist, '');
      expect(t1.album, '');
      expect(t1.verified, isTrue);

      final t2 = Track.fromJson({
        'id': 101,
        'pcm_hash': 998877,
        'recording_year': 1994.0, // double
        'recording_month': '12', // string
        'recording_day': 25,
        'duration_ms': '360000', // string ms
        'sample_rate': 96000.0, // double
        'bit_depth': '24', // string
        'verified': 0, // integer bool
      });
      expect(t2.id, '101');
      expect(t2.pcmHash, '998877');
      expect(t2.recordingYear, 1994);
      expect(t2.recordingMonth, 12);
      expect(t2.recordingDay, 25);
      expect(t2.durationMs, 360000);
      expect(t2.sampleRate, 96000);
      expect(t2.bitDepth, 24);
      expect(t2.verified, isFalse);
    });

    test('Album.fromJson handles nulls, int colors, and numeric years', () {
      final a1 = Album.fromJson({});
      expect(a1.id, '');
      expect(a1.title, '');
      expect(a1.displayTitle, 'Untitled Album');
      expect(a1.displayArtist, 'Unknown Artist');
      expect(a1.year, 0);
      expect(a1.trackCount, 0);

      final a2 = Album.fromJson({
        'id': 500,
        'title': 'Test Album',
        'release_year': '2026',
        'total_tracks': 12.0,
        'total_discs': '2',
        'cover_color': 0xFF1E3A8A,
      });
      expect(a2.id, '500');
      expect(a2.releaseYear, 2026);
      expect(a2.totalTracks, 12);
      expect(a2.totalDiscs, 2);
      expect(a2.coverColor, const Color(0xFF1E3A8A));
    });

    test('Artist.fromJson handles nulls and non-strings', () {
      final art1 = Artist.fromJson({});
      expect(art1.id, '');
      expect(art1.name, '');
      expect(art1.displayName, 'Unknown Artist');
      expect(art1.hasExternalIds, isFalse);

      final art2 = Artist.fromJson({
        'id': 77,
        'name': 'Daft Punk',
        'spotify_id': 12345,
      });
      expect(art2.id, '77');
      expect(art2.name, 'Daft Punk');
      expect(art2.spotifyId, '12345');
      expect(art2.hasExternalIds, isTrue);
    });

    test('Work.fromJson handles nulls and non-strings', () {
      final w1 = Work.fromJson({});
      expect(w1.id, '');
      expect(w1.title, '');
      expect(w1.compositionStartYear, isNull);

      final w2 = Work.fromJson({
        'id': 10,
        'title': 'Symphony No. 9',
        'composition_start_year': '1822',
        'composition_end_year': 1824.0,
      });
      expect(w2.id, '10');
      expect(w2.compositionStartYear, 1822);
      expect(w2.compositionEndYear, 1824);
    });

    test('Asset.fromJson and ImageAsset.fromJson handle type conversions', () {
      final asset = Asset.fromJson({
        'file_hash': 123456,
        'file_size': '1048576',
        'verified': 1,
      });
      expect(asset.fileHash, '123456');
      expect(asset.fileSize, 1048576);
      expect(asset.verified, isTrue);

      final image = ImageAsset.fromJson({
        'image_hash': 'img1',
        'file_hash': 'file1',
        'width': '500',
        'height': 500.0,
        'dominant_color': '#1E3A8A',
        'file_size': 50000.0,
      });
      expect(image.width, 500);
      expect(image.height, 500);
      expect(image.fileSize, 50000);
      expect(image.isSquare, isTrue);
      expect(image.parsedDominantColor, const Color(0xFF1E3A8A));
    });

    test('CasObject.fromJson safely parses nulls, booleans, and formats', () {
      // Empty map
      final c1 = CasObject.fromJson({});
      expect(c1.fileHash, '');
      expect(c1.hash, '');
      expect(c1.fileSize, 0);
      expect(c1.sizeBytes, 0);
      expect(c1.mimeType, '');
      expect(c1.assetType, 'audio');
      expect(c1.verified, isTrue);

      // Explicit null verified
      final c2 = CasObject.fromJson({
        'file_hash':
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'file_size': 1048576,
        'mime_type': 'audio/flac',
        'verified': null,
      });
      expect(c2.verified, isTrue);
      expect(c2.formattedSize, '1.0 MB');
      expect(c2.shortHash, 'e3b0c442...52b855');

      // False string and int boolean
      final c3 = CasObject.fromJson({
        'hash': '1234567890abcdef1234567890abcdef',
        'size_bytes': 512,
        'verified': 'false',
      });
      expect(c3.verified, isFalse);
      expect(c3.formattedSize, '512 B');

      final c4 = CasObject.fromJson({'hash': 'abcdef', 'verified': 0});
      expect(c4.verified, isFalse);

      final c5 = CasObject.fromJson({'hash': 'abcdef', 'verified': 1});
      expect(c5.verified, isTrue);
    });

    test('Tag.fromJson and SourceData.fromJson handle nulls and types', () {
      final tag1 = Tag.fromJson({});
      expect(tag1.id, '');
      expect(tag1.name, '');
      expect(tag1.category, 'general');
      expect(tag1.displayName, 'Untitled Tag');
      expect(tag1.displayCategory, 'general');
      expect(tag1.createdAt, isNull);

      final tag2 = Tag.fromJson({
        'id': 999,
        'name': 888,
        'category': 'genre',
        'created_at': '2026-01-01T12:00:00.000Z',
      });
      expect(tag2.id, '999');
      expect(tag2.name, '888');
      expect(tag2.category, 'genre');
      expect(tag2.createdAt, isNotNull);

      final src1 = SourceData.fromJson({});
      expect(src1.id, '');
      expect(src1.fileHash, '');
      expect(src1.sourceType, '');
      expect(src1.originalPath, '');
      expect(src1.note, '');
      expect(src1.hasNote, isFalse);

      final src2 = SourceData.fromJson({
        'id': 123,
        'file_hash': 456,
        'source_type': 'vinyl_rip',
        'note': 'EAC AccurateRip log: 100% confidence',
      });
      expect(src2.id, '123');
      expect(src2.fileHash, '456');
      expect(src2.sourceType, 'vinyl_rip');
      expect(src2.hasNote, isTrue);
    });

    test('Audio.fromJson handles nulls and numeric conversions', () {
      final audio = Audio.fromJson({
        'pcm_hash': 'hash1',
        'quality_score': '99',
        'bit_depth': 24.0,
        'sample_rate': 96000,
        'duration_ms': 250.5,
        'integrated_loudness': '-14.0',
        'true_peak': -0.1,
      });
      expect(audio.qualityScore, 99);
      expect(audio.bitDepth, 24);
      expect(audio.sampleRate, 96000);
      expect(audio.integratedLoudness, -14.0);
      expect(audio.truePeak, -0.1);
    });

    test(
      'Comprehensive boolean null-safety sweep (no Null is not a subtype of bool)',
      () {
        // Test Asset with null, boolean, num, string, and malformed verified values
        final assetNull = Asset.fromJson({'verified': null});
        expect(assetNull.verified, isTrue);

        final assetFalseBool = Asset.fromJson({'verified': false});
        expect(assetFalseBool.verified, isFalse);

        final assetTrueBool = Asset.fromJson({'verified': true});
        expect(assetTrueBool.verified, isTrue);

        final assetZeroNum = Asset.fromJson({'verified': 0});
        expect(assetZeroNum.verified, isFalse);

        final assetOneNum = Asset.fromJson({'verified': 1});
        expect(assetOneNum.verified, isTrue);

        final assetFalseStr = Asset.fromJson({'verified': 'false'});
        expect(assetFalseStr.verified, isFalse);

        final assetTrueStr = Asset.fromJson({'verified': 'true'});
        expect(assetTrueStr.verified, isTrue);

        final assetZeroStr = Asset.fromJson({'verified': '0'});
        expect(assetZeroStr.verified, isFalse);

        final assetOneStr = Asset.fromJson({'verified': '1'});
        expect(assetOneStr.verified, isTrue);

        final assetMalformedStr = Asset.fromJson({'verified': 'unrecognized'});
        expect(assetMalformedStr.verified, isTrue); // fallback to default

        // Test Track with identical matrix
        final trackNull = Track.fromJson({'verified': null});
        expect(trackNull.verified, isTrue);

        final trackFalseBool = Track.fromJson({'verified': false});
        expect(trackFalseBool.verified, isFalse);

        final trackZeroNum = Track.fromJson({'verified': 0});
        expect(trackZeroNum.verified, isFalse);

        final trackFalseStr = Track.fromJson({'verified': 'false'});
        expect(trackFalseStr.verified, isFalse);

        final trackZeroStr = Track.fromJson({'verified': '0'});
        expect(trackZeroStr.verified, isFalse);

        final trackOneStr = Track.fromJson({'verified': '1'});
        expect(trackOneStr.verified, isTrue);

        // Test CasObject with identical matrix
        final casNull = CasObject.fromJson({'verified': null});
        expect(casNull.verified, isTrue);

        final casFalse = CasObject.fromJson({'verified': false});
        expect(casFalse.verified, isFalse);

        // Verify copyWith with null parameter preserves existing boolean value
        final assetCopyNull = assetFalseBool.copyWith(verified: null);
        expect(assetCopyNull.verified, isFalse);

        final trackCopyNull = trackFalseBool.copyWith(verified: null);
        expect(trackCopyNull.verified, isFalse);

        // Verify getters returning bool do not fail on empty/null models
        final emptyArtist = Artist.fromJson({});
        expect(emptyArtist.hasExternalIds, isFalse);

        final emptyPlaylist = Playlist.fromJson({});
        expect(emptyPlaylist.isEmpty, isTrue);
        expect(emptyPlaylist.isNotEmpty, isFalse);

        final emptySource = SourceData.fromJson({});
        expect(emptySource.hasNote, isFalse);

        final emptyImage = ImageAsset.fromJson({});
        expect(emptyImage.isSquare, isFalse);
      },
    );
  });

  group('BaseRepository Response Unpacking & Null Safety', () {
    late LyraNativeBridge bridge;

    setUp(() async {
      bridge = LyraNativeBridge();
      await bridge.initialize(forceMock: true);
      LyraNativeBridge.setInstance(bridge);
    });

    tearDown(() {
      LyraNativeBridge.resetInstance();
    });

    test('unpackMap returns empty map when data is null', () async {
      bridge.registerMockHandler(
        'TestNullData',
        (params) async => {'code': 200, 'status': 'success', 'data': null},
      );

      final repo = PlaylistRepository(bridge);
      final res = await bridge.executeCommand('TestNullData');
      final data = repo.unpackMap(res);
      expect(data, isEmpty);
    });

    test('unpackList returns empty list when data is null', () async {
      bridge.registerMockHandler(
        'TestNullList',
        (params) async => {'code': 200, 'status': 'success', 'data': null},
      );

      final repo = PlaylistRepository(bridge);
      final res = await bridge.executeCommand('TestNullList');
      final items = repo.unpackList(res);
      expect(items, isEmpty);
    });

    test(
      'All repositories execute list and get operations without TypeErrors',
      () async {
        final playlistRepo = PlaylistRepository(bridge);
        final trackRepo = TrackRepository(bridge);
        final albumRepo = AlbumRepository(bridge);
        final artistRepo = ArtistRepository(bridge);
        final assetRepo = AssetRepository(bridge);
        final audioRepo = AudioRepository(bridge);
        final tagRepo = TagRepository(bridge);
        final workRepo = WorkRepository(bridge);
        final sourceDataRepo = SourceDataRepository(bridge);

        // Verify list calls
        final playlists = await playlistRepo.listPlaylists();
        expect(playlists, isNotEmpty);

        final tracks = await trackRepo.listTracks();
        expect(tracks, isNotEmpty);

        final albums = await albumRepo.listAlbums();
        expect(albums, isNotEmpty);

        final artists = await artistRepo.listArtists();
        expect(artists, isNotEmpty);

        final assets = await assetRepo.listAssets();
        expect(assets, isNotEmpty);

        final audioList = await audioRepo.listAudio();
        expect(audioList, isNotEmpty);

        final tags = await tagRepo.listTags();
        expect(tags, isNotEmpty);

        final works = await workRepo.listWorks();
        expect(works, isNotEmpty);

        // Verify individual gets
        final pl = await playlistRepo.getPlaylist('pl-001');
        expect(pl.id, 'pl-001');

        final trk = await trackRepo.getTrack('trk-001');
        expect(trk.id, 'trk-001');

        final alb = await albumRepo.getAlbum('alb-001');
        expect(alb.id, 'alb-001');

        final art = await artistRepo.getArtist('art-001');
        expect(art.id, 'art-001');

        final cover = await albumRepo.getAlbumCover('alb-001');
        expect(cover, isNotNull);

        final srcData = await sourceDataRepo.getSourceDataByAssetHash('7f83b1');
        expect(srcData, isNotNull);
      },
    );
  });

  group('Full UI Workflow & Navigation Stress Test', () {
    testWidgets(
      'Clicking through all tabs, tracks, playlists, create playlist has zero TypeErrors',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final service = MockMusicService();
        await tester.pumpWidget(buildTestApp(musicService: service));
        await tester.pumpAndSettle();

        // 1. Initial State: Tracks tab is active
        expect(find.text('Tracks Library'), findsOneWidget);
        expect(find.text('Hotel California (Live on MTV 1994)'), findsWidgets);

        // 2. Click on Works tab
        await tester.tap(find.text('Works'));
        await tester.pumpAndSettle();
        expect(find.text('Musical Works'), findsOneWidget);
        expect(
          find.text('Symphony No. 9 in D minor, Op. 125 "Choral"'),
          findsOneWidget,
        );

        // 3. Click a work row to scope tracks
        await tester.tap(find.text('Hotel California').first);
        await tester.pumpAndSettle();
        expect(find.text('Tracks Library'), findsOneWidget);
        expect(find.text('Work: Hotel California'), findsOneWidget);

        // 4. Click clear filter (X icon)
        await tester.tap(find.byIcon(LucideIcons.x).first);
        await tester.pumpAndSettle();
        expect(find.text('Work: Hotel California'), findsNothing);

        // 5. Click on Albums tab
        await tester.tap(find.text('Albums').first);
        await tester.pumpAndSettle();
        expect(find.text('Albums'), findsWidgets);
        expect(find.text('Kind of Blue'), findsOneWidget);

        // 6. Click an album to scope tracks
        await tester.tap(find.text('Kind of Blue').first);
        await tester.pumpAndSettle();
        expect(find.text('Tracks Library'), findsOneWidget);
        expect(find.text('Album: Kind of Blue'), findsOneWidget);

        // 7. Click on Artists tab
        await tester.tap(find.text('Artists').first);
        await tester.pumpAndSettle();
        expect(find.text('Artists'), findsWidgets);
        expect(find.text('Miles Davis'), findsWidgets);

        // 8. Click an artist to scope tracks
        await tester.tap(find.text('Miles Davis').first);
        await tester.pumpAndSettle();
        expect(find.text('Tracks Library'), findsOneWidget);
        expect(find.text('Artist: Miles Davis'), findsOneWidget);

        // 9. Click on Playlists tab header in sidebar
        await tester.tap(find.text('Playlists').first);
        await tester.pumpAndSettle();
        expect(find.text('Playlists'), findsWidgets);
        expect(find.text('Audiophile Reference Master'), findsWidgets);

        // 10. Click a playlist card
        await tester.tap(find.text('Late Night Jazz').first);
        await tester.pumpAndSettle();

        // 11. Create a new playlist via New Playlist button
        final newPlaylistBtn = find.text('New Playlist');
        expect(newPlaylistBtn, findsOneWidget);
        await tester.tap(newPlaylistBtn);
        await tester.pumpAndSettle();

        // Verify new playlist was added
        expect(find.text('New Playlist 4'), findsWidgets);

        // 11b. Click on Tags tab
        await tester.tap(find.text('Tags').first);
        await tester.pumpAndSettle();
        expect(find.text('Tags'), findsWidgets);
        expect(find.text('Audiophile'), findsWidgets);

        // 12. Click on CAS Storage tab
        final sidebarScrollable = find.descendant(
          of: find.byType(LyraSidebar),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('CAS Storage').first,
          50.0,
          scrollable: sidebarScrollable,
        );
        await tester.tap(find.text('CAS Storage').first);
        await tester.pumpAndSettle();
        expect(find.text('Content Addressable Storage'), findsOneWidget);
        expect(find.text('TOTAL BLOBS'), findsOneWidget);

        // Verify blobs
        await tester.tap(find.text('Verify All Blobs'));
        await tester.pumpAndSettle();

        // 13. Click on Settings tab
        await tester.scrollUntilVisible(
          find.text('Settings').first,
          50.0,
          scrollable: sidebarScrollable,
        );
        await tester.tap(find.text('Settings').first);
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsWidgets);
        expect(find.text('Appearance'), findsOneWidget);

        // Toggle Theme
        await tester.tap(find.text('Zinc Light'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Zinc Dark'));
        await tester.pumpAndSettle();

        // 14. Open Import Audio Modal
        await tester.tap(find.text('Import Audio'));
        await tester.pumpAndSettle();
        expect(find.text('Import Audio to CAS Pool'), findsOneWidget);

        // Ingest audio
        await tester.tap(find.text('Ingest & Verify'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // 15. Player controls: Play, Pause, Next, Prev
        await tester.drag(sidebarScrollable, const Offset(0, 500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tracks'));
        await tester.pumpAndSettle();

        // Play track
        await tester.tap(
          find.text('Hotel California (Live on MTV 1994)').first,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Next track
        final skipForwardIcon = find.byIcon(LucideIcons.skipForward);
        expect(skipForwardIcon, findsOneWidget);
        await tester.tap(skipForwardIcon);
        await tester.pumpAndSettle();

        // Previous track
        final skipBackIcon = find.byIcon(LucideIcons.skipBack);
        expect(skipBackIcon, findsOneWidget);
        await tester.tap(skipBackIcon);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('Empty catalog handles all views with zero TypeErrors', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final emptyService = EmptyMusicService();
      await tester.pumpWidget(buildTestApp(musicService: emptyService));
      await tester.pumpAndSettle();

      // Tracks empty state
      expect(find.text('No tracks found'), findsOneWidget);
      expect(find.text('No track selected'), findsOneWidget);

      // Works empty state
      await tester.tap(find.text('Works'));
      await tester.pumpAndSettle();
      expect(find.text('No musical works found'), findsOneWidget);

      // Albums empty state
      await tester.tap(find.text('Albums').first);
      await tester.pumpAndSettle();
      expect(find.text('No albums found'), findsOneWidget);

      // Artists empty state
      await tester.tap(find.text('Artists').first);
      await tester.pumpAndSettle();
      expect(find.text('No artists found'), findsOneWidget);

      // Playlists empty state
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();
      expect(find.text('No playlists created yet'), findsOneWidget);

      // Create playlist on empty state
      await tester.tap(find.text('Create Playlist'));
      await tester.pumpAndSettle();

      // Tags empty state
      await tester.tap(find.text('Tags').first);
      await tester.pumpAndSettle();
      expect(find.text('No tags created yet'), findsOneWidget);
    });
  });
}
