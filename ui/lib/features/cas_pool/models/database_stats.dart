// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// SQLite database metrics, WAL status, space usage, and health status.
@immutable
class DatabaseStats {
  /// File system path to the active SQLite database file.
  final String databasePath;

  /// Total physical size of the primary database file in bytes.
  final int databaseSizeBytes;

  /// Current physical size of the write-ahead log (WAL) file in bytes.
  final int walSizeBytes;

  /// Number of WAL frames/pages not yet checkpointed back to the main DB.
  final int walUncommittedPages;

  /// Reclaimable freelist space in bytes.
  final int reclaimableSizeBytes;

  /// Result of integrity checks, e.g. 'OK'.
  final String integrityStatus;

  /// Page size allocated by SQLite in bytes (typically 4096).
  final int pageSizeBytes;

  /// Total number of allocated pages in the database file.
  final int pageCount;

  /// Current SQLite database user version / schema migration version.
  final int schemaVersion;

  /// SQLite library version string (e.g. '3.45.1').
  final String sqliteVersion;

  /// Active journal mode (e.g. 'WAL').
  final String journalMode;

  const DatabaseStats({
    required this.databasePath,
    required this.databaseSizeBytes,
    required this.walSizeBytes,
    required this.walUncommittedPages,
    required this.reclaimableSizeBytes,
    this.integrityStatus = 'OK',
    this.pageSizeBytes = 4096,
    this.pageCount = 9830,
    this.schemaVersion = 12,
    this.sqliteVersion = '3.45.1',
    this.journalMode = 'WAL',
  });

  /// Factory constructor providing realistic default SQLite statistics for Lyra.
  factory DatabaseStats.defaults() {
    return const DatabaseStats(
      databasePath: '~/.local/share/lyra/lyra.db',
      databaseSizeBytes: 40265318, // ~38.4 MB
      walSizeBytes: 1258291, // ~1.2 MB
      walUncommittedPages: 42,
      reclaimableSizeBytes: 3984588, // ~3.8 MB freelist
      integrityStatus: 'OK',
      pageSizeBytes: 4096,
      pageCount: 9830,
      schemaVersion: 12,
      sqliteVersion: '3.45.1',
      journalMode: 'WAL',
    );
  }

  /// Creates a copy of [DatabaseStats] with mutated fields.
  DatabaseStats copyWith({
    String? databasePath,
    int? databaseSizeBytes,
    int? walSizeBytes,
    int? walUncommittedPages,
    int? reclaimableSizeBytes,
    String? integrityStatus,
    int? pageSizeBytes,
    int? pageCount,
    int? schemaVersion,
    String? sqliteVersion,
    String? journalMode,
  }) {
    return DatabaseStats(
      databasePath: databasePath ?? this.databasePath,
      databaseSizeBytes: databaseSizeBytes ?? this.databaseSizeBytes,
      walSizeBytes: walSizeBytes ?? this.walSizeBytes,
      walUncommittedPages: walUncommittedPages ?? this.walUncommittedPages,
      reclaimableSizeBytes: reclaimableSizeBytes ?? this.reclaimableSizeBytes,
      integrityStatus: integrityStatus ?? this.integrityStatus,
      pageSizeBytes: pageSizeBytes ?? this.pageSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      sqliteVersion: sqliteVersion ?? this.sqliteVersion,
      journalMode: journalMode ?? this.journalMode,
    );
  }

  /// Formatted database file size.
  String get formattedDatabaseSize => formatBytes(databaseSizeBytes);

  /// Formatted WAL file size.
  String get formattedWalSize => formatBytes(walSizeBytes);

  /// Formatted reclaimable freelist size.
  String get formattedReclaimableSize => formatBytes(reclaimableSizeBytes);

  /// Formatted WAL pages string (e.g. '42 pages').
  String get formattedWalPages => '$walUncommittedPages pages';

  /// Formatted page size.
  String get formattedPageSize => formatBytes(pageSizeBytes);

  /// Formatted page count with thousands separators.
  String get formattedPageCount => formatNumber(pageCount);

  /// Formatted uncommitted pages count with thousands separators.
  String get formattedUncommittedPages => formatNumber(walUncommittedPages);

  /// Formats byte count into human-readable representation.
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Formats an integer using thousands separators (e.g. 1842 -> 1,842).
  static String formatNumber(int number) {
    final str = number.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DatabaseStats &&
          runtimeType == other.runtimeType &&
          databasePath == other.databasePath &&
          databaseSizeBytes == other.databaseSizeBytes &&
          walSizeBytes == other.walSizeBytes &&
          walUncommittedPages == other.walUncommittedPages &&
          reclaimableSizeBytes == other.reclaimableSizeBytes &&
          integrityStatus == other.integrityStatus &&
          pageSizeBytes == other.pageSizeBytes &&
          pageCount == other.pageCount &&
          schemaVersion == other.schemaVersion &&
          sqliteVersion == other.sqliteVersion &&
          journalMode == other.journalMode;

  @override
  int get hashCode =>
      databasePath.hashCode ^
      databaseSizeBytes.hashCode ^
      walSizeBytes.hashCode ^
      walUncommittedPages.hashCode ^
      reclaimableSizeBytes.hashCode ^
      integrityStatus.hashCode ^
      pageSizeBytes.hashCode ^
      pageCount.hashCode ^
      schemaVersion.hashCode ^
      sqliteVersion.hashCode ^
      journalMode.hashCode;
}

/// Data payload for a browsable SQLite table containing column headers and row entries.
@immutable
class TableData {
  /// Name of the database table (e.g. 'Entity', 'Track').
  final String tableName;

  /// Ordered list of column names for this table.
  final List<String> columns;

  /// List of data rows, where each row is a map from column name to cell value.
  final List<Map<String, dynamic>> rows;

  /// Total count of rows in the table.
  final int totalCount;

  const TableData({
    required this.tableName,
    required this.columns,
    required this.rows,
    required this.totalCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableData &&
          runtimeType == other.runtimeType &&
          tableName == other.tableName &&
          listEquals(columns, other.columns) &&
          listEquals(rows, other.rows) &&
          totalCount == other.totalCount;

  @override
  int get hashCode =>
      tableName.hashCode ^
      Object.hashAll(columns) ^
      Object.hashAll(rows) ^
      totalCount.hashCode;
}

/// Statistics and domain role for an individual SQLite table.
@immutable
class TableStatItem {
  /// Name of the database table (e.g. 'Asset', 'Audio', 'Track').
  final String tableName;

  /// Total number of records stored in this table.
  final int recordCount;

  /// Functional role / classification of this entity within Lyra's domain.
  final String role;

  /// Optional contextual details, e.g. deduplication benefit.
  final String? details;

  const TableStatItem({
    required this.tableName,
    required this.recordCount,
    required this.role,
    this.details,
  });

  /// Formatted record count with thousands separators (e.g. 2,418).
  String get formattedRecordCount => DatabaseStats.formatNumber(recordCount);

  /// Default table statistics reflecting Lyra's single-level star topology and CAS deduplication.
  static List<TableStatItem> defaults() {
    return const [
      TableStatItem(
        tableName: 'Asset',
        recordCount: 2418,
        role: 'Physical CAS Blobs',
        details: '2,418 unique payloads on disk',
      ),
      TableStatItem(
        tableName: 'Audio',
        recordCount: 1842,
        role: 'Audio Entities',
        details: '576 duplicate tracks deduplicated',
      ),
      TableStatItem(
        tableName: 'Track',
        recordCount: 2418,
        role: 'Playback Track Records',
        details: '1:1 mapped to album releases',
      ),
      TableStatItem(
        tableName: 'Album',
        recordCount: 184,
        role: 'Release Collections',
        details: 'Normalized disc & multi-track releases',
      ),
      TableStatItem(
        tableName: 'Artist',
        recordCount: 312,
        role: 'Creator & Performer Entities',
        details: 'Linked across tracks and albums',
      ),
      TableStatItem(
        tableName: 'Work',
        recordCount: 1205,
        role: 'Musical Compositions',
        details: 'Canonical works and movements',
      ),
      TableStatItem(
        tableName: 'Playlist',
        recordCount: 28,
        role: 'User Collections',
        details: 'Custom sequences and smart criteria',
      ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableStatItem &&
          runtimeType == other.runtimeType &&
          tableName == other.tableName &&
          recordCount == other.recordCount &&
          role == other.role &&
          details == other.details;

  @override
  int get hashCode =>
      tableName.hashCode ^
      recordCount.hashCode ^
      role.hashCode ^
      details.hashCode;
}
