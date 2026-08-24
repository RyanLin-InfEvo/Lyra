// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';

/// Facade dialog container widget delegating to the active Design System Factory.
class LyraDialog extends StatelessWidget {
  final Widget? title;
  final Widget? description;
  final Widget? child;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  const LyraDialog({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final factory = LyraDesignSystemScope.of(context).factory;
    return factory.createDialog(
      key: key,
      title: title,
      description: description,
      child: child,
      actions: actions,
      onClose: onClose,
    );
  }
}
