// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';
import '../factory/shadcn_factory.dart';

/// Facade data table widget delegating to the active Design System Factory.
///
/// Supports both static tabular data ([LyraTable]) and high-performance
/// virtualized lists with sticky headers ([LyraTable.builder]).
class LyraTable extends StatelessWidget {
  final bool _isVirtual;
  final List<Widget>? headers;
  final List<List<Widget>>? rows;
  final List<double>? columnWidths;
  final ValueChanged<int>? onRowTap;
  final EdgeInsetsGeometry? padding;

  // Virtual builder properties
  final Widget? header;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final double? itemExtent;
  final ScrollPhysics? physics;
  final ScrollController? scrollController;

  const LyraTable({
    super.key,
    required List<Widget> this.headers,
    required List<List<Widget>> this.rows,
    this.columnWidths,
    this.onRowTap,
    this.padding,
  }) : _isVirtual = false,
       header = null,
       itemCount = null,
       itemBuilder = null,
       itemExtent = null,
       physics = null,
       scrollController = null;

  const LyraTable.builder({
    super.key,
    required Widget this.header,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.itemExtent,
    this.padding,
    this.physics,
    this.scrollController,
  }) : _isVirtual = true,
       headers = null,
       rows = null,
       columnWidths = null,
       onRowTap = null;

  @override
  Widget build(BuildContext context) {
    final factory =
        LyraDesignSystemScope.maybeOf(context)?.factory ??
        const ShadcnFactory();
    if (_isVirtual) {
      return factory.createVirtualTable(
        key: key,
        header: header!,
        itemCount: itemCount!,
        itemBuilder: itemBuilder!,
        itemExtent: itemExtent,
        padding: padding,
        physics: physics,
        scrollController: scrollController,
      );
    }
    return factory.createTable(
      key: key,
      headers: headers!,
      rows: rows!,
      columnWidths: columnWidths,
      onRowTap: onRowTap,
      padding: padding,
    );
  }
}
