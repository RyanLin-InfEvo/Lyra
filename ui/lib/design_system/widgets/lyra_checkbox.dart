// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';
import '../factory/shadcn_factory.dart';

/// Facade checkbox widget delegating to the active Design System Factory.
class LyraCheckbox extends StatelessWidget {
  final Key? _targetKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;
  final Widget? label;
  final Widget? sublabel;
  final EdgeInsetsGeometry? padding;

  const LyraCheckbox({
    Key? key,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.label,
    this.sublabel,
    this.padding,
  }) : _targetKey = key,
       super(key: null);

  @override
  Widget build(BuildContext context) {
    final factory =
        LyraDesignSystemScope.maybeOf(context)?.factory ??
        const ShadcnFactory();
    return factory.createCheckbox(
      key: _targetKey,
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      focusNode: focusNode,
      label: label,
      sublabel: sublabel,
      padding: padding,
    );
  }
}
