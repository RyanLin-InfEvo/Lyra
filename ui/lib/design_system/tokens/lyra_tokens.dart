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

  // Neutral Charcoal Palette (Pure Saturation 0: R == G == B)
  static const Color charcoal950 = Color(0xFF101010); // Main Canvas Background
  static const Color charcoal900 = Color(0xFF161616); // Sidebar Background
  static const Color charcoal850 = Color(0xFF1B1B1B); // Card & Container Surface (101010 + 11)
  static const Color charcoal800 = Color(0xFF242424); // Subtle 1px Border (161616 + 14)
  static const Color charcoal750 = Color(0xFF323232); // Selected / Active Item Surface (161616 + 28)
  static const Color charcoal700 = Color(0xFF383838); // Selected Item Hover Surface (161616 + 34)
  static const Color charcoalHover = Color(0xFF1C1C1C); // Sidebar Item Hover Surface (161616 + 6)
  static const Color charcoalSecondary = Color(0xFF222222); // Secondary Button / Pill Surface
  static const Color softWhite = Color(0xFFEDEDED); // Softened Primary Text (Anti-glare, Saturation 0)
  static const Color appleGray = Color(0xFF8E8E8E); // Apple Secondary Label Gray (Saturation 0)
  static const Color charcoalMutedText = Color(0xFF8E8E8E); // Secondary Label Gray (Saturation 0)

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

  /// Dark Mode Tokens (Apple HIG Pure Neutral Charcoal, Saturation 0)
  factory LyraThemeTokens.dark() {
    return const LyraThemeTokens(
      isDark: true,
      background: LyraColors.charcoal950, // #101010
      foreground: LyraColors.softWhite, // #EDEDED
      card: LyraColors.charcoal850, // #1B1B1B
      cardForeground: LyraColors.softWhite,
      border: LyraColors.charcoal800, // #242424
      text: LyraColors.softWhite, // #EDEDED
      textMuted: LyraColors.charcoalMutedText, // #8E8E8E
      primary: LyraColors.softWhite,
      primaryForeground: LyraColors.charcoal950,
      secondary: LyraColors.charcoal750, // #323232 (Selected Item)
      secondaryForeground: LyraColors.softWhite,
      muted: LyraColors.charcoalHover, // #1C1C1C
      mutedForeground: LyraColors.charcoalMutedText, // #8E8E8E
      accent: LyraColors.charcoalHover, // #1C1C1C (Hover Item)
      accentForeground: LyraColors.softWhite,
      destructive: LyraColors.red500,
      destructiveForeground: LyraColors.softWhite,
      ring: Color(0xFF007AFF), // Apple System Blue focus ring
      success: LyraColors.emerald500,
      successForeground: LyraColors.charcoal950,
      warning: LyraColors.amber500,
      warningForeground: LyraColors.charcoal950,
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

  // ===========================================================================
  // Interactive State Color & Border Helpers
  // ===========================================================================

  /// Transparent background preserving the exact RGB channels of [secondary],
  /// preventing dark-gray interpolation artifacts during Color.lerp transitions in Light Theme.
  Color get itemHoverTransparent => secondary.withValues(alpha: 0.0);

  /// Standard subtle hover highlight background for interactive items.
  Color get itemHoverBackground => secondary.withValues(alpha: 0.5);

  /// Standard selected background for interactive items.
  Color get itemSelectedBackground => secondary;

  /// Unified background color for list/nav items based on selection and hover/focus state.
  Color itemBackground({
    bool isSelected = false,
    bool isHovered = false,
    bool isFocused = false,
  }) {
    if (isSelected) return itemSelectedBackground;
    if (isHovered || isFocused) return itemHoverBackground;
    return itemHoverTransparent;
  }

  /// Sidebar background color ensuring receding navigation layer per Apple HIG.
  Color get sidebar => isDark ? LyraColors.charcoal900 : const Color(0xFFFFFFFF);

  /// Elevated surface background color for selected list rows and cards.
  Color get surfaceElevated =>
      isDark ? LyraColors.charcoal750 : LyraColors.zinc100;

  /// Elevated surface hover background color for selected list rows and cards.
  Color get surfaceElevatedHover =>
      isDark ? LyraColors.charcoal700 : LyraColors.zinc200;

  /// Secondary surface background color for active / current playing indicators.
  Color get surfaceSecondary =>
      isDark ? LyraColors.charcoalSecondary : LyraColors.zinc200;

  /// Computes hover surface color relative to [baseSurface].
  Color hoverOn(Color baseSurface) => baseSurface.hoverSurface(isDark: isDark);

  /// Computes active/selected surface color relative to [baseSurface].
  Color activeOn(Color baseSurface) => baseSurface.activeSurface(isDark: isDark);

  /// Subtle semi-transparent border color.
  Color get borderSubtle => border.withValues(alpha: 0.5);

  /// Focused ring border with [ring] color.
  Border focusedRingBorder({double width = 1.5}) =>
      Border.all(color: ring, width: width);

  /// Unfocused ring border preserving [ring] RGB channels to prevent dark-gray flashes during Border.lerp.
  Border unfocusedRingBorder({double width = 1.5}) =>
      Border.all(color: ring.withValues(alpha: 0.0), width: width);
}

/// Relative surface elevation extension for systematic layer management.
///
/// Follows pure saturation-0 grayscale rules (R == G == B):
/// - In dark mode, higher elevation adds brightness (+delta RGB units).
/// - In light mode, higher elevation subtracts brightness (-delta RGB units)
///   to maintain consistent relative contrast.
extension LyraSurfaceElevation on Color {
  /// Elevates a base surface color by [delta] brightness steps.
  Color elevate(int delta, {bool isDark = true}) {
    final effectiveDelta = isDark ? delta : -delta;
    final r = (this.r * 255.0).round();
    final g = (this.g * 255.0).round();
    final b = (this.b * 255.0).round();
    final a = (this.a * 255.0).round();
    return Color.fromARGB(
      a,
      (r + effectiveDelta).clamp(0, 255),
      (g + effectiveDelta).clamp(0, 255),
      (b + effectiveDelta).clamp(0, 255),
    );
  }

  /// Subtle interactive hover state (+6 RGB units, e.g. #161616 -> #1C1C1C).
  Color hoverSurface({bool isDark = true}) => elevate(6, isDark: isDark);

  /// Active or selected item surface (+28 RGB units, e.g. #161616 -> #323232).
  Color activeSurface({bool isDark = true}) => elevate(28, isDark: isDark);

  /// Hover state over an active/selected surface (+34 RGB units, e.g. #161616 -> #383838).
  Color activeHoverSurface({bool isDark = true}) => elevate(34, isDark: isDark);

  /// Subtle 1px dividing border (+14 RGB units, e.g. #101010 -> #1E1E1E, #161616 -> #242424).
  Color borderSurface({bool isDark = true}) => elevate(14, isDark: isDark);

  /// Card/container surface (+11 RGB units, e.g. #101010 -> #1B1B1B).
  Color cardSurface({bool isDark = true}) => elevate(11, isDark: isDark);
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
          primary: LyraColors.softWhite,
          primaryForeground: LyraColors.charcoal950,
          ring: const Color(0xFF71717A),
          accent: LyraColors.charcoalHover,
          secondary: LyraColors.charcoal750,
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
          primaryForeground: LyraColors.charcoal950,
          ring: const Color(0xFFFBBF24),
          accent: const Color(0xFFF59E0B).withValues(alpha: 0.2),
        );
    }

    final customColor = parseHexColor(accentColor);
    if (customColor != null) {
      final luminance = customColor.computeLuminance();
      final fg = luminance > 0.5
          ? LyraColors.charcoal950
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
