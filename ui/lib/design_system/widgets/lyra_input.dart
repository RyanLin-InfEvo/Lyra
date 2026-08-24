// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';

/// Facade text input widget delegating to the active Design System Factory.
class LyraInput extends StatelessWidget {
  final String? initialValue;
  final String? placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? leading;
  final Widget? trailing;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const LyraInput({
    super.key,
    this.initialValue,
    this.placeholder,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.leading,
    this.trailing,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.style,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final factory = LyraDesignSystemScope.of(context).factory;
    return factory.createInput(
      key: key,
      initialValue: initialValue,
      placeholder: placeholder,
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
}
