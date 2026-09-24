// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../contracts/lyra_contracts.dart';
import '../tokens/lyra_tokens.dart';
import 'lyra_design_system_factory.dart';
import 'lyra_design_system_scope.dart';

/// Shadcn implementation of the LyraDesignSystemFactory.
class ShadcnFactory extends LyraDesignSystemFactory {
  const ShadcnFactory();

  @override
  Widget createButton({
    Key? key,
    Widget? child,
    VoidCallback? onPressed,
    LyraButtonVariant variant = LyraButtonVariant.primary,
    LyraButtonSize size = LyraButtonSize.md,
    Widget? leading,
    Widget? trailing,
    MainAxisAlignment? mainAxisAlignment,
    CrossAxisAlignment? crossAxisAlignment,
    bool autofocus = false,
    FocusNode? focusNode,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
  }) {
    final shadSize = switch (size) {
      LyraButtonSize.sm => ShadButtonSize.sm,
      LyraButtonSize.md => ShadButtonSize.regular,
      LyraButtonSize.lg => ShadButtonSize.lg,
    };

    switch (variant) {
      case LyraButtonVariant.primary:
        return ShadButton(
          key: key,
          onPressed: onPressed,
          size: shadSize,
          leading: leading,
          trailing: trailing,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          autofocus: autofocus,
          focusNode: focusNode,
          width: width,
          height: height,
          padding: padding,
          child: child,
        );
      case LyraButtonVariant.secondary:
        return ShadButton.secondary(
          key: key,
          onPressed: onPressed,
          size: shadSize,
          leading: leading,
          trailing: trailing,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          autofocus: autofocus,
          focusNode: focusNode,
          width: width,
          height: height,
          padding: padding,
          child: child,
        );
      case LyraButtonVariant.outline:
        return ShadButton.outline(
          key: key,
          onPressed: onPressed,
          size: shadSize,
          leading: leading,
          trailing: trailing,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          autofocus: autofocus,
          focusNode: focusNode,
          width: width,
          height: height,
          padding: padding,
          child: child,
        );
      case LyraButtonVariant.ghost:
        return ShadButton.ghost(
          key: key,
          onPressed: onPressed,
          size: shadSize,
          leading: leading,
          trailing: trailing,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          autofocus: autofocus,
          focusNode: focusNode,
          width: width,
          height: height,
          padding: padding,
          child: child,
        );
      case LyraButtonVariant.destructive:
        return ShadButton.destructive(
          key: key,
          onPressed: onPressed,
          size: shadSize,
          leading: leading,
          trailing: trailing,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          autofocus: autofocus,
          focusNode: focusNode,
          width: width,
          height: height,
          padding: padding,
          child: child,
        );
      case LyraButtonVariant.link:
        return ShadButton.link(
          key: key,
          onPressed: onPressed,
          size: shadSize,
          leading: leading,
          trailing: trailing,
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          autofocus: autofocus,
          focusNode: focusNode,
          width: width,
          height: height,
          padding: padding,
          child: child,
        );
    }
  }

  @override
  Widget createCard({
    Key? key,
    Widget? title,
    Widget? description,
    Widget? child,
    Widget? footer,
    Widget? leading,
    Widget? trailing,
    EdgeInsetsGeometry? padding,
    LyraCardVariant variant = LyraCardVariant.defaultVariant,
    double? width,
    double? height,
    Color? backgroundColor,
    Border? border,
  }) {
    if (variant == LyraCardVariant.elevated) {
      return Builder(
        key: key,
        builder: (context) {
          final tokens =
              LyraDesignSystemScope.maybeOf(context)?.tokens ??
              LyraThemeTokens.dark();
          return ShadCard(
            title: title,
            description: description,
            footer: footer,
            leading: leading,
            trailing: trailing,
            padding: padding,
            width: width,
            height: height,
            backgroundColor: backgroundColor,
            border: border != null
                ? ShadBorder.all(
                    color: border.top.color,
                    width: border.top.width,
                  )
                : null,
            shadows: [
              BoxShadow(
                color: tokens.text.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            child: child,
          );
        },
      );
    }
    return ShadCard(
      key: key,
      title: title,
      description: description,
      footer: footer,
      leading: leading,
      trailing: trailing,
      padding: padding,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
      border: border != null
          ? ShadBorder.all(color: border.top.color, width: border.top.width)
          : null,
      shadows: null,
      child: child,
    );
  }

  @override
  Widget createInput({
    Key? key,
    String? initialValue,
    String? placeholder,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? leading,
    Widget? trailing,
    bool obscureText = false,
    bool enabled = true,
    bool autofocus = false,
    TextStyle? style,
    EdgeInsetsGeometry? padding,
  }) {
    return ShadInput(
      key: key,
      initialValue: initialValue,
      placeholder: placeholder != null ? Text(placeholder) : null,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      leading: leading,
      trailing: trailing,
      obscureText: obscureText,
      enabled: enabled,
      autofocus: autofocus,
      style: style,
      padding: padding,
    );
  }

  @override
  Widget createBadge({
    Key? key,
    required Widget child,
    LyraBadgeVariant variant = LyraBadgeVariant.defaultVariant,
    VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
  }) {
    switch (variant) {
      case LyraBadgeVariant.defaultVariant:
        return ShadBadge(
          key: key,
          onPressed: onPressed,
          padding: padding,
          child: child,
        );
      case LyraBadgeVariant.secondary:
        return ShadBadge.secondary(
          key: key,
          onPressed: onPressed,
          padding: padding,
          child: child,
        );
      case LyraBadgeVariant.outline:
        return ShadBadge.outline(
          key: key,
          onPressed: onPressed,
          padding: padding,
          child: child,
        );
      case LyraBadgeVariant.destructive:
        return ShadBadge.destructive(
          key: key,
          onPressed: onPressed,
          padding: padding,
          child: child,
        );
      case LyraBadgeVariant.success:
        return Builder(
          key: key,
          builder: (context) {
            final tokens =
                LyraDesignSystemScope.maybeOf(context)?.tokens ??
                LyraThemeTokens.dark();
            return ShadBadge(
              onPressed: onPressed,
              padding: padding,
              backgroundColor: tokens.success,
              foregroundColor: tokens.successForeground,
              child: child,
            );
          },
        );
    }
  }

  @override
  Widget createTable({
    Key? key,
    required List<Widget> headers,
    required List<List<Widget>> rows,
    List<double>? columnWidths,
    ValueChanged<int>? onRowTap,
    EdgeInsetsGeometry? padding,
  }) {
    return ShadTable.list(
      key: key,
      header: headers
          .map(
            (h) => ShadTableCell.header(
              alignment: AlignmentDirectional.centerStart,
              child: h,
            ),
          )
          .toList(),
      onRowTap: onRowTap,
      children: rows
          .map(
            (row) => row
                .map(
                  (cell) => ShadTableCell(
                    alignment: AlignmentDirectional.centerStart,
                    child: cell,
                  ),
                )
                .toList(),
          )
          .toList(),
    );
  }

  @override
  Widget createDialog({
    Key? key,
    Widget? title,
    Widget? description,
    Widget? child,
    List<Widget>? actions,
    VoidCallback? onClose,
  }) {
    return ShadDialog(
      key: key,
      title: title,
      description: description,
      actions: actions ?? const [],
      closeIcon: onClose != null
          ? ShadIconButton.ghost(
              icon: const Icon(LucideIcons.x, size: 16),
              width: 20,
              height: 20,
              padding: EdgeInsets.zero,
              onPressed: onClose,
            )
          : null,
      child: child,
    );
  }

  @override
  Widget createSwitch({
    Key? key,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool enabled = true,
    FocusNode? focusNode,
    bool autofocus = false,
  }) {
    if (autofocus) {
      if (focusNode != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusNode.requestFocus();
        });
      } else {
        return _AutofocusSwitchWrapper(
          switchKey: key,
          value: value,
          onChanged: onChanged,
          enabled: enabled,
        );
      }
    }
    return _SmoothShadSwitch(
      switchKey: key,
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      focusNode: focusNode,
    );
  }

  @override
  Widget createCheckbox({
    Key? key,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool enabled = true,
    FocusNode? focusNode,
    Widget? label,
    Widget? sublabel,
    EdgeInsetsGeometry? padding,
  }) {
    return ShadCheckbox(
      key: key,
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      focusNode: focusNode,
      label: label,
      sublabel: sublabel,
      padding: padding,
    );
  }

  @override
  Widget createTooltip({
    Key? key,
    required Widget child,
    required String message,
    FocusNode? focusNode,
    Duration? waitDuration,
    Duration? showDuration,
  }) {
    return Tooltip(
      key: key,
      message: message,
      waitDuration: waitDuration,
      showDuration: showDuration,
      child: child,
    );
  }

  @override
  Widget createSkeleton({
    Key? key,
    double? width,
    double? height,
    BorderRadiusGeometry? borderRadius,
  }) {
    return _ShadSkeleton(
      skeletonKey: key,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget createVirtualTable({
    Key? key,
    required Widget header,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    double? itemExtent,
    EdgeInsetsGeometry? padding,
    ScrollPhysics? physics,
    ScrollController? scrollController,
  }) {
    return Column(
      key: key,
      children: [
        header,
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            physics: physics,
            padding:
                padding ?? const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
            itemCount: itemCount,
            itemExtent: itemExtent,
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

class _ShadSkeleton extends StatefulWidget {
  final Key? skeletonKey;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;

  const _ShadSkeleton({
    this.skeletonKey,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<_ShadSkeleton> createState() => _ShadSkeletonState();
}

class _ShadSkeletonState extends State<_ShadSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.35,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens =
        LyraDesignSystemScope.maybeOf(context)?.tokens ??
        LyraThemeTokens.dark();
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          key: widget.skeletonKey,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: tokens.muted.withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4.0),
          ),
        );
      },
    );
  }
}

class _AutofocusSwitchWrapper extends StatefulWidget {
  final Key? switchKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const _AutofocusSwitchWrapper({
    this.switchKey,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<_AutofocusSwitchWrapper> createState() =>
      _AutofocusSwitchWrapperState();
}

class _AutofocusSwitchWrapperState extends State<_AutofocusSwitchWrapper> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SmoothShadSwitch(
      switchKey: widget.switchKey,
      value: widget.value,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      focusNode: _focusNode,
    );
  }
}

class _SmoothShadSwitch extends StatelessWidget {
  final Key? switchKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;

  const _SmoothShadSwitch({
    this.switchKey,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final checkedColor = theme.colorScheme.primary;
    final uncheckedColor = theme.colorScheme.input;
    final thumbColor = isDark
        ? theme.colorScheme.background
        : const Color(0xFFFFFFFF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: !enabled
            ? (value
                  ? checkedColor.withValues(alpha: 0.5)
                  : uncheckedColor.withValues(alpha: 0.5))
            : (value ? checkedColor : uncheckedColor),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ShadSwitch(
        key: switchKey,
        value: value,
        onChanged: onChanged,
        enabled: enabled,
        focusNode: focusNode,
        duration: const Duration(milliseconds: 180),
        checkedTrackColor: const Color(0x00000000),
        uncheckedTrackColor: const Color(0x00000000),
        thumbColor: thumbColor,
      ),
    );
  }
}
