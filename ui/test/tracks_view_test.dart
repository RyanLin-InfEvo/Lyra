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
import 'package:ui/features/tracks/tracks_view.dart';

Widget _buildTracksViewTest({
  required List<Track> tracks,
  Track? currentTrack,
  bool isPlaying = false,
  ValueChanged<Track>? onTrackSelected,
  VoidCallback? onTogglePlay,
  ValueChanged<Track>? onInspectTrack,
  ValueChanged<Track>? onInspectAudio,
  Map<String, int>? audioVersionCounts,
  String? filterLabel,
  VoidCallback? onClearFilter,
  ValueNotifier<ThemeMode>? themeNotifier,
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
              body: TracksView(
                tracks: tracks,
                currentTrack: currentTrack,
                isPlaying: isPlaying,
                onTrackSelected: onTrackSelected ?? (_) {},
                onTogglePlay: onTogglePlay ?? () {},
                onInspectTrack: onInspectTrack,
                onInspectAudio: onInspectAudio,
                audioVersionCounts: audioVersionCounts,
                filterLabel: filterLabel,
                onClearFilter: onClearFilter,
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  const sampleTracks = [
    Track(
      id: '1',
      title: 'Track One',
      artistName: 'Artist A',
      albumTitle: 'Album X',
      format: 'FLAC 24/96',
      durationMs: 252000,
      sampleRate: 96000,
      bitDepth: 24,
      pcmHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
    Track(
      id: '2',
      title: 'Track Two',
      artistName: 'Artist B',
      albumTitle: 'Album Y',
      format: 'DSD 5.6MHz',
      durationMs: 330000,
      sampleRate: 5644800,
      bitDepth: 1,
      pcmHash:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    ),
  ];

  testWidgets('TracksView renders empty state when tracks list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTracksViewTest(tracks: []));
    await tester.pumpAndSettle();

    expect(find.text('No tracks found'), findsOneWidget);
    expect(find.byIcon(LucideIcons.searchX), findsOneWidget);
  });

  testWidgets(
    'TracksView table header # and track row index/icon have identical horizontal alignment with zero jump on hover',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTracksViewTest(tracks: sampleTracks));
      await tester.pumpAndSettle();

      // 1. Verify header '#' position
      final headerHashFinder = find.text('#');
      expect(headerHashFinder, findsOneWidget);
      final headerHashTopLeft = tester.getTopLeft(headerHashFinder);

      // 2. Verify track index '1' position
      final index1Finder = find.text('1');
      expect(index1Finder, findsOneWidget);
      final index1TopLeft = tester.getTopLeft(index1Finder);

      // Header '#' and track index '1' should share the exact same horizontal start (dx)
      expect(index1TopLeft.dx, equals(headerHashTopLeft.dx));

      // 3. Hover over the first track row
      final firstRowFinder = find.text('Track One');
      expect(firstRowFinder, findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(firstRowFinder));
      await tester.pumpAndSettle();

      // Track index '1' is replaced by play icon
      expect(find.text('1'), findsNothing);
      final playIconFinder = find.byIcon(LucideIcons.play);
      expect(playIconFinder, findsOneWidget);

      // Play icon should start at the exact same horizontal position (dx)
      final playIconTopLeft = tester.getTopLeft(playIconFinder);
      expect(playIconTopLeft.dx, equals(headerHashTopLeft.dx));
      expect(playIconTopLeft.dx, equals(index1TopLeft.dx));

      // 4. Move mouse away -> play icon reverts to index '1' at the same dx
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(LucideIcons.play), findsNothing);
      final revertedIndexTopLeft = tester.getTopLeft(find.text('1'));
      expect(revertedIndexTopLeft.dx, equals(headerHashTopLeft.dx));
    },
  );

  testWidgets(
    'TracksView currently playing track renders volume2 icon at aligned dx',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTracksViewTest(
          tracks: sampleTracks,
          currentTrack: sampleTracks.first,
          isPlaying: true,
        ),
      );
      await tester.pumpAndSettle();

      final headerHashFinder = find.text('#');
      expect(headerHashFinder, findsOneWidget);
      final headerHashTopLeft = tester.getTopLeft(headerHashFinder);

      final volumeIconFinder = find.byIcon(LucideIcons.volume2);
      expect(volumeIconFinder, findsOneWidget);
      final volumeIconTopLeft = tester.getTopLeft(volumeIconFinder);

      // Volume icon shares identical horizontal alignment with header '#'
      expect(volumeIconTopLeft.dx, equals(headerHashTopLeft.dx));
    },
  );

  testWidgets('TracksView callbacks trigger on selection and toggle play', (
    tester,
  ) async {
    Track? selectedTrack;
    bool togglePlayCalled = false;

    await tester.pumpWidget(
      _buildTracksViewTest(
        tracks: sampleTracks,
        currentTrack: sampleTracks.first,
        isPlaying: false,
        onTrackSelected: (t) => selectedTrack = t,
        onTogglePlay: () => togglePlayCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    // Tapping current track triggers onTogglePlay
    await tester.tap(find.text('Track One'));
    await tester.pumpAndSettle();
    expect(togglePlayCalled, isTrue);

    // Tapping non-current track triggers onTrackSelected
    await tester.tap(find.text('Track Two'));
    await tester.pumpAndSettle();
    expect(selectedTrack?.id, equals('2'));
  });

  testWidgets(
    'TracksView renders filterLabel badge and triggers onClearFilter',
    (tester) async {
      bool clearClicked = false;

      await tester.pumpWidget(
        _buildTracksViewTest(
          tracks: sampleTracks,
          filterLabel: 'Album: Test Album',
          onClearFilter: () => clearClicked = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tracks Library'), findsOneWidget);
      expect(find.text('Album: Test Album'), findsOneWidget);

      // Tap clear button (X icon)
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(clearClicked, isTrue);
    },
  );

  testWidgets('TracksView empty state with filterLabel renders clear button', (
    tester,
  ) async {
    bool clearClicked = false;

    await tester.pumpWidget(
      _buildTracksViewTest(
        tracks: const [],
        filterLabel: 'Work: Unknown',
        onClearFilter: () => clearClicked = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No matching tracks found'), findsOneWidget);
    expect(
      find.text('No tracks found matching "Work: Unknown".'),
      findsOneWidget,
    );

    final clearBtn = find.text('Clear filter');
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();
    expect(clearClicked, isTrue);
  });

  testWidgets(
    'TracksView table header and active row adapt dynamically to Light and Dark mode',
    (tester) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(themeNotifier.dispose);

      await tester.pumpWidget(
        _buildTracksViewTest(
          tracks: sampleTracks,
          currentTrack: sampleTracks.first,
          themeNotifier: themeNotifier,
        ),
      );
      await tester.pump();

      // 1. Dark Mode: table background & ShadTheme is dark
      final tracksElementDark = find.byType(TracksView).evaluate().first;
      final themeDark = ShadTheme.of(tracksElementDark);
      expect(themeDark.brightness, equals(Brightness.dark));

      final activeTitleTextDark = tester.widget<Text>(find.text('Track One'));
      expect(activeTitleTextDark.style?.color, equals(LyraColors.zinc50));

      // Switch to Light Mode (single frame 0ms)
      themeNotifier.value = ThemeMode.light;
      await tester.pump();

      // 2. Light Mode: table background & ShadTheme is light
      final tracksElementLight = find.byType(TracksView).evaluate().first;
      final themeLight = ShadTheme.of(tracksElementLight);
      expect(themeLight.brightness, equals(Brightness.light));

      final activeTitleTextLight = tester.widget<Text>(find.text('Track One'));
      expect(activeTitleTextLight.style?.color, equals(LyraColors.zinc900));
    },
  );

  testWidgets(
    'TracksView triggers onInspectTrack callback when clicking CAS hash badge and info icon',
    (tester) async {
      Track? inspectedTrack;

      await tester.pumpWidget(
        _buildTracksViewTest(
          tracks: sampleTracks,
          onInspectTrack: (t) => inspectedTrack = t,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Find CAS hash badge for Track One (shortCasHash: "aaaaaa...aaaa")
      final casBadgeFinder = find.text('aaaaaa...aaaa');
      expect(casBadgeFinder, findsOneWidget);

      await tester.tap(casBadgeFinder);
      await tester.pumpAndSettle();

      expect(inspectedTrack?.id, equals('1'));

      // Reset
      inspectedTrack = null;

      // 2. Click the explicit info icon for Track Two
      final infoIcons = find.byIcon(LucideIcons.info);
      expect(infoIcons, findsNWidgets(2));

      await tester.tap(infoIcons.at(1));
      await tester.pumpAndSettle();

      expect(inspectedTrack?.id, equals('2'));
    },
  );

  testWidgets(
    'TracksView displays audio version counts and triggers onInspectAudio on badge tap',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Track? inspectedAudioTrack;

      await tester.pumpWidget(
        _buildTracksViewTest(
          tracks: sampleTracks,
          audioVersionCounts: {'1': 3, '2': 1},
          onInspectAudio: (track) {
            inspectedAudioTrack = track;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Track 1 should display '24-bit/96kHz · 3 versions'
      final multiVersionBadge = find.text('24-bit/96kHz · 3 versions');
      expect(multiVersionBadge, findsOneWidget);

      // Track 2 (single version) should display standard '1-bit/5644.8kHz'
      expect(find.text('1-bit/5644.8kHz'), findsOneWidget);

      // Tap multi-version badge
      await tester.tap(multiVersionBadge);
      await tester.pumpAndSettle();

      expect(inspectedAudioTrack?.id, equals('1'));

      // Reset
      inspectedAudioTrack = null;

      // Verify audioWaveform is no longer rendered in the row
      expect(find.byIcon(LucideIcons.audioWaveform), findsNothing);

      // Tap info icon for track 2
      final infoIcons = find.byIcon(LucideIcons.info);
      expect(infoIcons, findsNWidgets(2));

      await tester.tap(infoIcons.at(1));
      await tester.pumpAndSettle();

      expect(inspectedAudioTrack?.id, equals('2'));
    },
  );
}
