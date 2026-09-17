// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:ui/platform/linux_storage_io.dart';

void main() {
  group('Linux Storage & Migration Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lyra_storage_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'migrates legacy ui/shared_preferences.json to lyra/ when target does not exist',
      () async {
        final legacyDir = Directory(p.join(tempDir.path, 'ui'));
        legacyDir.createSync(recursive: true);
        final legacyFile = File(
          p.join(legacyDir.path, 'shared_preferences.json'),
        );
        final testData = {'flutter.theme': 'dark', 'flutter.volume': 0.75};
        legacyFile.writeAsStringSync(jsonEncode(testData));

        await migrateLinuxPreferences(dataHomeDir: tempDir);

        final targetFile = File(
          p.join(tempDir.path, 'lyra', 'shared_preferences.json'),
        );
        expect(targetFile.existsSync(), isTrue);
        expect(jsonDecode(targetFile.readAsStringSync()), equals(testData));

        // Legacy file should be removed
        expect(legacyFile.existsSync(), isFalse);
        // Since legacy dir was empty, it should be removed
        expect(legacyDir.existsSync(), isFalse);
      },
    );

    test(
      'retains legacy ui directory if it contains non-empty other files',
      () async {
        final legacyDir = Directory(p.join(tempDir.path, 'ui'));
        legacyDir.createSync(recursive: true);
        final legacyFile = File(
          p.join(legacyDir.path, 'shared_preferences.json'),
        );
        legacyFile.writeAsStringSync('{"flutter.test": true}');

        final otherFile = File(p.join(legacyDir.path, 'other_data.txt'));
        otherFile.writeAsStringSync('keep me');

        await migrateLinuxPreferences(dataHomeDir: tempDir);

        final targetFile = File(
          p.join(tempDir.path, 'lyra', 'shared_preferences.json'),
        );
        expect(targetFile.existsSync(), isTrue);
        expect(legacyFile.existsSync(), isFalse);

        // Other file still exists, so legacyDir is preserved
        expect(legacyDir.existsSync(), isTrue);
        expect(otherFile.existsSync(), isTrue);
      },
    );

    test('does not overwrite existing lyra/shared_preferences.json', () async {
      final legacyDir = Directory(p.join(tempDir.path, 'ui'));
      legacyDir.createSync(recursive: true);
      final legacyFile = File(
        p.join(legacyDir.path, 'shared_preferences.json'),
      );
      legacyFile.writeAsStringSync('{"flutter.source": "legacy"}');

      final targetDir = Directory(p.join(tempDir.path, 'lyra'));
      targetDir.createSync(recursive: true);
      final targetFile = File(
        p.join(targetDir.path, 'shared_preferences.json'),
      );
      targetFile.writeAsStringSync('{"flutter.source": "current"}');

      await migrateLinuxPreferences(dataHomeDir: tempDir);

      // Target should retain current content
      expect(
        jsonDecode(targetFile.readAsStringSync()),
        equals({'flutter.source': 'current'}),
      );
      // Legacy file remains untouched
      expect(legacyFile.existsSync(), isTrue);
    });

    test(
      'atomic migration overwrites 0-byte incomplete target files and leaves clean state',
      () async {
        final legacyDir = Directory(p.join(tempDir.path, 'ui'));
        legacyDir.createSync(recursive: true);
        final legacyFile = File(
          p.join(legacyDir.path, 'shared_preferences.json'),
        );
        final testData = {'flutter.theme': 'system', 'flutter.volume': 0.5};
        legacyFile.writeAsStringSync(jsonEncode(testData));

        final targetDir = Directory(p.join(tempDir.path, 'lyra'));
        targetDir.createSync(recursive: true);
        final targetFile = File(
          p.join(targetDir.path, 'shared_preferences.json'),
        );
        // Simulate a corrupted/aborted 0-byte file from previous failed run
        targetFile.writeAsStringSync('');
        expect(targetFile.existsSync(), isTrue);
        expect(targetFile.lengthSync(), 0);

        // Simulate an orphaned tmp file from a crashed write
        final staleTmpFile = File(
          p.join(targetDir.path, 'shared_preferences.json.tmp'),
        );
        staleTmpFile.writeAsStringSync('stale partial write');
        expect(staleTmpFile.existsSync(), isTrue);

        await migrateLinuxPreferences(dataHomeDir: tempDir);

        // Target file should now have the full recovered data from legacy
        expect(targetFile.existsSync(), isTrue);
        expect(targetFile.lengthSync(), greaterThan(0));
        expect(jsonDecode(targetFile.readAsStringSync()), equals(testData));

        // Legacy file and dir should be cleaned up
        expect(legacyFile.existsSync(), isFalse);
        expect(legacyDir.existsSync(), isFalse);

        // Stale tmp file should have been overwritten and cleaned up
        expect(staleTmpFile.existsSync(), isFalse);
      },
    );

    test('handles absence of legacy ui directory gracefully', () async {
      await expectLater(
        migrateLinuxPreferences(dataHomeDir: tempDir),
        completes,
      );
      final targetFile = File(
        p.join(tempDir.path, 'lyra', 'shared_preferences.json'),
      );
      expect(targetFile.existsSync(), isFalse);
    });

    test(
      'PathProviderLinux.private with applicationId "lyra" resolves path with lyra',
      () async {
        final provider = PathProviderLinux.private(applicationId: 'lyra');
        final path = await provider.getApplicationSupportPath();
        expect(path, isNotNull);
        expect(p.basename(path!), equals('lyra'));
      },
    );

    test('configureLinuxSharedPreferences updates store pathProviders', () {
      final linuxProvider = PathProviderLinux.private(applicationId: 'lyra');
      final storeLinux = SharedPreferencesLinux();
      final asyncStoreLinux = SharedPreferencesAsyncLinux();

      SharedPreferencesStorePlatform.instance = storeLinux;
      SharedPreferencesAsyncPlatform.instance = asyncStoreLinux;

      configureLinuxSharedPreferences(linuxProvider);

      expect(storeLinux.pathProvider, equals(linuxProvider));
      expect(asyncStoreLinux.pathProvider, equals(linuxProvider));
    });
  });
}
