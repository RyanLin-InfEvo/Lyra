// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/core/models/waveform_data.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/inspector/audio_inspector_drawer.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/player/controllers/playback_queue_controller.dart';
import 'package:ui/features/player/views/components/waveform_scrubber.dart';
import 'package:ui/features/player/views/now_playing_view.dart';
import 'package:ui/features/services/mock_music_service.dart';

Widget _buildScrubberTest({
  WaveformData? waveform,
  PlaybackQueueController? playbackController,
  Duration? position,
  Duration? duration,
  ValueChanged<Duration>? onSeek,
  double height = 64.0,
  bool showTimeLabels = true,
  bool isInteractive = true,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Waveform Scrubber Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        const tokens = LyraThemeTokens(
          isDark: true,
          background: LyraColors.zinc950,
          foreground: LyraColors.zinc50,
          card: LyraColors.zinc900,
          cardForeground: LyraColors.zinc50,
          border: LyraColors.zinc700,
          text: LyraColors.zinc50,
          textMuted: LyraColors.zinc400,
          primary: LyraColors.zinc50,
          primaryForeground: LyraColors.zinc900,
          secondary: LyraColors.zinc800,
          secondaryForeground: LyraColors.zinc50,
          muted: LyraColors.zinc800,
          mutedForeground: LyraColors.zinc400,
          accent: LyraColors.zinc800,
          accentForeground: LyraColors.zinc50,
          destructive: LyraColors.red500,
          destructiveForeground: LyraColors.zinc50,
          ring: LyraColors.zinc400,
          success: LyraColors.emerald500,
          successForeground: LyraColors.emerald950,
          warning: LyraColors.amber500,
          warningForeground: LyraColors.amber950,
        );

        return LyraDesignSystemScope(
          factory: factory,
          tokens: tokens,
          themeModeNotifier: themeModeNotifier,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400.0,
                child: WaveformScrubber(
                  waveform: waveform,
                  playbackController: playbackController,
                  position: position,
                  duration: duration,
                  onSeek: onSeek,
                  height: height,
                  showTimeLabels: showTimeLabels,
                  isInteractive: isInteractive,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WaveformScrubber Component', () {
    testWidgets('renders loading skeleton when waveform is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScrubberTest(
          waveform: null,
          position: const Duration(seconds: 10),
          duration: const Duration(seconds: 100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WaveformScrubber), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('0:10'), findsOneWidget);
      expect(find.text('1:40'), findsOneWidget);
    });

    testWidgets('renders waveform bars with valid waveform data', (
      tester,
    ) async {
      final wf = WaveformData.mock(pcmHash: 'test-hash', points: 60);

      await tester.pumpWidget(
        _buildScrubberTest(
          waveform: wf,
          position: const Duration(seconds: 30),
          duration: const Duration(seconds: 120),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WaveformScrubber), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('2:00'), findsOneWidget);
    });

    testWidgets('tapping directly on waveform seeks to target position', (
      tester,
    ) async {
      Duration? seekTarget;
      final wf = WaveformData.mock(pcmHash: 'seek-hash', points: 50);

      await tester.pumpWidget(
        _buildScrubberTest(
          waveform: wf,
          position: Duration.zero,
          duration: const Duration(seconds: 200),
          onSeek: (pos) => seekTarget = pos,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Find scrubber container and tap at 50% width
      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      final topLeft = tester.getTopLeft(gestureFinder);
      final size = tester.getSize(gestureFinder);

      // Tap in the middle (50% progress -> ~100s)
      await tester.tapAt(
        Offset(topLeft.dx + size.width * 0.5, topLeft.dy + size.height * 0.5),
      );
      await tester.pump();

      expect(seekTarget, isNotNull);
      expect(seekTarget!.inSeconds, closeTo(100, 2));
    });

    testWidgets('dragging along waveform continuously previews and seeks', (
      tester,
    ) async {
      Duration? lastSeek;
      final wf = WaveformData.mock(pcmHash: 'drag-hash', points: 50);

      await tester.pumpWidget(
        _buildScrubberTest(
          waveform: wf,
          position: Duration.zero,
          duration: const Duration(seconds: 100),
          onSeek: (pos) => lastSeek = pos,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final gestureFinder = find.byType(GestureDetector);
      final topLeft = tester.getTopLeft(gestureFinder);
      final size = tester.getSize(gestureFinder);

      // Drag from 25% to 75%
      final start = Offset(
        topLeft.dx + size.width * 0.25,
        topLeft.dy + size.height * 0.5,
      );
      final end = Offset(
        topLeft.dx + size.width * 0.75,
        topLeft.dy + size.height * 0.5,
      );

      final gesture = await tester.startGesture(start);
      await tester.pump();
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(lastSeek, isNotNull);
      expect(lastSeek!.inSeconds, closeTo(75, 2));
    });

    testWidgets('integrates seamlessly with PlaybackQueueController', (
      tester,
    ) async {
      final controller = PlaybackQueueController();
      const track = Track(
        id: 'trk-test',
        title: 'Waveform Track',
        artistName: 'Test Artist',
        albumTitle: 'Test Album',
        durationMs: 180000,
        bitDepth: 24,
        sampleRate: 96000,
        format: 'FLAC',
        pcmHash: 'pcm-test',
        verified: true,
      );

      controller.play(track);
      final wf = WaveformData.mock(pcmHash: 'pcm-test', points: 60);

      await tester.pumpWidget(
        _buildScrubberTest(waveform: wf, playbackController: controller),
      );
      await tester.pump();

      expect(find.text('3:00'), findsOneWidget);

      // Tap at 25% of scrubber width
      final gestureFinder = find.byType(GestureDetector);
      final topLeft = tester.getTopLeft(gestureFinder);
      final size = tester.getSize(gestureFinder);

      await tester.tapAt(
        Offset(topLeft.dx + size.width * 0.25, topLeft.dy + size.height * 0.5),
      );
      await tester.pump();

      // Controller position should be updated to ~45 seconds
      expect(controller.positionNotifier.value.inSeconds, closeTo(45, 2));

      controller.dispose();
    });

    testWidgets('hides time labels when showTimeLabels is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScrubberTest(
          waveform: WaveformData.mock(),
          position: const Duration(seconds: 40),
          duration: const Duration(seconds: 240),
          showTimeLabels: false,
        ),
      );
      await tester.pump();

      expect(find.text('0:40'), findsNothing);
      expect(find.text('4:00'), findsNothing);
    });

    testWidgets('ignores seek gestures when isInteractive is false', (
      tester,
    ) async {
      Duration? seekTarget;

      await tester.pumpWidget(
        _buildScrubberTest(
          waveform: WaveformData.mock(),
          position: Duration.zero,
          duration: const Duration(seconds: 100),
          onSeek: (pos) => seekTarget = pos,
          isInteractive: false,
        ),
      );
      await tester.pump();

      final gestureFinder = find.byType(GestureDetector);
      final center = tester.getCenter(gestureFinder);

      await tester.tapAt(center);
      await tester.pump();

      expect(seekTarget, isNull);
    });

    testWidgets('hovering displays floating timestamp badge', (tester) async {
      final wf = WaveformData.mock(pcmHash: 'hover-hash', points: 60);

      await tester.pumpWidget(
        _buildScrubberTest(
          waveform: wf,
          position: Duration.zero,
          duration: const Duration(seconds: 120),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final gestureFinder = find.byType(GestureDetector);
      final topLeft = tester.getTopLeft(gestureFinder);
      final size = tester.getSize(gestureFinder);

      // Simulate mouse hover at 50% (1:00)
      final hoverOffset = Offset(
        topLeft.dx + size.width * 0.5,
        topLeft.dy + size.height * 0.5,
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(hoverOffset);
      await tester.pump();

      // Floating hover badge at 50% of 120s is 1:00
      expect(find.text('1:00'), findsOneWidget);

      // Move away
      await gesture.moveTo(Offset(topLeft.dx - 100, topLeft.dy - 100));
      await tester.pump();
      expect(find.text('1:00'), findsNothing);
    });

    testWidgets(
      'dragging with mouse dynamically moves hover tooltip and updates timestamp',
      (tester) async {
        final wf = WaveformData.mock(pcmHash: 'drag-hover-hash', points: 60);

        await tester.pumpWidget(
          _buildScrubberTest(
            waveform: wf,
            position: Duration.zero,
            duration: const Duration(seconds: 120),
            showTimeLabels: false,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final gestureFinder = find.byType(GestureDetector);
        final topLeft = tester.getTopLeft(gestureFinder);
        final size = tester.getSize(gestureFinder);

        final p25 = Offset(
          topLeft.dx + size.width * 0.25,
          topLeft.dy + size.height * 0.5,
        );
        final p50 = Offset(
          topLeft.dx + size.width * 0.50,
          topLeft.dy + size.height * 0.5,
        );
        final p75 = Offset(
          topLeft.dx + size.width * 0.75,
          topLeft.dy + size.height * 0.5,
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);

        // 1. Hover at 25% (0:30)
        await gesture.moveTo(p25);
        await tester.pump();
        expect(find.text('0:30'), findsOneWidget);
        final xPos25 = tester
            .getTopLeft(find.byKey(const ValueKey('waveform_hover_tooltip')))
            .dx;

        // 2. Press down to start dragging at 25%
        await gesture.down(p25);
        await tester.pump();
        expect(find.text('0:30'), findsOneWidget);

        // 3. Drag to 50% - tooltip must update from 0:30 to 1:00 and move right
        await gesture.moveTo(p50);
        await tester.pump();
        expect(find.text('1:00'), findsOneWidget);
        expect(find.text('0:30'), findsNothing);
        final xPos50 = tester
            .getTopLeft(find.byKey(const ValueKey('waveform_hover_tooltip')))
            .dx;
        expect(xPos50, greaterThan(xPos25));

        // 4. Drag to 75% - tooltip must update from 1:00 to 1:30 and move further right
        await gesture.moveTo(p75);
        await tester.pump();
        expect(find.text('1:30'), findsOneWidget);
        expect(find.text('1:00'), findsNothing);
        final xPos75 = tester
            .getTopLeft(find.byKey(const ValueKey('waveform_hover_tooltip')))
            .dx;
        expect(xPos75, greaterThan(xPos50));

        // 5. Release mouse button inside scrubber - tooltip remains at 1:30
        await gesture.up();
        await tester.pump();
        expect(find.text('1:30'), findsOneWidget);

        // 6. Move mouse away outside scrubber - tooltip disappears
        await gesture.moveTo(Offset(topLeft.dx - 100, topLeft.dy - 100));
        await tester.pump();
        expect(find.text('1:30'), findsNothing);
        expect(
          find.byKey(const ValueKey('waveform_hover_tooltip')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'dragging with touch displays tooltip during active drag and hides on release',
      (tester) async {
        final wf = WaveformData.mock(pcmHash: 'touch-drag-hash', points: 60);

        await tester.pumpWidget(
          _buildScrubberTest(
            waveform: wf,
            position: Duration.zero,
            duration: const Duration(seconds: 120),
            showTimeLabels: false,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final gestureFinder = find.byType(GestureDetector);
        final topLeft = tester.getTopLeft(gestureFinder);
        final size = tester.getSize(gestureFinder);

        final start = Offset(
          topLeft.dx + size.width * 0.25,
          topLeft.dy + size.height * 0.5,
        );
        final mid = Offset(
          topLeft.dx + size.width * 0.50,
          topLeft.dy + size.height * 0.5,
        );

        // Touch drag
        final gesture = await tester.startGesture(start);
        await gesture.moveTo(mid);
        await tester.pump();
        expect(find.text('1:00'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('waveform_hover_tooltip')),
          findsOneWidget,
        );

        // Release touch
        await gesture.up();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('waveform_hover_tooltip')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'dragging beyond horizontal boundaries clamps tooltip position and timestamp',
      (tester) async {
        final wf = WaveformData.mock(pcmHash: 'clamp-drag-hash', points: 60);

        await tester.pumpWidget(
          _buildScrubberTest(
            waveform: wf,
            position: Duration.zero,
            duration: const Duration(seconds: 120),
            showTimeLabels: false,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final gestureFinder = find.byType(GestureDetector);
        final topLeft = tester.getTopLeft(gestureFinder);
        final size = tester.getSize(gestureFinder);

        final start = Offset(
          topLeft.dx + size.width * 0.5,
          topLeft.dy + size.height * 0.5,
        );
        final pastLeft = Offset(
          topLeft.dx - 80.0,
          topLeft.dy + size.height * 0.5,
        );
        final pastRight = Offset(
          topLeft.dx + size.width + 80.0,
          topLeft.dy + size.height * 0.5,
        );

        final gesture = await tester.startGesture(start);
        await gesture.moveTo(Offset(start.dx + 25.0, start.dy));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('waveform_hover_tooltip')),
          findsOneWidget,
        );

        // Drag past left edge -> clamps to 0:00
        await gesture.moveTo(pastLeft);
        await tester.pump();
        expect(find.text('0:00'), findsOneWidget);

        // Drag past right edge -> clamps to 2:00
        await gesture.moveTo(pastRight);
        await tester.pump();
        expect(find.text('2:00'), findsOneWidget);

        await gesture.up();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('waveform_hover_tooltip')),
          findsNothing,
        );
      },
    );
  });

  group('WaveformScrubber Integration with NowPlayingView & AudioInspectorContent', () {
    testWidgets(
      'NowPlayingView renders WaveformScrubber and seeking on it calls playbackController.seek()',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.first;

        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track);

        await tester.pumpWidget(
          _buildNowPlayingIntegrationTest(
            playbackController: controller,
            track: track,
            musicService: service,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final scrubberFinder = find.byType(WaveformScrubber);
        expect(scrubberFinder, findsOneWidget);

        final gestureFinder = find.descendant(
          of: scrubberFinder,
          matching: find.byType(GestureDetector),
        );
        expect(gestureFinder, findsOneWidget);

        final topLeft = tester.getTopLeft(gestureFinder);
        final size = tester.getSize(gestureFinder);

        await tester.tapAt(
          Offset(topLeft.dx + size.width * 0.5, topLeft.dy + size.height * 0.5),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final expectedSeconds = (track.duration.inSeconds * 0.5).round();
        expect(
          controller.positionNotifier.value.inSeconds,
          closeTo(expectedSeconds, 2),
        );
      },
    );

    testWidgets(
      'AudioInspectorContent renders WaveformScrubber under Acoustic Specifications and seeks when the active track is inspected',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.first;

        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track);

        await tester.pumpWidget(
          _buildInspectorIntegrationTest(
            track: track,
            playbackController: controller,
            musicService: service,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final scrubberFinder = find.byType(WaveformScrubber);
        expect(scrubberFinder, findsOneWidget);

        final gestureFinder = find.descendant(
          of: scrubberFinder,
          matching: find.byType(GestureDetector),
        );
        expect(gestureFinder, findsOneWidget);

        final topLeft = tester.getTopLeft(gestureFinder);
        final size = tester.getSize(gestureFinder);

        await tester.tapAt(
          Offset(
            topLeft.dx + size.width * 0.25,
            topLeft.dy + size.height * 0.5,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final expectedSeconds = (track.duration.inSeconds * 0.25).round();
        expect(
          controller.positionNotifier.value.inSeconds,
          closeTo(expectedSeconds, 2),
        );
      },
    );

    testWidgets(
      'AudioInspectorContent does not seek active playback when inspecting a different track',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final playingTrack = tracks[0];
        final otherTrack = tracks[1];

        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(playingTrack);
        controller.seek(const Duration(seconds: 15));

        await tester.pumpWidget(
          _buildInspectorIntegrationTest(
            track: otherTrack,
            playbackController: controller,
            musicService: service,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final scrubberFinder = find.byType(WaveformScrubber);
        expect(scrubberFinder, findsOneWidget);

        final gestureFinder = find.descendant(
          of: scrubberFinder,
          matching: find.byType(GestureDetector),
        );
        expect(gestureFinder, findsOneWidget);

        final center = tester.getCenter(gestureFinder);
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.positionNotifier.value.inSeconds, equals(15));
      },
    );

    testWidgets(
      'NowPlayingView tab 2 Details passes playbackController to AudioInspectorContent',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final service = MockMusicService();
        final tracks = await service.getTracks();
        final track = tracks.first;

        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(track);

        await tester.pumpWidget(
          _buildNowPlayingIntegrationTest(
            playbackController: controller,
            track: track,
            musicService: service,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Details'));
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byType(AudioInspectorContent), findsOneWidget);
        expect(find.byType(WaveformScrubber), findsNWidgets(2));
      },
    );
  });
}

Widget _buildNowPlayingIntegrationTest({
  required PlaybackQueueController playbackController,
  Track? track,
  MockMusicService? musicService,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'NowPlaying Waveform Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        const tokens = LyraThemeTokens(
          isDark: true,
          background: LyraColors.zinc950,
          foreground: LyraColors.zinc50,
          card: LyraColors.zinc900,
          cardForeground: LyraColors.zinc50,
          border: LyraColors.zinc700,
          text: LyraColors.zinc50,
          textMuted: LyraColors.zinc400,
          primary: LyraColors.zinc50,
          primaryForeground: LyraColors.zinc900,
          secondary: LyraColors.zinc800,
          secondaryForeground: LyraColors.zinc50,
          muted: LyraColors.zinc800,
          mutedForeground: LyraColors.zinc400,
          accent: LyraColors.zinc800,
          accentForeground: LyraColors.zinc50,
          destructive: LyraColors.red500,
          destructiveForeground: LyraColors.zinc50,
          ring: LyraColors.zinc400,
          success: LyraColors.emerald500,
          successForeground: LyraColors.emerald950,
          warning: LyraColors.amber500,
          warningForeground: LyraColors.amber950,
        );

        return LyraDesignSystemScope(
          factory: factory,
          tokens: tokens,
          themeModeNotifier: themeModeNotifier,
          child: Scaffold(
            body: NowPlayingView(
              track: track ?? playbackController.currentTrack,
              playbackController: playbackController,
              onCollapse: () {},
              musicService: musicService,
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildInspectorIntegrationTest({
  required Track track,
  PlaybackQueueController? playbackController,
  MockMusicService? musicService,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Inspector Waveform Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        const tokens = LyraThemeTokens(
          isDark: true,
          background: LyraColors.zinc950,
          foreground: LyraColors.zinc50,
          card: LyraColors.zinc900,
          cardForeground: LyraColors.zinc50,
          border: LyraColors.zinc700,
          text: LyraColors.zinc50,
          textMuted: LyraColors.zinc400,
          primary: LyraColors.zinc50,
          primaryForeground: LyraColors.zinc900,
          secondary: LyraColors.zinc800,
          secondaryForeground: LyraColors.zinc50,
          muted: LyraColors.zinc800,
          mutedForeground: LyraColors.zinc400,
          accent: LyraColors.zinc800,
          accentForeground: LyraColors.zinc50,
          destructive: LyraColors.red500,
          destructiveForeground: LyraColors.zinc50,
          ring: LyraColors.zinc400,
          success: LyraColors.emerald500,
          successForeground: LyraColors.emerald950,
          warning: LyraColors.amber500,
          warningForeground: LyraColors.amber950,
        );

        return LyraDesignSystemScope(
          factory: factory,
          tokens: tokens,
          themeModeNotifier: themeModeNotifier,
          child: Scaffold(
            body: SizedBox(
              width: 400.0,
              height: 800.0,
              child: AudioInspectorContent(
                track: track,
                playbackController: playbackController,
                musicService: musicService,
              ),
            ),
          ),
        );
      },
    ),
  );
}
