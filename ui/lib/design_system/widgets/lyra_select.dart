// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart' show Colors, Material, Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../factory/lyra_design_system_scope.dart';
import '../tokens/lyra_tokens.dart';

/// An individual selectable option item in [LyraSelect].
class LyraSelectItem<T> {
  final T value;
  final String label;
  final Widget? leading;
  final Widget? trailing;

  const LyraSelectItem({
    required this.value,
    required this.label,
    this.leading,
    this.trailing,
  });
}

/// A shared, reusable dropdown select component adhering to Apple HIG
/// and the Lyra Design System.
///
/// Features smooth entry animations (fade + scale), hover feedback,
/// keyboard navigation (Escape to dismiss), click-outside dismissal via [TapRegion],
/// and crisp dark/light theme token styling.
class LyraSelect<T> extends StatefulWidget {
  final T? value;
  final List<LyraSelectItem<T>> items;
  final ValueChanged<T>? onChanged;
  final String? placeholder;
  final String? tooltip;
  final Widget Function(BuildContext context, LyraSelectItem<T>? selectedItem)?
  triggerBuilder;
  final double? width;
  final double? popoverWidth;
  final double maxHeight;
  final bool enabled;
  final bool showLeadingInTrigger;

  const LyraSelect({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.placeholder,
    this.tooltip,
    this.triggerBuilder,
    this.width,
    this.popoverWidth,
    this.maxHeight = 260.0,
    this.enabled = true,
    this.showLeadingInTrigger = false,
  });

  @override
  State<LyraSelect<T>> createState() => _LyraSelectState<T>();
}

class _LyraSelectState<T> extends State<LyraSelect<T>> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final Object _tapRegionGroupId = Object();
  double _triggerWidth = 0.0;
  bool _isHovered = false;
  bool _isFocused = false;

  void _open() {
    if (!widget.enabled || _overlayController.isShowing) return;
    _focusNode.unfocus();
    _overlayController.show();
  }

  void _close() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
      if (widget.enabled && mounted) {
        _focusNode.requestFocus();
      }
    }
  }

  void _toggle() {
    if (_overlayController.isShowing) {
      _close();
    } else {
      _open();
    }
  }

  void _handleTap() {
    if (!widget.enabled) return;
    _toggle();
  }

  @override
  void didUpdateWidget(covariant LyraSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _close();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final selectedItem = widget.items
        .where((i) => i.value == widget.value)
        .firstOrNull;

    Widget trigger;
    if (widget.triggerBuilder != null) {
      trigger = MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: widget.triggerBuilder!(context, selectedItem),
        ),
      );
    } else {
      trigger = _buildDefaultTrigger(tokens, selectedItem);
    }

    if (widget.tooltip != null) {
      trigger = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: trigger,
      );
    }

    // Wrap trigger in a Focus node so it can be focused with Tab
    trigger = Focus(
      focusNode: _focusNode,
      canRequestFocus: widget.enabled,
      onFocusChange: (focused) {
        if (mounted) setState(() => _isFocused = focused);
      },
      onKeyEvent: (node, event) {
        if (!widget.enabled) return KeyEventResult.ignored;
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape &&
              _overlayController.isShowing) {
            _close();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (!_overlayController.isShowing) {
              _open();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: trigger,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          final effectiveWidth =
              widget.popoverWidth ??
              ((_triggerWidth > 0 && _triggerWidth.isFinite)
                  ? _triggerWidth
                  : 200.0);

          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4.0),
            child: Align(
              alignment: Alignment.topLeft,
              child: _SelectMenuOverlay<T>(
                tapRegionGroupId: _tapRegionGroupId,
                items: widget.items,
                selectedValue: widget.value,
                width: effectiveWidth,
                maxHeight: widget.maxHeight,
                tokens: tokens,
                onSelect: (val) {
                  widget.onChanged?.call(val);
                  _close();
                },
                onClose: _close,
              ),
            ),
          );
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            _triggerWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : (widget.popoverWidth ?? 200.0);
            return TapRegion(groupId: _tapRegionGroupId, child: trigger);
          },
        ),
      ),
    );
  }

  Widget _buildDefaultTrigger(
    LyraThemeTokens tokens,
    LyraSelectItem<T>? selectedItem,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _triggerWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.popoverWidth ?? 200.0);

        return MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) {
            if (mounted && widget.enabled) setState(() => _isHovered = true);
          },
          onExit: (_) {
            if (mounted && widget.enabled) setState(() => _isHovered = false);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: Container(
              width: widget.width,
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: (_isHovered || _isFocused)
                    ? tokens.secondary
                    : tokens.secondary.withValues(alpha: 0.4),
                borderRadius: LyraRadius.smRadius,
                border: Border.all(
                  color: (_isHovered || _isFocused)
                      ? tokens.border
                      : tokens.border.withValues(alpha: 0.6),
                  width: _isFocused ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showLeadingInTrigger &&
                          selectedItem?.leading != null) ...[
                        selectedItem!.leading!,
                        const SizedBox(width: 8.0),
                      ],
                      Text(
                        selectedItem?.label ?? widget.placeholder ?? '',
                        style: LyraTypography.p(
                          tokens,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 13.0),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6.0),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 14.0,
                    color: tokens.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectMenuOverlay<T> extends StatefulWidget {
  final Object tapRegionGroupId;
  final List<LyraSelectItem<T>> items;
  final T? selectedValue;
  final double width;
  final double maxHeight;
  final LyraThemeTokens tokens;
  final ValueChanged<T> onSelect;
  final VoidCallback onClose;

  const _SelectMenuOverlay({
    required this.tapRegionGroupId,
    required this.items,
    required this.selectedValue,
    required this.width,
    required this.maxHeight,
    required this.tokens,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_SelectMenuOverlay<T>> createState() => _SelectMenuOverlayState<T>();
}

class _SelectMenuOverlayState<T> extends State<_SelectMenuOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  final ScrollController _scrollController = ScrollController();
  late int _focusedIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(_fadeAnim);
    _animController.forward();

    final selectedIdx = widget.items.indexWhere(
      (i) => i.value == widget.selectedValue,
    );
    _focusedIndex = selectedIdx >= 0 ? selectedIdx : 0;
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _moveFocus(int delta) {
    if (widget.items.isEmpty) return;
    setState(() {
      final next = _focusedIndex + delta;
      _focusedIndex = next.clamp(0, widget.items.length - 1);
    });

    if (_scrollController.hasClients) {
      final itemHeight = 36.0;
      final targetOffset = _focusedIndex * itemHeight;
      if (targetOffset < _scrollController.offset) {
        _scrollController.jumpTo(targetOffset);
      } else if (targetOffset + itemHeight >
          _scrollController.offset + widget.maxHeight) {
        _scrollController.jumpTo(targetOffset + itemHeight - widget.maxHeight);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return TapRegion(
      groupId: widget.tapRegionGroupId,
      onTapOutside: (_) => widget.onClose(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              widget.onClose();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _moveFocus(1);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _moveFocus(-1);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              if (_focusedIndex >= 0 && _focusedIndex < widget.items.length) {
                widget.onSelect(widget.items[_focusedIndex].value);
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            alignment: Alignment.topLeft,
            scale: _scaleAnim,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: widget.width,
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: LyraRadius.mdRadius,
                  border: Border.all(color: tokens.border, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.text.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: LyraRadius.mdRadius,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = item.value == widget.selectedValue;
                      final isFocused = index == _focusedIndex;
                      return _SelectItemTile<T>(
                        item: item,
                        isSelected: isSelected,
                        isFocused: isFocused,
                        tokens: tokens,
                        onHover: () {
                          if (_focusedIndex != index) {
                            setState(() => _focusedIndex = index);
                          }
                        },
                        onTap: () => widget.onSelect(item.value),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectItemTile<T> extends StatefulWidget {
  final LyraSelectItem<T> item;
  final bool isSelected;
  final bool isFocused;
  final LyraThemeTokens tokens;
  final VoidCallback onTap;
  final VoidCallback? onHover;

  const _SelectItemTile({
    required this.item,
    required this.isSelected,
    this.isFocused = false,
    required this.tokens,
    required this.onTap,
    this.onHover,
  });

  @override
  State<_SelectItemTile<T>> createState() => _SelectItemTileState<T>();
}

class _SelectItemTileState<T> extends State<_SelectItemTile<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final item = widget.item;
    final isSelected = widget.isSelected;
    final isFocused = widget.isFocused;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
        widget.onHover?.call();
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: (_isHovered || isFocused)
              ? tokens.accent.withValues(alpha: 0.15)
              : (isSelected
                    ? tokens.secondary.withValues(alpha: 0.5)
                    : Colors.transparent),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: Row(
            children: [
              if (item.leading != null) ...[
                item.leading!,
                const SizedBox(width: 8.0),
              ],
              Expanded(
                child: Text(
                  item.label,
                  style: LyraTypography.p(tokens).copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? tokens.primary : tokens.text,
                    fontSize: 13.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.trailing != null) ...[
                const SizedBox(width: 8.0),
                item.trailing!,
              ] else if (isSelected) ...[
                const SizedBox(width: 8.0),
                Icon(LucideIcons.check, size: 14.0, color: tokens.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
