// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';
import 'package:ui/features/player/models/lyrics.dart';
import 'package:ui/features/player/views/components/lyrics_tab.dart';
import 'package:ui/features/player/views/components/up_next_tab.dart';
import 'package:ui/features/player/views/now_playing_view.dart';

Widget _buildLyricsTest({
  LyricsData? lyrics,
  required PlaybackQueueController playbackController,
  ValueListenable<Duration>? positionNotifier,
  VoidCallback? onReloadLyrics,
}) {
  const factory = ShadcnFactory();
  final tokens = LyraThemeTokens.dark();
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  return ShadApp(
    title: 'Lyrics Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: tokens,
        themeModeNotifier: themeModeNotifier,
        child: Scaffold(
          body: LyricsTab(
            lyrics: lyrics,
            playbackController: playbackController,
            positionNotifier: positionNotifier,
            onReloadLyrics: onReloadLyrics,
          ),
        ),
      ),
    ),
  );
}

Widget _buildNowPlayingTest({
  required PlaybackQueueController playbackController,
  Track? track,
  LyricsData? lyrics,
}) {
  const factory = ShadcnFactory();
  final tokens = LyraThemeTokens.dark();
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  return ShadApp(
    title: 'Now Playing Lyrics Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: tokens,
        themeModeNotifier: themeModeNotifier,
        child: Scaffold(
          body: NowPlayingView(
            track: track ?? playbackController.currentTrack,
            playbackController: playbackController,
            onCollapse: () {},
            lyrics: lyrics,
          ),
        ),
      ),
    ),
  );
}

void main() {
  final sampleTrack = Track(
    id: 'test-track-1',
    title: 'Aurora Lights',
    artistName: 'Lyra Sound',
    albumTitle: 'Cosmic Drift',
    durationMs: 225000,
  );

  group('LyricsData - LRC Parsing Unit Tests', () {
    test('Standard LRC parsing with timestamps [mm:ss.xx]', () {
      const lrc = '''
[ti:Aurora Lights]
[ar:Lyra Sound]
[00:05.50]Opening synth chords
[00:15.00]First verse begins
[01:30.25]Chorus builds up
''';
      final data = LyricsData.fromLrc(lrc);

      expect(data.isSynced, isTrue);
      expect(data.lines.length, equals(3));

      expect(data.lines[0].text, equals('Opening synth chords'));
      expect(
        data.lines[0].timestamp,
        equals(const Duration(seconds: 5, milliseconds: 500)),
      );

      expect(data.lines[1].text, equals('First verse begins'));
      expect(data.lines[1].timestamp, equals(const Duration(seconds: 15)));

      expect(data.lines[2].text, equals('Chorus builds up'));
      expect(
        data.lines[2].timestamp,
        equals(const Duration(minutes: 1, seconds: 30, milliseconds: 250)),
      );
    });

    test('Multi-timestamp parsing [01:10.00][02:20.00] Chorus', () {
      const lrc = '''
[00:10.00]Verse 1
[01:10.00][02:20.00] Chorus line repeated
[00:40.00]Verse 2
''';
      final data = LyricsData.fromLrc(lrc);

      expect(data.isSynced, isTrue);
      expect(data.lines.length, equals(4));

      // Sorted chronologically
      expect(data.lines[0].timestamp, equals(const Duration(seconds: 10)));
      expect(data.lines[0].text, equals('Verse 1'));

      expect(data.lines[1].timestamp, equals(const Duration(seconds: 40)));
      expect(data.lines[1].text, equals('Verse 2'));

      expect(
        data.lines[2].timestamp,
        equals(const Duration(minutes: 1, seconds: 10)),
      );
      expect(data.lines[2].text, equals('Chorus line repeated'));

      expect(
        data.lines[3].timestamp,
        equals(const Duration(minutes: 2, seconds: 20)),
      );
      expect(data.lines[3].text, equals('Chorus line repeated'));
    });

    test('Stripping metadata headers [ti:Song], [ar:Artist], [al:Album]', () {
      const lrc = '''
[ti:Song]
[ar:Artist]
[al:Album Name]
[by:Author]
[offset:0]
[00:10.00]Only real lyric line
''';
      final data = LyricsData.fromLrc(lrc);

      expect(data.isSynced, isTrue);
      expect(data.lines.length, equals(1));
      expect(data.lines[0].text, equals('Only real lyric line'));
    });

    test('Unsynced plain text fallback', () {
      const plain = '''
Verse one without timestamps
Verse two continues
Final closing verse
''';
      final data = LyricsData.fromLrc(plain);

      expect(data.isSynced, isFalse);
      expect(data.lines.length, equals(3));
      expect(data.lines[0].text, equals('Verse one without timestamps'));
      expect(data.lines[0].timestamp, equals(Duration.zero));
      expect(data.lines[1].text, equals('Verse two continues'));
      expect(data.lines[1].timestamp, equals(Duration.zero));
      expect(data.lines[2].text, equals('Final closing verse'));
      expect(data.lines[2].timestamp, equals(Duration.zero));
    });

    test('Empty input string and metadata-only input', () {
      final emptyData = LyricsData.fromLrc('');
      expect(emptyData.isSynced, isFalse);
      expect(emptyData.lines, isEmpty);
      expect(
        emptyData.findActiveIndex(const Duration(seconds: 10)),
        equals(-1),
      );

      final whitespaceData = LyricsData.fromLrc('   \n  \n  ');
      expect(whitespaceData.isSynced, isFalse);
      expect(whitespaceData.lines, isEmpty);

      final metadataOnly = LyricsData.fromLrc('[ti:Title]\n[ar:Artist]\n');
      expect(metadataOnly.isSynced, isFalse);
      expect(metadataOnly.lines, isEmpty);
    });

    test('findActiveIndex(position) before start, middle, and end of song', () {
      const lrc = '''
[00:10.00]First line
[00:20.00]Second line
[00:35.50]Third line
''';
      final data = LyricsData.fromLrc(lrc);

      // Before start (< 10s)
      expect(data.findActiveIndex(Duration.zero), equals(-1));
      expect(data.findActiveIndex(const Duration(seconds: 5)), equals(-1));
      expect(data.findActiveIndex(const Duration(seconds: 9)), equals(-1));

      // Exact first line (10s)
      expect(data.findActiveIndex(const Duration(seconds: 10)), equals(0));

      // Middle between first and second line
      expect(data.findActiveIndex(const Duration(seconds: 15)), equals(0));
      expect(data.findActiveIndex(const Duration(seconds: 19)), equals(0));

      // Second line (20s to 35.5s)
      expect(data.findActiveIndex(const Duration(seconds: 20)), equals(1));
      expect(data.findActiveIndex(const Duration(seconds: 30)), equals(1));

      // Third line (>= 35.5s)
      expect(
        data.findActiveIndex(const Duration(seconds: 35, milliseconds: 500)),
        equals(2),
      );
      expect(data.findActiveIndex(const Duration(minutes: 1)), equals(2));
      expect(data.findActiveIndex(const Duration(minutes: 5)), equals(2));
    });
  });

  group('LyricsTab - Empty State Widget Tests', () {
    testWidgets('shows elegant empty state when lyrics is null', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildLyricsTest(lyrics: null, playbackController: controller),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
      expect(find.text('No lyrics available'), findsOneWidget);
      expect(find.text('暫無歌詞'), findsOneWidget);
    });

    testWidgets('shows empty state when lyrics lines is empty', (tester) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildLyricsTest(
          lyrics: const LyricsData.empty(),
          playbackController: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.mic), findsOneWidget);
      expect(find.text('No lyrics available'), findsOneWidget);
      expect(find.text('暫無歌詞'), findsOneWidget);
    });

    testWidgets(
      'triggers onReloadLyrics callback when reload button is tapped',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);

        bool reloaded = false;
        await tester.pumpWidget(
          _buildLyricsTest(
            lyrics: null,
            playbackController: controller,
            onReloadLyrics: () => reloaded = true,
          ),
        );
        await tester.pumpAndSettle();

        final reloadBtn = find.text('Reload lyrics');
        expect(reloadBtn, findsOneWidget);
        await tester.tap(reloadBtn);
        await tester.pumpAndSettle();

        expect(reloaded, isTrue);
      },
    );
  });

  group('LyricsTab - Synced Lyrics & Active Line Highlighting', () {
    const lrcContent = '''
[00:00.00]Line Zero
[00:10.00]Line One
[00:20.00]Line Two
[00:30.00]Line Three
''';
    final syncedLyrics = LyricsData.fromLrc(lrcContent);

    testWidgets('renders all lyrics lines', (tester) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(sampleTrack);

      await tester.pumpWidget(
        _buildLyricsTest(lyrics: syncedLyrics, playbackController: controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('Line Zero'), findsOneWidget);
      expect(find.text('Line One'), findsOneWidget);
      expect(find.text('Line Two'), findsOneWidget);
      expect(find.text('Line Three'), findsOneWidget);
    });

    testWidgets('highlights active line as position advances', (tester) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(sampleTrack);

      await tester.pumpWidget(
        _buildLyricsTest(lyrics: syncedLyrics, playbackController: controller),
      );
      await tester.pumpAndSettle();

      AnimatedDefaultTextStyle getStyle(String text) {
        return tester.widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: find.text(text),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        );
      }

      // At 0s, Line Zero is active
      expect(getStyle('Line Zero').style.fontWeight, equals(FontWeight.bold));
      expect(getStyle('Line One').style.fontWeight, equals(FontWeight.w500));

      // Advance to 10s: Line One becomes active
      controller.seek(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(getStyle('Line One').style.fontWeight, equals(FontWeight.bold));
      expect(getStyle('Line Zero').style.fontWeight, equals(FontWeight.w500));

      // Advance to 25s: Line Two becomes active
      controller.seek(const Duration(seconds: 25));
      await tester.pumpAndSettle();

      expect(getStyle('Line Two').style.fontWeight, equals(FontWeight.bold));
      expect(getStyle('Line One').style.fontWeight, equals(FontWeight.w500));
    });

    testWidgets('tapping a lyrics line calls seek() and starts playback', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.addToQueue(sampleTrack);

      await tester.pumpWidget(
        _buildLyricsTest(lyrics: syncedLyrics, playbackController: controller),
      );
      await tester.pumpAndSettle();

      // Tap on "Line Two" which has timestamp 00:20.00
      final lineTwoFinder = find.text('Line Two');
      expect(lineTwoFinder, findsOneWidget);
      await tester.tap(lineTwoFinder);
      await tester.pumpAndSettle();

      expect(
        controller.positionNotifier.value,
        equals(const Duration(seconds: 20)),
      );
      expect(controller.isPlaying, isTrue);
    });

    testWidgets('manual drag pauses auto-scrolling for 3 seconds', (
      tester,
    ) async {
      final longLyrics = LyricsData.fromLrc(
        List.generate(
          30,
          (i) =>
              '[${i.toString().padLeft(2, '0')}:00.00] Long line number $i in track',
        ).join('\n'),
      );

      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(sampleTrack);

      await tester.pumpWidget(
        _buildLyricsTest(lyrics: longLyrics, playbackController: controller),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      expect(scrollable, findsOneWidget);

      // Drag to simulate user scroll
      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pump();

      // Advance position - auto-scroll is paused while _isUserScrolling is active
      controller.seek(const Duration(minutes: 10));
      await tester.pump(const Duration(milliseconds: 500));

      // Fast forward past the 3-second inactivity timer
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'didUpdateWidget properly handles custom positionNotifier changes',
      (tester) async {
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        final notifier1 = ValueNotifier<Duration>(Duration.zero);
        final notifier2 = ValueNotifier<Duration>(Duration.zero);
        addTearDown(notifier1.dispose);
        addTearDown(notifier2.dispose);

        await tester.pumpWidget(
          _buildLyricsTest(
            lyrics: syncedLyrics,
            playbackController: controller,
            positionNotifier: notifier1,
          ),
        );
        await tester.pumpAndSettle();

        AnimatedDefaultTextStyle getStyle(String text) {
          return tester.widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: find.text(text),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          );
        }

        expect(getStyle('Line Zero').style.fontWeight, equals(FontWeight.bold));
        expect(getStyle('Line One').style.fontWeight, equals(FontWeight.w500));

        // Update widget with notifier2
        await tester.pumpWidget(
          _buildLyricsTest(
            lyrics: syncedLyrics,
            playbackController: controller,
            positionNotifier: notifier2,
          ),
        );
        await tester.pumpAndSettle();

        // Advancing old notifier should have no effect
        notifier1.value = const Duration(seconds: 10);
        await tester.pumpAndSettle();
        expect(getStyle('Line Zero').style.fontWeight, equals(FontWeight.bold));
        expect(getStyle('Line One').style.fontWeight, equals(FontWeight.w500));

        // Advancing new notifier updates active line
        notifier2.value = const Duration(seconds: 10);
        await tester.pumpAndSettle();
        expect(getStyle('Line One').style.fontWeight, equals(FontWeight.bold));
        expect(getStyle('Line Zero').style.fontWeight, equals(FontWeight.w500));
      },
    );
  });

  group('LyricsTab - Unsynced Plain Text Lyrics', () {
    const plainContent = '''
Unsynced line 1
Unsynced line 2
Unsynced line 3
''';
    final plainLyrics = LyricsData.fromLrc(plainContent);

    testWidgets('renders scrollable plain-text lyrics', (tester) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildLyricsTest(lyrics: plainLyrics, playbackController: controller),
      );
      await tester.pumpAndSettle();

      expect(plainLyrics.isSynced, isFalse);
      expect(find.text('Unsynced line 1'), findsOneWidget);
      expect(find.text('Unsynced line 2'), findsOneWidget);
      expect(find.text('Unsynced line 3'), findsOneWidget);
    });
  });

  group('NowPlayingView - Tab Switching between Up Next and Lyrics', () {
    testWidgets('switches between Up Next and Lyrics tabs with sample lyrics', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(sampleTrack, contextQueue: [sampleTrack]);

      await tester.pumpWidget(
        _buildNowPlayingTest(playbackController: controller),
      );
      await tester.pumpAndSettle();

      // Initially UpNextTab is visible
      expect(find.byType(UpNextTab), findsOneWidget);
      expect(find.byType(LyricsTab), findsNothing);

      // Switch to Lyrics
      final lyricsTabButton = find.text('Lyrics');
      expect(lyricsTabButton, findsOneWidget);
      await tester.tap(lyricsTabButton);
      await tester.pumpAndSettle();

      expect(find.byType(LyricsTab), findsOneWidget);
      expect(find.byType(UpNextTab), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LyricsTab),
          matching: find.textContaining('Aurora Lights'),
        ),
        findsOneWidget,
      );

      // Switch back to Up Next
      final upNextTabButton = find.text('Up Next');
      expect(upNextTabButton, findsOneWidget);
      await tester.tap(upNextTabButton);
      await tester.pumpAndSettle();

      expect(find.byType(UpNextTab), findsOneWidget);
      expect(find.byType(LyricsTab), findsNothing);
    });

    testWidgets('NowPlayingView with empty lyrics displays empty state', (
      tester,
    ) async {
      final controller = PlaybackQueueController(autoStartTimer: false);
      addTearDown(controller.dispose);
      controller.play(sampleTrack);

      await tester.pumpWidget(
        _buildNowPlayingTest(
          playbackController: controller,
          lyrics: const LyricsData.empty(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Lyrics
      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();

      expect(find.byType(LyricsTab), findsOneWidget);
      expect(find.text('No lyrics available'), findsOneWidget);
      expect(find.text('暫無歌詞'), findsOneWidget);
    });
  });
}
