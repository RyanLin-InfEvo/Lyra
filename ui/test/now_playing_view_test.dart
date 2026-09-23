// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/inspector/audio_inspector_drawer.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';
import 'package:ui/features/player/models/lyrics.dart';
import 'package:ui/features/player/views/components/lyrics_tab.dart';
import 'package:ui/features/player/views/components/media_viewport.dart';
import 'package:ui/features/player/views/components/song_artwork_card.dart';
import 'package:ui/features/player/views/components/up_next_tab.dart';
import 'package:ui/features/player/views/components/video_surface_card.dart';
import 'package:ui/features/player/views/now_playing_view.dart';
import 'package:ui/features/services/music_service.dart';
import 'package:ui/features/shell/player_bar.dart';

Widget _buildNowPlayingTest({
  required PlaybackQueueController playbackController,
  Track? track,
  VoidCallback? onCollapse,
  String? queueSource,
  ValueNotifier<ThemeMode>? themeNotifier,
  double? videoAspectRatio,
  Widget? customVideoPlayer,
  String? videoTag,
  LyricsData? lyrics,
  ValueNotifier<int>? selectedTabNotifier,
  MusicService? musicService,
  void Function(Track track)? onAddToPlaylist,
  void Function(Track track)? onInspectAudio,
  ValueChanged<String>? onGoToAlbum,
  ValueChanged<String>? onGoToArtist,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Test',
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
            child: Scaffold(
              body: NowPlayingView(
                track: track ?? playbackController.currentTrack,
                playbackController: playbackController,
                onCollapse: onCollapse ?? () {},
                queueSource: queueSource,
                videoAspectRatio: videoAspectRatio,
                customVideoPlayer: customVideoPlayer,
                videoTag: videoTag,
                lyrics: lyrics,
                selectedTabNotifier: selectedTabNotifier,
                musicService: musicService,
                onAddToPlaylist: onAddToPlaylist,
                onInspectAudio: onInspectAudio,
                onGoToAlbum: onGoToAlbum,
                onGoToArtist: onGoToArtist,
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildVideoCardTest({
  required Track? track,
  required PlaybackQueueController playbackController,
  double? aspectRatio,
  String? videoTag,
  Widget? customVideoPlayer,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();
  final tokens = LyraThemeTokens.dark();
  final shadTheme = ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadZincColorScheme.dark(),
  );

  return ShadApp(
    title: 'Lyra Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: tokens,
        themeModeNotifier: themeModeNotifier,
        child: Scaffold(
          body: Center(
            child: VideoSurfaceCard(
              track: track,
              playbackController: playbackController,
              aspectRatio: aspectRatio,
              videoTag: videoTag,
              customVideoPlayer: customVideoPlayer,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildPlayerBarTest({
  Track? currentTrack,
  bool isPlaying = false,
  bool isNowPlayingExpanded = false,
  VoidCallback? onExpandNowPlaying,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();
  final tokens = LyraThemeTokens.dark();
  final shadTheme = ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadZincColorScheme.dark(),
  );

  return ShadApp(
    title: 'Lyra Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: tokens,
        themeModeNotifier: themeModeNotifier,
        child: Scaffold(
          body: LyraPlayerBar(
            currentTrack: currentTrack,
            isPlaying: isPlaying,
            currentPosition: const Duration(seconds: 45),
            volume: 0.8,
            isNowPlayingExpanded: isNowPlayingExpanded,
            onTogglePlay: () {},
            onNext: () {},
            onPrevious: () {},
            onSeek: (_) {},
            onVolumeChanged: (_) {},
            onExpandNowPlaying: onExpandNowPlaying,
          ),
        ),
      ),
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
    sampleRate: 96000,
    bitDepth: 24,
    ytmId: 'BciS5krYL80',
    verified: true,
  );

  const track2 = Track(
    id: 'trk-002',
    title: 'So What',
    artistName: 'Miles Davis',
    albumTitle: 'Kind of Blue',
    durationMs: 562000,
    format: 'FLAC',
    sampleRate: 192000,
    bitDepth: 24,
    verified: true,
  );

  const track3 = Track(
    id: 'trk-003',
    title: 'Giorgio by Moroder',
    artistName: 'Daft Punk',
    albumTitle: 'Random Access Memories',
    durationMs: 544000,
    format: 'FLAC',
    sampleRate: 88200,
    bitDepth: 24,
    verified: true,
  );

  group('NowPlayingView - Song Mode & Metadata Display', () {
    testWidgets(
      'renders track title, artist, album, and SongArtworkCard by default',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // Zero top bar clutter - floating collapse button
        expect(find.text('Now Playing'), findsNothing);
        expect(find.text('Collapse'), findsOneWidget);

        // Media Viewport in Song mode
        expect(find.byType(MediaViewport), findsOneWidget);
        expect(find.byType(SongArtworkCard), findsOneWidget);
        expect(find.byType(VideoSurfaceCard), findsNothing);

        // Fallback disc icon in artwork
        expect(find.byIcon(LucideIcons.disc), findsOneWidget);
      },
    );
  });

  group('NowPlayingView - Song vs Video Mode Toggling', () {
    testWidgets('switches between SongArtworkCard and VideoSurfaceCard', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1, contextQueue: [track1, track2]);

      await tester.pumpWidget(
        _buildNowPlayingTest(playbackController: controller),
      );
      await tester.pumpAndSettle();

      // Initially in Song mode
      expect(find.byType(SongArtworkCard), findsOneWidget);
      expect(find.byType(VideoSurfaceCard), findsNothing);

      // Tap 'Video' segmented pill
      final videoTab = find.text('Video');
      expect(videoTab, findsOneWidget);
      await tester.tap(videoTab);
      await tester.pumpAndSettle();

      // Now in Video mode showing VideoSurfaceCard
      expect(find.byType(VideoSurfaceCard), findsOneWidget);
      expect(find.byType(SongArtworkCard), findsNothing);
      expect(find.text('MV 1080p'), findsOneWidget);
      expect(find.text('YouTube Music ID: BciS5krYL80'), findsOneWidget);

      // Tap 'Song' segmented pill to switch back
      final songTab = find.text('Song');
      expect(songTab, findsOneWidget);
      await tester.tap(songTab);
      await tester.pumpAndSettle();

      expect(find.byType(SongArtworkCard), findsOneWidget);
      expect(find.byType(VideoSurfaceCard), findsNothing);
    });

    testWidgets('displays preview badge when current track has no ytmId', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track2, contextQueue: [track2]);

      await tester.pumpWidget(
        _buildNowPlayingTest(playbackController: controller),
      );
      await tester.pumpAndSettle();

      // Video option shows Video (Preview)
      final videoPreviewTab = find.text('Video (Preview)');
      expect(videoPreviewTab, findsOneWidget);
      await tester.tap(videoPreviewTab);
      await tester.pumpAndSettle();

      expect(find.byType(VideoSurfaceCard), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(
        find.text(
          'No music video linked to this track. Showing preview theater surface.',
        ),
        findsOneWidget,
      );
    });
  });

  group('NowPlayingView - UpNextTab & Queue Interactions', () {
    testWidgets('renders queue tracks and plays selected track upon click', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1, contextQueue: [track1, track2, track3]);

      await tester.pumpWidget(
        _buildNowPlayingTest(
          playbackController: controller,
          queueSource: 'Playing from Album: Hell Freezes Over',
        ),
      );
      await tester.pumpAndSettle();

      // Queue header
      expect(find.text('Up next'), findsOneWidget);
      expect(
        find.text('3'),
        findsNWidgets(2),
      ); // Queue count badge & track 3 index
      expect(
        find.text('Playing from Album: Hell Freezes Over'),
        findsOneWidget,
      );

      // Active track has volume indicator
      expect(find.byIcon(LucideIcons.volume2), findsOneWidget);

      // Track 2 in the queue
      final track2Finder = find.text('So What');
      expect(track2Finder, findsOneWidget);

      // Click track 2 in queue
      await tester.tap(track2Finder);
      await tester.pumpAndSettle();

      // Current track switched to track 2
      expect(controller.currentTrack, equals(track2));
      expect(controller.currentIndex, equals(1));

      // Verify queue items are isolated within RepaintBoundary
      final track2Repaint = find.ancestor(
        of: track2Finder,
        matching: find.byType(RepaintBoundary),
      );
      expect(track2Repaint, findsWidgets);
    });

    testWidgets(
      'permanent remove x button and grip handles are no longer rendered in rows',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // Verify no permanent 'x' buttons or gripVertical icons exist in the row trailing areas
        expect(find.byIcon(LucideIcons.x), findsNothing);
        expect(find.byIcon(LucideIcons.gripVertical), findsNothing);

        // Verify clean duration display in the trailing area for each track in UpNextTab
        final upNextFinder = find.byType(UpNextTab);
        expect(
          find.descendant(
            of: upNextFinder,
            matching: find.text(track1.formattedDuration),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: upNextFinder,
            matching: find.text(track2.formattedDuration),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: upNextFinder,
            matching: find.text(track3.formattedDuration),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'right-clicking a row opens context menu with actions and removing from queue works',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        expect(controller.queue.length, equals(3));

        // Right-click on track 3
        final track3Finder = find.text('Giorgio by Moroder');
        await tester.tap(
          track3Finder,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        // Verify context menu items are present
        expect(find.text('Play Now'), findsOneWidget);
        expect(find.text('Play Next'), findsOneWidget);
        expect(find.text('Remove from Queue'), findsOneWidget);

        // Tap "Remove from Queue"
        await tester.tap(find.text('Remove from Queue'));
        await tester.pumpAndSettle();

        expect(controller.queue.length, equals(2));
        expect(controller.queue.contains(track3), isFalse);
      },
    );

    testWidgets(
      'context menu actions invoke playback controls and custom callbacks',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        Track? addedToPlaylistTrack;
        Track? inspectedTrack;

        await tester.pumpWidget(
          _buildNowPlayingTest(
            playbackController: controller,
            onAddToPlaylist: (track) => addedToPlaylistTrack = track,
            onInspectAudio: (track) => inspectedTrack = track,
          ),
        );
        await tester.pumpAndSettle();

        // Right click track 2 to test "Play Now"
        await tester.tap(
          find.text('So What'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(find.text('Play Now'), findsOneWidget);
        expect(find.text('Add to Playlist...'), findsOneWidget);
        expect(find.text('Inspect Audio...'), findsOneWidget);

        await tester.tap(find.text('Play Now'));
        await tester.pumpAndSettle();

        expect(controller.currentTrack, equals(track2));

        // Right click track 3 to test "Play Next"
        await tester.tap(
          find.text('Giorgio by Moroder'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Play Next'));
        await tester.pumpAndSettle();

        // After playNext on track3 (when current is track2), track3 is next after track2
        expect(controller.queue[1], equals(track2));
        expect(controller.queue[2], equals(track3));

        // Right click track 2 to test "Add to Playlist..."
        await tester.tap(
          find.text('So What'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add to Playlist...'));
        await tester.pumpAndSettle();
        expect(addedToPlaylistTrack, equals(track2));

        // Right click track 2 to test "Inspect Audio..."
        await tester.tap(
          find.text('So What'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inspect Audio...'));
        await tester.pumpAndSettle();
        expect(inspectedTrack, equals(track2));
      },
    );

    testWidgets(
      'UpNextTab context menu includes Go to Album and Go to Artist and triggers callbacks',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        String? goToAlbumTitle;
        String? goToArtistName;

        await tester.pumpWidget(
          _buildNowPlayingTest(
            playbackController: controller,
            onGoToAlbum: (a) => goToAlbumTitle = a,
            onGoToArtist: (a) => goToArtistName = a,
          ),
        );
        await tester.pumpAndSettle();

        // Right-click track 1
        await tester.tap(
          find.text(track1.displayTitle),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Go to Album'), findsOneWidget);
        expect(find.text('Go to Artist'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ShadContextMenu),
            matching: find.byIcon(LucideIcons.disc),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ShadContextMenu),
            matching: find.byIcon(LucideIcons.mic2),
          ),
          findsOneWidget,
        );

        // Tap Go to Album
        await tester.tap(find.text('Go to Album'));
        await tester.pumpAndSettle();
        expect(goToAlbumTitle, equals(track1.album));
        expect(find.text('Go to Album'), findsNothing);

        // Right-click again and tap Go to Artist
        await tester.tap(
          find.text(track1.displayTitle),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go to Artist'));
        await tester.pumpAndSettle();
        expect(goToArtistName, equals(track1.artist));
        expect(find.text('Go to Artist'), findsNothing);
      },
    );

    testWidgets(
      'UpNextTab right-clicking row 1 then row 2 transfers context menu without residual menu',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        String? selectedAlbum;

        await tester.pumpWidget(
          _buildNowPlayingTest(
            playbackController: controller,
            onGoToAlbum: (a) => selectedAlbum = a,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Right click on Row 3 (Giorgio by Moroder)
        await tester.tap(
          find.text('Giorgio by Moroder'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Play Now'), findsOneWidget);
        expect(find.text('Go to Album'), findsOneWidget);

        // 2. Right click on Row 2 (So What) which is above Row 3 without closing Row 3's menu first
        await tester.tap(
          find.text('So What'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        // Should have exactly one context menu open, no residual menu
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
      'UpNextTab left-clicking another row dismisses context menu and plays that row',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // 1. Right click on Row 3 (Giorgio by Moroder)
        await tester.tap(
          find.text('Giorgio by Moroder'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Play Now'), findsOneWidget);

        // 2. Left click on Row 2 (So What) which is unoccluded above Row 3
        await tester.tap(find.text('So What'));
        await tester.pumpAndSettle();

        // Context menu should be dismissed immediately
        expect(find.text('Play Now'), findsNothing);

        // Active queue item should be index 1 (track2)
        expect(controller.currentIndex, equals(1));
      },
    );

    testWidgets(
      'UpNextTab scrolling the queue list dismisses the context menu',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        final manyTracks = List.generate(
          30,
          (i) => Track(
            id: 'qi_$i',
            title: 'Queue Track $i',
            artistName: 'Artist $i',
            albumTitle: 'Album $i',
            durationMs: 180000,
          ),
        );
        controller.play(manyTracks[0], contextQueue: manyTracks);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // 1. Right click on first queue item
        await tester.tap(
          find.text('Queue Track 0'),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Play Now'), findsOneWidget);

        // 2. Scroll the queue list downwards
        await tester.drag(
          find.byType(ReorderableListView),
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();

        // Context menu should be dismissed
        expect(find.text('Play Now'), findsNothing);
      },
    );

    testWidgets('clears queue when clicking clear queue button', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1, contextQueue: [track1, track2]);

      await tester.pumpWidget(
        _buildNowPlayingTest(playbackController: controller),
      );
      await tester.pumpAndSettle();

      final clearBtn = find.byIcon(LucideIcons.trash2);
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(controller.queue, isEmpty);
      expect(find.text('Queue is empty'), findsOneWidget);
    });

    testWidgets(
      'queue items respond to mouse hover events with localized hover state',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        final track2Finder = find.text('So What');
        expect(track2Finder, findsOneWidget);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        // Hover over track 2 item
        await gesture.moveTo(tester.getCenter(track2Finder));
        await tester.pumpAndSettle();

        expect(track2Finder, findsOneWidget);

        // Hover exit
        await gesture.moveTo(Offset.zero);
        await tester.pumpAndSettle();

        expect(track2Finder, findsOneWidget);
      },
    );

    testWidgets(
      'whole-row dragging with movement >= 10px reorders queue in controller and view',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // Initial queue order: track1, track2, track3
        expect(controller.queue, equals([track1, track2, track3]));

        final track1PosBefore = tester.getTopLeft(
          find.text('Hotel California (Live on MTV 1994)'),
        );
        final track2PosBefore = tester.getTopLeft(find.text('So What'));
        expect(track1PosBefore.dy, lessThan(track2PosBefore.dy));

        // Drag the first item's row down past track2 (80px down)
        final start = tester.getCenter(
          find.text('Hotel California (Live on MTV 1994)'),
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: start);
        await gesture.down(start);
        await tester.pump();

        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 50));
        }

        await gesture.up();
        await tester.pumpAndSettle();

        // Queue order should now have track1 moved after track2
        expect(controller.queue, equals([track2, track1, track3]));

        // Verify visual coordinates updated in the widget tree
        final track1PosAfter = tester.getTopLeft(
          find.text('Hotel California (Live on MTV 1994)'),
        );
        final track2PosAfter = tester.getTopLeft(find.text('So What'));
        expect(track2PosAfter.dy, lessThan(track1PosAfter.dy));

        // Also test programmatic reorderQueue updates the view reactively
        controller.reorderQueue(0, 3);
        await tester.pumpAndSettle();

        expect(controller.queue.last, equals(track2));
        expect(find.text('So What'), findsOneWidget);
      },
    );

    testWidgets(
      'mouse dragging (movement >= 10px) initiates reordering drag and reorders queue',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        expect(controller.queue, equals([track1, track2, track3]));

        // Mouse drag track 1 down 80px (past track 2) in steps
        final start = tester.getCenter(
          find.text('Hotel California (Live on MTV 1994)'),
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: start);
        await gesture.down(start);
        await tester.pump();

        // Drag down exceeding the 10px slop threshold
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Release mouse button
        await gesture.up();
        await tester.pumpAndSettle();

        // Queue order should now have track1 moved after track2
        expect(controller.queue, equals([track2, track1, track3]));
      },
    );

    testWidgets(
      'mouse pointer movement under slop threshold (< 10px) triggers play onTap rather than drag',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2, track3]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        expect(controller.currentTrack, equals(track1));
        expect(controller.currentIndex, equals(0));

        // Perform a small mouse jitter (5px movement, which is < 10px slop threshold) on track 2
        final target = tester.getCenter(find.text('So What'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: target);
        await gesture.down(target);
        // Move by 5px (below 10px slop threshold)
        await gesture.moveBy(const Offset(0, 5));
        await tester.pump();
        // Release pointer
        await gesture.up();
        await tester.pumpAndSettle();

        // Queue order must NOT have changed
        expect(controller.queue, equals([track1, track2, track3]));

        // But onTap was triggered, so current track switched to track2!
        expect(controller.currentTrack, equals(track2));
        expect(controller.currentIndex, equals(1));
      },
    );

    testWidgets('drag listener is disabled when queue has single track', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1, contextQueue: [track1]);

      await tester.pumpWidget(
        _buildNowPlayingTest(playbackController: controller),
      );
      await tester.pumpAndSettle();

      final dragListenerFinder = find.byType(
        ThresholdReorderableDragStartListener,
      );
      expect(dragListenerFinder, findsOneWidget);
      final ThresholdReorderableDragStartListener dragListener = tester.widget(
        dragListenerFinder,
      );
      expect(dragListener.enabled, isFalse);
    });

    testWidgets(
      'tapping a duplicate track in UpNextTab selects that exact index without resetting _queueItemIds',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        // Queue with duplicate track1 at index 0 and index 2: [track1, track2, track1]
        controller.play(track1, contextQueue: [track1, track2, track1]);
        expect(controller.currentIndex, equals(0));

        final initialItemIds = List<String>.from(controller.queueItemIds);
        expect(initialItemIds.length, equals(3));
        expect(initialItemIds[0], isNot(equals(initialItemIds[2])));

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // Target the second instance of track1 in the queue (index 2)
        final secondTrack1Row = find.byKey(
          ValueKey('queue_item_${initialItemIds[2]}'),
        );
        expect(secondTrack1Row, findsOneWidget);

        // Tap the second instance of track1 in the queue (index 2)
        await tester.tap(secondTrack1Row);
        await tester.pumpAndSettle();

        // Verify currentIndex moved directly to index 2, not resetting to index 0
        expect(controller.currentIndex, equals(2));
        expect(controller.currentTrack, equals(track1));

        // Verify queueItemIds were preserved and not regenerated
        expect(controller.queueItemIds, equals(initialItemIds));

        // Test context menu "Play Now" on the first instance of track1 (index 0)
        final firstTrack1Row = find.byKey(
          ValueKey('queue_item_${initialItemIds[0]}'),
        );
        await tester.tap(
          firstTrack1Row,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();

        expect(find.text('Play Now'), findsOneWidget);
        await tester.tap(find.text('Play Now'));
        await tester.pumpAndSettle();

        expect(controller.currentIndex, equals(0));
        expect(controller.queueItemIds, equals(initialItemIds));
      },
    );
  });

  group('NowPlayingView - Tab Switching to Lyrics', () {
    testWidgets('switches between Up Next and Lyrics tabs', (tester) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1, contextQueue: [track1]);

      await tester.pumpWidget(
        _buildNowPlayingTest(playbackController: controller),
      );
      await tester.pumpAndSettle();

      // Switch to Lyrics tab
      final lyricsTab = find.text('Lyrics');
      expect(lyricsTab, findsOneWidget);
      await tester.tap(lyricsTab);
      await tester.pumpAndSettle();

      // Shows LyricsTab with sample lyrics
      expect(find.byType(LyricsTab), findsOneWidget);
      expect(find.byType(UpNextTab), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LyricsTab),
          matching: find.textContaining('Hotel California'),
        ),
        findsOneWidget,
      );

      // Switch back to Up Next
      final upNextTab = find.text('Up Next');
      expect(upNextTab, findsOneWidget);
      await tester.tap(upNextTab);
      await tester.pumpAndSettle();

      expect(find.byType(UpNextTab), findsOneWidget);
      expect(find.byType(LyricsTab), findsNothing);
    });
  });

  group('NowPlayingView - Tab Switching to Details / Inspector', () {
    testWidgets('switches to Details tab and renders AudioInspectorContent', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1, contextQueue: [track1]);

      await tester.pumpWidget(
        _buildNowPlayingTest(playbackController: controller),
      );
      await tester.pumpAndSettle();

      // Details tab button is present in right-side segmented pill switcher
      final detailsTab = find.text('Details');
      expect(detailsTab, findsOneWidget);

      // Tap Details tab
      await tester.tap(detailsTab);
      await tester.pumpAndSettle();

      // Displays AudioInspectorContent starting cleanly below tab header without blank vertical gap
      expect(find.byType(AudioInspectorContent), findsOneWidget);
      expect(find.byType(UpNextTab), findsNothing);
      expect(find.byType(LyricsTab), findsNothing);

      final inspectorTop = tester
          .getTopLeft(find.byType(AudioInspectorContent))
          .dy;
      final detailsTabTop = tester.getTopLeft(detailsTab).dy;
      expect(inspectorTop - detailsTabTop, lessThan(50.0));

      // Shows technical info from track
      expect(find.text('24-bit/96kHz'), findsOneWidget);
      expect(find.text('Audio Specifications'), findsOneWidget);
    });

    testWidgets('external selectedTabNotifier controls active tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1, contextQueue: [track1]);

      final tabNotifier = ValueNotifier<int>(0);
      addTearDown(tabNotifier.dispose);

      await tester.pumpWidget(
        _buildNowPlayingTest(
          playbackController: controller,
          selectedTabNotifier: tabNotifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UpNextTab), findsOneWidget);
      expect(find.byType(AudioInspectorContent), findsNothing);

      // Programmatically switch to Details tab (index 2) via notifier
      tabNotifier.value = 2;
      await tester.pumpAndSettle();

      expect(find.byType(AudioInspectorContent), findsOneWidget);
      expect(find.byType(UpNextTab), findsNothing);
    });
  });

  group('NowPlayingView - Collapse & Keyboard Escape', () {
    testWidgets('invokes onCollapse when collapse button is tapped', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1);

      bool collapsed = false;
      await tester.pumpWidget(
        _buildNowPlayingTest(
          playbackController: controller,
          onCollapse: () => collapsed = true,
        ),
      );
      await tester.pumpAndSettle();

      final collapseBtn = find.text('Collapse');
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      expect(collapsed, isTrue);
    });

    testWidgets('invokes onCollapse when Escape keyboard key is pressed', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1);

      bool collapsed = false;
      await tester.pumpWidget(
        _buildNowPlayingTest(
          playbackController: controller,
          onCollapse: () => collapsed = true,
        ),
      );
      await tester.pumpAndSettle();

      // Send Escape key event
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(collapsed, isTrue);
    });
  });

  group('PlayerBar - Expand Now Playing Integration', () {
    testWidgets('invokes onExpandNowPlaying when chevronUp button is tapped', (
      tester,
    ) async {
      bool expanded = false;
      await tester.pumpWidget(
        _buildPlayerBarTest(
          currentTrack: track1,
          isPlaying: true,
          onExpandNowPlaying: () => expanded = true,
        ),
      );
      await tester.pumpAndSettle();

      final expandBtn = find.byIcon(LucideIcons.chevronUp);
      expect(expandBtn, findsOneWidget);
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      expect(expanded, isTrue);
    });

    testWidgets(
      'invokes onExpandNowPlaying when track title or album art is clicked',
      (tester) async {
        int expandCalls = 0;
        await tester.pumpWidget(
          _buildPlayerBarTest(
            currentTrack: track1,
            isPlaying: true,
            onExpandNowPlaying: () => expandCalls++,
          ),
        );
        await tester.pumpAndSettle();

        // Tap album art
        final albumArtSquare = find.byIcon(LucideIcons.music).first;
        await tester.tap(albumArtSquare);
        await tester.pumpAndSettle();
        expect(expandCalls, equals(1));

        // Tap track title
        final titleText = find.text('Hotel California (Live on MTV 1994)');
        await tester.tap(titleText);
        await tester.pumpAndSettle();
        expect(expandCalls, equals(2));
      },
    );

    testWidgets(
      'displays chevronDown and Collapse tooltip when isNowPlayingExpanded is true',
      (tester) async {
        await tester.pumpWidget(
          _buildPlayerBarTest(
            currentTrack: track1,
            isPlaying: true,
            isNowPlayingExpanded: true,
            onExpandNowPlaying: () {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(LucideIcons.chevronDown), findsOneWidget);
        expect(find.byIcon(LucideIcons.chevronUp), findsNothing);
        expect(find.byTooltip('Collapse Now Playing'), findsOneWidget);
      },
    );
  });

  group('SongArtworkCard - Artwork Presentation', () {
    testWidgets(
      'renders square album art presentation card with disc fallback',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // 1. SongArtworkCard is present
        expect(find.byType(SongArtworkCard), findsOneWidget);
        expect(find.byIcon(LucideIcons.disc), findsOneWidget);

        // 2. Secondary buttons under artwork are removed
        expect(find.byIcon(LucideIcons.heart), findsNothing);
      },
    );
  });

  group('VideoSurfaceCard - Dynamic Aspect Ratios & Theater Viewport', () {
    testWidgets('adapts to 4:3 classic MV ratio and displays MV 4:3 tag', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1);

      await tester.pumpWidget(
        _buildVideoCardTest(
          track: track1,
          playbackController: controller,
          aspectRatio: 4 / 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VideoSurfaceCard), findsOneWidget);
      expect(find.text('MV 4:3'), findsOneWidget);

      final aspectRatioFinder = find.byType(AspectRatio);
      expect(aspectRatioFinder, findsOneWidget);
      final AspectRatio aspectRatioWidget = tester.widget(aspectRatioFinder);
      expect(aspectRatioWidget.aspectRatio, closeTo(4 / 3, 0.001));
    });

    testWidgets(
      'adapts to 21:9 cinemascope MV ratio and displays MV 21:9 tag',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1);

        await tester.pumpWidget(
          _buildVideoCardTest(
            track: track1,
            playbackController: controller,
            aspectRatio: 21 / 9,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoSurfaceCard), findsOneWidget);
        expect(find.text('MV 21:9'), findsOneWidget);

        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final AspectRatio aspectRatioWidget = tester.widget(aspectRatioFinder);
        expect(aspectRatioWidget.aspectRatio, closeTo(21 / 9, 0.001));
      },
    );

    testWidgets('adapts to 9:16 vertical MV ratio and displays MV 9:16 tag', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1);

      await tester.pumpWidget(
        _buildVideoCardTest(
          track: track1,
          playbackController: controller,
          aspectRatio: 9 / 16,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VideoSurfaceCard), findsOneWidget);
      expect(find.text('MV 9:16'), findsOneWidget);

      final aspectRatioFinder = find.byType(AspectRatio);
      expect(aspectRatioFinder, findsOneWidget);
      final AspectRatio aspectRatioWidget = tester.widget(aspectRatioFinder);
      expect(aspectRatioWidget.aspectRatio, closeTo(9 / 16, 0.001));

      // Check rendered constraints do not exceed maxHeight 460
      final Size cardSize = tester.getSize(aspectRatioFinder);
      expect(cardSize.height, lessThanOrEqualTo(460.0));
      expect(cardSize.width, closeTo(cardSize.height * (9 / 16), 0.5));
    });

    testWidgets(
      'renders customVideoPlayer fitted inside letterboxed canvas with BoxFit.contain',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1);

        const customPlayer = SizedBox(
          key: ValueKey('custom_player_surface'),
          width: 640,
          height: 480,
        );

        await tester.pumpWidget(
          _buildVideoCardTest(
            track: track1,
            playbackController: controller,
            customVideoPlayer: customPlayer,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('custom_player_surface')),
          findsOneWidget,
        );
        final fittedBoxFinder = find.ancestor(
          of: find.byKey(const ValueKey('custom_player_surface')),
          matching: find.byType(FittedBox),
        );
        expect(fittedBoxFinder, findsOneWidget);
        final FittedBox fittedBox = tester.widget(fittedBoxFinder);
        expect(fittedBox.fit, equals(BoxFit.contain));
      },
    );

    testWidgets('respects explicit custom videoTag override', (tester) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1);

      await tester.pumpWidget(
        _buildVideoCardTest(
          track: track1,
          playbackController: controller,
          aspectRatio: 16 / 9,
          videoTag: '4K HDR',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4K HDR'), findsOneWidget);
    });

    testWidgets(
      'NowPlayingView propagates videoAspectRatio to VideoSurfaceCard',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1);

        await tester.pumpWidget(
          _buildNowPlayingTest(
            playbackController: controller,
            videoAspectRatio: 4 / 3,
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Video mode
        await tester.tap(find.text('Video'));
        await tester.pumpAndSettle();

        expect(find.byType(VideoSurfaceCard), findsOneWidget);
        expect(find.text('MV 4:3'), findsOneWidget);

        final AspectRatio aspectRatioWidget = tester.widget(
          find.byType(AspectRatio),
        );
        expect(aspectRatioWidget.aspectRatio, closeTo(4 / 3, 0.001));
      },
    );
  });

  group('NowPlayingView - 2:1 Responsive Split View Ratio', () {
    testWidgets(
      'verifies 2:1 ratio for wide screen split-view and narrow screen stacked view',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1);

        // 1. Wide Screen (Desktop Split-View)
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        final mediaViewportFinder = find.byType(MediaViewport);
        expect(mediaViewportFinder, findsOneWidget);

        final splitRowFinder = find
            .ancestor(of: mediaViewportFinder, matching: find.byType(Row))
            .first;
        final Row splitRow = tester.widget<Row>(splitRowFinder);
        expect(splitRow.children.length, equals(3));
        final leftExpanded = splitRow.children[0] as Expanded;
        final rightExpanded = splitRow.children[2] as Expanded;
        expect(leftExpanded.flex, equals(2));
        expect(rightExpanded.flex, equals(1));

        // 2. Narrow Screen (Stacked Column)
        tester.view.physicalSize = const Size(600, 800);
        await tester.pumpAndSettle();

        final splitColFinder = find.byKey(
          const ValueKey('now_playing_split_column'),
        );
        final Column splitCol = tester.widget<Column>(splitColFinder);
        expect(splitCol.children.length, equals(3));
        final topExpanded = splitCol.children[0] as Expanded;
        final bottomExpanded = splitCol.children[2] as Expanded;
        expect(topExpanded.flex, equals(2));
        expect(bottomExpanded.flex, equals(1));
      },
    );

    testWidgets(
      'switches between UpNext and Lyrics tabs via AnimatedSwitcher without errors',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.addAllToQueue([track1, track2]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // Initially Up Next tab is selected
        expect(find.byType(UpNextTab), findsOneWidget);
        expect(find.byType(LyricsTab), findsNothing);

        // Tap shuffle button (uses closure)
        await tester.tap(find.byIcon(LucideIcons.shuffle).first);
        await tester.pumpAndSettle();
        expect(controller.shuffleMode, isTrue);

        // Switch to Lyrics tab
        await tester.tap(find.text('Lyrics'));
        await tester.pumpAndSettle();

        expect(find.byType(LyricsTab), findsOneWidget);
        expect(find.byType(UpNextTab), findsNothing);

        // Switch back to Up Next tab
        await tester.tap(find.text('Up Next'));
        await tester.pumpAndSettle();

        expect(find.byType(UpNextTab), findsOneWidget);
        expect(find.byType(LyricsTab), findsNothing);
      },
    );
  });
}
