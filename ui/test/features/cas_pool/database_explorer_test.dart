// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
import 'package:ui/design_system/widgets/lyra_dialog.dart';
import 'package:ui/design_system/widgets/lyra_input.dart';
import 'package:ui/features/cas_pool/controllers/database_explorer_controller.dart';
import 'package:ui/features/cas_pool/models/database_stats.dart';
import 'package:ui/features/cas_pool/widgets/database_explorer_tab.dart';

Widget _buildDatabaseExplorerTest({
  required DatabaseExplorerController controller,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  final isDark = themeMode == ThemeMode.dark;
  final tokens = isDark ? LyraThemeTokens.dark() : LyraThemeTokens.light();
  final shadTheme = ShadThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: isDark
        ? const ShadZincColorScheme.dark()
        : const ShadZincColorScheme.light(),
  );

  return ShadApp(
    title: 'Database Explorer Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: const ShadcnFactory(),
        tokens: tokens,
        themeModeNotifier: ValueNotifier(themeMode),
        child: Scaffold(body: DatabaseExplorerTab(controller: controller)),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseStats & TableData Unit Tests', () {
    test(
      'DatabaseStats.defaults initializes with expected mock SQLite values',
      () {
        final stats = DatabaseStats.defaults();
        expect(stats.databasePath, contains('lyra.db'));
        expect(stats.databaseSizeBytes, equals(40265318));
        expect(stats.walSizeBytes, equals(1258291));
        expect(stats.walUncommittedPages, equals(42));
        expect(stats.reclaimableSizeBytes, equals(3984588));
        expect(stats.integrityStatus, equals('OK'));
        expect(stats.pageSizeBytes, equals(4096));
        expect(stats.pageCount, equals(9830));
        expect(stats.schemaVersion, equals(12));
        expect(stats.sqliteVersion, equals('3.45.1'));
        expect(stats.journalMode, equals('WAL'));

        // Formatted getters
        expect(stats.formattedDatabaseSize, equals('38.4 MB'));
        expect(stats.formattedWalSize, equals('1.2 MB'));
        expect(stats.formattedReclaimableSize, equals('3.8 MB'));
        expect(stats.formattedWalPages, equals('42 pages'));
        expect(stats.formattedPageSize, equals('4.0 KB'));
        expect(stats.formattedPageCount, equals('9,830'));
        expect(stats.formattedUncommittedPages, equals('42'));
      },
    );

    test('DatabaseStats.formatBytes handles byte boundaries correctly', () {
      expect(DatabaseStats.formatBytes(512), equals('512 B'));
      expect(DatabaseStats.formatBytes(2048), equals('2.0 KB'));
      expect(DatabaseStats.formatBytes(15 * 1024 * 1024), equals('15.0 MB'));
      expect(
        DatabaseStats.formatBytes(2 * 1024 * 1024 * 1024),
        equals('2.00 GB'),
      );
    });

    test('DatabaseStats copyWith creates clean immutable copies', () {
      final original = DatabaseStats.defaults();
      final updated = original.copyWith(
        walUncommittedPages: 0,
        walSizeBytes: 32768,
        reclaimableSizeBytes: 0,
      );

      expect(updated.walUncommittedPages, equals(0));
      expect(updated.walSizeBytes, equals(32768));
      expect(updated.reclaimableSizeBytes, equals(0));
      expect(updated.databasePath, equals(original.databasePath));
      expect(updated.pageSizeBytes, equals(original.pageSizeBytes));
      expect(updated == original, isFalse);
    });

    test('TableData model equality and hashCode', () {
      const data1 = TableData(
        tableName: 'Entity',
        columns: ['id', 'entity_type'],
        rows: [
          {'id': '1', 'entity_type': 'artist'},
        ],
        totalCount: 1,
      );
      const data2 = TableData(
        tableName: 'Entity',
        columns: ['id', 'entity_type'],
        rows: [
          {'id': '1', 'entity_type': 'artist'},
        ],
        totalCount: 1,
      );
      expect(data1, equals(data2));
      expect(data1.hashCode, equals(data2.hashCode));
    });

    test(
      'TableStatItem.defaults reflects domain topology with deduplication info',
      () {
        final tables = TableStatItem.defaults();
        expect(tables.length, equals(7));

        final names = tables.map((t) => t.tableName).toList();
        expect(
          names,
          containsAll([
            'Asset',
            'Audio',
            'Track',
            'Album',
            'Artist',
            'Work',
            'Playlist',
          ]),
        );

        final audioTable = tables.firstWhere((t) => t.tableName == 'Audio');
        expect(audioTable.recordCount, equals(1842));
        expect(audioTable.formattedRecordCount, equals('1,842'));
        expect(
          audioTable.details,
          contains('576 duplicate tracks deduplicated'),
        );
      },
    );
  });

  group('DatabaseExplorerController Unit Tests', () {
    late DatabaseExplorerController controller;

    setUp(() {
      controller = DatabaseExplorerController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state is idle with defaults and data browser setup', () {
      expect(controller.isLoading, isFalse);
      expect(controller.isCheckpointing, isFalse);
      expect(controller.isVacuuming, isFalse);
      expect(controller.isVerifyingIntegrity, isFalse);
      expect(controller.isLoadingTableData, isFalse);
      expect(controller.isBusy, isFalse);
      expect(controller.lastIntegrityStatus, isNull);
      expect(controller.lastActionMessage, isNull);
      expect(controller.stats.walUncommittedPages, equals(42));

      // Browser state
      expect(controller.selectedTable, equals('Entity'));
      expect(controller.currentPage, equals(1));
      expect(controller.pageSize, equals(50));
      expect(controller.searchQuery, isEmpty);
      expect(controller.availableTables.length, equals(10));
      expect(controller.availableTables, contains('Image'));
      expect(
        controller.currentColumns,
        equals(['id', 'entity_type', 'created_at', 'updated_at']),
      );
      expect(controller.totalTableCount, equals(60));
      expect(controller.filteredRowCount, equals(60));
      expect(controller.totalPages, equals(2));
      expect(controller.pagedRows.length, equals(50));
    });

    test('Table selection updates selectedTable, columns, and resets page', () {
      controller.goToPage(2);
      expect(controller.currentPage, equals(2));

      controller.selectTable('Track');
      expect(controller.selectedTable, equals('Track'));
      expect(controller.currentPage, equals(1));
      expect(
        controller.currentColumns,
        equals([
          'id',
          'title',
          'pcm_hash',
          'work_id',
          'duration',
          'recording_year',
          'isrc',
          'musicbrainz_id',
        ]),
      );
      expect(controller.totalTableCount, equals(55));
      expect(controller.totalPages, equals(2));
      expect(controller.pagedRows.length, equals(50));

      // Selecting already selected table does not reset or notify unnecessarily
      controller.selectTable('Track');
      expect(controller.selectedTable, equals('Track'));
    });

    test('Search filter filters across all columns case-insensitively', () {
      controller.selectTable('Entity');
      expect(controller.totalTableCount, equals(60));

      // Search by entity_type 'artist'
      controller.setSearchQuery('artist');
      expect(controller.searchQuery, equals('artist'));
      expect(controller.currentPage, equals(1));
      expect(controller.filteredRowCount, greaterThan(0));
      expect(controller.filteredRowCount, lessThan(60));
      for (final row in controller.pagedRows) {
        expect(row['entity_type'], equals('artist'));
      }

      // Search by partial UUID case-insensitively
      controller.setSearchQuery('DA5D1C54');
      expect(controller.filteredRowCount, equals(1));
      expect(
        controller.pagedRows.first['id'],
        equals('da5d1c54-3f89-4b13-a00a-9228ae564f44'),
      );

      // Search with non-matching query
      controller.setSearchQuery('nonexistent_string_12345');
      expect(controller.filteredRowCount, equals(0));
      expect(controller.pagedRows, isEmpty);
      expect(controller.totalPages, equals(1));

      // Clear search query
      controller.setSearchQuery('');
      expect(controller.filteredRowCount, equals(60));
      expect(controller.pagedRows.length, equals(50));
    });

    test('Pagination navigates forward, backward, and clamps properly', () {
      controller.selectTable('Entity'); // 60 rows, pageSize=50 -> 2 pages
      expect(controller.totalPages, equals(2));
      expect(controller.currentPage, equals(1));
      expect(controller.pagedRows.length, equals(50));

      // Next page
      controller.nextPage();
      expect(controller.currentPage, equals(2));
      expect(controller.pagedRows.length, equals(10));

      // Next page at boundary does nothing
      controller.nextPage();
      expect(controller.currentPage, equals(2));

      // Previous page
      controller.previousPage();
      expect(controller.currentPage, equals(1));
      expect(controller.pagedRows.length, equals(50));

      // Previous page at boundary does nothing
      controller.previousPage();
      expect(controller.currentPage, equals(1));

      // Go to explicit page
      controller.goToPage(2);
      expect(controller.currentPage, equals(2));

      // Go to page out of bounds clamps safely
      controller.goToPage(100);
      expect(controller.currentPage, equals(2));

      controller.goToPage(-10);
      expect(controller.currentPage, equals(1));
    });

    test('NULL column values are handled safely without exceptions', () {
      controller.selectTable('Entity');
      final nullRows = controller.pagedRows.where(
        (r) => r['created_at'] == null,
      );
      expect(nullRows, isNotEmpty);

      // Search query filter does not throw on nulls
      controller.setSearchQuery('2026');
      expect(controller.filteredRowCount, greaterThan(0));

      // All returned rows with 2026 match non-null fields
      for (final row in controller.pagedRows) {
        final matches = row.values.any(
          (v) => v != null && v.toString().contains('2026'),
        );
        expect(matches, isTrue);
      }
    });

    test(
      'Switching table clears search filter in controller and resets page',
      () {
        controller.selectTable('Entity');
        controller.goToPage(2);
        expect(controller.currentPage, equals(2));

        controller.setSearchQuery('artist');
        expect(controller.currentPage, equals(1));

        controller.selectTable('Track');
        expect(controller.selectedTable, equals('Track'));
        expect(controller.searchQuery, isEmpty);
        expect(controller.currentPage, equals(1));
      },
    );

    test(
      'setPageSize updates pageSize, recalculates totalPages, and clamps currentPage',
      () {
        controller.selectTable('Entity'); // 60 rows
        expect(controller.pageSize, equals(50));
        expect(controller.totalPages, equals(2));

        controller.goToPage(2);
        expect(controller.currentPage, equals(2));

        // When changing page size from 50 to 25, totalPages becomes 3,
        // currentPage 2 is clamped to [1, 3] and remains 2
        controller.setPageSize(25);
        expect(controller.pageSize, equals(25));
        expect(controller.currentPage, equals(2));
        expect(controller.totalPages, equals(3));
        expect(controller.pagedRows.length, equals(25));

        // When changing page size to 100, totalPages becomes 1,
        // currentPage is clamped down to 1
        controller.setPageSize(100);
        expect(controller.pageSize, equals(100));
        expect(controller.totalPages, equals(1));
        expect(controller.currentPage, equals(1));

        // Clamping negative or excessive values
        controller.setPageSize(-5);
        expect(controller.pageSize, equals(1));
        controller.setPageSize(5000);
        expect(controller.pageSize, equals(1000));
      },
    );

    test('currentPage clamps properly when rows or filter change', () {
      controller.selectTable('Entity'); // 60 rows
      controller.setPageSize(25); // 3 pages
      controller.goToPage(3);
      expect(controller.currentPage, equals(3));

      // Filter to 'artist' (only 6 rows -> totalPages = 1)
      controller.setSearchQuery('artist');
      expect(controller.totalPages, equals(1));
      expect(controller.currentPage, equals(1));

      // Clear search query (60 rows -> totalPages = 3)
      controller.setSearchQuery('');
      expect(controller.totalPages, equals(3));
      controller.goToPage(3);
      expect(controller.currentPage, equals(3));

      // Switch table to Audio (resets to page 1 and clamped)
      controller.selectTable('Playlist');
      expect(controller.currentPage, equals(1));
    });

    test(
      'navigateToTable updates selectedTable, applies filter, and resets page to 1',
      () {
        controller.selectTable('Entity');
        controller.goToPage(2);
        expect(controller.currentPage, equals(2));

        controller.navigateToTable('Track', filter: 'Symphony');
        expect(controller.selectedTable, equals('Track'));
        expect(controller.searchQuery, equals('Symphony'));
        expect(controller.currentPage, equals(1));
        expect(controller.filteredRowCount, greaterThan(0));
        expect(
          controller.pagedRows.every(
            (r) => r.values.any(
              (v) => v != null && v.toString().contains('Symphony'),
            ),
          ),
          isTrue,
        );
      },
    );

    test('Zero or negative initialPageSize is clamped safely', () {
      final cZero = DatabaseExplorerController(initialPageSize: 0);
      expect(cZero.pageSize, equals(1));
      expect(cZero.totalPages, greaterThanOrEqualTo(1));
      cZero.dispose();

      final cNeg = DatabaseExplorerController(initialPageSize: -50);
      expect(cNeg.pageSize, equals(1));
      expect(cNeg.totalPages, greaterThanOrEqualTo(1));
      cNeg.dispose();

      final cHuge = DatabaseExplorerController(initialPageSize: 9999);
      expect(cHuge.pageSize, equals(1000));
      cHuge.dispose();
    });

    test('Filtered row caching behaves correctly', () {
      controller.selectTable('Entity');
      final count1 = controller.filteredRowCount;
      final rows1 = controller.pagedRows;
      expect(count1, equals(60));
      expect(rows1.length, equals(50));

      // Subsequent access uses cache
      expect(controller.filteredRowCount, equals(count1));

      // Searching invalidates cache and returns filtered subset
      controller.setSearchQuery('artist');
      expect(controller.filteredRowCount, lessThan(60));
      expect(controller.filteredRowCount, greaterThan(0));

      // Switching table clears filter and invalidates cache
      controller.selectTable('Track');
      expect(controller.searchQuery, isEmpty);
      expect(controller.totalTableCount, equals(55));
      expect(controller.filteredRowCount, equals(55));
    });

    test('loadStats executes async refresh and clears isLoading', () async {
      final future = controller.loadStats(
        delay: const Duration(milliseconds: 10),
      );
      expect(controller.isLoading, isTrue);
      expect(controller.isBusy, isTrue);

      await future;
      expect(controller.isLoading, isFalse);
      expect(controller.isBusy, isFalse);
    });

    test('refreshTableData sets and resets isLoadingTableData', () async {
      final future = controller.refreshTableData(
        delay: const Duration(milliseconds: 10),
      );
      expect(controller.isLoadingTableData, isTrue);
      expect(controller.isBusy, isTrue);

      await future;
      expect(controller.isLoadingTableData, isFalse);
      expect(controller.isBusy, isFalse);
    });

    test(
      'checkpointWal resets uncommitted pages and updates message',
      () async {
        final future = controller.checkpointWal(
          delay: const Duration(milliseconds: 10),
        );
        expect(controller.isCheckpointing, isTrue);
        expect(controller.isBusy, isTrue);

        await future;
        expect(controller.isCheckpointing, isFalse);
        expect(controller.isBusy, isFalse);
        expect(controller.stats.walUncommittedPages, equals(0));
        expect(controller.stats.walSizeBytes, equals(32768));
        expect(
          controller.lastActionMessage,
          contains('WAL checkpoint completed'),
        );
      },
    );

    test('vacuumDatabase defragments pages and reclaims space', () async {
      final initialSize = controller.stats.databaseSizeBytes;
      final future = controller.vacuumDatabase(
        delay: const Duration(milliseconds: 10),
      );
      expect(controller.isVacuuming, isTrue);
      expect(controller.isBusy, isTrue);

      await future;
      expect(controller.isVacuuming, isFalse);
      expect(controller.isBusy, isFalse);
      expect(controller.stats.databaseSizeBytes, lessThan(initialSize));
      expect(controller.stats.reclaimableSizeBytes, equals(0));
      expect(
        controller.lastActionMessage,
        contains('Database vacuum completed'),
      );
    });

    test('verifyIntegrity sets OK on success and records message', () async {
      final future = controller.verifyIntegrity(
        delay: const Duration(milliseconds: 10),
        mockResult: 'OK',
      );
      expect(controller.isVerifyingIntegrity, isTrue);
      expect(controller.isBusy, isTrue);

      await future;
      expect(controller.isVerifyingIntegrity, isFalse);
      expect(controller.isBusy, isFalse);
      expect(controller.lastIntegrityStatus, equals('OK'));
      expect(controller.stats.integrityStatus, equals('OK'));
      expect(controller.lastActionIsError, isFalse);
      expect(
        controller.lastActionMessage,
        contains('integrity check passed: OK'),
      );
    });

    test('verifyIntegrity handles error results properly', () async {
      await controller.verifyIntegrity(
        delay: const Duration(milliseconds: 10),
        mockResult: 'row 42 missing index entry',
      );
      expect(
        controller.lastIntegrityStatus,
        equals('row 42 missing index entry'),
      );
      expect(
        controller.stats.integrityStatus,
        equals('row 42 missing index entry'),
      );
      expect(controller.lastActionIsError, isTrue);
      expect(controller.lastActionMessage, contains('integrity check failed'));
    });

    test(
      'verifyIntegrity with simulateError sets lastActionIsError to true',
      () async {
        await controller.verifyIntegrity(
          delay: Duration.zero,
          simulateError: true,
        );
        expect(controller.lastActionIsError, isTrue);
        expect(controller.lastIntegrityStatus, contains('failed'));
        expect(
          controller.lastActionMessage,
          contains('integrity check failed'),
        );
      },
    );

    test('clearActionMessage clears lastActionMessage', () async {
      await controller.checkpointWal(delay: Duration.zero);
      expect(controller.lastActionMessage, isNotNull);
      controller.clearActionMessage();
      expect(controller.lastActionMessage, isNull);
      expect(controller.lastActionIsError, isFalse);
    });

    test(
      'Calling maintenance operations while isBusy returns immediately without executing',
      () async {
        final future = controller.verifyIntegrity(
          delay: const Duration(milliseconds: 50),
          mockResult: 'OK',
        );
        expect(controller.isBusy, isTrue);

        // Attempt concurrent operations while isBusy is true
        await controller.checkpointWal(delay: Duration.zero);
        expect(controller.stats.walUncommittedPages, equals(42));

        await controller.vacuumDatabase(delay: Duration.zero);
        expect(controller.stats.pageCount, equals(9830));

        await future;
        expect(controller.isBusy, isFalse);
        expect(controller.lastIntegrityStatus, equals('OK'));
      },
    );

    test(
      'checkpointWal after integrity failure resets lastActionIsError to false',
      () async {
        await controller.verifyIntegrity(
          delay: Duration.zero,
          mockResult: 'corruption in table Asset',
        );
        expect(controller.lastActionIsError, isTrue);
        expect(
          controller.lastIntegrityStatus,
          equals('corruption in table Asset'),
        );

        await controller.checkpointWal(delay: Duration.zero);
        expect(controller.lastActionIsError, isFalse);
        expect(
          controller.lastActionMessage,
          contains('WAL checkpoint completed'),
        );
      },
    );
  });

  group('DatabaseExplorerTab Widget Tests', () {
    testWidgets(
      'Renders top health status card and metrics conforming to requirements',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Section 1: Database Health Status
        expect(find.text('Database Health Status'), findsOneWidget);
        expect(find.text(controller.stats.databasePath), findsOneWidget);
        expect(find.text('Database Size'), findsOneWidget);
        expect(find.text('38.4 MB'), findsOneWidget);
        expect(find.text('WAL Journal'), findsOneWidget);
        expect(find.text('1.2 MB (42 pages)'), findsOneWidget);
        expect(find.text('Reclaimable Space'), findsOneWidget);
        expect(find.text('3.8 MB (Freelist)'), findsOneWidget);
        expect(find.text('Integrity Status'), findsOneWidget);
        expect(find.text('Healthy (OK)'), findsOneWidget);

        // Inline Action buttons
        expect(find.text('Checkpoint WAL'), findsOneWidget);
        expect(find.text('Vacuum Database'), findsOneWidget);
        expect(find.text('Verify Integrity'), findsOneWidget);

        // Section 2: SQLite Data Browser
        expect(find.text('SQLite Data Browser'), findsOneWidget);
        expect(find.text('Table:'), findsOneWidget);
        expect(find.text('Entity'), findsWidgets);
        expect(find.text('Filter in any column...'), findsOneWidget);
      },
    );

    testWidgets(
      'Monospace path copy button copies path to clipboard and shows feedback',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        String? clipboardData;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'Clipboard.setData') {
                clipboardData =
                    (methodCall.arguments as Map)['text'] as String?;
                return null;
              }
              return null;
            });

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final copyButton = find.byKey(const Key('copy_database_path_button'));
        expect(copyButton, findsOneWidget);

        final mouseRegion = tester.widget<MouseRegion>(
          find
              .ancestor(of: copyButton, matching: find.byType(MouseRegion))
              .first,
        );
        expect(mouseRegion.cursor, equals(SystemMouseCursors.click));

        await tester.tap(copyButton);
        await tester.pump();

        expect(clipboardData, equals(controller.stats.databasePath));
        expect(find.text('Copied'), findsWidgets);

        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();
        expect(find.text('Copy'), findsOneWidget);
      },
    );

    testWidgets('Checkpoint WAL executes operation and updates UI in-place', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DatabaseExplorerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildDatabaseExplorerTest(controller: controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.2 MB (42 pages)'), findsOneWidget);

      final button = find.widgetWithText(LyraButton, 'Checkpoint WAL');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      expect(find.text('Checkpointing WAL frames...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('32.0 KB (0 pages)'), findsOneWidget);
      expect(find.textContaining('WAL checkpoint completed'), findsOneWidget);
    });

    testWidgets(
      'Verify Integrity executes check and displays OK result in-place',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final button = find.widgetWithText(LyraButton, 'Verify Integrity');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();

        expect(find.text('Verifying database integrity...'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(
          find.text('Database integrity check passed: OK.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Vacuum Database shows LyraDialog confirmation and allows cancel',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final vacuumButton = find.widgetWithText(LyraButton, 'Vacuum Database');
        await tester.ensureVisible(vacuumButton);
        await tester.tap(vacuumButton);
        await tester.pumpAndSettle();

        // LyraDialog modal opens
        expect(find.byType(LyraDialog), findsOneWidget);
        expect(find.text('Confirm Vacuum'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Cancel button dismisses modal without triggering vacuum
        await tester.tap(find.widgetWithText(LyraButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsNothing);
        expect(controller.isVacuuming, isFalse);
      },
    );

    testWidgets(
      'Vacuum Database dialog X close button dismisses dialog without popping host view',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final vacuumButton = find.widgetWithText(LyraButton, 'Vacuum Database');
        await tester.ensureVisible(vacuumButton);
        await tester.tap(vacuumButton);
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsOneWidget);

        final closeIcon = find.descendant(
          of: find.byType(LyraDialog),
          matching: find.byIcon(LucideIcons.x),
        );
        expect(closeIcon, findsOneWidget);
        await tester.tap(closeIcon);
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsNothing);
        expect(find.byType(DatabaseExplorerTab), findsOneWidget);
        expect(find.text('Database Health Status'), findsOneWidget);
        expect(controller.isVacuuming, isFalse);
      },
    );

    testWidgets(
      'Vacuum Database dialog wraps with BlockSemantics and dismisses on Escape key',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final vacuumButton = find.widgetWithText(LyraButton, 'Vacuum Database');
        await tester.ensureVisible(vacuumButton);
        await tester.tap(vacuumButton);
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsNothing);
        expect(find.byType(DatabaseExplorerTab), findsOneWidget);
        expect(controller.isVacuuming, isFalse);
      },
    );

    testWidgets('Vacuum Database confirms in LyraDialog and executes vacuum', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DatabaseExplorerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildDatabaseExplorerTest(controller: controller),
      );
      await tester.pumpAndSettle();

      final vacuumButton = find.widgetWithText(LyraButton, 'Vacuum Database');
      await tester.ensureVisible(vacuumButton);
      await tester.tap(vacuumButton);
      await tester.pumpAndSettle();

      // Tap Confirm Vacuum
      await tester.tap(find.widgetWithText(LyraButton, 'Confirm Vacuum'));
      await tester.pump();

      expect(find.byType(LyraDialog), findsNothing);
      expect(
        find.text('Vacuuming database and defragmenting pages...'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.textContaining('Database vacuum completed'), findsOneWidget);
      expect(find.text('0 B (Freelist)'), findsOneWidget);
    });

    testWidgets(
      'Displays destructive badge and error on failed integrity check',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final future = controller.verifyIntegrity(
          delay: const Duration(milliseconds: 10),
          mockResult: 'corruption in index idx_audio_hash',
        );
        await tester.pump(const Duration(milliseconds: 20));
        await future;
        await tester.pumpAndSettle();

        expect(find.text('corruption in index idx_audio_hash'), findsOneWidget);
        expect(find.text('Check Failed'), findsOneWidget);
        expect(
          find.textContaining('Database integrity check failed'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Subsequent checkpoint WAL clears destructive badge after integrity failure',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // 1. Simulate integrity failure
        final verifyFuture = controller.verifyIntegrity(
          delay: const Duration(milliseconds: 10),
          mockResult: 'corrupt page 12',
        );
        await tester.pump(const Duration(milliseconds: 20));
        await verifyFuture;
        await tester.pumpAndSettle();

        expect(find.text('corrupt page 12'), findsOneWidget);
        expect(find.text('Check Failed'), findsOneWidget);
        expect(
          find.textContaining('Database integrity check failed'),
          findsOneWidget,
        );

        // 2. Execute checkpoint WAL
        final checkpointButton = find.widgetWithText(
          LyraButton,
          'Checkpoint WAL',
        );
        await tester.ensureVisible(checkpointButton);
        await tester.tap(checkpointButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // 3. Verify destructive badge is gone and normal checkpoint message is shown
        expect(find.text('Check Failed'), findsNothing);
        expect(find.textContaining('WAL checkpoint completed'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders Data Browser with table selector, search filter, headers, and formatted NULL cells',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Table selector
        expect(
          find.byKey(const Key('table_selector_dropdown')),
          findsOneWidget,
        );

        // Search input
        expect(find.byType(LyraInput), findsOneWidget);

        // Table headers for Entity table in Title Case (Apple HIG) with raw column name tooltips
        expect(find.text('#'), findsOneWidget);
        expect(find.text('ID'), findsOneWidget);
        expect(find.text('Entity Type'), findsOneWidget);
        expect(find.text('Created At'), findsOneWidget);
        expect(find.text('Updated At'), findsOneWidget);
        expect(find.byTooltip('Column: entity_type'), findsOneWidget);

        // Row numbers gutter
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);

        // Monospace UUID cell from reference screenshot
        expect(
          find.text('da5d1c54-3f89-4b13-a00a-9228ae564f44'),
          findsOneWidget,
        );

        // Formatted NULL cell rendered in italics
        final nullFinders = find.text('NULL');
        expect(nullFinders, findsWidgets);

        final nullWidget = tester.widget<Text>(nullFinders.first);
        expect(nullWidget.style?.fontStyle, equals(FontStyle.italic));

        // Showing 1-50 of 60 records
        expect(find.text('Showing 1–50 of 60 records'), findsOneWidget);
        expect(find.text('Page 1 of 2'), findsOneWidget);
      },
    );

    testWidgets(
      'Table selector dropdown switches displayed table columns and data rows',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        expect(find.text('Entity Type'), findsOneWidget);
        expect(find.text('Name'), findsNothing);

        // Tap dropdown to open PopupMenu
        await tester.tap(find.byKey(const Key('table_selector_dropdown')));
        await tester.pumpAndSettle();

        // Select 'Artist'
        await tester.tap(find.text('Artist').last);
        await tester.pumpAndSettle();

        expect(controller.selectedTable, equals('Artist'));
        expect(find.text('Entity Type'), findsNothing);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Description'), findsOneWidget);
        expect(find.text('Ludwig van Beethoven'), findsOneWidget);
        expect(find.text('Johann Sebastian Bach'), findsOneWidget);
      },
    );

    testWidgets(
      'Search filter input updates results and displays empty state when no match',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        expect(find.text('Showing 1–50 of 60 records'), findsOneWidget);

        // Search for specific ID
        final searchInput = find.byType(EditableText);
        await tester.enterText(searchInput, 'da5d1c54');
        await tester.pumpAndSettle();

        expect(controller.searchQuery, equals('da5d1c54'));
        expect(find.text('Showing 1–1 of 1 records'), findsOneWidget);
        expect(
          find.text('da5d1c54-3f89-4b13-a00a-9228ae564f44'),
          findsOneWidget,
        );

        // Non matching query
        await tester.enterText(searchInput, 'nonexistent_record_xyz');
        await tester.pumpAndSettle();

        expect(find.text('Showing 0 records'), findsOneWidget);
        expect(find.text('No matching records found'), findsOneWidget);

        // Clear query
        await tester.enterText(searchInput, '');
        await tester.pumpAndSettle();

        expect(find.text('Showing 1–50 of 60 records'), findsOneWidget);
      },
    );

    testWidgets('Pagination Next and Previous buttons navigate pages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DatabaseExplorerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildDatabaseExplorerTest(controller: controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(find.text('Showing 1–50 of 60 records'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Visibility Rules: On page 1 of 2, Previous button is hidden, Next button is visible
      expect(find.byKey(const Key('prev_page_button')), findsNothing);
      expect(find.byKey(const Key('next_page_button')), findsWidgets);

      final nextButton = find.byKey(const Key('next_page_button')).first;

      // Next button advances page
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(controller.currentPage, equals(2));
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(find.text('Showing 51–60 of 60 records'), findsOneWidget);
      expect(find.text('51'), findsOneWidget);

      // Visibility Rules: On page 2 of 2, Next button is hidden, Previous button is visible
      expect(find.byKey(const Key('next_page_button')), findsNothing);
      expect(find.byKey(const Key('prev_page_button')), findsWidgets);

      final prevButton = find.byKey(const Key('prev_page_button')).first;

      // Previous button goes back to page 1
      await tester.ensureVisible(prevButton);
      await tester.tap(prevButton);
      await tester.pumpAndSettle();

      expect(controller.currentPage, equals(1));
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(find.text('Showing 1–50 of 60 records'), findsOneWidget);
      expect(find.byKey(const Key('prev_page_button')), findsNothing);
      expect(find.byKey(const Key('next_page_button')), findsWidgets);
    });

    testWidgets(
      'Switching table in UI clears search input text and resets controller search filter and page',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Enter search text
        final searchInput = find.byType(EditableText);
        await tester.enterText(searchInput, 'artist');
        await tester.pumpAndSettle();
        expect(controller.searchQuery, equals('artist'));

        // Switch table via dropdown
        await tester.tap(find.byKey(const Key('table_selector_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Track').last);
        await tester.pumpAndSettle();

        expect(controller.selectedTable, equals('Track'));
        expect(controller.searchQuery, isEmpty);
        expect(controller.currentPage, equals(1));
        // Search textfield is also cleared
        expect(find.text('artist'), findsNothing);
      },
    );

    testWidgets(
      'Hyphenated English sentences are not treated as UUID identifiers',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final customData = {
          'Playlist': const TableData(
            tableName: 'Playlist',
            columns: ['id', 'title', 'description'],
            rows: [
              {
                'id': 'da5d1c54-3f89-4b13-a00a-9228ae564f44',
                'title': 'Test Playlist',
                'description':
                    'Bit-perfect reference recordings for high-end DACs and headphones.',
              },
            ],
            totalCount: 1,
          ),
        };
        final controller = DatabaseExplorerController(
          initialTable: 'Playlist',
          initialTableData: customData,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // UUID should be formatted with monospace
        final uuidWidget = tester.widget<Text>(
          find.text('da5d1c54-3f89-4b13-a00a-9228ae564f44'),
        );
        expect(uuidWidget.style?.fontFamily, equals('monospace'));

        // English sentence with hyphens should NOT be formatted with monospace
        final descWidget = tester.widget<Text>(
          find.text(
            'Bit-perfect reference recordings for high-end DACs and headphones.',
          ),
        );
        expect(descWidget.style?.fontFamily, isNot(equals('monospace')));
      },
    );

    testWidgets('Tooltip is present on monospace cells', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = DatabaseExplorerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildDatabaseExplorerTest(controller: controller),
      );
      await tester.pumpAndSettle();

      const uuid = 'da5d1c54-3f89-4b13-a00a-9228ae564f44';
      final cellFinder = find.text(uuid);
      expect(cellFinder, findsOneWidget);

      final cellTooltip = tester.widget<Tooltip>(
        find.ancestor(of: cellFinder, matching: find.byType(Tooltip)),
      );
      expect(cellTooltip.richMessage, isNotNull);
      expect(cellTooltip.richMessage, isA<WidgetSpan>());
    });

    testWidgets(
      'Toolbar and pagination bar render gracefully without overflow on narrow viewports',
      (tester) async {
        tester.view.physicalSize = const Size(380, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Table:'), findsOneWidget);
        expect(find.byKey(const Key('prev_page_button')), findsNothing);
        expect(find.byKey(const Key('next_page_button')), findsWidgets);
      },
    );

    testWidgets(
      'Page size selector dropdown mutates controller.pageSize and updates pagination',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('page_size_selector_dropdown')),
          findsOneWidget,
        );
        expect(find.text('50 / page'), findsOneWidget);
        expect(find.text('Showing 1–50 of 60 records'), findsOneWidget);

        // Tap page size dropdown
        await tester.tap(find.byKey(const Key('page_size_selector_dropdown')));
        await tester.pumpAndSettle();

        // Select '25 / page'
        await tester.tap(find.text('25 / page').last);
        await tester.pumpAndSettle();

        expect(controller.pageSize, equals(25));
        expect(find.text('Showing 1–25 of 60 records'), findsOneWidget);
        expect(find.text('Page 1 of 3'), findsOneWidget);
      },
    );

    testWidgets(
      'Clicking any non-null cell copies value to clipboard and shows in-place feedback',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        String? clipboardData;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'Clipboard.setData') {
                clipboardData =
                    (methodCall.arguments as Map)['text'] as String?;
                return null;
              }
              return null;
            });

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final cellFinder = find.text('da5d1c54-3f89-4b13-a00a-9228ae564f44');
        expect(cellFinder, findsOneWidget);

        // Left-click cell
        await tester.tap(cellFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(clipboardData, equals('da5d1c54-3f89-4b13-a00a-9228ae564f44'));
        expect(find.text('Copied'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
      },
    );

    testWidgets(
      'Right-clicking cell opens context menu with Copy Value, Copy Row JSON, and Relational Navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        String? clipboardData;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'Clipboard.setData') {
                clipboardData =
                    (methodCall.arguments as Map)['text'] as String?;
                return null;
              }
              return null;
            });

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Right-click on first row (artist entity)
        final cellFinder = find.text('da5d1c54-3f89-4b13-a00a-9228ae564f44');
        await tester.tap(cellFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Copy Value'), findsOneWidget);
        expect(find.text('Copy Row JSON'), findsOneWidget);
        expect(find.text('View in Artist Table'), findsOneWidget);

        // Tap Copy Row JSON
        await tester.tap(find.text('Copy Row JSON'));
        await tester.pumpAndSettle();

        expect(clipboardData, isNotNull);
        final decoded = jsonDecode(clipboardData!) as Map<String, dynamic>;
        expect(decoded['id'], equals('da5d1c54-3f89-4b13-a00a-9228ae564f44'));
        expect(decoded['entity_type'], equals('artist'));
      },
    );

    testWidgets(
      'Relational navigation in Entity table switches to target table with ID filter',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Right-click on first row (artist entity)
        final cellFinder = find.text('da5d1c54-3f89-4b13-a00a-9228ae564f44');
        await tester.tap(cellFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        // Tap View in Artist Table
        await tester.tap(find.text('View in Artist Table'));
        await tester.pumpAndSettle();

        expect(controller.selectedTable, equals('Artist'));
        expect(
          controller.searchQuery,
          equals('da5d1c54-3f89-4b13-a00a-9228ae564f44'),
        );
        expect(find.text('Ludwig van Beethoven'), findsOneWidget);
      },
    );

    testWidgets(
      'Compact health status cards render horizontally with compact height and right-aligned action buttons',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        expect(find.text('Database Health Status'), findsOneWidget);
        expect(find.text('Database Size'), findsOneWidget);
        expect(find.text('WAL Journal'), findsOneWidget);
        expect(find.text('Reclaimable Space'), findsOneWidget);
        expect(find.text('Integrity Status'), findsOneWidget);

        expect(find.byKey(const Key('checkpoint_wal_button')), findsWidgets);
        expect(find.byKey(const Key('vacuum_database_button')), findsWidgets);
        expect(find.byKey(const Key('verify_integrity_button')), findsWidgets);
      },
    );

    testWidgets(
      'Relational navigation in Asset table finds in Audio table with Hash filter',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);
        controller.selectTable('Asset');

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final assetRow = controller.pagedRows.first;
        final fileHash = assetRow['file_hash'] as String;

        final cellFinder = find.text(fileHash);
        expect(cellFinder, findsOneWidget);

        // Right-click to open context menu
        await tester.tap(cellFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Find in Audio Table (Hash)'), findsOneWidget);
        await tester.tap(find.text('Find in Audio Table (Hash)'));
        await tester.pumpAndSettle();

        expect(controller.selectedTable, equals('Audio'));
        expect(controller.searchQuery, equals(fileHash));
      },
    );

    testWidgets(
      'Relational navigation in Audio table links to Track and Asset tables',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);
        controller.selectTable('Audio');

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final audioRow = controller.pagedRows.first;
        final pcmHash = audioRow['pcm_hash'] as String;

        final cellFinder = find.text(pcmHash);
        expect(cellFinder, findsOneWidget);

        await tester.tap(cellFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Find in Track Table (PCM)'), findsOneWidget);
        expect(find.text('View in Asset Table'), findsOneWidget);

        await tester.tap(find.text('View in Asset Table'));
        await tester.pumpAndSettle();

        expect(controller.selectedTable, equals('Asset'));
      },
    );

    testWidgets(
      'Tapping cell provides in-place copy visual feedback and assigns ValueKey',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);

        String? clipboardData;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'Clipboard.setData') {
                clipboardData =
                    (methodCall.arguments as Map)['text'] as String?;
                return null;
              }
              return null;
            });

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Check ValueKey exists on cell
        final firstRow = controller.pagedRows.first;
        final expectedKey = ValueKey('${firstRow['id']}_id');
        final cellFinder = find.byKey(expectedKey);
        expect(cellFinder, findsOneWidget);

        // Verify tooltip richMessage is configured on cell
        final cellTooltip = tester.widget<Tooltip>(
          find.descendant(of: cellFinder, matching: find.byType(Tooltip)),
        );
        expect(cellTooltip.richMessage, isNotNull);
        expect(cellTooltip.richMessage, isA<WidgetSpan>());

        // Hover over cell to verify tooltip displays 'Click to copy'
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: tester.getCenter(cellFinder));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Click to copy'), findsOneWidget);

        // Click cell to copy
        await tester.tap(cellFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(clipboardData, equals(firstRow['id']));

        // Verify in-place feedback is shown (green checkmark + Copied)
        expect(find.text('Copied'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);

        // Fast forward 1600ms to verify copy timer expiration and reset to Click to copy
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Click to copy'), findsOneWidget);
        expect(find.text('Copied'), findsNothing);

        // Test stale-state reset immediately on mouse exit
        await tester.tap(cellFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Copied'), findsOneWidget);

        // Move mouse away to trigger onExit
        await gesture.moveTo(Offset.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // When mouse exits, stale Copied state is reset immediately
        expect(find.text('Copied'), findsNothing);
        await gesture.removePointer();
      },
    );

    testWidgets(
      'Image table schema aligns with core SQLite image table without role column',
      (tester) async {
        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);
        controller.selectTable('Image');

        expect(
          controller.currentColumns,
          equals([
            'image_hash',
            'file_hash',
            'width',
            'height',
            'dominant_color',
          ]),
        );
        expect(controller.currentColumns.contains('role'), isFalse);
      },
    );

    testWidgets(
      'Asset table context menu provides Find in Image Table (Hash) for image mime types',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);
        controller.selectTable('Asset');

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final imageRow = controller.pagedRows.firstWhere(
          (r) => (r['mime_type'] as String).startsWith('image/'),
        );
        final fileHash = imageRow['file_hash'] as String;

        final cellFinder = find.text(fileHash);
        expect(cellFinder, findsOneWidget);

        await tester.tap(cellFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Find in Image Table (Hash)'), findsOneWidget);
        await tester.tap(find.text('Find in Image Table (Hash)'));
        await tester.pumpAndSettle();

        expect(controller.selectedTable, equals('Image'));
        expect(controller.searchQuery, equals(fileHash));
      },
    );

    testWidgets(
      'Image table context menu provides View in Asset Table and primary tap copies value',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = DatabaseExplorerController();
        addTearDown(controller.dispose);
        controller.selectTable('Image');

        String? clipboardData;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'Clipboard.setData') {
                clipboardData =
                    (methodCall.arguments as Map)['text'] as String?;
                return null;
              }
              return null;
            });

        await tester.pumpWidget(
          _buildDatabaseExplorerTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final imgRow = controller.pagedRows.first;
        final fileHash = imgRow['file_hash'] as String;

        final cellFinder = find.text(fileHash);
        expect(cellFinder, findsOneWidget);

        // 1. Primary tap should copy to clipboard, NOT navigate away
        await tester.tap(cellFinder);
        await tester.pump();

        expect(clipboardData, equals(fileHash));
        expect(controller.selectedTable, equals('Image'));

        // 2. Right-click should open context menu with 'View in Asset Table'
        await tester.tap(cellFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('View in Asset Table'), findsOneWidget);
        await tester.tap(find.text('View in Asset Table'));
        await tester.pumpAndSettle();

        expect(controller.selectedTable, equals('Asset'));
        expect(controller.searchQuery, equals(fileHash));
      },
    );
  });
}
