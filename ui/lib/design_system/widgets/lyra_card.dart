// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../contracts/lyra_contracts.dart';
import '../factory/lyra_design_system_scope.dart';

/// Facade card container widget delegating to the active Design System Factory.
class LyraCard extends StatelessWidget {
  final Widget? title;
  final Widget? description;
  final Widget? child;
  final Widget? footer;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final LyraCardVariant variant;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Border? border;

  const LyraCard({
    super.key,
    this.title,
    this.description,
    this.child,
    this.footer,
    this.leading,
    this.trailing,
    this.padding,
    this.variant = LyraCardVariant.defaultVariant,
    this.width,
    this.height,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final factory = LyraDesignSystemScope.of(context).factory;
    return factory.createCard(
      key: key,
      title: title,
      description: description,
      child: child,
      footer: footer,
      leading: leading,
      trailing: trailing,
      padding: padding,
      variant: variant,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
      border: border,
    );
  }
}
