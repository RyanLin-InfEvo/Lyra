// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/core/bridge/mock_lyra_bridge.dart';
import 'package:ui/design_system/contracts/lyra_contracts.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
import 'package:ui/design_system/widgets/lyra_checkbox.dart';
import 'package:ui/design_system/widgets/lyra_copy_button.dart';
import 'package:ui/design_system/widgets/lyra_switch.dart';
import 'package:ui/features/audio/models/audio_device.dart';
import 'package:ui/features/cas_pool/controllers/backend_settings_controller.dart';
import 'package:ui/features/cas_pool/controllers/cas_controller.dart';
import 'package:ui/features/cas_pool/models/engine_config.dart';
import 'package:ui/features/cas_pool/widgets/backend_settings_tab.dart';

Widget _buildBackendSettingsTabTest({
  required BackendSettingsController controller,
  CasController? casController,
  VoidCallback? onVerifyAll,
  VoidCallback? onRequestPrune,
  VoidCallback? onRequestClearWaveforms,
  BackendSettingsSection initialSection = BackendSettingsSection.audioHardware,
  ValueChanged<BackendSettingsSection>? onSectionChanged,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Backend Settings Test',
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
            child: Scaffold(
              body: BackendSettingsTab(
                controller: controller,
                casController: casController,
                onVerifyAll: onVerifyAll,
                onRequestPrune: onRequestPrune,
                onRequestClearWaveforms: onRequestClearWaveforms,
                initialSection: initialSection,
                onSectionChanged: onSectionChanged,
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EngineConfig Model Tests', () {
    test('defaults() initializes with specification defaults', () {
      final config = EngineConfig.defaults();

      expect(config.storage.storageRoot, equals(''));
      expect(config.storage.databasePath, equals(''));
      expect(config.storage.casObjectsDir, equals(''));

      expect(config.database.cacheSizeKb, equals(131072));
      expect(config.database.mmapSizeBytes, equals(536870912));
      expect(config.database.busyTimeoutMs, equals(30000));
      expect(config.database.walAutocheckpoint, equals(1000));

      expect(config.audio.outputDeviceId, equals('default'));
      expect(config.audio.bufferSizeFrames, equals(512));
      expect(config.audio.exclusiveMode, isTrue);
      expect(
        config.audio.volumeMode,
        equals(AudioVolumeMode.bitPerfectLock0dB),
      );
      expect(config.audio.resamplerQuality, equals(ResamplerQuality.soxrHq));
      expect(config.audio.dsdMode, equals(DsdMode.dop));

      expect(config.ingestion.parallelThreads, equals(0));
      expect(config.ingestion.detectedCpuCores, equals(16));
      expect(config.ingestion.mode, equals(IngestionMode.full));
    });

    test('toJson() and fromJson() are symmetric and lossless', () {
      final original = EngineConfig.defaults();
      final json = original.toJson();
      final reconstructed = EngineConfig.fromJson(json);

      expect(reconstructed, equals(original));
      expect(reconstructed.hashCode, equals(original.hashCode));
      expect(reconstructed.isModifiedFrom(original), isFalse);
    });

    test('copyWith() updates individual fields without mutating others', () {
      final original = EngineConfig.defaults();
      final modified = original.copyWith(
        audio: original.audio.copyWith(
          bufferSizeFrames: 256,
          exclusiveMode: false,
        ),
        database: original.database.copyWith(cacheSizeKb: 262144),
      );

      expect(modified.audio.bufferSizeFrames, equals(256));
      expect(modified.audio.exclusiveMode, isFalse);
      expect(modified.database.cacheSizeKb, equals(262144));

      // Unchanged fields remain identical
      expect(modified.storage, equals(original.storage));
      expect(modified.ingestion, equals(original.ingestion));
      expect(modified.isModifiedFrom(original), isTrue);
    });

    test('Enum fromValue parses valid strings, aliases, and fallbacks', () {
      expect(
        AudioVolumeMode.fromValue('linear'),
        equals(AudioVolumeMode.linear),
      );
      expect(
        AudioVolumeMode.fromValue('logarithmic_db'),
        equals(AudioVolumeMode.logarithmicDb),
      );
      expect(
        AudioVolumeMode.fromValue('bit_perfect_lock_0db'),
        equals(AudioVolumeMode.bitPerfectLock0dB),
      );
      expect(
        AudioVolumeMode.fromValue('bitperfect_lock_0db'),
        equals(AudioVolumeMode.bitPerfectLock0dB),
      );
      expect(
        AudioVolumeMode.fromValue('invalid_mode'),
        equals(AudioVolumeMode.bitPerfectLock0dB),
      );

      expect(
        ResamplerQuality.fromValue('native'),
        equals(ResamplerQuality.native),
      );
      expect(
        ResamplerQuality.fromValue('sinc_medium'),
        equals(ResamplerQuality.sincMedium),
      );
      expect(
        ResamplerQuality.fromValue('soxr_hq'),
        equals(ResamplerQuality.soxrHq),
      );
      expect(
        ResamplerQuality.fromValue('unknown'),
        equals(ResamplerQuality.soxrHq),
      );

      expect(DsdMode.fromValue('dop'), equals(DsdMode.dop));
      expect(DsdMode.fromValue('pcm_transcode'), equals(DsdMode.pcmTranscode));
      expect(DsdMode.fromValue('invalid'), equals(DsdMode.dop));

      expect(IngestionMode.fromValue('fast'), equals(IngestionMode.fast));
      expect(IngestionMode.fromValue('full'), equals(IngestionMode.full));
      expect(IngestionMode.fromValue('unknown'), equals(IngestionMode.full));
    });

    test(
      'toSavePayload() serializes only mutable fields and excludes read-only engine paths and detected cores',
      () {
        final config = EngineConfig.defaults();
        final payload = config.toSavePayload();

        expect(payload.containsKey('storage'), isFalse);
        expect(payload.containsKey('database'), isTrue);
        expect(payload.containsKey('audio'), isTrue);
        expect(payload.containsKey('ingestion'), isTrue);

        final ingestion = payload['ingestion'] as Map<String, dynamic>;
        expect(ingestion.containsKey('parallel_threads'), isTrue);
        expect(ingestion.containsKey('mode'), isTrue);
        expect(ingestion.containsKey('detected_cpu_cores'), isFalse);
      },
    );

    test(
      'fromJson() handles robust type conversions for string numbers and integer booleans',
      () {
        final json = {
          'database': {
            'cache_size_kb': '262144',
            'mmap_size_bytes': '1073741824',
            'busy_timeout_ms': '60000',
            'wal_autocheckpoint': '2000',
          },
          'audio': {
            'output_device_id': 'dac-01',
            'buffer_size_frames': '256',
            'exclusive_mode': 0,
            'volume_mode': 'linear',
            'resampler_quality': 'native',
            'dsd_mode': 'pcm_transcode',
          },
          'ingestion': {
            'parallel_threads': '8',
            'detected_cpu_cores': '32',
            'mode': 'fast',
          },
        };

        final parsed = EngineConfig.fromJson(json);

        expect(parsed.database.cacheSizeKb, equals(262144));
        expect(parsed.database.mmapSizeBytes, equals(1073741824));
        expect(parsed.database.busyTimeoutMs, equals(60000));
        expect(parsed.database.walAutocheckpoint, equals(2000));
        expect(parsed.audio.bufferSizeFrames, equals(256));
        expect(parsed.audio.exclusiveMode, isFalse);
        expect(parsed.ingestion.parallelThreads, equals(8));
        expect(parsed.ingestion.detectedCpuCores, equals(32));
      },
    );
  });

  group('BackendSettingsController Unit Tests', () {
    late MockLyraBridge bridge;
    late BackendSettingsController controller;

    setUp(() {
      bridge = MockLyraBridge();
      controller = BackendSettingsController(bridge: bridge, autoLoad: false);
    });

    tearDown(() {
      if (!controller.isDisposed) {
        controller.dispose();
      }
      bridge.dispose();
    });

    test('Initial state is clean with no dirty or restart flags', () {
      expect(controller.isDirty, isFalse);
      expect(controller.restartRequired, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.isSaving, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.statusMessage, isNull);
    });

    test(
      'Modifying hardware buffer size marks isDirty and restartRequired',
      () {
        controller.setBufferSize(256);

        expect(controller.isDirty, isTrue);
        expect(controller.restartRequired, isTrue);
        expect(controller.pendingConfig.audio.bufferSizeFrames, equals(256));
        expect(controller.config.audio.bufferSizeFrames, equals(512));
      },
    );

    test('Modifying exclusive mode marks isDirty and restartRequired', () {
      controller.setExclusiveMode(false);

      expect(controller.isDirty, isTrue);
      expect(controller.restartRequired, isTrue);
      expect(controller.pendingConfig.audio.exclusiveMode, isFalse);
    });

    test(
      'Modifying database cache size marks isDirty but NOT restartRequired',
      () {
        controller.setDatabaseCacheSize(262144);

        expect(controller.isDirty, isTrue);
        expect(controller.restartRequired, isFalse);
        expect(controller.pendingConfig.database.cacheSizeKb, equals(262144));
      },
    );

    test('resetDraft() restores pendingConfig to committed config', () {
      controller.setBufferSize(64);
      controller.setDatabaseCacheSize(65536);
      expect(controller.isDirty, isTrue);

      controller.resetDraft();

      expect(controller.isDirty, isFalse);
      expect(controller.restartRequired, isFalse);
      expect(controller.pendingConfig, equals(controller.config));
    });

    test('restoreDefaults() resets draft to system defaults', () {
      controller.setOutputDevice('custom-dac');
      controller.setBufferSize(64);

      controller.restoreDefaults();

      expect(controller.pendingConfig.audio.bufferSizeFrames, equals(512));
      expect(controller.pendingConfig.audio.outputDeviceId, equals('default'));
    });

    test('saveConfig() dispatches to bridge and commits changes', () async {
      controller.setBufferSize(1024);
      controller.setExclusiveMode(false);
      expect(controller.isDirty, isTrue);

      final success = await controller.saveConfig();

      expect(success, isTrue);
      expect(controller.isDirty, isFalse);
      expect(controller.restartRequired, isFalse);
      expect(controller.config.audio.bufferSizeFrames, equals(1024));
      expect(controller.config.audio.exclusiveMode, isFalse);
      expect(
        controller.statusMessage,
        equals('Engine settings saved successfully.'),
      );
    });

    test(
      'loadConfig() populates config and audio devices from bridge',
      () async {
        await controller.loadConfig();

        expect(controller.isLoading, isFalse);
        expect(controller.audioDevices.isNotEmpty, isTrue);
        expect(
          controller.audioDevices.any((d) => d.id == 'usb-dac-01'),
          isTrue,
        );
      },
    );

    test('All setters properly notify listeners and update pendingConfig', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setOutputDevice('usb-dac-01');
      controller.setVolumeMode(AudioVolumeMode.logarithmicDb);
      controller.setResamplerQuality(ResamplerQuality.native);
      controller.setDsdMode(DsdMode.pcmTranscode);
      controller.setDatabaseMmapSize(268435456);
      controller.setBusyTimeout(60000);
      controller.setWalAutocheckpoint(2000);
      controller.setParallelThreads(8);
      controller.setIngestionMode(IngestionMode.fast);

      expect(notifyCount, equals(9));
      expect(
        controller.pendingConfig.audio.outputDeviceId,
        equals('usb-dac-01'),
      );
      expect(
        controller.pendingConfig.audio.volumeMode,
        equals(AudioVolumeMode.logarithmicDb),
      );
      expect(
        controller.pendingConfig.audio.resamplerQuality,
        equals(ResamplerQuality.native),
      );
      expect(
        controller.pendingConfig.audio.dsdMode,
        equals(DsdMode.pcmTranscode),
      );
      expect(
        controller.pendingConfig.database.mmapSizeBytes,
        equals(268435456),
      );
      expect(controller.pendingConfig.database.busyTimeoutMs, equals(60000));
      expect(controller.pendingConfig.database.walAutocheckpoint, equals(2000));
      expect(controller.pendingConfig.ingestion.parallelThreads, equals(8));
      expect(
        controller.pendingConfig.ingestion.mode,
        equals(IngestionMode.fast),
      );
    });

    test(
      'saveConfig() handles error response without code and retains isDirty',
      () async {
        bridge.registerMockHandler(
          'system.set_config',
          (payload) async => {
            'success': false,
            'status': 'error',
            'message': 'Device error',
          },
        );
        controller.setBufferSize(256);
        expect(controller.isDirty, isTrue);

        final success = await controller.saveConfig();

        expect(success, isFalse);
        expect(controller.isDirty, isTrue);
        expect(controller.errorMessage, equals('Device error'));
        expect(controller.config.audio.bufferSizeFrames, equals(512));
      },
    );

    test(
      'saveConfig() does not mutate state or schedule timer if controller is disposed while awaiting',
      () async {
        final completer = Completer<Map<String, dynamic>>();
        bridge.registerMockHandler(
          'system.set_config',
          (payload) => completer.future,
        );

        controller.setBufferSize(256);
        final saveFuture = controller.saveConfig();

        controller.dispose();
        completer.complete({'code': 200, 'message': 'Success'});

        final result = await saveFuture;
        expect(result, isFalse);
        expect(controller.statusMessage, isNull);
      },
    );

    test(
      'saveConfig() retains server-authoritative restart_required flag',
      () async {
        bridge.registerMockHandler(
          'system.set_config',
          (payload) async => {
            'code': 200,
            'status': 'success',
            'data': {'restart_required': true},
          },
        );
        controller.setDatabaseCacheSize(262144);
        expect(controller.restartRequired, isFalse);

        final success = await controller.saveConfig();

        expect(success, isTrue);
        expect(controller.isDirty, isFalse);
        expect(controller.isRestartPending, isTrue);

        controller.acknowledgeRestart();
        expect(controller.isRestartPending, isFalse);
      },
    );

    test(
      'loadConfig() sets errorMessage and fails fast when bridge returns error code or status',
      () async {
        bridge.registerMockHandler(
          'system.get_config',
          (payload) async => {
            'code': 500,
            'status': 'error',
            'message': 'Storage daemon unreachable',
          },
        );

        final initialConfig = controller.config;
        await controller.loadConfig();

        expect(controller.errorMessage, isNotNull);
        expect(controller.errorMessage, contains('Storage daemon unreachable'));
        expect(controller.config, equals(initialConfig));
      },
    );

    test(
      'loadConfig() handles generic Map devicesData and devices with Map<dynamic, dynamic>',
      () async {
        bridge.registerMockHandler(
          'system.get_config',
          (payload) async => {
            'code': 200,
            'status': 'success',
            'data': EngineConfig.defaults().toJson(),
          },
        );

        // Intentionally return non-Map<String, dynamic> generic maps
        final Map<dynamic, dynamic> genericData = {
          'devices': <dynamic>[
            <dynamic, dynamic>{
              'id': 'generic-dac-01',
              'name': 'Generic USB DAC',
              'is_default': true,
              'sample_rates': <dynamic>[44100, 96000],
              'formats': <dynamic>['f32', 's24'],
            },
          ],
        };

        bridge.registerMockHandler(
          'audio.list_devices',
          (payload) async => {
            'code': 200,
            'status': 'success',
            'data': genericData,
          },
        );

        await controller.loadConfig();

        expect(controller.audioDevices.length, equals(1));
        expect(controller.audioDevices.first.id, equals('generic-dac-01'));
      },
    );

    test('setOutputDevice() does not clear isRestartPending', () async {
      bridge.registerMockHandler(
        'system.set_config',
        (payload) async => {
          'code': 200,
          'status': 'success',
          'data': {'restart_required': true},
        },
      );
      controller.setBufferSize(256);
      await controller.saveConfig();

      expect(controller.isRestartPending, isTrue);

      // Switching output device must NOT reset isRestartPending
      controller.setOutputDevice('usb-dac-02');
      expect(controller.isRestartPending, isTrue);
    });

    test(
      'loadConfig() does not overwrite pendingConfig when isDirty is true',
      () async {
        controller.setBufferSize(256);
        expect(controller.isDirty, isTrue);

        await controller.loadConfig();

        expect(controller.isDirty, isTrue);
        expect(controller.pendingConfig.audio.bufferSizeFrames, equals(256));
      },
    );

    test('loadConfig() does not operate after disposal', () async {
      final completer = Completer<Map<String, dynamic>>();
      bridge.registerMockHandler(
        'system.get_config',
        (payload) => completer.future,
      );

      final initialConfig = controller.config;
      controller.setBufferSize(256);
      final loadFuture = controller.loadConfig();
      controller.dispose();

      completer.complete({
        'code': 200,
        'status': 'success',
        'data': EngineConfig.defaults()
            .copyWith(
              audio: EngineConfig.defaults().audio.copyWith(
                bufferSizeFrames: 1024,
              ),
            )
            .toJson(),
      });

      await loadFuture;
      expect(
        controller.config.audio.bufferSizeFrames,
        equals(initialConfig.audio.bufferSizeFrames),
      );
    });
  });

  group('BackendSettingsTab Widget Tests', () {
    late MockLyraBridge bridge;
    late BackendSettingsController controller;

    setUp(() {
      bridge = MockLyraBridge();
      controller = BackendSettingsController(bridge: bridge, autoLoad: false);
    });

    tearDown(() {
      controller.dispose();
      bridge.dispose();
    });

    testWidgets(
      'Renders all four grouped cards cleanly in Dark and Light mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
        addTearDown(themeNotifier.dispose);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            themeNotifier: themeNotifier,
          ),
        );
        await tester.pumpAndSettle();

        // Master navigation items rendered in sidebar
        expect(find.text('Audio Hardware'), findsOneWidget);
        expect(find.text('Database Engine'), findsOneWidget);
        expect(find.text('Ingestion Pipeline'), findsOneWidget);
        expect(find.text('Storage & Maintenance'), findsOneWidget);

        // Section 1: Audio Hardware (Default)
        expect(
          find.text('Audio Hardware & Bit-Perfect Engine'),
          findsOneWidget,
        );
        expect(find.text('Output Device'), findsOneWidget);
        expect(find.text('Exclusive Mode'), findsOneWidget);
        expect(find.text('Buffer Size (Frames)'), findsOneWidget);
        expect(find.text('Volume Strategy'), findsOneWidget);
        expect(find.text('Resampler Engine'), findsOneWidget);
        expect(find.text('DSD Decoding'), findsOneWidget);

        // Section 2: Database Engine
        await tester.tap(find.text('Database Engine'));
        await tester.pumpAndSettle();
        expect(find.text('Database Engine Tuning'), findsOneWidget);
        expect(find.text('Page Cache Size'), findsOneWidget);
        expect(find.text('Memory-Mapped I/O (MMAP)'), findsOneWidget);
        expect(find.text('Busy Timeout'), findsOneWidget);
        expect(find.text('WAL Autocheckpoint'), findsOneWidget);

        // Section 3: Ingestion Pipeline
        await tester.tap(find.text('Ingestion Pipeline'));
        await tester.pumpAndSettle();
        expect(find.text('Worker Threads'), findsOneWidget);
        expect(find.text('Ingestion Mode'), findsOneWidget);

        // Section 4: Storage & Maintenance
        await tester.tap(find.text('Storage & Maintenance'));
        await tester.pumpAndSettle();
        expect(find.text('Storage & Cache Maintenance'), findsOneWidget);
        expect(find.text('Verify Integrity'), findsOneWidget);
        expect(find.text('Prune Orphans'), findsOneWidget);
        expect(find.text('Clear Waveform Cache'), findsOneWidget);

        // Switch to Light Mode and verify no errors across sections
        themeNotifier.value = ThemeMode.light;
        await tester.pumpAndSettle();

        expect(find.text('Storage & Cache Maintenance'), findsOneWidget);

        await tester.tap(find.text('Audio Hardware'));
        await tester.pumpAndSettle();
        expect(
          find.text('Audio Hardware & Bit-Perfect Engine'),
          findsOneWidget,
        );

        await tester.tap(find.text('Database Engine'));
        await tester.pumpAndSettle();
        expect(find.text('Database Engine Tuning'), findsOneWidget);
      },
    );

    testWidgets(
      'Clicking Buffer Size pill updates buffer size and displays sticky action bar with restart warning',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Initially clean, no action bar
        expect(find.text('Save Engine Settings'), findsNothing);
        expect(find.text('Discard Changes'), findsNothing);

        // Tap buffer size 256 pill
        final pill256 = find.widgetWithText(LyraButton, '256');
        expect(pill256, findsOneWidget);
        await tester.tap(pill256);
        await tester.pumpAndSettle();

        expect(controller.isDirty, isTrue);
        expect(controller.restartRequired, isTrue);
        expect(controller.pendingConfig.audio.bufferSizeFrames, equals(256));

        // Action bar is now visible
        expect(find.text('Save Engine Settings'), findsOneWidget);
        expect(find.text('Discard Changes'), findsOneWidget);
        expect(
          find.text(
            'Hardware buffer or exclusive mode adjustments require audio engine restart.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Toggling Exclusive Mode switch updates state and displays restart required alert',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byType(LyraSwitch);
        expect(switchFinder, findsOneWidget);

        // Toggle Exclusive Mode
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(controller.isDirty, isTrue);
        expect(controller.restartRequired, isTrue);
        expect(controller.pendingConfig.audio.exclusiveMode, isFalse);
        expect(find.text('Save Engine Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'Clicking Volume Strategy pills updates mode in pendingConfig',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final linearPill = find.widgetWithText(LyraButton, 'Linear');
        expect(linearPill, findsOneWidget);

        await tester.tap(linearPill);
        await tester.pumpAndSettle();

        expect(controller.isDirty, isTrue);
        expect(controller.restartRequired, isFalse);
        expect(
          controller.pendingConfig.audio.volumeMode,
          equals(AudioVolumeMode.linear),
        );
      },
    );

    testWidgets(
      'Clicking Database Cache Size and MMAP pills updates pendingConfig without restart required',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Select Database Engine section
        await tester.tap(find.text('Database Engine'));
        await tester.pumpAndSettle();

        // Tap 256 MB in Page Cache Size
        final cache256 = find.widgetWithText(LyraButton, '256 MB').first;
        await tester.tap(cache256);
        await tester.pumpAndSettle();

        expect(controller.isDirty, isTrue);
        expect(controller.restartRequired, isFalse);
        expect(
          controller.pendingConfig.database.cacheSizeKb,
          equals(256 * 1024),
        );

        // Tap Off in MMAP
        final mmapOff = find.widgetWithText(LyraButton, 'Off');
        await tester.tap(mmapOff);
        await tester.pumpAndSettle();

        expect(controller.pendingConfig.database.mmapSizeBytes, equals(0));
      },
    );

    testWidgets(
      'Auto thread checkbox toggles parallelThreads between Auto and manual count',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Select Ingestion Pipeline section
        await tester.tap(find.text('Ingestion Pipeline'));
        await tester.pumpAndSettle();

        // Initially Auto is checked (parallelThreads == 0)
        expect(find.text('Auto (16 threads)'), findsOneWidget);
        final slider = tester.widget<ShadSlider>(find.byType(ShadSlider));
        expect(slider.enabled, isFalse);

        // Uncheck Auto
        final autoCheckbox = find.byType(LyraCheckbox);
        await tester.tap(autoCheckbox);
        await tester.pumpAndSettle();

        expect(controller.isDirty, isTrue);
        expect(controller.pendingConfig.ingestion.parallelThreads, equals(16));
        expect(find.text('16 / 128 threads'), findsOneWidget);

        final updatedSlider = tester.widget<ShadSlider>(
          find.byType(ShadSlider),
        );
        expect(updatedSlider.enabled, isTrue);
      },
    );

    testWidgets(
      'Discard Changes button reverts all modifications and hides action bar',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Make modifications
        await tester.tap(find.widgetWithText(LyraButton, '64'));
        await tester.pumpAndSettle();
        expect(controller.isDirty, isTrue);

        // Tap Discard Changes
        await tester.tap(find.widgetWithText(LyraButton, 'Discard Changes'));
        await tester.pumpAndSettle();

        expect(controller.isDirty, isFalse);
        expect(controller.restartRequired, isFalse);
        expect(controller.pendingConfig.audio.bufferSizeFrames, equals(512));
        expect(find.text('Save Engine Settings'), findsNothing);
      },
    );

    testWidgets(
      'Save Engine Settings button saves config, shows success message, and commits draft',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Modify buffer size
        await tester.tap(find.widgetWithText(LyraButton, '1024'));
        await tester.pumpAndSettle();

        // Tap Save Engine Settings
        final saveBtn = find.widgetWithText(LyraButton, 'Save Engine Settings');
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Confirm secondary diff dialog
        expect(
          find.byKey(const Key('engine_config_diff_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('diff_dialog_confirm_button')).first,
        );
        await tester.pumpAndSettle();

        expect(controller.isDirty, isFalse);
        expect(controller.config.audio.bufferSizeFrames, equals(1024));
        expect(
          find.text('Engine settings saved successfully.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Maintenance action buttons invoke callbacks provided by host',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final casController = CasController(
          initialOrphanedCount: 5,
          initialOrphanedBytes: 0,
        );
        addTearDown(casController.dispose);

        bool pruneRequested = false;
        bool clearWaveformsRequested = false;
        bool verifyCompleted = false;

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            casController: casController,
            onVerifyAll: () => verifyCompleted = true,
            onRequestPrune: () => pruneRequested = true,
            onRequestClearWaveforms: () => clearWaveformsRequested = true,
          ),
        );
        await tester.pumpAndSettle();

        // Select Storage & Maintenance section
        await tester.tap(find.text('Storage & Maintenance'));
        await tester.pumpAndSettle();

        // Tap Prune Orphans
        await tester.tap(find.widgetWithText(LyraButton, 'Prune Orphans'));
        await tester.pumpAndSettle();
        expect(pruneRequested, isTrue);

        // Tap Clear Waveform Cache
        await tester.tap(
          find.widgetWithText(LyraButton, 'Clear Waveform Cache'),
        );
        await tester.pumpAndSettle();
        expect(clearWaveformsRequested, isTrue);

        // Tap Verify Integrity
        await tester.tap(find.widgetWithText(LyraButton, 'Verify Integrity'));
        await tester.pump();
        expect(find.text('Verifying Storage Integrity...'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(verifyCompleted, isTrue);
      },
    );

    testWidgets(
      'Adversarial check: Anti-clutter no-emoji policy across BackendSettingsTab',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        final emojiRegex = RegExp(
          r'[\u{1F300}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F1E0}-\u{1F1FF}]',
          unicode: true,
        );

        for (final textWidget in textWidgets) {
          final data = textWidget.data;
          if (data != null) {
            expect(
              emojiRegex.hasMatch(data),
              isFalse,
              reason: 'Found decorative emoji in UI text: "$data"',
            );
          }
        }
      },
    );

    testWidgets('Save success status text renders with tokens.success color', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildBackendSettingsTabTest(controller: controller),
      );
      await tester.pumpAndSettle();

      controller.setBufferSize(256);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(LyraButton, 'Save Engine Settings'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('diff_dialog_confirm_button')).first,
      );
      await tester.pumpAndSettle();

      final successTextFinder = find.text(
        'Engine settings saved successfully.',
      );
      expect(successTextFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(successTextFinder);
      final tokens = LyraThemeTokens.dark();
      expect(textWidget.style?.color, equals(tokens.success));

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Sticky action bar renders long status and error messages without RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        controller.setBufferSize(256);
        bridge.registerMockHandler(
          'system.set_config',
          (payload) async => {
            'success': false,
            'code': 500,
            'message':
                'Extremely long failure explanation detailing hardware buffer negotiation failure across CoreAudio device HAL nodes without truncation.',
          },
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(LyraButton, 'Save Engine Settings'),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ShadSlider has stable ValueKey to avoid gesture cancellation and destruction on drag',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // Select Ingestion Pipeline section
        await tester.tap(find.text('Ingestion Pipeline'));
        await tester.pumpAndSettle();

        final sliderFinder = find.byType(ShadSlider);
        expect(sliderFinder, findsOneWidget);

        final slider = tester.widget<ShadSlider>(sliderFinder);
        expect(slider.key, equals(const ValueKey('worker_threads_slider')));
      },
    );

    testWidgets('Card 2 subtitle and warning icon adhere to specifications', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildBackendSettingsTabTest(controller: controller),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Output device selection, exclusive mode, hardware buffer frames, volume strategy, and resampler profiles.',
        ),
        findsOneWidget,
      );

      controller.setBufferSize(256);
      await tester.pumpAndSettle();

      final warningIconFinder = find.byIcon(LucideIcons.triangleAlert);
      expect(warningIconFinder, findsOneWidget);
      final warningIcon = tester.widget<Icon>(warningIconFinder);
      final tokens = LyraThemeTokens.dark();
      expect(warningIcon.color, equals(tokens.warning));
    });

    testWidgets(
      'SingleChildScrollView eliminates magic 120.0 padding for action bar clearance',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        final padding = scrollView.padding as EdgeInsets;
        expect(padding.bottom, isNot(equals(120.0)));
      },
    );

    testWidgets(
      'Maintenance action buttons are disabled when casController is null',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            casController: null,
          ),
        );
        await tester.pumpAndSettle();

        // Select Storage & Maintenance section
        await tester.tap(find.text('Storage & Maintenance'));
        await tester.pumpAndSettle();

        final verifyBtn = tester.widget<LyraButton>(
          find.widgetWithText(LyraButton, 'Verify Integrity'),
        );
        final pruneBtn = tester.widget<LyraButton>(
          find.widgetWithText(LyraButton, 'Prune Orphans'),
        );
        final clearWaveformsBtn = tester.widget<LyraButton>(
          find.widgetWithText(LyraButton, 'Clear Waveform Cache'),
        );

        expect(verifyBtn.onPressed, isNull);
        expect(pruneBtn.onPressed, isNull);
        expect(clearWaveformsBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'Master-Detail section switching preserves uncommitted draft across sections',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // 1. Modify buffer size in Audio Hardware
        await tester.tap(find.widgetWithText(LyraButton, '256'));
        await tester.pumpAndSettle();
        expect(controller.isDirty, isTrue);
        expect(controller.pendingConfig.audio.bufferSizeFrames, equals(256));

        // Sticky action bar is visible
        expect(find.text('Save Engine Settings'), findsOneWidget);
        expect(find.text('Discard Changes'), findsOneWidget);

        // 2. Switch to Database Engine
        await tester.tap(find.text('Database Engine'));
        await tester.pumpAndSettle();

        // Modify cache size
        await tester.tap(find.widgetWithText(LyraButton, '256 MB').first);
        await tester.pumpAndSettle();
        expect(
          controller.pendingConfig.database.cacheSizeKb,
          equals(256 * 1024),
        );

        // Sticky action bar remains visible across sections
        expect(find.text('Save Engine Settings'), findsOneWidget);

        // 3. Switch back to Audio Hardware and verify modifications persisted
        await tester.tap(find.text('Audio Hardware'));
        await tester.pumpAndSettle();
        expect(controller.pendingConfig.audio.bufferSizeFrames, equals(256));

        // 4. Tap Discard Changes -> both revert to committed
        await tester.tap(find.widgetWithText(LyraButton, 'Discard Changes'));
        await tester.pumpAndSettle();

        expect(controller.isDirty, isFalse);
        expect(controller.pendingConfig.audio.bufferSizeFrames, equals(512));
        expect(controller.pendingConfig.database.cacheSizeKb, equals(131072));
        expect(find.text('Save Engine Settings'), findsNothing);
      },
    );

    testWidgets('Initial section parameter sets the initially active section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildBackendSettingsTabTest(
          controller: controller,
          initialSection: BackendSettingsSection.databaseEngine,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Database Engine Tuning'), findsOneWidget);
      expect(find.text('Audio Hardware & Bit-Perfect Engine'), findsNothing);
    });

    testWidgets('onSectionChanged callback is invoked on section navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      BackendSettingsSection? selected;
      await tester.pumpWidget(
        _buildBackendSettingsTabTest(
          controller: controller,
          onSectionChanged: (s) => selected = s,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ingestion Pipeline'));
      await tester.pumpAndSettle();

      expect(selected, equals(BackendSettingsSection.ingestionPipeline));
    });

    testWidgets(
      'Prune Orphans button is disabled when casController.orphanedCount == 0',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final casController = CasController(initialOrphanedCount: 0);
        addTearDown(casController.dispose);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            casController: casController,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Storage & Maintenance'));
        await tester.pumpAndSettle();

        final pruneBtn = tester.widget<LyraButton>(
          find.widgetWithText(LyraButton, 'Prune Orphans'),
        );
        expect(pruneBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'Restart alert banner has dismiss button that calls controller.acknowledgeRestart()',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Simulate a saved config with server-side restart_required
        bridge.registerMockHandler(
          'system.set_config',
          (payload) async => {
            'code': 200,
            'status': 'success',
            'data': {'restart_required': true},
          },
        );

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        controller.setDatabaseCacheSize(262144);
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(LyraButton, 'Save Engine Settings'),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('diff_dialog_confirm_button')).first,
        );
        await tester.pumpAndSettle();

        expect(controller.isRestartPending, isTrue);
        expect(
          find.text(
            'Hardware buffer or exclusive mode adjustments require audio engine restart.',
          ),
          findsOneWidget,
        );

        // Find dismiss button
        final dismissBtnFinder = find.byWidgetPredicate(
          (w) =>
              w is LyraButton &&
              w.key == const ValueKey('dismiss_restart_banner'),
        );
        expect(dismissBtnFinder, findsOneWidget);

        await tester.tap(dismissBtnFinder);
        await tester.pumpAndSettle();

        expect(controller.isRestartPending, isFalse);

        // Drain status timer
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Output device select always includes default alongside enumerated physical devices',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Preload controller with physical devices none of which have id 'default'
        final customController = BackendSettingsController(
          bridge: bridge,
          autoLoad: false,
          initialDevices: [
            const AudioDevice(
              id: 'dac-usb-a',
              name: 'High-Res DAC USB A',
              isDefault: false,
              minSampleRate: 44100,
              maxSampleRate: 96000,
            ),
          ],
        );
        addTearDown(customController.dispose);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: customController),
        );
        await tester.pumpAndSettle();

        final selectFinder = find.byType(LyraSelect<String>);
        expect(selectFinder, findsOneWidget);
        final select = tester.widget<LyraSelect<String>>(selectFinder);

        final itemValues = select.items.map((i) => i.value).toList();
        expect(itemValues, contains('default'));
        expect(itemValues, contains('dac-usb-a'));
      },
    );

    testWidgets(
      'Storage & Maintenance file path rows use SelectableText and include LyraCopyButton',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Storage & Maintenance'));
        await tester.pumpAndSettle();

        // Must find SelectableText
        expect(find.byType(SelectableText), findsAtLeastNWidgets(3));

        // Must find LyraCopyButton
        expect(find.byType(LyraCopyButton), findsAtLeastNWidgets(3));
      },
    );

    testWidgets(
      'Ingestion Pipeline worker threads header renders safely without overflow on compact widths < 600px',
      (tester) async {
        tester.view.physicalSize = const Size(550, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            initialSection: BackendSettingsSection.ingestionPipeline,
          ),
        );
        await tester.pumpAndSettle();

        final err = tester.takeException();
        expect(err, isNull);
        expect(find.text('Worker Threads'), findsOneWidget);
      },
    );

    testWidgets(
      'Busy Timeout numeric input updates pendingConfig on valid entry and syncs on reset',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            initialSection: BackendSettingsSection.databaseEngine,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('busy_timeout_input')), findsWidgets);
        expect(find.text('ms'), findsOneWidget);

        // Enter valid timeout
        await tester.enterText(
          find.byKey(const ValueKey('busy_timeout_input')).first,
          '15000',
        );
        await tester.pumpAndSettle();

        expect(controller.pendingConfig.database.busyTimeoutMs, equals(15000));
        expect(controller.isDirty, isTrue);

        // Discard changes
        await tester.tap(find.widgetWithText(LyraButton, 'Discard Changes'));
        await tester.pumpAndSettle();

        expect(controller.pendingConfig.database.busyTimeoutMs, equals(30000));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('busy_timeout_input')).first,
            matching: find.text('30000'),
          ),
          findsOneWidget,
        );

        // Enter out-of-range value (> 300,000)
        await tester.enterText(
          find.byKey(const ValueKey('busy_timeout_input')).first,
          '500000',
        );
        await tester.pumpAndSettle();

        expect(controller.pendingConfig.database.busyTimeoutMs, equals(30000));
      },
    );

    testWidgets(
      'WAL Autocheckpoint numeric input updates pendingConfig on valid entry and syncs on reset',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            initialSection: BackendSettingsSection.databaseEngine,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('wal_autocheckpoint_input')),
          findsWidgets,
        );
        expect(find.text('pages'), findsOneWidget);

        // Enter valid pages
        await tester.enterText(
          find.byKey(const ValueKey('wal_autocheckpoint_input')).first,
          '2500',
        );
        await tester.pumpAndSettle();

        expect(
          controller.pendingConfig.database.walAutocheckpoint,
          equals(2500),
        );
        expect(controller.isDirty, isTrue);

        // Discard changes
        await tester.tap(find.widgetWithText(LyraButton, 'Discard Changes'));
        await tester.pumpAndSettle();

        expect(
          controller.pendingConfig.database.walAutocheckpoint,
          equals(1000),
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('wal_autocheckpoint_input')).first,
            matching: find.text('1000'),
          ),
          findsOneWidget,
        );

        // Enter out-of-range value (< 10)
        await tester.enterText(
          find.byKey(const ValueKey('wal_autocheckpoint_input')).first,
          '5',
        );
        await tester.pumpAndSettle();

        expect(
          controller.pendingConfig.database.walAutocheckpoint,
          equals(1000),
        );
      },
    );

    testWidgets(
      'Clicking Save Engine Settings triggers EngineConfigDiffDialog and canceling preserves uncommitted draft',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            initialSection: BackendSettingsSection.databaseEngine,
          ),
        );
        await tester.pumpAndSettle();

        // Modify busy timeout
        await tester.enterText(
          find.byKey(const ValueKey('busy_timeout_input')).first,
          '20000',
        );
        await tester.pumpAndSettle();
        expect(controller.isDirty, isTrue);

        // Click Save Engine Settings
        await tester.tap(
          find.widgetWithText(LyraButton, 'Save Engine Settings'),
        );
        await tester.pumpAndSettle();

        // Diff dialog must appear
        expect(
          find.byKey(const Key('engine_config_diff_dialog')),
          findsOneWidget,
        );
        expect(
          find.text('Confirm Engine Configuration Changes'),
          findsOneWidget,
        );
        expect(find.text('DATABASE ENGINE • BUSY TIMEOUT'), findsOneWidget);
        expect(find.text('30000 ms'), findsOneWidget);
        expect(find.text('20000 ms'), findsOneWidget);

        // Cancel dialog
        await tester.tap(
          find.byKey(const Key('diff_dialog_cancel_button')).first,
        );
        await tester.pumpAndSettle();

        // Dialog should be dismissed, controller still dirty, config not saved
        expect(
          find.byKey(const Key('engine_config_diff_dialog')),
          findsNothing,
        );
        expect(controller.isDirty, isTrue);
        expect(controller.config.database.busyTimeoutMs, equals(30000));

        // Save again and confirm
        await tester.tap(
          find.widgetWithText(LyraButton, 'Save Engine Settings'),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('engine_config_diff_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('diff_dialog_confirm_button')).first,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('engine_config_diff_dialog')),
          findsNothing,
        );
        expect(controller.isDirty, isFalse);
        expect(controller.config.database.busyTimeoutMs, equals(20000));

        // Let status timer expire cleanly
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Displays validation errors on invalid numeric input and disables Save button',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(
            controller: controller,
            initialSection: BackendSettingsSection.databaseEngine,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Enter out of range (> 300,000) in Busy Timeout
        await tester.enterText(
          find.byKey(const ValueKey('busy_timeout_input')).first,
          '500000',
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Value must be between 0 and 300,000 ms'),
          findsOneWidget,
        );
        final saveBtn1 = tester.widget<LyraButton>(
          find.widgetWithText(LyraButton, 'Save Engine Settings'),
        );
        expect(saveBtn1.onPressed, isNull);

        // 2. Clear input to empty string ""
        await tester.enterText(
          find.byKey(const ValueKey('busy_timeout_input')).first,
          '',
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Value must be between 0 and 300,000 ms'),
          findsOneWidget,
        );
        final saveBtn2 = tester.widget<LyraButton>(
          find.widgetWithText(LyraButton, 'Save Engine Settings'),
        );
        expect(saveBtn2.onPressed, isNull);

        // 3. Enter valid timeout -> error disappears
        await tester.enterText(
          find.byKey(const ValueKey('busy_timeout_input')).first,
          '15000',
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Value must be between 0 and 300,000 ms'),
          findsNothing,
        );
        final saveBtn3 = tester.widget<LyraButton>(
          find.widgetWithText(LyraButton, 'Save Engine Settings'),
        );
        expect(saveBtn3.onPressed, isNotNull);

        // 4. Enter out of range (< 10) in WAL Autocheckpoint
        await tester.enterText(
          find.byKey(const ValueKey('wal_autocheckpoint_input')).first,
          '5',
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Value must be between 10 and 100,000 pages'),
          findsOneWidget,
        );
        final saveBtn4 = tester.widget<LyraButton>(
          find.widgetWithText(LyraButton, 'Save Engine Settings'),
        );
        expect(saveBtn4.onPressed, isNull);
      },
    );

    testWidgets(
      'Dismissing restart banner when restartRequired is true hides banner and resets on setting change',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildBackendSettingsTabTest(controller: controller),
        );
        await tester.pumpAndSettle();

        // 1. Modify buffer size to 256 -> restartRequired = true
        await tester.tap(find.widgetWithText(LyraButton, '256'));
        await tester.pumpAndSettle();

        expect(controller.restartRequired, isTrue);
        expect(
          find.text(
            'Hardware buffer or exclusive mode adjustments require audio engine restart.',
          ),
          findsOneWidget,
        );

        // 2. Click dismiss button on the banner
        final dismissBtn = find
            .byKey(const ValueKey('dismiss_restart_banner'))
            .first;
        expect(dismissBtn, findsOneWidget);
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();

        // Banner MUST be hidden now
        expect(
          find.text(
            'Hardware buffer or exclusive mode adjustments require audio engine restart.',
          ),
          findsNothing,
        );

        // 3. Change another restart-triggering setting (e.g. buffer size to 128)
        await tester.tap(find.widgetWithText(LyraButton, '128'));
        await tester.pumpAndSettle();

        // Banner should reappear
        expect(
          find.text(
            'Hardware buffer or exclusive mode adjustments require audio engine restart.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
