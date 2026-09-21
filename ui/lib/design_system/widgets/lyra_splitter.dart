// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';

/// Reusable vertical pane splitter handle with responsive mouse tracking,
/// dragging states, and visual divider highlight.
class LyraSplitter extends StatefulWidget {
  /// Invoked during horizontal dragging with the horizontal delta (dx).
  final ValueChanged<double>? onDelta;

  /// Invoked when a horizontal drag gesture starts.
  final VoidCallback? onDragStart;

  /// Invoked when a horizontal drag gesture ends or cancels.
  final VoidCallback? onDragEnd;

  /// Invoked on double tap (typically to reset the pane to default width).
  final VoidCallback? onDoubleTap;

  /// The interactive hit-target width. Defaults to 8.0 pixels.
  final double hitWidth;

  /// Custom divider color in idle state. Falls back to tokens.border.
  final Color? normalColor;

  /// Custom divider color in hovered or dragging state. Falls back to tokens.primary.
  final Color? activeColor;

  const LyraSplitter({
    super.key,
    this.onDelta,
    this.onDragStart,
    this.onDragEnd,
    this.onDoubleTap,
    this.hitWidth = 8.0,
    this.normalColor,
    this.activeColor,
  });

  @override
  State<LyraSplitter> createState() => _LyraSplitterState();
}

class _LyraSplitterState extends State<LyraSplitter> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final isActive = _isHovered || _isDragging;

    final dividerColor = isActive
        ? (widget.activeColor ?? tokens.primary.withValues(alpha: 0.8))
        : (widget.normalColor ?? tokens.border);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
          widget.onDragStart?.call();
        },
        onHorizontalDragUpdate: (details) {
          widget.onDelta?.call(details.delta.dx);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        onHorizontalDragCancel: () {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        onDoubleTap: widget.onDoubleTap,
        child: SizedBox(
          width: widget.hitWidth,
          height: double.infinity,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isActive ? 2.0 : 1.0,
              height: double.infinity,
              color: dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
