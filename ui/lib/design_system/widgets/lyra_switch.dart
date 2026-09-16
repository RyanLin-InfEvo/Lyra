// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import '../factory/lyra_design_system_scope.dart';

/// Swappable design system switch widget.
class LyraSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  const LyraSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return LyraDesignSystemScope.of(context).factory.createSwitch(
      key: key,
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}
