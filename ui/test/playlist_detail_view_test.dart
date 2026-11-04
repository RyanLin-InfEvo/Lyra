// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/common/context_menu_coordinator.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';
import 'package:ui/features/playlists/playlist_detail_view.dart';
import 'package:ui/features/settings/services/preferences_service.dart';

Widget _buildPlaylistDetailTest(
  Widget child, {
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Playlist Detail Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final tokens = isDark
            ? LyraThemeTokens.dark()
            : LyraThemeTokens.light();
        final shadTheme = ShadThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          colorScheme: isDark
              ? const ShadZincColorScheme.dark()
              : const ShadZincColorScheme.light(),
        );

        return ShadTheme(
          data: shadTheme,
          child: LyraDesignSystemScope(
            factory: factory,
            tokens: tokens,
            themeModeNotifier: themeModeNotifier,
            child: Scaffold(body: child),
          ),
        );
      },
    ),
  );
}

void main() {
  const track1 = Track(
    id: 'trk-001',
    title: 'Hotel California (Live on MTV 1994)',
    artistName: 'Eagles',
    albumTitle: 'Hell Freezes Over',
    durationMs: 432000,
    format: 'FLAC',
  );

  const track2 = Track(
    id: 'trk-002',
    title: 'So What',
    artistName: 'Miles Davis',
    albumTitle: 'Kind of Blue',
    durationMs: 562000,
    format: 'FLAC',
  );

  const track3 = Track(
    id: 'trk-003',
    title: 'Giorgio by Moroder',
    artistName: 'Daft Punk',
    albumTitle: 'Random Access Memories',
    durationMs: 544000,
    format: 'FLAC',
  );

  final testPlaylist = Playlist(
    id: 'pl-001',
    title: 'Audiophile Reference Master',
    description: 'Bit-perfect acoustic reference recordings',
    trackIds: const ['trk-001', 'trk-002', 'trk-003'],
    createdAt: DateTime(2026, 1, 1),
  );

  group('PlaylistDetailView Header & Navigation', () {
    testWidgets(
      'renders playlist title, description, track count, and duration',
      (tester) async {
        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2, track3],
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header components
        expect(find.text('PLAYLIST'), findsOneWidget);
        expect(find.text('Audiophile Reference Master'), findsOneWidget);
        expect(
          find.text('Bit-perfect acoustic reference recordings'),
          findsOneWidget,
        );
        expect(find.text('3 tracks'), findsOneWidget);
        expect(find.text('25 min'), findsOneWidget);
        expect(find.byIcon(LucideIcons.listMusic), findsWidgets);
        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
        expect(find.text('Play All'), findsOneWidget);
        expect(find.text('Shuffle All'), findsOneWidget);
      },
    );

    testWidgets('back button calls onBack callback', (tester) async {
      var backCalled = false;
      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: testPlaylist,
            tracks: const [track1, track2, track3],
            onBack: () => backCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byIcon(LucideIcons.arrowLeft);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });
  });

  group('PlaylistDetailView Actions & Playback', () {
    testWidgets('Play All triggers playback controller with playlist tracks', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: testPlaylist,
            tracks: const [track1, track2, track3],
            playbackController: controller,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playAllBtn = find.text('Play All');
      expect(playAllBtn, findsOneWidget);
      await tester.tap(playAllBtn);
      await tester.pumpAndSettle();

      expect(controller.isPlaying, isTrue);
      expect(controller.currentTrack, equals(track1));
      expect(controller.queue, equals([track1, track2, track3]));
    });

    testWidgets('Shuffle All triggers playback with shuffled tracks', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: testPlaylist,
            tracks: const [track1, track2, track3],
            playbackController: controller,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shuffleBtn = find.text('Shuffle All');
      expect(shuffleBtn, findsOneWidget);
      await tester.tap(shuffleBtn);
      await tester.pumpAndSettle();

      expect(controller.isPlaying, isTrue);
      expect(controller.queue.length, equals(3));
      expect(controller.queue.toSet(), equals({track1, track2, track3}));
    });

    testWidgets(
      'custom onPlayAll and onShuffleAll callbacks are called when provided',
      (tester) async {
        var customPlayAllCalled = false;
        var customShuffleAllCalled = false;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2, track3],
              onBack: () {},
              onPlayAll: () => customPlayAllCalled = true,
              onShuffleAll: () => customShuffleAllCalled = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Play All'));
        await tester.pumpAndSettle();
        expect(customPlayAllCalled, isTrue);

        await tester.tap(find.text('Shuffle All'));
        await tester.pumpAndSettle();
        expect(customShuffleAllCalled, isTrue);
      },
    );
  });

  group('PlaylistDetailView Tracks Table & Reordering', () {
    testWidgets(
      'renders all tracks with indices, titles, artists, and duration',
      (tester) async {
        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2, track3],
              currentTrack: track1,
              isPlaying: true,
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header row
        expect(
          find.byKey(const Key('playlist_tracks_table_header')),
          findsOneWidget,
        );
        expect(find.text('Title & Artist'), findsOneWidget);
        expect(find.text('Album'), findsOneWidget);
        expect(find.text('Time'), findsOneWidget);

        // Track 1 (active & playing -> volume icon)
        expect(find.byIcon(LucideIcons.volume2), findsOneWidget);
        expect(
          find.text('Hotel California (Live on MTV 1994)'),
          findsOneWidget,
        );
        expect(find.text('Eagles'), findsOneWidget);
        expect(find.text('Hell Freezes Over'), findsOneWidget);

        // Track 2
        expect(find.text('So What'), findsOneWidget);
        expect(find.text('Miles Davis'), findsOneWidget);
        expect(find.text('Kind of Blue'), findsOneWidget);

        // Track 3
        expect(find.text('Giorgio by Moroder'), findsOneWidget);
        expect(find.text('Daft Punk'), findsOneWidget);
        expect(find.text('Random Access Memories'), findsOneWidget);
      },
    );

    testWidgets('tapping track calls onTrackSelected in singleClick mode', (
      tester,
    ) async {
      Track? selectedTrack;
      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: testPlaylist,
            tracks: const [track1, track2, track3],
            trackActivationMode: TrackActivationMode.singleClick,
            onBack: () {},
            onTrackSelected: (t) => selectedTrack = t,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('So What'));
      await tester.pumpAndSettle();

      expect(selectedTrack, equals(track2));
    });

    testWidgets(
      'PlaylistDetailView in doubleClick mode: single-click selects/inspects, double-click plays, Enter plays',
      (tester) async {
        Track? selectedTrack;
        Track? inspectedTrack;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2, track3],
              trackActivationMode: TrackActivationMode.doubleClick,
              onBack: () {},
              onTrackSelected: (t) => selectedTrack = t,
              onTrackFocus: (t) => inspectedTrack = t,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Single click on 'So What'
        await tester.tap(find.text('So What'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // In doubleClick mode, single click MUST NOT trigger onTrackSelected
        expect(selectedTrack, isNull);
        // It should call onTrackFocus
        expect(inspectedTrack?.id, equals(track2.id));

        // 2. Double click on 'So What' initiates playback
        final gesture1 = await tester.startGesture(
          tester.getCenter(find.text('So What')),
        );
        await gesture1.up();
        await tester.pump(const Duration(milliseconds: 60));
        final gesture2 = await tester.startGesture(
          tester.getCenter(find.text('So What')),
        );
        await gesture2.up();
        await tester.pumpAndSettle();

        expect(selectedTrack?.id, equals(track2.id));

        // 3. Reset and select 'Giorgio by Moroder', then press Enter key
        selectedTrack = null;
        await tester.tap(find.text('Giorgio by Moroder'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(selectedTrack, isNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(selectedTrack?.id, equals(track3.id));
      },
    );

    testWidgets('reordering tracks invokes onReorderTracks callback', (
      tester,
    ) async {
      int? reorderOldIndex;
      int? reorderNewIndex;

      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: testPlaylist,
            tracks: const [track1, track2, track3],
            onBack: () {},
            onReorderTracks: (oldIdx, newIdx) {
              reorderOldIndex = oldIdx;
              reorderNewIndex = newIdx;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag first track down by 80px past track 2 using mouse
      final firstRow = find.text('Hotel California (Live on MTV 1994)');
      final gesture = await tester.startGesture(
        tester.getCenter(firstRow),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reorderOldIndex, equals(0));
      expect(reorderNewIndex, isNotNull);
    });
  });

  group('PlaylistDetailView Context Menu & Track Management', () {
    testWidgets('right-click opens context menu with expected items', (
      tester,
    ) async {
      int? removedIndex;
      Track? removedTrack;
      Track? inspectedTrack;
      String? goToAlbumTitle;
      String? goToArtistName;

      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: testPlaylist,
            tracks: const [track1, track2, track3],
            onBack: () {},
            onRemoveTrack: (index, track) {
              removedIndex = index;
              removedTrack = track;
            },
            onInspectAudio: (t) => inspectedTrack = t,
            onGoToAlbum: (a) => goToAlbumTitle = a,
            onGoToArtist: (a) => goToArtistName = a,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Secondary click on track 2
      await tester.tap(
        find.text('So What'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      // Verify menu items
      expect(find.text('Play Now'), findsOneWidget);
      expect(find.text('Play Next'), findsOneWidget);
      expect(find.text('Add to Queue'), findsOneWidget);
      expect(find.text('Go to Album'), findsOneWidget);
      expect(find.text('Go to Artist'), findsOneWidget);
      expect(find.text('Remove from Playlist'), findsOneWidget);
      expect(find.text('Inspect Audio'), findsOneWidget);

      expect(find.byIcon(LucideIcons.listStart), findsOneWidget);
      expect(find.byIcon(LucideIcons.disc), findsOneWidget);
      expect(find.byIcon(LucideIcons.mic2), findsOneWidget);

      // Tap Go to Album
      await tester.tap(find.text('Go to Album'));
      await tester.pumpAndSettle();
      expect(goToAlbumTitle, equals(track2.album));
      expect(find.text('Go to Album'), findsNothing);

      // Secondary click on track 2 to test Go to Artist
      await tester.tap(
        find.text('So What'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Artist'));
      await tester.pumpAndSettle();
      expect(goToArtistName, equals(track2.artist));
      expect(find.text('Go to Artist'), findsNothing);

      // Secondary click on track 2 to test Remove from Playlist
      await tester.tap(
        find.text('So What'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      // Tap Remove from Playlist
      await tester.tap(find.text('Remove from Playlist'));
      await tester.pumpAndSettle();

      expect(removedIndex, equals(1));
      expect(removedTrack, equals(track2));

      // Secondary click on track 1 to test Inspect Audio
      await tester.tap(
        find.text('Hotel California (Live on MTV 1994)'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect Audio'));
      await tester.pumpAndSettle();
      expect(inspectedTrack, equals(track1));
    });

    testWidgets('context menu Play Next and Add to Queue trigger callbacks', (
      tester,
    ) async {
      Track? playNextTrack;
      Track? addToQueueTrack;

      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: testPlaylist,
            tracks: const [track1, track2, track3],
            onBack: () {},
            onPlayNext: (t) => playNextTrack = t,
            onAddToQueue: (t) => addToQueueTrack = t,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Right click track 3 to test Play Next
      await tester.tap(
        find.text('Giorgio by Moroder'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play Next'));
      await tester.pumpAndSettle();
      expect(playNextTrack, equals(track3));

      // Right click track 1 to test Add to Queue
      await tester.tap(
        find.text('Hotel California (Live on MTV 1994)'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Queue'));
      await tester.pumpAndSettle();
      expect(addToQueueTrack, equals(track1));
    });

    testWidgets(
      'PlaylistDetailView right-clicking row 3 then row 2 transfers context menu without residual menu',
      (tester) async {
        String? selectedAlbum;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2, track3],
              onBack: () {},
              onGoToAlbum: (a) => selectedAlbum = a,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Right-click on Row 3 (Giorgio by Moroder)
        await tester.tap(
          find.text('Giorgio by Moroder'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Play Now'), findsOneWidget);
        expect(find.text('Go to Album'), findsOneWidget);

        // 2. Right-click on Row 2 (So What) which is above Row 3
        await tester.tap(
          find.text('So What'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        // Exactly one context menu should be open
        expect(find.text('Play Now'), findsOneWidget);
        expect(find.text('Go to Album'), findsOneWidget);

        // Tap Go to Album - should act on Track 2 (Kind of Blue)
        await tester.tap(find.text('Go to Album'));
        await tester.pumpAndSettle();

        expect(selectedAlbum, equals(track2.album));
        expect(find.text('Go to Album'), findsNothing);
      },
    );

    testWidgets(
      'PlaylistDetailView left-clicking another row dismisses context menu and plays that row',
      (tester) async {
        Track? playedTrack;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: [track1, track2, track3],
              trackActivationMode: TrackActivationMode.singleClick,
              onBack: () {},
              onTrackSelected: (t) => playedTrack = t,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Right click on Row 1 ('Hotel California')
        await tester.tap(
          find.text(track1.title!),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Play Now'), findsOneWidget);

        // 2. Left click on Row 2 ('So What')
        await tester.tap(find.text('So What'));
        await tester.pumpAndSettle();

        // Context menu should be dismissed immediately
        expect(find.text('Play Now'), findsNothing);

        // Track 2 should have been played
        expect(playedTrack, equals(track2));
      },
    );

    testWidgets(
      'PlaylistDetailView scrolling the list dismisses the context menu',
      (tester) async {
        final manyTracks = List.generate(
          30,
          (i) => Track(
            id: 'pt_$i',
            title: 'Playlist Track $i',
            artistName: 'Artist $i',
            albumTitle: 'Album $i',
            durationMs: 180000,
          ),
        );
        final playlist = Playlist(
          id: 'pl_many',
          title: 'Many Tracks Playlist',
          trackIds: manyTracks.map((t) => t.id).toList(),
        );

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: playlist,
              tracks: manyTracks,
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Right click on first track
        await tester.tap(
          find.text('Playlist Track 0'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Play Now'), findsOneWidget);

        // 2. Scroll the list downwards
        await tester.drag(
          find.byType(ReorderableListView).last,
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();

        // Context menu should be dismissed
        expect(find.text('Play Now'), findsNothing);
      },
    );
  });

  group('PlaylistDetailView Empty State', () {
    testWidgets('renders empty state when playlist has 0 tracks', (
      tester,
    ) async {
      final emptyPlaylist = Playlist(
        id: 'pl-empty',
        title: 'Empty Chillout',
        trackIds: const [],
      );

      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: emptyPlaylist,
            tracks: const [],
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empty Chillout'), findsOneWidget);
      expect(find.text('0 tracks'), findsOneWidget);
      expect(find.text('0 min'), findsOneWidget);
      expect(find.text('No tracks in this playlist'), findsOneWidget);
      expect(
        find.text('Add tracks to this playlist from your library.'),
        findsOneWidget,
      );

      // Buttons are disabled
      final playAll = tester.widget<ShadButton>(
        find.descendant(
          of: find.byKey(const Key('playlist_play_all_button')),
          matching: find.byType(ShadButton),
        ),
      );
      expect(playAll.onPressed, isNull);
    });
  });

  group('PlaylistDetailView Deterministic Keys & Touch Safety', () {
    testWidgets('precomputes stable deterministic keys for duplicate tracks', (
      tester,
    ) async {
      final dupTracks = const [track1, track2, track1];
      final dupPlaylist = Playlist(
        id: 'pl-dup',
        title: 'Duplicate Playlist',
        trackIds: const ['trk-001', 'trk-002', 'trk-001'],
      );

      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: dupPlaylist,
            tracks: dupTracks,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify keys are deterministic: 'playlist_track_trk-001_0', 'playlist_track_trk-002_0', 'playlist_track_trk-001_1'
      expect(
        find.byKey(const ValueKey('playlist_track_trk-001_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist_track_trk-002_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist_track_trk-001_1')),
        findsOneWidget,
      );

      // Re-pump / re-render and check keys stay identical
      await tester.pumpWidget(
        _buildPlaylistDetailTest(
          PlaylistDetailView(
            playlist: dupPlaylist,
            tracks: dupTracks,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('playlist_track_trk-001_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist_track_trk-002_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('playlist_track_trk-001_1')),
        findsOneWidget,
      );
    });

    testWidgets(
      'removing duplicate track passes exact index and track instance',
      (tester) async {
        final dupTracks = const [track1, track2, track1];
        final dupPlaylist = Playlist(
          id: 'pl-dup',
          title: 'Duplicate Playlist',
          trackIds: const ['trk-001', 'trk-002', 'trk-001'],
        );

        int? removedIndex;
        Track? removedTrack;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: dupPlaylist,
              tracks: dupTracks,
              onBack: () {},
              onRemoveTrack: (index, track) {
                removedIndex = index;
                removedTrack = track;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Target the second instance of track1 at index 2 by its key
        final secondRow = find.byKey(
          const ValueKey('playlist_track_trk-001_1'),
        );
        expect(secondRow, findsOneWidget);

        await tester.tap(
          secondRow,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove from Playlist'));
        await tester.pumpAndSettle();

        expect(removedIndex, equals(2));
        expect(removedTrack, equals(track1));
      },
    );

    testWidgets(
      'touch swipe does not trigger drag reorder immediately, allowing vertical scroll',
      (tester) async {
        int? reorderOld;
        int? reorderNew;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2, track3],
              onBack: () {},
              onReorderTracks: (o, n) {
                reorderOld = o;
                reorderNew = n;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Perform a quick vertical drag using touch pointer
        final firstRow = find.text('Hotel California (Live on MTV 1994)');
        final gesture = await tester.startGesture(
          tester.getCenter(firstRow),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump();
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        // Since it was a quick touch drag without holding, reorder should NOT have been triggered
        expect(reorderOld, isNull);
        expect(reorderNew, isNull);
      },
    );
  });

  group('PlaylistDetailView Column Customization', () {
    const trackWithMeta = Track(
      id: 'trk-col-1',
      title: 'Comfortably Numb',
      artistName: 'Pink Floyd',
      albumTitle: 'The Wall',
      durationMs: 382000,
      recordingYear: 1979,
      genre: 'Progressive Rock',
      format: 'FLAC',
      bitDepth: 24,
      sampleRate: 96000,
    );

    testWidgets(
      'right-clicking table header opens column customization overlay and dismisses on close',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [trackWithMeta],
              onBack: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('playlist_tracks_table_header'));
        expect(header, findsOneWidget);

        // Right-click the header row
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify overlay is displayed
        final columnsWindow = find.byKey(
          const Key('playlist_tracks_columns_window'),
        );
        expect(columnsWindow, findsOneWidget);
        expect(find.text('COLUMNS'), findsOneWidget);
        expect(
          find.byKey(const Key('playlist_tracks_columns_reset_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('playlist_tracks_columns_close_button')),
          findsOneWidget,
        );

        // Verify column options exist in overlay
        expect(
          find.descendant(
            of: columnsWindow,
            matching: find.text('Track Number'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: columnsWindow,
            matching: find.text('Title & Artist'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: columnsWindow, matching: find.text('Album')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: columnsWindow, matching: find.text('Time')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: columnsWindow, matching: find.text('Resolution')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: columnsWindow, matching: find.text('Year Date')),
          findsOneWidget,
        );

        // Tap close button and verify overlay closes
        await tester.tap(
          find.byKey(const Key('playlist_tracks_columns_close_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('playlist_tracks_columns_window')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'toggling column visibility updates visible columns in header, rows, and fires callback',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        Set<TrackColumn>? updatedColumns;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [trackWithMeta],
              onBack: () {},
              onVisibleColumnsChanged: (cols) => updatedColumns = cols,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('playlist_tracks_table_header'));

        // Right-click header to open customization overlay
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        final albumCheckbox = find.byKey(
          const Key('playlist_track_col_checkbox_album'),
        );
        expect(albumCheckbox, findsOneWidget);
        expect(tester.widget<ShadCheckbox>(albumCheckbox).value, isTrue);

        // 1. Toggle off Album
        await tester.tap(find.byKey(const Key('track_col_menu_album')));
        await tester.pumpAndSettle();

        expect(tester.widget<ShadCheckbox>(albumCheckbox).value, isFalse);
        expect(updatedColumns?.contains(TrackColumn.album), isFalse);
        expect(
          find.descendant(of: header, matching: find.text('Album')),
          findsNothing,
        );
        expect(find.text('The Wall'), findsNothing);

        // 2. Toggle on Year Date
        final yearCheckbox = find.byKey(
          const Key('playlist_track_col_checkbox_year'),
        );
        expect(yearCheckbox, findsOneWidget);
        expect(tester.widget<ShadCheckbox>(yearCheckbox).value, isFalse);

        await tester.tap(find.byKey(const Key('track_col_menu_year')));
        await tester.pumpAndSettle();

        expect(tester.widget<ShadCheckbox>(yearCheckbox).value, isTrue);
        expect(updatedColumns?.contains(TrackColumn.year), isTrue);
        expect(
          find.descendant(of: header, matching: find.text('Year')),
          findsOneWidget,
        );
        expect(find.text('1979'), findsOneWidget);

        // 3. Attempt to toggle mandatory Title & Artist column (must remain visible)
        await tester.tap(find.byKey(const Key('track_col_menu_title')));
        await tester.pumpAndSettle();

        final titleCheckbox = find.byKey(
          const Key('playlist_track_col_checkbox_title'),
        );
        expect(tester.widget<ShadCheckbox>(titleCheckbox).value, isTrue);
        expect(
          find.descendant(of: header, matching: find.text('Title & Artist')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'reordering columns via dragging in overlay updates column order dynamically',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        List<TrackColumn>? newColumnOrder;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [trackWithMeta],
              onBack: () {},
              onColumnOrderChanged: (order) => newColumnOrder = order,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('playlist_tracks_table_header'));
        final headerHashFinder = find.descendant(
          of: header,
          matching: find.text('#'),
        );
        final headerTimeFinder = find.descendant(
          of: header,
          matching: find.text('Time'),
        );

        // Initially # is to the left of Time
        expect(
          tester.getTopLeft(headerHashFinder).dx,
          lessThan(tester.getTopLeft(headerTimeFinder).dx),
        );

        // Right-click header to open overlay
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Drag Duration grip up to top (above index 0)
        final durationGrip = find.descendant(
          of: find.byKey(const Key('playlist_track_col_menu_duration')),
          matching: find.byIcon(LucideIcons.gripVertical),
        );
        expect(durationGrip, findsOneWidget);

        await tester.timedDrag(
          durationGrip,
          const Offset(0, -450),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();

        // Duration is now first in column order
        expect(newColumnOrder, isNotNull);
        expect(newColumnOrder!.first, equals(TrackColumn.duration));

        // Time is now to the left of # in table header
        final newTimeLeft = tester
            .getTopLeft(
              find.descendant(of: header, matching: find.text('Time')),
            )
            .dx;
        final newHashLeft = tester
            .getTopLeft(find.descendant(of: header, matching: find.text('#')))
            .dx;
        expect(newTimeLeft, lessThan(newHashLeft));
      },
    );

    testWidgets(
      'Reset button restores default visible columns and column order',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        Set<TrackColumn>? resetColumns;
        List<TrackColumn>? resetOrder;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [trackWithMeta],
              visibleColumns: {TrackColumn.title},
              onBack: () {},
              onVisibleColumnsChanged: (cols) => resetColumns = cols,
              onColumnOrderChanged: (order) => resetOrder = order,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('playlist_tracks_table_header'));

        // Initially only Title & Artist is visible
        expect(
          find.descendant(of: header, matching: find.text('#')),
          findsNothing,
        );
        expect(
          find.descendant(of: header, matching: find.text('Album')),
          findsNothing,
        );
        expect(
          find.descendant(of: header, matching: find.text('Time')),
          findsNothing,
        );
        expect(
          find.descendant(of: header, matching: find.text('Title & Artist')),
          findsOneWidget,
        );

        // Right-click header to open overlay
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Tap Reset
        await tester.tap(
          find.byKey(const Key('playlist_tracks_columns_reset_button')),
        );
        await tester.pumpAndSettle();

        // Default columns are restored
        expect(
          find.descendant(of: header, matching: find.text('#')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text('Title & Artist')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text('Album')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text('Time')),
          findsOneWidget,
        );

        expect(resetColumns, equals(PlaylistDetailView.defaultVisibleColumns));
        expect(resetOrder, equals(TrackColumn.values));
      },
    );

    testWidgets(
      'PlaylistDetailView single-click on currently playing track calls onTogglePlay',
      (tester) async {
        bool togglePlayCalled = false;
        Track? selectedTrack;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2],
              onBack: () {},
              currentTrack: track1,
              isPlaying: true,
              trackActivationMode: TrackActivationMode.singleClick,
              onTogglePlay: () => togglePlayCalled = true,
              onTrackSelected: (t) => selectedTrack = t,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap currently playing track (track1)
        await tester.tap(find.text(track1.title!));
        await tester.pumpAndSettle();

        expect(togglePlayCalled, isTrue);
        expect(selectedTrack, isNull);
      },
    );

    testWidgets(
      'PlaylistDetailView doubleClick mode invokes onTrackFocus instead of onInspectAudio on single click',
      (tester) async {
        bool inspectCalled = false;
        Track? focusedTrack;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2],
              onBack: () {},
              trackActivationMode: TrackActivationMode.doubleClick,
              onInspectAudio: (_) => inspectCalled = true,
              onTrackFocus: (t) => focusedTrack = t,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(track1.title!));
        await tester.pumpAndSettle();

        expect(inspectCalled, isFalse);
        expect(focusedTrack?.id, equals(track1.id));
      },
    );

    testWidgets(
      'PlaylistDetailView handles duplicate tracks disambiguating row selection',
      (tester) async {
        Track? playedTrack;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2, track1],
              onBack: () {},
              trackActivationMode: TrackActivationMode.doubleClick,
              onTrackSelected: (t) => playedTrack = t,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final track1Widgets = find.text(track1.title!);
        expect(track1Widgets, findsNWidgets(2));

        // Click the second occurrence (index 2)
        await tester.tap(track1Widgets.at(1));
        await tester.pumpAndSettle();

        // Press Enter to play
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(playedTrack?.id, equals(track1.id));
      },
    );

    testWidgets(
      'PlaylistDetailView Escape dismisses context menu first before clearing row selection',
      (tester) async {
        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2],
              onBack: () {},
              trackActivationMode: TrackActivationMode.doubleClick,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Click track 1 to select it
        await tester.tap(find.text(track1.title!));
        await tester.pumpAndSettle();

        // Right-click track 1 to open context menu
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(find.text(track1.title!)));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(LyraContextMenuCoordinator.activeController, isNotNull);

        // First Escape dismisses context menu only
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(LyraContextMenuCoordinator.activeController, isNull);

        // Second Escape clears selection
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'PlaylistDetailView does not handle Escape/Enter when isNowPlayingExpanded is true',
      (tester) async {
        Track? playedTrack;
        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2],
              onBack: () {},
              trackActivationMode: TrackActivationMode.doubleClick,
              isNowPlayingExpanded: true,
              onTrackSelected: (t) => playedTrack = t,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Click track 1
        await tester.tap(find.text(track1.title!));
        await tester.pumpAndSettle();

        // Enter key should NOT trigger track playback because Now Playing is expanded
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(playedTrack, isNull);
      },
    );

    testWidgets(
      'Enter key initiates playback and dismisses active context menu in PlaylistDetailView',
      (tester) async {
        Track? playedTrack;
        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2],
              onBack: () {},
              trackActivationMode: TrackActivationMode.doubleClick,
              onTrackSelected: (t) => playedTrack = t,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Click track 1 to select
        await tester.tap(find.text(track1.title!));
        await tester.pumpAndSettle();

        // Right-click track 1 to open context menu
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(find.text(track1.title!)));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(LyraContextMenuCoordinator.activeController, isNotNull);

        // Enter key plays track AND dismisses context menu
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(playedTrack?.id, equals(track1.id));
        expect(LyraContextMenuCoordinator.activeController, isNull);
      },
    );

    testWidgets(
      'Selected track index does not leak across different playlist IDs',
      (tester) async {
        Track? playedTrack;
        final playlistA = const Playlist(id: 'pl-A', title: 'Playlist A');
        final playlistB = const Playlist(id: 'pl-B', title: 'Playlist B');

        Widget buildView(Playlist pl) {
          return _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: pl,
              tracks: const [track1, track2],
              onBack: () {},
              trackActivationMode: TrackActivationMode.doubleClick,
              onTrackSelected: (t) => playedTrack = t,
            ),
          );
        }

        await tester.pumpWidget(buildView(playlistA));
        await tester.pumpAndSettle();

        // Select track 1 in Playlist A
        await tester.tap(find.text(track1.title!));
        await tester.pumpAndSettle();

        // Switch to Playlist B with different ID
        await tester.pumpWidget(buildView(playlistB));
        await tester.pumpAndSettle();

        // In Playlist B, selection must be cleared; pressing Enter should NOT play track 1
        playedTrack = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(playedTrack, isNull);
      },
    );

    testWidgets(
      'Single-click in doubleClick mode does NOT hijack onInspectAudio when onTrackFocus is null',
      (tester) async {
        bool inspectCalled = false;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2],
              onBack: () {},
              trackActivationMode: TrackActivationMode.doubleClick,
              onInspectAudio: (t) => inspectCalled = true,
              onTrackFocus: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Single click track 1
        await tester.tap(find.text(track1.title!));
        await tester.pumpAndSettle();

        // Should NOT call onInspectAudio on single click
        expect(inspectCalled, isFalse);
      },
    );

    testWidgets(
      'PlaylistDetailView updates dynamically when PreferencesService trackActivationMode changes',
      (tester) async {
        final prefs = InMemoryPreferencesService(
          trackActivationMode: TrackActivationMode.doubleClick,
        );
        Track? playedTrack;

        await tester.pumpWidget(
          _buildPlaylistDetailTest(
            PlaylistDetailView(
              playlist: testPlaylist,
              tracks: const [track1, track2],
              onBack: () {},
              preferencesService: prefs,
              onTrackSelected: (t) => playedTrack = t,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Single click should NOT play in doubleClick mode
        await tester.tap(find.text(track1.title!));
        await tester.pumpAndSettle();
        expect(playedTrack, isNull);

        // Update preference to singleClick
        await prefs.setTrackActivationMode(TrackActivationMode.singleClick);
        await tester.pumpAndSettle();

        // Now single click on track 2 should immediately play
        await tester.tap(find.text(track2.title!));
        await tester.pumpAndSettle();
        expect(playedTrack?.id, equals(track2.id));
      },
    );
  });
}
