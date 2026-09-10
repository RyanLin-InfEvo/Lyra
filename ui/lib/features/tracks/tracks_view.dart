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
import '../models/track.dart';

/// Columns available in the Tracks table.
class TrackColumn {
  final String name;
  final String headerLabel;
  final String label;
  final double? width;
  final int? flex;
  final bool isMandatory;
  final bool defaultVisible;

  const TrackColumn._({
    required this.name,
    required this.headerLabel,
    required this.label,
    this.width,
    this.flex,
    this.isMandatory = false,
    this.defaultVisible = true,
  });

  static const TrackColumn index = TrackColumn._(
    name: 'index',
    headerLabel: '#',
    label: 'Track Number',
    width: 40.0,
  );

  static const TrackColumn title = TrackColumn._(
    name: 'title',
    headerLabel: 'TITLE & ARTIST',
    label: 'Title & Artist',
    flex: 5,
    isMandatory: true,
  );

  static const TrackColumn album = TrackColumn._(
    name: 'album',
    headerLabel: 'ALBUM',
    label: 'Album',
    flex: 4,
  );

  /// Best resolution format badge (e.g. 24-bit/96kHz) and audio version count.
  static const TrackColumn resolution = TrackColumn._(
    name: 'resolution',
    headerLabel: 'RESOLUTION',
    label: 'Resolution',
    flex: 3,
  );

  static const TrackColumn duration = TrackColumn._(
    name: 'duration',
    headerLabel: 'TIME',
    label: 'TIME',
    width: 76.0,
  );

  static const TrackColumn work = TrackColumn._(
    name: 'work',
    headerLabel: 'WORK',
    label: 'Work / Composition',
    flex: 4,
    defaultVisible: false,
  );

  static const TrackColumn iswc = TrackColumn._(
    name: 'iswc',
    headerLabel: 'ISWC',
    label: 'ISWC',
    width: 140.0,
    defaultVisible: false,
  );

  static const TrackColumn year = TrackColumn._(
    name: 'year',
    headerLabel: 'YEAR',
    label: 'Year Date',
    width: 60.0,
    defaultVisible: false,
  );

  static const TrackColumn musicbrainzId = TrackColumn._(
    name: 'musicbrainzId',
    headerLabel: 'MUSICBRAINZ ID',
    label: 'MusicBrainz ID',
    flex: 3,
    defaultVisible: false,
  );

  static const TrackColumn isrc = TrackColumn._(
    name: 'isrc',
    headerLabel: 'ISRC',
    label: 'ISRC',
    width: 130.0,
    defaultVisible: false,
  );

  static const TrackColumn genre = TrackColumn._(
    name: 'genre',
    headerLabel: 'GENRE',
    label: 'Genre',
    flex: 2,
    defaultVisible: false,
  );

  static const TrackColumn trackNumber = TrackColumn._(
    name: 'trackNumber',
    headerLabel: 'TRK#',
    label: 'Track #',
    width: 50.0,
    defaultVisible: false,
  );

  static const List<TrackColumn> values = [
    index,
    title,
    album,
    resolution,
    work,
    year,
    genre,
    iswc,
    isrc,
    musicbrainzId,
    trackNumber,
    duration,
  ];

  static final Set<TrackColumn> defaultVisibleColumns = {
    index,
    title,
    album,
    resolution,
    duration,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackColumn &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'TrackColumn.$name';
}

/// High-density tracks table view with audiophile format badges.
class TracksView extends StatefulWidget {
  final List<Track> tracks;
  final Track? currentTrack;
  final bool isPlaying;
  final ValueChanged<Track> onTrackSelected;
  final VoidCallback onTogglePlay;
  final ValueChanged<Track>? onInspectTrack;
  final ValueChanged<Track>? onInspectAudio;
  final Map<String, int>? audioVersionCounts;
  final String? filterLabel;
  final VoidCallback? onClearFilter;
  final Set<TrackColumn>? visibleColumns;
  final ValueChanged<Set<TrackColumn>>? onVisibleColumnsChanged;
  final List<TrackColumn>? columnOrder;
  final ValueChanged<List<TrackColumn>>? onColumnOrderChanged;

  const TracksView({
    super.key,
    required this.tracks,
    required this.currentTrack,
    required this.isPlaying,
    required this.onTrackSelected,
    required this.onTogglePlay,
    this.onInspectTrack,
    this.onInspectAudio,
    this.audioVersionCounts,
    this.filterLabel,
    this.onClearFilter,
    this.visibleColumns,
    this.onVisibleColumnsChanged,
    this.columnOrder,
    this.onColumnOrderChanged,
  });

  @override
  State<TracksView> createState() => _TracksViewState();
}

class _TracksViewState extends State<TracksView> {
  late List<TrackColumn> _internalColumnOrder;
  late Set<TrackColumn> _internalVisibleColumns;
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
  void didUpdateWidget(covariant TracksView oldWidget) {
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

  static List<TrackColumn> _normalizeColumnOrder(List<TrackColumn>? order) {
    if (order == null || order.isEmpty) {
      return List<TrackColumn>.from(TrackColumn.values);
    }
    final normalized = <TrackColumn>[];
    for (final col in order) {
      if (TrackColumn.values.contains(col) && !normalized.contains(col)) {
        normalized.add(col);
      }
    }
    for (final col in TrackColumn.values) {
      if (!normalized.contains(col)) {
        normalized.add(col);
      }
    }
    return normalized;
  }

  static Set<TrackColumn> _normalizeVisibleColumns(Set<TrackColumn>? visible) {
    if (visible == null || visible.isEmpty) {
      return Set<TrackColumn>.from(TrackColumn.defaultVisibleColumns);
    }
    final normalized = Set<TrackColumn>.from(visible);
    for (final col in TrackColumn.values) {
      if (col.isMandatory) {
        normalized.add(col);
      }
    }
    return normalized;
  }

  List<TrackColumn> get _effectiveColumnOrder => _internalColumnOrder;
  Set<TrackColumn> get _effectiveVisibleColumns => _internalVisibleColumns;

  void _toggleColumn(TrackColumn column) {
    if (column.isMandatory) return;
    final current = Set<TrackColumn>.from(_internalVisibleColumns);
    if (current.contains(column)) {
      if (current.length > 1) {
        current.remove(column);
      } else {
        return;
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
    final newOrder = List<TrackColumn>.from(_internalColumnOrder);
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);
    widget.onColumnOrderChanged?.call(newOrder);
    setState(() {
      _internalColumnOrder = newOrder;
    });
  }

  void _resetColumns() {
    final defaultOrder = List<TrackColumn>.from(TrackColumn.values);
    final defaultVisible = Set<TrackColumn>.from(
      TrackColumn.defaultVisibleColumns,
    );
    widget.onColumnOrderChanged?.call(defaultOrder);
    widget.onVisibleColumnsChanged?.call(defaultVisible);
    setState(() {
      _internalColumnOrder = defaultOrder;
      _internalVisibleColumns = defaultVisible;
    });
  }

  Widget _buildHeaderCell(TrackColumn col, LyraThemeTokens tokens) {
    Widget child;
    if (col == TrackColumn.duration) {
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
    } else if (col == TrackColumn.index) {
      child = Align(
        alignment: Alignment.centerLeft,
        child: Text(
          col.headerLabel,
          style: LyraTypography.small(
            tokens,
          ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.bold),
        ),
      );
    } else if (col == TrackColumn.trackNumber) {
      child = Align(
        alignment: Alignment.centerLeft,
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

    if (widget.tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.searchX, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text(
              widget.filterLabel != null
                  ? 'No matching tracks found'
                  : 'No tracks found',
              style: LyraTypography.h3(tokens),
            ),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              widget.filterLabel != null
                  ? 'No tracks found matching "${widget.filterLabel}".'
                  : 'Try adjusting your search query or import new audio files.',
              style: LyraTypography.muted(tokens),
            ),
            if (widget.filterLabel != null && widget.onClearFilter != null) ...[
              const SizedBox(height: LyraSpacing.md),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onClearFilter,
                  child: LyraBadge.secondary(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(LucideIcons.x, size: 12.0),
                        SizedBox(width: 4.0),
                        Text('Clear filter'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // View Header
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
                  Text('Tracks Library', style: LyraTypography.h2(tokens)),
                  const SizedBox(height: LyraSpacing.xs),
                  Text(
                    '${widget.tracks.length} tracks',
                    style: LyraTypography.muted(tokens),
                  ),
                ],
              ),
              if (widget.filterLabel != null) ...[
                const SizedBox(width: LyraSpacing.lg),
                LyraBadge.secondary(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.filterLabel!,
                        style: LyraTypography.small(
                          tokens,
                        ).copyWith(fontSize: 11.0, fontWeight: FontWeight.w500),
                      ),
                      if (widget.onClearFilter != null) ...[
                        const SizedBox(width: 6.0),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onClearFilter,
                            child: Icon(
                              LucideIcons.x,
                              size: 12.0,
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Table Header with Draggable Floating Columns Window
        DraggableColumnsOverlay(
          key: const Key('tracks_table_header_context_menu'),
          controller: _columnsOverlayController,
          positionNotifier: _columnsPositionNotifier,
          estimatedCardHeight: 60.0 + _effectiveColumnOrder.length * 36.0,
          onReset: _resetColumns,
          cardKey: const Key('tracks_columns_window'),
          headerKey: const Key('tracks_columns_window_header'),
          resetKey: const Key('tracks_columns_reset_button'),
          closeKey: const Key('tracks_columns_close_button'),
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
              final canToggle =
                  !col.isMandatory &&
                  (!isVisible || _effectiveVisibleColumns.length > 1);
              return _TrackColumnMenuItem(
                key: Key('track_col_menu_${col.name}'),
                index: index,
                col: col,
                isVisible: isVisible,
                canToggle: canToggle,
                tokens: tokens,
                onToggle: () => _toggleColumn(col),
              );
            },
          ),
          child: Container(
            key: const Key('tracks_table_header'),
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
            itemCount: widget.tracks.length,
            itemExtent: 56.0,
            itemBuilder: (context, index) {
              final track = widget.tracks[index];
              final isCurrent = widget.currentTrack?.id == track.id;
              final versionCount =
                  widget.audioVersionCounts?[track.id] ??
                  widget.audioVersionCounts?[track.pcmHash] ??
                  1;

              return _TrackRow(
                index: index + 1,
                track: track,
                isCurrent: isCurrent,
                isPlaying: isCurrent && widget.isPlaying,
                versionCount: versionCount,
                columnOrder: _effectiveColumnOrder,
                visibleColumns: _effectiveVisibleColumns,
                onTap: () {
                  if (isCurrent) {
                    widget.onTogglePlay();
                  } else {
                    widget.onTrackSelected(track);
                  }
                },
                onInspect: widget.onInspectTrack != null
                    ? () => widget.onInspectTrack!(track)
                    : null,
                onInspectAudio: widget.onInspectAudio != null
                    ? () => widget.onInspectAudio!(track)
                    : (widget.onInspectTrack != null
                          ? () => widget.onInspectTrack!(track)
                          : null),
                tokens: tokens,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrackColumnMenuItem extends StatefulWidget {
  final int index;
  final TrackColumn col;
  final bool isVisible;
  final bool canToggle;
  final LyraThemeTokens tokens;
  final VoidCallback onToggle;

  const _TrackColumnMenuItem({
    super.key,
    required this.index,
    required this.col,
    required this.isVisible,
    this.canToggle = true,
    required this.tokens,
    required this.onToggle,
  });

  @override
  State<_TrackColumnMenuItem> createState() => _TrackColumnMenuItemState();
}

class _TrackColumnMenuItemState extends State<_TrackColumnMenuItem> {
  bool _isHovered = false;
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.isVisible;
  }

  @override
  void didUpdateWidget(covariant _TrackColumnMenuItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isChecked != widget.isVisible) {
      _isChecked = widget.isVisible;
    }
  }

  void _handleToggle() {
    if (!widget.canToggle) return;
    setState(() {
      _isChecked = !_isChecked;
    });
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final col = widget.col;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.canToggle
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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
                onTap: widget.canToggle ? _handleToggle : null,
                child: Row(
                  children: [
                    IgnorePointer(
                      child: ShadCheckbox(
                        key: Key('track_col_checkbox_${col.name}'),
                        value: _isChecked,
                        enabled: widget.canToggle,
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

/// Single row item in the Tracks table.
class _TrackRow extends StatefulWidget {
  final int index;
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final int versionCount;
  final VoidCallback onTap;
  final VoidCallback? onInspect;
  final VoidCallback? onInspectAudio;
  final LyraThemeTokens tokens;
  final List<TrackColumn> columnOrder;
  final Set<TrackColumn> visibleColumns;

  const _TrackRow({
    required this.index,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    this.versionCount = 1,
    required this.onTap,
    this.onInspect,
    this.onInspectAudio,
    required this.tokens,
    required this.columnOrder,
    required this.visibleColumns,
  });

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _isHovered = false;

  Widget _buildRowCell(TrackColumn col, LyraThemeTokens tokens) {
    switch (col.name) {
      case 'index':
        return SizedBox(
          width: col.width ?? 40.0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _isHovered || widget.isPlaying
                ? Icon(
                    widget.isPlaying ? LucideIcons.volume2 : LucideIcons.play,
                    size: 16.0,
                    color: widget.isCurrent ? tokens.primary : tokens.text,
                  )
                : Text(
                    '${widget.index}',
                    style: LyraTypography.small(tokens).copyWith(
                      color: widget.isCurrent
                          ? tokens.primary
                          : tokens.textMuted,
                      fontWeight: widget.isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
          ),
        );
      case 'trackNumber':
        return SizedBox(
          width: col.width ?? 50.0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                widget.track.trackNumber != null
                    ? '${widget.track.trackNumber}'
                    : '-',
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.textMuted),
              ),
            ),
          ),
        );
      case 'title':
        return Expanded(
          flex: col.flex ?? 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.track.displayTitle,
                  style: LyraTypography.p(tokens).copyWith(
                    fontWeight: widget.isCurrent
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: widget.isCurrent ? tokens.primary : tokens.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.track.artist,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      case 'work':
        return Expanded(
          flex: col.flex ?? 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.track.workTitle ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'album':
        return Expanded(
          flex: col.flex ?? 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.track.album,
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'resolution':
        return Expanded(
          flex: col.flex ?? 3,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: MouseRegion(
                      cursor:
                          (widget.onInspectAudio ?? widget.onInspect) != null
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onInspectAudio ?? widget.onInspect,
                        child: LyraBadge.secondary(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          child: Text(
                            widget.versionCount > 1
                                ? '${widget.track.formattedQuality} · ${widget.versionCount} versions'
                                : widget.track.formattedQuality,
                            style: LyraTypography.small(tokens).copyWith(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.onInspectAudio != null ||
                      widget.onInspect != null) ...[
                    const SizedBox(width: 4.0),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onInspectAudio ?? widget.onInspect,
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(
                            LucideIcons.info,
                            size: 14.0,
                            color: _isHovered
                                ? tokens.primary
                                : tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      case 'duration':
        return SizedBox(
          width: col.width ?? 76.0,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                widget.track.formattedDuration,
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.textMuted),
              ),
            ),
          ),
        );
      case 'year':
        return SizedBox(
          width: col.width ?? 60.0,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.track.year != null ? '${widget.track.year}' : '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'iswc':
        return SizedBox(
          width: col.width ?? 140.0,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: widget.track.iswc != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: LyraBadge.outline(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      child: Text(
                        widget.track.iswc!,
                        style: LyraTypography.mono(tokens, fontSize: 10.0),
                        overflow: TextOverflow.ellipsis,
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
      case 'isrc':
        return SizedBox(
          width: col.width ?? 130.0,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: widget.track.isrc != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: LyraBadge.outline(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      child: Text(
                        widget.track.isrc!,
                        style: LyraTypography.mono(tokens, fontSize: 10.0),
                        overflow: TextOverflow.ellipsis,
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
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: widget.track.musicbrainzId != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: LyraBadge.outline(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      child: Text(
                        widget.track.musicbrainzId!,
                        style: LyraTypography.mono(tokens, fontSize: 10.0),
                        overflow: TextOverflow.ellipsis,
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
      case 'genre':
        return Expanded(
          flex: col.flex ?? 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              widget.track.genre ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCell(TrackColumn col, LyraThemeTokens tokens) =>
      _buildRowCell(col, tokens);

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onSecondaryTap: widget.onInspectAudio ?? widget.onInspect,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.xl,
              vertical: LyraSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: widget.isCurrent
                  ? tokens.secondary
                  : _isHovered
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
                    _buildCell(col, tokens),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
