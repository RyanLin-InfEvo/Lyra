// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';

/// Theme-adaptive Lyra architectural brand icon with optional entrance animation.
///
/// Mirrors `docs/visual-designs/icon/` specifications:
/// - Sizes `< 64px` use the mini geometry (18px strings, no four-point star).
/// - Sizes `>= 64px` use the normal geometry (15px strings + four-point star).
class LyraBrandLogo extends StatefulWidget {
  final double size;
  final bool animated;
  final double borderRadius;
  final bool showBorder;
  final VoidCallback? onTap;

  const LyraBrandLogo({
    super.key,
    this.size = 48.0,
    this.animated = false,
    this.borderRadius = 0.0,
    this.showBorder = true,
    this.onTap,
  });

  @override
  State<LyraBrandLogo> createState() => LyraBrandLogoState();
}

class LyraBrandLogoState extends State<LyraBrandLogo>
    with SingleTickerProviderStateMixin {
  static const Duration _totalDuration = Duration(milliseconds: 940);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
      value: widget.animated ? 0.0 : 1.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.animated || disableAnimations) {
      _controller.value = 1.0;
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant LyraBrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!widget.animated || disableAnimations) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  /// Current normalized animation progress (`0.0` to `1.0`).
  @visibleForTesting
  double get animationProgress => _controller.value;

  /// Replays the entrance animation from the beginning.
  void replay() {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _controller.value = 1.0;
      return;
    }
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final isDark = tokens.isDark;
    final isMini = widget.size < 64.0;

    final Widget artwork = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _LyraBrandPainter(
              isDark: isDark,
              isMini: isMini,
              progress: _controller.value,
            ),
          );
        },
      ),
    );

    final Widget framed = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.showBorder
            ? Border.all(color: tokens.border, width: 1.0)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: artwork,
    );

    if (widget.onTap == null) {
      return Semantics(image: true, label: 'Lyra logo', child: framed);
    }

    return Semantics(
      button: true,
      label: 'Lyra logo',
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(onTap: widget.onTap, child: framed),
      ),
    );
  }
}

class _LyraBrandPainter extends CustomPainter {
  final bool isDark;
  final bool isMini;
  final double progress;

  static const Curve _stringCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve _starCurve = Cubic(0.34, 1.56, 0.64, 1.0);

  const _LyraBrandPainter({
    required this.isDark,
    required this.isMini,
    required this.progress,
  });

  double _intervalProgress(double startMs, double endMs, Curve curve) {
    const totalMs = 940.0;
    final start = startMs / totalMs;
    final end = endMs / totalMs;
    if (progress <= start) return 0.0;
    if (progress >= end) return 1.0;
    final t = (progress - start) / (end - start);
    return curve.transform(t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 512.0;
    canvas.save();
    canvas.scale(scale, scale);

    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final monogramColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final stringColor = isDark
        ? const Color(0xFFD2D8E2)
        : const Color(0xFF94A3B8);
    final starTargetColor = isDark
        ? const Color(0xFFEFF1F5)
        : const Color(0xFF475569);

    // Background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 512, 512),
      Paint()..color = bgColor,
    );

    // Architectural L Monogram: M136 102H180V366H376V406H136V102Z
    final lPath = Path()
      ..moveTo(136, 102)
      ..lineTo(180, 102)
      ..lineTo(180, 366)
      ..lineTo(376, 366)
      ..lineTo(376, 406)
      ..lineTo(136, 406)
      ..close();
    canvas.drawPath(lPath, Paint()..color = monogramColor);

    // Parallel Harp Strings (grow bottom-to-top anchored at y=366)
    final s1T = _intervalProgress(80.0, 530.0, _stringCurve).clamp(0.0, 1.0);
    final s2T = _intervalProgress(180.0, 600.0, _stringCurve).clamp(0.0, 1.0);

    final stringPaint = Paint()..color = stringColor;
    final s1X = isMini ? 195.0 : 198.0;
    final s2X = isMini ? 228.0 : 231.0;
    final stringWidth = isMini ? 18.0 : 15.0;

    if (s1T > 0) {
      final h1 = 264.0 * s1T;
      canvas.drawRect(
        Rect.fromLTWH(s1X, 366.0 - h1, stringWidth, h1),
        stringPaint,
      );
    }
    if (s2T > 0) {
      final h2 = 226.0 * s2T;
      canvas.drawRect(
        Rect.fromLTWH(s2X, 366.0 - h2, stringWidth, h2),
        stringPaint,
      );
    }

    // Four-Point Star Node (hidden for <64px mini scale)
    if (!isMini) {
      const startMs = 420.0;
      const endMs = 940.0;
      const totalMs = 940.0;
      final rawT =
          ((progress - startMs / totalMs) / ((endMs - startMs) / totalMs))
              .clamp(0.0, 1.0);

      if (rawT > 0) {
        final curvedT = _starCurve.transform(rawT);
        final starScale = 0.2 + (0.8 * curvedT);
        final rotationRad = (-90.0 * (1.0 - curvedT)) * (math.pi / 180.0);
        final opacity = (rawT / 0.6).clamp(0.0, 1.0);
        final Color starColor;
        if (rawT <= 0.6) {
          starColor = monogramColor;
        } else {
          final colorT = ((rawT - 0.6) / 0.4).clamp(0.0, 1.0);
          starColor = Color.lerp(monogramColor, starTargetColor, colorT)!;
        }

        canvas.save();
        canvas.translate(283.0, 124.0);
        canvas.rotate(rotationRad);
        canvas.scale(starScale, starScale);

        final starPath = Path()
          ..moveTo(0, -21)
          ..lineTo(6.2, -6.2)
          ..lineTo(21, 0)
          ..lineTo(6.2, 6.2)
          ..lineTo(0, 21)
          ..lineTo(-6.2, 6.2)
          ..lineTo(-21, 0)
          ..lineTo(-6.2, -6.2)
          ..close();

        canvas.drawPath(
          starPath,
          Paint()..color = starColor.withValues(alpha: opacity),
        );
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LyraBrandPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.isMini != isMini ||
        oldDelegate.progress != progress;
  }
}
