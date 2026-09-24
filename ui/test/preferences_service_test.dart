// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/playlists/playlist_detail_view.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/settings/services/preferences_service.dart';
import 'package:ui/features/shell/app_shell.dart';
import 'package:ui/features/works/works_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesService Tests', () {
    test('default values when preferences are empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesService(prefs);

      expect(service.themeMode, ThemeMode.dark);
      expect(service.accentColor, 'zinc');
      expect(service.isSidebarCollapsed, isFalse);
      expect(service.sidebarWidth, 210.0);
      expect(service.inspectorWidth, 420.0);
      expect(service.volume, 0.85);
      expect(service.getTrackColumnOrder(), isNull);
      expect(service.getTrackVisibleColumns(), isNull);
      expect(service.trackColumnWidths, isEmpty);
      expect(service.getWorkColumnOrder(), isNull);
      expect(service.getWorkVisibleColumns(), isNull);
      expect(service.getPlaylistColumnOrder(), isNull);
      expect(service.getPlaylistVisibleColumns(), isNull);
      expect(service.showNowPlayingWaveform, isTrue);
      expect(service.showInspectorWaveform, isTrue);
      expect(service.nowPlayingWaveformPoints, 140);
      expect(service.inspectorWaveformPoints, 100);
      expect(service.nowPlayingWaveformPulseAnimation, isTrue);
      expect(service.inspectorWaveformPulseAnimation, isTrue);
      expect(service.nowPlayingWaveformHoverTimeGuide, isTrue);
      expect(service.inspectorWaveformHoverTimeGuide, isTrue);
      expect(service.waveformPulseAnimation, isTrue);
      expect(service.waveformHoverTimeGuide, isTrue);
      expect(service.audioExclusiveMode, isFalse);
      expect(service.audioBufferSize, 256);
      expect(service.audioDopEnabled, isFalse);
      expect(service.casAutoVerify, isTrue);
    });

    test('initializes with mock initial values correctly', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesService.keyThemeMode: 'light',
        SharedPreferencesService.keyAccentColor: 'emerald',
        SharedPreferencesService.keySidebarCollapsed: true,
        SharedPreferencesService.keySidebarWidth: 260.0,
        SharedPreferencesService.keyInspectorWidth: 500.0,
        SharedPreferencesService.keyVolume: 0.42,
        SharedPreferencesService.keyTrackColumnOrder: ['title', 'index'],
        SharedPreferencesService.keyTrackVisibleColumns: ['title', 'duration'],
        SharedPreferencesService.keyTrackColumnWidths: jsonEncode({
          'title': 300.0,
          'duration': 90.0,
        }),
        SharedPreferencesService.keyWorkColumnOrder: ['title', 'composer'],
        SharedPreferencesService.keyWorkVisibleColumns: ['title'],
        SharedPreferencesService.keyPlaylistColumnOrder: ['album', 'title'],
        SharedPreferencesService.keyPlaylistVisibleColumns: ['album'],
        SharedPreferencesService.keyShowNowPlayingWaveform: false,
        SharedPreferencesService.keyShowInspectorWaveform: false,
        SharedPreferencesService.keyNowPlayingWaveformPoints: 280,
        SharedPreferencesService.keyInspectorWaveformPoints: 150,
        SharedPreferencesService.keyWaveformPulseAnimation: false,
        SharedPreferencesService.keyWaveformHoverTimeGuide: false,
        SharedPreferencesService.keyAudioExclusiveMode: true,
        SharedPreferencesService.keyAudioBufferSize: 512,
        SharedPreferencesService.keyAudioDopEnabled: true,
        SharedPreferencesService.keyCasAutoVerify: false,
      });

      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesService(prefs);

      expect(service.themeMode, ThemeMode.light);
      expect(service.accentColor, 'emerald');
      expect(service.isSidebarCollapsed, isTrue);
      expect(service.sidebarWidth, 260.0);
      expect(service.inspectorWidth, 500.0);
      expect(service.volume, 0.42);
      expect(service.getTrackColumnOrder(), ['title', 'index']);
      expect(service.getTrackVisibleColumns(), {'title', 'duration'});
      expect(service.trackColumnWidths, {'title': 300.0, 'duration': 90.0});
      expect(service.getWorkColumnOrder(), ['title', 'composer']);
      expect(service.getWorkVisibleColumns(), {'title'});
      expect(service.getPlaylistColumnOrder(), ['album', 'title']);
      expect(service.getPlaylistVisibleColumns(), {'album'});
      expect(service.showNowPlayingWaveform, isFalse);
      expect(service.showInspectorWaveform, isFalse);
      expect(service.nowPlayingWaveformPoints, 280);
      expect(service.inspectorWaveformPoints, 150);
      expect(service.nowPlayingWaveformPulseAnimation, isFalse);
      expect(service.inspectorWaveformPulseAnimation, isFalse);
      expect(service.nowPlayingWaveformHoverTimeGuide, isFalse);
      expect(service.inspectorWaveformHoverTimeGuide, isFalse);
      expect(service.waveformPulseAnimation, isFalse);
      expect(service.waveformHoverTimeGuide, isFalse);
      expect(service.audioExclusiveMode, isTrue);
      expect(service.audioBufferSize, 512);
      expect(service.audioDopEnabled, isTrue);
      expect(service.casAutoVerify, isFalse);
    });

    test('fallback to ThemeMode.dark on invalid themeMode string', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesService.keyThemeMode: 'unrecognized_theme',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesService(prefs);

      expect(service.themeMode, ThemeMode.dark);
    });

    test('saving and retrieving properties via setters', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesService(prefs);

      await service.setThemeMode(ThemeMode.light);
      expect(service.themeMode, ThemeMode.light);

      await service.setAccentColor('amber');
      expect(service.accentColor, 'amber');

      await service.setSidebarCollapsed(true);
      expect(service.isSidebarCollapsed, isTrue);

      await service.setSidebarWidth(280.0);
      expect(service.sidebarWidth, 280.0);

      await service.resetSidebarWidth();
      expect(service.sidebarWidth, 210.0);

      await service.setInspectorWidth(450.0);
      expect(service.inspectorWidth, 450.0);

      await service.setVolume(0.65);
      expect(service.volume, 0.65);

      await service.setTrackColumnOrder(['work', 'year']);
      expect(service.getTrackColumnOrder(), ['work', 'year']);

      await service.setTrackVisibleColumns({'work', 'year'});
      expect(service.getTrackVisibleColumns(), {'work', 'year'});

      await service.setTrackColumnWidths({'album': 220.0});
      expect(service.trackColumnWidths, {'album': 220.0});

      await service.setWorkColumnOrder(['movement', 'date']);
      expect(service.getWorkColumnOrder(), ['movement', 'date']);

      await service.setWorkVisibleColumns({'movement'});
      expect(service.getWorkVisibleColumns(), {'movement'});

      await service.setPlaylistColumnOrder(['isrc', 'genre']);
      expect(service.getPlaylistColumnOrder(), ['isrc', 'genre']);

      await service.setPlaylistVisibleColumns({'isrc'});
      expect(service.getPlaylistVisibleColumns(), {'isrc'});

      await service.resetTableColumns();
      expect(service.getTrackColumnOrder(), isNull);
      expect(service.getTrackVisibleColumns(), isNull);
      expect(service.trackColumnWidths, isEmpty);
      expect(service.getWorkColumnOrder(), isNull);
      expect(service.getWorkVisibleColumns(), isNull);
      expect(service.getPlaylistColumnOrder(), isNull);
      expect(service.getPlaylistVisibleColumns(), isNull);

      await service.setShowNowPlayingWaveform(false);
      expect(service.showNowPlayingWaveform, isFalse);

      await service.setShowInspectorWaveform(false);
      expect(service.showInspectorWaveform, isFalse);

      await service.setNowPlayingWaveformPoints(280);
      expect(service.nowPlayingWaveformPoints, 280);

      await service.setInspectorWaveformPoints(150);
      expect(service.inspectorWaveformPoints, 150);

      await service.setWaveformPulseAnimation(false);
      expect(service.waveformPulseAnimation, isFalse);

      await service.setWaveformHoverTimeGuide(false);
      expect(service.waveformHoverTimeGuide, isFalse);

      await service.setAudioExclusiveMode(true);
      expect(service.audioExclusiveMode, isTrue);

      await service.setAudioBufferSize(64);
      expect(service.audioBufferSize, 64);

      await service.setAudioDopEnabled(true);
      expect(service.audioDopEnabled, isTrue);

      await service.setCasAutoVerify(false);
      expect(service.casAutoVerify, isFalse);
    });
  });

  group('InMemoryPreferencesService Tests', () {
    test('default values', () {
      final service = InMemoryPreferencesService();

      expect(service.themeMode, ThemeMode.dark);
      expect(service.accentColor, 'zinc');
      expect(service.isSidebarCollapsed, isFalse);
      expect(service.sidebarWidth, 210.0);
      expect(service.inspectorWidth, 420.0);
      expect(service.volume, 0.85);
      expect(service.getTrackColumnOrder(), isNull);
      expect(service.getTrackVisibleColumns(), isNull);
      expect(service.trackColumnWidths, isEmpty);
      expect(service.getWorkColumnOrder(), isNull);
      expect(service.getWorkVisibleColumns(), isNull);
      expect(service.getPlaylistColumnOrder(), isNull);
      expect(service.getPlaylistVisibleColumns(), isNull);
      expect(service.showNowPlayingWaveform, isTrue);
      expect(service.showInspectorWaveform, isTrue);
      expect(service.nowPlayingWaveformPoints, 140);
      expect(service.inspectorWaveformPoints, 100);
      expect(service.nowPlayingWaveformPulseAnimation, isTrue);
      expect(service.inspectorWaveformPulseAnimation, isTrue);
      expect(service.nowPlayingWaveformHoverTimeGuide, isTrue);
      expect(service.inspectorWaveformHoverTimeGuide, isTrue);
      expect(service.waveformPulseAnimation, isTrue);
      expect(service.waveformHoverTimeGuide, isTrue);
      expect(service.audioExclusiveMode, isFalse);
      expect(service.audioBufferSize, 256);
      expect(service.audioDopEnabled, isFalse);
      expect(service.casAutoVerify, isTrue);
    });

    test('custom initial values and setters', () async {
      final service = InMemoryPreferencesService(
        themeMode: ThemeMode.light,
        accentColor: 'blue',
        isSidebarCollapsed: true,
        sidebarWidth: 260.0,
        inspectorWidth: 500.0,
        volume: 0.5,
        trackColumnOrder: ['a', 'b'],
        trackVisibleColumns: {'a'},
        trackColumnWidths: {'title': 300.0},
        workColumnOrder: ['c'],
        workVisibleColumns: {'c'},
        playlistColumnOrder: ['d'],
        playlistVisibleColumns: {'d'},
        showNowPlayingWaveform: false,
        showInspectorWaveform: false,
        nowPlayingWaveformPoints: 70,
        inspectorWaveformPoints: 50,
        waveformPulseAnimation: false,
        waveformHoverTimeGuide: false,
        audioExclusiveMode: true,
        audioBufferSize: 128,
        audioDopEnabled: true,
        casAutoVerify: false,
      );

      expect(service.themeMode, ThemeMode.light);
      expect(service.accentColor, 'blue');
      expect(service.isSidebarCollapsed, isTrue);
      expect(service.sidebarWidth, 260.0);
      expect(service.inspectorWidth, 500.0);
      expect(service.volume, 0.5);
      expect(service.getTrackColumnOrder(), ['a', 'b']);
      expect(service.getTrackVisibleColumns(), {'a'});
      expect(service.trackColumnWidths, {'title': 300.0});
      expect(service.getWorkColumnOrder(), ['c']);
      expect(service.getWorkVisibleColumns(), {'c'});
      expect(service.getPlaylistColumnOrder(), ['d']);
      expect(service.getPlaylistVisibleColumns(), {'d'});
      expect(service.showNowPlayingWaveform, isFalse);
      expect(service.showInspectorWaveform, isFalse);
      expect(service.nowPlayingWaveformPoints, 70);
      expect(service.inspectorWaveformPoints, 50);
      expect(service.nowPlayingWaveformPulseAnimation, isFalse);
      expect(service.inspectorWaveformPulseAnimation, isFalse);
      expect(service.nowPlayingWaveformHoverTimeGuide, isFalse);
      expect(service.inspectorWaveformHoverTimeGuide, isFalse);
      expect(service.waveformPulseAnimation, isFalse);
      expect(service.waveformHoverTimeGuide, isFalse);
      expect(service.audioExclusiveMode, isTrue);
      expect(service.audioBufferSize, 128);
      expect(service.audioDopEnabled, isTrue);
      expect(service.casAutoVerify, isFalse);

      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeMode, ThemeMode.dark);

      await service.setAccentColor('rose');
      expect(service.accentColor, 'rose');

      await service.setSidebarCollapsed(false);
      expect(service.isSidebarCollapsed, isFalse);

      await service.setSidebarWidth(320.0);
      expect(service.sidebarWidth, 320.0);

      await service.resetSidebarWidth();
      expect(service.sidebarWidth, 210.0);

      await service.setInspectorWidth(600.0);
      expect(service.inspectorWidth, 600.0);

      await service.setVolume(0.9);
      expect(service.volume, 0.9);

      await service.setTrackColumnOrder(['x', 'y']);
      expect(service.getTrackColumnOrder(), ['x', 'y']);

      await service.setTrackVisibleColumns({'y'});
      expect(service.getTrackVisibleColumns(), {'y'});

      await service.setTrackColumnWidths({'album': 250.0});
      expect(service.trackColumnWidths, {'album': 250.0});

      await service.setWorkColumnOrder(['z']);
      expect(service.getWorkColumnOrder(), ['z']);

      await service.setWorkVisibleColumns({'z'});
      expect(service.getWorkVisibleColumns(), {'z'});

      await service.setPlaylistColumnOrder(['p']);
      expect(service.getPlaylistColumnOrder(), ['p']);

      await service.setPlaylistVisibleColumns({'p'});
      expect(service.getPlaylistVisibleColumns(), {'p'});

      await service.resetTableColumns();
      expect(service.getTrackColumnOrder(), isNull);
      expect(service.getTrackVisibleColumns(), isNull);
      expect(service.trackColumnWidths, isEmpty);
      expect(service.getWorkColumnOrder(), isNull);
      expect(service.getWorkVisibleColumns(), isNull);
      expect(service.getPlaylistColumnOrder(), isNull);
      expect(service.getPlaylistVisibleColumns(), isNull);

      await service.setShowNowPlayingWaveform(true);
      expect(service.showNowPlayingWaveform, isTrue);

      await service.setShowInspectorWaveform(true);
      expect(service.showInspectorWaveform, isTrue);

      await service.setNowPlayingWaveformPoints(280);
      expect(service.nowPlayingWaveformPoints, 280);

      await service.setInspectorWaveformPoints(150);
      expect(service.inspectorWaveformPoints, 150);

      await service.setWaveformPulseAnimation(true);
      expect(service.waveformPulseAnimation, isTrue);

      await service.setWaveformHoverTimeGuide(true);
      expect(service.waveformHoverTimeGuide, isTrue);

      await service.setAudioExclusiveMode(false);
      expect(service.audioExclusiveMode, isFalse);

      await service.setAudioBufferSize(512);
      expect(service.audioBufferSize, 512);

      await service.setAudioDopEnabled(false);
      expect(service.audioDopEnabled, isFalse);

      await service.setCasAutoVerify(true);
      expect(service.casAutoVerify, isTrue);
    });

    test('notifies listeners when settings change', () async {
      final service = InMemoryPreferencesService();
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.setShowNowPlayingWaveform(false);
      expect(notifyCount, 1);

      await service.setShowInspectorWaveform(false);
      expect(notifyCount, 2);

      await service.setNowPlayingWaveformPoints(70);
      expect(notifyCount, 3);

      await service.setInspectorWaveformPoints(50);
      expect(notifyCount, 4);

      await service.setWaveformPulseAnimation(false);
      expect(notifyCount, 5);

      await service.setWaveformHoverTimeGuide(false);
      expect(notifyCount, 6);

      await service.resetSidebarWidth();
      expect(notifyCount, 7);

      await service.resetTableColumns();
      expect(notifyCount, 8);
    });

    test('defensive copying of lists, sets, and maps', () async {
      final list = ['col1', 'col2'];
      final set = {'col1'};
      final map = {'col1': 120.0};
      final service = InMemoryPreferencesService(
        trackColumnOrder: list,
        trackVisibleColumns: set,
        trackColumnWidths: map,
      );

      list.add('col3');
      set.add('col2');
      map['col2'] = 200.0;
      expect(service.getTrackColumnOrder(), ['col1', 'col2']);
      expect(service.getTrackVisibleColumns(), {'col1'});
      expect(service.trackColumnWidths, {'col1': 120.0});

      final retrievedList = service.getTrackColumnOrder()!;
      retrievedList.add('col4');
      expect(service.getTrackColumnOrder(), ['col1', 'col2']);

      final retrievedMap = service.trackColumnWidths;
      retrievedMap['col3'] = 300.0;
      expect(service.trackColumnWidths, {'col1': 120.0});
    });
  });

  group('Defensive Type Conversion, Error Resilience & Edge Cases', () {
    test(
      'volume getter handles int (1 and 0) and num strings without throwing',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: 1,
        });
        final prefs1 = await SharedPreferences.getInstance();
        final service1 = SharedPreferencesService(prefs1);
        expect(service1.volume, 1.0);

        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: 0,
        });
        final prefs0 = await SharedPreferences.getInstance();
        final service0 = SharedPreferencesService(prefs0);
        expect(service0.volume, 0.0);

        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: '0.45',
        });
        final prefsStr = await SharedPreferences.getInstance();
        final serviceStr = SharedPreferencesService(prefsStr);
        expect(serviceStr.volume, 0.45);

        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: 'corrupted',
        });
        final prefsErr = await SharedPreferences.getInstance();
        final serviceErr = SharedPreferencesService(prefsErr);
        expect(serviceErr.volume, 0.85);
      },
    );

    test(
      'volume getter sanitizes NaN, Infinity, negative and out-of-range values',
      () async {
        // NaN num
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: double.nan,
        });
        var prefs = await SharedPreferences.getInstance();
        var service = SharedPreferencesService(prefs);
        expect(service.volume, 0.85);

        // Infinity num
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: double.infinity,
        });
        prefs = await SharedPreferences.getInstance();
        service = SharedPreferencesService(prefs);
        expect(service.volume, 0.85);

        // Negative Infinity num
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: double.negativeInfinity,
        });
        prefs = await SharedPreferences.getInstance();
        service = SharedPreferencesService(prefs);
        expect(service.volume, 0.85);

        // Below range clamped to 0.0
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: -0.25,
        });
        prefs = await SharedPreferences.getInstance();
        service = SharedPreferencesService(prefs);
        expect(service.volume, 0.0);

        // Above range clamped to 1.0
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: 1.75,
        });
        prefs = await SharedPreferences.getInstance();
        service = SharedPreferencesService(prefs);
        expect(service.volume, 1.0);

        // String NaN
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: 'NaN',
        });
        prefs = await SharedPreferences.getInstance();
        service = SharedPreferencesService(prefs);
        expect(service.volume, 0.85);

        // String Infinity
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: 'Infinity',
        });
        prefs = await SharedPreferences.getInstance();
        service = SharedPreferencesService(prefs);
        expect(service.volume, 0.85);

        // String out of range (negative)
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: '-0.5',
        });
        prefs = await SharedPreferences.getInstance();
        service = SharedPreferencesService(prefs);
        expect(service.volume, 0.0);

        // String out of range (above 1.0)
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyVolume: '1.2',
        });
        prefs = await SharedPreferences.getInstance();
        service = SharedPreferencesService(prefs);
        expect(service.volume, 1.0);
      },
    );

    test(
      'audioBufferSize getter handles num, string, and corrupted values safely',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyAudioBufferSize: '512',
        });
        final prefs1 = await SharedPreferences.getInstance();
        final service1 = SharedPreferencesService(prefs1);
        expect(service1.audioBufferSize, 512);

        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyAudioBufferSize: 128.0,
        });
        final prefs2 = await SharedPreferences.getInstance();
        final service2 = SharedPreferencesService(prefs2);
        expect(service2.audioBufferSize, 128);

        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyAudioBufferSize: 'invalid_buffer',
        });
        final prefs3 = await SharedPreferences.getInstance();
        final service3 = SharedPreferencesService(prefs3);
        expect(service3.audioBufferSize, 256);
      },
    );

    test(
      'themeMode getter handles invalid, non-string, or unknown values safely',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyThemeMode: 'unknown_theme',
        });
        final prefs1 = await SharedPreferences.getInstance();
        final service1 = SharedPreferencesService(prefs1);
        expect(service1.themeMode, ThemeMode.dark);

        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyThemeMode: 12345,
        });
        final prefs2 = await SharedPreferences.getInstance();
        final service2 = SharedPreferencesService(prefs2);
        expect(service2.themeMode, ThemeMode.dark);
      },
    );

    test(
      'column lists return null on corrupted types or empty lists',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesService.keyTrackColumnOrder: <String>[],
          SharedPreferencesService.keyTrackVisibleColumns: <dynamic>[1, 2, 3],
          SharedPreferencesService.keyWorkColumnOrder: 'invalid_format',
          SharedPreferencesService.keyWorkVisibleColumns: <String>[],
          SharedPreferencesService.keyPlaylistColumnOrder: <dynamic>['a', 123],
          SharedPreferencesService.keyPlaylistVisibleColumns: <String>[],
        });
        final prefs = await SharedPreferences.getInstance();
        final service = SharedPreferencesService(prefs);

        expect(service.getTrackColumnOrder(), isNull);
        expect(service.getTrackVisibleColumns(), isNull);
        expect(service.getWorkColumnOrder(), isNull);
        expect(service.getWorkVisibleColumns(), isNull);
        expect(service.getPlaylistColumnOrder(), isNull);
        expect(service.getPlaylistVisibleColumns(), isNull);
      },
    );

    testWidgets(
      'volume debounce in AppShell flushes final value without flooding disk I/O',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final spyPrefs = SpyPreferencesService(volume: 0.85);
        await tester.pumpWidget(_buildTestApp(spyPrefs));
        await tester.pumpAndSettle();

        final shellState = tester.state<AppShellState>(find.byType(AppShell));

        // Rapidly fire multiple volume updates
        shellState.volumeNotifier.value = 0.50;
        shellState.volumeNotifier.value = 0.60;
        shellState.volumeNotifier.value = 0.70;

        // Pump 100ms - debounce timer has not expired yet
        await tester.pump(const Duration(milliseconds: 100));
        expect(spyPrefs.setVolumeCalls, 0);

        // Fire another update resetting the 300ms window
        shellState.volumeNotifier.value = 0.30;
        await tester.pump(const Duration(milliseconds: 200));
        expect(spyPrefs.setVolumeCalls, 0);

        // Now advance clock past 300ms from the last event
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        // Only 1 call made with the final value
        expect(spyPrefs.setVolumeCalls, 1);
        expect(spyPrefs.volume, 0.30);
      },
    );

    testWidgets(
      'volume unmount flushes pending value during active debounce timer',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final spyPrefs = SpyPreferencesService(volume: 0.85);
        await tester.pumpWidget(_buildTestApp(spyPrefs));
        await tester.pumpAndSettle();

        final shellState = tester.state<AppShellState>(find.byType(AppShell));

        // Change volume which schedules a 300ms debounce timer
        shellState.volumeNotifier.value = 0.45;

        // Advance 100ms - debounce timer is active, nothing persisted yet
        await tester.pump(const Duration(milliseconds: 100));
        expect(spyPrefs.setVolumeCalls, 0);

        // Unmount AppShell while debounce timer is still active
        await tester.pumpWidget(const SizedBox());

        // Debounce timer cancelled and volume synchronously flushed to preferencesService
        expect(spyPrefs.setVolumeCalls, 1);
        expect(spyPrefs.volume, 0.45);
      },
    );

    testWidgets(
      'corrupted column visibility storage falls back to defaults in AppShell',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Simulate storage having only unknown/corrupted column strings
        final corruptedPrefs = InMemoryPreferencesService(
          trackVisibleColumns: {'non_existent_1', 'unknown_2'},
          workVisibleColumns: {'corrupted_col'},
          playlistVisibleColumns: {'bogus_col'},
        );

        await tester.pumpWidget(_buildTestApp(corruptedPrefs));
        await tester.pumpAndSettle();

        final shellState = tester.state<AppShellState>(find.byType(AppShell));

        // Should fall back to defaultVisibleColumns, not just mandatory column
        expect(
          shellState.trackVisibleColumns,
          Set<TrackColumn>.from(TrackColumn.defaultVisibleColumns),
        );
        expect(
          shellState.workVisibleColumns,
          Set<WorkColumn>.from(WorkColumn.defaultVisibleColumns),
        );
        expect(
          shellState.playlistVisibleColumns,
          Set<TrackColumn>.from(PlaylistDetailView.defaultVisibleColumns),
        );
      },
    );
    test(
      'target-specific pulse and hover guide settings are decoupled in InMemory',
      () async {
        final service = InMemoryPreferencesService();
        expect(service.nowPlayingWaveformPulseAnimation, isTrue);
        expect(service.inspectorWaveformPulseAnimation, isTrue);

        await service.setNowPlayingWaveformPulseAnimation(false);
        expect(service.nowPlayingWaveformPulseAnimation, isFalse);
        expect(service.inspectorWaveformPulseAnimation, isTrue);

        await service.setInspectorWaveformHoverTimeGuide(false);
        expect(service.nowPlayingWaveformHoverTimeGuide, isTrue);
        expect(service.inspectorWaveformHoverTimeGuide, isFalse);

        // Fallback setters update both
        await service.setWaveformPulseAnimation(true);
        expect(service.nowPlayingWaveformPulseAnimation, isTrue);
        expect(service.inspectorWaveformPulseAnimation, isTrue);

        await service.setWaveformHoverTimeGuide(false);
        expect(service.nowPlayingWaveformHoverTimeGuide, isFalse);
        expect(service.inspectorWaveformHoverTimeGuide, isFalse);
      },
    );

    test(
      'SharedPreferencesService decouples target-specific pulse and hover guide',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = SharedPreferencesService(prefs);

        await service.setNowPlayingWaveformPulseAnimation(false);
        expect(service.nowPlayingWaveformPulseAnimation, isFalse);
        expect(service.inspectorWaveformPulseAnimation, isTrue);

        await service.setInspectorWaveformHoverTimeGuide(false);
        expect(service.nowPlayingWaveformHoverTimeGuide, isTrue);
        expect(service.inspectorWaveformHoverTimeGuide, isFalse);
      },
    );
  });
}

class SpyPreferencesService extends InMemoryPreferencesService {
  int setVolumeCalls = 0;
  SpyPreferencesService({
    super.volume,
    super.trackVisibleColumns,
    super.workVisibleColumns,
    super.playlistVisibleColumns,
  });

  @override
  Future<void> setVolume(double volume) async {
    setVolumeCalls++;
    await super.setVolume(volume);
  }
}

Widget _buildTestApp(PreferencesService prefs) {
  final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  return ShadApp(
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return ShadTheme(
          data: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadZincColorScheme.dark(),
          ),
          child: LyraDesignSystemScope(
            factory: const ShadcnFactory(),
            tokens: LyraThemeTokens.dark(),
            themeModeNotifier: themeNotifier,
            child: AppShell(
              musicService: MockMusicService(),
              preferencesService: prefs,
            ),
          ),
        );
      },
    ),
  );
}
