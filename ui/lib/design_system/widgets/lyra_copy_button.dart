// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../factory/lyra_design_system_scope.dart';
import '../tokens/lyra_tokens.dart';

/// Interactive copy-to-clipboard button with micro-interactions:
/// - Smooth animated transition from copy icon to success checkmark
/// - Highlighted border and background box on hover ("反白框")
/// - Optional tooltip support ("Copy" / "Copied")
/// - Both compact icon-only and labeled variants
/// - Clean timer disposal to prevent memory/controller leaks
class LyraCopyButton extends StatefulWidget {
  /// The text content to copy to the system clipboard.
  final String text;

  /// Label shown in idle state when [showLabel] is true. Defaults to 'Copy'.
  final String? label;

  /// Label shown in copied state when [showCopiedLabel] is true. Defaults to 'Copied'.
  final String? copiedLabel;

  /// Whether to display [label] beside the icon in the idle state.
  final bool showLabel;

  /// Whether to display [copiedLabel] beside the checkmark in the copied state.
  final bool showCopiedLabel;

  /// Optional tooltip message shown when hovering in the idle state.
  final String? tooltip;

  /// Optional tooltip message shown when hovering in the copied state.
  final String? copiedTooltip;

  /// Size of the copy/check icon in logical pixels.
  final double iconSize;

  /// Optional fixed button footprint size in logical pixels for icon mode.
  /// Defaults to 24.0 in icon-only mode.
  final double? size;

  /// Padding surrounding the button content.
  final EdgeInsetsGeometry? padding;

  /// Border radius for the button background and highlight outline.
  final BorderRadius? borderRadius;

  /// Duration to display the copied/success state before reverting.
  final Duration feedbackDuration;

  /// Optional callback invoked after clipboard copy completes.
  final VoidCallback? onCopied;

  /// Optional external [FocusNode].
  final FocusNode? focusNode;

  /// Default compact copy button.
  ///
  /// In the idle state, shows only the copy icon (with tooltip).
  /// When copied, smoothly transitions to the green checkmark with a constant, rock-solid footprint.
  const LyraCopyButton({
    super.key,
    required this.text,
    this.label,
    this.copiedLabel = 'Copied',
    this.showLabel = false,
    this.showCopiedLabel = false,
    this.tooltip = 'Copy',
    this.copiedTooltip = 'Copied',
    this.iconSize = 13.0,
    this.size = 24.0,
    this.padding,
    this.borderRadius,
    this.feedbackDuration = const Duration(milliseconds: 1800),
    this.onCopied,
    this.focusNode,
  });

  /// Explicit icon-only compact copy button.
  ///
  /// Maintains a fixed compact footprint in both idle and copied states.
  const LyraCopyButton.icon({
    super.key,
    required this.text,
    this.showCopiedLabel = false,
    this.tooltip = 'Copy',
    this.copiedTooltip = 'Copied',
    this.iconSize = 13.0,
    this.size = 24.0,
    this.padding,
    this.borderRadius,
    this.feedbackDuration = const Duration(milliseconds: 1800),
    this.onCopied,
    this.focusNode,
  }) : label = null,
       copiedLabel = 'Copied',
       showLabel = false;

  /// Labeled copy button showing text beside the icon.
  ///
  /// Transitions between [label] ('Copy') and [copiedLabel] ('Copied').
  const LyraCopyButton.labeled({
    super.key,
    required this.text,
    this.label = 'Copy',
    this.copiedLabel = 'Copied',
    this.showLabel = true,
    this.showCopiedLabel = true,
    this.tooltip,
    this.copiedTooltip,
    this.iconSize = 13.0,
    this.size = 24.0,
    this.padding,
    this.borderRadius,
    this.feedbackDuration = const Duration(milliseconds: 1800),
    this.onCopied,
    this.focusNode,
  });

  @override
  State<LyraCopyButton> createState() => _LyraCopyButtonState();
}

class _LyraCopyButtonState extends State<LyraCopyButton> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isCopied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LyraCopyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _resetTimer?.cancel();
      _isCopied = false;
    }
  }

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;

    _resetTimer?.cancel();
    setState(() {
      _isCopied = true;
    });

    widget.onCopied?.call();

    _resetTimer = Timer(widget.feedbackDuration, () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final isHoveredOrFocused = _isHovered || _isFocused;

    final Color backgroundColor;
    final Border border;

    if (_isCopied) {
      backgroundColor = tokens.success.withValues(alpha: 0.12);
      border = Border.all(
        color: tokens.success.withValues(alpha: 0.5),
        width: 1.0,
      );
    } else if (isHoveredOrFocused) {
      backgroundColor = tokens.secondary.withValues(alpha: 0.5);
      border = Border.all(
        color: tokens.text.withValues(alpha: 0.25),
        width: 1.0,
      );
    } else {
      backgroundColor = const Color(0x00000000);
      border = Border.all(color: const Color(0x00000000), width: 1.0);
    }

    final isShowingLabel = _isCopied
        ? (widget.showCopiedLabel && widget.copiedLabel != null)
        : (widget.showLabel && widget.label != null);

    final isIconOnly = !widget.showLabel && !widget.showCopiedLabel;
    final currentLabel = _isCopied ? widget.copiedLabel : widget.label;
    final targetSize = widget.size ?? 24.0;

    final Widget content;
    if (isShowingLabel && currentLabel != null) {
      content = Row(
        key: ValueKey<bool>(_isCopied),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isCopied ? LucideIcons.check : LucideIcons.copy,
            size: widget.iconSize,
            color: _isCopied
                ? tokens.success
                : (isHoveredOrFocused ? tokens.text : tokens.textMuted),
          ),
          const SizedBox(width: 4.0),
          Text(
            currentLabel,
            style: LyraTypography.small(tokens).copyWith(
              color: _isCopied
                  ? tokens.success
                  : (isHoveredOrFocused ? tokens.text : tokens.textMuted),
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      content = Icon(
        _isCopied ? LucideIcons.check : LucideIcons.copy,
        key: ValueKey<bool>(_isCopied),
        size: widget.iconSize,
        color: _isCopied
            ? tokens.success
            : (isHoveredOrFocused ? tokens.text : tokens.textMuted),
      );
    }

    final switcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      child: content,
    );

    final defaultPadding = isShowingLabel
        ? const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0)
        : (isIconOnly ? EdgeInsets.zero : const EdgeInsets.all(4.0));

    final container = AnimatedContainer(
      duration: LyraAnimation.fast,
      curve: LyraAnimation.defaultCurve,
      width: isIconOnly ? targetSize : null,
      height: targetSize,
      alignment: Alignment.center,
      padding: widget.padding ?? defaultPadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        borderRadius: widget.borderRadius ?? LyraRadius.smRadius,
      ),
      child: switcher,
    );

    final String? activeTooltip = _isCopied
        ? (widget.copiedTooltip ?? widget.tooltip)
        : widget.tooltip;

    Widget result = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            _handleCopy();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleCopy,
          child: container,
        ),
      ),
    );

    if (activeTooltip != null && activeTooltip.isNotEmpty) {
      result = Tooltip(
        message: activeTooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: result,
      );
    }

    return result;
  }
}
