// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';

/// Facade data table widget delegating to the active Design System Factory.
class LyraTable extends StatelessWidget {
  final List<Widget> headers;
  final List<List<Widget>> rows;
  final List<double>? columnWidths;
  final ValueChanged<int>? onRowTap;
  final EdgeInsetsGeometry? padding;

  const LyraTable({
    super.key,
    required this.headers,
    required this.rows,
    this.columnWidths,
    this.onRowTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final factory = LyraDesignSystemScope.of(context).factory;
    return factory.createTable(
      key: key,
      headers: headers,
      rows: rows,
      columnWidths: columnWidths,
      onRowTap: onRowTap,
      padding: padding,
    );
  }
}
