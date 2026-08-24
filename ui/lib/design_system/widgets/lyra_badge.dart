// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../contracts/lyra_contracts.dart';
import '../factory/lyra_design_system_scope.dart';

/// Facade badge widget delegating to the active Design System Factory.
class LyraBadge extends StatelessWidget {
  final Widget child;
  final LyraBadgeVariant variant;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;

  const LyraBadge({
    super.key,
    required this.child,
    this.variant = LyraBadgeVariant.defaultVariant,
    this.onPressed,
    this.padding,
  });

  const LyraBadge.secondary({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
  }) : variant = LyraBadgeVariant.secondary;

  const LyraBadge.outline({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
  }) : variant = LyraBadgeVariant.outline;

  const LyraBadge.destructive({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
  }) : variant = LyraBadgeVariant.destructive;

  const LyraBadge.success({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
  }) : variant = LyraBadgeVariant.success;

  @override
  Widget build(BuildContext context) {
    final factory = LyraDesignSystemScope.of(context).factory;
    return factory.createBadge(
      key: key,
      variant: variant,
      onPressed: onPressed,
      padding: padding,
      child: child,
    );
  }
}
