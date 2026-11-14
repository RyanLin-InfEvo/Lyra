// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart' show Material, ReorderableListView;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../design_system/contracts/lyra_contracts.dart';
import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../../../design_system/widgets/lyra_badge.dart';
import '../../../../design_system/widgets/lyra_button.dart';
import '../../../../design_system/widgets/lyra_checkbox.dart';
import '../../../../widgets/draggable_columns_overlay.dart';
import '../../../../widgets/threshold_reorderable_drag_start_listener.dart';
import '../../../common/context_menu_coordinator.dart';
import '../../../models/track.dart';
import '../../../settings/services/preferences_service.dart';
import '../../../tracks/tracks_view.dart'
    show
        TrackColumn,
        TrackCoverThumbnail,
        buildTrackListSubtitleChildren,
        buildTrackListTrailingChildren,
        buildTrackListTrailingHeaderLabels,
        computeTrackListTrailingMetrics,
        normalizeTrackColumnOrder,
        normalizeTrackVisibleColumns;
import '../../controllers/playback_queue_controller.dart';

export '../../../../widgets/threshold_reorderable_drag_start_listener.dart';

/// Up Next tab component displaying the active playback queue, track items, and queue actions.
class UpNextTab extends StatefulWidget {
  final PlaybackQueueController playbackController;
  final PreferencesService? preferencesService;
  final String? queueSource;
  final void Function(Track track)? onAddToPlaylist;
  final void Function(Track track)? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;
  final TrackListViewMode? viewMode;
  final bool? showHeader;
  final Set<TrackColumn>? visibleColumns;
  final ValueChanged<Set<TrackColumn>>? onVisibleColumnsChanged;
  final List<TrackColumn>? columnOrder;
  final ValueChanged<List<TrackColumn>>? onColumnOrderChanged;

  static final Set<TrackColumn> defaultVisibleColumns = {
    TrackColumn.index,
    TrackColumn.cover,
    TrackColumn.title,
    TrackColumn.album,
    TrackColumn.duration,
  };

  const UpNextTab({
    super.key,
    required this.playbackController,
    this.preferencesService,
    this.queueSource,
    this.onAddToPlaylist,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
    this.viewMode,
    this.showHeader,
    this.visibleColumns,
    this.onVisibleColumnsChanged,
    this.columnOrder,
    this.onColumnOrderChanged,
  });

  @override
  State<UpNextTab> createState() => _UpNextTabState();
}

class _UpNextTabState extends State<UpNextTab> {
  late final ScrollController _scrollController;
  final OverlayPortalController _columnsOverlayController =
      OverlayPortalController();
  final ValueNotifier<Offset> _columnsMenuPositionNotifier =
      ValueNotifier<Offset>(Offset.zero);

  late TrackListViewMode _viewMode;
  late bool _showHeader;
  late Set<TrackColumn> _visibleColumns;
  late List<TrackColumn> _columnOrder;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.playbackController.addListener(_onPlaybackChanged);
    widget.preferencesService?.addListener(_onPreferencesChanged);
    _syncStateFromSources();
  }

  void _syncStateFromSources() {
    final prefs = widget.preferencesService;
    _viewMode =
        widget.viewMode ?? prefs?.upNextViewMode ?? TrackListViewMode.list;
    _showHeader = widget.showHeader ?? prefs?.showUpNextHeader ?? true;

    final prefOrderNames = prefs?.getUpNextColumnOrder();
    final colByName = {for (final col in TrackColumn.values) col.name: col};
    final prefOrder = prefOrderNames
        ?.map((name) => colByName[name])
        .whereType<TrackColumn>()
        .toList();
    _columnOrder = normalizeTrackColumnOrder(widget.columnOrder ?? prefOrder);

    final prefVisibleNames = prefs?.getUpNextVisibleColumns();
    final prefVisible = prefVisibleNames
        ?.map((name) => colByName[name])
        .whereType<TrackColumn>()
        .toSet();
    _visibleColumns = normalizeTrackVisibleColumns(
      widget.visibleColumns ?? prefVisible,
      defaults: UpNextTab.defaultVisibleColumns,
    );
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPreferencesChanged() {
    if (!mounted) return;
    final prefs = widget.preferencesService;
    if (prefs == null) return;

    final nextMode = widget.viewMode ?? prefs.upNextViewMode;
    final nextShowHeader = widget.showHeader ?? prefs.showUpNextHeader;

    final colByName = {for (final col in TrackColumn.values) col.name: col};
    final prefOrder = prefs
        .getUpNextColumnOrder()
        ?.map((name) => colByName[name])
        .whereType<TrackColumn>()
        .toList();
    final nextOrder = normalizeTrackColumnOrder(
      widget.columnOrder ?? prefOrder,
    );

    final prefVisible = prefs
        .getUpNextVisibleColumns()
        ?.map((name) => colByName[name])
        .whereType<TrackColumn>()
        .toSet();
    final nextVisible = normalizeTrackVisibleColumns(
      widget.visibleColumns ?? prefVisible,
      defaults: UpNextTab.defaultVisibleColumns,
    );

    if (_viewMode != nextMode ||
        _showHeader != nextShowHeader ||
        !listEquals(_columnOrder, nextOrder) ||
        !setEquals(_visibleColumns, nextVisible)) {
      setState(() {
        _viewMode = nextMode;
        _showHeader = nextShowHeader;
        _columnOrder = nextOrder;
        _visibleColumns = nextVisible;
      });
    }
  }

  @override
  void didUpdateWidget(covariant UpNextTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackController != widget.playbackController) {
      oldWidget.playbackController.removeListener(_onPlaybackChanged);
      widget.playbackController.addListener(_onPlaybackChanged);
    }
    if (oldWidget.preferencesService != widget.preferencesService) {
      oldWidget.preferencesService?.removeListener(_onPreferencesChanged);
      widget.preferencesService?.addListener(_onPreferencesChanged);
    }
    if (oldWidget.preferencesService != widget.preferencesService ||
        oldWidget.viewMode != widget.viewMode ||
        oldWidget.showHeader != widget.showHeader ||
        oldWidget.visibleColumns != widget.visibleColumns ||
        oldWidget.columnOrder != widget.columnOrder) {
      _syncStateFromSources();
    }
  }

  @override
  void dispose() {
    widget.playbackController.removeListener(_onPlaybackChanged);
    widget.preferencesService?.removeListener(_onPreferencesChanged);
    _scrollController.dispose();
    _columnsMenuPositionNotifier.dispose();
    super.dispose();
  }

  List<TrackColumn> get _orderedVisibleColumns =>
      _columnOrder.where(_visibleColumns.contains).toList();

  void _toggleColumn(TrackColumn col) {
    if (col.isMandatory) return;
    final next = Set<TrackColumn>.from(_visibleColumns);
    if (next.contains(col)) {
      next.remove(col);
    } else {
      next.add(col);
    }
    setState(() {
      _visibleColumns = next;
    });
    if (widget.onVisibleColumnsChanged != null) {
      widget.onVisibleColumnsChanged!.call(next);
    } else {
      widget.preferencesService?.setUpNextVisibleColumns(
        next.map((c) => c.name).toSet(),
      );
    }
  }

  void _reorderColumns(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final next = List<TrackColumn>.from(_columnOrder);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    setState(() {
      _columnOrder = next;
    });
    if (widget.onColumnOrderChanged != null) {
      widget.onColumnOrderChanged!.call(next);
    } else {
      widget.preferencesService?.setUpNextColumnOrder(
        next.map((c) => c.name).toList(),
      );
    }
  }

  void _resetColumnsToDefault() {
    final nextOrder = List<TrackColumn>.from(TrackColumn.values);
    final nextVisible = Set<TrackColumn>.from(UpNextTab.defaultVisibleColumns);
    setState(() {
      _columnOrder = nextOrder;
      _visibleColumns = nextVisible;
    });
    if (widget.onColumnOrderChanged != null) {
      widget.onColumnOrderChanged!.call(nextOrder);
    } else {
      widget.preferencesService?.setUpNextColumnOrder(
        nextOrder.map((c) => c.name).toList(),
      );
    }
    if (widget.onVisibleColumnsChanged != null) {
      widget.onVisibleColumnsChanged!.call(nextVisible);
    } else {
      widget.preferencesService?.setUpNextVisibleColumns(
        nextVisible.map((c) => c.name).toSet(),
      );
    }
  }

  void _showColumnsMenu(Offset globalPosition, BuildContext context) {
    LyraContextMenuCoordinator.hideActive();
    DraggableColumnsOverlay.showAt(
      controller: _columnsOverlayController,
      positionNotifier: _columnsMenuPositionNotifier,
      globalPosition: globalPosition,
      context: context,
      estimatedCardHeight: 60.0 + _columnOrder.length * 36.0,
    );
  }

  static double _detailColumnWidth(TrackColumn col) {
    switch (col.name) {
      case 'index':
        return 34.0;
      case 'cover':
        return 48.0;
      case 'year':
        return 58.0;
      case 'trackNumber':
        return 50.0;
      case 'duration':
        return 60.0;
      case 'iswc':
      case 'isrc':
        return 110.0;
      case 'musicbrainzId':
        return 180.0;
      case 'title':
        return 150.0;
      case 'album':
      case 'work':
        return 120.0;
      case 'resolution':
        return 90.0;
      case 'genre':
        return 60.0;
      default:
        return col.width ?? 90.0;
    }
  }

  static double _requiredDetailTableWidth(
    List<TrackColumn> cols, {
    double textScale = 1.0,
  }) {
    if (cols.isEmpty) return 0.0;
    final effectiveScale = math.max(1.0, textScale);
    // Account for outer ListView horizontal padding (sm * 2) + row padding (md * 2) + column spacing
    var width = LyraSpacing.sm * 2 + LyraSpacing.md * 2;
    for (var i = 0; i < cols.length; i++) {
      final base = _detailColumnWidth(cols[i]);
      width += cols[i] == TrackColumn.cover ? base : base * effectiveScale;
      if (i > 0) width += LyraSpacing.sm;
    }
    return width;
  }

  Widget _buildListTableHeader(
    LyraThemeTokens tokens,
    List<TrackColumn> orderedVisible,
  ) {
    final showIndex = orderedVisible.contains(TrackColumn.index);
    final showCover = orderedVisible.contains(TrackColumn.cover);
    final hasResolution = orderedVisible.contains(TrackColumn.resolution);
    final hasDuration = orderedVisible.contains(TrackColumn.duration);
    final hasTrailing = hasResolution || hasDuration;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));
    final headerTextStyle = LyraTypography.small(tokens).copyWith(
      color: tokens.textMuted,
      fontWeight: FontWeight.w600,
      fontSize: 11.0,
    );

    return Container(
      key: const Key('up_next_table_header'),
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.sm + LyraSpacing.md,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceSecondary.withValues(alpha: 0.35),
        border: Border(bottom: BorderSide(color: tokens.border, width: 1.0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final indexWidth = showIndex
              ? math.min(28.0 * scale, constraints.maxWidth * 0.2)
              : 0.0;
          final leftFixedWidth =
              (showIndex ? indexWidth + LyraSpacing.xs : 0.0) +
              (showCover ? 38.0 + LyraSpacing.md : 0.0) +
              (hasTrailing ? LyraSpacing.sm : 0.0);
          final metrics = computeTrackListTrailingMetrics(
            availableRowWidth: constraints.maxWidth,
            leftFixedWidth: leftFixedWidth,
            hasResolution: hasResolution,
            hasDuration: hasDuration,
            textScale: scale,
          );
          final trailingLabels = buildTrackListTrailingHeaderLabels(
            orderedVisibleColumns: orderedVisible,
            metrics: metrics,
            style: headerTextStyle,
          );

          return Row(
            children: [
              if (showIndex) ...[
                SizedBox(
                  width: indexWidth,
                  child: Center(
                    child: Text(
                      '#',
                      style: headerTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: LyraSpacing.xs),
              ],
              if (showCover) ...[
                SizedBox(
                  width: 38.0,
                  child: Center(
                    child: Text(
                      'Cover',
                      style: headerTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: LyraSpacing.md),
              ],
              Expanded(
                child: Text(
                  'Title & Details',
                  style: headerTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingLabels.isNotEmpty) ...[
                const SizedBox(width: LyraSpacing.sm),
                ...trailingLabels,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailTableHeader(
    LyraThemeTokens tokens,
    List<TrackColumn> orderedVisible,
  ) {
    return Container(
      key: const Key('up_next_table_header'),
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.sm + LyraSpacing.md,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceSecondary.withValues(alpha: 0.35),
        border: Border(bottom: BorderSide(color: tokens.border, width: 1.0)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < orderedVisible.length; i++) ...[
            if (i > 0) const SizedBox(width: LyraSpacing.sm),
            _buildDetailHeaderCell(orderedVisible[i], tokens),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailHeaderCell(TrackColumn col, LyraThemeTokens tokens) {
    final textStyle = LyraTypography.small(tokens).copyWith(
      color: tokens.textMuted,
      fontWeight: FontWeight.w600,
      fontSize: 11.0,
    );
    final alignRight =
        col == TrackColumn.duration ||
        col == TrackColumn.year ||
        col == TrackColumn.trackNumber;
    final alignCenter = col == TrackColumn.index || col == TrackColumn.cover;
    final label = Text(
      col.headerLabel,
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignRight
          ? TextAlign.right
          : (alignCenter ? TextAlign.center : TextAlign.left),
    );

    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));
    if (col.flex != null) {
      return Expanded(flex: col.flex!, child: label);
    }
    return SizedBox(
      width: col == TrackColumn.cover
          ? _detailColumnWidth(col)
          : _detailColumnWidth(col) * scale,
      child: alignCenter ? Center(child: label) : label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final textScale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(1.0),
    );
    final queue = widget.playbackController.queue;
    final currentIndex = widget.playbackController.currentIndex;
    final orderedVisible = _orderedVisibleColumns;

    return DraggableColumnsOverlay(
      controller: _columnsOverlayController,
      positionNotifier: _columnsMenuPositionNotifier,
      estimatedCardHeight: 60.0 + _columnOrder.length * 36.0,
      cardKey: const Key('up_next_columns_window'),
      headerKey: const Key('up_next_columns_window_header'),
      resetKey: const Key('up_next_columns_reset_button'),
      closeKey: const Key('up_next_columns_close_button'),
      tokens: tokens,
      onReset: _resetColumnsToDefault,
      content: ReorderableListView.builder(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        itemCount: _columnOrder.length,
        onReorder: _reorderColumns,
        proxyDecorator: (child, index, animation) =>
            DraggableColumnsOverlay.proxyDecorator(
              child,
              index,
              animation,
              tokens,
            ),
        itemBuilder: (context, index) {
          final col = _columnOrder[index];
          return _UpNextColumnMenuItem(
            key: ValueKey('up_next_col_menu_${col.name}'),
            index: index,
            col: col,
            isChecked: _visibleColumns.contains(col),
            canToggle: !col.isMandatory,
            onToggle: () => _toggleColumn(col),
            tokens: tokens,
          );
        },
      ),
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Queue Top Header Bar (Right-clickable for attributes even when table header hidden)
            GestureDetector(
              key: const Key('up_next_top_header'),
              behavior: HitTestBehavior.opaque,
              onSecondaryTapDown: (details) =>
                  _showColumnsMenu(details.globalPosition, context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  LyraSpacing.md,
                  LyraSpacing.md,
                  LyraSpacing.md,
                  LyraSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Up next',
                                  style: LyraTypography.h4(tokens),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: LyraSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 1.0,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.secondary,
                                  borderRadius: LyraRadius.fullRadius,
                                ),
                                child: Text(
                                  '${queue.length}',
                                  style: LyraTypography.small(tokens).copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.0,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            widget.queueSource ?? 'Playing from Library',
                            style: LyraTypography.muted(
                              tokens,
                            ).copyWith(fontSize: 12.0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: LyraSpacing.sm),

                    // Shuffle Queue Toggle
                    LyraButton.ghost(
                      size: LyraButtonSize.sm,
                      width: 28.0,
                      height: 28.0,
                      padding: EdgeInsets.zero,
                      onPressed: queue.isEmpty
                          ? null
                          : () => widget.playbackController.toggleShuffle(),
                      child: Icon(
                        LucideIcons.shuffle,
                        size: 16.0,
                        color: widget.playbackController.shuffleMode
                            ? tokens.primary
                            : tokens.textMuted,
                      ),
                    ),

                    const SizedBox(width: 2.0),

                    // Clear Queue Action
                    LyraButton.ghost(
                      size: LyraButtonSize.sm,
                      width: 28.0,
                      height: 28.0,
                      padding: EdgeInsets.zero,
                      onPressed: queue.isEmpty
                          ? null
                          : () => widget.playbackController.clearQueue(),
                      child: Icon(
                        LucideIcons.trash2,
                        size: 16.0,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(height: 1.0, color: tokens.border),

            // Queue List / Detail Body or Empty State
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(LyraSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.listMusic,
                              size: 48.0,
                              color: tokens.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: LyraSpacing.md),
                            Text(
                              'Queue is empty',
                              style: LyraTypography.h4(
                                tokens,
                              ).copyWith(color: tokens.textMuted),
                            ),
                            const SizedBox(height: LyraSpacing.xs),
                            Text(
                              'Select songs from the library to start playing',
                              style: LyraTypography.muted(tokens),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isDetail = _viewMode == TrackListViewMode.detail;
                        final requiredWidth = isDetail
                            ? _requiredDetailTableWidth(
                                orderedVisible,
                                textScale: textScale,
                              )
                            : 0.0;
                        final effectiveWidth = isDetail
                            ? math.max(constraints.maxWidth, requiredWidth)
                            : constraints.maxWidth;
                        final needsHorizontalScroll =
                            isDetail && requiredWidth > constraints.maxWidth;

                        final content = SizedBox(
                          width: effectiveWidth,
                          height: constraints.maxHeight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_showHeader)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onSecondaryTapDown: (details) =>
                                      _showColumnsMenu(
                                        details.globalPosition,
                                        context,
                                      ),
                                  child: isDetail
                                      ? _buildDetailTableHeader(
                                          tokens,
                                          orderedVisible,
                                        )
                                      : _buildListTableHeader(
                                          tokens,
                                          orderedVisible,
                                        ),
                                ),
                              Expanded(
                                child:
                                    NotificationListener<
                                      ScrollStartNotification
                                    >(
                                      onNotification: (notification) {
                                        LyraContextMenuCoordinator.hideActive();
                                        return false;
                                      },
                                      child: ReorderableListView.builder(
                                        scrollController: _scrollController,
                                        itemCount: queue.length,
                                        itemExtent:
                                            (_viewMode == TrackListViewMode.list
                                                ? 64.0
                                                : 58.0) *
                                            textScale,
                                        buildDefaultDragHandles: false,
                                        proxyDecorator:
                                            (child, index, animation) =>
                                                _proxyDecorator(
                                                  child,
                                                  index,
                                                  animation,
                                                  tokens,
                                                ),
                                        onReorder: (oldIndex, newIndex) {
                                          widget.playbackController
                                              .reorderQueue(oldIndex, newIndex);
                                        },
                                        padding: const EdgeInsets.symmetric(
                                          vertical: LyraSpacing.xs,
                                          horizontal: LyraSpacing.sm,
                                        ),
                                        itemBuilder: (context, index) {
                                          final track = queue[index];
                                          final isCurrent =
                                              index == currentIndex;
                                          final queueItemIds = widget
                                              .playbackController
                                              .queueItemIds;
                                          final itemId =
                                              index < queueItemIds.length
                                              ? queueItemIds[index]
                                              : 'qi_${track.id}_$index';

                                          return _QueueItemRow(
                                            key: ValueKey('queue_item_$itemId'),
                                            track: track,
                                            index: index,
                                            isCurrent: isCurrent,
                                            canReorder: queue.length > 1,
                                            tokens: tokens,
                                            viewMode: _viewMode,
                                            orderedVisibleColumns:
                                                orderedVisible,
                                            onTap: () {
                                              widget.playbackController
                                                  .playQueueItem(index);
                                            },
                                            playbackController:
                                                widget.playbackController,
                                            onAddToPlaylist:
                                                widget.onAddToPlaylist,
                                            onInspectAudio:
                                                widget.onInspectAudio,
                                            onGoToAlbum: widget.onGoToAlbum,
                                            onGoToArtist: widget.onGoToArtist,
                                          );
                                        },
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        );

                        if (needsHorizontalScroll) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: content,
                          );
                        }
                        return content;
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
        final t = Curves.easeInOut.transform(animation.value);
        final isCurrent = index == widget.playbackController.currentIndex;

        return Material(
          color: const Color(0x00000000),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: LyraRadius.mdRadius,
              border: isCurrent
                  ? null
                  : Border.all(
                      color: tokens.border.withValues(alpha: t.clamp(0.0, 1.0)),
                      width: 1.0,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.2 * t),
                  blurRadius: 4.0 + 8.0 * t,
                  offset: Offset(0, 2.0 + 2.0 * t),
                ),
              ],
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.grabbing,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _QueueItemRow extends StatefulWidget {
  final Track track;
  final int index;
  final bool isCurrent;
  final bool canReorder;
  final LyraThemeTokens tokens;
  final TrackListViewMode viewMode;
  final List<TrackColumn> orderedVisibleColumns;
  final VoidCallback onTap;
  final PlaybackQueueController playbackController;
  final void Function(Track track)? onAddToPlaylist;
  final void Function(Track track)? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;

  const _QueueItemRow({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrent,
    this.canReorder = true,
    required this.tokens,
    required this.viewMode,
    required this.orderedVisibleColumns,
    required this.onTap,
    required this.playbackController,
    this.onAddToPlaylist,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
  });

  @override
  State<_QueueItemRow> createState() => _QueueItemRowState();
}

class _QueueItemRowState extends State<_QueueItemRow> {
  bool _isHovered = false;
  late final ShadContextMenuController _contextMenuController =
      ShadContextMenuController();

  @override
  void initState() {
    super.initState();
    _contextMenuController.addListener(_handleContextMenuChanged);
  }

  void _handleContextMenuChanged() {
    if (_contextMenuController.isOpen) {
      LyraContextMenuCoordinator.setActive(_contextMenuController);
    } else if (LyraContextMenuCoordinator.isActive(_contextMenuController)) {
      LyraContextMenuCoordinator.hideActive();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _contextMenuController.removeListener(_handleContextMenuChanged);
    LyraContextMenuCoordinator.onDisposed(_contextMenuController);
    _contextMenuController.dispose();
    super.dispose();
  }

  Widget _buildListRowContent(LyraThemeTokens tokens) {
    final track = widget.track;
    final index = widget.index;
    final isCurrent = widget.isCurrent;
    final isPlaying = isCurrent && widget.playbackController.isPlaying;
    final orderedVisible = widget.orderedVisibleColumns;
    final showIndex = orderedVisible.contains(TrackColumn.index);
    final showCover = orderedVisible.contains(TrackColumn.cover);
    final hasResolution = orderedVisible.contains(TrackColumn.resolution);
    final hasDuration = orderedVisible.contains(TrackColumn.duration);
    final hasTrailing = hasResolution || hasDuration;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));

    final subtitleStyle = LyraTypography.small(
      tokens,
    ).copyWith(color: tokens.textMuted);
    final subtitleChildren = buildTrackListSubtitleChildren(
      track,
      orderedVisible,
      subtitleStyle,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final indexWidth = showIndex
            ? math.min(28.0 * scale, constraints.maxWidth * 0.2)
            : 0.0;
        final leftFixedWidth =
            (showIndex ? indexWidth + LyraSpacing.xs : 0.0) +
            (showCover ? 38.0 + LyraSpacing.md : 0.0) +
            (hasTrailing ? LyraSpacing.sm : 0.0);
        final metrics = computeTrackListTrailingMetrics(
          availableRowWidth: constraints.maxWidth,
          leftFixedWidth: leftFixedWidth,
          hasResolution: hasResolution,
          hasDuration: hasDuration,
          textScale: scale,
        );
        final trailingChildren = buildTrackListTrailingChildren(
          track: track,
          orderedVisibleColumns: orderedVisible,
          tokens: tokens,
          onInspectAudio: widget.onInspectAudio != null
              ? () => widget.onInspectAudio!(track)
              : null,
          maxBadgeWidth: metrics.maxBadgeWidth,
          durationWidth: metrics.durationWidth,
        );

        return Row(
          children: [
            if (showIndex) ...[
              SizedBox(
                width: indexWidth,
                child: Center(
                  child: isPlaying
                      ? Icon(
                          LucideIcons.volume2,
                          size: 16.0,
                          color: tokens.primary,
                        )
                      : _isHovered
                      ? Icon(
                          LucideIcons.play,
                          size: 16.0,
                          color: isCurrent ? tokens.primary : tokens.text,
                        )
                      : Text(
                          '${index + 1}',
                          style: LyraTypography.small(tokens).copyWith(
                            color: isCurrent
                                ? tokens.primary
                                : tokens.textMuted,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              const SizedBox(width: LyraSpacing.xs),
            ],
            if (showCover) ...[
              TrackCoverThumbnail(
                track: track,
                isActive: isCurrent,
                size: 38.0,
              ),
              const SizedBox(width: LyraSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (orderedVisible.contains(TrackColumn.title))
                    Text(
                      track.displayTitle,
                      style: LyraTypography.p(tokens).copyWith(
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isCurrent ? tokens.primary : tokens.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (subtitleChildren.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Row(children: subtitleChildren),
                  ],
                ],
              ),
            ),
            if (trailingChildren.isNotEmpty) ...[
              const SizedBox(width: LyraSpacing.sm),
              ...trailingChildren,
            ],
          ],
        );
      },
    );
  }

  Widget _buildDetailRowContent(LyraThemeTokens tokens) {
    final orderedVisible = widget.orderedVisibleColumns;
    return Row(
      children: [
        for (var i = 0; i < orderedVisible.length; i++) ...[
          if (i > 0) const SizedBox(width: LyraSpacing.sm),
          _buildDetailCell(orderedVisible[i], tokens),
        ],
      ],
    );
  }

  Widget _buildDetailCell(TrackColumn col, LyraThemeTokens tokens) {
    final track = widget.track;
    final index = widget.index;
    final isCurrent = widget.isCurrent;
    final isPlaying = isCurrent && widget.playbackController.isPlaying;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1.0));
    final cellWidth =
        _UpNextTabState._detailColumnWidth(col) *
        (col == TrackColumn.cover ? 1.0 : scale);

    Widget content;
    switch (col.name) {
      case 'index':
        content = Center(
          child: isPlaying
              ? Icon(LucideIcons.volume2, size: 16.0, color: tokens.primary)
              : _isHovered
              ? Icon(
                  LucideIcons.play,
                  size: 16.0,
                  color: isCurrent ? tokens.primary : tokens.text,
                )
              : Text(
                  '${index + 1}',
                  style: LyraTypography.small(tokens).copyWith(
                    color: isCurrent ? tokens.primary : tokens.textMuted,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        );
        break;
      case 'cover':
        content = Center(
          child: TrackCoverThumbnail(
            track: track,
            isActive: isCurrent,
            size: 30.0,
            borderRadius: 4.0,
          ),
        );
        break;
      case 'title':
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              track.displayTitle,
              style: LyraTypography.p(tokens).copyWith(
                fontSize: 13.0,
                height: 1.25,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                color: isCurrent ? tokens.primary : tokens.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (track.artist.trim().isNotEmpty)
              Text(
                track.artist,
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontSize: 11.0,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        );
        break;
      case 'album':
        content = Text(
          track.album.trim().isNotEmpty ? track.album : '-',
          style: LyraTypography.small(tokens).copyWith(color: tokens.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'resolution':
        final badge = LyraBadge.outline(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          child: Text(
            track.formattedQuality,
            style: LyraTypography.small(
              tokens,
            ).copyWith(fontSize: 10.0, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
        content = Align(
          alignment: Alignment.centerLeft,
          child: widget.onInspectAudio != null
              ? MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onInspectAudio!(track),
                    child: badge,
                  ),
                )
              : badge,
        );
        break;
      case 'work':
        content = Text(
          track.workTitle?.trim().isNotEmpty == true ? track.workTitle! : '-',
          style: LyraTypography.small(tokens).copyWith(color: tokens.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'year':
        content = Text(
          track.year != null && track.year! > 0 ? '${track.year}' : '-',
          style: LyraTypography.small(tokens).copyWith(color: tokens.textMuted),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'genre':
        content = Text(
          track.genre?.trim().isNotEmpty == true ? track.genre! : '-',
          style: LyraTypography.small(tokens).copyWith(color: tokens.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'iswc':
        content = Text(
          track.iswc?.trim().isNotEmpty == true ? track.iswc! : '-',
          style: LyraTypography.mono(
            tokens,
            fontSize: 11.0,
          ).copyWith(color: tokens.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'isrc':
        content = Text(
          track.isrc?.trim().isNotEmpty == true ? track.isrc! : '-',
          style: LyraTypography.mono(
            tokens,
            fontSize: 11.0,
          ).copyWith(color: tokens.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'musicbrainzId':
        content = Text(
          track.musicBrainzId?.trim().isNotEmpty == true
              ? track.musicBrainzId!
              : '-',
          style: LyraTypography.mono(
            tokens,
            fontSize: 11.0,
          ).copyWith(color: tokens.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'trackNumber':
        content = Text(
          track.trackNumber != null && track.trackNumber! > 0
              ? '${track.trackNumber}'
              : '-',
          style: LyraTypography.small(tokens).copyWith(color: tokens.textMuted),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
      case 'duration':
      default:
        content = Text(
          track.formattedDuration,
          style: LyraTypography.small(
            tokens,
          ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.w500),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        break;
    }

    if (col.flex != null) {
      return Expanded(flex: col.flex!, child: content);
    }
    return SizedBox(width: cellWidth, child: content);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final track = widget.track;
    final index = widget.index;
    final isCurrent = widget.isCurrent;
    final onTap = widget.onTap;

    return RepaintBoundary(
      child: ThresholdReorderableDragStartListener(
        index: index,
        enabled: widget.canReorder,
        child: ShadContextMenuRegion(
          controller: _contextMenuController,
          tapEnabled: false,
          constraints: const BoxConstraints(minWidth: 180),
          popoverReverseDuration: const Duration(milliseconds: 50),
          items: [
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.play, size: 16.0),
              onPressed: () {
                widget.playbackController.playQueueItem(index);
              },
              child: const Text('Play Now'),
            ),
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.listStart, size: 16.0),
              onPressed: () {
                widget.playbackController.playNext(track);
              },
              child: const Text('Play Next'),
            ),
            if (widget.onAddToPlaylist != null)
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.folderPlus, size: 16.0),
                onPressed: () {
                  widget.onAddToPlaylist!(track);
                },
                child: const Text('Add to Playlist...'),
              ),
            if (widget.onGoToAlbum != null && track.album.trim().isNotEmpty)
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.disc, size: 16.0),
                onPressed: () {
                  widget.onGoToAlbum!(track.album);
                },
                child: const Text('Go to Album'),
              ),
            if (widget.onGoToArtist != null && track.artist.trim().isNotEmpty)
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.mic2, size: 16.0),
                onPressed: () {
                  widget.onGoToArtist!(track.artist);
                },
                child: const Text('Go to Artist'),
              ),
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.trash2, size: 16.0),
              onPressed: () {
                widget.playbackController.removeFromQueue(index);
              },
              child: const Text('Remove from Queue'),
            ),
            if (widget.onInspectAudio != null)
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.info, size: 16.0),
                onPressed: () {
                  widget.onInspectAudio!(track);
                },
                child: const Text('Inspect Audio...'),
              ),
          ],
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTap: () {
                LyraContextMenuCoordinator.hideActive();
                onTap();
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.symmetric(
                  horizontal: LyraSpacing.md,
                  vertical: widget.viewMode == TrackListViewMode.list
                      ? 8.0
                      : 6.0,
                ),
                margin: const EdgeInsets.symmetric(vertical: 2.0),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? ((_isHovered || _contextMenuController.isOpen)
                            ? tokens.secondary.withValues(alpha: 0.65)
                            : tokens.secondary.withValues(alpha: 0.35))
                      : ((_isHovered || _contextMenuController.isOpen)
                            ? tokens.secondary.withValues(alpha: 0.5)
                            : tokens.secondary.withValues(alpha: 0.0)),
                  borderRadius: LyraRadius.mdRadius,
                  border: isCurrent
                      ? Border.all(color: tokens.border, width: 1.0)
                      : null,
                ),
                child: widget.viewMode == TrackListViewMode.list
                    ? _buildListRowContent(tokens)
                    : _buildDetailRowContent(tokens),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpNextColumnMenuItem extends StatefulWidget {
  final int index;
  final TrackColumn col;
  final bool isChecked;
  final bool canToggle;
  final VoidCallback onToggle;
  final LyraThemeTokens tokens;

  const _UpNextColumnMenuItem({
    super.key,
    required this.index,
    required this.col,
    required this.isChecked,
    required this.canToggle,
    required this.onToggle,
    required this.tokens,
  });

  @override
  State<_UpNextColumnMenuItem> createState() => _UpNextColumnMenuItemState();
}

class _UpNextColumnMenuItemState extends State<_UpNextColumnMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final col = widget.col;
    final tokens = widget.tokens;

    return Material(
      color: const Color(0x00000000),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: _isHovered
                ? tokens.secondary.withValues(alpha: 0.55)
                : const Color(0x00000000),
            borderRadius: LyraRadius.smRadius,
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
                      vertical: 2.0,
                    ),
                    child: Icon(
                      LucideIcons.gripVertical,
                      size: 14.0,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.canToggle ? widget.onToggle : null,
                  child: Row(
                    children: [
                      LyraCheckbox(
                        key: Key('up_next_col_checkbox_${col.name}'),
                        value: widget.isChecked,
                        enabled: widget.canToggle,
                        onChanged: widget.canToggle
                            ? (_) => widget.onToggle()
                            : null,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          col.label,
                          style: LyraTypography.small(tokens).copyWith(
                            color: widget.canToggle
                                ? tokens.text
                                : tokens.textMuted,
                            fontWeight: widget.isChecked
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!widget.canToggle) ...[
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
      ),
    );
  }
}
