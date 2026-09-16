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
import 'package:ui/design_system/widgets/lyra_button.dart';
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
  Set<TrackColumn>? visibleColumns,
  ValueChanged<Set<TrackColumn>>? onVisibleColumnsChanged,
  List<TrackColumn>? columnOrder,
  ValueChanged<List<TrackColumn>>? onColumnOrderChanged,
  ValueNotifier<ThemeMode>? themeNotifier,
  VoidCallback? onImport,
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
                visibleColumns: visibleColumns,
                onVisibleColumnsChanged: onVisibleColumnsChanged,
                columnOrder: columnOrder,
                onColumnOrderChanged: onColumnOrderChanged,
                onImport: onImport,
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

      final filterText = tester.widget<Text>(find.text('Album: Test Album'));
      expect(filterText.style?.fontSize, equals(12.0));
      expect(filterText.style?.fontWeight, equals(FontWeight.w500));

      expect(find.byTooltip('Clear filter'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Clear filter',
        ),
        findsOneWidget,
      );

      // Tap clear button (X icon)
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(clearClicked, isTrue);
    },
  );

  testWidgets(
    'TracksView header filter token displays close button with hover state',
    (tester) async {
      await tester.pumpWidget(
        _buildTracksViewTest(
          tracks: sampleTracks,
          filterLabel: 'Album: Test Album',
          onClearFilter: () {},
        ),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(LucideIcons.x);
      expect(iconFinder, findsOneWidget);

      final iconBeforeHover = tester.widget<Icon>(iconFinder);
      expect(iconBeforeHover.color, equals(LyraThemeTokens.dark().textMuted));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(iconFinder));
      await tester.pumpAndSettle();

      final iconAfterHover = tester.widget<Icon>(iconFinder);
      expect(iconAfterHover.color, equals(LyraThemeTokens.dark().text));
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
    'TracksView triggers onInspectTrack callback when clicking info icon and does not display CAS hash',
    (tester) async {
      Track? inspectedTrack;

      await tester.pumpWidget(
        _buildTracksViewTest(
          tracks: sampleTracks,
          onInspectTrack: (t) => inspectedTrack = t,
        ),
      );
      await tester.pumpAndSettle();

      // Verify CAS HASH does NOT appear anywhere in the header or view
      expect(find.text('CAS HASH'), findsNothing);
      expect(find.text('aaaaaa...aaaa'), findsNothing);

      // Verify info icons are removed
      expect(find.byIcon(LucideIcons.info), findsNothing);

      final resolutionBadgeFinder = find.text('24-bit/96kHz');
      expect(resolutionBadgeFinder, findsOneWidget);

      // 1. Click resolution badge for Track One
      await tester.tap(resolutionBadgeFinder);
      await tester.pumpAndSettle();

      expect(inspectedTrack?.id, equals('1'));

      // Reset
      inspectedTrack = null;

      // 2. Click the resolution badge for Track Two
      await tester.tap(find.text('1-bit/5644.8kHz'));
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

      // Verify info icon is no longer rendered in the row
      expect(find.byIcon(LucideIcons.info), findsNothing);

      // Tap resolution badge for track 2
      final track2Badge = find.text('1-bit/5644.8kHz');
      expect(track2Badge, findsOneWidget);

      await tester.tap(track2Badge);
      await tester.pumpAndSettle();

      expect(inspectedAudioTrack?.id, equals('2'));
    },
  );

  group('TracksView Column Customization Tests', () {
    testWidgets(
      'right-clicking header opens context menu with column checkboxes and toggling hides/shows columns',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        Set<TrackColumn>? changedColumns;

        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: sampleTracks,
            onVisibleColumnsChanged: (cols) => changedColumns = cols,
          ),
        );
        await tester.pumpAndSettle();

        // Verify initial state: all columns visible in header
        expect(find.text('#'), findsOneWidget);
        expect(find.text('Title & Artist'), findsOneWidget);
        expect(find.text('Album'), findsOneWidget);
        expect(find.text('Resolution'), findsOneWidget);
        expect(find.text('Time'), findsOneWidget);

        // Verify rows show album and duration
        expect(find.text('Album X'), findsOneWidget);
        expect(find.text('Album Y'), findsOneWidget);
        expect(find.text('4:12'), findsOneWidget);

        // Context menu items are not yet visible
        expect(find.byKey(const Key('track_col_menu_album')), findsNothing);

        // Right-click the header row
        final header = find.byKey(const Key('tracks_table_header'));
        expect(header, findsOneWidget);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify context menu is now open with checkboxes for each column
        final columnsWindow = find.byKey(const Key('tracks_columns_window'));
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
          find.descendant(of: columnsWindow, matching: find.text('Resolution')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('track_col_menu_duration')),
            matching: find.text('Time'),
          ),
          findsOneWidget,
        );

        // Verify checkboxes states
        final albumCheckboxFinder = find.byKey(
          const Key('track_col_checkbox_album'),
        );
        expect(albumCheckboxFinder, findsOneWidget);
        expect(tester.widget<ShadCheckbox>(albumCheckboxFinder).value, isTrue);

        // 1. Toggle off Album
        await tester.tap(find.byKey(const Key('track_col_menu_album')));
        await tester.pumpAndSettle();

        // Header and rows should no longer display Album
        expect(
          find.descendant(of: header, matching: find.text('Album')),
          findsNothing,
        );
        expect(find.text('Album X'), findsNothing);
        expect(find.text('Album Y'), findsNothing);
        expect(tester.widget<ShadCheckbox>(albumCheckboxFinder).value, isFalse);
        expect(changedColumns?.contains(TrackColumn.album), isFalse);

        // Other columns remain visible
        expect(
          find.descendant(of: header, matching: find.text('Title & Artist')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text('Resolution')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text('Time')),
          findsOneWidget,
        );

        // 2. Toggle off Resolution
        final resCheckboxFinder = find.byKey(
          const Key('track_col_checkbox_resolution'),
        );
        expect(resCheckboxFinder, findsOneWidget);
        await tester.tap(find.byKey(const Key('track_col_menu_resolution')));
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: header, matching: find.text('Resolution')),
          findsNothing,
        );
        expect(tester.widget<ShadCheckbox>(resCheckboxFinder).value, isFalse);
        expect(changedColumns?.contains(TrackColumn.resolution), isFalse);

        // 3. Attempt to toggle mandatory Title & Artist column (must remain visible)
        final titleItemFinder = find.byKey(const Key('track_col_menu_title'));
        expect(titleItemFinder, findsOneWidget);
        await tester.tap(titleItemFinder);
        await tester.pumpAndSettle();

        // Mandatory title column is still checked and visible
        expect(
          find.descendant(of: header, matching: find.text('Title & Artist')),
          findsOneWidget,
        );
        expect(find.text('Track One'), findsOneWidget);
        final titleCheckboxFinder = find.byKey(
          const Key('track_col_checkbox_title'),
        );
        expect(tester.widget<ShadCheckbox>(titleCheckboxFinder).value, isTrue);

        // 4. Toggle Album back on
        await tester.tap(find.byKey(const Key('track_col_menu_album')));
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: header, matching: find.text('Album')),
          findsOneWidget,
        );
        expect(find.text('Album X'), findsOneWidget);
        expect(find.text('Album Y'), findsOneWidget);
        expect(tester.widget<ShadCheckbox>(albumCheckboxFinder).value, isTrue);
        expect(changedColumns?.contains(TrackColumn.album), isTrue);
      },
    );

    testWidgets(
      'TracksView column checkbox provides instant zero-latency visual feedback and overlay card has RepaintBoundary',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildTracksViewTest(tracks: sampleTracks));
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('tracks_table_header'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify overlay floating card is wrapped in a RepaintBoundary
        final card = find.byKey(const Key('tracks_columns_window'));
        expect(card, findsOneWidget);
        expect(
          find.ancestor(of: card, matching: find.byType(RepaintBoundary)),
          findsWidgets,
        );

        final albumCheckboxFinder = find.byKey(
          const Key('track_col_checkbox_album'),
        );
        expect(tester.widget<ShadCheckbox>(albumCheckboxFinder).value, isTrue);

        // Tap to toggle off Album
        await tester.tap(find.byKey(const Key('track_col_menu_album')));
        // Single frame pump - instant visual feedback before table settle
        await tester.pump();
        expect(tester.widget<ShadCheckbox>(albumCheckboxFinder).value, isFalse);

        await tester.pumpAndSettle();
        expect(
          find.descendant(of: header, matching: find.text('Album')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'TracksView right-clicking header displays refined Shadcn card with COLUMNS header, Reset button, and grip handles',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildTracksViewTest(tracks: sampleTracks));
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('tracks_table_header'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Refined card header
        expect(find.text('COLUMNS'), findsOneWidget);
        expect(
          find.byKey(const Key('tracks_columns_reset_button')),
          findsOneWidget,
        );
        expect(find.text('Reset'), findsOneWidget);

        // Grip handles for each column
        final gripHandles = find.byIcon(LucideIcons.gripVertical);
        expect(gripHandles, findsNWidgets(TrackColumn.values.length));

        // Lock icon on mandatory title column
        final lockIcon = find.byIcon(LucideIcons.lock);
        expect(lockIcon, findsOneWidget);
      },
    );

    testWidgets(
      'TracksView dragging column in context menu reorders table header and rows dynamically',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        List<TrackColumn>? newColumnOrder;

        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: sampleTracks,
            onColumnOrderChanged: (order) => newColumnOrder = order,
          ),
        );
        await tester.pumpAndSettle();

        // Initially: # is first column, Time is last column
        final header = find.byKey(const Key('tracks_table_header'));
        final headerHashFinder = find.text('#');
        final headerTimeFinder = find.descendant(
          of: header,
          matching: find.text('Time'),
        );
        expect(
          tester.getTopLeft(headerHashFinder).dx,
          lessThan(tester.getTopLeft(headerTimeFinder).dx),
        );

        // Right-click header to open column context menu
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Drag duration (from end of list) up above index 0 (drag by -450px)
        final durationGrip = find.descendant(
          of: find.byKey(const Key('track_col_menu_duration')),
          matching: find.byIcon(LucideIcons.gripVertical),
        );
        expect(durationGrip, findsOneWidget);

        await tester.timedDrag(
          durationGrip,
          const Offset(0, -450),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();

        // Callback should have received duration as first column
        expect(newColumnOrder, isNotNull);
        expect(newColumnOrder!.first, equals(TrackColumn.duration));

        // In table header, Time should now be to the left of #
        final newTimeLeft = tester
            .getTopLeft(
              find.descendant(of: header, matching: find.text('Time')),
            )
            .dx;
        final newHashLeft = tester.getTopLeft(find.text('#')).dx;
        expect(newTimeLeft, lessThan(newHashLeft));

        // In table row 1, duration is also now to the left of track index 1
        final rowTimeLeft = tester
            .getTopLeft(find.text(sampleTracks.first.formattedDuration))
            .dx;
        final rowIndexLeft = tester.getTopLeft(find.text('1')).dx;
        expect(rowTimeLeft, lessThan(rowIndexLeft));

        // Now test Reset button restores default column order
        await tester.tap(find.byKey(const Key('tracks_columns_reset_button')));
        await tester.pumpAndSettle();

        expect(newColumnOrder, equals(TrackColumn.values));
        final restoredHashLeft = tester.getTopLeft(find.text('#')).dx;
        final restoredTimeLeft = tester
            .getTopLeft(
              find.descendant(of: header, matching: find.text('Time')),
            )
            .dx;
        expect(restoredHashLeft, lessThan(restoredTimeLeft));
      },
    );

    testWidgets(
      'TracksView safely normalizes empty or partial column orders and visible columns',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Test empty columnOrder and visibleColumns
        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: sampleTracks,
            columnOrder: const [],
            visibleColumns: const {},
          ),
        );
        await tester.pumpAndSettle();

        // Should safely fallback to default columns without throwing
        expect(find.text('#'), findsOneWidget);
        expect(find.text('Title & Artist'), findsOneWidget);
        expect(find.text('Time'), findsOneWidget);

        // 2. Test partial columnOrder (e.g. only duration specified)
        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: sampleTracks,
            columnOrder: const [TrackColumn.duration],
          ),
        );
        await tester.pumpAndSettle();

        // duration should be first, and remaining columns appended safely
        final durationLeft = tester.getTopLeft(find.text('Time')).dx;
        final hashLeft = tester.getTopLeft(find.text('#')).dx;
        expect(durationLeft, lessThan(hashLeft));
        expect(find.text('Title & Artist'), findsOneWidget);
      },
    );

    testWidgets(
      'TracksView toggles newly added columns (work, iswc, year, musicbrainzId, isrc, genre, trackNumber) on/off and renders properly',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const detailedTracks = [
          Track(
            id: 'trk-101',
            title: 'Symphony No. 9',
            artistName: 'Beethoven & Karajan',
            albumTitle: '9 Symphonies',
            workTitle: 'Symphony No. 9 "Choral"',
            recordingYear: 1977,
            trackNumber: 4,
            genre: 'Classical',
            iswc: 'T-070.240.123-1',
            isrc: 'DEF057700125',
            musicbrainzId: 'mb-trk-beethoven-9',
            durationMs: 1455000,
            format: 'FLAC',
            sampleRate: 96000,
            bitDepth: 24,
          ),
        ];

        Set<TrackColumn> visible = Set<TrackColumn>.from(
          TrackColumn.defaultVisibleColumns,
        );

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return _buildTracksViewTest(
                tracks: detailedTracks,
                visibleColumns: visible,
                onVisibleColumnsChanged: (newCols) {
                  setState(() => visible = newCols);
                },
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // Initially new columns are not visible
        expect(find.text('Work'), findsNothing);
        expect(find.text('ISWC'), findsNothing);
        expect(find.text('Year'), findsNothing);
        expect(find.text('MusicBrainz ID'), findsNothing);
        expect(find.text('ISRC'), findsNothing);
        expect(find.text('Genre'), findsNothing);
        expect(find.text('Trk#'), findsNothing);

        // Open context menu
        final header = find.byKey(const Key('tracks_table_header'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Toggle on all new columns
        await tester.tap(find.byKey(const Key('track_col_menu_work')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('track_col_menu_iswc')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('track_col_menu_year')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('track_col_menu_musicbrainzId')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('track_col_menu_isrc')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('track_col_menu_genre')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('track_col_menu_trackNumber')));
        await tester.pumpAndSettle();

        // Verify headers are now rendered
        final tableHeader = find.byKey(const Key('tracks_table_header'));
        expect(
          find.descendant(of: tableHeader, matching: find.text('Work')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tableHeader, matching: find.text('ISWC')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tableHeader, matching: find.text('Year')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: tableHeader,
            matching: find.text('MusicBrainz ID'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tableHeader, matching: find.text('ISRC')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tableHeader, matching: find.text('Genre')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tableHeader, matching: find.text('Trk#')),
          findsOneWidget,
        );

        // Verify row values are rendered with correct typography/badges
        expect(find.text('Symphony No. 9 "Choral"'), findsOneWidget);
        expect(find.text('T-070.240.123-1'), findsOneWidget);
        expect(find.text('1977'), findsOneWidget);
        expect(find.text('mb-trk-beethoven-9'), findsOneWidget);
        expect(find.text('DEF057700125'), findsOneWidget);
        expect(find.text('Classical'), findsOneWidget);
        expect(find.text('4'), findsWidgets); // index + trackNumber

        // Toggle work back off
        await tester.tap(find.byKey(const Key('track_col_menu_work')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: tableHeader, matching: find.text('Work')),
          findsNothing,
        );
        expect(find.text('Symphony No. 9 "Choral"'), findsNothing);
      },
    );

    testWidgets(
      'TracksView dragging work column to the top reorders it dynamically',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        List<TrackColumn>? newColumnOrder;

        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: sampleTracks,
            visibleColumns: TrackColumn.values.toSet(),
            onColumnOrderChanged: (order) => newColumnOrder = order,
          ),
        );
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('tracks_table_header'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        final workGrip = find.descendant(
          of: find.byKey(const Key('track_col_menu_work')),
          matching: find.byIcon(LucideIcons.gripVertical),
        );
        expect(workGrip, findsOneWidget);

        await tester.timedDrag(
          workGrip,
          const Offset(0, -250),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();

        expect(newColumnOrder, isNotNull);
        expect(newColumnOrder!.first, equals(TrackColumn.work));
      },
    );

    testWidgets(
      'TracksView column spacing ensures items to the right of TIME have >= 16px gutter separation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Place duration (TIME) before title so there is an item to the right of TIME
        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: sampleTracks,
            columnOrder: const [
              TrackColumn.duration,
              TrackColumn.title,
              TrackColumn.album,
            ],
            visibleColumns: {
              TrackColumn.duration,
              TrackColumn.title,
              TrackColumn.album,
            },
          ),
        );
        await tester.pumpAndSettle();

        // Check header separation between Time and Title & Artist
        final timeHeaderFinder = find.text('Time');
        final titleHeaderFinder = find.text('Title & Artist');
        expect(timeHeaderFinder, findsOneWidget);
        expect(titleHeaderFinder, findsOneWidget);

        final timeHeaderRight = tester.getTopRight(timeHeaderFinder).dx;
        final titleHeaderLeft = tester.getTopLeft(titleHeaderFinder).dx;
        expect(titleHeaderLeft - timeHeaderRight, greaterThanOrEqualTo(16.0));

        // Check row cell separation between formattedDuration and track displayTitle
        final durationRowFinder = find.text(
          sampleTracks.first.formattedDuration,
        );
        final titleRowFinder = find.text(sampleTracks.first.displayTitle);
        expect(durationRowFinder, findsOneWidget);
        expect(titleRowFinder, findsOneWidget);

        final durationRowRight = tester.getTopRight(durationRowFinder).dx;
        final titleRowLeft = tester.getTopLeft(titleRowFinder).dx;
        expect(titleRowLeft - durationRowRight, greaterThanOrEqualTo(16.0));
      },
    );

    testWidgets(
      'TracksView newly added columns appear before Time by default',
      (tester) async {
        expect(TrackColumn.values.last, equals(TrackColumn.duration));
        expect(TrackColumn.duration.label, equals('Time'));
        expect(TrackColumn.duration.width, equals(76.0));
      },
    );

    testWidgets(
      'TracksView column customization window is draggable and clamped within screen boundaries',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildTracksViewTest(tracks: sampleTracks));
        await tester.pumpAndSettle();

        // Right-click header
        final header = find.byKey(const Key('tracks_table_header'));
        final headerCenter = tester.getCenter(header);
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(headerCenter);
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify window is open and positioned
        final windowFinder = find.byKey(const Key('tracks_columns_window'));
        final headerFinder = find.byKey(
          const Key('tracks_columns_window_header'),
        );
        expect(windowFinder, findsOneWidget);
        expect(headerFinder, findsOneWidget);

        final initialPos = tester.getTopLeft(windowFinder);
        expect(initialPos.dx, equals(headerCenter.dx));
        expect(initialPos.dy, equals(headerCenter.dy));

        // Drag header by (120, 80)
        await tester.drag(headerFinder, const Offset(120, 80));
        await tester.pumpAndSettle();

        final movedPos = tester.getTopLeft(windowFinder);
        expect(movedPos.dx, equals(initialPos.dx + 120.0));
        expect(movedPos.dy, equals(initialPos.dy + 80.0));

        // Drag far beyond right and bottom edges -> must clamp within screen
        await tester.drag(headerFinder, const Offset(2000, 2000));
        await tester.pumpAndSettle();

        final clampedBottomRight = tester.getTopLeft(windowFinder);
        expect(clampedBottomRight.dx, equals(1280.0 - 270.0 - 8.0));
        expect(clampedBottomRight.dy, lessThanOrEqualTo(800.0 - 100.0));

        // Drag far beyond top and left edges -> must clamp to (8, 8)
        await tester.drag(headerFinder, const Offset(-5000, -5000));
        await tester.pumpAndSettle();

        final clampedLeftTop = tester.getTopLeft(windowFinder);
        expect(clampedLeftTop.dx, equals(8.0));
        expect(clampedLeftTop.dy, equals(8.0));

        // Dismissal test 1: Click 'X' close button
        final closeButton = find.byKey(
          const Key('tracks_columns_close_button'),
        );
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tracks_columns_window')), findsNothing);

        // Reopen via long press
        await tester.longPress(header);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tracks_columns_window')), findsOneWidget);

        // Dismissal test 2: Press Escape key
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tracks_columns_window')), findsNothing);

        // Reopen via right-click
        await gesture.down(headerCenter);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tracks_columns_window')), findsOneWidget);

        // Dismissal test 3: Tap outside
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tracks_columns_window')), findsNothing);
      },
    );

    testWidgets(
      'TracksView column header sorting works ascending, descending, and reset',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const unsortedTracks = [
          Track(
            id: '1',
            title: 'Zebra',
            artistName: 'Artist A',
            albumTitle: 'Album X',
            format: 'FLAC 24/96',
            durationMs: 252000,
            sampleRate: 96000,
            bitDepth: 24,
          ),
          Track(
            id: '2',
            title: 'Alpha',
            artistName: 'Artist B',
            albumTitle: 'Album Y',
            format: 'DSD 5.6MHz',
            durationMs: 330000,
            sampleRate: 5644800,
            bitDepth: 1,
          ),
        ];

        await tester.pumpWidget(_buildTracksViewTest(tracks: unsortedTracks));
        await tester.pumpAndSettle();

        // Initially unsorted: Zebra is first, Alpha is second
        expect(
          tester.getTopLeft(find.text('Zebra')).dy,
          lessThan(tester.getTopLeft(find.text('Alpha')).dy),
        );

        // Tap Title & Artist header to sort ascending
        final titleHeader = find.text('Title & Artist');
        await tester.tap(titleHeader);
        await tester.pumpAndSettle();

        // Now sorted ascending: Alpha is first, Zebra is second
        expect(
          tester.getTopLeft(find.text('Alpha')).dy,
          lessThan(tester.getTopLeft(find.text('Zebra')).dy),
        );
        expect(find.byIcon(LucideIcons.arrowUp), findsOneWidget);

        // Tap Title & Artist header again to sort descending
        await tester.tap(titleHeader);
        await tester.pumpAndSettle();

        // Now sorted descending: Zebra is first, Alpha is second
        expect(
          tester.getTopLeft(find.text('Zebra')).dy,
          lessThan(tester.getTopLeft(find.text('Alpha')).dy),
        );
        expect(find.byIcon(LucideIcons.arrowDown), findsOneWidget);

        // Tap Title & Artist header again to reset sort
        await tester.tap(titleHeader);
        await tester.pumpAndSettle();

        // Unsorted again: Zebra is first, Alpha is second
        expect(
          tester.getTopLeft(find.text('Zebra')).dy,
          lessThan(tester.getTopLeft(find.text('Alpha')).dy),
        );
        expect(find.byIcon(LucideIcons.arrowUp), findsNothing);
        expect(find.byIcon(LucideIcons.arrowDown), findsNothing);
      },
    );

    testWidgets(
      'TracksView renders Import Audio CTA button in empty state and triggers onImport',
      (tester) async {
        bool importCalled = false;
        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: const [],
            onImport: () => importCalled = true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No tracks found'), findsOneWidget);
        final importButton = find.text('Import Audio');
        expect(importButton, findsOneWidget);

        await tester.tap(importButton);
        await tester.pumpAndSettle();

        expect(importCalled, isTrue);

        // Verify Import Audio is NOT shown when filterLabel is present
        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: const [],
            filterLabel: 'Test',
            onImport: () => importCalled = true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Import Audio'), findsNothing);
      },
    );

    testWidgets(
      'TracksView renders fallback dash for empty string iswc, isrc, and musicbrainzId',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const emptyMetaTracks = [
          Track(
            id: 'trk-empty-1',
            title: 'Empty Meta Track',
            artistName: 'Artist',
            albumTitle: 'Album',
            iswc: '',
            isrc: '',
            musicbrainzId: '',
          ),
        ];

        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: emptyMetaTracks,
            visibleColumns: {
              TrackColumn.title,
              TrackColumn.iswc,
              TrackColumn.isrc,
              TrackColumn.musicbrainzId,
            },
          ),
        );
        await tester.pumpAndSettle();

        // Check fallback '-'
        expect(find.text('-'), findsNWidgets(3));
      },
    );

    testWidgets(
      'TracksView sorts by resolution, iswc, isrc, and musicbrainzId',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const sortTracks = [
          Track(
            id: 'trk-b',
            title: 'Track B',
            artistName: 'Artist',
            albumTitle: 'Album',
            format: 'MP3',
            sampleRate: 44100,
            bitDepth: 16,
            iswc: 'T-222',
            isrc: 'ISRC-B',
            musicbrainzId: 'mb-b',
          ),
          Track(
            id: 'trk-a',
            title: 'Track A',
            artistName: 'Artist',
            albumTitle: 'Album',
            format: 'FLAC',
            sampleRate: 96000,
            bitDepth: 24,
            iswc: 'T-111',
            isrc: 'ISRC-A',
            musicbrainzId: 'mb-a',
          ),
        ];

        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: sortTracks,
            visibleColumns: {
              TrackColumn.title,
              TrackColumn.resolution,
              TrackColumn.iswc,
              TrackColumn.isrc,
              TrackColumn.musicbrainzId,
            },
          ),
        );
        await tester.pumpAndSettle();

        // 1. Sort by resolution
        await tester.tap(find.text('Resolution'));
        await tester.pumpAndSettle();
        expect(find.text('Track A'), findsOneWidget);

        // 2. Sort by iswc
        await tester.tap(find.text('ISWC'));
        await tester.pumpAndSettle();
        expect(find.text('T-111'), findsOneWidget);

        // 3. Sort by isrc
        await tester.tap(find.text('ISRC'));
        await tester.pumpAndSettle();
        expect(find.text('ISRC-A'), findsOneWidget);

        // 4. Sort by musicbrainzId
        await tester.tap(find.text('MusicBrainz ID'));
        await tester.pumpAndSettle();
        expect(find.text('mb-a'), findsOneWidget);
      },
    );

    testWidgets(
      'TracksView triggers onClearFilter via LyraButton.outline in empty state',
      (tester) async {
        bool clearCalled = false;
        await tester.pumpWidget(
          _buildTracksViewTest(
            tracks: const [],
            filterLabel: 'Active Filter',
            onClearFilter: () => clearCalled = true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Clear filter'), findsOneWidget);
        expect(find.byType(LyraButton), findsOneWidget);
        await tester.tap(find.text('Clear filter'));
        await tester.pumpAndSettle();

        expect(clearCalled, isTrue);
      },
    );

    testWidgets(
      'TracksView adapts itemExtent dynamically under text scaling without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const tracks = [
          Track(
            id: 'trk-1',
            title: 'Track 1',
            artistName: 'Artist 1',
            albumTitle: 'Album 1',
          ),
        ];

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: _buildTracksViewTest(tracks: tracks),
          ),
        );
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(find.byType(ListView).first);
        expect(listView.itemExtent, 56.0 * 1.5);
      },
    );
  });
}
