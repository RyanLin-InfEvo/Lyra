// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

export 'package:path_provider_platform_interface/path_provider_platform_interface.dart'
    show PathProviderPlatform;

/// Stub implementation of PathProviderLinux for non-IO platforms (e.g. Web).
class PathProviderLinux extends PathProviderPlatform {
  /// Constructs a stub instance.
  PathProviderLinux.private({
    Map<String, String> environment = const <String, String>{},
    String? executableName,
    String? applicationId,
  });
}

/// Stub migration function for non-IO platforms.
Future<void> migrateLinuxPreferences({dynamic dataHomeDir}) async {}

/// Stub preference synchronizer for non-IO platforms.
void configureLinuxSharedPreferences(PathProviderPlatform provider) {}
