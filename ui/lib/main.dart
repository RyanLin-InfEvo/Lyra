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

/// Derives a [ShadColorScheme] based on the active [accentColor] and [brightness].
ShadColorScheme deriveShadColorScheme(
  String accentColor,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  final lower = accentColor.toLowerCase().trim();

  if (isDark) {
    const base = ShadZincColorScheme.dark(
      background: Color(0xFF09090B),
      foreground: Color(0xFFFAFAFA),
      card: Color(0xFF18181B),
      cardForeground: Color(0xFFFAFAFA),
      popover: Color(0xFF18181B),
      popoverForeground: Color(0xFFFAFAFA),
      border: Color(0xFF27272A),
      input: Color(0xFF27272A),
    );

    switch (lower) {
      case 'zinc':
        return base.copyWith(
          primary: const Color(0xFFFAFAFA),
          primaryForeground: const Color(0xFF18181B),
          ring: const Color(0xFF71717A),
        );
      case 'blue':
        return base.copyWith(
          primary: const Color(0xFF3B82F6),
          primaryForeground: const Color(0xFFFFFFFF),
          ring: const Color(0xFF60A5FA),
          accent: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        );
      case 'emerald':
        return base.copyWith(
          primary: const Color(0xFF10B981),
          primaryForeground: const Color(0xFFFFFFFF),
          ring: const Color(0xFF34D399),
          accent: const Color(0xFF10B981).withValues(alpha: 0.2),
        );
      case 'violet':
        return base.copyWith(
          primary: const Color(0xFF8B5CF6),
          primaryForeground: const Color(0xFFFFFFFF),
          ring: const Color(0xFFA78BFA),
          accent: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
        );
      case 'rose':
        return base.copyWith(
          primary: const Color(0xFFF43F5E),
          primaryForeground: const Color(0xFFFFFFFF),
          ring: const Color(0xFFFB7185),
          accent: const Color(0xFFF43F5E).withValues(alpha: 0.2),
        );
      case 'amber':
        return base.copyWith(
          primary: const Color(0xFFF59E0B),
          primaryForeground: const Color(0xFF09090B),
          ring: const Color(0xFFFBBF24),
          accent: const Color(0xFFF59E0B).withValues(alpha: 0.2),
        );
      case 'slate':
        return base.copyWith(
          primary: const Color(0xFF94A3B8),
          primaryForeground: const Color(0xFF0F172A),
          ring: const Color(0xFFCBD5E1),
          accent: const Color(0xFF94A3B8).withValues(alpha: 0.2),
        );
    }

    final customColor = parseHexColor(accentColor);
    if (customColor != null) {
      final isLight = customColor.computeLuminance() > 0.5;
      final fg = isLight ? const Color(0xFF09090B) : const Color(0xFFFFFFFF);
      return base.copyWith(
        primary: customColor,
        primaryForeground: fg,
        ring: customColor,
        accent: customColor.withValues(alpha: 0.2),
        accentForeground: const Color(0xFFFAFAFA),
      );
    }

    return base.copyWith(
      primary: const Color(0xFFFAFAFA),
      primaryForeground: const Color(0xFF18181B),
      ring: const Color(0xFF71717A),
    );
  }

  switch (lower) {
    case 'zinc':
      return const ShadZincColorScheme.light();
    case 'slate':
      return const ShadSlateColorScheme.light();
    case 'blue':
      return const ShadBlueColorScheme.light();
    case 'emerald':
      final base = const ShadGreenColorScheme.light();
      return base.copyWith(
        primary: LyraColors.emerald500,
        ring: LyraColors.emerald500,
        accent: LyraColors.emerald500.withValues(alpha: 0.12),
      );
    case 'violet':
      return const ShadVioletColorScheme.light();
    case 'rose':
      return const ShadRoseColorScheme.light();
    case 'amber':
      final base = const ShadYellowColorScheme.light();
      return base.copyWith(
        primary: LyraColors.amber500,
        ring: LyraColors.amber500,
        accent: LyraColors.amber500.withValues(alpha: 0.12),
      );
  }

  final customColor = parseHexColor(accentColor);
  if (customColor != null) {
    final base = const ShadZincColorScheme.light();
    final isDarkColor = customColor.computeLuminance() < 0.5;
    final fg = isDarkColor ? Colors.white : Colors.black;
    return base.copyWith(
      primary: customColor,
      primaryForeground: fg,
      ring: customColor,
      accent: customColor.withValues(alpha: 0.12),
      accentForeground: Colors.black,
    );
  }

  return const ShadZincColorScheme.light();
}

class _LyraAppState extends State<LyraApp> {
  late final ValueNotifier<ThemeMode> _themeModeNotifier;
  String _currentAccentColor = 'zinc';
  final MockMusicService _musicService = MockMusicService();
  final ShadcnFactory _shadcnFactory = const ShadcnFactory();

  @override
  void initState() {
    super.initState();
    _currentAccentColor = widget.preferencesService?.accentColor ?? 'zinc';
    _themeModeNotifier = ValueNotifier<ThemeMode>(
      widget.preferencesService?.themeMode ?? ThemeMode.dark,
    );
    _themeModeNotifier.addListener(_onThemeModeChanged);
    widget.preferencesService?.addListener(_onPreferencesChanged);
  }

  void _onPreferencesChanged() {
    if (mounted) {
      bool needRebuild = false;
      if (widget.preferencesService != null) {
        if (_themeModeNotifier.value != widget.preferencesService!.themeMode) {
          _themeModeNotifier.value = widget.preferencesService!.themeMode;
        }
        if (_currentAccentColor != widget.preferencesService!.accentColor) {
          _currentAccentColor = widget.preferencesService!.accentColor;
          needRebuild = true;
        }
      }
      if (needRebuild) {
        setState(() {});
      }
    }
  }

  void _onThemeModeChanged() {
    widget.preferencesService?.setThemeMode(_themeModeNotifier.value);
  }

  @override
  void didUpdateWidget(covariant LyraApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferencesService != widget.preferencesService) {
      oldWidget.preferencesService?.removeListener(_onPreferencesChanged);
      widget.preferencesService?.addListener(_onPreferencesChanged);
      if (widget.preferencesService != null) {
        _themeModeNotifier.value = widget.preferencesService!.themeMode;
        _currentAccentColor = widget.preferencesService!.accentColor;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.preferencesService?.removeListener(_onPreferencesChanged);
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
          final accentColor = widget.preferencesService?.accentColor ?? 'zinc';
          final tokens = deriveLyraThemeTokens(accentColor, isDark);
          final colorScheme = deriveShadColorScheme(
            accentColor,
            isDark ? Brightness.dark : Brightness.light,
          );
          final shadTheme = ShadThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            colorScheme: colorScheme,
            switchTheme: const ShadSwitchTheme(
              duration: Duration(milliseconds: 180),
            ),
            popoverTheme: const ShadPopoverTheme(
              reverseDuration: Duration(milliseconds: 50),
            ),
            contextMenuTheme: ShadContextMenuTheme(
              constraints: const BoxConstraints(minWidth: 180),
              padding: const EdgeInsets.symmetric(
                vertical: 4.0,
                horizontal: 4.0,
              ),
              itemPadding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 6.0,
              ),
              popoverReverseDuration: const Duration(milliseconds: 50),
              effects: [
                FadeEffect(
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOutCubic,
                ),
                ScaleEffect(
                  begin: const Offset(0.98, 0.98),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOutCubic,
                ),
              ],
              decoration: ShadDecoration(
                color: tokens.card.withValues(alpha: 0.92),
                border: ShadBorder.all(
                  color: tokens.border.withValues(alpha: 0.8),
                  width: 1.0,
                  radius: BorderRadius.circular(6.0),
                ),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 16.0,
                  offset: const Offset(0, 8),
                  spreadRadius: -2.0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6.0,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
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
