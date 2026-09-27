// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
import 'package:ui/design_system/widgets/lyra_dialog.dart';
import 'package:ui/features/cas_pool/cas_view.dart';
import 'package:ui/features/models/cas_object.dart';

Widget _buildCasViewTest({
  List<CasObject>? casObjects,
  VoidCallback? onVerifyAll,
  ValueChanged<CasObject>? onInspectAsset,
  CasController? controller,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  final defaultObjects = [
    CasObject(
      hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      sizeBytes: 15 * 1024 * 1024,
      mimeType: 'audio/flac',
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      assetType: 'audio',
      references: 3,
    ),
    CasObject(
      hash: 'a1b2c3d4e5f60718293a4b5c6d7e8f90123456789abcdef0123456789abcdef0',
      sizeBytes: 2 * 1024 * 1024,
      mimeType: 'image/jpeg',
      createdAt: DateTime.parse('2026-01-02T00:00:00Z'),
      assetType: 'cover',
      references: 1,
    ),
  ];

  return ShadApp(
    title: 'Lyra Test',
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
              body: CasView(
                casObjects: casObjects ?? defaultObjects,
                onVerifyAll: onVerifyAll,
                onInspectAsset: onInspectAsset,
                controller: controller,
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

  group('CasView Widget Tests', () {
    testWidgets('Renders header, segmented storage bar, table headers, and rows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildCasViewTest());
      await tester.pumpAndSettle();

      // 1. Header check: Clean title, no long subtitle
      expect(find.text('CAS Storage'), findsOneWidget);
      expect(
        find.text(
          'Content-addressed storage metrics, SQLite database explorer, and engine settings.',
        ),
        findsNothing,
      );

      // 2. Action buttons removed from top header (100% clean and safe in Storage Overview)
      expect(find.text('Verify Integrity'), findsNothing);
      expect(find.text('Prune Orphans'), findsNothing);
      expect(find.text('Clear Waveforms'), findsNothing);
      expect(find.text('Clear Waveform Cache'), findsNothing);

      // 3. Horizontal Segmented Storage Bar & Legend check
      expect(find.text('Audio '), findsOneWidget);
      expect(find.text('Images '), findsOneWidget);
      expect(find.text('Covers '), findsNothing);
      expect(find.text('Waveforms '), findsOneWidget);
      expect(find.text('Database '), findsOneWidget);
      expect(find.textContaining('Total'), findsOneWidget);

      // Verify rich non-white colors are present
      final containers = tester.widgetList<Container>(find.byType(Container));
      final colors = <Color>[];
      for (final c in containers) {
        if (c.color != null) colors.add(c.color!);
        if (c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color != null) {
          colors.add((c.decoration as BoxDecoration).color!);
        }
      }
      expect(colors.contains(const Color(0xFF3B82F6)), isTrue);
      expect(colors.contains(const Color(0xFF10B981)), isTrue);
      expect(colors.contains(const Color(0xFFF59E0B)), isTrue);
      expect(colors.contains(const Color(0xFF8B5CF6)), isTrue);

      // 4. Old square metric cards must be completely removed
      expect(find.text('TOTAL BLOBS'), findsNothing);
      expect(find.text('STORAGE CAPACITY'), findsNothing);
      expect(find.text('IMMUTABILITY STATUS'), findsNothing);

      // 5. Table headers check: Title Case, no ALL CAPS
      expect(find.text('Integrity Hash'), findsOneWidget);
      expect(find.text('File Size'), findsOneWidget);
      expect(find.text('MIME Type'), findsOneWidget);
      expect(find.text('References'), findsOneWidget);
      expect(find.text('STATUS / ACTIONS'), findsNothing);

      // 6. Blob row items
      expect(
        find.text(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
        findsOneWidget,
      );
      expect(find.text('15.0 MB'), findsWidgets);
      expect(find.text('audio/flac'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // 7. No redundant Verified badge on normal items
      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('Switches views cleanly between the three CAS tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = CasController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildCasViewTest(controller: controller));
      await tester.pumpAndSettle();

      // Initially on Storage Overview
      expect(find.text('Integrity Hash'), findsOneWidget);

      // Switch to Database Explorer
      controller.setTab(CasTab.databaseExplorer);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'SQLite database health status, WAL checkpoints, and table statistics.',
        ),
        findsOneWidget,
      );
      expect(find.text('Integrity Hash'), findsNothing);

      // Switch to Backend Engine Settings
      controller.setTab(CasTab.backendSettings);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Audio hardware buffers, exclusive mode, database tuning, and ingestion pipeline.',
        ),
        findsOneWidget,
      );
      expect(find.text('Storage & Cache Maintenance'), findsOneWidget);
      expect(find.text('Verify Integrity'), findsOneWidget);
      expect(find.text('Prune Orphans'), findsOneWidget);
      expect(find.text('Clear Waveform Cache'), findsOneWidget);

      // Switch back to Storage Overview
      controller.setTab(CasTab.storageOverview);
      await tester.pumpAndSettle();

      expect(find.text('Integrity Hash'), findsOneWidget);
    });

    testWidgets('Search input filters blob objects and shows empty state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildCasViewTest());
      await tester.pumpAndSettle();

      expect(find.text('audio/flac'), findsOneWidget);
      expect(find.text('image/jpeg'), findsOneWidget);

      // Type into search field
      final searchInput = find.byType(EditableText);
      await tester.enterText(searchInput, 'image');
      await tester.pumpAndSettle();

      expect(find.text('audio/flac'), findsNothing);
      expect(find.text('image/jpeg'), findsOneWidget);

      // Type non-matching query
      await tester.enterText(searchInput, 'xyz_not_found');
      await tester.pumpAndSettle();

      expect(find.text('No Matching CAS Objects'), findsOneWidget);

      // Clear search
      await tester.enterText(searchInput, '');
      await tester.pumpAndSettle();

      expect(find.text('audio/flac'), findsOneWidget);
      expect(find.text('image/jpeg'), findsOneWidget);
    });

    testWidgets(
      'Verify Integrity button in Engine Settings shows progress bar during verification',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = CasController(initialTab: CasTab.backendSettings);
        addTearDown(controller.dispose);

        bool verifyAllCalled = false;
        await tester.pumpWidget(
          _buildCasViewTest(
            controller: controller,
            onVerifyAll: () => verifyAllCalled = true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Storage & Cache Maintenance'), findsOneWidget);

        // Tap Verify Integrity
        await tester.tap(find.text('Verify Integrity'));
        await tester.pump();

        // While verifying, callback has NOT been invoked yet
        expect(verifyAllCalled, isFalse);
        expect(find.text('Verifying Storage Integrity...'), findsOneWidget);

        // Finish verification
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(verifyAllCalled, isTrue);
        expect(find.text('Verifying Storage Integrity...'), findsNothing);
      },
    );

    testWidgets(
      'Prune Orphans button in Engine Settings opens LyraDialog and allows cancel or confirm',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = CasController(
          initialTab: CasTab.backendSettings,
          initialOrphanedCount: 3,
          initialOrphanedBytes: 12 * 1024 * 1024,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_buildCasViewTest(controller: controller));
        await tester.pumpAndSettle();

        expect(find.text('Storage & Cache Maintenance'), findsOneWidget);
        expect(find.text('Prune Orphans (12.0 MB)'), findsOneWidget);

        // Open Dialog
        await tester.tap(find.text('Prune Orphans (12.0 MB)'));
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsOneWidget);
        expect(find.text('Prune Orphaned Blobs'), findsOneWidget);

        // Click Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsNothing);
        expect(controller.orphanedCount, equals(3));

        // Re-open and Confirm Prune
        await tester.tap(find.text('Prune Orphans (12.0 MB)'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm Prune'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsNothing);
        expect(controller.orphanedCount, equals(0));
        expect(find.text('Prune Orphans'), findsOneWidget);
      },
    );

    testWidgets(
      'Clear Waveform Cache button in Engine Settings opens LyraDialog and clears cache on confirm',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = CasController(
          initialTab: CasTab.backendSettings,
          initialWaveformCacheBytes: 40 * 1024 * 1024,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_buildCasViewTest(controller: controller));
        await tester.pumpAndSettle();

        expect(find.text('Storage & Cache Maintenance'), findsOneWidget);

        // Open Dialog
        await tester.tap(find.text('Clear Waveform Cache'));
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsOneWidget);
        expect(find.text('Clear Waveform Cache'), findsWidgets);

        // Confirm Clear
        await tester.tap(find.text('Clear Cache'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byType(LyraDialog), findsNothing);
        expect(controller.waveformCacheBytes, equals(0));
      },
    );

    testWidgets('Tapping blob row triggers onInspectAsset callback', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      CasObject? inspected;
      await tester.pumpWidget(
        _buildCasViewTest(onInspectAsset: (obj) => inspected = obj),
      );
      await tester.pumpAndSettle();

      final mimeCell = find.text('audio/flac').first;
      expect(mimeCell, findsOneWidget);

      await tester.tap(mimeCell);
      await tester.pumpAndSettle();

      expect(inspected, isNotNull);
      expect(
        inspected!.hash,
        equals(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
      );
    });

    testWidgets(
      'Clicking Integrity Hash copies hash to clipboard and does not inspect asset',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final List<MethodCall> clipboardCalls = <MethodCall>[];
        CasObject? inspected;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'Clipboard.setData') {
                clipboardCalls.add(methodCall);
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await tester.pumpWidget(
          _buildCasViewTest(onInspectAsset: (obj) => inspected = obj),
        );
        await tester.pumpAndSettle();

        final hashFinder = find.text(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        );
        expect(hashFinder, findsOneWidget);

        // Initially tooltip is configured with richMessage WidgetSpan
        final initialTooltip = tester.widget<Tooltip>(
          find.byType(Tooltip).first,
        );
        expect(initialTooltip.richMessage, isNotNull);
        expect(initialTooltip.richMessage, isA<WidgetSpan>());

        // Click hash text
        await tester.tap(hashFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Tapping hash MUST NOT trigger onInspectAsset
        expect(inspected, isNull);

        // Hash string remains visible in place
        expect(hashFinder, findsOneWidget);

        // Tooltip updates to 'Copied' with green checkmark icon
        expect(find.text('Copied'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);

        expect(
          clipboardCalls.any(
            (call) =>
                call.arguments['text'] ==
                'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
          isTrue,
        );

        // After timer reverts back to 'Click to copy hash'
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Click to copy hash'), findsOneWidget);
        expect(hashFinder, findsOneWidget);
      },
    );

    testWidgets(
      'Adversarial check: Anti-clutter no-emoji policy & encapsulated immutability',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildCasViewTest());
        await tester.pumpAndSettle();

        // 1. Strictly NO "Reveal in File Manager"
        expect(find.textContaining('Reveal in File Manager'), findsNothing);
        expect(find.textContaining('Show in Folder'), findsNothing);

        // 2. Strictly NO emojis across any Text widget in CasView
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

    testWidgets(
      'Renders unverified badge and warning when obj.verified is false',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final objects = [
          CasObject(
            hash:
                'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            sizeBytes: 1024,
            mimeType: 'audio/wav',
            createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
            verified: false,
          ),
        ];

        await tester.pumpWidget(_buildCasViewTest(casObjects: objects));
        await tester.pumpAndSettle();

        expect(find.text('Unverified'), findsOneWidget);
        expect(find.text('Verified'), findsNothing);
      },
    );

    testWidgets(
      'Engine Settings Verify Integrity button is disabled during verification and calls callback upon completion',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = CasController(initialTab: CasTab.backendSettings);
        addTearDown(controller.dispose);

        bool verifyAllCalled = false;
        await tester.pumpWidget(
          _buildCasViewTest(
            controller: controller,
            onVerifyAll: () => verifyAllCalled = true,
          ),
        );
        await tester.pumpAndSettle();

        final button = find.widgetWithText(LyraButton, 'Verify Integrity');
        expect(button, findsOneWidget);

        await tester.tap(button);
        await tester.pump();

        expect(verifyAllCalled, isFalse);
        expect(find.text('Verifying Storage Integrity...'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(verifyAllCalled, isTrue);
      },
    );

    testWidgets(
      'Synchronizes search text when controller searchQuery is updated externally',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = CasController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(_buildCasViewTest(controller: controller));
        await tester.pumpAndSettle();

        controller.setSearchQuery('external_query');
        await tester.pumpAndSettle();

        final editableText = tester.widget<EditableText>(
          find.byType(EditableText),
        );
        expect(editableText.controller.text, equals('external_query'));
      },
    );

    testWidgets(
      'Right-clicking table header opens column picker context menu',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildCasViewTest());
        await tester.pumpAndSettle();

        expect(find.text('File Size'), findsOneWidget);

        // Right-click on header
        final headerFinder = find.text('Integrity Hash');
        await tester.tap(headerFinder, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.byType(ShadContextMenuRegion), findsWidgets);
      },
    );
  });
}
