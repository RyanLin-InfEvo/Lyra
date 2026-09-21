// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_splitter.dart';
import 'package:ui/features/inspector/audio_inspector_drawer.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/settings/services/preferences_service.dart';
import 'package:ui/features/shell/app_shell.dart';
import 'package:ui/features/shell/sidebar.dart';
import 'package:ui/features/tracks/tracks_view.dart';

Widget _buildSplitterApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(themeMode);
  final isDark = themeMode == ThemeMode.dark;
  final tokens = isDark ? LyraThemeTokens.dark() : LyraThemeTokens.light();
  return ShadApp(
    home: ShadTheme(
      data: ShadThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        colorScheme: isDark
            ? const ShadZincColorScheme.dark()
            : const ShadZincColorScheme.light(),
      ),
      child: LyraDesignSystemScope(
        factory: const ShadcnFactory(),
        tokens: tokens,
        themeModeNotifier: themeModeNotifier,
        child: Scaffold(body: child),
      ),
    ),
  );
}

Widget _buildAppShellWithPrefs({
  required PreferencesService preferencesService,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  return ShadApp(
    home: ShadTheme(
      data: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      child: LyraDesignSystemScope(
        factory: const ShadcnFactory(),
        tokens: LyraThemeTokens.dark(),
        themeModeNotifier: themeModeNotifier,
        child: AppShell(
          musicService: MockMusicService(),
          preferencesService: preferencesService,
        ),
      ),
    ),
  );
}

class CallCountingPreferencesService extends InMemoryPreferencesService {
  int setSidebarWidthCalls = 0;
  int setInspectorWidthCalls = 0;
  int setTrackColumnWidthsCalls = 0;

  CallCountingPreferencesService({
    super.sidebarWidth,
    super.inspectorWidth,
    super.trackColumnWidths,
  });

  @override
  Future<void> setSidebarWidth(double width) async {
    setSidebarWidthCalls++;
    return super.setSidebarWidth(width);
  }

  @override
  Future<void> setInspectorWidth(double width) async {
    setInspectorWidthCalls++;
    return super.setInspectorWidth(width);
  }

  @override
  Future<void> setTrackColumnWidths(Map<String, double> widths) async {
    setTrackColumnWidthsCalls++;
    return super.setTrackColumnWidths(widths);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyraSplitter Component Tests', () {
    testWidgets(
      'renders MouseRegion with resizeLeftRight cursor and handles gestures',
      (tester) async {
        double totalDelta = 0.0;
        bool dragStarted = false;
        bool dragEnded = false;
        bool doubleTapped = false;

        await tester.pumpWidget(
          _buildSplitterApp(
            child: Center(
              child: SizedBox(
                height: 200.0,
                child: LyraSplitter(
                  onDelta: (d) => totalDelta += d,
                  onDragStart: () => dragStarted = true,
                  onDragEnd: () => dragEnded = true,
                  onDoubleTap: () => doubleTapped = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify MouseRegion cursor
        final mouseRegion = tester.widget<MouseRegion>(
          find.descendant(
            of: find.byType(LyraSplitter),
            matching: find.byType(MouseRegion),
          ),
        );
        expect(mouseRegion.cursor, SystemMouseCursors.resizeLeftRight);

        // Verify drag gestures
        final splitterFinder = find.byType(LyraSplitter);
        await tester.drag(splitterFinder, const Offset(30.0, 0.0));
        await tester.pumpAndSettle();

        expect(dragStarted, isTrue);
        expect(dragEnded, isTrue);
        // HorizontalDragGestureRecognizer consumes ~20px slop before reporting deltas
        expect(totalDelta, closeTo(10.0, 0.1));

        // Verify double tap
        await tester.tap(splitterFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(splitterFinder);
        await tester.pumpAndSettle();

        expect(doubleTapped, isTrue);
      },
    );
  });

  group('AppShell Split View Resizing Tests', () {
    testWidgets(
      'sidebar_resize_handle drags and resizes sidebar width, clamps, and double-taps to reset with zero layout gap',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = InMemoryPreferencesService(sidebarWidth: 210.0);
        await tester.pumpWidget(
          _buildAppShellWithPrefs(preferencesService: prefs),
        );
        await tester.pumpAndSettle();

        // Verify no standalone splitter exists in AppShell (0px gap)
        expect(find.byType(LyraSplitter), findsNothing);

        // Initially 210.0
        final sidebarFinder = find.byType(LyraSidebar);
        expect(tester.getSize(sidebarFinder).width, 210.0);

        final handleFinder = find.byKey(const Key('sidebar_resize_handle'));
        expect(handleFinder, findsOneWidget);

        // Drag right by 60px (20px slop + 40px delta) -> width should be 250.0
        await tester.drag(handleFinder, const Offset(60.0, 0.0));
        await tester.pumpAndSettle();

        expect(tester.getSize(sidebarFinder).width, 250.0);
        expect(prefs.sidebarWidth, 250.0);

        // Drag far right by 300px -> clamped to 420.0
        await tester.drag(handleFinder, const Offset(300.0, 0.0));
        await tester.pumpAndSettle();

        expect(tester.getSize(sidebarFinder).width, 420.0);
        expect(prefs.sidebarWidth, 420.0);

        // Drag far left by 400px -> clamped to 160.0
        await tester.drag(handleFinder, const Offset(-400.0, 0.0));
        await tester.pumpAndSettle();

        expect(tester.getSize(sidebarFinder).width, 160.0);
        expect(prefs.sidebarWidth, 160.0);

        // Double tap handle -> resets to default 210.0
        await tester.tap(handleFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(handleFinder);
        await tester.pumpAndSettle();

        expect(tester.getSize(sidebarFinder).width, 210.0);
        expect(prefs.sidebarWidth, 210.0);
      },
    );

    testWidgets('collapsing sidebar hides sidebar_resize_handle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final prefs = InMemoryPreferencesService(isSidebarCollapsed: false);
      await tester.pumpWidget(
        _buildAppShellWithPrefs(preferencesService: prefs),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sidebar_resize_handle')), findsOneWidget);

      // Toggle collapse via Collapse sidebar tooltip
      final collapseBtn = find.byTooltip('Collapse sidebar');
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sidebar_resize_handle')), findsNothing);
    });

    testWidgets(
      'inspector_resize_handle drags and resizes inspector width and double-taps to reset',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = InMemoryPreferencesService(inspectorWidth: 420.0);
        await tester.pumpWidget(
          _buildAppShellWithPrefs(preferencesService: prefs),
        );
        await tester.pumpAndSettle();

        // Open inspector via Meta+I
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pumpAndSettle();

        expect(find.byType(AudioInspectorDrawer), findsOneWidget);
        // Verify no standalone splitter exists in AppShell
        expect(find.byType(LyraSplitter), findsNothing);

        final inspectorHandle = find.byKey(
          const Key('inspector_resize_handle'),
        );
        expect(inspectorHandle, findsOneWidget);

        final inspectorFinder = find.byType(AudioInspectorDrawer);
        expect(tester.getSize(inspectorFinder).width, 420.0);

        // Drag inspector edge to the left by 70px (20px slop + 50px delta) -> inspector grows to 470.0
        await tester.drag(inspectorHandle, const Offset(-70.0, 0.0));
        await tester.pumpAndSettle();

        expect(tester.getSize(inspectorFinder).width, 470.0);
        expect(prefs.inspectorWidth, 470.0);

        // Double tap inspector handle -> resets to 420.0
        await tester.tap(inspectorHandle);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(inspectorHandle);
        await tester.pumpAndSettle();

        expect(tester.getSize(inspectorFinder).width, 420.0);
        expect(prefs.inspectorWidth, 420.0);
      },
    );

    testWidgets(
      'sidebar edge drag updates do NOT call setSidebarWidth on mouse move, saving only on drag end',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final countingPrefs = CallCountingPreferencesService(
          sidebarWidth: 210.0,
        );
        await tester.pumpWidget(
          _buildAppShellWithPrefs(preferencesService: countingPrefs),
        );
        await tester.pumpAndSettle();

        final handleFinder = find.byKey(const Key('sidebar_resize_handle'));
        final gesture = await tester.startGesture(
          tester.getCenter(handleFinder),
        );
        await tester.pump();

        await gesture.moveBy(const Offset(30.0, 0.0));
        await tester.pump();
        await gesture.moveBy(const Offset(30.0, 0.0));
        await tester.pump();
        await gesture.moveBy(const Offset(30.0, 0.0));
        await tester.pump();

        // During dragging moves, preferences must NOT be invoked!
        expect(countingPrefs.setSidebarWidthCalls, 0);

        // When releasing drag gesture, saved exactly once!
        await gesture.up();
        await tester.pumpAndSettle();

        expect(countingPrefs.setSidebarWidthCalls, 1);
        expect(countingPrefs.sidebarWidth, closeTo(270.0, 1.0));
      },
    );

    testWidgets(
      'inspector edge drag updates do NOT call setInspectorWidth on mouse move, saving only on drag end',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final countingPrefs = CallCountingPreferencesService(
          inspectorWidth: 420.0,
        );
        await tester.pumpWidget(
          _buildAppShellWithPrefs(preferencesService: countingPrefs),
        );
        await tester.pumpAndSettle();

        // Open inspector
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pumpAndSettle();

        final inspectorHandle = find.byKey(
          const Key('inspector_resize_handle'),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(inspectorHandle),
        );
        await tester.pump();

        await gesture.moveBy(const Offset(-30.0, 0.0));
        await tester.pump();
        await gesture.moveBy(const Offset(-30.0, 0.0));
        await tester.pump();

        // During dragging moves, preferences must NOT be invoked!
        expect(countingPrefs.setInspectorWidthCalls, 0);

        // When releasing drag gesture, saved exactly once!
        await gesture.up();
        await tester.pumpAndSettle();

        expect(countingPrefs.setInspectorWidthCalls, 1);
        expect(countingPrefs.inspectorWidth, closeTo(450.0, 1.0));
      },
    );
  });

  group('TracksView Column Width Resizing Tests', () {
    testWidgets('drag column resize handle resizes column width and persists', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final prefs = InMemoryPreferencesService();
      final tracks = const [
        Track(
          id: 't1',
          title: 'Test Track',
          artistName: 'Test Artist',
          albumTitle: 'Test Album',
          durationMs: 180000,
        ),
      ];

      Map<String, double>? reportedWidths;

      await tester.pumpWidget(
        _buildSplitterApp(
          child: TracksView(
            tracks: tracks,
            currentTrack: null,
            isPlaying: false,
            preferencesService: prefs,
            onTrackSelected: (_) {},
            onTogglePlay: () {},
            onColumnWidthsChanged: (w) => reportedWidths = w,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locate resize handle for title column
      final titleHandleFinder = find.byKey(
        const Key('column_resize_handle_title'),
      );
      expect(titleHandleFinder, findsOneWidget);

      // Drag handle right by 60px
      await tester.drag(titleHandleFinder, const Offset(60.0, 0.0));
      await tester.pumpAndSettle();

      expect(reportedWidths, isNotNull);
      expect(reportedWidths!['title'], isNotNull);
      expect(prefs.trackColumnWidths['title'], isNotNull);

      // Double-tap handle resets width
      await tester.tap(titleHandleFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(titleHandleFinder);
      await tester.pumpAndSettle();

      expect(reportedWidths!.containsKey('title'), isFalse);
      expect(prefs.trackColumnWidths.containsKey('title'), isFalse);
    });

    testWidgets('drag column resize handle clamps to minWidth', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final prefs = InMemoryPreferencesService();
      final tracks = const [
        Track(
          id: 't1',
          title: 'Test Track',
          artistName: 'Test Artist',
          albumTitle: 'Test Album',
          durationMs: 180000,
        ),
      ];

      Map<String, double>? reportedWidths;

      await tester.pumpWidget(
        _buildSplitterApp(
          child: TracksView(
            tracks: tracks,
            currentTrack: null,
            isPlaying: false,
            preferencesService: prefs,
            onTrackSelected: (_) {},
            onTogglePlay: () {},
            onColumnWidthsChanged: (w) => reportedWidths = w,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title column minWidth is 70.0
      final titleHandleFinder = find.byKey(
        const Key('column_resize_handle_title'),
      );
      await tester.drag(titleHandleFinder, const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      expect(reportedWidths!['title'], 70.0);
      expect(prefs.trackColumnWidths['title'], 70.0);

      // Index column minWidth is 40.0
      final indexHandleFinder = find.byKey(
        const Key('column_resize_handle_index'),
      );
      await tester.drag(indexHandleFinder, const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      expect(reportedWidths!['index'], 40.0);
      expect(prefs.trackColumnWidths['index'], 40.0);
    });

    testWidgets(
      'initial trackColumnWidths from preferencesService are restored',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = InMemoryPreferencesService(
          trackColumnWidths: {'title': 350.0},
        );
        final tracks = const [
          Track(
            id: 't1',
            title: 'Test Track',
            artistName: 'Test Artist',
            albumTitle: 'Test Album',
            durationMs: 180000,
          ),
        ];

        await tester.pumpWidget(
          _buildSplitterApp(
            child: TracksView(
              tracks: tracks,
              currentTrack: null,
              isPlaying: false,
              preferencesService: prefs,
              onTrackSelected: (_) {},
              onTogglePlay: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleHeaderCell = find.byKey(const ValueKey('header_cell_title'));
        expect(titleHeaderCell, findsOneWidget);
        expect(tester.getSize(titleHeaderCell).width, 350.0);
      },
    );

    testWidgets(
      'tracks column drag updates do NOT call setTrackColumnWidths on mouse move, saving only on drag end',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final countingPrefs = CallCountingPreferencesService();
        const tracks = [
          Track(
            id: 't1',
            title: 'Test Track',
            artistName: 'Test Artist',
            albumTitle: 'Test Album',
            durationMs: 180000,
          ),
        ];

        await tester.pumpWidget(
          _buildSplitterApp(
            child: TracksView(
              tracks: tracks,
              currentTrack: null,
              isPlaying: false,
              preferencesService: countingPrefs,
              onTrackSelected: (_) {},
              onTogglePlay: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleHandleFinder = find.byKey(
          const Key('column_resize_handle_title'),
        );
        expect(titleHandleFinder, findsOneWidget);

        // Before drag, zero calls
        expect(countingPrefs.setTrackColumnWidthsCalls, 0);

        // Drag column handle right by 60px
        await tester.drag(titleHandleFinder, const Offset(60.0, 0.0));
        await tester.pumpAndSettle();

        // Exactly 1 call upon drag end (never on each drag update)
        expect(countingPrefs.setTrackColumnWidthsCalls, 1);
        expect(countingPrefs.trackColumnWidths['title'], isNotNull);
      },
    );
  });
}
