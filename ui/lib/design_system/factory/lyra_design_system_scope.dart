// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';

import '../tokens/lyra_tokens.dart';
import 'lyra_design_system_factory.dart';

/// Inherited scope providing access to the current Design System Factory,
/// active theme tokens, and dynamic theme switching capabilities.
class LyraDesignSystemScope extends InheritedWidget {
  final LyraDesignSystemFactory factory;
  final LyraThemeTokens tokens;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const LyraDesignSystemScope({
    super.key,
    required this.factory,
    required this.tokens,
    required this.themeModeNotifier,
    required super.child,
  });

  /// Access the nearest [LyraDesignSystemScope] ancestor.
  static LyraDesignSystemScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<LyraDesignSystemScope>();
    assert(scope != null, 'No LyraDesignSystemScope found in context.');
    return scope!;
  }

  /// Optionally access the nearest [LyraDesignSystemScope] ancestor.
  static LyraDesignSystemScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LyraDesignSystemScope>();
  }

  /// Toggle between dark and light themes.
  void toggleTheme() {
    if (themeModeNotifier.value == ThemeMode.dark) {
      themeModeNotifier.value = ThemeMode.light;
    } else {
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  /// Set explicit theme mode.
  void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }

  @override
  bool updateShouldNotify(LyraDesignSystemScope oldWidget) {
    return factory != oldWidget.factory ||
        tokens != oldWidget.tokens ||
        themeModeNotifier != oldWidget.themeModeNotifier;
  }
}
