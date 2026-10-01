// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/material.dart' show Tooltip, TooltipState;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../design_system/tokens/lyra_tokens.dart';
import '../../../design_system/widgets/lyra_badge.dart';
import '../../../design_system/widgets/lyra_card.dart';
import '../../../design_system/widgets/lyra_input.dart';
import '../../models/cas_object.dart';
import '../controllers/cas_controller.dart';

/// Columns available in the CAS Blobs table.
enum CasBlobColumn {
  hash('Integrity Hash'),
  size('File Size'),
  mimeType('MIME Type'),
  references('References');

  final String label;
  const CasBlobColumn(this.label);
}

/// Tab 1: Storage capacity metrics, horizontal segmented storage bar, and content-addressed blobs browser.
class CasStorageTab extends StatefulWidget {
  final CasController controller;
  final ValueChanged<CasObject>? onInspectAsset;
  final VoidCallback? onVerifyAll;

  const CasStorageTab({
    super.key,
    required this.controller,
    this.onInspectAsset,
    this.onVerifyAll,
  });

  @override
  State<CasStorageTab> createState() => _CasStorageTabState();
}

class _CasStorageTabState extends State<CasStorageTab> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final ShadContextMenuController _headerContextMenuController;

  final Set<CasBlobColumn> _visibleColumns = Set<CasBlobColumn>.from(
    CasBlobColumn.values,
  );

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
    _scrollController = ScrollController();
    _headerContextMenuController = ShadContextMenuController();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CasStorageTab oldWidget) {
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
    _scrollController.dispose();
    _headerContextMenuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final controller = widget.controller;

    final audio = controller.audioBytes;
    final covers = controller.coverBytes;
    final waveforms = controller.waveformCacheBytes;
    final database = controller.databaseBytes;
    final totalStorage = audio + covers + waveforms + database;

    int audioFlex = 0;
    int coverFlex = 0;
    int waveformFlex = 0;
    int databaseFlex = 0;

    if (totalStorage > 0) {
      audioFlex = audio > 0
          ? (audio / totalStorage * 1000).round().clamp(1, 1000)
          : 0;
      coverFlex = covers > 0
          ? (covers / totalStorage * 1000).round().clamp(1, 1000)
          : 0;
      waveformFlex = waveforms > 0
          ? (waveforms / totalStorage * 1000).round().clamp(1, 1000)
          : 0;
      databaseFlex = database > 0
          ? (database / totalStorage * 1000).round().clamp(1, 1000)
          : 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // iOS / macOS Segmented Storage Capacity Bar Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.xl),
          child: LyraCard(
            padding: const EdgeInsets.all(LyraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal Segmented Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Container(
                    height: 12.0,
                    width: double.infinity,
                    color: tokens.secondary,
                    child: totalStorage == 0
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              if (audioFlex > 0)
                                Expanded(
                                  flex: audioFlex,
                                  child: Container(
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ),
                              if (coverFlex > 0)
                                Expanded(
                                  flex: coverFlex,
                                  child: Container(
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              if (waveformFlex > 0)
                                Expanded(
                                  flex: waveformFlex,
                                  child: Container(
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              if (databaseFlex > 0)
                                Expanded(
                                  flex: databaseFlex,
                                  child: Container(
                                    color: const Color(0xFF8B5CF6),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: LyraSpacing.md),

                // Clean Legend below with total capacity on the right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: LyraSpacing.lg,
                        runSpacing: LyraSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildLegendItem(
                            tokens: tokens,
                            color: const Color(0xFF3B82F6),
                            label: 'Audio',
                            value: controller.formattedAudioBytes,
                          ),
                          _buildLegendItem(
                            tokens: tokens,
                            color: const Color(0xFF10B981),
                            label: 'Images',
                            value: controller.formattedImageBytes,
                          ),
                          _buildLegendItem(
                            tokens: tokens,
                            color: const Color(0xFFF59E0B),
                            label: 'Waveforms',
                            value: controller.formattedWaveformCacheBytes,
                          ),
                          _buildLegendItem(
                            tokens: tokens,
                            color: const Color(0xFF8B5CF6),
                            label: 'Database',
                            value: controller.formattedDatabaseBytes,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: LyraSpacing.md),
                    Text(
                      '${CasController.formatBytes(totalStorage)} Total',
                      style: LyraTypography.small(tokens).copyWith(
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: LyraSpacing.lg),

        // Blob Objects Explorer Header & Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.xl),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: LyraSpacing.md,
            runSpacing: LyraSpacing.xs,
            children: [
              Text('Blob Objects Explorer', style: LyraTypography.h4(tokens)),
              SizedBox(
                width: 280.0,
                child: LyraInput(
                  controller: _searchController,
                  placeholder: 'Search hash or MIME type...',
                  leading: Icon(
                    LucideIcons.search,
                    size: 14.0,
                    color: tokens.textMuted,
                  ),
                  onChanged: (value) => controller.setSearchQuery(value),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: LyraSpacing.sm),

        // Table Header with Right-click Column Picker Context Menu
        ShadContextMenuRegion(
          controller: _headerContextMenuController,
          tapEnabled: false,
          constraints: const BoxConstraints(minWidth: 180),
          items: [
            for (final col in CasBlobColumn.values)
              ShadContextMenuItem(
                leading: _visibleColumns.contains(col)
                    ? const Icon(LucideIcons.check, size: 14.0)
                    : const SizedBox(width: 14.0),
                closeOnTap: false,
                onPressed: () {
                  setState(() {
                    if (_visibleColumns.contains(col)) {
                      if (_visibleColumns.length > 1) {
                        _visibleColumns.remove(col);
                      }
                    } else {
                      _visibleColumns.add(col);
                    }
                  });
                },
                child: Text(col.label),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.xl,
              vertical: LyraSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: tokens.secondary.withValues(alpha: 0.5),
              border: Border(
                top: BorderSide(color: tokens.border),
                bottom: BorderSide(color: tokens.border),
              ),
            ),
            child: Row(
              children: [
                if (_visibleColumns.contains(CasBlobColumn.hash))
                  Expanded(
                    flex: 5,
                    child: Text(
                      'Integrity Hash',
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (_visibleColumns.contains(CasBlobColumn.size))
                  Expanded(
                    flex: 2,
                    child: Text(
                      'File Size',
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (_visibleColumns.contains(CasBlobColumn.mimeType))
                  Expanded(
                    flex: 2,
                    child: Text(
                      'MIME Type',
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (_visibleColumns.contains(CasBlobColumn.references))
                  Expanded(
                    flex: 2,
                    child: Text(
                      'References',
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Blobs List
        Expanded(
          child: controller.filteredCasObjects.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(LyraSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.fileSearch,
                          size: 40.0,
                          color: tokens.textMuted,
                        ),
                        const SizedBox(height: LyraSpacing.md),
                        Text(
                          controller.searchQuery.isEmpty
                              ? 'No CAS Blobs Found'
                              : 'No Matching CAS Objects',
                          style: LyraTypography.h4(tokens),
                        ),
                        const SizedBox(height: LyraSpacing.xs),
                        Text(
                          controller.searchQuery.isEmpty
                              ? 'The Content Addressable Storage pool currently contains no objects.'
                              : 'Try adjusting your search query or MIME type filter.',
                          style: LyraTypography.muted(tokens),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
                  itemCount: controller.filteredCasObjects.length,
                  itemExtent: 60.0,
                  itemBuilder: (context, index) {
                    final obj = controller.filteredCasObjects[index];
                    return _CasBlobRow(
                      obj: obj,
                      tokens: tokens,
                      visibleColumns: _visibleColumns,
                      onInspectAsset: widget.onInspectAsset,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required LyraThemeTokens tokens,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.0,
          height: 8.0,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6.0),
        Text(
          '$label ',
          style: LyraTypography.small(
            tokens,
          ).copyWith(fontWeight: FontWeight.w500, color: tokens.text),
        ),
        Text(
          value,
          style: LyraTypography.small(tokens).copyWith(color: tokens.textMuted),
        ),
      ],
    );
  }
}

class _CasBlobRow extends StatefulWidget {
  final CasObject obj;
  final LyraThemeTokens tokens;
  final Set<CasBlobColumn> visibleColumns;
  final ValueChanged<CasObject>? onInspectAsset;

  const _CasBlobRow({
    required this.obj,
    required this.tokens,
    required this.visibleColumns,
    this.onInspectAsset,
  });

  @override
  State<_CasBlobRow> createState() => _CasBlobRowState();
}

class _CasBlobRowState extends State<_CasBlobRow> {
  bool _copied = false;
  Timer? _copyTimer;
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copyHash() {
    Clipboard.setData(ClipboardData(text: widget.obj.hash));
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
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final obj = widget.obj;

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onInspectAsset != null
            ? () => widget.onInspectAsset!(obj)
            : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: tokens.border.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.xl,
            vertical: LyraSpacing.md,
          ),
          child: Row(
            children: [
              if (widget.visibleColumns.contains(CasBlobColumn.hash))
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.fileCode,
                        size: 16.0,
                        color: tokens.textMuted,
                      ),
                      const SizedBox(width: LyraSpacing.sm),
                      Flexible(
                        child: Tooltip(
                          key: _tooltipKey,
                          enableTapToDismiss: false,
                          waitDuration: Duration.zero,
                          showDuration: const Duration(milliseconds: 2000),
                          padding: EdgeInsets.zero,
                          margin: EdgeInsets.zero,
                          decoration: const BoxDecoration(
                            color: Color(0x00000000),
                          ),
                          richMessage: WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOutCubic,
                              height: 28.0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.card,
                                borderRadius: LyraRadius.smRadius,
                                border: Border.all(
                                  color: _copied
                                      ? tokens.success
                                      : tokens.border,
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
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
                                            'Click to copy hash',
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
                              if (mounted && _copied) {
                                setState(() => _copied = false);
                              }
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _copyHash,
                              child: Text(
                                obj.hash,
                                style: LyraTypography.mono(
                                  tokens,
                                  fontSize: 12.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!obj.verified) ...[
                        const SizedBox(width: LyraSpacing.xs),
                        LyraBadge.destructive(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.x,
                                size: 10.0,
                                color: Color(0xFFFFFFFF),
                              ),
                              SizedBox(width: 4.0),
                              Text('Unverified'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (widget.visibleColumns.contains(CasBlobColumn.size))
                Expanded(
                  flex: 2,
                  child: Text(
                    obj.formattedSize,
                    style: LyraTypography.small(tokens),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              if (widget.visibleColumns.contains(CasBlobColumn.mimeType))
                Expanded(
                  flex: 2,
                  child: Text(
                    obj.mimeType,
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              if (widget.visibleColumns.contains(CasBlobColumn.references))
                Expanded(
                  flex: 2,
                  child: Text(
                    '${obj.references}',
                    style: LyraTypography.small(tokens),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
