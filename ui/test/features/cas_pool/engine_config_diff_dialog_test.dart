// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/audio/models/audio_device.dart';
import 'package:ui/features/cas_pool/models/engine_config.dart';
import 'package:ui/features/cas_pool/widgets/engine_config_diff_dialog.dart';

Widget _buildDialogHarness({
  required List<EngineConfigDiffItem> diffs,
  bool restartRequired = false,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
}) {
  const factory = ShadcnFactory();
  final tokens = LyraThemeTokens.dark();
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  return ShadApp(
    title: 'Engine Config Diff Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      child: LyraDesignSystemScope(
        factory: factory,
        tokens: tokens,
        themeModeNotifier: themeModeNotifier,
        child: Scaffold(
          body: EngineConfigDiffDialog(
            diffs: diffs,
            restartRequired: restartRequired,
            onConfirm: onConfirm ?? () {},
            onCancel: onCancel ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeEngineConfigDiff', () {
    test('returns empty list when current and pending are identical', () {
      final config = EngineConfig.defaults();
      final diffs = computeEngineConfigDiff(config, config);
      expect(diffs, isEmpty);
    });

    test('detects Database Engine changes properly', () {
      final current = EngineConfig.defaults();
      final pending = current.copyWith(
        database: current.database.copyWith(
          cacheSizeKb: 262144, // 256 MB
          mmapSizeBytes: 0, // Off
          busyTimeoutMs: 15000,
          walAutocheckpoint: 500,
        ),
      );

      final diffs = computeEngineConfigDiff(current, pending);
      expect(diffs.length, equals(4));

      final cacheDiff = diffs.firstWhere((d) => d.label == 'Cache Size');
      expect(cacheDiff.section, equals('Database Engine'));
      expect(cacheDiff.oldValue, equals('128 MB'));
      expect(cacheDiff.newValue, equals('256 MB'));

      final mmapDiff = diffs.firstWhere((d) => d.label == 'MMAP Size');
      expect(mmapDiff.section, equals('Database Engine'));
      expect(mmapDiff.oldValue, equals('512 MB'));
      expect(mmapDiff.newValue, equals('Off'));

      final timeoutDiff = diffs.firstWhere((d) => d.label == 'Busy Timeout');
      expect(timeoutDiff.section, equals('Database Engine'));
      expect(timeoutDiff.oldValue, equals('30000 ms'));
      expect(timeoutDiff.newValue, equals('15000 ms'));

      final walDiff = diffs.firstWhere((d) => d.label == 'WAL Autocheckpoint');
      expect(walDiff.section, equals('Database Engine'));
      expect(walDiff.oldValue, equals('1000 pages'));
      expect(walDiff.newValue, equals('500 pages'));
    });

    test('detects Audio Hardware changes properly with device names', () {
      final current = EngineConfig.defaults();
      final devices = [
        const AudioDevice(id: 'usb-dac-01', name: 'Topping DX7 Pro+'),
      ];

      final pending = current.copyWith(
        audio: current.audio.copyWith(
          outputDeviceId: 'usb-dac-01',
          exclusiveMode: false,
          bufferSizeFrames: 256,
          volumeMode: AudioVolumeMode.linear,
          resamplerQuality: ResamplerQuality.native,
          dsdMode: DsdMode.pcmTranscode,
        ),
      );

      final diffs = computeEngineConfigDiff(current, pending, devices: devices);
      expect(diffs.length, equals(6));

      final deviceDiff = diffs.firstWhere((d) => d.label == 'Output Device');
      expect(deviceDiff.section, equals('Audio Hardware'));
      expect(deviceDiff.oldValue, equals('Default System Audio'));
      expect(deviceDiff.newValue, equals('Topping DX7 Pro+'));

      final exclDiff = diffs.firstWhere((d) => d.label == 'Exclusive Mode');
      expect(exclDiff.oldValue, equals('Enabled'));
      expect(exclDiff.newValue, equals('Disabled'));

      final bufDiff = diffs.firstWhere((d) => d.label == 'Buffer Size');
      expect(bufDiff.oldValue, equals('512 frames'));
      expect(bufDiff.newValue, equals('256 frames'));

      final volDiff = diffs.firstWhere((d) => d.label == 'Volume Strategy');
      expect(volDiff.oldValue, equals('Bit-Perfect Lock 0dB'));
      expect(volDiff.newValue, equals('Linear'));

      final resampDiff = diffs.firstWhere(
        (d) => d.label == 'Resampler Quality',
      );
      expect(resampDiff.oldValue, equals('SOXR High Quality'));
      expect(resampDiff.newValue, equals('Bit-Perfect Native'));

      final dsdDiff = diffs.firstWhere((d) => d.label == 'DSD Mode');
      expect(dsdDiff.oldValue, equals('DoP (DSD over PCM)'));
      expect(dsdDiff.newValue, equals('PCM Transcode'));
    });

    test('detects Ingestion Pipeline changes properly', () {
      final current = EngineConfig.defaults();
      final pending = current.copyWith(
        ingestion: current.ingestion.copyWith(
          parallelThreads: 8,
          mode: IngestionMode.fast,
        ),
      );

      final diffs = computeEngineConfigDiff(current, pending);
      expect(diffs.length, equals(2));

      final threadsDiff = diffs.firstWhere((d) => d.label == 'Worker Threads');
      expect(threadsDiff.section, equals('Ingestion Pipeline'));
      expect(threadsDiff.oldValue, equals('Auto (16 threads)'));
      expect(threadsDiff.newValue, equals('8 threads'));

      final modeDiff = diffs.firstWhere((d) => d.label == 'Ingestion Mode');
      expect(modeDiff.section, equals('Ingestion Pipeline'));
      expect(modeDiff.oldValue, equals('Full Analysis (Waveforms)'));
      expect(modeDiff.newValue, equals('Fast Ingest'));
    });

    test('detects Storage Engine changes properly', () {
      final current = EngineConfig.defaults(storageRoot: '/var/lib/lyra');
      final pending = current.copyWith(
        storage: current.storage.copyWith(
          storageRoot: '/mnt/storage/lyra',
          databasePath: '/mnt/storage/lyra/lyra.db',
          casObjectsDir: '/mnt/storage/lyra/objects',
        ),
      );

      final diffs = computeEngineConfigDiff(current, pending);
      expect(diffs.length, equals(3));

      final rootDiff = diffs.firstWhere((d) => d.label == 'Storage Root');
      expect(rootDiff.section, equals('Storage Engine'));
      expect(rootDiff.oldValue, equals('/var/lib/lyra'));
      expect(rootDiff.newValue, equals('/mnt/storage/lyra'));

      final dbDiff = diffs.firstWhere((d) => d.label == 'Database Path');
      expect(dbDiff.section, equals('Storage Engine'));
      expect(dbDiff.oldValue, equals('/var/lib/lyra/lyra.db'));
      expect(dbDiff.newValue, equals('/mnt/storage/lyra/lyra.db'));

      final casDiff = diffs.firstWhere((d) => d.label == 'CAS Objects Dir');
      expect(casDiff.section, equals('Storage Engine'));
      expect(casDiff.oldValue, equals('/var/lib/lyra/objects'));
      expect(casDiff.newValue, equals('/mnt/storage/lyra/objects'));
    });

    test('formats singular 1 thread properly in Worker Threads diff', () {
      final current = EngineConfig.defaults().copyWith(
        ingestion: EngineConfig.defaults().ingestion.copyWith(
          parallelThreads: 4,
        ),
      );
      final pending = current.copyWith(
        ingestion: current.ingestion.copyWith(parallelThreads: 1),
      );

      final diffs = computeEngineConfigDiff(current, pending);
      final threadsDiff = diffs.firstWhere((d) => d.label == 'Worker Threads');
      expect(threadsDiff.newValue, equals('1 thread'));
      expect(threadsDiff.oldValue, equals('4 threads'));
    });
  });

  group('EngineConfigDiffDialog Widget Tests', () {
    testWidgets('renders empty diff message when no changes are present', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDialogHarness(diffs: []));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Engine Configuration Changes'), findsOneWidget);
      expect(find.text('No settings have been modified.'), findsOneWidget);
      expect(find.text('No changes detected.'), findsOneWidget);
      expect(find.byKey(const Key('diff_dialog_cancel_button')), findsWidgets);
      expect(find.byKey(const Key('diff_dialog_confirm_button')), findsWidgets);
    });

    testWidgets('renders diff items with monospaced style and labels', (
      tester,
    ) async {
      final diffs = [
        const EngineConfigDiffItem(
          section: 'Database Engine',
          label: 'Busy Timeout',
          oldValue: '30000 ms',
          newValue: '10000 ms',
        ),
      ];

      await tester.pumpWidget(
        _buildDialogHarness(diffs: diffs, restartRequired: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('DATABASE ENGINE • BUSY TIMEOUT'), findsOneWidget);
      expect(find.text('30000 ms'), findsOneWidget);
      expect(find.text('10000 ms'), findsOneWidget);
      expect(
        find.text(
          'Review the 1 modified setting before applying changes to the engine.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Note: Audio engine will restart to apply hardware buffer or exclusive mode changes.',
        ),
        findsNothing,
      );
    });

    testWidgets('shows restart warning banner when restartRequired is true', (
      tester,
    ) async {
      final diffs = [
        const EngineConfigDiffItem(
          section: 'Audio Hardware',
          label: 'Buffer Size',
          oldValue: '512 frames',
          newValue: '256 frames',
        ),
      ];

      await tester.pumpWidget(
        _buildDialogHarness(diffs: diffs, restartRequired: true),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Note: Audio engine will restart to apply hardware buffer or exclusive mode changes.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('triggers onCancel when Cancel button is tapped', (
      tester,
    ) async {
      bool canceled = false;
      await tester.pumpWidget(
        _buildDialogHarness(diffs: [], onCancel: () => canceled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('diff_dialog_cancel_button')).first,
      );
      await tester.pumpAndSettle();

      expect(canceled, isTrue);
    });

    testWidgets('triggers onConfirm when Confirm & Save button is tapped', (
      tester,
    ) async {
      bool confirmed = false;
      await tester.pumpWidget(
        _buildDialogHarness(diffs: [], onConfirm: () => confirmed = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('diff_dialog_confirm_button')).first,
      );
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets(
      'renders on compact screen (500x480) without RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(500, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final diffs = List.generate(
          10,
          (i) => EngineConfigDiffItem(
            section: 'Section $i',
            label: 'Setting $i with longer descriptive label',
            oldValue: 'Old Value $i',
            newValue: 'New Value $i',
          ),
        );

        await tester.pumpWidget(
          _buildDialogHarness(diffs: diffs, restartRequired: true),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('engine_config_diff_dialog')),
          findsOneWidget,
        );
      },
    );
  });
}
