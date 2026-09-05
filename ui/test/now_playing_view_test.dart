// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';
import 'package:ui/features/player/models/lyrics.dart';
import 'package:ui/features/player/views/components/lyrics_tab.dart';
import 'package:ui/features/player/views/components/media_viewport.dart';
import 'package:ui/features/player/views/components/song_artwork_card.dart';
import 'package:ui/features/player/views/components/up_next_tab.dart';
import 'package:ui/features/player/views/components/video_surface_card.dart';
import 'package:ui/features/player/views/now_playing_view.dart';
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

        // Top bar header
        expect(find.text('Now Playing'), findsOneWidget);
        expect(find.text('Collapse'), findsOneWidget);

        // Media Viewport in Song mode
        expect(find.byType(MediaViewport), findsOneWidget);
        expect(find.byType(SongArtworkCard), findsOneWidget);
        expect(find.byType(VideoSurfaceCard), findsNothing);

        // Track metadata rendered inside SongArtworkCard
        expect(find.text('Hotel California (Live on MTV 1994)'), findsWidgets);
        expect(find.text('Eagles'), findsWidgets);
        expect(find.text('Hell Freezes Over'), findsWidgets);

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
    });

    testWidgets('removes track from queue when clicking remove action', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(track1, contextQueue: [track1, track2, track3]);

      await tester.pumpWidget(
        _buildNowPlayingTest(playbackController: controller),
      );
      await tester.pumpAndSettle();

      expect(controller.queue.length, equals(3));

      // Tap remove (X icon) on the last track
      final removeButtons = find.byIcon(LucideIcons.x);
      expect(removeButtons, findsNWidgets(3));
      await tester.tap(removeButtons.last);
      await tester.pumpAndSettle();

      expect(controller.queue.length, equals(2));
      expect(controller.queue.contains(track3), isFalse);
    });

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

  group('SongArtworkCard - Secondary Controls', () {
    testWidgets(
      'shuffle toggle and repeat mode cycler update playback controller',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track1, contextQueue: [track1, track2]);

        await tester.pumpWidget(
          _buildNowPlayingTest(playbackController: controller),
        );
        await tester.pumpAndSettle();

        // 1. Shuffle toggle
        expect(controller.shuffleMode, isFalse);
        final shuffleBtn = find.byIcon(LucideIcons.shuffle).first;
        await tester.tap(shuffleBtn);
        await tester.pumpAndSettle();
        expect(controller.shuffleMode, isTrue);

        // 2. Repeat mode cycling: off -> all -> one -> off
        expect(controller.repeatMode, equals(RepeatMode.off));
        final repeatBtn = find.byIcon(LucideIcons.repeat);
        await tester.tap(repeatBtn);
        await tester.pumpAndSettle();
        expect(controller.repeatMode, equals(RepeatMode.all));

        await tester.tap(find.byIcon(LucideIcons.repeat));
        await tester.pumpAndSettle();
        expect(controller.repeatMode, equals(RepeatMode.one));
        expect(find.byIcon(LucideIcons.repeat1), findsOneWidget);

        await tester.tap(find.byIcon(LucideIcons.repeat1));
        await tester.pumpAndSettle();
        expect(controller.repeatMode, equals(RepeatMode.off));

        // 3. Favorite toggle
        final favoriteBtn = find.byIcon(LucideIcons.heart);
        expect(favoriteBtn, findsOneWidget);
        await tester.tap(favoriteBtn);
        await tester.pumpAndSettle();
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

        final splitColFinder = find
            .ancestor(of: mediaViewportFinder, matching: find.byType(Column))
            .first;
        final Column splitCol = tester.widget<Column>(splitColFinder);
        expect(splitCol.children.length, equals(3));
        final topExpanded = splitCol.children[0] as Expanded;
        final bottomExpanded = splitCol.children[2] as Expanded;
        expect(topExpanded.flex, equals(2));
        expect(bottomExpanded.flex, equals(1));
      },
    );
  });
}
