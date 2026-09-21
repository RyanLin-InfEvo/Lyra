// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstract service defining persistence operations for application preferences and table states.
abstract class PreferencesService {
  // Theme mode
  ThemeMode get themeMode;
  Future<void> setThemeMode(ThemeMode mode);

  // Sidebar collapsed & width
  bool get isSidebarCollapsed;
  Future<void> setSidebarCollapsed(bool collapsed);
  double get sidebarWidth;
  Future<void> setSidebarWidth(double width);

  // Inspector width
  double get inspectorWidth;
  Future<void> setInspectorWidth(double width);

  // Player volume
  double get volume;
  Future<void> setVolume(double volume);

  // Table columns & ordering
  List<String>? getTrackColumnOrder();
  Future<void> setTrackColumnOrder(List<String> columns);

  Set<String>? getTrackVisibleColumns();
  Future<void> setTrackVisibleColumns(Set<String> columns);

  Map<String, double> get trackColumnWidths;
  Future<void> setTrackColumnWidths(Map<String, double> widths);

  List<String>? getWorkColumnOrder();
  Future<void> setWorkColumnOrder(List<String> columns);

  Set<String>? getWorkVisibleColumns();
  Future<void> setWorkVisibleColumns(Set<String> columns);

  List<String>? getPlaylistColumnOrder();
  Future<void> setPlaylistColumnOrder(List<String> columns);

  Set<String>? getPlaylistVisibleColumns();
  Future<void> setPlaylistVisibleColumns(Set<String> columns);

  // Audio & CAS settings
  bool get audioExclusiveMode;
  Future<void> setAudioExclusiveMode(bool enabled);

  int get audioBufferSize;
  Future<void> setAudioBufferSize(int size);

  bool get audioDopEnabled;
  Future<void> setAudioDopEnabled(bool enabled);

  bool get casAutoVerify;
  Future<void> setCasAutoVerify(bool enabled);
}

/// SharedPreferences implementation of [PreferencesService] for persistent desktop storage.
class SharedPreferencesService implements PreferencesService {
  static const String keyThemeMode = 'lyra_theme_mode';
  static const String keySidebarCollapsed = 'lyra_sidebar_collapsed';
  static const String keySidebarWidth = 'lyra_sidebar_width';
  static const String keyInspectorWidth = 'lyra_inspector_width';
  static const String keyVolume = 'lyra_volume';
  static const String keyTrackColumnOrder = 'lyra_track_column_order';
  static const String keyTrackVisibleColumns = 'lyra_track_visible_columns';
  static const String keyTrackColumnWidths = 'lyra_track_column_widths';
  static const String keyWorkColumnOrder = 'lyra_work_column_order';
  static const String keyWorkVisibleColumns = 'lyra_work_visible_columns';
  static const String keyPlaylistColumnOrder = 'lyra_playlist_column_order';
  static const String keyPlaylistVisibleColumns =
      'lyra_playlist_visible_columns';
  static const String keyAudioExclusiveMode = 'lyra_audio_exclusive_mode';
  static const String keyAudioBufferSize = 'lyra_audio_buffer_size';
  static const String keyAudioDopEnabled = 'lyra_audio_dop_enabled';
  static const String keyCasAutoVerify = 'lyra_cas_auto_verify';

  final SharedPreferences _prefs;

  const SharedPreferencesService(this._prefs);

  @override
  ThemeMode get themeMode {
    try {
      final val = _prefs.get(keyThemeMode);
      if (val is String) {
        return ThemeMode.values.firstWhere(
          (mode) => mode.name == val,
          orElse: () => ThemeMode.dark,
        );
      }
      return ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      await _prefs.setString(keyThemeMode, mode.name);
    } catch (_) {}
  }

  @override
  bool get isSidebarCollapsed {
    try {
      final val = _prefs.get(keySidebarCollapsed);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setSidebarCollapsed(bool collapsed) async {
    try {
      await _prefs.setBool(keySidebarCollapsed, collapsed);
    } catch (_) {}
  }

  @override
  double get sidebarWidth {
    try {
      final val = _prefs.get(keySidebarWidth);
      if (val is num) {
        final d = val.toDouble();
        if (d.isNaN || d.isInfinite) return 210.0;
        return d.clamp(160.0, 420.0);
      }
      if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed != null && !parsed.isNaN && !parsed.isInfinite) {
          return parsed.clamp(160.0, 420.0);
        }
        return 210.0;
      }
      return 210.0;
    } catch (_) {
      return 210.0;
    }
  }

  @override
  Future<void> setSidebarWidth(double width) async {
    try {
      await _prefs.setDouble(keySidebarWidth, width);
    } catch (_) {}
  }

  @override
  double get inspectorWidth {
    try {
      final val = _prefs.get(keyInspectorWidth);
      if (val is num) {
        final d = val.toDouble();
        if (d.isNaN || d.isInfinite) return 420.0;
        return d.clamp(300.0, 1000.0);
      }
      if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed != null && !parsed.isNaN && !parsed.isInfinite) {
          return parsed.clamp(300.0, 1000.0);
        }
        return 420.0;
      }
      return 420.0;
    } catch (_) {
      return 420.0;
    }
  }

  @override
  Future<void> setInspectorWidth(double width) async {
    try {
      await _prefs.setDouble(keyInspectorWidth, width);
    } catch (_) {}
  }

  @override
  double get volume {
    try {
      final val = _prefs.get(keyVolume);
      if (val is num) {
        final d = val.toDouble();
        if (d.isNaN || d.isInfinite) return 0.85;
        return d.clamp(0.0, 1.0);
      }
      if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed != null && !parsed.isNaN && !parsed.isInfinite) {
          return parsed.clamp(0.0, 1.0);
        }
        return 0.85;
      }
      return 0.85;
    } catch (_) {
      return 0.85;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _prefs.setDouble(keyVolume, volume);
    } catch (_) {}
  }

  List<String>? _getStringListSafe(String key) {
    try {
      final val = _prefs.get(key);
      if (val is List) {
        if (val.isEmpty || val.any((e) => e is! String)) {
          return null;
        }
        return val.cast<String>().toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  List<String>? getTrackColumnOrder() =>
      _getStringListSafe(keyTrackColumnOrder);

  @override
  Future<void> setTrackColumnOrder(List<String> columns) async {
    try {
      await _prefs.setStringList(keyTrackColumnOrder, columns);
    } catch (_) {}
  }

  @override
  Set<String>? getTrackVisibleColumns() =>
      _getStringListSafe(keyTrackVisibleColumns)?.toSet();

  @override
  Future<void> setTrackVisibleColumns(Set<String> columns) async {
    try {
      await _prefs.setStringList(keyTrackVisibleColumns, columns.toList());
    } catch (_) {}
  }

  @override
  Map<String, double> get trackColumnWidths {
    try {
      final val = _prefs.getString(keyTrackColumnWidths);
      if (val == null) return {};
      final decoded = jsonDecode(val);
      if (decoded is Map) {
        final Map<String, double> result = {};
        for (final entry in decoded.entries) {
          if (entry.key is String && entry.value is num) {
            final d = (entry.value as num).toDouble();
            if (!d.isNaN && !d.isInfinite && d > 0) {
              result[entry.key as String] = d;
            }
          }
        }
        return result;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> setTrackColumnWidths(Map<String, double> widths) async {
    try {
      await _prefs.setString(keyTrackColumnWidths, jsonEncode(widths));
    } catch (_) {}
  }

  @override
  List<String>? getWorkColumnOrder() => _getStringListSafe(keyWorkColumnOrder);

  @override
  Future<void> setWorkColumnOrder(List<String> columns) async {
    try {
      await _prefs.setStringList(keyWorkColumnOrder, columns);
    } catch (_) {}
  }

  @override
  Set<String>? getWorkVisibleColumns() =>
      _getStringListSafe(keyWorkVisibleColumns)?.toSet();

  @override
  Future<void> setWorkVisibleColumns(Set<String> columns) async {
    try {
      await _prefs.setStringList(keyWorkVisibleColumns, columns.toList());
    } catch (_) {}
  }

  @override
  List<String>? getPlaylistColumnOrder() =>
      _getStringListSafe(keyPlaylistColumnOrder);

  @override
  Future<void> setPlaylistColumnOrder(List<String> columns) async {
    try {
      await _prefs.setStringList(keyPlaylistColumnOrder, columns);
    } catch (_) {}
  }

  @override
  Set<String>? getPlaylistVisibleColumns() =>
      _getStringListSafe(keyPlaylistVisibleColumns)?.toSet();

  @override
  Future<void> setPlaylistVisibleColumns(Set<String> columns) async {
    try {
      await _prefs.setStringList(keyPlaylistVisibleColumns, columns.toList());
    } catch (_) {}
  }

  @override
  bool get audioExclusiveMode {
    try {
      final val = _prefs.get(keyAudioExclusiveMode);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setAudioExclusiveMode(bool enabled) async {
    try {
      await _prefs.setBool(keyAudioExclusiveMode, enabled);
    } catch (_) {}
  }

  @override
  int get audioBufferSize {
    try {
      final val = _prefs.get(keyAudioBufferSize);
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 256;
      return 256;
    } catch (_) {
      return 256;
    }
  }

  @override
  Future<void> setAudioBufferSize(int size) async {
    try {
      await _prefs.setInt(keyAudioBufferSize, size);
    } catch (_) {}
  }

  @override
  bool get audioDopEnabled {
    try {
      final val = _prefs.get(keyAudioDopEnabled);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setAudioDopEnabled(bool enabled) async {
    try {
      await _prefs.setBool(keyAudioDopEnabled, enabled);
    } catch (_) {}
  }

  @override
  bool get casAutoVerify {
    try {
      final val = _prefs.get(keyCasAutoVerify);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setCasAutoVerify(bool enabled) async {
    try {
      await _prefs.setBool(keyCasAutoVerify, enabled);
    } catch (_) {}
  }
}

/// In-memory implementation of [PreferencesService] for testing and transient state fallbacks.
class InMemoryPreferencesService implements PreferencesService {
  ThemeMode _themeMode;
  bool _isSidebarCollapsed;
  double _sidebarWidth;
  double _inspectorWidth;
  double _volume;
  List<String>? _trackColumnOrder;
  Set<String>? _trackVisibleColumns;
  Map<String, double> _trackColumnWidths;
  List<String>? _workColumnOrder;
  Set<String>? _workVisibleColumns;
  List<String>? _playlistColumnOrder;
  Set<String>? _playlistVisibleColumns;
  bool _audioExclusiveMode;
  int _audioBufferSize;
  bool _audioDopEnabled;
  bool _casAutoVerify;

  InMemoryPreferencesService({
    ThemeMode themeMode = ThemeMode.dark,
    bool isSidebarCollapsed = false,
    double sidebarWidth = 210.0,
    double inspectorWidth = 420.0,
    double volume = 0.85,
    List<String>? trackColumnOrder,
    Set<String>? trackVisibleColumns,
    Map<String, double>? trackColumnWidths,
    List<String>? workColumnOrder,
    Set<String>? workVisibleColumns,
    List<String>? playlistColumnOrder,
    Set<String>? playlistVisibleColumns,
    bool audioExclusiveMode = false,
    int audioBufferSize = 256,
    bool audioDopEnabled = false,
    bool casAutoVerify = true,
  }) : _themeMode = themeMode,
       _isSidebarCollapsed = isSidebarCollapsed,
       _sidebarWidth = sidebarWidth,
       _inspectorWidth = inspectorWidth,
       _volume = volume,
       _trackColumnOrder = trackColumnOrder != null
           ? List<String>.from(trackColumnOrder)
           : null,
       _trackVisibleColumns = trackVisibleColumns != null
           ? Set<String>.from(trackVisibleColumns)
           : null,
       _trackColumnWidths = trackColumnWidths != null
           ? Map<String, double>.from(trackColumnWidths)
           : {},
       _workColumnOrder = workColumnOrder != null
           ? List<String>.from(workColumnOrder)
           : null,
       _workVisibleColumns = workVisibleColumns != null
           ? Set<String>.from(workVisibleColumns)
           : null,
       _playlistColumnOrder = playlistColumnOrder != null
           ? List<String>.from(playlistColumnOrder)
           : null,
       _playlistVisibleColumns = playlistVisibleColumns != null
           ? Set<String>.from(playlistVisibleColumns)
           : null,
       _audioExclusiveMode = audioExclusiveMode,
       _audioBufferSize = audioBufferSize,
       _audioDopEnabled = audioDopEnabled,
       _casAutoVerify = casAutoVerify;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
  }

  @override
  bool get isSidebarCollapsed => _isSidebarCollapsed;

  @override
  Future<void> setSidebarCollapsed(bool collapsed) async {
    _isSidebarCollapsed = collapsed;
  }

  @override
  double get sidebarWidth => _sidebarWidth;

  @override
  Future<void> setSidebarWidth(double width) async {
    _sidebarWidth = width;
  }

  @override
  double get inspectorWidth => _inspectorWidth;

  @override
  Future<void> setInspectorWidth(double width) async {
    _inspectorWidth = width;
  }

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  List<String>? getTrackColumnOrder() =>
      _trackColumnOrder != null ? List<String>.from(_trackColumnOrder!) : null;

  @override
  Future<void> setTrackColumnOrder(List<String> columns) async {
    _trackColumnOrder = List<String>.from(columns);
  }

  @override
  Set<String>? getTrackVisibleColumns() => _trackVisibleColumns != null
      ? Set<String>.from(_trackVisibleColumns!)
      : null;

  @override
  Future<void> setTrackVisibleColumns(Set<String> columns) async {
    _trackVisibleColumns = Set<String>.from(columns);
  }

  @override
  Map<String, double> get trackColumnWidths =>
      Map<String, double>.from(_trackColumnWidths);

  @override
  Future<void> setTrackColumnWidths(Map<String, double> widths) async {
    _trackColumnWidths = Map<String, double>.from(widths);
  }

  @override
  List<String>? getWorkColumnOrder() =>
      _workColumnOrder != null ? List<String>.from(_workColumnOrder!) : null;

  @override
  Future<void> setWorkColumnOrder(List<String> columns) async {
    _workColumnOrder = List<String>.from(columns);
  }

  @override
  Set<String>? getWorkVisibleColumns() => _workVisibleColumns != null
      ? Set<String>.from(_workVisibleColumns!)
      : null;

  @override
  Future<void> setWorkVisibleColumns(Set<String> columns) async {
    _workVisibleColumns = Set<String>.from(columns);
  }

  @override
  List<String>? getPlaylistColumnOrder() => _playlistColumnOrder != null
      ? List<String>.from(_playlistColumnOrder!)
      : null;

  @override
  Future<void> setPlaylistColumnOrder(List<String> columns) async {
    _playlistColumnOrder = List<String>.from(columns);
  }

  @override
  Set<String>? getPlaylistVisibleColumns() => _playlistVisibleColumns != null
      ? Set<String>.from(_playlistVisibleColumns!)
      : null;

  @override
  Future<void> setPlaylistVisibleColumns(Set<String> columns) async {
    _playlistVisibleColumns = Set<String>.from(columns);
  }

  @override
  bool get audioExclusiveMode => _audioExclusiveMode;

  @override
  Future<void> setAudioExclusiveMode(bool enabled) async {
    _audioExclusiveMode = enabled;
  }

  @override
  int get audioBufferSize => _audioBufferSize;

  @override
  Future<void> setAudioBufferSize(int size) async {
    _audioBufferSize = size;
  }

  @override
  bool get audioDopEnabled => _audioDopEnabled;

  @override
  Future<void> setAudioDopEnabled(bool enabled) async {
    _audioDopEnabled = enabled;
  }

  @override
  bool get casAutoVerify => _casAutoVerify;

  @override
  Future<void> setCasAutoVerify(bool enabled) async {
    _casAutoVerify = enabled;
  }
}
