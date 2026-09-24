// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/models/waveform_data.dart';
import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../controllers/playback_queue_controller.dart';

/// Interactive audiophile waveform scrubber component.
///
/// Features:
/// - Discrete dual-polarity vertical rounded bars with split progress coloring.
/// - Playhead indicator with glowing cap marker and dynamic playing pulse.
/// - Direct seeking and scrubbing gestures with real-time target preview.
/// - Mouse hover guide line with floating timestamp tooltip badge.
/// - Monospace time labels for elapsed and total duration.
/// - Animated skeleton placeholder bars when waveform data is loading.
class WaveformScrubber extends StatefulWidget {
  /// Downsampled waveform points model, or null if loading.
  final WaveformData? waveform;

  /// Optional playback queue controller to automatically bind position, duration, and seek.
  final PlaybackQueueController? playbackController;

  /// Explicit playback position (overrides [playbackController] position if provided).
  final Duration? position;

  /// Explicit total duration (overrides [playbackController] duration if provided).
  final Duration? duration;

  /// Callback triggered when seeking by tap or drag.
  final ValueChanged<Duration>? onSeek;

  /// Total component height (including time labels if [showTimeLabels] is true).
  final double height;

  /// Whether to display elapsed and remaining / total time labels underneath the waveform.
  final bool showTimeLabels;

  /// Whether user interaction (tapping, dragging, hover guide) is enabled.
  final bool isInteractive;

  /// Whether to enable looping shimmer / pulse animations.
  /// Defaults to false during widget tests to avoid pumpAndSettle timeouts.
  final bool? enableAnimation;

  /// Whether to show the glowing pulse behind the playhead when playing.
  final bool enablePulseAnimation;

  /// Whether to show the hover guide line and floating timestamp tooltip.
  final bool enableHoverTimeGuide;

  const WaveformScrubber({
    super.key,
    this.waveform,
    this.playbackController,
    this.position,
    this.duration,
    this.onSeek,
    this.height = 64.0,
    this.showTimeLabels = true,
    this.isInteractive = true,
    this.enableAnimation,
    this.enablePulseAnimation = true,
    this.enableHoverTimeGuide = true,
  });

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final ValueNotifier<double?> _hoverXNotifier = ValueNotifier<double?>(null);

  bool _isDragging = false;
  double? _dragFraction;
  bool _isHovered = false;
  bool _isMouseDevice = false;
  Offset? _lastDragPosition;

  bool get _shouldAnimate {
    if (widget.enableAnimation != null) return widget.enableAnimation!;
    final binding = WidgetsBinding.instance;
    return !binding.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      value: 0.5,
    );
    if (_shouldAnimate) {
      _animController.repeat(reverse: true);
    }

    widget.playbackController?.positionNotifier.addListener(_onStateChanged);
    widget.playbackController?.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(WaveformScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isInteractive && oldWidget.isInteractive) {
      _hoverXNotifier.value = null;
      _isHovered = false;
      _isMouseDevice = false;
      _lastDragPosition = null;
      if (_isDragging) {
        _isDragging = false;
        _dragFraction = null;
      }
    }
    if (widget.enableAnimation != oldWidget.enableAnimation) {
      if (_shouldAnimate && !_animController.isAnimating) {
        _animController.repeat(reverse: true);
      } else if (!_shouldAnimate && _animController.isAnimating) {
        _animController.stop();
      }
    }
    if (oldWidget.playbackController != widget.playbackController) {
      oldWidget.playbackController?.positionNotifier.removeListener(
        _onStateChanged,
      );
      oldWidget.playbackController?.removeListener(_onStateChanged);
      widget.playbackController?.positionNotifier.addListener(_onStateChanged);
      widget.playbackController?.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.playbackController?.positionNotifier.removeListener(_onStateChanged);
    widget.playbackController?.removeListener(_onStateChanged);
    _hoverXNotifier.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Duration get _effectiveDuration {
    if (widget.duration != null) return widget.duration!;
    if (widget.playbackController != null) {
      return widget.playbackController!.duration;
    }
    return Duration.zero;
  }

  Duration get _effectivePosition {
    if (widget.position != null) return widget.position!;
    if (widget.playbackController != null) {
      return widget.playbackController!.positionNotifier.value;
    }
    return Duration.zero;
  }

  bool get _isPlaying {
    if (widget.playbackController != null) {
      return widget.playbackController!.isPlaying;
    }
    return false;
  }

  double _getFraction(Duration pos, Duration total) {
    if (_isDragging && _dragFraction != null) {
      return _dragFraction!;
    }
    final totalMs = total.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  void _handleSeek(double localX, double width) {
    if (!widget.isInteractive || width <= 0) return;
    final fraction = (localX / width).clamp(0.0, 1.0);
    final total = _effectiveDuration;
    final targetMs = (total.inMilliseconds * fraction).round();
    final target = Duration(milliseconds: targetMs);

    if (widget.onSeek != null) {
      widget.onSeek!(target);
    } else if (widget.playbackController != null) {
      widget.playbackController!.seek(target);
    }
  }

  void _handleTapDown(TapDownDetails details, double maxWidth) {
    if (!widget.isInteractive) return;
    final clampedX = maxWidth > 0
        ? details.localPosition.dx.clamp(0.0, maxWidth)
        : 0.0;
    final frac = maxWidth > 0 ? (clampedX / maxWidth).clamp(0.0, 1.0) : 0.0;
    _lastDragPosition = details.localPosition;
    if (details.kind == PointerDeviceKind.mouse) {
      _isMouseDevice = true;
      _isHovered = true;
    }
    _hoverXNotifier.value = clampedX;
    setState(() {
      _isDragging = true;
      _dragFraction = frac;
    });
    _handleSeek(clampedX, maxWidth);
  }

  void _handleTapUp(TapUpDetails details, double maxWidth, double maxHeight) {
    _lastDragPosition = details.localPosition;
    final isInside =
        details.localPosition.dx >= 0 &&
        details.localPosition.dx <= maxWidth &&
        details.localPosition.dy >= 0 &&
        details.localPosition.dy <= maxHeight;

    if (!isInside || !_isMouseDevice) {
      _isHovered = false;
      _hoverXNotifier.value = null;
    } else {
      _hoverXNotifier.value = details.localPosition.dx.clamp(0.0, maxWidth);
    }
    _lastDragPosition = null;

    if (_isDragging) {
      setState(() {
        _isDragging = false;
        _dragFraction = null;
      });
    }
  }

  void _handleTapCancel() {
    if (!_isHovered || !_isMouseDevice) {
      _hoverXNotifier.value = null;
    }
    _lastDragPosition = null;
    if (_isDragging) {
      setState(() {
        _isDragging = false;
        _dragFraction = null;
      });
    }
  }

  void _handleDragStart(DragStartDetails details, double maxWidth) {
    if (!widget.isInteractive) return;
    final clampedX = maxWidth > 0
        ? details.localPosition.dx.clamp(0.0, maxWidth)
        : 0.0;
    final frac = maxWidth > 0 ? (clampedX / maxWidth).clamp(0.0, 1.0) : 0.0;
    _lastDragPosition = details.localPosition;
    if (details.kind == PointerDeviceKind.mouse) {
      _isMouseDevice = true;
      _isHovered = true;
    }
    _hoverXNotifier.value = clampedX;
    setState(() {
      _isDragging = true;
      _dragFraction = frac;
    });
    _handleSeek(clampedX, maxWidth);
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (!widget.isInteractive) return;
    final clampedX = maxWidth > 0
        ? details.localPosition.dx.clamp(0.0, maxWidth)
        : 0.0;
    final frac = maxWidth > 0 ? (clampedX / maxWidth).clamp(0.0, 1.0) : 0.0;
    _lastDragPosition = details.localPosition;
    _hoverXNotifier.value = clampedX;
    setState(() {
      _dragFraction = frac;
    });
    _handleSeek(clampedX, maxWidth);
  }

  void _handleDragEnd(
    DragEndDetails details,
    double maxWidth,
    double maxHeight,
  ) {
    final lastPos = _lastDragPosition;
    final isInside =
        lastPos != null &&
        lastPos.dx >= 0 &&
        lastPos.dx <= maxWidth &&
        lastPos.dy >= 0 &&
        lastPos.dy <= maxHeight;

    if (!isInside || !_isMouseDevice) {
      _isHovered = false;
      _hoverXNotifier.value = null;
    } else {
      _isHovered = true;
      _hoverXNotifier.value = lastPos.dx.clamp(0.0, maxWidth);
    }
    _lastDragPosition = null;

    if (_isDragging) {
      setState(() {
        _isDragging = false;
        _dragFraction = null;
      });
    }
  }

  void _handleDragCancel() {
    if (!_isHovered || !_isMouseDevice) {
      _hoverXNotifier.value = null;
    }
    _lastDragPosition = null;
    if (_isDragging) {
      setState(() {
        _isDragging = false;
        _dragFraction = null;
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final totalDuration = _effectiveDuration;
    final currentPos = _effectivePosition;
    final double fraction = _getFraction(currentPos, totalDuration);

    final Duration displayedElapsed = _isDragging && _dragFraction != null
        ? Duration(
            milliseconds: (totalDuration.inMilliseconds * _dragFraction!)
                .round(),
          )
        : currentPos;

    final double waveformHeight = widget.showTimeLabels
        ? math.max(24.0, widget.height - 20.0)
        : widget.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: waveformHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;

              return MouseRegion(
                cursor: widget.isInteractive
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                onEnter: (event) {
                  if (!widget.isInteractive) return;
                  _isMouseDevice = true;
                  _isHovered = true;
                  _hoverXNotifier.value = maxWidth > 0
                      ? event.localPosition.dx.clamp(0.0, maxWidth)
                      : 0.0;
                },
                onHover: (event) {
                  if (!widget.isInteractive) return;
                  _isMouseDevice = true;
                  _isHovered = true;
                  _hoverXNotifier.value = maxWidth > 0
                      ? event.localPosition.dx.clamp(0.0, maxWidth)
                      : 0.0;
                },
                onExit: (_) {
                  _isHovered = false;
                  if (!_isDragging) {
                    _hoverXNotifier.value = null;
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _handleTapDown(details, maxWidth),
                  onTapUp: (details) =>
                      _handleTapUp(details, maxWidth, waveformHeight),
                  onTapCancel: _handleTapCancel,
                  onHorizontalDragStart: (details) =>
                      _handleDragStart(details, maxWidth),
                  onHorizontalDragUpdate: (details) =>
                      _handleDragUpdate(details, maxWidth),
                  onHorizontalDragEnd: (details) =>
                      _handleDragEnd(details, maxWidth, waveformHeight),
                  onHorizontalDragCancel: _handleDragCancel,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Waveform canvas with animated shimmer / pulse
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _animController,
                            builder: (context, _) {
                              return ValueListenableBuilder<double?>(
                                valueListenable: _hoverXNotifier,
                                builder: (context, hoverX, _) {
                                  return CustomPaint(
                                    painter: _WaveformPainter(
                                      waveform: widget.waveform,
                                      progress: fraction,
                                      hoverX: hoverX,
                                      tokens: tokens,
                                      isPlaying: _isPlaying,
                                      animValue: _animController.value,
                                      enablePulseAnimation:
                                          widget.enablePulseAnimation,
                                      enableHoverTimeGuide:
                                          widget.enableHoverTimeGuide,
                                    ),
                                    size: Size(maxWidth, waveformHeight),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      // Floating Hover Timestamp Tooltip
                      if (widget.isInteractive &&
                          widget.enableHoverTimeGuide &&
                          totalDuration.inMilliseconds > 0)
                        ValueListenableBuilder<double?>(
                          valueListenable: _hoverXNotifier,
                          builder: (context, hoverX, _) {
                            if (hoverX == null) {
                              return const SizedBox.shrink();
                            }
                            final badgeWidth = totalDuration.inHours > 0
                                ? 62.0
                                : 46.0;
                            final leftOffset = (hoverX - (badgeWidth / 2))
                                .clamp(
                                  0.0,
                                  math.max(0.0, maxWidth - badgeWidth),
                                )
                                .toDouble();
                            final hoverFraction = maxWidth > 0
                                ? (hoverX / maxWidth).clamp(0.0, 1.0)
                                : 0.0;
                            final hoverMs =
                                (totalDuration.inMilliseconds * hoverFraction)
                                    .round();

                            return Positioned(
                              top: -24.0,
                              left: leftOffset,
                              child: IgnorePointer(
                                key: const ValueKey('waveform_hover_tooltip'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5.0,
                                    vertical: 2.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.card,
                                    borderRadius: LyraRadius.smRadius,
                                    border: Border.all(
                                      color: tokens.border,
                                      width: 1.0,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 4.0,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _formatDuration(
                                      Duration(milliseconds: hoverMs),
                                    ),
                                    style:
                                        LyraTypography.mono(
                                          tokens,
                                          fontSize: 10.5,
                                        ).copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: tokens.text,
                                        ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.showTimeLabels) ...[
          const SizedBox(height: 4.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(displayedElapsed),
                style: LyraTypography.mono(
                  tokens,
                  fontSize: 11.0,
                ).copyWith(color: tokens.textMuted),
              ),
              Text(
                _formatDuration(totalDuration),
                style: LyraTypography.mono(
                  tokens,
                  fontSize: 11.0,
                ).copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Custom painter rendering discrete dual-polarity waveform bars, split progress color,
/// playhead cursor, dynamic pulse shimmer, and loading skeleton.
class _WaveformPainter extends CustomPainter {
  final WaveformData? waveform;
  final double progress;
  final double? hoverX;
  final LyraThemeTokens tokens;
  final bool isPlaying;
  final double animValue;
  final bool enablePulseAnimation;
  final bool enableHoverTimeGuide;

  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.hoverX,
    required this.tokens,
    required this.isPlaying,
    required this.animValue,
    this.enablePulseAnimation = true,
    this.enableHoverTimeGuide = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height / 2.0;
    final maxHalfHeight = (size.height / 2.0) * 0.92;
    final playheadX = (progress * size.width).clamp(0.0, size.width);

    // 1. Draw Waveform Bars or Skeleton
    if (waveform != null && waveform!.points.isNotEmpty) {
      final points = waveform!.points;
      final count = points.length;
      final step = size.width / count;
      final barWidth = (step * 0.68).clamp(1.5, 6.0);
      final radius = Radius.circular(barWidth / 2.0);

      final playedPaint = Paint()
        ..color = tokens.primary
        ..style = PaintingStyle.fill;

      final unplayedPaint = Paint()
        ..color = tokens.border.withValues(alpha: 0.70)
        ..style = PaintingStyle.fill;

      final hoveredUnplayedPaint = Paint()
        ..color = tokens.border
        ..style = PaintingStyle.fill;

      for (int i = 0; i < count; i++) {
        final x = i * step + (step - barWidth) / 2.0;
        final barCenterX = x + barWidth / 2.0;
        final pt = points[i];

        // Minimum visible bar height of 3.0 pt for silent passages
        final topExtent = math.max(3.0, pt.max.abs() * maxHalfHeight);
        final bottomExtent = math.max(3.0, pt.min.abs() * maxHalfHeight);

        final top = (centerY - topExtent).clamp(0.0, centerY - 1.5);
        final bottom = (centerY + bottomExtent).clamp(
          centerY + 1.5,
          size.height,
        );

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x, top, x + barWidth, bottom),
          radius,
        );

        if (barCenterX <= playheadX) {
          if (isPlaying && enablePulseAnimation) {
            // Subtle dynamic shimmer traveling across played bars
            final wavePhase = math.sin(
              (i / count) * 8.0 * math.pi - animValue * 2.0 * math.pi,
            );
            final shimmerAlpha = (0.85 + 0.15 * wavePhase).clamp(0.70, 1.0);
            playedPaint.color = tokens.primary.withValues(alpha: shimmerAlpha);
          } else {
            playedPaint.color = tokens.primary;
          }
          canvas.drawRRect(rrect, playedPaint);
        } else {
          if (hoverX != null && barCenterX <= hoverX!) {
            canvas.drawRRect(rrect, hoveredUnplayedPaint);
          } else {
            canvas.drawRRect(rrect, unplayedPaint);
          }
        }
      }
    } else {
      // Skeleton Loading State: animated undulating bars
      final skeletonCount = (size.width / 5.5).floor().clamp(24, 120);
      final step = size.width / skeletonCount;
      final barWidth = (step * 0.60).clamp(1.5, 4.0);
      final radius = Radius.circular(barWidth / 2.0);
      final skeletonPaint = Paint()..style = PaintingStyle.fill;

      for (int i = 0; i < skeletonCount; i++) {
        final x = i * step + (step - barWidth) / 2.0;
        final phase =
            (i / skeletonCount) * 3.5 * math.pi + animValue * 2.0 * math.pi;
        final wave = math.sin(phase) * 0.5 + 0.5;
        final h = 6.0 + wave * (maxHalfHeight * 1.5);

        final top = (centerY - h / 2.0).clamp(0.0, centerY - 1.5);
        final bottom = (centerY + h / 2.0).clamp(centerY + 1.5, size.height);

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x, top, x + barWidth, bottom),
          radius,
        );

        final alpha = (0.20 + 0.25 * wave).clamp(0.15, 0.50);
        skeletonPaint.color = tokens.mutedForeground.withValues(alpha: alpha);
        canvas.drawRRect(rrect, skeletonPaint);
      }
    }

    // 2. Hover Guide Line
    if (enableHoverTimeGuide && hoverX != null) {
      final hX = hoverX!.clamp(0.0, size.width);
      final hoverLinePaint = Paint()
        ..color = tokens.primary.withValues(alpha: 0.35)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(hX, 0.0), Offset(hX, size.height), hoverLinePaint);
    }

    // 3. Playhead Indicator (Line + Glowing Cap Marker + Dynamic Pulse)
    if (progress >= 0.0 && progress <= 1.0) {
      // Subtle pulse glow behind playhead line when playing
      if (isPlaying && enablePulseAnimation) {
        final pulse = math.sin(animValue * 2.0 * math.pi) * 0.5 + 0.5;
        final glowAlpha = (0.25 + 0.20 * pulse).clamp(0.15, 0.50);
        final glowPaint = Paint()
          ..color = tokens.primary.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawRect(
          Rect.fromLTRB(playheadX - 2.5, 0.0, playheadX + 2.5, size.height),
          glowPaint,
        );
      }

      // Vertical Playhead Line
      final playheadLinePaint = Paint()
        ..color = tokens.primary
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(playheadX, 0.0),
        Offset(playheadX, size.height),
        playheadLinePaint,
      );

      // Accent Marker / Cap at the top
      final capCenter = Offset(playheadX, 3.5);
      final capRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: capCenter, width: 7.0, height: 7.0),
        const Radius.circular(3.5),
      );
      final capPaint = Paint()
        ..color = tokens.primary
        ..style = PaintingStyle.fill;
      canvas.drawRRect(capRRect, capPaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return waveform != oldDelegate.waveform ||
        progress != oldDelegate.progress ||
        hoverX != oldDelegate.hoverX ||
        tokens != oldDelegate.tokens ||
        isPlaying != oldDelegate.isPlaying ||
        enablePulseAnimation != oldDelegate.enablePulseAnimation ||
        enableHoverTimeGuide != oldDelegate.enableHoverTimeGuide ||
        (isPlaying &&
            enablePulseAnimation &&
            animValue != oldDelegate.animValue) ||
        (waveform == null && animValue != oldDelegate.animValue);
  }
}
