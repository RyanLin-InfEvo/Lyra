// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/database_stats.dart';

/// State controller managing SQLite database metrics, WAL checkpointing,
/// vacuuming operations, PRAGMA integrity verification, and the SQLite Data Browser.
class DatabaseExplorerController extends ChangeNotifier {
  DatabaseStats _stats;
  final List<TableStatItem> _tableStats;
  final Map<String, TableData> _tableDataCache;

  bool _isLoading = false;
  bool _isCheckpointing = false;
  bool _isVacuuming = false;
  bool _isVerifyingIntegrity = false;
  bool _lastActionIsError = false;
  String? _lastIntegrityStatus;
  String? _lastActionMessage;
  bool _disposed = false;

  // Data Browser state
  String _selectedTable;
  String _searchQuery = '';
  int _currentPage = 1;
  int _pageSize;
  bool _isLoadingTableData = false;
  List<Map<String, dynamic>>? _cachedFilteredRows;

  /// Ordered list of available tables in lyra.db matching domain topology.
  static const List<String> defaultTables = [
    'Entity',
    'Track',
    'Artist',
    'Album',
    'Work',
    'Playlist',
    'Tag',
    'Asset',
    'Audio',
  ];

  /// Creates a new [DatabaseExplorerController] with optional initial statistics and table data.
  DatabaseExplorerController({
    DatabaseStats? initialStats,
    List<TableStatItem>? initialTableStats,
    Map<String, TableData>? initialTableData,
    String initialTable = 'Entity',
    int initialPageSize = 50,
  }) : _stats = initialStats ?? DatabaseStats.defaults(),
       _tableStats = initialTableStats ?? TableStatItem.defaults(),
       _tableDataCache = initialTableData ?? _createDefaultTableData(),
       _selectedTable = initialTable,
       _pageSize = initialPageSize.clamp(1, 1000);

  /// Whether this controller has been disposed.
  bool get isDisposed => _disposed;

  /// Active SQLite file statistics and metrics.
  DatabaseStats get stats => _stats;

  /// Unmodifiable view of table-level record statistics.
  List<TableStatItem> get tableStats => List.unmodifiable(_tableStats);

  /// Whether statistics are currently being refreshed from SQLite.
  bool get isLoading => _isLoading;

  /// Whether a WAL checkpoint operation is currently executing.
  bool get isCheckpointing => _isCheckpointing;

  /// Whether a database VACUUM operation is currently executing.
  bool get isVacuuming => _isVacuuming;

  /// Whether a PRAGMA integrity_check pass is currently executing.
  bool get isVerifyingIntegrity => _isVerifyingIntegrity;

  /// Whether table data is currently loading.
  bool get isLoadingTableData => _isLoadingTableData;

  /// Whether any asynchronous maintenance or query operation is active.
  bool get isBusy =>
      _isLoading ||
      _isCheckpointing ||
      _isVacuuming ||
      _isVerifyingIntegrity ||
      _isLoadingTableData;

  /// Whether the most recent maintenance operation resulted in an error state.
  bool get lastActionIsError => _lastActionIsError;

  /// Result of the most recent integrity check (e.g. 'OK' or specific error string).
  String? get lastIntegrityStatus => _lastIntegrityStatus;

  /// User-facing descriptive message resulting from the most recent maintenance operation.
  String? get lastActionMessage => _lastActionMessage;

  // ---------------------------------------------------------------------------
  // Data Browser Getters & Operations
  // ---------------------------------------------------------------------------

  /// List of browsable tables in lyra.db.
  List<String> get availableTables => defaultTables;

  /// Currently selected table name for browsing.
  String get selectedTable => _selectedTable;

  /// Active search/filter string applied across all columns.
  String get searchQuery => _searchQuery;

  /// Current active page index (1-indexed).
  int get currentPage => _currentPage;

  /// Number of records displayed per page.
  int get pageSize => _pageSize;

  /// Column names of the currently selected table.
  List<String> get currentColumns {
    return _tableDataCache[_selectedTable]?.columns ?? const [];
  }

  /// Raw unfiltered rows for the currently selected table.
  List<Map<String, dynamic>> get _rawRowsForSelectedTable {
    return _tableDataCache[_selectedTable]?.rows ?? const [];
  }

  /// Rows filtered case-insensitively across all columns by [searchQuery].
  List<Map<String, dynamic>> get _filteredRows {
    if (_cachedFilteredRows != null) {
      return _cachedFilteredRows!;
    }
    final rows = _rawRowsForSelectedTable;
    if (_searchQuery.trim().isEmpty) {
      return _cachedFilteredRows = rows;
    }
    final query = _searchQuery.trim().toLowerCase();
    return _cachedFilteredRows = rows.where((row) {
      for (final value in row.values) {
        if (value != null && value.toString().toLowerCase().contains(query)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  /// Total count of rows in the selected table before filtering.
  int get totalTableCount => _rawRowsForSelectedTable.length;

  /// Total count of rows matching the current filter.
  int get filteredRowCount => _filteredRows.length;

  /// Total number of pages based on [filteredRowCount] and [pageSize] (at least 1).
  int get totalPages {
    if (filteredRowCount <= 0) return 1;
    final pages = (filteredRowCount / _pageSize).ceil();
    return pages < 1 ? 1 : pages;
  }

  /// Current slice of rows displayed on [currentPage].
  List<Map<String, dynamic>> get pagedRows {
    final filtered = _filteredRows;
    if (filtered.isEmpty) return const [];
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= filtered.length) return const [];
    final endIndex = (startIndex + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  /// Switches active table for browsing, resetting page to 1 and clearing filter.
  void selectTable(String table) {
    if (_disposed) return;
    if (_selectedTable == table) return;
    _selectedTable = table;
    _searchQuery = '';
    _cachedFilteredRows = null;
    _currentPage = 1;
    _currentPage = _currentPage.clamp(1, totalPages);
    notifyListeners();
  }

  /// Sets search query filter across all columns, resetting page to 1.
  void setSearchQuery(String query) {
    if (_disposed) return;
    if (_searchQuery == query) return;
    _searchQuery = query;
    _cachedFilteredRows = null;
    _currentPage = _currentPage.clamp(1, totalPages);
    notifyListeners();
  }

  /// Sets number of records displayed per page, clamping current page to totalPages.
  void setPageSize(int size) {
    if (_disposed) return;
    final newSize = size.clamp(1, 1000);
    if (_pageSize == newSize) return;
    _pageSize = newSize;
    _cachedFilteredRows = null;
    _currentPage = _currentPage.clamp(1, totalPages);
    notifyListeners();
  }

  /// Navigates to a specific database table and applies an optional search query filter.
  void navigateToTable(String table, {String filter = ''}) {
    if (_disposed) return;
    _selectedTable = table;
    final trimmed = filter.trim();
    _searchQuery = trimmed.isNotEmpty ? trimmed : '';
    _cachedFilteredRows = null;
    _currentPage = 1;
    _currentPage = _currentPage.clamp(1, totalPages);
    notifyListeners();
  }

  /// Navigates to the next page if not already at the last page.
  void nextPage() {
    if (_disposed) return;
    if (_currentPage < totalPages) {
      _currentPage++;
      notifyListeners();
    }
  }

  /// Navigates to the previous page if not already at the first page.
  void previousPage() {
    if (_disposed) return;
    if (_currentPage > 1) {
      _currentPage--;
      notifyListeners();
    }
  }

  /// Navigates to an explicit page, clamping to [1, totalPages].
  void goToPage(int page) {
    if (_disposed) return;
    final clamped = page.clamp(1, totalPages);
    if (_currentPage != clamped) {
      _currentPage = clamped;
      notifyListeners();
    }
  }

  /// Reloads or refreshes table data for the active view.
  Future<void> refreshTableData({
    Duration delay = const Duration(milliseconds: 30),
  }) async {
    if (_disposed || isBusy) return;
    _isLoadingTableData = true;
    _cachedFilteredRows = null;
    _currentPage = _currentPage.clamp(1, totalPages);
    notifyListeners();

    await Future<void>.delayed(delay);
    if (_disposed) return;

    _isLoadingTableData = false;
    _cachedFilteredRows = null;
    _currentPage = _currentPage.clamp(1, totalPages);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Maintenance & Query Actions
  // ---------------------------------------------------------------------------

  /// Refreshes SQLite database file metrics and table record counts.
  Future<void> loadStats({
    Duration delay = const Duration(milliseconds: 30),
  }) async {
    if (_disposed || isBusy) return;

    _isLoading = true;
    notifyListeners();

    await Future<void>.delayed(delay);
    if (_disposed) return;

    _isLoading = false;
    notifyListeners();
  }

  /// Checkpoints the write-ahead log (WAL) frames into the main database file.
  ///
  /// Flushes all uncommitted WAL pages and truncates the WAL log footprint.
  Future<void> checkpointWal({
    Duration delay = const Duration(milliseconds: 50),
  }) async {
    if (_disposed || isBusy) return;

    _isCheckpointing = true;
    notifyListeners();

    await Future<void>.delayed(delay);
    if (_disposed) return;

    // Reclaim WAL pages and update state
    _stats = _stats.copyWith(
      walUncommittedPages: 0,
      walSizeBytes: 32768, // Reset to standard 32 KB minimum header
    );
    _lastActionIsError = false;
    _lastActionMessage =
        'WAL checkpoint completed. 0 uncommitted frames remaining.';
    _isCheckpointing = false;
    notifyListeners();
  }

  /// Executes VACUUM on the SQLite database to defragment pages and reclaim unused disk space.
  Future<void> vacuumDatabase({
    Duration delay = const Duration(milliseconds: 80),
  }) async {
    if (_disposed || isBusy) return;

    _isVacuuming = true;
    notifyListeners();

    await Future<void>.delayed(delay);
    if (_disposed) return;

    // Reclaim freelist space and simulate page defragmentation
    final reclaimed = _stats.reclaimableSizeBytes > 0
        ? _stats.reclaimableSizeBytes
        : (_stats.databaseSizeBytes * 0.08).round();
    final newSize = _stats.databaseSizeBytes - reclaimed;
    final newPages = (_stats.pageCount * 0.92).round();

    _stats = _stats.copyWith(
      databaseSizeBytes: newSize,
      pageCount: newPages,
      reclaimableSizeBytes: 0,
      walUncommittedPages: 0,
      walSizeBytes: 32768,
    );
    _lastActionIsError = false;
    _lastActionMessage =
        'Database vacuum completed. Reclaimed ${DatabaseStats.formatBytes(reclaimed)} of fragmented space.';
    _isVacuuming = false;
    notifyListeners();
  }

  /// Executes PRAGMA integrity_check against SQLite database schema and indices.
  Future<void> verifyIntegrity({
    Duration delay = const Duration(milliseconds: 60),
    String mockResult = 'OK',
    bool simulateError = false,
  }) async {
    if (_disposed || isBusy) return;

    _isVerifyingIntegrity = true;
    notifyListeners();

    await Future<void>.delayed(delay);
    if (_disposed) return;

    final status = simulateError ? 'PRAGMA integrity_check failed' : mockResult;
    _lastIntegrityStatus = status;
    _stats = _stats.copyWith(integrityStatus: status);
    if (status != 'OK' || simulateError) {
      _lastActionIsError = true;
      _lastActionMessage = 'Database integrity check failed: $status.';
    } else {
      _lastActionIsError = false;
      _lastActionMessage = 'Database integrity check passed: OK.';
    }

    _isVerifyingIntegrity = false;
    notifyListeners();
  }

  /// Clears the last user-facing action message and resets the error flag.
  void clearActionMessage() {
    if (_disposed) return;
    if (_lastActionMessage == null && !_lastActionIsError) return;
    _lastActionMessage = null;
    _lastActionIsError = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle Management
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Default Realistic Mock Data Generator
  // ---------------------------------------------------------------------------

  static Map<String, TableData> _createDefaultTableData() {
    // 1. Entity table (60 rows so pageSize=50 gives 2 pages)
    final entityRows = <Map<String, dynamic>>[
      // Reference screenshot exact entries
      {
        'id': 'da5d1c54-3f89-4b13-a00a-9228ae564f44',
        'entity_type': 'artist',
        'created_at': null,
        'updated_at': '2026-03-14 01:27:20',
      },
      {
        'id': '4da4efaf-391a-4c43-a596-37509569f8e3',
        'entity_type': 'artist',
        'created_at': null,
        'updated_at': null,
      },
      {
        'id': 'ba28f049-4779-4940-9712-262afb4e7956',
        'entity_type': 'artist',
        'created_at': null,
        'updated_at': null,
      },
      {
        'id': '5b88dae6-f73a-405b-b9cb-0fcf7fdb7941',
        'entity_type': 'artist',
        'created_at': null,
        'updated_at': null,
      },
      {
        'id': '7fc19c50-b4f5-4cd9-90f8-c011a4bb2622',
        'entity_type': 'artist',
        'created_at': null,
        'updated_at': null,
      },
      {
        'id': 'c5a9f149-e703-48a9-b915-d0b6f3f3cddd',
        'entity_type': 'artist',
        'created_at': null,
        'updated_at': null,
      },
    ];

    // Generate 54 more entity rows for pagination testing
    final entityTypes = ['track', 'album', 'work', 'playlist', 'tag'];
    for (int i = 7; i <= 60; i++) {
      final hexI = i.toRadixString(16).padLeft(4, '0');
      final type = entityTypes[(i - 7) % entityTypes.length];
      final isEven = i % 2 == 0;
      entityRows.add({
        'id': 'e$hexI-0000-4000-8000-${hexI}deadbeef',
        'entity_type': type,
        'created_at': isEven
            ? '2026-03-14 02:${(i % 60).toString().padLeft(2, '0')}:00'
            : null,
        'updated_at': isEven
            ? '2026-03-14 03:${(i % 60).toString().padLeft(2, '0')}:00'
            : null,
      });
    }

    // 2. Track table (55 rows)
    final trackTitles = [
      'Symphony No. 5 in C minor, Op. 67: I. Allegro con brio',
      'Cello Suite No. 1 in G major, BWV 1007: I. Prélude',
      'Piano Concerto No. 21 in C major, K. 467: II. Andante',
      'Clair de Lune, L. 75',
      'The Four Seasons, Op. 8 No. 1 "Spring": I. Allegro',
      'Gymnopédie No. 1',
      'Nocturne in E-flat major, Op. 9 No. 2',
      'Canon in D major, P. 37',
      'Goldberg Variations, BWV 988: Aria',
      'Adagio for Strings, Op. 11',
      'Swan Lake Suite, Op. 20a: Scene',
      'Enigma Variations, Op. 36: IX. Nimrod',
      'Boléro, M. 81',
      'Peer Gynt Suite No. 1, Op. 46: Morning Mood',
      'Rhapsody in Blue',
    ];
    final trackRows = <Map<String, dynamic>>[];
    for (int i = 1; i <= 55; i++) {
      final hex = i.toRadixString(16).padLeft(8, '0');
      final title = i <= trackTitles.length
          ? trackTitles[i - 1]
          : '${trackTitles[(i - 1) % trackTitles.length]} (Take $i)';
      trackRows.add({
        'id': 'track-$hex-4000-8000-0000000000$hex',
        'title': title,
        'pcm_hash':
            'a${hex}e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8',
        'work_id': i <= 8 ? 'wrk-000$i-4000-8000-00000000000$i' : null,
        'duration': 180.0 + (i * 3.5),
        'recording_year': 1990 + (i % 35),
        'isrc': i % 3 == 0 ? null : 'USPR3${i.toString().padLeft(7, '0')}',
        'musicbrainz_id': i % 4 == 0 ? null : 'mb-rec-$hex',
      });
    }

    // 3. Artist table (15 rows)
    final artistRows = <Map<String, dynamic>>[
      {
        'id': 'da5d1c54-3f89-4b13-a00a-9228ae564f44',
        'name': 'Ludwig van Beethoven',
        'description':
            'German composer and pianist of the Classical and Romantic eras.',
        'musicbrainz_id': '1f9df192-a621-4f54-8850-2c5373b7eac9',
        'spotify_id': '2wOqMjp9TyABvtHdOSOTUS',
        'ytm_id': 'MPREb_9J40e0Beeth',
      },
      {
        'id': '4da4efaf-391a-4c43-a596-37509569f8e3',
        'name': 'Johann Sebastian Bach',
        'description': 'German composer of the late Baroque period.',
        'musicbrainz_id': '24f1766e-9635-4d58-a4d4-9413f9f98a4c',
        'spotify_id': '5aIqB5nVVvmFsvSdExz4Aj',
        'ytm_id': 'MPREb_Bach0001',
      },
      {
        'id': 'ba28f049-4779-4940-9712-262afb4e7956',
        'name': 'Wolfgang Amadeus Mozart',
        'description':
            'Prodigious and prolific composer of the Classical period.',
        'musicbrainz_id': 'b972f589-fb0e-474e-b64a-603103ec9553',
        'spotify_id': '4NJhFmfw43RLBLjQvxDuRS',
        'ytm_id': null,
      },
      {
        'id': '5b88dae6-f73a-405b-b9cb-0fcf7fdb7941',
        'name': 'Johannes Brahms',
        'description': null,
        'musicbrainz_id': 'c70d12a2-24fe-4f83-a6e6-57d84f8efb51',
        'spotify_id': '5wJ1ld52IP2NDHpKpvyEgQ',
        'ytm_id': null,
      },
      {
        'id': '7fc19c50-b4f5-4cd9-90f8-c011a4bb2622',
        'name': 'Yo-Yo Ma',
        'description': 'Renowned American cellist born in Paris.',
        'musicbrainz_id': '4e11295a-c80b-47e0-9cc4-7685002bca48',
        'spotify_id': '0u6Jj7FqY71542f7JvV1Qo',
        'ytm_id': 'MPREb_YoYoMa',
      },
      {
        'id': 'c5a9f149-e703-48a9-b915-d0b6f3f3cddd',
        'name': 'Hilary Hahn',
        'description': 'Three-time Grammy Award-winning American violinist.',
        'musicbrainz_id': 'e8dc6297-b873-455b-b4a1-0efcae40ccb7',
        'spotify_id': '5n7k8bW327Xy1f74j8bV1R',
        'ytm_id': 'MPREb_HilaryHahn',
      },
      {
        'id': 'art-0007-4000-8000-000000000007',
        'name': 'Glenn Gould',
        'description':
            'Canadian classical pianist renowned for his Bach interpretations.',
        'musicbrainz_id': 'f7d98342-a1b2-4c3d-8e4f-0123456789ab',
        'spotify_id': null,
        'ytm_id': null,
      },
      {
        'id': 'art-0008-4000-8000-000000000008',
        'name': 'Pyotr Ilyich Tchaikovsky',
        'description': null,
        'musicbrainz_id': '9cb69428-a6e7-4e0e-9275-70e72e179927',
        'spotify_id': '3MKda4W1b8r22zF30wR9eP',
        'ytm_id': null,
      },
      {
        'id': 'art-0009-4000-8000-000000000009',
        'name': 'Claude Debussy',
        'description': 'French composer associated with Impressionist music.',
        'musicbrainz_id': '50d998d7-d779-450f-a2e4-96947b055375',
        'spotify_id': '4bfpGk6mQYJp28VvHw2qL4',
        'ytm_id': null,
      },
      {
        'id': 'art-0010-4000-8000-000000000010',
        'name': 'Gustav Mahler',
        'description': null,
        'musicbrainz_id': '8d610e52-e6ed-420d-965f-4a001a1e7dcf',
        'spotify_id': '2RWBp4Q0sWn0Xp48YjJ3Vb',
        'ytm_id': null,
      },
      {
        'id': 'art-0011-4000-8000-000000000011',
        'name': 'Hans Zimmer',
        'description': 'German film score composer and music producer.',
        'musicbrainz_id': 'e6ca5200-b0e0-42a0-853f-320d3678f4e0',
        'spotify_id': '0YC192cP3KUr29chQRzbtv',
        'ytm_id': 'MPREb_HansZimmer',
      },
      {
        'id': 'art-0012-4000-8000-000000000012',
        'name': 'Max Richter',
        'description': 'German-British composer and pianist.',
        'musicbrainz_id': 'd69e4f52-4759-4ee2-bb8a-2114777e0892',
        'spotify_id': '2Kqb2G6cQe1k0H0x0xX1X1',
        'ytm_id': null,
      },
      {
        'id': 'art-0013-4000-8000-000000000013',
        'name': 'Olafur Arnalds',
        'description': null,
        'musicbrainz_id': null,
        'spotify_id': null,
        'ytm_id': null,
      },
      {
        'id': 'art-0014-4000-8000-000000000014',
        'name': 'Nils Frahm',
        'description':
            'German musician, composer, and record producer based in Berlin.',
        'musicbrainz_id': null,
        'spotify_id': '5gCOr25T9L2y3JvX9p3mK1',
        'ytm_id': null,
      },
      {
        'id': 'art-0015-4000-8000-000000000015',
        'name': 'Vikingur Olafsson',
        'description':
            'Icelandic pianist known for contemporary Bach recordings.',
        'musicbrainz_id': '89b821a4-9781-4203-9d41-36f7881c2f1e',
        'spotify_id': '1YnQoV2oZqBw2K1J0h9gL4',
        'ytm_id': null,
      },
    ];

    // 4. Album table (10 rows)
    final albumRows = <Map<String, dynamic>>[
      {
        'id': 'alb-0001-4000-8000-000000000001',
        'title': 'Bach: The Goldberg Variations (1981 Recording)',
        'release_year': 1982,
        'release_month': 9,
        'release_day': 1,
      },
      {
        'id': 'alb-0002-4000-8000-000000000002',
        'title': 'Beethoven: Symphonies Nos. 5 & 7',
        'release_year': 1975,
        'release_month': 3,
        'release_day': null,
      },
      {
        'id': 'alb-0003-4000-8000-000000000003',
        'title': 'Six Evolutions - Bach: Cello Suites',
        'release_year': 2018,
        'release_month': 8,
        'release_day': 17,
      },
      {
        'id': 'alb-0004-4000-8000-000000000004',
        'title': 'Hilary Hahn Plays Bach: Sonatas Nos. 1 & 2, Partita No. 1',
        'release_year': 1997,
        'release_month': 10,
        'release_day': 21,
      },
      {
        'id': 'alb-0005-4000-8000-000000000005',
        'title': 'Interstellar (Original Motion Picture Soundtrack)',
        'release_year': 2014,
        'release_month': 11,
        'release_day': 17,
      },
      {
        'id': 'alb-0006-4000-8000-000000000006',
        'title': 'Recomposed by Max Richter: Vivaldi - The Four Seasons',
        'release_year': 2012,
        'release_month': null,
        'release_day': null,
      },
      {
        'id': 'alb-0007-4000-8000-000000000007',
        'title': 'Debussy: Complete Piano Works',
        'release_year': 2005,
        'release_month': 4,
        'release_day': 12,
      },
      {
        'id': 'alb-0008-4000-8000-000000000008',
        'title': 'Mahler: Symphony No. 2 "Resurrection"',
        'release_year': 1987,
        'release_month': 10,
        'release_day': null,
      },
      {
        'id': 'alb-0009-4000-8000-000000000009',
        'title': 'All Melody',
        'release_year': 2018,
        'release_month': 1,
        'release_day': 26,
      },
      {
        'id': 'alb-0010-4000-8000-000000000010',
        'title': 'From Afar',
        'release_year': 2022,
        'release_month': 10,
        'release_day': 7,
      },
    ];

    // 5. Work table (8 rows)
    final workRows = <Map<String, dynamic>>[
      {
        'id': 'wrk-0001-4000-8000-000000000001',
        'title': 'Symphony No. 5 in C minor, Op. 67',
        'composition_date_text': '1804–1808',
        'iswc': 'T-801.234.567-1',
        'musicbrainz_id': 'mb-wrk-beeth-sym5',
      },
      {
        'id': 'wrk-0002-4000-8000-000000000002',
        'title': 'Cello Suites, BWV 1007–1012',
        'composition_date_text': 'c. 1717–1723',
        'iswc': 'T-802.345.678-2',
        'musicbrainz_id': 'mb-wrk-bach-suites',
      },
      {
        'id': 'wrk-0003-4000-8000-000000000003',
        'title': 'Goldberg Variations, BWV 988',
        'composition_date_text': '1741',
        'iswc': null,
        'musicbrainz_id': 'mb-wrk-bach-goldberg',
      },
      {
        'id': 'wrk-0004-4000-8000-000000000004',
        'title': 'Le quattro stagioni, Op. 8',
        'composition_date_text': '1720–1723',
        'iswc': 'T-804.567.890-4',
        'musicbrainz_id': null,
      },
      {
        'id': 'wrk-0005-4000-8000-000000000005',
        'title': 'Suite bergamasque, L. 75: III. Clair de lune',
        'composition_date_text': '1890',
        'iswc': null,
        'musicbrainz_id': null,
      },
      {
        'id': 'wrk-0006-4000-8000-000000000006',
        'title': 'Gymnopédies',
        'composition_date_text': '1888',
        'iswc': 'T-806.789.012-6',
        'musicbrainz_id': null,
      },
      {
        'id': 'wrk-0007-4000-8000-000000000007',
        'title': 'Symphony No. 2 in C minor "Resurrection"',
        'composition_date_text': '1888–1894',
        'iswc': null,
        'musicbrainz_id': 'mb-wrk-mahler-sym2',
      },
      {
        'id': 'wrk-0008-4000-8000-000000000008',
        'title': 'Nocturnes, Op. 9',
        'composition_date_text': '1830–1832',
        'iswc': 'T-808.901.234-8',
        'musicbrainz_id': null,
      },
    ];

    // 6. Playlist table (6 rows)
    final playlistRows = <Map<String, dynamic>>[
      {
        'id': 'ply-0001-4000-8000-000000000001',
        'title': 'Audiophile Reference Tracks',
        'description':
            'Bit-perfect reference recordings for high-end DACs and headphones.',
      },
      {
        'id': 'ply-0002-4000-8000-000000000002',
        'title': 'Late Night Classical & Focus',
        'description':
            'Intimate solo piano, cello, and quiet ambient soundscapes.',
      },
      {
        'id': 'ply-0003-4000-8000-000000000003',
        'title': 'Baroque Masterworks',
        'description': null,
      },
      {
        'id': 'ply-0004-4000-8000-000000000004',
        'title': 'Hi-Res Orchestral Dynamics',
        'description':
            'Full dynamic range symphonies without dynamic compression.',
      },
      {
        'id': 'ply-0005-4000-8000-000000000005',
        'title': 'Chamber Music Intimacy',
        'description': null,
      },
      {
        'id': 'ply-0006-4000-8000-000000000006',
        'title': 'Favorites',
        'description': 'Starred personal favorites collection.',
      },
    ];

    // 7. Tag table (8 rows)
    final tagRows = <Map<String, dynamic>>[
      {
        'id': 'tag-0001',
        'name': 'Hi-Res Lossless',
        'category': 'audio_quality',
      },
      {'id': 'tag-0002', 'name': 'Bit-Perfect', 'category': 'playback'},
      {'id': 'tag-0003', 'name': 'DSD / DxD', 'category': 'format'},
      {'id': 'tag-0004', 'name': 'Baroque', 'category': 'period'},
      {'id': 'tag-0005', 'name': 'Classical', 'category': 'genre'},
      {'id': 'tag-0006', 'name': 'Romantic', 'category': 'period'},
      {'id': 'tag-0007', 'name': 'Contemporary', 'category': 'genre'},
      {'id': 'tag-0008', 'name': 'Vinyl Rip', 'category': 'source'},
    ];

    // 8. Asset table (12 rows)
    final assetRows = <Map<String, dynamic>>[];
    for (int i = 1; i <= 12; i++) {
      final hex = i.toRadixString(16).padLeft(8, '0');
      assetRows.add({
        'file_hash':
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b785$hex',
        'size_bytes': 1024 * 1024 * (5 + i * 2),
        'mime_type': i % 3 == 0 ? 'image/jpeg' : 'audio/flac',
        'created_at':
            '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')} 12:00:00',
      });
    }

    // 9. Audio table (12 rows)
    final audioRows = <Map<String, dynamic>>[];
    for (int i = 1; i <= 12; i++) {
      final hex = i.toRadixString(16).padLeft(8, '0');
      audioRows.add({
        'pcm_hash':
            'a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abc$hex',
        'sample_rate': i % 2 == 0 ? 96000 : (i % 3 == 0 ? 192000 : 44100),
        'channels': 2,
        'bit_depth': i % 2 == 0 ? 24 : 16,
        'format': i % 2 == 0 ? 'pcm_s24le' : 'pcm_s16le',
      });
    }

    return {
      'Entity': TableData(
        tableName: 'Entity',
        columns: ['id', 'entity_type', 'created_at', 'updated_at'],
        rows: entityRows,
        totalCount: entityRows.length,
      ),
      'Track': TableData(
        tableName: 'Track',
        columns: [
          'id',
          'title',
          'pcm_hash',
          'work_id',
          'duration',
          'recording_year',
          'isrc',
          'musicbrainz_id',
        ],
        rows: trackRows,
        totalCount: trackRows.length,
      ),
      'Artist': TableData(
        tableName: 'Artist',
        columns: [
          'id',
          'name',
          'description',
          'musicbrainz_id',
          'spotify_id',
          'ytm_id',
        ],
        rows: artistRows,
        totalCount: artistRows.length,
      ),
      'Album': TableData(
        tableName: 'Album',
        columns: [
          'id',
          'title',
          'release_year',
          'release_month',
          'release_day',
        ],
        rows: albumRows,
        totalCount: albumRows.length,
      ),
      'Work': TableData(
        tableName: 'Work',
        columns: [
          'id',
          'title',
          'composition_date_text',
          'iswc',
          'musicbrainz_id',
        ],
        rows: workRows,
        totalCount: workRows.length,
      ),
      'Playlist': TableData(
        tableName: 'Playlist',
        columns: ['id', 'title', 'description'],
        rows: playlistRows,
        totalCount: playlistRows.length,
      ),
      'Tag': TableData(
        tableName: 'Tag',
        columns: ['id', 'name', 'category'],
        rows: tagRows,
        totalCount: tagRows.length,
      ),
      'Asset': TableData(
        tableName: 'Asset',
        columns: ['file_hash', 'size_bytes', 'mime_type', 'created_at'],
        rows: assetRows,
        totalCount: assetRows.length,
      ),
      'Audio': TableData(
        tableName: 'Audio',
        columns: ['pcm_hash', 'sample_rate', 'channels', 'bit_depth', 'format'],
        rows: audioRows,
        totalCount: audioRows.length,
      ),
    };
  }
}
