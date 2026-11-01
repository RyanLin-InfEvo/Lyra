// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

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
import 'package:ui/features/services/music_service.dart';
import 'package:ui/features/settings/services/preferences_service.dart';

class SpyMusicService extends MockMusicService {
  final List<({String target, int points})> waveformRequests = [];

  @override
  Future<WaveformData> getWaveform(
    String trackIdOrPcmHash, {
    int points = 120,
  }) async {
    waveformRequests.add((target: trackIdOrPcmHash, points: points));
    return super.getWaveform(trackIdOrPcmHash, points: points);
  }
}

class ControlledMusicService extends MockMusicService {
  final List<Completer<WaveformData>> completers = [];
  final List<({String target, int points})> requests = [];

  @override
  Future<WaveformData> getWaveform(
    String trackIdOrPcmHash, {
    int points = 120,
  }) {
    requests.add((target: trackIdOrPcmHash, points: points));
    final completer = Completer<WaveformData>();
    completers.add(completer);
    return completer.future;
  }
}

Widget _buildNowPlayingTestApp({
  Track? track,
  required PlaybackQueueController playbackController,
  required MusicService musicService,
  required PreferencesService preferencesService,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'NowPlaying Waveform Decoupling Test',
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
              track: track,
              playbackController: playbackController,
              onCollapse: () {},
              musicService: musicService,
              preferencesService: preferencesService,
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildInspectorTestApp({
  required Track track,
  required PlaybackQueueController playbackController,
  required SpyMusicService musicService,
  required PreferencesService preferencesService,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Inspector Waveform Decoupling Test',
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
                preferencesService: preferencesService,
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  group('Waveform Settings & Presentation Decoupling Tests', () {
    late SpyMusicService musicService;
    late Track testTrack;

    setUp(() async {
      musicService = SpyMusicService();
      final tracks = await musicService.getTracks();
      testTrack = tracks.first;
    });

    testWidgets(
      'NowPlayingView honors showNowPlayingWaveform toggle and density settings',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = InMemoryPreferencesService(
          showNowPlayingWaveform: true,
          nowPlayingWaveformPoints: 70,
          waveformPulseAnimation: false,
          waveformHoverTimeGuide: false,
        );
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(testTrack);

        await tester.pumpWidget(
          _buildNowPlayingTestApp(
            track: testTrack,
            playbackController: controller,
            musicService: musicService,
            preferencesService: prefs,
          ),
        );
        await tester.pumpAndSettle();

        // 1. WaveformScrubber is visible
        expect(find.byType(WaveformScrubber), findsOneWidget);

        // 2. Verified requested density was 70 points
        expect(musicService.waveformRequests, isNotEmpty);
        expect(musicService.waveformRequests.last.points, 70);

        // 3. Verified pulse & hover guide toggles passed to WaveformScrubber
        final scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.enablePulseAnimation, isFalse);
        expect(scrubber.enableHoverTimeGuide, isFalse);
        expect(scrubber.waveform?.points.length, 70);

        // 4. Toggle showNowPlayingWaveform to false dynamically
        await prefs.setShowNowPlayingWaveform(false);
        await tester.pumpAndSettle();

        // Waveform is hidden / removed from view
        expect(find.byType(WaveformScrubber), findsNothing);

        // 5. Toggle back to true with 280 points
        await prefs.setNowPlayingWaveformPoints(280);
        await prefs.setShowNowPlayingWaveform(true);
        await tester.pumpAndSettle();

        expect(find.byType(WaveformScrubber), findsOneWidget);
        expect(musicService.waveformRequests.last.points, 280);

        // 6. While waveform is currently displayed, adjust density to 350
        await prefs.setNowPlayingWaveformPoints(350);
        await tester.pumpAndSettle();

        expect(musicService.waveformRequests.last.points, 350);
        final updatedScrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(updatedScrubber.waveform?.points.length, 350);
      },
    );

    testWidgets(
      'AudioInspectorContent honors showInspectorWaveform toggle and density settings',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = InMemoryPreferencesService(
          showInspectorWaveform: true,
          inspectorWaveformPoints: 50,
          waveformPulseAnimation: false,
          waveformHoverTimeGuide: false,
        );
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(testTrack);

        await tester.pumpWidget(
          _buildInspectorTestApp(
            track: testTrack,
            playbackController: controller,
            musicService: musicService,
            preferencesService: prefs,
          ),
        );
        await tester.pumpAndSettle();

        // 1. WaveformScrubber is visible under Acoustic Specifications
        expect(find.byType(WaveformScrubber), findsOneWidget);

        // 2. Verified requested density was 50 points
        expect(musicService.waveformRequests, isNotEmpty);
        expect(musicService.waveformRequests.last.points, 50);

        final scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.enablePulseAnimation, isFalse);
        expect(scrubber.enableHoverTimeGuide, isFalse);
        expect(scrubber.waveform?.points.length, 50);

        // 3. Toggle showInspectorWaveform to false dynamically
        await prefs.setShowInspectorWaveform(false);
        await tester.pumpAndSettle();

        // Waveform is hidden in inspector
        expect(find.byType(WaveformScrubber), findsNothing);

        // 4. Toggle back to true with 150 points
        await prefs.setInspectorWaveformPoints(150);
        await prefs.setShowInspectorWaveform(true);
        await tester.pumpAndSettle();

        expect(find.byType(WaveformScrubber), findsOneWidget);
        expect(musicService.waveformRequests.last.points, 150);
      },
    );

    testWidgets(
      'WaveformScrubber honors enablePulseAnimation and enableHoverTimeGuide flags',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final waveform = WaveformData(
          pcmHash: 'hash-test',
          points: WaveformData.generateMockPoints(
            count: 4,
            seedString: 'hash-test',
          ),
        );

        // Render with pulse animation false and hover guide false
        final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
        const factory = ShadcnFactory();
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

        await tester.pumpWidget(
          ShadApp(
            home: LyraDesignSystemScope(
              factory: factory,
              tokens: tokens,
              themeModeNotifier: themeModeNotifier,
              child: Scaffold(
                body: SizedBox(
                  width: 400.0,
                  height: 64.0,
                  child: WaveformScrubber(
                    waveform: waveform,
                    position: const Duration(seconds: 10),
                    duration: const Duration(seconds: 100),
                    enablePulseAnimation: false,
                    enableHoverTimeGuide: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.enablePulseAnimation, isFalse);
        expect(scrubber.enableHoverTimeGuide, isFalse);
      },
    );

    testWidgets(
      'NowPlayingView and AudioInspectorContent read target-specific pulse and hover guide independently',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = InMemoryPreferencesService(
          showNowPlayingWaveform: true,
          showInspectorWaveform: true,
          nowPlayingWaveformPulseAnimation: true,
          nowPlayingWaveformHoverTimeGuide: false,
          inspectorWaveformPulseAnimation: false,
          inspectorWaveformHoverTimeGuide: true,
        );

        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(testTrack);

        await tester.pumpWidget(
          _buildNowPlayingTestApp(
            track: testTrack,
            playbackController: controller,
            musicService: musicService,
            preferencesService: prefs,
          ),
        );
        await tester.pumpAndSettle();

        var scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.enablePulseAnimation, isTrue);
        expect(scrubber.enableHoverTimeGuide, isFalse);

        await tester.pumpWidget(
          _buildInspectorTestApp(
            track: testTrack,
            playbackController: controller,
            musicService: musicService,
            preferencesService: prefs,
          ),
        );
        await tester.pumpAndSettle();

        scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.enablePulseAnimation, isFalse);
        expect(scrubber.enableHoverTimeGuide, isTrue);
      },
    );

    testWidgets(
      'Nullifying current track while waveform request is in flight invalidates request and does not set waveform',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controlledService = ControlledMusicService();
        final prefs = InMemoryPreferencesService(
          showNowPlayingWaveform: true,
          nowPlayingWaveformPoints: 100,
        );
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(testTrack);

        await tester.pumpWidget(
          _buildNowPlayingTestApp(
            track: testTrack,
            playbackController: controller,
            musicService: controlledService,
            preferencesService: prefs,
          ),
        );
        // Initial build triggers getWaveform, which is now in flight
        expect(controlledService.requests, hasLength(1));
        expect(controlledService.completers, hasLength(1));

        // Waveform is not yet loaded
        var scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.waveform, isNull);

        // Clear playback queue and nullify track while request is in flight
        controller.clearQueue();
        await tester.pumpWidget(
          _buildNowPlayingTestApp(
            track: null,
            playbackController: controller,
            musicService: controlledService,
            preferencesService: prefs,
          ),
        );
        await tester.pump();

        // Complete any in-flight requests that were triggered
        final mockWf = WaveformData(
          pcmHash: testTrack.pcmHash,
          points: const [
            WaveformPoint(min: -0.1, max: 0.5, rms: 0.3),
            WaveformPoint(min: -0.2, max: 0.6, rms: 0.4),
          ],
        );
        for (final completer in controlledService.completers) {
          if (!completer.isCompleted) completer.complete(mockWf);
        }
        await tester.pump();

        // Waveform MUST still be null (request was invalidated and cleared)
        scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.waveform, isNull);
      },
    );

    testWidgets(
      'Switching tracks immediately clears the old waveform before the new one loads',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controlledService = ControlledMusicService();
        final prefs = InMemoryPreferencesService(
          showNowPlayingWaveform: true,
          nowPlayingWaveformPoints: 100,
        );
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(testTrack);

        await tester.pumpWidget(
          _buildNowPlayingTestApp(
            track: testTrack,
            playbackController: controller,
            musicService: controlledService,
            preferencesService: prefs,
          ),
        );
        expect(controlledService.completers, hasLength(1));

        // Complete track 1's waveform
        final track1Wf = WaveformData(
          pcmHash: testTrack.pcmHash,
          points: const [WaveformPoint(min: -0.2, max: 0.4, rms: 0.3)],
        );
        controlledService.completers.first.complete(track1Wf);
        await tester.pump();

        var scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.waveform, equals(track1Wf));

        // Switch to track 2
        const track2 = Track(
          id: 'track-2',
          title: 'Track Two',
          artistName: 'Artist Two',
          durationMs: 200000,
          pcmHash: 'pcm-hash-track-2',
        );

        controller.play(track2);
        await tester.pumpWidget(
          _buildNowPlayingTestApp(
            track: track2,
            playbackController: controller,
            musicService: controlledService,
            preferencesService: prefs,
          ),
        );
        // Only pump a single frame (track 2 completer has NOT completed)
        await tester.pump();

        // Old waveform MUST be cleared immediately for track transition skeleton
        scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.waveform, isNull);

        // Now complete track 2's waveform
        expect(controlledService.completers, hasLength(2));
        final track2Wf = WaveformData(
          pcmHash: track2.pcmHash,
          points: const [WaveformPoint(min: -0.8, max: 0.3, rms: 0.5)],
        );
        controlledService.completers.last.complete(track2Wf);
        await tester.pump();

        scrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(scrubber.waveform, equals(track2Wf));
      },
    );

    testWidgets(
      'Rapid playback events do not issue duplicate in-flight waveform requests',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controlledService = ControlledMusicService();
        final prefs = InMemoryPreferencesService(
          showNowPlayingWaveform: true,
          nowPlayingWaveformPoints: 100,
        );
        final controller = PlaybackQueueController(autoStartTimer: false);
        addTearDown(controller.dispose);
        controller.play(testTrack);

        await tester.pumpWidget(
          _buildNowPlayingTestApp(
            track: testTrack,
            playbackController: controller,
            musicService: controlledService,
            preferencesService: prefs,
          ),
        );

        // Initial fetch triggered
        expect(controlledService.requests, hasLength(1));

        // Simulate rapid playback updates (toggle play, shuffle, etc.)
        controller.togglePlay();
        await tester.pump();
        controller.toggleShuffle();
        await tester.pump();
        controller.togglePlay();
        await tester.pump();

        // Requests length MUST remain 1 because initial request is still in flight
        expect(controlledService.requests, hasLength(1));

        // Now complete the request
        final mockWf = WaveformData(
          pcmHash: testTrack.pcmHash,
          points: const [WaveformPoint(min: -0.5, max: 0.5, rms: 0.4)],
        );
        controlledService.completers.first.complete(mockWf);
        await tester.pump();

        // Still 1 request
        expect(controlledService.requests, hasLength(1));
      },
    );
  });
}
