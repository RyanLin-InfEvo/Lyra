// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import '../contracts/lyra_contracts.dart';

/// Abstract factory interface defining the contract for all Swappable Design Systems in Lyra.
abstract class LyraDesignSystemFactory {
  const LyraDesignSystemFactory();

  /// Creates a button with the given configuration.
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
  });

  /// Creates a card container with optional header, body, and footer.
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
  });

  /// Creates a text input field.
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
  });

  /// Creates a badge for status or metadata tags.
  Widget createBadge({
    Key? key,
    required Widget child,
    LyraBadgeVariant variant = LyraBadgeVariant.defaultVariant,
    VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
  });

  /// Creates a high density data table with header and rows.
  Widget createTable({
    Key? key,
    required List<Widget> headers,
    required List<List<Widget>> rows,
    List<double>? columnWidths,
    ValueChanged<int>? onRowTap,
    EdgeInsetsGeometry? padding,
  });

  /// Creates a modal dialog container.
  Widget createDialog({
    Key? key,
    Widget? title,
    Widget? description,
    Widget? child,
    List<Widget>? actions,
    VoidCallback? onClose,
  });
}
