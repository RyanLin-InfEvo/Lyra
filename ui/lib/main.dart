// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'design_system/factory/lyra_design_system_scope.dart';
import 'design_system/factory/shadcn_factory.dart';
import 'design_system/tokens/lyra_tokens.dart';
import 'features/services/mock_music_service.dart';
import 'features/shell/app_shell.dart';

void main() {
  runApp(const LyraApp());
}

/// Root application widget configuring Shadcn theme and Lyra Design System Scope.
class LyraApp extends StatefulWidget {
  const LyraApp({super.key});

  @override
  State<LyraApp> createState() => _LyraAppState();
}

class _LyraAppState extends State<LyraApp> {
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.dark,
  );
  final MockMusicService _musicService = MockMusicService();
  final ShadcnFactory _shadcnFactory = const ShadcnFactory();

  @override
  void dispose() {
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
              child: AppShell(musicService: _musicService),
            ),
          );
        },
      ),
    );
  }
}
