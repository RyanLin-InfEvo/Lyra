// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode for activating audio playback from track lists and tables.
enum TrackActivationMode {
  /// Double-clicking a track row or pressing Enter initiates playback. Single-clicking selects/focuses the row.
  doubleClick,

  /// Single-clicking a track row immediately initiates playback.
  singleClick;

  static TrackActivationMode fromString(String? value) {
    if (value == null) return TrackActivationMode.doubleClick;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return TrackActivationMode.doubleClick;
    for (final mode in TrackActivationMode.values) {
      if (mode.name == trimmed) return mode;
    }
    final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    for (final mode in TrackActivationMode.values) {
      if (mode.name.toLowerCase() == normalized) return mode;
    }
    return TrackActivationMode.doubleClick;
  }
}

/// Display layout mode for track lists (Tracks Library, Playlist Detail, Up Next Queue).
enum TrackListViewMode {
  /// Compact vertical list item (cover art on left, stacked title & metadata in middle, trailing duration/badges on right).
  list,

  /// Multi-column file-manager-style table row.
  detail;

  /// Parses a [TrackListViewMode] from a raw string, defaulting to [fallback].
  static TrackListViewMode fromString(
    String? value, {
    TrackListViewMode fallback = TrackListViewMode.detail,
  }) {
    if (value == null || value.isEmpty) {
      return fallback;
    }
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '');
    if (normalized == 'list') {
      return TrackListViewMode.list;
    }
    if (normalized == 'detail' ||
        normalized == 'details' ||
        normalized == 'table') {
      return TrackListViewMode.detail;
    }
    for (final mode in TrackListViewMode.values) {
      if (mode.name.toLowerCase() == normalized) {
        return mode;
      }
    }
    return fallback;
  }
}

/// Target view selector for the Views & Layout settings section.
enum ViewSettingsTarget {
  tracks('Tracks Library'),
  playlist('Playlist Detail'),
  upNext('Up Next Queue');

  final String label;
  const ViewSettingsTarget(this.label);
}

/// Screen placement options for floating toast notifications.
enum NotificationPosition {
  bottomLeft,
  bottomRight,
  topLeft,
  topRight;

  String get label {
    switch (this) {
      case NotificationPosition.bottomLeft:
        return 'Bottom Left';
      case NotificationPosition.bottomRight:
        return 'Bottom Right';
      case NotificationPosition.topLeft:
        return 'Top Left';
      case NotificationPosition.topRight:
        return 'Top Right';
    }
  }

  static NotificationPosition fromString(String? value) {
    if (value == null) return NotificationPosition.bottomLeft;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return NotificationPosition.bottomLeft;
    for (final pos in NotificationPosition.values) {
      if (pos.name == trimmed) return pos;
    }
    final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    for (final pos in NotificationPosition.values) {
      if (pos.name.toLowerCase() == normalized) return pos;
    }
    return NotificationPosition.bottomLeft;
  }
}

/// Abstract service defining persistence operations for application preferences and table states.
abstract class PreferencesService extends ChangeNotifier {
  // Theme mode & Accent
  ThemeMode get themeMode;
  Future<void> setThemeMode(ThemeMode mode);

  String get accentColor;
  Future<void> setAccentColor(String color);

  // Sidebar collapsed & width
  bool get isSidebarCollapsed;
  Future<void> setSidebarCollapsed(bool collapsed);
  double get sidebarWidth;
  Future<void> setSidebarWidth(double width);
  Future<void> resetSidebarWidth();

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

  List<String>? getUpNextColumnOrder();
  Future<void> setUpNextColumnOrder(List<String> columns);

  Set<String>? getUpNextVisibleColumns();
  Future<void> setUpNextVisibleColumns(Set<String> columns);

  TrackListViewMode get trackViewMode;
  Future<void> setTrackViewMode(TrackListViewMode mode);

  TrackListViewMode get playlistViewMode;
  Future<void> setPlaylistViewMode(TrackListViewMode mode);

  TrackListViewMode get upNextViewMode;
  Future<void> setUpNextViewMode(TrackListViewMode mode);

  bool get showTrackHeader;
  Future<void> setShowTrackHeader(bool show);

  bool get showPlaylistHeader;
  Future<void> setShowPlaylistHeader(bool show);

  bool get showUpNextHeader;
  Future<void> setShowUpNextHeader(bool show);

  Future<void> resetTableColumns();

  // Waveform visualization preferences
  bool get showNowPlayingWaveform;
  Future<void> setShowNowPlayingWaveform(bool show);

  bool get showInspectorWaveform;
  Future<void> setShowInspectorWaveform(bool show);

  int get nowPlayingWaveformPoints;
  Future<void> setNowPlayingWaveformPoints(int points);

  int get inspectorWaveformPoints;
  Future<void> setInspectorWaveformPoints(int points);

  bool get nowPlayingWaveformPulseAnimation;
  Future<void> setNowPlayingWaveformPulseAnimation(bool enabled);

  bool get inspectorWaveformPulseAnimation;
  Future<void> setInspectorWaveformPulseAnimation(bool enabled);

  bool get nowPlayingWaveformHoverTimeGuide;
  Future<void> setNowPlayingWaveformHoverTimeGuide(bool enabled);

  bool get inspectorWaveformHoverTimeGuide;
  Future<void> setInspectorWaveformHoverTimeGuide(bool enabled);

  // Fallbacks for backward compatibility
  bool get waveformPulseAnimation;
  Future<void> setWaveformPulseAnimation(bool enabled);

  bool get waveformHoverTimeGuide;
  Future<void> setWaveformHoverTimeGuide(bool enabled);

  // Legacy Audio & CAS settings (for backward compatibility)
  bool get audioExclusiveMode;
  Future<void> setAudioExclusiveMode(bool enabled);

  int get audioBufferSize;
  Future<void> setAudioBufferSize(int size);

  bool get audioDopEnabled;
  Future<void> setAudioDopEnabled(bool enabled);

  bool get casAutoVerify;
  Future<void> setCasAutoVerify(bool enabled);

  // Track activation mode
  TrackActivationMode get trackActivationMode;
  Future<void> setTrackActivationMode(TrackActivationMode mode);

  // Notification placement & auto-dismiss
  NotificationPosition get notificationPosition;
  Future<void> setNotificationPosition(NotificationPosition position);

  bool get toastAutoDismiss;
  Future<void> setToastAutoDismiss(bool autoDismiss);

  bool get toastShowProgressBar;
  Future<void> setToastShowProgressBar(bool show);

  int get toastDurationSeconds;
  Future<void> setToastDurationSeconds(int seconds);
}

/// SharedPreferences implementation of [PreferencesService] for persistent desktop storage.
class SharedPreferencesService extends PreferencesService {
  static const String keyThemeMode = 'lyra_theme_mode';
  static const String keyAccentColor = 'lyra_accent_color';
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
  static const String keyUpNextColumnOrder = 'lyra_up_next_column_order';
  static const String keyUpNextVisibleColumns = 'lyra_up_next_visible_columns';
  static const String keyTrackViewMode = 'lyra_track_view_mode';
  static const String keyPlaylistViewMode = 'lyra_playlist_view_mode';
  static const String keyUpNextViewMode = 'lyra_up_next_view_mode';
  static const String keyShowTrackHeader = 'lyra_show_track_header';
  static const String keyShowPlaylistHeader = 'lyra_show_playlist_header';
  static const String keyShowUpNextHeader = 'lyra_show_up_next_header';
  static const String keyShowNowPlayingWaveform =
      'lyra_show_now_playing_waveform';
  static const String keyShowInspectorWaveform = 'lyra_show_inspector_waveform';
  static const String keyNowPlayingWaveformPoints =
      'lyra_now_playing_waveform_points';
  static const String keyInspectorWaveformPoints =
      'lyra_inspector_waveform_points';
  static const String keyNowPlayingWaveformPulseAnimation =
      'lyra_now_playing_waveform_pulse_animation';
  static const String keyInspectorWaveformPulseAnimation =
      'lyra_inspector_waveform_pulse_animation';
  static const String keyNowPlayingWaveformHoverTimeGuide =
      'lyra_now_playing_waveform_hover_time_guide';
  static const String keyInspectorWaveformHoverTimeGuide =
      'lyra_inspector_waveform_hover_time_guide';
  static const String keyWaveformPulseAnimation =
      'lyra_waveform_pulse_animation';
  static const String keyWaveformHoverTimeGuide =
      'lyra_waveform_hover_time_guide';
  static const String keyAudioExclusiveMode = 'lyra_audio_exclusive_mode';
  static const String keyAudioBufferSize = 'lyra_audio_buffer_size';
  static const String keyAudioDopEnabled = 'lyra_audio_dop_enabled';
  static const String keyCasAutoVerify = 'lyra_cas_auto_verify';
  static const String keyTrackActivationMode = 'lyra_track_activation_mode';
  static const String keyNotificationPosition = 'lyra_notification_position';
  static const String keyToastAutoDismiss = 'lyra_toast_auto_dismiss';
  static const String keyToastShowProgressBar = 'lyra_toast_show_progress_bar';
  static const String keyToastDurationSeconds = 'lyra_toast_duration_seconds';

  final SharedPreferences _prefs;

  SharedPreferencesService(this._prefs);

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
    notifyListeners();
  }

  @override
  String get accentColor {
    try {
      final val = _prefs.getString(keyAccentColor);
      return val ?? 'zinc';
    } catch (_) {
      return 'zinc';
    }
  }

  @override
  Future<void> setAccentColor(String color) async {
    try {
      await _prefs.setString(keyAccentColor, color);
    } catch (_) {}
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  @override
  Future<void> resetSidebarWidth() async {
    await setSidebarWidth(210.0);
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
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  @override
  Set<String>? getTrackVisibleColumns() =>
      _getStringListSafe(keyTrackVisibleColumns)?.toSet();

  @override
  Future<void> setTrackVisibleColumns(Set<String> columns) async {
    try {
      await _prefs.setStringList(keyTrackVisibleColumns, columns.toList());
    } catch (_) {}
    notifyListeners();
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
    if (mapEquals(trackColumnWidths, widths)) return;
    try {
      await _prefs.setString(keyTrackColumnWidths, jsonEncode(widths));
    } catch (_) {}
    notifyListeners();
  }

  @override
  List<String>? getWorkColumnOrder() => _getStringListSafe(keyWorkColumnOrder);

  @override
  Future<void> setWorkColumnOrder(List<String> columns) async {
    try {
      await _prefs.setStringList(keyWorkColumnOrder, columns);
    } catch (_) {}
    notifyListeners();
  }

  @override
  Set<String>? getWorkVisibleColumns() =>
      _getStringListSafe(keyWorkVisibleColumns)?.toSet();

  @override
  Future<void> setWorkVisibleColumns(Set<String> columns) async {
    try {
      await _prefs.setStringList(keyWorkVisibleColumns, columns.toList());
    } catch (_) {}
    notifyListeners();
  }

  @override
  List<String>? getPlaylistColumnOrder() =>
      _getStringListSafe(keyPlaylistColumnOrder);

  @override
  Future<void> setPlaylistColumnOrder(List<String> columns) async {
    try {
      await _prefs.setStringList(keyPlaylistColumnOrder, columns);
    } catch (_) {}
    notifyListeners();
  }

  @override
  Set<String>? getPlaylistVisibleColumns() =>
      _getStringListSafe(keyPlaylistVisibleColumns)?.toSet();

  @override
  Future<void> setPlaylistVisibleColumns(Set<String> columns) async {
    try {
      await _prefs.setStringList(keyPlaylistVisibleColumns, columns.toList());
    } catch (_) {}
    notifyListeners();
  }

  @override
  List<String>? getUpNextColumnOrder() =>
      _getStringListSafe(keyUpNextColumnOrder);

  @override
  Future<void> setUpNextColumnOrder(List<String> columns) async {
    try {
      await _prefs.setStringList(keyUpNextColumnOrder, columns);
    } catch (_) {}
    notifyListeners();
  }

  @override
  Set<String>? getUpNextVisibleColumns() =>
      _getStringListSafe(keyUpNextVisibleColumns)?.toSet();

  @override
  Future<void> setUpNextVisibleColumns(Set<String> columns) async {
    try {
      await _prefs.setStringList(keyUpNextVisibleColumns, columns.toList());
    } catch (_) {}
    notifyListeners();
  }

  TrackListViewMode _getViewModeSafe(
    String key, {
    TrackListViewMode fallback = TrackListViewMode.detail,
  }) {
    try {
      final val = _prefs.get(key);
      if (val is String) {
        return TrackListViewMode.fromString(val, fallback: fallback);
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  @override
  TrackListViewMode get trackViewMode =>
      _getViewModeSafe(keyTrackViewMode, fallback: TrackListViewMode.detail);

  @override
  Future<void> setTrackViewMode(TrackListViewMode mode) async {
    try {
      await _prefs.setString(keyTrackViewMode, mode.name);
    } catch (_) {}
    notifyListeners();
  }

  @override
  TrackListViewMode get playlistViewMode =>
      _getViewModeSafe(keyPlaylistViewMode, fallback: TrackListViewMode.detail);

  @override
  Future<void> setPlaylistViewMode(TrackListViewMode mode) async {
    try {
      await _prefs.setString(keyPlaylistViewMode, mode.name);
    } catch (_) {}
    notifyListeners();
  }

  @override
  TrackListViewMode get upNextViewMode =>
      _getViewModeSafe(keyUpNextViewMode, fallback: TrackListViewMode.list);

  @override
  Future<void> setUpNextViewMode(TrackListViewMode mode) async {
    try {
      await _prefs.setString(keyUpNextViewMode, mode.name);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get showTrackHeader {
    try {
      final val = _prefs.get(keyShowTrackHeader);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setShowTrackHeader(bool show) async {
    try {
      await _prefs.setBool(keyShowTrackHeader, show);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get showPlaylistHeader {
    try {
      final val = _prefs.get(keyShowPlaylistHeader);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setShowPlaylistHeader(bool show) async {
    try {
      await _prefs.setBool(keyShowPlaylistHeader, show);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get showUpNextHeader {
    try {
      final val = _prefs.get(keyShowUpNextHeader);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setShowUpNextHeader(bool show) async {
    try {
      await _prefs.setBool(keyShowUpNextHeader, show);
    } catch (_) {}
    notifyListeners();
  }

  @override
  Future<void> resetTableColumns() async {
    try {
      await _prefs.remove(keyTrackColumnOrder);
      await _prefs.remove(keyTrackVisibleColumns);
      await _prefs.remove(keyTrackColumnWidths);
      await _prefs.remove(keyWorkColumnOrder);
      await _prefs.remove(keyWorkVisibleColumns);
      await _prefs.remove(keyPlaylistColumnOrder);
      await _prefs.remove(keyPlaylistVisibleColumns);
      await _prefs.remove(keyUpNextColumnOrder);
      await _prefs.remove(keyUpNextVisibleColumns);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get showNowPlayingWaveform {
    try {
      final val = _prefs.get(keyShowNowPlayingWaveform);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setShowNowPlayingWaveform(bool show) async {
    try {
      await _prefs.setBool(keyShowNowPlayingWaveform, show);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get showInspectorWaveform {
    try {
      final val = _prefs.get(keyShowInspectorWaveform);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setShowInspectorWaveform(bool show) async {
    try {
      await _prefs.setBool(keyShowInspectorWaveform, show);
    } catch (_) {}
    notifyListeners();
  }

  @override
  int get nowPlayingWaveformPoints {
    try {
      final val = _prefs.get(keyNowPlayingWaveformPoints);
      if (val is num) return val.toInt().clamp(10, 1200);
      if (val is String) {
        final parsed = int.tryParse(val);
        if (parsed != null) return parsed.clamp(10, 1200);
      }
      return 140;
    } catch (_) {
      return 140;
    }
  }

  @override
  Future<void> setNowPlayingWaveformPoints(int points) async {
    final clamped = points.clamp(10, 1200);
    try {
      await _prefs.setInt(keyNowPlayingWaveformPoints, clamped);
    } catch (_) {}
    notifyListeners();
  }

  @override
  int get inspectorWaveformPoints {
    try {
      final val = _prefs.get(keyInspectorWaveformPoints);
      if (val is num) return val.toInt().clamp(10, 300);
      if (val is String) {
        final parsed = int.tryParse(val);
        if (parsed != null) return parsed.clamp(10, 300);
      }
      return 100;
    } catch (_) {
      return 100;
    }
  }

  @override
  Future<void> setInspectorWaveformPoints(int points) async {
    final clamped = points.clamp(10, 300);
    try {
      await _prefs.setInt(keyInspectorWaveformPoints, clamped);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get nowPlayingWaveformPulseAnimation {
    try {
      final val = _prefs.get(keyNowPlayingWaveformPulseAnimation);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return waveformPulseAnimation;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setNowPlayingWaveformPulseAnimation(bool enabled) async {
    try {
      await _prefs.setBool(keyNowPlayingWaveformPulseAnimation, enabled);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get inspectorWaveformPulseAnimation {
    try {
      final val = _prefs.get(keyInspectorWaveformPulseAnimation);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return waveformPulseAnimation;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setInspectorWaveformPulseAnimation(bool enabled) async {
    try {
      await _prefs.setBool(keyInspectorWaveformPulseAnimation, enabled);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get nowPlayingWaveformHoverTimeGuide {
    try {
      final val = _prefs.get(keyNowPlayingWaveformHoverTimeGuide);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return waveformHoverTimeGuide;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setNowPlayingWaveformHoverTimeGuide(bool enabled) async {
    try {
      await _prefs.setBool(keyNowPlayingWaveformHoverTimeGuide, enabled);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get inspectorWaveformHoverTimeGuide {
    try {
      final val = _prefs.get(keyInspectorWaveformHoverTimeGuide);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return waveformHoverTimeGuide;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setInspectorWaveformHoverTimeGuide(bool enabled) async {
    try {
      await _prefs.setBool(keyInspectorWaveformHoverTimeGuide, enabled);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get waveformPulseAnimation {
    try {
      final val = _prefs.get(keyWaveformPulseAnimation);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setWaveformPulseAnimation(bool enabled) async {
    try {
      await _prefs.setBool(keyWaveformPulseAnimation, enabled);
      await _prefs.setBool(keyNowPlayingWaveformPulseAnimation, enabled);
      await _prefs.setBool(keyInspectorWaveformPulseAnimation, enabled);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get waveformHoverTimeGuide {
    try {
      final val = _prefs.get(keyWaveformHoverTimeGuide);
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setWaveformHoverTimeGuide(bool enabled) async {
    try {
      await _prefs.setBool(keyWaveformHoverTimeGuide, enabled);
      await _prefs.setBool(keyNowPlayingWaveformHoverTimeGuide, enabled);
      await _prefs.setBool(keyInspectorWaveformHoverTimeGuide, enabled);
    } catch (_) {}
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  @override
  TrackActivationMode get trackActivationMode {
    try {
      final val = _prefs.get(keyTrackActivationMode);
      if (val is String) {
        return TrackActivationMode.fromString(val);
      }
      if (val is int && val >= 0 && val < TrackActivationMode.values.length) {
        return TrackActivationMode.values[val];
      }
      return TrackActivationMode.doubleClick;
    } catch (_) {
      return TrackActivationMode.doubleClick;
    }
  }

  @override
  Future<void> setTrackActivationMode(TrackActivationMode mode) async {
    try {
      await _prefs.setString(keyTrackActivationMode, mode.name);
    } catch (_) {}
    notifyListeners();
  }

  @override
  NotificationPosition get notificationPosition {
    try {
      final val = _prefs.get(keyNotificationPosition);
      if (val is String) {
        return NotificationPosition.fromString(val);
      }
      if (val is int && val >= 0 && val < NotificationPosition.values.length) {
        return NotificationPosition.values[val];
      }
      return NotificationPosition.bottomLeft;
    } catch (_) {
      return NotificationPosition.bottomLeft;
    }
  }

  @override
  Future<void> setNotificationPosition(NotificationPosition position) async {
    try {
      await _prefs.setString(keyNotificationPosition, position.name);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get toastAutoDismiss {
    try {
      final val = _prefs.get(keyToastAutoDismiss);
      if (val is bool) return val;
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setToastAutoDismiss(bool autoDismiss) async {
    try {
      await _prefs.setBool(keyToastAutoDismiss, autoDismiss);
    } catch (_) {}
    notifyListeners();
  }

  @override
  bool get toastShowProgressBar {
    try {
      return _prefs.getBool(keyToastShowProgressBar) ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setToastShowProgressBar(bool show) async {
    try {
      await _prefs.setBool(keyToastShowProgressBar, show);
    } catch (_) {}
    notifyListeners();
  }

  @override
  int get toastDurationSeconds {
    try {
      final val = _prefs.get(keyToastDurationSeconds);
      if (val is int) return val.clamp(1, 60);
      return 10;
    } catch (_) {
      return 10;
    }
  }

  @override
  Future<void> setToastDurationSeconds(int seconds) async {
    try {
      await _prefs.setInt(keyToastDurationSeconds, seconds.clamp(1, 60));
    } catch (_) {}
    notifyListeners();
  }
}

/// In-memory implementation of [PreferencesService] for testing and transient state fallbacks.
class InMemoryPreferencesService extends PreferencesService {
  ThemeMode _themeMode;
  String _accentColor;
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
  List<String>? _upNextColumnOrder;
  Set<String>? _upNextVisibleColumns;
  TrackListViewMode _trackViewMode;
  TrackListViewMode _playlistViewMode;
  TrackListViewMode _upNextViewMode;
  bool _showTrackHeader;
  bool _showPlaylistHeader;
  bool _showUpNextHeader;
  bool _showNowPlayingWaveform;
  bool _showInspectorWaveform;
  int _nowPlayingWaveformPoints;
  int _inspectorWaveformPoints;
  bool _nowPlayingWaveformPulseAnimation;
  bool _inspectorWaveformPulseAnimation;
  bool _nowPlayingWaveformHoverTimeGuide;
  bool _inspectorWaveformHoverTimeGuide;
  bool _audioExclusiveMode;
  int _audioBufferSize;
  bool _audioDopEnabled;
  bool _casAutoVerify;
  TrackActivationMode _trackActivationMode;
  NotificationPosition _notificationPosition;
  bool _toastAutoDismiss;
  bool _toastShowProgressBar;
  int _toastDurationSeconds;

  InMemoryPreferencesService({
    ThemeMode themeMode = ThemeMode.dark,
    String accentColor = 'zinc',
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
    List<String>? upNextColumnOrder,
    Set<String>? upNextVisibleColumns,
    TrackListViewMode trackViewMode = TrackListViewMode.detail,
    TrackListViewMode playlistViewMode = TrackListViewMode.detail,
    TrackListViewMode upNextViewMode = TrackListViewMode.list,
    bool showTrackHeader = true,
    bool showPlaylistHeader = true,
    bool showUpNextHeader = true,
    bool showNowPlayingWaveform = true,
    bool showInspectorWaveform = true,
    int nowPlayingWaveformPoints = 140,
    int inspectorWaveformPoints = 100,
    bool? nowPlayingWaveformPulseAnimation,
    bool? inspectorWaveformPulseAnimation,
    bool? nowPlayingWaveformHoverTimeGuide,
    bool? inspectorWaveformHoverTimeGuide,
    bool waveformPulseAnimation = true,
    bool waveformHoverTimeGuide = true,
    bool audioExclusiveMode = false,
    int audioBufferSize = 256,
    bool audioDopEnabled = false,
    bool casAutoVerify = true,
    TrackActivationMode trackActivationMode = TrackActivationMode.doubleClick,
    NotificationPosition notificationPosition = NotificationPosition.bottomLeft,
    bool toastAutoDismiss = true,
    bool toastShowProgressBar = true,
    int toastDurationSeconds = 10,
  }) : _themeMode = themeMode,
       _accentColor = accentColor,
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
       _upNextColumnOrder = upNextColumnOrder != null
           ? List<String>.from(upNextColumnOrder)
           : null,
       _upNextVisibleColumns = upNextVisibleColumns != null
           ? Set<String>.from(upNextVisibleColumns)
           : null,
       _trackViewMode = trackViewMode,
       _playlistViewMode = playlistViewMode,
       _upNextViewMode = upNextViewMode,
       _showTrackHeader = showTrackHeader,
       _showPlaylistHeader = showPlaylistHeader,
       _showUpNextHeader = showUpNextHeader,
       _showNowPlayingWaveform = showNowPlayingWaveform,
       _showInspectorWaveform = showInspectorWaveform,
       _nowPlayingWaveformPoints = nowPlayingWaveformPoints.clamp(10, 1200),
       _inspectorWaveformPoints = inspectorWaveformPoints.clamp(10, 300),
       _nowPlayingWaveformPulseAnimation =
           nowPlayingWaveformPulseAnimation ?? waveformPulseAnimation,
       _inspectorWaveformPulseAnimation =
           inspectorWaveformPulseAnimation ?? waveformPulseAnimation,
       _nowPlayingWaveformHoverTimeGuide =
           nowPlayingWaveformHoverTimeGuide ?? waveformHoverTimeGuide,
       _inspectorWaveformHoverTimeGuide =
           inspectorWaveformHoverTimeGuide ?? waveformHoverTimeGuide,
       _audioExclusiveMode = audioExclusiveMode,
       _audioBufferSize = audioBufferSize,
       _audioDopEnabled = audioDopEnabled,
       _casAutoVerify = casAutoVerify,
       _trackActivationMode = trackActivationMode,
       _notificationPosition = notificationPosition,
       _toastAutoDismiss = toastAutoDismiss,
       _toastShowProgressBar = toastShowProgressBar,
       _toastDurationSeconds = toastDurationSeconds;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
  }

  @override
  String get accentColor => _accentColor;

  @override
  Future<void> setAccentColor(String color) async {
    _accentColor = color;
    notifyListeners();
  }

  @override
  bool get isSidebarCollapsed => _isSidebarCollapsed;

  @override
  Future<void> setSidebarCollapsed(bool collapsed) async {
    _isSidebarCollapsed = collapsed;
    notifyListeners();
  }

  @override
  double get sidebarWidth => _sidebarWidth;

  @override
  Future<void> setSidebarWidth(double width) async {
    _sidebarWidth = width;
    notifyListeners();
  }

  @override
  Future<void> resetSidebarWidth() async {
    await setSidebarWidth(210.0);
  }

  @override
  double get inspectorWidth => _inspectorWidth;

  @override
  Future<void> setInspectorWidth(double width) async {
    _inspectorWidth = width;
    notifyListeners();
  }

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    notifyListeners();
  }

  @override
  List<String>? getTrackColumnOrder() =>
      _trackColumnOrder != null ? List<String>.from(_trackColumnOrder!) : null;

  @override
  Future<void> setTrackColumnOrder(List<String> columns) async {
    _trackColumnOrder = List<String>.from(columns);
    notifyListeners();
  }

  @override
  Set<String>? getTrackVisibleColumns() => _trackVisibleColumns != null
      ? Set<String>.from(_trackVisibleColumns!)
      : null;

  @override
  Future<void> setTrackVisibleColumns(Set<String> columns) async {
    _trackVisibleColumns = Set<String>.from(columns);
    notifyListeners();
  }

  @override
  Map<String, double> get trackColumnWidths =>
      Map<String, double>.from(_trackColumnWidths);

  @override
  Future<void> setTrackColumnWidths(Map<String, double> widths) async {
    if (mapEquals(_trackColumnWidths, widths)) return;
    _trackColumnWidths = Map<String, double>.from(widths);
    notifyListeners();
  }

  @override
  List<String>? getWorkColumnOrder() =>
      _workColumnOrder != null ? List<String>.from(_workColumnOrder!) : null;

  @override
  Future<void> setWorkColumnOrder(List<String> columns) async {
    _workColumnOrder = List<String>.from(columns);
    notifyListeners();
  }

  @override
  Set<String>? getWorkVisibleColumns() => _workVisibleColumns != null
      ? Set<String>.from(_workVisibleColumns!)
      : null;

  @override
  Future<void> setWorkVisibleColumns(Set<String> columns) async {
    _workVisibleColumns = Set<String>.from(columns);
    notifyListeners();
  }

  @override
  List<String>? getPlaylistColumnOrder() => _playlistColumnOrder != null
      ? List<String>.from(_playlistColumnOrder!)
      : null;

  @override
  Future<void> setPlaylistColumnOrder(List<String> columns) async {
    _playlistColumnOrder = List<String>.from(columns);
    notifyListeners();
  }

  @override
  Set<String>? getPlaylistVisibleColumns() => _playlistVisibleColumns != null
      ? Set<String>.from(_playlistVisibleColumns!)
      : null;

  @override
  Future<void> setPlaylistVisibleColumns(Set<String> columns) async {
    _playlistVisibleColumns = Set<String>.from(columns);
    notifyListeners();
  }

  @override
  List<String>? getUpNextColumnOrder() => _upNextColumnOrder != null
      ? List<String>.from(_upNextColumnOrder!)
      : null;

  @override
  Future<void> setUpNextColumnOrder(List<String> columns) async {
    _upNextColumnOrder = List<String>.from(columns);
    notifyListeners();
  }

  @override
  Set<String>? getUpNextVisibleColumns() => _upNextVisibleColumns != null
      ? Set<String>.from(_upNextVisibleColumns!)
      : null;

  @override
  Future<void> setUpNextVisibleColumns(Set<String> columns) async {
    _upNextVisibleColumns = Set<String>.from(columns);
    notifyListeners();
  }

  @override
  TrackListViewMode get trackViewMode => _trackViewMode;

  @override
  Future<void> setTrackViewMode(TrackListViewMode mode) async {
    _trackViewMode = mode;
    notifyListeners();
  }

  @override
  TrackListViewMode get playlistViewMode => _playlistViewMode;

  @override
  Future<void> setPlaylistViewMode(TrackListViewMode mode) async {
    _playlistViewMode = mode;
    notifyListeners();
  }

  @override
  TrackListViewMode get upNextViewMode => _upNextViewMode;

  @override
  Future<void> setUpNextViewMode(TrackListViewMode mode) async {
    _upNextViewMode = mode;
    notifyListeners();
  }

  @override
  bool get showTrackHeader => _showTrackHeader;

  @override
  Future<void> setShowTrackHeader(bool show) async {
    _showTrackHeader = show;
    notifyListeners();
  }

  @override
  bool get showPlaylistHeader => _showPlaylistHeader;

  @override
  Future<void> setShowPlaylistHeader(bool show) async {
    _showPlaylistHeader = show;
    notifyListeners();
  }

  @override
  bool get showUpNextHeader => _showUpNextHeader;

  @override
  Future<void> setShowUpNextHeader(bool show) async {
    _showUpNextHeader = show;
    notifyListeners();
  }

  @override
  Future<void> resetTableColumns() async {
    _trackColumnOrder = null;
    _trackVisibleColumns = null;
    _trackColumnWidths = {};
    _workColumnOrder = null;
    _workVisibleColumns = null;
    _playlistColumnOrder = null;
    _playlistVisibleColumns = null;
    _upNextColumnOrder = null;
    _upNextVisibleColumns = null;
    notifyListeners();
  }

  @override
  bool get showNowPlayingWaveform => _showNowPlayingWaveform;

  @override
  Future<void> setShowNowPlayingWaveform(bool show) async {
    _showNowPlayingWaveform = show;
    notifyListeners();
  }

  @override
  bool get showInspectorWaveform => _showInspectorWaveform;

  @override
  Future<void> setShowInspectorWaveform(bool show) async {
    _showInspectorWaveform = show;
    notifyListeners();
  }

  @override
  int get nowPlayingWaveformPoints => _nowPlayingWaveformPoints;

  @override
  Future<void> setNowPlayingWaveformPoints(int points) async {
    _nowPlayingWaveformPoints = points.clamp(10, 1200);
    notifyListeners();
  }

  @override
  int get inspectorWaveformPoints => _inspectorWaveformPoints;

  @override
  Future<void> setInspectorWaveformPoints(int points) async {
    _inspectorWaveformPoints = points.clamp(10, 300);
    notifyListeners();
  }

  @override
  bool get nowPlayingWaveformPulseAnimation =>
      _nowPlayingWaveformPulseAnimation;

  @override
  Future<void> setNowPlayingWaveformPulseAnimation(bool enabled) async {
    _nowPlayingWaveformPulseAnimation = enabled;
    notifyListeners();
  }

  @override
  bool get inspectorWaveformPulseAnimation => _inspectorWaveformPulseAnimation;

  @override
  Future<void> setInspectorWaveformPulseAnimation(bool enabled) async {
    _inspectorWaveformPulseAnimation = enabled;
    notifyListeners();
  }

  @override
  bool get nowPlayingWaveformHoverTimeGuide =>
      _nowPlayingWaveformHoverTimeGuide;

  @override
  Future<void> setNowPlayingWaveformHoverTimeGuide(bool enabled) async {
    _nowPlayingWaveformHoverTimeGuide = enabled;
    notifyListeners();
  }

  @override
  bool get inspectorWaveformHoverTimeGuide => _inspectorWaveformHoverTimeGuide;

  @override
  Future<void> setInspectorWaveformHoverTimeGuide(bool enabled) async {
    _inspectorWaveformHoverTimeGuide = enabled;
    notifyListeners();
  }

  @override
  bool get waveformPulseAnimation => _nowPlayingWaveformPulseAnimation;

  @override
  Future<void> setWaveformPulseAnimation(bool enabled) async {
    _nowPlayingWaveformPulseAnimation = enabled;
    _inspectorWaveformPulseAnimation = enabled;
    notifyListeners();
  }

  @override
  bool get waveformHoverTimeGuide => _nowPlayingWaveformHoverTimeGuide;

  @override
  Future<void> setWaveformHoverTimeGuide(bool enabled) async {
    _nowPlayingWaveformHoverTimeGuide = enabled;
    _inspectorWaveformHoverTimeGuide = enabled;
    notifyListeners();
  }

  @override
  bool get audioExclusiveMode => _audioExclusiveMode;

  @override
  Future<void> setAudioExclusiveMode(bool enabled) async {
    _audioExclusiveMode = enabled;
    notifyListeners();
  }

  @override
  int get audioBufferSize => _audioBufferSize;

  @override
  Future<void> setAudioBufferSize(int size) async {
    _audioBufferSize = size;
    notifyListeners();
  }

  @override
  bool get audioDopEnabled => _audioDopEnabled;

  @override
  Future<void> setAudioDopEnabled(bool enabled) async {
    _audioDopEnabled = enabled;
    notifyListeners();
  }

  @override
  bool get casAutoVerify => _casAutoVerify;

  @override
  Future<void> setCasAutoVerify(bool enabled) async {
    _casAutoVerify = enabled;
    notifyListeners();
  }

  @override
  TrackActivationMode get trackActivationMode => _trackActivationMode;

  @override
  Future<void> setTrackActivationMode(TrackActivationMode mode) async {
    _trackActivationMode = mode;
    notifyListeners();
  }

  @override
  NotificationPosition get notificationPosition => _notificationPosition;

  @override
  Future<void> setNotificationPosition(NotificationPosition position) async {
    _notificationPosition = position;
    notifyListeners();
  }

  @override
  bool get toastAutoDismiss => _toastAutoDismiss;

  @override
  Future<void> setToastAutoDismiss(bool autoDismiss) async {
    _toastAutoDismiss = autoDismiss;
    notifyListeners();
  }

  @override
  bool get toastShowProgressBar => _toastShowProgressBar;

  @override
  Future<void> setToastShowProgressBar(bool show) async {
    _toastShowProgressBar = show;
    notifyListeners();
  }

  @override
  int get toastDurationSeconds => _toastDurationSeconds;

  @override
  Future<void> setToastDurationSeconds(int seconds) async {
    _toastDurationSeconds = seconds.clamp(1, 60);
    notifyListeners();
  }
}
