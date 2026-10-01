// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' show Tooltip, TooltipState;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadContextMenuRegion, ShadContextMenuItem;

import '../../../design_system/contracts/lyra_contracts.dart';
import '../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../design_system/tokens/lyra_tokens.dart';
import '../../../design_system/widgets/lyra_badge.dart';
import '../../../design_system/widgets/lyra_button.dart';
import '../../../design_system/widgets/lyra_card.dart';
import '../../../design_system/widgets/lyra_dialog.dart';
import '../../../design_system/widgets/lyra_input.dart';
import '../controllers/database_explorer_controller.dart';
import '../models/database_stats.dart';

/// SQLite Database Health Status & full-featured SQLite Data Browser tab.
class DatabaseExplorerTab extends StatefulWidget {
  final DatabaseExplorerController controller;

  const DatabaseExplorerTab({super.key, required this.controller});

  @override
  State<DatabaseExplorerTab> createState() => _DatabaseExplorerTabState();
}

class _DatabaseExplorerTabState extends State<DatabaseExplorerTab> {
  /// Converts snake_case SQLite column names to Title Case with acronym preservation (Apple HIG).
  static String formatColumnHeader(String col) {
    switch (col) {
      case 'id':
        return 'ID';
      case 'pcm_hash':
        return 'PCM Hash';
      case 'file_hash':
        return 'File Hash';
      case 'work_id':
        return 'Work ID';
      case 'isrc':
        return 'ISRC';
      case 'iswc':
        return 'ISWC';
      case 'musicbrainz_id':
        return 'MusicBrainz ID';
      case 'spotify_id':
        return 'Spotify ID';
      case 'ytm_id':
        return 'YTM ID';
    }

    return col
        .split('_')
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          if (lower == 'id') return 'ID';
          if (lower == 'pcm') return 'PCM';
          if (lower == 'url') return 'URL';
          if (lower == 'uri') return 'URI';
          if (lower == 'cas') return 'CAS';
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  bool _showVacuumDialog = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant DatabaseExplorerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      if (_searchController.text != widget.controller.searchQuery) {
        _searchController.text = widget.controller.searchQuery;
      }
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_searchController.text != widget.controller.searchQuery) {
      _searchController.text = widget.controller.searchQuery;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final controller = widget.controller;
    final stats = controller.stats;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.xl,
            vertical: LyraSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Compact Database Health Status
              _buildDatabaseHealthCard(tokens, stats, controller),
              const SizedBox(height: LyraSpacing.lg),

              // Section 2: SQLite Data Browser
              _buildDataBrowserCard(tokens, controller),
              const SizedBox(height: LyraSpacing.xl),
            ],
          ),
        ),

        // Vacuum Confirmation Dialog Modal
        if (_showVacuumDialog) _buildVacuumDialog(tokens, controller),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Database Health Status Panel
  // ---------------------------------------------------------------------------

  Widget _buildDatabaseHealthCard(
    LyraThemeTokens tokens,
    DatabaseStats stats,
    DatabaseExplorerController controller,
  ) {
    final isBusy = controller.isBusy;

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.activity, size: 18.0, color: tokens.textMuted),
              const SizedBox(width: LyraSpacing.sm),
              Flexible(
                child: Text(
                  'Database Health Status',
                  style: LyraTypography.h4(
                    tokens,
                  ).copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.md),

          // Monospace Database Path Bar with Copy Button
          _DatabasePathBar(path: stats.databasePath, tokens: tokens),
          const SizedBox(height: LyraSpacing.lg),

          // 4-Tile Metrics Grid with Inline Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              const minTileWidth = 260.0;
              final colCount = (constraints.maxWidth / minTileWidth)
                  .floor()
                  .clamp(1, 4);
              final itemWidth =
                  (constraints.maxWidth - (colCount - 1) * LyraSpacing.md) /
                  colCount;

              return Wrap(
                spacing: LyraSpacing.md,
                runSpacing: LyraSpacing.md,
                children: [
                  // 1. Database Size
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricTileWithAction(
                      tokens: tokens,
                      label: 'Database Size',
                      value: stats.formattedDatabaseSize,
                    ),
                  ),

                  // 2. WAL Journal
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricTileWithAction(
                      tokens: tokens,
                      label: 'WAL Journal',
                      value:
                          '${stats.formattedWalSize} (${stats.formattedWalPages})',
                      action: LyraButton.outline(
                        key: const Key('checkpoint_wal_button'),
                        size: LyraButtonSize.sm,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        onPressed: isBusy
                            ? null
                            : () => controller.checkpointWal(),
                        child: const Text(
                          'Checkpoint WAL',
                          style: TextStyle(fontSize: 12.0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),

                  // 3. Reclaimable Space
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricTileWithAction(
                      tokens: tokens,
                      label: 'Reclaimable Space',
                      value: '${stats.formattedReclaimableSize} (Freelist)',
                      action: LyraButton.outline(
                        key: const Key('vacuum_database_button'),
                        size: LyraButtonSize.sm,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        onPressed: isBusy
                            ? null
                            : () => setState(() => _showVacuumDialog = true),
                        child: const Text(
                          'Vacuum Database',
                          style: TextStyle(fontSize: 12.0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),

                  // 4. Integrity Status
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricTileWithAction(
                      tokens: tokens,
                      label: 'Integrity Status',
                      value: stats.integrityStatus == 'OK'
                          ? 'Healthy (OK)'
                          : stats.integrityStatus,
                      action: LyraButton.outline(
                        key: const Key('verify_integrity_button'),
                        size: LyraButtonSize.sm,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        onPressed: isBusy
                            ? null
                            : () => controller.verifyIntegrity(),
                        child: const Text(
                          'Verify Integrity',
                          style: TextStyle(fontSize: 12.0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: LyraSpacing.md),

          // In-place result display for operations without layout shift
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            constraints: const BoxConstraints(minHeight: 28.0),
            alignment: Alignment.centerLeft,
            child: _buildOperationStatus(tokens, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTileWithAction({
    required LyraThemeTokens tokens,
    required String label,
    required String value,
    Widget? action,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56.0),
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.md,
        vertical: LyraSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.secondary.withValues(alpha: 0.35),
        borderRadius: LyraRadius.smRadius,
        border: Border.all(
          color: tokens.border.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted, fontSize: 12.0),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Tooltip(
                  message: value,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Text(
                    value,
                    style: LyraTypography.p(
                      tokens,
                    ).copyWith(fontWeight: FontWeight.w600, color: tokens.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: LyraSpacing.sm),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildOperationStatus(
    LyraThemeTokens tokens,
    DatabaseExplorerController controller,
  ) {
    if (controller.isCheckpointing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.loader2, size: 14.0, color: tokens.textMuted),
          const SizedBox(width: LyraSpacing.sm),
          Text(
            'Checkpointing WAL frames...',
            style: LyraTypography.muted(tokens),
          ),
        ],
      );
    }

    if (controller.isVacuuming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.loader2, size: 14.0, color: tokens.textMuted),
          const SizedBox(width: LyraSpacing.sm),
          Text(
            'Vacuuming database and defragmenting pages...',
            style: LyraTypography.muted(tokens),
          ),
        ],
      );
    }

    if (controller.isVerifyingIntegrity) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.loader2, size: 14.0, color: tokens.textMuted),
          const SizedBox(width: LyraSpacing.sm),
          Text(
            'Verifying database integrity...',
            style: LyraTypography.muted(tokens),
          ),
        ],
      );
    }

    if (controller.lastActionMessage != null) {
      final isError = controller.lastActionIsError;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.lastIntegrityStatus != null && isError) ...[
            Flexible(
              child: LyraBadge.destructive(
                child: const Text(
                  'Check Failed',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: LyraSpacing.sm),
          ],
          Flexible(
            child: Text(
              controller.lastActionMessage!,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: isError
                  ? LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.destructive)
                  : LyraTypography.muted(tokens),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // Section 2: Full SQLite Data Browser
  // ---------------------------------------------------------------------------

  Widget _buildDataBrowserCard(
    LyraThemeTokens tokens,
    DatabaseExplorerController controller,
  ) {
    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(
                LucideIcons.tableProperties,
                size: 18.0,
                color: tokens.textMuted,
              ),
              const SizedBox(width: LyraSpacing.sm),
              Flexible(
                child: Text(
                  'SQLite Data Browser',
                  style: LyraTypography.h4(
                    tokens,
                  ).copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.md),

          // Toolbar: Table Dropdown + Search Filter + Record Counter
          _buildBrowserToolbar(tokens, controller),
          const SizedBox(height: LyraSpacing.md),

          // Data Grid
          _buildDataGrid(tokens, controller),
          const SizedBox(height: LyraSpacing.md),

          // Pagination Bar
          _buildPaginationBar(tokens, controller),
        ],
      ),
    );
  }

  Widget _buildBrowserToolbar(
    LyraThemeTokens tokens,
    DatabaseExplorerController controller,
  ) {
    final startRecord = controller.filteredRowCount == 0
        ? 0
        : (controller.currentPage - 1) * controller.pageSize + 1;
    final endRecord =
        (controller.currentPage - 1) * controller.pageSize +
        controller.pagedRows.length;

    final pageSizes = {25, 50, 100, controller.pageSize}.toList()..sort();
    final pageSizeItems = pageSizes
        .map((size) => LyraSelectItem<int>(value: size, label: '$size / page'))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: LyraSpacing.md,
          runSpacing: LyraSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            // Left side: Table Selector & Search Input wrapped
            Wrap(
              spacing: LyraSpacing.md,
              runSpacing: LyraSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Table:',
                      style: LyraTypography.small(tokens).copyWith(
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(width: LyraSpacing.sm),

                    // Table Dropdown Selector
                    LyraSelect<String>(
                      key: const Key('table_selector_dropdown'),
                      tooltip: 'Select database table',
                      value: controller.selectedTable,
                      popoverWidth: 160.0,
                      items: controller.availableTables.map((table) {
                        return LyraSelectItem<String>(
                          value: table,
                          label: table,
                          leading: Icon(
                            LucideIcons.table,
                            size: 14.0,
                            color: table == controller.selectedTable
                                ? tokens.primary
                                : tokens.textMuted,
                          ),
                        );
                      }).toList(),
                      onChanged: (table) {
                        controller.selectTable(table);
                        _searchController.text = '';
                      },
                    ),
                  ],
                ),

                // Search Filter Input
                SizedBox(
                  width: constraints.maxWidth < 280.0
                      ? constraints.maxWidth
                      : 280.0,
                  child: LyraInput(
                    key: const Key('database_browser_search_input'),
                    controller: _searchController,
                    placeholder: 'Filter in any column...',
                    leading: Icon(
                      LucideIcons.search,
                      size: 14.0,
                      color: tokens.textMuted,
                    ),
                    trailing: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _searchController.clear();
                              controller.setSearchQuery('');
                            },
                            child: Icon(
                              LucideIcons.x,
                              size: 14.0,
                              color: tokens.textMuted,
                            ),
                          )
                        : null,
                    onChanged: (val) => controller.setSearchQuery(val),
                  ),
                ),
              ],
            ),

            // Right side: Page size selector & Record counter
            Wrap(
              spacing: LyraSpacing.md,
              runSpacing: LyraSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LyraSelect<int>(
                  key: const Key('page_size_selector_dropdown'),
                  tooltip: 'Rows per page',
                  value: controller.pageSize,
                  popoverWidth: 120.0,
                  items: pageSizeItems,
                  onChanged: (size) => controller.setPageSize(size),
                ),
                Text(
                  controller.filteredRowCount == 0
                      ? 'Showing 0 records'
                      : 'Showing $startRecord–$endRecord of ${controller.filteredRowCount} records',
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataGrid(
    LyraThemeTokens tokens,
    DatabaseExplorerController controller,
  ) {
    final columns = controller.currentColumns;
    final rows = controller.pagedRows;

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: LyraRadius.smRadius,
        border: Border.all(
          color: tokens.border.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 700.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Container(
                decoration: BoxDecoration(
                  color: tokens.secondary.withValues(alpha: 0.45),
                  border: Border(
                    bottom: BorderSide(
                      color: tokens.border.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: LyraSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row Number Gutter Header
                    Container(
                      width: 48.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: tokens.border.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Text(
                        '#',
                        style: LyraTypography.small(tokens).copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.textMuted,
                        ),
                      ),
                    ),

                    // Column Headers
                    ...columns.map((col) {
                      final width = _getColumnWidth(col);
                      return Container(
                        width: width,
                        padding: const EdgeInsets.symmetric(
                          horizontal: LyraSpacing.md,
                        ),
                        child: Tooltip(
                          message: 'Column: $col',
                          waitDuration: const Duration(milliseconds: 500),
                          child: Text(
                            formatColumnHeader(col),
                            style: LyraTypography.small(tokens).copyWith(
                              fontWeight: FontWeight.w600,
                              color: tokens.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Data Rows / Empty State
              if (rows.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36.0),
                  alignment: Alignment.center,
                  child: Center(
                    child: Text(
                      'No matching records found',
                      style: LyraTypography.muted(tokens),
                    ),
                  ),
                )
              else
                ...rows.asMap().entries.map((entry) {
                  final rowIndex = entry.key;
                  final row = entry.value;
                  final rowNumber =
                      (controller.currentPage - 1) * controller.pageSize +
                      rowIndex +
                      1;
                  final isLast = rowIndex == rows.length - 1;
                  final isOdd = rowIndex.isOdd;

                  return Container(
                    decoration: BoxDecoration(
                      color: isOdd
                          ? tokens.secondary.withValues(alpha: 0.15)
                          : null,
                      border: isLast
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: tokens.border.withValues(alpha: 0.3),
                                width: 1.0,
                              ),
                            ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: LyraSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row Number Gutter
                        Container(
                          width: 48.0,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: tokens.border.withValues(alpha: 0.4),
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: Text(
                            '$rowNumber',
                            style: LyraTypography.mono(
                              tokens,
                            ).copyWith(fontSize: 12.0, color: tokens.textMuted),
                          ),
                        ),

                        // Columns Data Cells
                        ...columns.map((col) {
                          final width = _getColumnWidth(col);
                          final value = row[col];

                          return Container(
                            width: width,
                            padding: const EdgeInsets.symmetric(
                              horizontal: LyraSpacing.md,
                            ),
                            child: _buildCellWidget(
                              tokens,
                              value,
                              column: col,
                              row: row,
                              rowIndex: rowIndex,
                              controller: controller,
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCellWidget(
    LyraThemeTokens tokens,
    dynamic value, {
    String column = '',
    Map<String, dynamic> row = const {},
    int rowIndex = 0,
    DatabaseExplorerController? controller,
  }) {
    return _DataCellWidget(
      key: ValueKey('${row['id'] ?? rowIndex}_$column'),
      tokens: tokens,
      value: value,
      column: column,
      row: row,
      controller: controller ?? widget.controller,
    );
  }

  double _getColumnWidth(String column) {
    switch (column) {
      case 'id':
      case 'pcm_hash':
      case 'file_hash':
      case 'image_hash':
      case 'work_id':
        return 280.0;
      case 'title':
      case 'name':
      case 'description':
        return 220.0;
      case 'created_at':
      case 'updated_at':
      case 'composition_date_text':
        return 170.0;
      case 'musicbrainz_id':
      case 'spotify_id':
      case 'ytm_id':
      case 'isrc':
      case 'iswc':
        return 190.0;
      case 'entity_type':
      case 'category':
      case 'format':
      case 'mime_type':
      case 'dominant_color':
        return 130.0;
      case 'duration':
      case 'recording_year':
      case 'release_year':
      case 'release_month':
      case 'release_day':
      case 'sample_rate':
      case 'channels':
      case 'bit_depth':
      case 'size_bytes':
      case 'width':
      case 'height':
        return 110.0;
      default:
        return 150.0;
    }
  }

  Widget _buildPaginationBar(
    LyraThemeTokens tokens,
    DatabaseExplorerController controller,
  ) {
    final showPrev = controller.currentPage > 1;
    final showNext = controller.currentPage < controller.totalPages;

    return Align(
      alignment: Alignment.centerRight,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        child: Wrap(
          spacing: LyraSpacing.sm,
          runSpacing: LyraSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (showPrev)
              LyraButton.outline(
                key: const Key('prev_page_button'),
                size: LyraButtonSize.sm,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 6.0,
                ),
                onPressed: () => controller.previousPage(),
                child: const Icon(LucideIcons.chevronLeft, size: 16.0),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.xs),
              child: Text(
                'Page ${controller.currentPage} of ${controller.totalPages}',
                style: LyraTypography.small(
                  tokens,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (showNext)
              LyraButton.outline(
                key: const Key('next_page_button'),
                size: LyraButtonSize.sm,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 6.0,
                ),
                onPressed: () => controller.nextPage(),
                child: const Icon(LucideIcons.chevronRight, size: 16.0),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vacuum Confirmation Modal Dialog
  // ---------------------------------------------------------------------------

  Widget _buildVacuumDialog(
    LyraThemeTokens tokens,
    DatabaseExplorerController controller,
  ) {
    return Container(
      color: const Color(0x80000000),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440.0),
        child: LyraDialog(
          title: Text('Vacuum Database', style: LyraTypography.h3(tokens)),
          description: Text(
            'Are you sure you want to vacuum the database? '
            'This rebuilds the database file, defragmenting allocated pages '
            'and reclaiming unused disk space. This operation may take several seconds.',
            style: LyraTypography.muted(tokens),
          ),
          actions: [
            LyraButton.ghost(
              size: LyraButtonSize.sm,
              onPressed: () => setState(() => _showVacuumDialog = false),
              child: const Text('Cancel'),
            ),
            LyraButton.destructive(
              size: LyraButtonSize.sm,
              onPressed: () async {
                setState(() => _showVacuumDialog = false);
                await controller.vacuumDatabase();
              },
              child: const Text('Confirm Vacuum'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Monospace Database Path Bar with In-Place Tooltip Feedback
// -----------------------------------------------------------------------------

class _DatabasePathBar extends StatefulWidget {
  final String path;
  final LyraThemeTokens tokens;

  const _DatabasePathBar({required this.path, required this.tokens});

  @override
  State<_DatabasePathBar> createState() => _DatabasePathBarState();
}

class _DatabasePathBarState extends State<_DatabasePathBar> {
  bool _copied = false;
  bool _isHovered = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copyPath() {
    Clipboard.setData(ClipboardData(text: widget.path));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.secondary.withValues(alpha: 0.35),
        borderRadius: LyraRadius.smRadius,
        border: Border.all(
          color: tokens.border.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.md,
        vertical: LyraSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.hardDrive, size: 16.0, color: tokens.textMuted),
          const SizedBox(width: LyraSpacing.sm),
          Expanded(
            child: Text(
              widget.path,
              style: LyraTypography.mono(
                tokens,
              ).copyWith(fontSize: 12.0, color: tokens.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: LyraSpacing.sm),
          Tooltip(
            message: _copied ? '' : 'Copy database path',
            waitDuration: const Duration(milliseconds: 400),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: GestureDetector(
                key: const Key('copy_database_path_button'),
                behavior: HitTestBehavior.opaque,
                onTap: _copyPath,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOutCubic,
                  height: 28.0,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: _copied
                        ? tokens.success.withValues(alpha: 0.12)
                        : (_isHovered
                              ? tokens.secondary
                              : tokens.secondary.withValues(alpha: 0.35)),
                    borderRadius: LyraRadius.smRadius,
                    border: Border.all(
                      color: _copied
                          ? tokens.success.withValues(alpha: 0.5)
                          : (_isHovered
                                ? tokens.border
                                : tokens.border.withValues(alpha: 0.5)),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          _copied ? LucideIcons.check : LucideIcons.copy,
                          key: ValueKey<bool>(_copied),
                          size: 13.0,
                          color: _copied ? tokens.success : tokens.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        _copied ? 'Copied' : 'Copy',
                        style: LyraTypography.small(tokens).copyWith(
                          fontSize: 11.0,
                          fontWeight: _copied
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _copied ? tokens.success : tokens.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Interactive Data Cell Widget with Click-to-Copy & Right-Click Context Menu
// -----------------------------------------------------------------------------

class _DataCellWidget extends StatefulWidget {
  final LyraThemeTokens tokens;
  final dynamic value;
  final String column;
  final Map<String, dynamic> row;
  final DatabaseExplorerController controller;

  const _DataCellWidget({
    super.key,
    required this.tokens,
    required this.value,
    required this.column,
    required this.row,
    required this.controller,
  });

  @override
  State<_DataCellWidget> createState() => _DataCellWidgetState();
}

class _DataCellWidgetState extends State<_DataCellWidget> {
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _hexHashRegex = RegExp(r'^[a-fA-F0-9]{32,64}$');

  bool _copied = false;
  Timer? _copyTimer;
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  void didUpdateWidget(covariant _DataCellWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _copied = false;
      _copyTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    if (widget.value == null) return;
    final str = widget.value.toString();
    Clipboard.setData(ClipboardData(text: str));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _tooltipKey.currentState?.ensureTooltipVisible();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _copied) {
        _tooltipKey.currentState?.ensureTooltipVisible();
      }
    });
    _copyTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _copyRowJson(Map<String, dynamic> row) {
    try {
      final json = const JsonEncoder.withIndent(
        '  ',
      ).convert(row.map((k, v) => MapEntry(k, v?.toString() ?? v)));
      Clipboard.setData(ClipboardData(text: json));
    } catch (_) {
      Clipboard.setData(ClipboardData(text: row.toString()));
    }
  }

  void _onCellTap() {
    _copy();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final value = widget.value;

    final items = _buildMenuItems(tokens);

    if (value == null) {
      return ShadContextMenuRegion(
        constraints: const BoxConstraints(minWidth: 200),
        popoverReverseDuration: const Duration(milliseconds: 50),
        items: items,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: Text(
            'NULL',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: tokens.textMuted.withValues(alpha: 0.6),
              fontSize: 13.0,
            ),
          ),
        ),
      );
    }

    final str = value.toString();
    final isMonospace = _uuidRegex.hasMatch(str) || _hexHashRegex.hasMatch(str);

    return ShadContextMenuRegion(
      constraints: const BoxConstraints(minWidth: 200),
      popoverReverseDuration: const Duration(milliseconds: 50),
      items: items,
      child: Tooltip(
        key: _tooltipKey,
        enableTapToDismiss: false,
        waitDuration: Duration.zero,
        showDuration: const Duration(milliseconds: 2000),
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        decoration: const BoxDecoration(color: Color(0x00000000)),
        richMessage: WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            height: 28.0,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: LyraRadius.smRadius,
              border: Border.all(
                color: _copied ? tokens.success : tokens.border,
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.9,
                          end: 1.0,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _copied
                      ? Row(
                          key: const ValueKey<bool>(true),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.check,
                              size: 13.0,
                              color: tokens.success,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              'Copied',
                              style: TextStyle(
                                color: tokens.success,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Click to copy',
                          key: const ValueKey<bool>(false),
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 12.0,
                            height: 1.2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onExit: (event) {
            _copyTimer?.cancel();
            if (mounted && _copied) setState(() => _copied = false);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onCellTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 2.0,
              ),
              child: Text(
                str,
                style: isMonospace
                    ? LyraTypography.mono(
                        tokens,
                      ).copyWith(fontSize: 12.0, color: tokens.text)
                    : LyraTypography.small(tokens),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems(LyraThemeTokens tokens) {
    final row = widget.row;
    final controller = widget.controller;
    final value = widget.value;
    final currentTable = controller.selectedTable;

    final items = <Widget>[
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.copy, size: 14.0),
        enabled: value != null,
        onPressed: value != null
            ? () {
                Clipboard.setData(ClipboardData(text: value.toString()));
              }
            : null,
        child: Text(value == null ? 'Copy Value (Empty)' : 'Copy Value'),
      ),
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.code, size: 14.0),
        onPressed: () => _copyRowJson(row),
        child: const Text('Copy Row JSON'),
      ),
    ];

    if (currentTable == 'Entity') {
      final entityType = row['entity_type']?.toString().toLowerCase();
      final id = row['id']?.toString().trim();
      if (id != null && id.isNotEmpty) {
        switch (entityType) {
          case 'track':
            items.add(
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.music, size: 14.0),
                onPressed: () =>
                    controller.navigateToTable('Track', filter: id),
                child: const Text('View in Track Table'),
              ),
            );
            break;
          case 'artist':
            items.add(
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.mic2, size: 14.0),
                onPressed: () =>
                    controller.navigateToTable('Artist', filter: id),
                child: const Text('View in Artist Table'),
              ),
            );
            break;
          case 'album':
            items.add(
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.disc, size: 14.0),
                onPressed: () =>
                    controller.navigateToTable('Album', filter: id),
                child: const Text('View in Album Table'),
              ),
            );
            break;
          case 'work':
            items.add(
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.bookOpen, size: 14.0),
                onPressed: () => controller.navigateToTable('Work', filter: id),
                child: const Text('View in Work Table'),
              ),
            );
            break;
          case 'playlist':
            items.add(
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.listMusic, size: 14.0),
                onPressed: () =>
                    controller.navigateToTable('Playlist', filter: id),
                child: const Text('View in Playlist Table'),
              ),
            );
            break;
          case 'tag':
            items.add(
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.tag, size: 14.0),
                onPressed: () => controller.navigateToTable('Tag', filter: id),
                child: const Text('View in Tag Table'),
              ),
            );
            break;
        }
      }
    } else if (currentTable == 'Track') {
      final id = row['id']?.toString().trim();
      if (id != null && id.isNotEmpty) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.database, size: 14.0),
            onPressed: () => controller.navigateToTable('Entity', filter: id),
            child: const Text('View in Entity Table'),
          ),
        );
      }
      final pcmHash = row['pcm_hash']?.toString().trim();
      if (pcmHash != null && pcmHash.isNotEmpty) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.activity, size: 14.0),
            onPressed: () =>
                controller.navigateToTable('Audio', filter: pcmHash),
            child: const Text('View related Audio (PCM Hash)'),
          ),
        );
      }
      final workId = row['work_id']?.toString().trim();
      if (workId != null && workId.isNotEmpty) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.bookOpen, size: 14.0),
            onPressed: () => controller.navigateToTable('Work', filter: workId),
            child: const Text('View related Work'),
          ),
        );
      }
    } else if (currentTable == 'Audio') {
      final pcmHash = row['pcm_hash']?.toString().trim();
      if (pcmHash != null && pcmHash.isNotEmpty) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.music, size: 14.0),
            onPressed: () =>
                controller.navigateToTable('Track', filter: pcmHash),
            child: const Text('Find in Track Table (PCM)'),
          ),
        );
      }
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.fileArchive, size: 14.0),
          onPressed: () => controller.navigateToTable('Asset'),
          child: const Text('View in Asset Table'),
        ),
      );
    } else if (currentTable == 'Asset') {
      final fileHash = row['file_hash']?.toString().trim();
      if (fileHash != null && fileHash.isNotEmpty) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.activity, size: 14.0),
            onPressed: () =>
                controller.navigateToTable('Audio', filter: fileHash),
            child: const Text('Find in Audio Table (Hash)'),
          ),
        );
      }
      final mimeType = row['mime_type']?.toString().toLowerCase();
      if (fileHash != null &&
          fileHash.isNotEmpty &&
          mimeType != null &&
          mimeType.startsWith('image/')) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.image, size: 14.0),
            onPressed: () =>
                controller.navigateToTable('Image', filter: fileHash),
            child: const Text('Find in Image Table (Hash)'),
          ),
        );
      }
    } else if (currentTable == 'Image') {
      final fileHash = row['file_hash']?.toString().trim();
      items.add(
        ShadContextMenuItem(
          leading: const Icon(LucideIcons.fileArchive, size: 14.0),
          onPressed: () =>
              controller.navigateToTable('Asset', filter: fileHash ?? ''),
          child: const Text('View in Asset Table'),
        ),
      );
    } else if ([
      'Artist',
      'Album',
      'Work',
      'Playlist',
      'Tag',
    ].contains(currentTable)) {
      final id = row['id']?.toString().trim();
      if (id != null && id.isNotEmpty) {
        items.add(
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.database, size: 14.0),
            onPressed: () => controller.navigateToTable('Entity', filter: id),
            child: const Text('View in Entity Table'),
          ),
        );
      }
    }

    return items;
  }
}
