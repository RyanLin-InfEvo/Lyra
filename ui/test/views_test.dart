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
import 'package:ui/design_system/widgets/lyra_badge.dart';
import 'package:ui/design_system/widgets/lyra_switch.dart';
import 'package:ui/features/albums/albums_view.dart';
import 'package:ui/features/artists/artists_view.dart';
import 'package:ui/features/models/album.dart';
import 'package:ui/features/models/artist.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/work.dart';
import 'package:ui/features/playlists/playlists_view.dart';
import 'package:ui/features/settings/services/preferences_service.dart';
import 'package:ui/features/settings/settings_view.dart';
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

    const multiPlaylists = [
      Playlist(
        id: 'pl-1',
        title: 'Master Reference',
        description: '24/192 recordings',
        trackIds: ['t-1', 't-2', 't-3'],
      ),
      Playlist(
        id: 'pl-2',
        title: 'Acoustic Sessions',
        description: 'DSD direct transfers',
        trackIds: ['t-4', 't-5'],
      ),
      Playlist(
        id: 'pl-3',
        title: 'Jazz Classics',
        description: 'Blue Note Remasters',
        trackIds: ['t-6'],
      ),
    ];

    testWidgets(
      'Normal click on a playlist triggers onPlaylistSelected and single-selects without toolbar',
      (tester) async {
        Playlist? selectedPlaylist;
        await tester.pumpWidget(
          _buildViewTest(
            PlaylistsView(
              playlists: multiPlaylists,
              onPlaylistSelected: (p) => selectedPlaylist = p,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);

        await tester.tap(find.text('Master Reference'));
        await tester.pumpAndSettle();

        expect(selectedPlaylist?.id, equals('pl-1'));
        // Normal single click does not emerge toolbar
        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
        // Visual indicator check badge is shown on selected card
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
      },
    );

    testWidgets(
      'Ctrl/Cmd+Click toggles multi-selection and emerges batch action toolbar',
      (tester) async {
        await tester.pumpWidget(
          _buildViewTest(const PlaylistsView(playlists: multiPlaylists)),
        );
        await tester.pumpAndSettle();

        // 1. Ctrl + Click Playlist 1 -> toolbar emerges with 1 selected
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('Master Reference'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);

        // 2. Ctrl + Click Playlist 2 -> 2 selected
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('Acoustic Sessions'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsNWidgets(2));

        // 3. Escape key clears selection and dismisses toolbar
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
        expect(find.byIcon(LucideIcons.check), findsNothing);
      },
    );

    testWidgets('Shift+Click performs range selection on playlists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildViewTest(const PlaylistsView(playlists: multiPlaylists)),
      );
      await tester.pumpAndSettle();

      // Normal click Playlist 1 (anchor)
      await tester.tap(find.text('Master Reference'));
      await tester.pumpAndSettle();

      // Shift + Click Playlist 3 -> range selects all 3
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Jazz Classics'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNWidgets(3));
    });

    testWidgets('Ctrl/Cmd+A selects all playlists and emerges toolbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildViewTest(const PlaylistsView(playlists: multiPlaylists)),
      );
      await tester.pumpAndSettle();

      // Ctrl + A
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNWidgets(3));
    });

    testWidgets('Clicking blank space clears playlist selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildViewTest(const PlaylistsView(playlists: multiPlaylists)),
      );
      await tester.pumpAndSettle();

      // Select Playlist 1 and Playlist 2 via Ctrl+Click
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Master Reference'));
      await tester.tap(find.text('Acoustic Sessions'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
      expect(find.text('2 selected'), findsOneWidget);

      // Tap on blank space below grid cards
      final cardBottom = tester.getBottomLeft(find.text('Jazz Classics'));
      await tester.tapAt(cardBottom + const Offset(50, 150));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
      expect(find.byIcon(LucideIcons.check), findsNothing);
    });

    testWidgets(
      'PlaylistsView BatchActionToolbar dispatches batch callbacks correctly including delete',
      (tester) async {
        List<Playlist>? batchPlayNext;
        List<Playlist>? batchAddToQueue;
        List<Playlist>? batchDelete;
        List<Playlist>? batchAddTag;

        await tester.pumpWidget(
          _buildViewTest(
            PlaylistsView(
              playlists: multiPlaylists,
              onBatchPlayNext: (pl) => batchPlayNext = pl,
              onBatchAddToQueue: (pl) => batchAddToQueue = pl,
              onBatchDelete: (pl) => batchDelete = pl,
              onBatchAddTag: (pl) => batchAddTag = pl,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Ctrl + A selects all
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
        expect(find.text('3 selected'), findsOneWidget);

        // 2. Test batch buttons
        await tester.tap(find.byKey(const Key('batch_play_next_button')));
        await tester.pumpAndSettle();
        expect(batchPlayNext?.length, equals(3));

        await tester.tap(find.byKey(const Key('batch_add_to_queue_button')));
        await tester.pumpAndSettle();
        expect(batchAddToQueue?.length, equals(3));

        await tester.tap(find.byKey(const Key('batch_delete_button')));
        await tester.pumpAndSettle();
        expect(batchDelete?.length, equals(3));

        await tester.tap(find.byKey(const Key('batch_add_tag_button')));
        await tester.pumpAndSettle();
        expect(batchAddTag?.length, equals(3));

        // 3. Clear button clears selection
        await tester.tap(find.byKey(const Key('batch_clear_selection_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
      },
    );
  });

  group('AlbumsView Tests', () {
    const sampleAlbums = [
      Album(
        id: 'alb-1',
        title: 'Kind of Blue',
        artist: 'Miles Davis',
        year: 1959,
        trackCount: 5,
        format: 'FLAC 24/192',
      ),
      Album(
        id: 'alb-2',
        title: 'A Love Supreme',
        artist: 'John Coltrane',
        year: 1965,
        trackCount: 4,
        format: 'DSD 64',
      ),
      Album(
        id: 'alb-3',
        title: 'Time Out',
        artist: 'Dave Brubeck',
        year: 1959,
        trackCount: 7,
        format: 'FLAC 24/96',
      ),
    ];

    testWidgets('Empty albums view renders empty state', (tester) async {
      await tester.pumpWidget(_buildViewTest(const AlbumsView(albums: [])));
      await tester.pumpAndSettle();

      expect(find.text('No albums found'), findsOneWidget);
    });

    testWidgets(
      'AlbumsView renders header without redundant total count badge',
      (tester) async {
        await tester.pumpWidget(
          _buildViewTest(AlbumsView(albums: [sampleAlbums[0]])),
        );
        await tester.pumpAndSettle();

        expect(find.text('Albums'), findsOneWidget);
        expect(find.text('1 releases in master quality'), findsOneWidget);

        // Verify redundant header total badge is eliminated
        expect(
          find.descendant(
            of: find.byType(LyraBadge),
            matching: find.text('1 Total'),
          ),
          findsNothing,
        );

        // Card format badge should still be present
        expect(find.text('FLAC 24/192'), findsOneWidget);
      },
    );

    testWidgets(
      'Normal click on an album triggers onAlbumSelected and single-selects without toolbar',
      (tester) async {
        Album? selectedAlbum;
        await tester.pumpWidget(
          _buildViewTest(
            AlbumsView(
              albums: sampleAlbums,
              onAlbumSelected: (a) => selectedAlbum = a,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);

        await tester.tap(find.text('Kind of Blue'));
        await tester.pumpAndSettle();

        expect(selectedAlbum?.id, equals('alb-1'));
        // Normal single click does not emerge toolbar
        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
        // Visual indicator check badge is shown on selected card
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
      },
    );

    testWidgets(
      'Ctrl/Cmd+Click toggles multi-selection and emerges batch action toolbar',
      (tester) async {
        await tester.pumpWidget(
          _buildViewTest(const AlbumsView(albums: sampleAlbums)),
        );
        await tester.pumpAndSettle();

        // 1. Ctrl + Click Album 1 -> toolbar emerges with 1 selected
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('Kind of Blue'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);

        // 2. Ctrl + Click Album 2 -> 2 selected
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('A Love Supreme'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsNWidgets(2));

        // 3. Escape key clears selection and dismisses toolbar
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
        expect(find.byIcon(LucideIcons.check), findsNothing);
      },
    );

    testWidgets('Shift+Click performs range selection across albums grid', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildViewTest(const AlbumsView(albums: sampleAlbums)),
      );
      await tester.pumpAndSettle();

      // 1. Normal click Album 1
      await tester.tap(find.text('Kind of Blue'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);

      // 2. Shift + Click Album 3 -> range selects albums 1, 2, 3
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Time Out'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNWidgets(3));
    });

    testWidgets(
      'Ctrl+A selects all albums and batch buttons trigger callbacks',
      (tester) async {
        List<Album>? batchPlayNext;
        List<Album>? batchAddToQueue;
        List<Album>? batchAddToPlaylist;
        List<Album>? batchAddTag;

        await tester.pumpWidget(
          _buildViewTest(
            AlbumsView(
              albums: sampleAlbums,
              onBatchPlayNext: (a) => batchPlayNext = a,
              onBatchAddToQueue: (a) => batchAddToQueue = a,
              onBatchAddToPlaylist: (a) => batchAddToPlaylist = a,
              onBatchAddTag: (a) => batchAddTag = a,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Ctrl + A selects all albums
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
        expect(find.text('3 selected'), findsOneWidget);

        // 2. Test batch buttons
        await tester.tap(find.byKey(const Key('batch_play_next_button')));
        await tester.pumpAndSettle();
        expect(batchPlayNext?.length, equals(3));

        await tester.tap(find.byKey(const Key('batch_add_to_queue_button')));
        await tester.pumpAndSettle();
        expect(batchAddToQueue?.length, equals(3));

        await tester.tap(find.byKey(const Key('batch_add_to_playlist_button')));
        await tester.pumpAndSettle();
        expect(batchAddToPlaylist?.length, equals(3));

        await tester.tap(find.byKey(const Key('batch_add_tag_button')));
        await tester.pumpAndSettle();
        expect(batchAddTag?.length, equals(3));

        // 3. Clear button clears selection
        await tester.tap(find.byKey(const Key('batch_clear_selection_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
      },
    );

    testWidgets('Clicking blank space clears album selection', (tester) async {
      await tester.pumpWidget(
        _buildViewTest(const AlbumsView(albums: sampleAlbums)),
      );
      await tester.pumpAndSettle();

      // Select Album 1 and 2
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Kind of Blue'));
      await tester.tap(find.text('A Love Supreme'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);

      // Tap on blank space below grid cards
      final cardBottom = tester.getBottomLeft(find.text('Time Out'));
      await tester.tapAt(cardBottom + const Offset(50, 150));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
      expect(find.byIcon(LucideIcons.check), findsNothing);
    });
  });

  group('ArtistsView Tests', () {
    const sampleArtists = [
      Artist(id: 'art-1', name: 'Miles Davis', role: 'Trumpeter'),
      Artist(id: 'art-2', name: 'John Coltrane', role: 'Saxophonist'),
      Artist(id: 'art-3', name: 'Dave Brubeck', role: 'Pianist'),
    ];

    testWidgets('Empty artists view renders empty state', (tester) async {
      await tester.pumpWidget(_buildViewTest(const ArtistsView(artists: [])));
      await tester.pumpAndSettle();

      expect(find.text('No artists found'), findsOneWidget);
    });

    testWidgets(
      'Normal click on an artist triggers onArtistSelected without toolbar',
      (tester) async {
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

        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);

        await tester.tap(find.text('Miles Davis'));
        await tester.pumpAndSettle();

        expect(selectedArtist?.id, equals('art-1'));
        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
      },
    );

    testWidgets(
      'Ctrl/Cmd+Click toggles multi-selection and emerges batch action toolbar',
      (tester) async {
        await tester.pumpWidget(
          _buildViewTest(const ArtistsView(artists: sampleArtists)),
        );
        await tester.pumpAndSettle();

        // 1. Ctrl + Click Artist 1
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('Miles Davis'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);

        // 2. Ctrl + Click Artist 2
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(find.text('John Coltrane'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsNWidgets(2));

        // 3. Escape key clears selection
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
        expect(find.byIcon(LucideIcons.check), findsNothing);
      },
    );

    testWidgets('Shift+Click performs range selection across artists grid', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildViewTest(const ArtistsView(artists: sampleArtists)),
      );
      await tester.pumpAndSettle();

      // 1. Normal click Artist 1
      await tester.tap(find.text('Miles Davis'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);

      // 2. Shift + Click Artist 3 -> selects artists 1, 2, 3
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Dave Brubeck'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNWidgets(3));
    });

    testWidgets('Ctrl+A selects all artists and batch buttons fire callbacks', (
      tester,
    ) async {
      List<Artist>? batchPlayNext;
      List<Artist>? batchAddToQueue;
      List<Artist>? batchAddToPlaylist;
      List<Artist>? batchAddTag;

      await tester.pumpWidget(
        _buildViewTest(
          ArtistsView(
            artists: sampleArtists,
            onBatchPlayNext: (a) => batchPlayNext = a,
            onBatchAddToQueue: (a) => batchAddToQueue = a,
            onBatchAddToPlaylist: (a) => batchAddToPlaylist = a,
            onBatchAddTag: (a) => batchAddTag = a,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Ctrl + A selects all artists
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);
      expect(find.text('3 selected'), findsOneWidget);

      // 2. Test batch buttons
      await tester.tap(find.byKey(const Key('batch_play_next_button')));
      await tester.pumpAndSettle();
      expect(batchPlayNext?.length, equals(3));

      await tester.tap(find.byKey(const Key('batch_add_to_queue_button')));
      await tester.pumpAndSettle();
      expect(batchAddToQueue?.length, equals(3));

      await tester.tap(find.byKey(const Key('batch_add_to_playlist_button')));
      await tester.pumpAndSettle();
      expect(batchAddToPlaylist?.length, equals(3));

      await tester.tap(find.byKey(const Key('batch_add_tag_button')));
      await tester.pumpAndSettle();
      expect(batchAddTag?.length, equals(3));

      // 3. Clear button clears selection
      await tester.tap(find.byKey(const Key('batch_clear_selection_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
    });

    testWidgets('Clicking blank space clears artist selection', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildViewTest(const ArtistsView(artists: sampleArtists)),
      );
      await tester.pumpAndSettle();

      // Select Artist 1 and 2
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Miles Davis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('John Coltrane'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsOneWidget);

      // Tap on blank space below grid cards
      await tester.tapAt(const Offset(100, 480));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batch_action_toolbar')), findsNothing);
      expect(find.byIcon(LucideIcons.check), findsNothing);
    });
  });

  group('SettingsView Tests', () {
    testWidgets(
      'SettingsView renders toggle switches, handles toggling, and eliminates redundant header badges',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final prefs = InMemoryPreferencesService(audioExclusiveMode: true);
        await tester.pumpWidget(
          _buildViewTest(SettingsView(preferencesService: prefs)),
        );
        await tester.pumpAndSettle();

        // 1. Verify header and titles
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Audio Output'), findsOneWidget);
        expect(find.text('CAS Storage'), findsOneWidget);

        // 2. Verify redundant badges eliminated:
        // Audio Output header badge ('Exclusive Mode') must NOT exist
        expect(
          find.descendant(
            of: find.byType(LyraBadge),
            matching: find.text('Exclusive Mode'),
          ),
          findsNothing,
        );

        // 3. Verify presence of LyraSwitch instances (Exclusive Mode, DoP, SHA-256)
        final switches = find.byType(LyraSwitch);
        expect(switches, findsNWidgets(3));

        final exclusiveSwitch = switches.at(0);
        final dopSwitch = switches.at(1);
        final shaSwitch = switches.at(2);

        expect(tester.widget<LyraSwitch>(exclusiveSwitch).value, isTrue);
        expect(tester.widget<LyraSwitch>(dopSwitch).value, isFalse);
        expect(tester.widget<LyraSwitch>(shaSwitch).value, isTrue);

        // 4. Toggle Exclusive Mode switch
        await tester.tap(exclusiveSwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<LyraSwitch>(exclusiveSwitch).value, isFalse);
        expect(prefs.audioExclusiveMode, isFalse);

        // Toggle back
        await tester.tap(exclusiveSwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<LyraSwitch>(exclusiveSwitch).value, isTrue);
        expect(prefs.audioExclusiveMode, isTrue);

        // 5. Toggle DSD over PCM (DoP) switch
        await tester.tap(dopSwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<LyraSwitch>(dopSwitch).value, isTrue);
        expect(prefs.audioDopEnabled, isTrue);

        // 6. Toggle Verify SHA-256 switch
        await tester.tap(shaSwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<LyraSwitch>(shaSwitch).value, isFalse);
        expect(prefs.casAutoVerify, isFalse);

        // 7. Verify legitimate badge still remains (e.g. 'Block-level CAS')
        expect(find.text('Block-level CAS'), findsOneWidget);

        // 8. Verify setting rows have MergeSemantics for accessibility
        expect(find.byType(MergeSemantics), findsNWidgets(5));
      },
    );
  });
}
