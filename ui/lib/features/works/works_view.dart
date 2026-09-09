// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart'
    show
        ClampingScrollPhysics,
        Colors,
        Material,
        ReorderableDragStartListener,
        ReorderableListView;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../widgets/draggable_columns_overlay.dart';
import '../models/work.dart';

/// Columns available in the Musical Works table.
class WorkColumn {
  final String name;
  final String headerLabel;
  final String label;
  final double? width;
  final int? flex;
  final bool isMandatory;
  final bool defaultVisible;

  const WorkColumn._({
    required this.name,
    required this.headerLabel,
    required this.label,
    this.width,
    this.flex,
    this.isMandatory = false,
    this.defaultVisible = true,
  });

  static const WorkColumn index = WorkColumn._(
    name: 'index',
    headerLabel: '#',
    label: 'Track Number / Index',
    width: 40.0,
  );

  static const WorkColumn title = WorkColumn._(
    name: 'title',
    headerLabel: 'COMPOSITION TITLE',
    label: 'Title',
    flex: 5,
    isMandatory: true,
  );

  static const WorkColumn composer = WorkColumn._(
    name: 'composer',
    headerLabel: 'COMPOSER',
    label: 'Composer',
    flex: 4,
  );

  static const WorkColumn lyricist = WorkColumn._(
    name: 'lyricist',
    headerLabel: 'LYRICIST',
    label: 'Lyricist',
    flex: 3,
    defaultVisible: false,
  );

  static const WorkColumn movement = WorkColumn._(
    name: 'movement',
    headerLabel: 'MOVEMENT',
    label: 'Movement',
    flex: 3,
    defaultVisible: false,
  );

  static const WorkColumn date = WorkColumn._(
    name: 'date',
    headerLabel: 'COMPOSITION YEAR / DATE',
    label: 'Year / Date',
    flex: 3,
  );

  static const WorkColumn iswc = WorkColumn._(
    name: 'iswc',
    headerLabel: 'ISWC',
    label: 'ISWC',
    flex: 3,
  );

  static const WorkColumn musicbrainzId = WorkColumn._(
    name: 'musicbrainzId',
    headerLabel: 'MUSICBRAINZ ID',
    label: 'MusicBrainz ID',
    flex: 3,
  );

  static const List<WorkColumn> values = [
    index,
    title,
    composer,
    lyricist,
    movement,
    date,
    iswc,
    musicbrainzId,
  ];

  static final Set<WorkColumn> defaultVisibleColumns = {
    index,
    title,
    composer,
    date,
    iswc,
    musicbrainzId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkColumn &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'WorkColumn.$name';
}

/// High-density table view of Tier 1 musical composition works.
class WorksView extends StatefulWidget {
  final List<Work> works;
  final ValueChanged<Work>? onWorkSelected;
  final Set<WorkColumn>? visibleColumns;
  final ValueChanged<Set<WorkColumn>>? onVisibleColumnsChanged;
  final List<WorkColumn>? columnOrder;
  final ValueChanged<List<WorkColumn>>? onColumnOrderChanged;

  const WorksView({
    super.key,
    required this.works,
    this.onWorkSelected,
    this.visibleColumns,
    this.onVisibleColumnsChanged,
    this.columnOrder,
    this.onColumnOrderChanged,
  });

  @override
  State<WorksView> createState() => _WorksViewState();
}

class _WorksViewState extends State<WorksView> {
  late List<WorkColumn> _internalColumnOrder;
  late Set<WorkColumn> _internalVisibleColumns;
  late final OverlayPortalController _columnsOverlayController;
  late final ValueNotifier<Offset> _columnsPositionNotifier;

  @override
  void initState() {
    super.initState();
    _columnsOverlayController = OverlayPortalController();
    _columnsPositionNotifier = ValueNotifier<Offset>(Offset.zero);
    _internalColumnOrder = _normalizeColumnOrder(widget.columnOrder);
    _internalVisibleColumns = _normalizeVisibleColumns(widget.visibleColumns);
  }

  @override
  void didUpdateWidget(covariant WorksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.columnOrder != null &&
        widget.columnOrder != oldWidget.columnOrder) {
      _internalColumnOrder = _normalizeColumnOrder(widget.columnOrder);
    }
    if (widget.visibleColumns != null &&
        widget.visibleColumns != oldWidget.visibleColumns) {
      _internalVisibleColumns = _normalizeVisibleColumns(widget.visibleColumns);
    }
  }

  @override
  void dispose() {
    _columnsPositionNotifier.dispose();
    super.dispose();
  }

  static List<WorkColumn> _normalizeColumnOrder(List<WorkColumn>? order) {
    if (order == null || order.isEmpty) {
      return List<WorkColumn>.from(WorkColumn.values);
    }
    final normalized = <WorkColumn>[];
    for (final col in order) {
      if (WorkColumn.values.contains(col) && !normalized.contains(col)) {
        normalized.add(col);
      }
    }
    for (final col in WorkColumn.values) {
      if (!normalized.contains(col)) {
        normalized.add(col);
      }
    }
    return normalized;
  }

  static Set<WorkColumn> _normalizeVisibleColumns(Set<WorkColumn>? visible) {
    if (visible == null || visible.isEmpty) {
      return Set<WorkColumn>.from(WorkColumn.defaultVisibleColumns);
    }
    final normalized = Set<WorkColumn>.from(visible);
    for (final col in WorkColumn.values) {
      if (col.isMandatory) {
        normalized.add(col);
      }
    }
    return normalized;
  }

  List<WorkColumn> get _effectiveColumnOrder => _internalColumnOrder;
  Set<WorkColumn> get _effectiveVisibleColumns => _internalVisibleColumns;

  void _toggleColumn(WorkColumn column) {
    if (column.isMandatory) return;
    final current = Set<WorkColumn>.from(_internalVisibleColumns);
    if (current.contains(column)) {
      if (current.length > 1) {
        current.remove(column);
      }
    } else {
      current.add(column);
    }
    widget.onVisibleColumnsChanged?.call(current);
    setState(() {
      _internalVisibleColumns = current;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final newOrder = List<WorkColumn>.from(_internalColumnOrder);
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);
    widget.onColumnOrderChanged?.call(newOrder);
    setState(() {
      _internalColumnOrder = newOrder;
    });
  }

  void _resetColumns() {
    final defaultOrder = List<WorkColumn>.from(WorkColumn.values);
    final defaultVisible = Set<WorkColumn>.from(
      WorkColumn.defaultVisibleColumns,
    );
    widget.onColumnOrderChanged?.call(defaultOrder);
    widget.onVisibleColumnsChanged?.call(defaultVisible);
    setState(() {
      _internalColumnOrder = defaultOrder;
      _internalVisibleColumns = defaultVisible;
    });
  }

  Widget _buildHeaderCell(WorkColumn col, LyraThemeTokens tokens) {
    Widget child;
    if (col == WorkColumn.musicbrainzId) {
      child = Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text(
            col.headerLabel,
            style: LyraTypography.small(
              tokens,
            ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (col == WorkColumn.index) {
      child = Align(
        alignment: Alignment.centerLeft,
        child: Text(
          col.headerLabel,
          style: LyraTypography.small(
            tokens,
          ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      child = Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Text(
          col.headerLabel,
          style: LyraTypography.small(
            tokens,
          ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (col.width != null) {
      return SizedBox(width: col.width, child: child);
    } else {
      return Expanded(flex: col.flex ?? 1, child: child);
    }
  }

  Widget _proxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
    LyraThemeTokens tokens,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: tokens.border, width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (widget.works.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.layers, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text('No musical works found', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Import audio tracks to automatically resolve musical composition works.',
              style: LyraTypography.muted(tokens),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.xl,
            vertical: LyraSpacing.lg,
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Musical Works', style: LyraTypography.h2(tokens)),
                  const SizedBox(height: LyraSpacing.xs),
                  Text(
                    '${widget.works.length} compositions (Tier 1)',
                    style: LyraTypography.muted(tokens),
                  ),
                ],
              ),
              const Spacer(),
              LyraBadge.secondary(child: Text('${widget.works.length} Works')),
            ],
          ),
        ),

        // Table Header with Draggable Floating Columns Window
        DraggableColumnsOverlay(
          key: const Key('works_table_header_context_menu'),
          controller: _columnsOverlayController,
          positionNotifier: _columnsPositionNotifier,
          estimatedCardHeight: 60.0 + _effectiveColumnOrder.length * 36.0,
          onReset: _resetColumns,
          cardKey: const Key('works_columns_window'),
          headerKey: const Key('works_columns_window_header'),
          resetKey: const Key('works_columns_reset_button'),
          closeKey: const Key('works_columns_close_button'),
          tokens: tokens,
          content: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) =>
                _proxyDecorator(child, index, animation, tokens),
            itemCount: _effectiveColumnOrder.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final col = _effectiveColumnOrder[index];
              final isVisible = _effectiveVisibleColumns.contains(col);
              return _WorkColumnMenuItem(
                key: Key('work_col_menu_${col.name}'),
                index: index,
                col: col,
                isVisible: isVisible,
                tokens: tokens,
                onToggle: () => _toggleColumn(col),
              );
            },
          ),
          child: Container(
            key: const Key('works_table_header'),
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.xl,
              vertical: LyraSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: tokens.background,
              border: Border(
                bottom: BorderSide(color: tokens.border, width: 1.0),
              ),
            ),
            child: Row(
              children: [
                for (final col in _effectiveColumnOrder)
                  if (_effectiveVisibleColumns.contains(col))
                    _buildHeaderCell(col, tokens),
              ],
            ),
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
            itemCount: widget.works.length,
            itemExtent: 60.0,
            itemBuilder: (context, index) {
              final work = widget.works[index];
              return _WorkRow(
                index: index + 1,
                work: work,
                columnOrder: _effectiveColumnOrder,
                visibleColumns: _effectiveVisibleColumns,
                onTap: () => widget.onWorkSelected?.call(work),
                tokens: tokens,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorkColumnMenuItem extends StatefulWidget {
  final int index;
  final WorkColumn col;
  final bool isVisible;
  final LyraThemeTokens tokens;
  final VoidCallback onToggle;

  const _WorkColumnMenuItem({
    super.key,
    required this.index,
    required this.col,
    required this.isVisible,
    required this.tokens,
    required this.onToggle,
  });

  @override
  State<_WorkColumnMenuItem> createState() => _WorkColumnMenuItemState();
}

class _WorkColumnMenuItemState extends State<_WorkColumnMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final col = widget.col;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: col.isMandatory
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: Container(
        height: 36.0,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: _isHovered ? tokens.secondary.withValues(alpha: 0.5) : null,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 8.0,
                  ),
                  child: Icon(
                    LucideIcons.gripVertical,
                    size: 14.0,
                    color: tokens.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: col.isMandatory ? null : widget.onToggle,
                child: Row(
                  children: [
                    IgnorePointer(
                      child: ShadCheckbox(
                        key: Key('work_col_checkbox_${col.name}'),
                        value: widget.isVisible,
                        enabled: !col.isMandatory,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        col.label,
                        style: LyraTypography.small(tokens).copyWith(
                          color: col.isMandatory
                              ? tokens.textMuted
                              : tokens.text,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (col.isMandatory) ...[
                      const SizedBox(width: 4.0),
                      Icon(
                        LucideIcons.lock,
                        size: 12.0,
                        color: tokens.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkRow extends StatefulWidget {
  final int index;
  final Work work;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;
  final List<WorkColumn> columnOrder;
  final Set<WorkColumn> visibleColumns;

  const _WorkRow({
    required this.index,
    required this.work,
    required this.onTap,
    required this.tokens,
    required this.columnOrder,
    required this.visibleColumns,
  });

  @override
  State<_WorkRow> createState() => _WorkRowState();
}

class _WorkRowState extends State<_WorkRow> {
  bool _isHovered = false;

  Widget _buildRowCell(
    WorkColumn col,
    LyraThemeTokens tokens,
    String dateText,
  ) {
    switch (col.name) {
      case 'index':
        return SizedBox(
          width: col.width ?? 40.0,
          child: Text(
            '${widget.index}',
            style: LyraTypography.small(
              tokens,
            ).copyWith(color: tokens.textMuted),
          ),
        );
      case 'title':
        return Expanded(
          flex: col.flex ?? 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.work.title,
              style: LyraTypography.p(
                tokens,
              ).copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'composer':
        return Expanded(
          flex: col.flex ?? 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.work.composer ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'lyricist':
        return Expanded(
          flex: col.flex ?? 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.work.lyricist ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'movement':
        return Expanded(
          flex: col.flex ?? 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.work.movement ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'date':
        return Expanded(
          flex: col.flex ?? 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              dateText,
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
            ),
          ),
        );
      case 'iswc':
        return Expanded(
          flex: col.flex ?? 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: widget.work.iswc != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: LyraBadge.outline(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      child: Text(
                        widget.work.iswc!,
                        style: LyraTypography.mono(tokens, fontSize: 10.0),
                      ),
                    ),
                  )
                : Text(
                    '-',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                  ),
          ),
        );
      case 'musicbrainzId':
        return Expanded(
          flex: col.flex ?? 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                widget.work.musicbrainzId ?? '-',
                style: LyraTypography.mono(
                  tokens,
                  fontSize: 10.0,
                ).copyWith(color: tokens.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCell(WorkColumn col, LyraThemeTokens tokens, String dateText) =>
      _buildRowCell(col, tokens, dateText);

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final work = widget.work;
    final dateText = work.displayDate;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.xl,
              vertical: LyraSpacing.md,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? tokens.secondary.withValues(alpha: 0.5)
                  : null,
              border: Border(
                bottom: BorderSide(
                  color: tokens.border.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                for (final col in widget.columnOrder)
                  if (widget.visibleColumns.contains(col))
                    _buildCell(col, tokens, dateText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
