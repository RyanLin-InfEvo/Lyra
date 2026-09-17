// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:xdg_directories/xdg_directories.dart' as xdg;

export 'package:path_provider_linux/path_provider_linux.dart'
    show PathProviderLinux;
export 'package:path_provider_platform_interface/path_provider_platform_interface.dart'
    show PathProviderPlatform;

/// Synchronizes Linux SharedPreferences plugins with the configured PathProvider instance.
void configureLinuxSharedPreferences(PathProviderPlatform provider) {
  if (provider is PathProviderLinux) {
    final store = SharedPreferencesStorePlatform.instance;
    if (store is SharedPreferencesLinux) {
      // ignore: invalid_use_of_visible_for_testing_member
      store.pathProvider = provider;
    }
    final asyncStore = SharedPreferencesAsyncPlatform.instance;
    if (asyncStore is SharedPreferencesAsyncLinux) {
      // ignore: invalid_use_of_visible_for_testing_member
      asyncStore.pathProvider = provider;
    }
  }
}

/// Migrates legacy preferences from ~/.local/share/ui/shared_preferences.json
/// to ~/.local/share/lyra/shared_preferences.json.
///
/// If [legacyFile] exists and [targetFile] either does not exist or is 0 bytes,
/// atomically copies the file via temporary file to the target path, deletes the legacy file,
/// and removes the legacy directory if it is empty.
Future<void> migrateLinuxPreferences({Directory? dataHomeDir}) async {
  try {
    final baseDir = dataHomeDir ?? xdg.dataHome;
    final legacyDir = Directory(p.join(baseDir.path, 'ui'));
    final legacyFile = File(
      p.join(baseDir.path, 'ui', 'shared_preferences.json'),
    );
    final targetDir = Directory(p.join(baseDir.path, 'lyra'));
    final targetFile = File(
      p.join(baseDir.path, 'lyra', 'shared_preferences.json'),
    );

    if (legacyFile.existsSync()) {
      final targetNeedsMigration =
          !targetFile.existsSync() || targetFile.lengthSync() == 0;
      if (targetNeedsMigration) {
        if (!targetDir.existsSync()) {
          targetDir.createSync(recursive: true);
        }
        final tmpFile = File(
          p.join(targetDir.path, 'shared_preferences.json.tmp'),
        );
        if (tmpFile.existsSync()) {
          tmpFile.deleteSync();
        }
        legacyFile.copySync(tmpFile.path);
        tmpFile.renameSync(targetFile.path); // Atomic POSIX rename
        legacyFile.deleteSync();
        debugPrint(
          '[Lyra] Migrated shared_preferences.json atomically from legacy "ui" to "lyra".',
        );
      }

      if (legacyDir.existsSync()) {
        final remaining = legacyDir.listSync();
        if (remaining.isEmpty) {
          legacyDir.deleteSync();
          debugPrint(
            '[Lyra] Removed empty legacy directory: ${legacyDir.path}',
          );
        }
      }
    }
  } on FileSystemException catch (e, stack) {
    debugPrint(
      '[Lyra] FileSystemException during preferences migration: $e\n$stack',
    );
  } catch (e, stack) {
    debugPrint(
      '[Lyra] Failed to migrate preferences from legacy path: $e\n$stack',
    );
  }
}
