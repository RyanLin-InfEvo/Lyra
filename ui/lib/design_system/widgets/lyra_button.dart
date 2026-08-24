// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../contracts/lyra_contracts.dart';
import '../factory/lyra_design_system_scope.dart';

/// Facade button widget delegating to the active Design System Factory.
class LyraButton extends StatelessWidget {
  final Widget? child;
  final VoidCallback? onPressed;
  final LyraButtonVariant variant;
  final LyraButtonSize size;
  final Widget? leading;
  final Widget? trailing;
  final MainAxisAlignment? mainAxisAlignment;
  final CrossAxisAlignment? crossAxisAlignment;
  final bool autofocus;
  final FocusNode? focusNode;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const LyraButton({
    super.key,
    this.child,
    this.onPressed,
    this.variant = LyraButtonVariant.primary,
    this.size = LyraButtonSize.md,
    this.leading,
    this.trailing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.height,
    this.padding,
  });

  const LyraButton.secondary({
    super.key,
    this.child,
    this.onPressed,
    this.size = LyraButtonSize.md,
    this.leading,
    this.trailing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.height,
    this.padding,
  }) : variant = LyraButtonVariant.secondary;

  const LyraButton.outline({
    super.key,
    this.child,
    this.onPressed,
    this.size = LyraButtonSize.md,
    this.leading,
    this.trailing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.height,
    this.padding,
  }) : variant = LyraButtonVariant.outline;

  const LyraButton.ghost({
    super.key,
    this.child,
    this.onPressed,
    this.size = LyraButtonSize.md,
    this.leading,
    this.trailing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.height,
    this.padding,
  }) : variant = LyraButtonVariant.ghost;

  const LyraButton.destructive({
    super.key,
    this.child,
    this.onPressed,
    this.size = LyraButtonSize.md,
    this.leading,
    this.trailing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.height,
    this.padding,
  }) : variant = LyraButtonVariant.destructive;

  const LyraButton.link({
    super.key,
    this.child,
    this.onPressed,
    this.size = LyraButtonSize.md,
    this.leading,
    this.trailing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.height,
    this.padding,
  }) : variant = LyraButtonVariant.link;

  @override
  Widget build(BuildContext context) {
    final factory = LyraDesignSystemScope.of(context).factory;
    return factory.createButton(
      key: key,
      onPressed: onPressed,
      variant: variant,
      size: size,
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
