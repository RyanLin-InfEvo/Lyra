// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Smooth rotating loading spinner adhering to Apple HIG motion smoothness and layout safety.
class LyraSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final Duration duration;
  final String? semanticsLabel;

  const LyraSpinner({
    super.key,
    this.size = 16.0,
    this.color,
    this.duration = const Duration(milliseconds: 1000),
    this.semanticsLabel = 'Loading',
  }) : assert(duration > Duration.zero, 'duration must be greater than zero');

  @override
  State<LyraSpinner> createState() => _LyraSpinnerState();
}

class _LyraSpinnerState extends State<LyraSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant LyraSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox.square(
      dimension: widget.size,
      child: Center(
        child: RepaintBoundary(
          child: RotationTransition(
            turns: _controller,
            child: Icon(
              LucideIcons.loader2,
              size: widget.size,
              color: widget.color,
            ),
          ),
        ),
      ),
    );

    if (widget.semanticsLabel != null && widget.semanticsLabel!.isNotEmpty) {
      return Semantics(label: widget.semanticsLabel, child: spinner);
    }

    return spinner;
  }
}
