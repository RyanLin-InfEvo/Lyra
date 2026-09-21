// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';
import '../factory/shadcn_factory.dart';

/// Facade tooltip widget delegating to the active Design System Factory.
class LyraTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final FocusNode? focusNode;
  final Duration? waitDuration;
  final Duration? showDuration;

  const LyraTooltip({
    super.key,
    required this.message,
    required this.child,
    this.focusNode,
    this.waitDuration,
    this.showDuration,
  });

  @override
  Widget build(BuildContext context) {
    final factory =
        LyraDesignSystemScope.maybeOf(context)?.factory ??
        const ShadcnFactory();
    return factory.createTooltip(
      key: key,
      message: message,
      focusNode: focusNode,
      waitDuration: waitDuration,
      showDuration: showDuration,
      child: child,
    );
  }
}
