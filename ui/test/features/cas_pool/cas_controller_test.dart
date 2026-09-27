// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/cas_pool/controllers/cas_controller.dart';
import 'package:ui/features/models/cas_object.dart';

void main() {
  group('CasController Unit Tests', () {
    late List<CasObject> testObjects;

    setUp(() {
      testObjects = [
        CasObject(
          hash:
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          sizeBytes: 10 * 1024 * 1024, // 10 MB
          mimeType: 'audio/flac',
          createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
          assetType: 'audio',
        ),
        CasObject(
          hash:
              'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
          sizeBytes: 2 * 1024 * 1024, // 2 MB
          mimeType: 'image/jpeg',
          createdAt: DateTime.parse('2026-01-02T00:00:00Z'),
          assetType: 'cover',
        ),
        CasObject(
          hash:
              '4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce',
          sizeBytes: 500 * 1024, // 500 KB
          mimeType: 'audio/mp3',
          createdAt: DateTime.parse('2026-01-03T00:00:00Z'),
          assetType: 'audio',
        ),
      ];
    });

    test(
      'Initializes with default values and calculates metrics correctly',
      () {
        final controller = CasController(initialObjects: testObjects);
        addTearDown(controller.dispose);

        expect(controller.activeTab, equals(CasTab.storageOverview));
        expect(controller.totalBlobs, equals(3));
        expect(
          controller.totalBytes,
          equals(10 * 1024 * 1024 + 2 * 1024 * 1024 + 500 * 1024),
        );
        expect(controller.audioBytes, equals(10 * 1024 * 1024 + 500 * 1024));
        expect(controller.coverBytes, equals(2 * 1024 * 1024));
        expect(controller.formattedCoverBytes, equals('2.0 MB'));
        expect(controller.formattedImageBytes, equals('2.0 MB'));
        expect(controller.immutabilityStatus, equals('100% Bit-Perfect'));
        expect(controller.searchQuery, isEmpty);
        expect(controller.filteredCasObjects.length, equals(3));
        expect(controller.isVerifying, isFalse);
        expect(controller.verificationProgress, equals(0.0));
        expect(controller.isPruning, isFalse);
        expect(controller.isClearingWaveforms, isFalse);
      },
    );

    test('Switching tabs updates activeTab and notifies listeners', () {
      final controller = CasController();
      addTearDown(controller.dispose);

      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      controller.setTab(CasTab.databaseExplorer);
      expect(controller.activeTab, equals(CasTab.databaseExplorer));
      expect(notificationCount, equals(1));

      // Re-selecting current tab should not notify
      controller.setTab(CasTab.databaseExplorer);
      expect(notificationCount, equals(1));

      controller.setTab(CasTab.backendSettings);
      expect(controller.activeTab, equals(CasTab.backendSettings));
      expect(notificationCount, equals(2));
    });

    test(
      'Search query filters CAS objects by hash substring (case-insensitive)',
      () {
        final controller = CasController(initialObjects: testObjects);
        addTearDown(controller.dispose);

        // Search by partial hash
        controller.setSearchQuery('e3b0c4');
        expect(controller.filteredCasObjects.length, equals(1));
        expect(controller.filteredCasObjects.first.hash, startsWith('e3b0c4'));

        // Case-insensitive uppercase search
        controller.setSearchQuery('E3B0C4');
        expect(controller.filteredCasObjects.length, equals(1));

        // Empty query restores full list
        controller.setSearchQuery('');
        expect(controller.filteredCasObjects.length, equals(3));
      },
    );

    test('Search query filters CAS objects by MIME type', () {
      final controller = CasController(initialObjects: testObjects);
      addTearDown(controller.dispose);

      controller.setSearchQuery('image');
      expect(controller.filteredCasObjects.length, equals(1));
      expect(
        controller.filteredCasObjects.first.mimeType,
        equals('image/jpeg'),
      );

      controller.setSearchQuery('audio');
      expect(controller.filteredCasObjects.length, equals(2));

      controller.setSearchQuery('non-existent');
      expect(controller.filteredCasObjects, isEmpty);
    });

    test(
      'verifyIntegrity runs through progress steps and updates state',
      () async {
        final controller = CasController(initialObjects: testObjects);
        addTearDown(controller.dispose);

        final progressStates = <double>[];
        controller.addListener(() {
          progressStates.add(controller.verificationProgress);
        });

        final future = controller.verifyIntegrity(
          stepDuration: const Duration(milliseconds: 2),
        );
        expect(controller.isVerifying, isTrue);

        await future;

        expect(controller.isVerifying, isFalse);
        expect(controller.verificationProgress, equals(1.0));
        expect(progressStates, isNotEmpty);
        expect(progressStates.last, equals(1.0));
      },
    );

    test(
      'Orphan pruning handles dryRun and actual cleanup correctly',
      () async {
        final controller = CasController(
          initialObjects: testObjects,
          initialOrphanedCount: 5,
          initialOrphanedBytes: 15 * 1024 * 1024,
        );
        addTearDown(controller.dispose);

        // Dry run should report metrics without mutating state
        final dryRunResult = await controller.pruneOrphans(dryRun: true);
        expect(dryRunResult['orphanedCount'], equals(5));
        expect(dryRunResult['orphanedBytes'], equals(15 * 1024 * 1024));
        expect(controller.orphanedCount, equals(5));
        expect(controller.orphanedBytes, equals(15 * 1024 * 1024));

        // Actual pruning resets count and bytes to 0
        final actualResult = await controller.pruneOrphans(dryRun: false);
        expect(actualResult['orphanedCount'], equals(5));
        expect(actualResult['orphanedBytes'], equals(15 * 1024 * 1024));
        expect(controller.orphanedCount, equals(0));
        expect(controller.orphanedBytes, equals(0));
        expect(controller.isPruning, isFalse);
      },
    );

    test('clearWaveforms resets waveform cache bytes to 0', () async {
      final controller = CasController(
        initialObjects: testObjects,
        initialWaveformCacheBytes: 50 * 1024 * 1024,
      );
      addTearDown(controller.dispose);

      expect(controller.waveformCacheBytes, equals(50 * 1024 * 1024));

      await controller.clearWaveforms();

      expect(controller.waveformCacheBytes, equals(0));
      expect(controller.formattedWaveformCacheBytes, equals('0 B'));
      expect(controller.isClearingWaveforms, isFalse);
    });

    test('Byte formatting utility handles various sizes properly', () {
      expect(CasController.formatBytes(512), equals('512 B'));
      expect(CasController.formatBytes(2048), equals('2.0 KB'));
      expect(CasController.formatBytes(15 * 1024 * 1024), equals('15.0 MB'));
      expect(
        CasController.formatBytes(2 * 1024 * 1024 * 1024),
        equals('2.00 GB'),
      );
    });

    test('Disposed controller guards against further notifications', () {
      final controller = CasController();
      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Should not throw
      controller.setTab(CasTab.databaseExplorer);
      controller.setSearchQuery('test');
    });

    test('pruneOrphans guards against concurrent invocations', () async {
      final controller = CasController(
        initialObjects: testObjects,
        initialOrphanedCount: 5,
        initialOrphanedBytes: 15 * 1024 * 1024,
      );
      addTearDown(controller.dispose);

      // Launch two concurrent pruneOrphans calls
      final future1 = controller.pruneOrphans();
      expect(controller.isPruning, isTrue);

      final future2 = controller.pruneOrphans();

      // Second invocation should immediately return 0 without doing duplicate work
      final result2 = await future2;
      expect(result2['orphanedCount'], equals(0));
      expect(result2['orphanedBytes'], equals(0));

      final result1 = await future1;
      expect(result1['orphanedCount'], equals(5));
      expect(result1['orphanedBytes'], equals(15 * 1024 * 1024));
      expect(controller.isPruning, isFalse);
    });

    test('immutabilityStatus reflects empty and unverified states', () {
      final emptyController = CasController();
      addTearDown(emptyController.dispose);
      expect(emptyController.immutabilityStatus, equals('No Blobs'));

      final unverifiedObject = CasObject(
        hash:
            'b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2',
        sizeBytes: 1024,
        mimeType: 'audio/wav',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        assetType: 'audio',
        verified: false,
      );

      final unverifiedController = CasController(
        initialObjects: [testObjects.first, unverifiedObject],
      );
      addTearDown(unverifiedController.dispose);
      expect(
        unverifiedController.immutabilityStatus,
        equals('Integrity Warning'),
      );

      final verifiedController = CasController(initialObjects: testObjects);
      addTearDown(verifiedController.dispose);
      expect(verifiedController.immutabilityStatus, equals('100% Bit-Perfect'));
    });

    test('databaseBytes and totalPoolBytes calculate and format correctly', () {
      final controller = CasController(
        initialObjects: testObjects,
        initialDatabaseBytes: 40 * 1024 * 1024,
        initialWaveformCacheBytes: 20 * 1024 * 1024,
      );
      addTearDown(controller.dispose);

      expect(controller.databaseBytes, equals(40 * 1024 * 1024));
      expect(controller.formattedDatabaseBytes, equals('40.0 MB'));
      expect(
        controller.totalPoolBytes,
        equals(controller.totalBytes + 20 * 1024 * 1024 + 40 * 1024 * 1024),
      );
      expect(controller.formattedTotalPoolBytes, isNotEmpty);

      controller.setDatabaseBytes(10 * 1024 * 1024);
      expect(controller.databaseBytes, equals(10 * 1024 * 1024));
      expect(controller.formattedDatabaseBytes, equals('10.0 MB'));
    });
  });
}
