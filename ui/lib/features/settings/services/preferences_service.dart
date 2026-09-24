// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<void> resetTableColumns() async {
    try {
      await _prefs.remove(keyTrackColumnOrder);
      await _prefs.remove(keyTrackVisibleColumns);
      await _prefs.remove(keyTrackColumnWidths);
      await _prefs.remove(keyWorkColumnOrder);
      await _prefs.remove(keyWorkVisibleColumns);
      await _prefs.remove(keyPlaylistColumnOrder);
      await _prefs.remove(keyPlaylistVisibleColumns);
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
      if (val is num) return val.toInt().clamp(30, 1200);
      if (val is String) {
        final parsed = int.tryParse(val);
        if (parsed != null) return parsed.clamp(30, 1200);
      }
      return 140;
    } catch (_) {
      return 140;
    }
  }

  @override
  Future<void> setNowPlayingWaveformPoints(int points) async {
    final clamped = points.clamp(30, 1200);
    try {
      await _prefs.setInt(keyNowPlayingWaveformPoints, clamped);
    } catch (_) {}
    notifyListeners();
  }

  @override
  int get inspectorWaveformPoints {
    try {
      final val = _prefs.get(keyInspectorWaveformPoints);
      if (val is num) return val.toInt().clamp(30, 300);
      if (val is String) {
        final parsed = int.tryParse(val);
        if (parsed != null) return parsed.clamp(30, 300);
      }
      return 100;
    } catch (_) {
      return 100;
    }
  }

  @override
  Future<void> setInspectorWaveformPoints(int points) async {
    final clamped = points.clamp(30, 300);
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
       _showNowPlayingWaveform = showNowPlayingWaveform,
       _showInspectorWaveform = showInspectorWaveform,
       _nowPlayingWaveformPoints = nowPlayingWaveformPoints.clamp(30, 1200),
       _inspectorWaveformPoints = inspectorWaveformPoints.clamp(30, 300),
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
       _casAutoVerify = casAutoVerify;

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
  Future<void> resetTableColumns() async {
    _trackColumnOrder = null;
    _trackVisibleColumns = null;
    _trackColumnWidths = {};
    _workColumnOrder = null;
    _workVisibleColumns = null;
    _playlistColumnOrder = null;
    _playlistVisibleColumns = null;
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
    _nowPlayingWaveformPoints = points.clamp(30, 1200);
    notifyListeners();
  }

  @override
  int get inspectorWaveformPoints => _inspectorWaveformPoints;

  @override
  Future<void> setInspectorWaveformPoints(int points) async {
    _inspectorWaveformPoints = points.clamp(30, 300);
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
}
