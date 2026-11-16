// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/albums/album_detail_view.dart';
import 'package:ui/features/artists/artist_detail_view.dart';
import 'package:ui/features/models/album.dart';
import 'package:ui/features/models/artist.dart';
import 'package:ui/features/models/tag.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';
import 'package:ui/features/tags/tag_detail_view.dart';

Widget _wrapTestWidget(
  Widget child, {
  Brightness brightness = Brightness.dark,
}) {
  final isDark = brightness == Brightness.dark;
  final themeNotifier = ValueNotifier<ThemeMode>(
    isDark ? ThemeMode.dark : ThemeMode.light,
  );
  final tokens = isDark ? LyraThemeTokens.dark() : LyraThemeTokens.light();
  const factory = ShadcnFactory();
  final shadTheme = ShadThemeData(
    brightness: brightness,
    colorScheme: isDark
        ? const ShadZincColorScheme.dark()
        : const ShadZincColorScheme.light(),
  );

  return ShadApp(
    title: 'Entity Detail Views Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: tokens,
        themeModeNotifier: themeNotifier,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  final tracks = [
    const Track(
      id: 'trk-2',
      title: 'Blue in Green',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      durationMs: 327000,
      discNumber: 1,
      trackNumber: 2,
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
    ),
    const Track(
      id: 'trk-1',
      title: 'So What',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      durationMs: 562000,
      discNumber: 1,
      trackNumber: 1,
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
    ),
    const Track(
      id: 'trk-d2',
      title: 'Alternate Take',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      durationMs: 400000,
      discNumber: 2,
      trackNumber: 1,
      format: 'FLAC',
      sampleRate: 96000,
      bitDepth: 24,
    ),
  ];

  group('ArtistDetailView', () {
    final artist = Artist(
      id: 'art-1',
      name: 'Miles Davis',
      role: 'Trumpeter / Bandleader',
      createdAt: DateTime(2025, 11, 10),
    );
    final albums = [
      Album(
        id: 'alb-1',
        title: 'Kind of Blue',
        artistName: 'Miles Davis',
        releaseYear: 1959,
        releaseMonth: 8,
        releaseDay: 17,
        totalDiscs: 2,
        format: 'FLAC 24/96',
        createdAt: DateTime(2025, 11, 10),
      ),
      Album(
        id: 'alb-2',
        title: 'Sketches of Spain',
        artistName: 'Miles Davis',
        releaseYear: 1960,
        format: 'FLAC 24/96',
      ),
    ];

    testWidgets('renders artist metadata, horizontal albums shelf, and tracks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Album? tappedAlbum;
      var backPressed = false;
      final controller = PlaybackQueueController();

      await tester.pumpWidget(
        _wrapTestWidget(
          ArtistDetailView(
            artist: artist,
            albums: albums,
            tracks: tracks,
            playbackController: controller,
            onBack: () => backPressed = true,
            onAlbumSelected: (a) => tappedAlbum = a,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ARTIST'), findsOneWidget);
      expect(find.text('Miles Davis'), findsWidgets);
      expect(find.text('2 albums'), findsOneWidget);
      expect(find.text('3 tracks'), findsOneWidget);
      expect(find.text('Added 2025-11-10'), findsOneWidget);
      expect(find.byKey(const Key('artist_albums_shelf')), findsOneWidget);

      await tester.tap(find.byKey(const Key('artist_album_card_alb-1')));
      await tester.pumpAndSettle();
      expect(tappedAlbum?.id, 'alb-1');

      // Keyboard activation on album card works as well
      tappedAlbum = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tappedAlbum?.id, 'alb-1');

      await tester.tap(find.byKey(const Key('artist_play_all_button')).first);
      await tester.pumpAndSettle();
      expect(controller.currentTrack?.id, 'trk-2');

      await tester.tap(
        find.byKey(const Key('artist_detail_back_button')).first,
      );
      await tester.pumpAndSettle();
      expect(backPressed, isTrue);

      // Pump empty tree and dispose controller before FakeAsync invariant checks.
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    testWidgets(
      'hides album shelf cleanly and shows empty state at 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(600, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          _wrapTestWidget(
            ArtistDetailView(
              artist: artist,
              albums: const [],
              tracks: const [],
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('artist_albums_shelf')), findsNothing);
        expect(find.text('No tracks for this artist'), findsOneWidget);
      },
    );
  });

  group('AlbumDetailView', () {
    final album = Album(
      id: 'alb-1',
      title: 'Kind of Blue',
      artistName: 'Miles Davis',
      releaseYear: 1959,
      releaseMonth: 8,
      releaseDay: 17,
      totalDiscs: 2,
      format: 'FLAC 24/96',
      createdAt: DateTime(2025, 11, 10),
    );

    testWidgets(
      'renders album metadata, clickable artist link, and sorts tracks by disc and track number',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var artistTapped = false;

        await tester.pumpWidget(
          _wrapTestWidget(
            AlbumDetailView(
              album: album,
              tracks: tracks,
              onBack: () {},
              onArtistTap: () => artistTapped = true,
            ),
            brightness: Brightness.light,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ALBUM'), findsOneWidget);
        expect(find.text('Kind of Blue'), findsOneWidget);
        expect(find.text('1959-08-17'), findsOneWidget);
        expect(find.text('2 discs'), findsOneWidget);
        expect(find.text('3 tracks'), findsOneWidget);
        expect(find.text('FLAC 24/96'), findsOneWidget);
        expect(find.text('Added 2025-11-10'), findsOneWidget);

        // Verify canonical disc/track ordering: So What (d1t1) above Blue in Green (d1t2) above Alternate Take (d2t1)
        final soWhatTop = tester.getTopLeft(find.text('So What')).dy;
        final blueInGreenTop = tester.getTopLeft(find.text('Blue in Green')).dy;
        final altTakeTop = tester.getTopLeft(find.text('Alternate Take')).dy;
        expect(soWhatTop, lessThan(blueInGreenTop));
        expect(blueInGreenTop, lessThan(altTakeTop));

        await tester.tap(find.byKey(const Key('album_detail_subtitle_link')));
        await tester.pumpAndSettle();
        expect(artistTapped, isTrue);
      },
    );
  });

  group('TagDetailView', () {
    final tag = Tag(
      id: 'tag-1',
      name: 'Audiophile',
      category: 'quality',
      createdAt: DateTime(2025, 12, 2),
    );

    testWidgets(
      'renders tag metadata, created date, tracks, and Filter in Tracks button',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var filterTapped = false;

        await tester.pumpWidget(
          _wrapTestWidget(
            TagDetailView(
              tag: tag,
              tracks: tracks,
              onBack: () {},
              onFilterInTracks: () => filterTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('TAG'), findsOneWidget);
        expect(find.text('Audiophile'), findsOneWidget);
        expect(find.text('Category: quality'), findsOneWidget);
        expect(find.text('Created 2025-12-02'), findsOneWidget);
        expect(find.text('Filter in Tracks'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('tag_filter_in_tracks_button')).first,
        );
        await tester.pumpAndSettle();
        expect(filterTapped, isTrue);
      },
    );
  });
}
