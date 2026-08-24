// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../contracts/lyra_contracts.dart';
import '../tokens/lyra_tokens.dart';
import 'lyra_design_system_factory.dart';

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
        return ShadBadge(
          key: key,
          onPressed: onPressed,
          padding: padding,
          backgroundColor: LyraColors.emerald600,
          foregroundColor: const Color(0xFFFFFFFF),
          child: child,
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
      child: child,
    );
  }
}
