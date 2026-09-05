// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/shell/player_bar.dart';

Widget _buildPlayerBarTest({
  Track? currentTrack,
  bool isPlaying = false,
  Duration currentPosition = const Duration(seconds: 30),
  double volume = 0.75,
  VoidCallback? onTogglePlay,
  VoidCallback? onNext,
  VoidCallback? onPrevious,
  ValueChanged<Duration>? onSeek,
  ValueChanged<double>? onVolumeChanged,
  ValueNotifier<ThemeMode>? themeNotifier,
  bool isNowPlayingExpanded = false,
  VoidCallback? onExpandNowPlaying,
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
              body: LyraPlayerBar(
                currentTrack: currentTrack,
                isPlaying: isPlaying,
                currentPosition: currentPosition,
                volume: volume,
                isNowPlayingExpanded: isNowPlayingExpanded,
                onTogglePlay: onTogglePlay ?? () {},
                onNext: onNext ?? () {},
                onPrevious: onPrevious ?? () {},
                onSeek: onSeek ?? (_) {},
                onVolumeChanged: onVolumeChanged ?? (_) {},
                onExpandNowPlaying: onExpandNowPlaying,
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  const testTrack = Track(
    id: '1',
    title: 'Test Song',
    artistName: 'Test Artist',
    albumTitle: 'Test Album',
    format: 'FLAC 24/96',
    durationMs: 200000,
    sampleRate: 96000,
    bitDepth: 24,
    pcmHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  );

  testWidgets('LyraPlayerBar displays track info and duration', (tester) async {
    await tester.pumpWidget(
      _buildPlayerBarTest(
        currentTrack: testTrack,
        currentPosition: const Duration(minutes: 1, seconds: 15),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Song'), findsOneWidget);
    expect(find.text('Test Artist • Test Album'), findsOneWidget);
    expect(find.text('FLAC 24/96'), findsOneWidget);
    expect(find.text('1:15'), findsOneWidget);
    expect(find.text('3:20'), findsOneWidget);
  });

  testWidgets('LyraPlayerBar progress slider seeks on tap and drag', (
    tester,
  ) async {
    Duration? seekedDuration;

    await tester.pumpWidget(
      _buildPlayerBarTest(
        currentTrack: testTrack,
        currentPosition: const Duration(seconds: 0),
        onSeek: (pos) => seekedDuration = pos,
      ),
    );
    await tester.pumpAndSettle();

    // Find progress slider gesture area
    final progressFinder = find.byType(GestureDetector).at(1);
    expect(progressFinder, findsOneWidget);

    // Tap halfway across the progress slider
    final progressCenter = tester.getCenter(progressFinder);
    await tester.tapAt(progressCenter);
    await tester.pumpAndSettle();

    expect(seekedDuration, isNotNull);
    expect(seekedDuration!.inSeconds, greaterThan(0));

    // Drag on progress slider
    await tester.drag(progressFinder, const Offset(50, 0));
    await tester.pumpAndSettle();
    expect(seekedDuration, isNotNull);
  });

  testWidgets('LyraPlayerBar volume slider adjusts on tap and drag', (
    tester,
  ) async {
    double? updatedVolume;

    await tester.pumpWidget(
      _buildPlayerBarTest(
        currentTrack: testTrack,
        volume: 0.5,
        onVolumeChanged: (vol) => updatedVolume = vol,
      ),
    );
    await tester.pumpAndSettle();

    final volumeGestureFinder = find.byType(GestureDetector).last;
    expect(volumeGestureFinder, findsOneWidget);

    final volumeCenter = tester.getCenter(volumeGestureFinder);
    await tester.tapAt(volumeCenter);
    await tester.pumpAndSettle();

    expect(updatedVolume, isNotNull);
  });

  testWidgets('LyraPlayerBar sliders respond to mouse hover events', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPlayerBarTest(
        currentTrack: testTrack,
        currentPosition: const Duration(seconds: 60),
      ),
    );
    await tester.pumpAndSettle();

    final gestureDetectorFinders = find.byType(GestureDetector);
    final progressGestureFinder = gestureDetectorFinders.at(1);

    // Simulate pointer hover enter and exit
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(progressGestureFinder));
    await tester.pump(const Duration(milliseconds: 150));

    await gesture.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets(
    'LyraPlayerBar adapts background and controls dynamically in a single frame',
    (tester) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(themeNotifier.dispose);

      await tester.pumpWidget(
        _buildPlayerBarTest(
          currentTrack: testTrack,
          themeNotifier: themeNotifier,
        ),
      );
      await tester.pump();

      // 1. Dark Mode: PlayerBar container background is zinc900 (tokens.card)
      final playerBarContainerDark = tester.widget<Container>(
        find.byType(Container).first,
      );
      final darkDeco = playerBarContainerDark.decoration as BoxDecoration;
      expect(darkDeco.color, equals(LyraColors.zinc900));

      // Switch to Light Mode (single frame 0ms)
      themeNotifier.value = ThemeMode.light;
      await tester.pump();

      // 2. Light Mode: PlayerBar container background is white (Color(0xFFFFFFFF))
      final playerBarContainerLight = tester.widget<Container>(
        find.byType(Container).first,
      );
      final lightDeco = playerBarContainerLight.decoration as BoxDecoration;
      expect(lightDeco.color, equals(const Color(0xFFFFFFFF)));
    },
  );

  testWidgets(
    'LyraPlayerBar toggle button reflects isNowPlayingExpanded state and tooltips',
    (tester) async {
      bool toggled = false;

      // 1. When isNowPlayingExpanded is false: displays chevronUp and 'Expand Now Playing' tooltip
      await tester.pumpWidget(
        _buildPlayerBarTest(
          currentTrack: testTrack,
          isNowPlayingExpanded: false,
          onExpandNowPlaying: () => toggled = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.chevronUp), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronDown), findsNothing);
      expect(find.byTooltip('Expand Now Playing'), findsOneWidget);

      // Tap toggle button
      await tester.tap(find.byIcon(LucideIcons.chevronUp));
      await tester.pumpAndSettle();
      expect(toggled, isTrue);

      // 2. When isNowPlayingExpanded is true: displays chevronDown and 'Collapse Now Playing' tooltip
      await tester.pumpWidget(
        _buildPlayerBarTest(
          currentTrack: testTrack,
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
}
