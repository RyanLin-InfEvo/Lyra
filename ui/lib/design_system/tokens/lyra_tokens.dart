// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

/// Semantic zinc and accent color palette matching Shadcn design system.
class LyraColors {
  const LyraColors._();

  // Zinc Palette
  static const Color zinc50 = Color(0xFFFAFAFA);
  static const Color zinc100 = Color(0xFFF4F4F5);
  static const Color zinc200 = Color(0xFFE4E4E7);
  static const Color zinc300 = Color(0xFFD4D4D8);
  static const Color zinc400 = Color(0xFFA1A1AA);
  static const Color zinc500 = Color(0xFF71717A);
  static const Color zinc600 = Color(0xFF52525B);
  static const Color zinc700 = Color(0xFF3F3F46);
  static const Color zinc800 = Color(0xFF27272A);
  static const Color zinc900 = Color(0xFF18181B);
  static const Color zinc950 = Color(0xFF09090B);

  // Emerald Palette (Success / CAS Verified)
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald950 = Color(0xFF022C22);

  // Blue Palette (Focus Ring / Hi-Res FLAC)
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue950 = Color(0xFF172554);

  // Amber Palette (Warning / WAV)
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber950 = Color(0xFF451A03);

  // Red Palette (Destructive / Unverified)
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red950 = Color(0xFF450A0A);
}

/// Theme tokens defining colors for light and dark modes.
class LyraThemeTokens {
  final bool isDark;
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color ring;
  final Color success;
  final Color successForeground;
  final Color warning;
  final Color warningForeground;

  const LyraThemeTokens({
    required this.isDark,
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.ring,
    required this.success,
    required this.successForeground,
    required this.warning,
    required this.warningForeground,
  });

  /// Zinc Dark Mode Tokens
  factory LyraThemeTokens.dark() {
    return const LyraThemeTokens(
      isDark: true,
      background: LyraColors.zinc950, // #09090b
      foreground: LyraColors.zinc50, // #fafafa
      card: LyraColors.zinc900, // #18181b
      cardForeground: LyraColors.zinc50,
      border: LyraColors.zinc800, // #27272a
      text: LyraColors.zinc50, // #fafafa
      textMuted: LyraColors.zinc400, // #a1a1aa
      primary: LyraColors.zinc50,
      primaryForeground: LyraColors.zinc900,
      secondary: LyraColors.zinc800,
      secondaryForeground: LyraColors.zinc50,
      muted: LyraColors.zinc800,
      mutedForeground: LyraColors.zinc400,
      accent: LyraColors.zinc800,
      accentForeground: LyraColors.zinc50,
      destructive: LyraColors.red500,
      destructiveForeground: LyraColors.zinc50,
      ring: LyraColors.blue500, // #3b82f6
      success: LyraColors.emerald500,
      successForeground: LyraColors.zinc950,
      warning: LyraColors.amber500,
      warningForeground: LyraColors.zinc950,
    );
  }

  /// Zinc Light Mode Tokens
  factory LyraThemeTokens.light() {
    return const LyraThemeTokens(
      isDark: false,
      background: Color(0xFFFFFFFF),
      foreground: LyraColors.zinc950,
      card: Color(0xFFFFFFFF),
      cardForeground: LyraColors.zinc950,
      border: LyraColors.zinc200,
      text: LyraColors.zinc950,
      textMuted: LyraColors.zinc500,
      primary: LyraColors.zinc900,
      primaryForeground: LyraColors.zinc50,
      secondary: LyraColors.zinc100,
      secondaryForeground: LyraColors.zinc900,
      muted: LyraColors.zinc100,
      mutedForeground: LyraColors.zinc500,
      accent: LyraColors.zinc100,
      accentForeground: LyraColors.zinc900,
      destructive: LyraColors.red600,
      destructiveForeground: LyraColors.zinc50,
      ring: LyraColors.blue600,
      success: LyraColors.emerald600,
      successForeground: Color(0xFFFFFFFF),
      warning: LyraColors.amber600,
      warningForeground: LyraColors.zinc950,
    );
  }

  /// Returns a copy of this [LyraThemeTokens] with the given fields replaced.
  LyraThemeTokens copyWith({
    bool? isDark,
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? destructiveForeground,
    Color? ring,
    Color? success,
    Color? successForeground,
    Color? warning,
    Color? warningForeground,
  }) {
    return LyraThemeTokens(
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground:
          destructiveForeground ?? this.destructiveForeground,
      ring: ring ?? this.ring,
      success: success ?? this.success,
      successForeground: successForeground ?? this.successForeground,
      warning: warning ?? this.warning,
      warningForeground: warningForeground ?? this.warningForeground,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyraThemeTokens &&
          runtimeType == other.runtimeType &&
          isDark == other.isDark &&
          background == other.background &&
          foreground == other.foreground &&
          card == other.card &&
          cardForeground == other.cardForeground &&
          border == other.border &&
          text == other.text &&
          textMuted == other.textMuted &&
          primary == other.primary &&
          primaryForeground == other.primaryForeground &&
          secondary == other.secondary &&
          secondaryForeground == other.secondaryForeground &&
          muted == other.muted &&
          mutedForeground == other.mutedForeground &&
          accent == other.accent &&
          accentForeground == other.accentForeground &&
          destructive == other.destructive &&
          destructiveForeground == other.destructiveForeground &&
          ring == other.ring &&
          success == other.success &&
          successForeground == other.successForeground &&
          warning == other.warning &&
          warningForeground == other.warningForeground;

  @override
  int get hashCode => Object.hashAll([
    isDark,
    background,
    foreground,
    card,
    cardForeground,
    border,
    text,
    textMuted,
    primary,
    primaryForeground,
    secondary,
    secondaryForeground,
    muted,
    mutedForeground,
    accent,
    accentForeground,
    destructive,
    destructiveForeground,
    ring,
    success,
    successForeground,
    warning,
    warningForeground,
  ]);
}

/// Parses a hex color string (e.g. '#3B82F6', '3B82F6', '0xFF3B82F6').
Color? parseHexColor(String hex) {
  var clean = hex.replaceAll('#', '').trim();
  if (clean.startsWith('0x') || clean.startsWith('0X')) {
    clean = clean.substring(2);
  }
  if (clean.length == 6) {
    clean = 'FF$clean';
  }
  if (clean.length == 8) {
    final val = int.tryParse(clean, radix: 16);
    if (val != null) return Color(val);
  }
  return null;
}

/// Derives [LyraThemeTokens] reflecting the specified [accentColor] (preset name or hex code).
LyraThemeTokens deriveLyraThemeTokens(String accentColor, bool isDark) {
  final base = isDark ? LyraThemeTokens.dark() : LyraThemeTokens.light();
  final lower = accentColor.toLowerCase().trim();

  if (isDark) {
    switch (lower) {
      case 'zinc':
        return base.copyWith(
          primary: const Color(0xFFFAFAFA),
          primaryForeground: const Color(0xFF18181B),
          ring: const Color(0xFF71717A),
          accent: const Color(0xFF27272A),
        );
      case 'slate':
        return base.copyWith(
          primary: const Color(0xFF94A3B8),
          primaryForeground: const Color(0xFF0F172A),
          ring: const Color(0xFFCBD5E1),
          accent: const Color(0xFF94A3B8).withValues(alpha: 0.2),
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
    }

    final customColor = parseHexColor(accentColor);
    if (customColor != null) {
      final luminance = customColor.computeLuminance();
      final fg = luminance > 0.5
          ? const Color(0xFF09090B)
          : const Color(0xFFFFFFFF);
      return base.copyWith(
        primary: customColor,
        primaryForeground: fg,
        ring: customColor,
        accent: customColor.withValues(alpha: 0.2),
      );
    }

    return base;
  }

  // Light Mode
  switch (lower) {
    case 'zinc':
      return base;
    case 'slate':
      const c = Color(0xFF64748B);
      return base.copyWith(
        primary: c,
        primaryForeground: const Color(0xFFFFFFFF),
        ring: c,
        accent: c.withValues(alpha: 0.12),
      );
    case 'blue':
      const c = LyraColors.blue500;
      return base.copyWith(
        primary: c,
        primaryForeground: const Color(0xFFFFFFFF),
        ring: c,
        accent: c.withValues(alpha: 0.12),
      );
    case 'emerald':
      const c = LyraColors.emerald500;
      return base.copyWith(
        primary: c,
        primaryForeground: const Color(0xFFFFFFFF),
        ring: c,
        accent: c.withValues(alpha: 0.12),
      );
    case 'violet':
      const c = Color(0xFF8B5CF6);
      return base.copyWith(
        primary: c,
        primaryForeground: const Color(0xFFFFFFFF),
        ring: c,
        accent: c.withValues(alpha: 0.12),
      );
    case 'rose':
      const c = Color(0xFFF43F5E);
      return base.copyWith(
        primary: c,
        primaryForeground: const Color(0xFFFFFFFF),
        ring: c,
        accent: c.withValues(alpha: 0.12),
      );
    case 'amber':
      const c = LyraColors.amber500;
      return base.copyWith(
        primary: c,
        primaryForeground: const Color(0xFF000000),
        ring: c,
        accent: c.withValues(alpha: 0.12),
      );
  }

  final customColor = parseHexColor(accentColor);
  if (customColor != null) {
    final luminance = customColor.computeLuminance();
    final fg = luminance > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    return base.copyWith(
      primary: customColor,
      primaryForeground: fg,
      ring: customColor,
      accent: customColor.withValues(alpha: 0.12),
    );
  }

  return base;
}

/// Spacing tokens based on standard 4px/8px grid system.
class LyraSpacing {
  const LyraSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Radius tokens for rounded borders.
class LyraRadius {
  const LyraRadius._();

  static const double none = 0.0;
  static const double sm = 4.0;
  static const double md = 6.0;
  static const double lg = 8.0;
  static const double xl = 12.0;
  static const double full = 9999.0;

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );
}

/// Typography tokens for consistent font hierarchy.
class LyraTypography {
  const LyraTypography._();

  static TextStyle h1(LyraThemeTokens tokens) => TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.8,
    color: tokens.text,
  );

  static TextStyle h2(LyraThemeTokens tokens) => TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: tokens.text,
  );

  static TextStyle h3(LyraThemeTokens tokens) => TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: tokens.text,
  );

  static TextStyle h4(LyraThemeTokens tokens) => TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    color: tokens.text,
  );

  static TextStyle p(LyraThemeTokens tokens) => TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    height: 1.4,
    color: tokens.text,
  );

  static TextStyle small(LyraThemeTokens tokens) => TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    color: tokens.text,
  );

  static TextStyle muted(LyraThemeTokens tokens) => TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.normal,
    color: tokens.textMuted,
  );

  static TextStyle mono(LyraThemeTokens tokens, {double fontSize = 12.0}) =>
      TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: tokens.text,
      );
}

/// Motion and animation tokens for duration and easing curves.
class LyraAnimation {
  const LyraAnimation._();

  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration sheet = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);

  // Easing Curves
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve springGentle = Cubic(0.32, 0.72, 0.0, 1.0);
  static const Curve deceleration = Cubic(0.0, 0.0, 0.2, 1.0);
}
