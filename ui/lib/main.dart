// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system/factory/lyra_design_system_scope.dart';
import 'design_system/factory/shadcn_factory.dart';
import 'design_system/tokens/lyra_tokens.dart';
import 'features/services/mock_music_service.dart';
import 'features/settings/services/preferences_service.dart';
import 'features/shell/app_shell.dart';
import 'platform/linux_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    PathProviderPlatform.instance = PathProviderLinux.private(
      applicationId: 'lyra',
    );
    configureLinuxSharedPreferences(PathProviderPlatform.instance);
    await migrateLinuxPreferences();
  }
  PreferencesService preferencesService;
  try {
    final prefs = await SharedPreferences.getInstance();
    preferencesService = SharedPreferencesService(prefs);
    debugPrint(
      '[Lyra] PreferencesService initialized: SharedPreferencesService',
    );
  } catch (e, stack) {
    debugPrint('[Lyra] SharedPreferences initialization failed: $e\n$stack');
    preferencesService = InMemoryPreferencesService();
  }
  runApp(LyraApp(preferencesService: preferencesService));
}

/// Root application widget configuring Shadcn theme and Lyra Design System Scope.
class LyraApp extends StatefulWidget {
  final PreferencesService? preferencesService;

  const LyraApp({super.key, this.preferencesService});

  @override
  State<LyraApp> createState() => _LyraAppState();
}

class _LyraAppState extends State<LyraApp> {
  late final ValueNotifier<ThemeMode> _themeModeNotifier;
  final MockMusicService _musicService = MockMusicService();
  final ShadcnFactory _shadcnFactory = const ShadcnFactory();

  @override
  void initState() {
    super.initState();
    _themeModeNotifier = ValueNotifier<ThemeMode>(
      widget.preferencesService?.themeMode ?? ThemeMode.dark,
    );
    _themeModeNotifier.addListener(_onThemeModeChanged);
  }

  void _onThemeModeChanged() {
    widget.preferencesService?.setThemeMode(_themeModeNotifier.value);
  }

  @override
  void didUpdateWidget(covariant LyraApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferencesService != widget.preferencesService &&
        widget.preferencesService != null) {
      _themeModeNotifier.value = widget.preferencesService!.themeMode;
    }
  }

  @override
  void dispose() {
    _themeModeNotifier.removeListener(_onThemeModeChanged);
    _themeModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Lyra Desktop',
      debugShowCheckedModeBanner: false,
      home: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeModeNotifier,
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
              factory: _shadcnFactory,
              tokens: tokens,
              themeModeNotifier: _themeModeNotifier,
              child: AppShell(
                musicService: _musicService,
                preferencesService: widget.preferencesService,
              ),
            ),
          );
        },
      ),
    );
  }
}
