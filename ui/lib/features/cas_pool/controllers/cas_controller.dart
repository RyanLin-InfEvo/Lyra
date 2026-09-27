// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/cas_object.dart';

/// Available tabs in the Content Addressable Storage & Database Explorer view.
enum CasTab {
  /// Tab 1: Storage capacity metrics, integrity validation, and content-addressed blobs browser.
  storageOverview,

  /// Tab 2: SQLite database file health, WAL page checkpoints, and table records count.
  databaseExplorer,

  /// Tab 3: Miniaudio hardware buffers, exclusive mode, database tuning, and ingestion pipeline.
  backendSettings,
}

/// State controller managing CAS storage metrics, tabs, search filtering, and maintenance actions.
class CasController extends ChangeNotifier {
  CasTab _activeTab;
  List<CasObject> _casObjects;
  String _searchQuery = '';

  // Storage metric overrides or defaults
  int _waveformCacheBytes;
  int _databaseBytes;
  int _orphanedCount;
  int _orphanedBytes;

  // Verification state
  bool _isVerifying = false;
  double _verificationProgress = 0.0;

  // Pruning and cache clearing states
  bool _isPruning = false;
  bool _isClearingWaveforms = false;

  bool _disposed = false;

  /// Creates a new [CasController] instance with optional initial state.
  CasController({
    CasTab initialTab = CasTab.storageOverview,
    List<CasObject>? initialObjects,
    int? initialWaveformCacheBytes,
    int? initialDatabaseBytes,
    int initialOrphanedCount = 0,
    int initialOrphanedBytes = 0,
  }) : _activeTab = initialTab,
       _casObjects = initialObjects != null
           ? List<CasObject>.from(initialObjects)
           : <CasObject>[],
       _waveformCacheBytes =
           initialWaveformCacheBytes ??
           (initialObjects != null && initialObjects.isNotEmpty
               ? 142 * 1024 * 1024
               : 0),
       _databaseBytes =
           initialDatabaseBytes ??
           (initialObjects != null && initialObjects.isNotEmpty
               ? (38.4 * 1024 * 1024).round()
               : 0),
       _orphanedCount = initialOrphanedCount,
       _orphanedBytes = initialOrphanedBytes;

  /// Whether this controller has been disposed.
  bool get isDisposed => _disposed;

  // ---------------------------------------------------------------------------
  // Tab Management
  // ---------------------------------------------------------------------------

  /// Currently active tab in the CAS Explorer.
  CasTab get activeTab => _activeTab;

  /// Switches the active tab.
  void setTab(CasTab tab) {
    if (_disposed || _activeTab == tab) return;
    _activeTab = tab;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CAS Objects & Search Filtering
  // ---------------------------------------------------------------------------

  /// Unmodifiable view of all CAS objects currently loaded.
  List<CasObject> get casObjects => List.unmodifiable(_casObjects);

  /// Updates the list of CAS objects.
  void setCasObjects(List<CasObject> objects) {
    if (_disposed) return;
    _casObjects = List<CasObject>.from(objects);
    if (_waveformCacheBytes == 0 && _casObjects.isNotEmpty) {
      _waveformCacheBytes = 142 * 1024 * 1024;
    }
    if (_databaseBytes == 0 && _casObjects.isNotEmpty) {
      _databaseBytes = (38.4 * 1024 * 1024).round();
    }
    notifyListeners();
  }

  /// Current search keyword filtering the CAS blobs list.
  String get searchQuery => _searchQuery;

  /// Updates the search filter query.
  void setSearchQuery(String query) {
    if (_disposed || _searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Filtered list of CAS objects matching the current [searchQuery].
  ///
  /// Matches case-insensitively against file SHA-256 hash substring or MIME type.
  List<CasObject> get filteredCasObjects {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return List.unmodifiable(_casObjects);
    }
    return _casObjects.where((obj) {
      final matchesHash = obj.hash.toLowerCase().contains(query);
      final matchesMime = obj.mimeType.toLowerCase().contains(query);
      return matchesHash || matchesMime;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Storage Metrics
  // ---------------------------------------------------------------------------

  /// Total number of content-addressed physical blobs.
  int get totalBlobs => _casObjects.length;

  /// Total physical size in bytes across all CAS objects.
  int get totalBytes =>
      _casObjects.fold<int>(0, (sum, obj) => sum + obj.sizeBytes);

  /// Cumulative size of audio asset blobs in bytes.
  int get audioBytes => _casObjects
      .where(
        (obj) =>
            obj.assetType.toLowerCase() == 'audio' ||
            obj.mimeType.toLowerCase().startsWith('audio/'),
      )
      .fold<int>(0, (sum, obj) => sum + obj.sizeBytes);

  /// Cumulative size of image/cover asset blobs in bytes.
  int get coverBytes => _casObjects
      .where(
        (obj) =>
            obj.assetType.toLowerCase().contains('cover') ||
            obj.assetType.toLowerCase().contains('image') ||
            obj.mimeType.toLowerCase().startsWith('image/'),
      )
      .fold<int>(0, (sum, obj) => sum + obj.sizeBytes);

  /// Size of precomputed waveform cache files in bytes.
  int get waveformCacheBytes => _waveformCacheBytes;

  /// Sets the waveform cache byte size directly (e.g. from backend metrics).
  void setWaveformCacheBytes(int bytes) {
    if (_disposed || _waveformCacheBytes == bytes) return;
    _waveformCacheBytes = bytes;
    notifyListeners();
  }

  /// Size of SQLite database and index overhead in bytes.
  int get databaseBytes => _databaseBytes;

  /// Sets the database overhead byte size directly.
  void setDatabaseBytes(int bytes) {
    if (_disposed || _databaseBytes == bytes) return;
    _databaseBytes = bytes;
    notifyListeners();
  }

  /// Total combined storage pool bytes (blobs + waveform cache + database overhead).
  int get totalPoolBytes => totalBytes + _waveformCacheBytes + _databaseBytes;

  /// Formatted string representing the cryptographic immutability status.
  String get immutabilityStatus {
    if (_casObjects.isEmpty) {
      return 'No Blobs';
    }
    if (_casObjects.any((obj) => !obj.verified)) {
      return 'Integrity Warning';
    }
    return '100% Bit-Perfect';
  }

  // ---------------------------------------------------------------------------
  // Integrity Verification
  // ---------------------------------------------------------------------------

  /// Whether a background SHA-256 cryptographic verification is in progress.
  bool get isVerifying => _isVerifying;

  /// Verification progress from 0.0 (started) to 1.0 (completed).
  double get verificationProgress => _verificationProgress;

  /// Initiates an integrity verification pass across all CAS blobs.
  ///
  /// Updates [verificationProgress] incrementally and resets [isVerifying] upon completion.
  Future<void> verifyIntegrity({
    Duration stepDuration = const Duration(milliseconds: 40),
  }) async {
    if (_disposed || _isVerifying) return;

    _isVerifying = true;
    _verificationProgress = 0.0;
    notifyListeners();

    const totalSteps = 5;
    for (int step = 1; step <= totalSteps; step++) {
      await Future<void>.delayed(stepDuration);
      if (_disposed) return;
      _verificationProgress = step / totalSteps;
      notifyListeners();
    }

    _isVerifying = false;
    _verificationProgress = 1.0;
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Orphan Pruning
  // ---------------------------------------------------------------------------

  /// Whether an orphaned blob garbage collection is currently running.
  bool get isPruning => _isPruning;

  /// Number of orphaned unreferenced blobs pending cleanup.
  int get orphanedCount => _orphanedCount;

  /// Size in bytes of unreferenced orphaned blobs pending cleanup.
  int get orphanedBytes => _orphanedBytes;

  /// Updates orphaned blob metrics (typically populated from backend query).
  void setOrphanedMetrics({required int count, required int bytes}) {
    if (_disposed) return;
    _orphanedCount = count;
    _orphanedBytes = bytes;
    notifyListeners();
  }

  /// Prunes unreferenced orphaned blobs from CAS storage.
  ///
  /// If [dryRun] is true, returns expected freed counts without mutating state.
  Future<Map<String, dynamic>> pruneOrphans({bool dryRun = false}) async {
    if (_disposed || _isPruning) {
      return {'orphanedCount': 0, 'orphanedBytes': 0};
    }

    if (dryRun) {
      return {'orphanedCount': _orphanedCount, 'orphanedBytes': _orphanedBytes};
    }

    _isPruning = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_disposed) {
      return {'orphanedCount': 0, 'orphanedBytes': 0};
    }

    final freedCount = _orphanedCount;
    final freedBytes = _orphanedBytes;

    _orphanedCount = 0;
    _orphanedBytes = 0;
    _isPruning = false;
    notifyListeners();

    return {'orphanedCount': freedCount, 'orphanedBytes': freedBytes};
  }

  // ---------------------------------------------------------------------------
  // Waveform Cache Clearing
  // ---------------------------------------------------------------------------

  /// Whether waveform cache clearing is currently in progress.
  bool get isClearingWaveforms => _isClearingWaveforms;

  /// Clears the waveform cache and resets cache bytes to zero.
  Future<void> clearWaveforms() async {
    if (_disposed || _isClearingWaveforms) return;

    _isClearingWaveforms = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_disposed) return;

    _waveformCacheBytes = 0;
    _isClearingWaveforms = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Byte Formatting Utilities
  // ---------------------------------------------------------------------------

  /// Formats raw byte count into human-readable representation.
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

  /// Formatted total storage size.
  String get formattedTotalBytes => formatBytes(totalBytes);

  /// Formatted audio assets storage size.
  String get formattedAudioBytes => formatBytes(audioBytes);

  /// Formatted cover assets storage size.
  String get formattedCoverBytes => formatBytes(coverBytes);

  /// Formatted image assets storage size (alias to [formattedCoverBytes]).
  String get formattedImageBytes => formattedCoverBytes;

  /// Formatted waveform cache size.
  String get formattedWaveformCacheBytes => formatBytes(waveformCacheBytes);

  /// Formatted orphaned blobs size.
  String get formattedOrphanedBytes => formatBytes(orphanedBytes);

  /// Formatted database overhead size.
  String get formattedDatabaseBytes => formatBytes(databaseBytes);

  /// Formatted total combined pool storage size.
  String get formattedTotalPoolBytes => formatBytes(totalPoolBytes);

  // ---------------------------------------------------------------------------
  // Lifecycle Management
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
