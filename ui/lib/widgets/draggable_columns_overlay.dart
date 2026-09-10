// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design_system/tokens/lyra_tokens.dart';

/// A desktop-grade draggable floating window overlay for column customization.
///
/// Features:
/// - Smooth dragging via [ValueNotifier<Offset>] without rebuilding parent views or table rows.
/// - Screen boundary clamping so the window never moves offscreen.
/// - Triple dismissal mechanisms: tap outside ([TapRegion]), Escape key ([Focus]), or close ('X') button.
/// - Refined Shadcn card styling matching Lyra's design tokens.
class DraggableColumnsOverlay extends StatelessWidget {
  final OverlayPortalController controller;
  final ValueNotifier<Offset> positionNotifier;
  final double cardWidth;
  final double estimatedCardHeight;
  final VoidCallback onReset;
  final VoidCallback? onClose;
  final Key? cardKey;
  final Key? headerKey;
  final Key? resetKey;
  final Key? closeKey;
  final Widget content;
  final Widget child;
  final LyraThemeTokens tokens;

  const DraggableColumnsOverlay({
    super.key,
    required this.controller,
    required this.positionNotifier,
    this.cardWidth = 270.0,
    this.estimatedCardHeight = 450.0,
    required this.onReset,
    this.onClose,
    this.cardKey,
    this.headerKey,
    this.resetKey,
    this.closeKey,
    required this.content,
    required this.child,
    required this.tokens,
  });

  /// Programmatically opens the overlay at [globalPosition], clamped within screen boundaries.
  static void showAt({
    required OverlayPortalController controller,
    required ValueNotifier<Offset> positionNotifier,
    required Offset globalPosition,
    required BuildContext context,
    double cardWidth = 270.0,
    double estimatedCardHeight = 450.0,
  }) {
    final size = MediaQuery.sizeOf(context);
    final maxX = math.max(8.0, size.width - cardWidth - 8.0);
    final maxY = math.max(8.0, size.height - estimatedCardHeight - 8.0);
    positionNotifier.value = Offset(
      globalPosition.dx.clamp(8.0, maxX),
      globalPosition.dy.clamp(8.0, maxY),
    );
    if (!controller.isShowing) {
      controller.show();
    }
  }

  void _show(Offset globalPosition, BuildContext context) {
    showAt(
      controller: controller,
      positionNotifier: positionNotifier,
      globalPosition: globalPosition,
      context: context,
      cardWidth: cardWidth,
      estimatedCardHeight: estimatedCardHeight,
    );
  }

  void _hide() {
    if (controller.isShowing) {
      controller.hide();
      onClose?.call();
    }
  }

  /// Default proxy decorator for [ReorderableListView] items inside the columns card.
  static Widget proxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
    LyraThemeTokens tokens,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: tokens.border, width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: controller,
      overlayChildBuilder: (overlayContext) {
        return ValueListenableBuilder<Offset>(
          valueListenable: positionNotifier,
          builder: (context, position, _) {
            final size = MediaQuery.sizeOf(context);
            final maxX = math.max(8.0, size.width - cardWidth - 8.0);
            final maxY = math.max(8.0, size.height - estimatedCardHeight - 8.0);
            final clampedX = position.dx.clamp(8.0, maxX);
            final clampedY = position.dy.clamp(8.0, maxY);

            return Stack(
              children: [
                Positioned(
                  left: clampedX,
                  top: clampedY,
                  child: RepaintBoundary(
                    child: TapRegion(
                      onTapOutside: (_) => _hide(),
                      child: Focus(
                        autofocus: true,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.escape) {
                            _hide();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            key: cardKey,
                            width: cardWidth,
                            constraints: BoxConstraints(
                              maxHeight: math.max(120.0, size.height - 32.0),
                            ),
                            decoration: BoxDecoration(
                              color: tokens.card,
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: tokens.border,
                                width: 1.0,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 16.0,
                                  offset: Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  blurRadius: 8.0,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 8.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Movable Header
                                GestureDetector(
                                  key: headerKey,
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: (details) {
                                    final current = positionNotifier.value;
                                    final nextX = current.dx + details.delta.dx;
                                    final nextY = current.dy + details.delta.dy;
                                    positionNotifier.value = Offset(
                                      nextX.clamp(8.0, maxX),
                                      nextY.clamp(8.0, maxY),
                                    );
                                  },
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.move,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0,
                                        vertical: 4.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'COLUMNS',
                                            style: LyraTypography.small(tokens)
                                                .copyWith(
                                                  fontSize: 11.0,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.8,
                                                  color: tokens.textMuted,
                                                ),
                                          ),
                                          const Spacer(),
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              key: resetKey,
                                              behavior: HitTestBehavior.opaque,
                                              onTap: onReset,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4.0,
                                                      vertical: 2.0,
                                                    ),
                                                child: Text(
                                                  'Reset',
                                                  style:
                                                      LyraTypography.small(
                                                        tokens,
                                                      ).copyWith(
                                                        fontSize: 11.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: tokens.textMuted,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8.0),
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              key: closeKey,
                                              behavior: HitTestBehavior.opaque,
                                              onTap: _hide,
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  2.0,
                                                ),
                                                child: Icon(
                                                  LucideIcons.x,
                                                  size: 14.0,
                                                  color: tokens.textMuted,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 1.0,
                                  color: tokens.border,
                                  margin: const EdgeInsets.only(
                                    top: 4.0,
                                    bottom: 6.0,
                                  ),
                                ),
                                Flexible(child: content),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (details) =>
              _show(details.globalPosition, context),
          onLongPressStart: (details) => _show(details.globalPosition, context),
          child: child,
        ),
      ),
    );
  }
}
