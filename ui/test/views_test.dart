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
import 'package:ui/features/artists/artists_view.dart';
import 'package:ui/features/models/artist.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/work.dart';
import 'package:ui/features/playlists/playlists_view.dart';
import 'package:ui/features/works/works_view.dart';

Widget _buildViewTest(Widget child, {ValueNotifier<ThemeMode>? themeNotifier}) {
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
            child: Scaffold(body: child),
          ),
        );
      },
    ),
  );
}

void main() {
  group('WorksView Tests', () {
    final sampleWorks = [
      const Work(
        id: 'wrk-1',
        title: 'Symphony No. 5 in C Minor',
        compositionStartYear: 1804,
        compositionEndYear: 1808,
        iswc: 'T-070.111.222-3',
        musicbrainzId: 'mb-1',
      ),
      const Work(
        id: 'wrk-2',
        title: 'Kind of Blue Compositions',
        compositionDateText: '1959',
      ),
    ];

    testWidgets('WorksView renders empty state', (tester) async {
      await tester.pumpWidget(_buildViewTest(const WorksView(works: [])));
      await tester.pumpAndSettle();

      expect(find.text('No musical works found'), findsOneWidget);
    });

    testWidgets('WorksView renders list and triggers selection', (
      tester,
    ) async {
      Work? selectedWork;

      await tester.pumpWidget(
        _buildViewTest(
          WorksView(
            works: sampleWorks,
            onWorkSelected: (w) => selectedWork = w,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Musical Works'), findsOneWidget);
      expect(find.text('Symphony No. 5 in C Minor'), findsOneWidget);
      expect(find.text('1804–1808'), findsOneWidget);
      expect(find.text('T-070.111.222-3'), findsOneWidget);

      await tester.tap(find.text('Symphony No. 5 in C Minor'));
      await tester.pumpAndSettle();
      expect(selectedWork?.id, equals('wrk-1'));
    });

    testWidgets(
      'WorksView right-clicking header opens context menu with column checkboxes and toggling hides/shows columns',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        Set<WorkColumn>? changedColumns;

        await tester.pumpWidget(
          _buildViewTest(
            WorksView(
              works: sampleWorks,
              onVisibleColumnsChanged: (cols) => changedColumns = cols,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial visible headers
        expect(find.text('#'), findsOneWidget);
        expect(find.text('COMPOSITION TITLE'), findsOneWidget);
        expect(find.text('COMPOSER'), findsOneWidget);
        expect(find.text('COMPOSITION YEAR / DATE'), findsOneWidget);
        expect(find.text('ISWC'), findsOneWidget);
        expect(find.text('MUSICBRAINZ ID'), findsOneWidget);

        // Initial rows
        expect(find.text('1804–1808'), findsOneWidget);
        expect(find.text('T-070.111.222-3'), findsOneWidget);
        expect(find.text('mb-1'), findsOneWidget);

        // Right click header
        final header = find.byKey(const Key('works_table_header'));
        expect(header, findsOneWidget);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify context menu displays each column label
        expect(find.text('Track Number / Index'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Composer'), findsOneWidget);
        expect(find.text('Lyricist'), findsOneWidget);
        expect(find.text('Movement'), findsOneWidget);
        expect(find.text('Year / Date'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('work_col_menu_iswc')),
            matching: find.text('ISWC'),
          ),
          findsOneWidget,
        );
        expect(find.text('MusicBrainz ID'), findsOneWidget);

        // 1. Toggle off Year / Date
        final dateCheckboxFinder = find.byKey(
          const Key('work_col_checkbox_date'),
        );
        expect(dateCheckboxFinder, findsOneWidget);
        expect(tester.widget<ShadCheckbox>(dateCheckboxFinder).value, isTrue);

        await tester.tap(find.byKey(const Key('work_col_menu_date')));
        await tester.pumpAndSettle();

        expect(find.text('COMPOSITION YEAR / DATE'), findsNothing);
        expect(find.text('1804–1808'), findsNothing);
        expect(tester.widget<ShadCheckbox>(dateCheckboxFinder).value, isFalse);
        expect(changedColumns?.contains(WorkColumn.date), isFalse);

        // 2. Toggle off ISWC
        final iswcCheckboxFinder = find.byKey(
          const Key('work_col_checkbox_iswc'),
        );
        expect(iswcCheckboxFinder, findsOneWidget);
        await tester.tap(find.byKey(const Key('work_col_menu_iswc')));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const Key('works_table_header')),
            matching: find.text('ISWC'),
          ),
          findsNothing,
        );
        expect(find.text('T-070.111.222-3'), findsNothing);
        expect(tester.widget<ShadCheckbox>(iswcCheckboxFinder).value, isFalse);
        expect(changedColumns?.contains(WorkColumn.iswc), isFalse);

        // 3. Attempt to toggle mandatory Title column
        await tester.tap(find.byKey(const Key('work_col_menu_title')));
        await tester.pumpAndSettle();

        expect(find.text('COMPOSITION TITLE'), findsOneWidget);
        expect(find.text('Symphony No. 5 in C Minor'), findsOneWidget);
        final titleCheckboxFinder = find.byKey(
          const Key('work_col_checkbox_title'),
        );
        expect(tester.widget<ShadCheckbox>(titleCheckboxFinder).value, isTrue);

        // 4. Toggle Year / Date back on
        await tester.tap(find.byKey(const Key('work_col_menu_date')));
        await tester.pumpAndSettle();

        expect(find.text('COMPOSITION YEAR / DATE'), findsOneWidget);
        expect(find.text('1804–1808'), findsOneWidget);
        expect(tester.widget<ShadCheckbox>(dateCheckboxFinder).value, isTrue);
        expect(changedColumns?.contains(WorkColumn.date), isTrue);
      },
    );

    testWidgets(
      'WorksView column checkbox provides instant zero-latency visual feedback and overlay card has RepaintBoundary',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildViewTest(WorksView(works: sampleWorks)));
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('works_table_header'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify overlay floating card is wrapped in a RepaintBoundary
        final card = find.byKey(const Key('works_columns_window'));
        expect(card, findsOneWidget);
        expect(
          find.ancestor(of: card, matching: find.byType(RepaintBoundary)),
          findsWidgets,
        );

        final dateCheckboxFinder = find.byKey(
          const Key('work_col_checkbox_date'),
        );
        expect(tester.widget<ShadCheckbox>(dateCheckboxFinder).value, isTrue);

        // Tap to toggle off Date
        await tester.tap(find.byKey(const Key('work_col_menu_date')));
        // Single frame pump - instant visual feedback before table settle
        await tester.pump();
        expect(tester.widget<ShadCheckbox>(dateCheckboxFinder).value, isFalse);

        await tester.pumpAndSettle();
        expect(find.text('COMPOSITION YEAR / DATE'), findsNothing);
      },
    );

    testWidgets(
      'WorksView right-clicking header displays refined Shadcn card with COLUMNS header, Reset button, and grip handles',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildViewTest(WorksView(works: sampleWorks)));
        await tester.pumpAndSettle();

        final header = find.byKey(const Key('works_table_header'));
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
          find.byKey(const Key('works_columns_reset_button')),
          findsOneWidget,
        );
        expect(find.text('Reset'), findsOneWidget);

        // Grip handles for each column
        final gripHandles = find.byIcon(LucideIcons.gripVertical);
        expect(gripHandles, findsNWidgets(WorkColumn.values.length));

        // Lock icon on mandatory title column
        final lockIcon = find.byIcon(LucideIcons.lock);
        expect(lockIcon, findsOneWidget);
      },
    );

    testWidgets(
      'WorksView dragging column in context menu reorders table header and rows dynamically',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        List<WorkColumn>? newColumnOrder;

        await tester.pumpWidget(
          _buildViewTest(
            WorksView(
              works: sampleWorks,
              onColumnOrderChanged: (order) => newColumnOrder = order,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially: # is first column, MUSICBRAINZ ID is last column
        final headerHashFinder = find.text('#');
        final headerMbFinder = find.text('MUSICBRAINZ ID');
        expect(
          tester.getTopLeft(headerHashFinder).dx,
          lessThan(tester.getTopLeft(headerMbFinder).dx),
        );

        // Right-click header to open context menu
        final header = find.byKey(const Key('works_table_header'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Drag musicbrainzId (last index) up to top (index 0)
        final mbGrip = find.descendant(
          of: find.byKey(const Key('work_col_menu_musicbrainzId')),
          matching: find.byIcon(LucideIcons.gripVertical),
        );
        expect(mbGrip, findsOneWidget);

        await tester.timedDrag(
          mbGrip,
          const Offset(0, -320),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();

        expect(newColumnOrder, isNotNull);
        expect(newColumnOrder!.first, equals(WorkColumn.musicbrainzId));

        // In table header, MUSICBRAINZ ID is now to the left of #
        final newMbLeft = tester.getTopLeft(find.text('MUSICBRAINZ ID')).dx;
        final newHashLeft = tester.getTopLeft(find.text('#')).dx;
        expect(newMbLeft, lessThan(newHashLeft));

        // In table row 1, musicbrainz id (mb-1) is also now to the left of index 1
        final rowMbLeft = tester.getTopLeft(find.text('mb-1')).dx;
        final rowIndexLeft = tester.getTopLeft(find.text('1')).dx;
        expect(rowMbLeft, lessThan(rowIndexLeft));

        // Now test Reset button restores default column order
        await tester.tap(find.byKey(const Key('works_columns_reset_button')));
        await tester.pumpAndSettle();

        expect(newColumnOrder, equals(WorkColumn.values));
        final restoredHashLeft = tester.getTopLeft(find.text('#')).dx;
        final restoredMbLeft = tester
            .getTopLeft(find.text('MUSICBRAINZ ID'))
            .dx;
        expect(restoredHashLeft, lessThan(restoredMbLeft));
      },
    );

    testWidgets(
      'WorksView safely normalizes empty or partial column orders and visible columns',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Test empty columnOrder and visibleColumns
        await tester.pumpWidget(
          _buildViewTest(
            WorksView(
              works: sampleWorks,
              columnOrder: const [],
              visibleColumns: const {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should safely fallback to default columns without throwing
        expect(find.text('#'), findsOneWidget);
        expect(find.text('COMPOSITION TITLE'), findsOneWidget);
        expect(find.text('MUSICBRAINZ ID'), findsOneWidget);

        // 2. Test partial columnOrder (e.g. only musicbrainzId specified)
        await tester.pumpWidget(
          _buildViewTest(
            WorksView(
              works: sampleWorks,
              columnOrder: const [WorkColumn.musicbrainzId],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // musicbrainzId should be first, and remaining columns appended safely
        final mbLeft = tester.getTopLeft(find.text('MUSICBRAINZ ID')).dx;
        final hashLeft = tester.getTopLeft(find.text('#')).dx;
        expect(mbLeft, lessThan(hashLeft));
        expect(find.text('COMPOSITION TITLE'), findsOneWidget);
      },
    );

    testWidgets(
      'WorksView renders composer, lyricist, and movement columns and allows toggling',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const worksWithEnrichedData = [
          Work(
            id: 'wrk-001',
            title: 'Symphony No. 9 in D minor',
            composer: 'Ludwig van Beethoven',
            lyricist: 'Friedrich Schiller',
            movement: 'Ode to Joy',
            compositionStartYear: 1822,
            compositionEndYear: 1824,
          ),
        ];

        Set<WorkColumn> visible = Set<WorkColumn>.from(
          WorkColumn.defaultVisibleColumns,
        );

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return _buildViewTest(
                WorksView(
                  works: worksWithEnrichedData,
                  visibleColumns: visible,
                  onVisibleColumnsChanged: (newCols) {
                    setState(() => visible = newCols);
                  },
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // Composer is in defaultVisible
        expect(find.text('COMPOSER'), findsOneWidget);
        expect(find.text('Ludwig van Beethoven'), findsOneWidget);

        // Lyricist and Movement are initially hidden
        expect(find.text('LYRICIST'), findsNothing);
        expect(find.text('MOVEMENT'), findsNothing);

        // Right click header
        final header = find.byKey(const Key('works_table_header'));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(tester.getCenter(header));
        await gesture.up();
        await tester.pumpAndSettle();

        // Toggle on Lyricist and Movement
        await tester.tap(find.byKey(const Key('work_col_menu_lyricist')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('work_col_menu_movement')));
        await tester.pumpAndSettle();

        expect(find.text('LYRICIST'), findsOneWidget);
        expect(find.text('MOVEMENT'), findsOneWidget);
        expect(find.text('Friedrich Schiller'), findsOneWidget);
        expect(find.text('Ode to Joy'), findsOneWidget);
      },
    );

    testWidgets(
      'WorksView column customization window is draggable and clamped within screen boundaries',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildViewTest(WorksView(works: sampleWorks)));
        await tester.pumpAndSettle();

        // Right-click header
        final header = find.byKey(const Key('works_table_header'));
        final headerCenter = tester.getCenter(header);
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(headerCenter);
        await gesture.up();
        await tester.pumpAndSettle();

        // Verify window is open and positioned
        final windowFinder = find.byKey(const Key('works_columns_window'));
        final headerFinder = find.byKey(
          const Key('works_columns_window_header'),
        );
        expect(windowFinder, findsOneWidget);
        expect(headerFinder, findsOneWidget);

        final initialPos = tester.getTopLeft(windowFinder);
        expect(initialPos.dx, equals(headerCenter.dx));
        expect(initialPos.dy, equals(headerCenter.dy));

        // Drag header by (100, 70)
        await tester.drag(headerFinder, const Offset(100, 70));
        await tester.pumpAndSettle();

        final movedPos = tester.getTopLeft(windowFinder);
        expect(movedPos.dx, equals(initialPos.dx + 100.0));
        expect(movedPos.dy, equals(initialPos.dy + 70.0));

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
        final closeButton = find.byKey(const Key('works_columns_close_button'));
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('works_columns_window')), findsNothing);

        // Reopen via long press
        await tester.longPress(header);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('works_columns_window')), findsOneWidget);

        // Dismissal test 2: Press Escape key
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('works_columns_window')), findsNothing);

        // Reopen via right-click
        await gesture.down(headerCenter);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('works_columns_window')), findsOneWidget);

        // Dismissal test 3: Tap outside
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('works_columns_window')), findsNothing);
      },
    );
  });

  group('ArtistsView Tests', () {
    final sampleArtists = [
      const Artist(
        id: 'art-1',
        name: 'Miles Davis',
        role: 'Trumpet / Composer',
      ),
      const Artist(id: 'art-2', name: 'Pink Floyd', role: 'Progressive Rock'),
    ];

    testWidgets('ArtistsView renders empty state', (tester) async {
      await tester.pumpWidget(_buildViewTest(const ArtistsView(artists: [])));
      await tester.pumpAndSettle();

      expect(find.text('No artists found'), findsOneWidget);
    });

    testWidgets('ArtistsView renders grid and triggers selection', (
      tester,
    ) async {
      Artist? selectedArtist;

      await tester.pumpWidget(
        _buildViewTest(
          ArtistsView(
            artists: sampleArtists,
            onArtistSelected: (a) => selectedArtist = a,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Miles Davis'), findsOneWidget);
      expect(find.text('Trumpet / Composer'), findsOneWidget);
      expect(find.text('Pink Floyd'), findsOneWidget);

      await tester.tap(find.text('Miles Davis'));
      await tester.pumpAndSettle();
      expect(selectedArtist?.id, equals('art-1'));
    });
  });

  group('PlaylistsView Tests', () {
    final samplePlaylists = [
      Playlist(
        id: 'pl-1',
        title: 'Master Reference',
        description: '24/192 recordings',
        trackIds: const ['t-1', 't-2', 't-3'],
      ),
    ];

    testWidgets('PlaylistsView renders empty state and new playlist action', (
      tester,
    ) async {
      bool newPlaylistCalled = false;

      await tester.pumpWidget(
        _buildViewTest(
          PlaylistsView(
            playlists: const [],
            onNewPlaylist: () => newPlaylistCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No playlists created yet'), findsOneWidget);
      final createBtn = find.text('Create Playlist');
      expect(createBtn, findsOneWidget);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();
      expect(newPlaylistCalled, isTrue);
    });

    testWidgets('PlaylistsView renders cards and triggers callbacks', (
      tester,
    ) async {
      Playlist? selectedPl;
      bool newPlCalled = false;

      await tester.pumpWidget(
        _buildViewTest(
          PlaylistsView(
            playlists: samplePlaylists,
            onPlaylistSelected: (pl) => selectedPl = pl,
            onNewPlaylist: () => newPlCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('Master Reference'), findsOneWidget);
      expect(find.text('3 tracks'), findsOneWidget);

      // Tap playlist card
      await tester.tap(find.text('Master Reference'));
      await tester.pumpAndSettle();
      expect(selectedPl?.id, equals('pl-1'));

      // Tap header New Playlist button
      await tester.tap(find.text('New Playlist'));
      await tester.pumpAndSettle();
      expect(newPlCalled, isTrue);
    });

    testWidgets(
      'PlaylistsView top-right New Playlist button is the designated creation entry in populated view',
      (tester) async {
        bool createClicked = false;

        await tester.pumpWidget(
          _buildViewTest(
            PlaylistsView(
              playlists: samplePlaylists,
              onNewPlaylist: () => createClicked = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Top right button exists in header row
        final newPlaylistBtn = find.text('New Playlist');
        expect(newPlaylistBtn, findsOneWidget);

        await tester.tap(newPlaylistBtn);
        await tester.pumpAndSettle();
        expect(createClicked, isTrue);
      },
    );

    testWidgets(
      'PlaylistsView cards and icons adapt dynamically to Light and Dark mode',
      (tester) async {
        final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
        addTearDown(themeNotifier.dispose);

        await tester.pumpWidget(
          _buildViewTest(
            PlaylistsView(playlists: samplePlaylists),
            themeNotifier: themeNotifier,
          ),
        );
        await tester.pump();

        // 1. Dark Mode: ShadTheme card is dark zinc900
        final cardElementDark = find.byType(PlaylistsView).evaluate().first;
        final themeDark = ShadTheme.of(cardElementDark);
        expect(themeDark.brightness, equals(Brightness.dark));
        expect(
          themeDark.colorScheme.card,
          equals(const ShadZincColorScheme.dark().card),
        );

        // Switch to Light Mode (single frame 0ms)
        themeNotifier.value = ThemeMode.light;
        await tester.pump();

        // 2. Light Mode: ShadTheme card is light white
        final cardElementLight = find.byType(PlaylistsView).evaluate().first;
        final themeLight = ShadTheme.of(cardElementLight);
        expect(themeLight.brightness, equals(Brightness.light));
        expect(
          themeLight.colorScheme.card,
          equals(const ShadZincColorScheme.light().card),
        );
      },
    );
  });
}
