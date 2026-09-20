// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart'
    show
        ClampingScrollPhysics,
        Material,
        ReorderableDragStartListener,
        ReorderableListView;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_copy_button.dart';
import '../../widgets/draggable_columns_overlay.dart';
import '../../widgets/threshold_reorderable_drag_start_listener.dart';
import '../common/context_menu_coordinator.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../player/controllers/playback_queue_controller.dart';
import '../tracks/tracks_view.dart';

export '../tracks/tracks_view.dart' show TrackColumn;

/// Detailed view for a single playlist, featuring metadata header, playback actions,
/// and reorderable track list with context menu support and customizable table columns.
class PlaylistDetailView extends StatefulWidget {
  final Playlist playlist;
  final List<Track> tracks;
  final VoidCallback onBack;
  final PlaybackQueueController? playbackController;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffleAll;
  final ValueChanged<Track>? onTrackSelected;
  final ValueChanged<Track>? onPlayNext;
  final ValueChanged<Track>? onAddToQueue;
  final void Function(int index, Track track)? onRemoveTrack;
  final void Function(int oldIndex, int newIndex)? onReorderTracks;
  final ValueChanged<Track>? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;
  final Track? currentTrack;
  final bool isPlaying;
  final Set<TrackColumn>? visibleColumns;
  final ValueChanged<Set<TrackColumn>>? onVisibleColumnsChanged;
  final List<TrackColumn>? columnOrder;
  final ValueChanged<List<TrackColumn>>? onColumnOrderChanged;

  static final Set<TrackColumn> defaultVisibleColumns = {
    TrackColumn.index,
    TrackColumn.title,
    TrackColumn.album,
    TrackColumn.duration,
  };

  const PlaylistDetailView({
    super.key,
    required this.playlist,
    required this.tracks,
    required this.onBack,
    this.playbackController,
    this.onPlayAll,
    this.onShuffleAll,
    this.onTrackSelected,
    this.onPlayNext,
    this.onAddToQueue,
    this.onRemoveTrack,
    this.onReorderTracks,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
    this.currentTrack,
    this.isPlaying = false,
    this.visibleColumns,
    this.onVisibleColumnsChanged,
    this.columnOrder,
    this.onColumnOrderChanged,
  });

  @override
  State<PlaylistDetailView> createState() => _PlaylistDetailViewState();
}

class _PlaylistDetailViewState extends State<PlaylistDetailView> {
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
  void didUpdateWidget(covariant PlaylistDetailView oldWidget) {
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
      return Set<TrackColumn>.from(PlaylistDetailView.defaultVisibleColumns);
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
      PlaylistDetailView.defaultVisibleColumns,
    );
    widget.onColumnOrderChanged?.call(defaultOrder);
    widget.onVisibleColumnsChanged?.call(defaultVisible);
    setState(() {
      _internalColumnOrder = defaultOrder;
      _internalVisibleColumns = defaultVisible;
    });
  }

  void _handlePlayAll() {
    if (widget.onPlayAll != null) {
      widget.onPlayAll!();
    } else if (widget.playbackController != null && widget.tracks.isNotEmpty) {
      widget.playbackController!.play(
        widget.tracks.first,
        contextQueue: widget.tracks,
      );
    }
  }

  void _handleShuffleAll() {
    if (widget.onShuffleAll != null) {
      widget.onShuffleAll!();
    } else if (widget.playbackController != null && widget.tracks.isNotEmpty) {
      final shuffled = List<Track>.from(widget.tracks)..shuffle();
      widget.playbackController!.play(shuffled.first, contextQueue: shuffled);
    }
  }

  void _handlePlayTrack(Track track) {
    if (widget.onTrackSelected != null) {
      widget.onTrackSelected!(track);
    } else if (widget.playbackController != null) {
      widget.playbackController!.play(track, contextQueue: widget.tracks);
    }
  }

  void _handlePlayNext(Track track) {
    if (widget.onPlayNext != null) {
      widget.onPlayNext!(track);
    } else if (widget.playbackController != null) {
      widget.playbackController!.playNext(track);
    }
  }

  void _handleAddToQueue(Track track) {
    if (widget.onAddToQueue != null) {
      widget.onAddToQueue!(track);
    } else if (widget.playbackController != null) {
      widget.playbackController!.addToQueue(track);
    }
  }

  String _formatTotalDuration(List<Track> tracks) {
    final totalMs = tracks.fold<int>(
      0,
      (sum, track) => sum + (track.durationMs ?? 0),
    );
    if (totalMs <= 0) return '0 min';
    final totalSeconds = totalMs ~/ 1000;
    final totalMinutes = totalSeconds ~/ 60;
    final hours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;

    if (hours > 0) {
      if (remainingMinutes > 0) {
        return '$hours hr $remainingMinutes min';
      }
      return '$hours hr';
    }
    if (totalMinutes > 0) {
      return '$totalMinutes min';
    }
    return '$totalSeconds sec';
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
        return Material(
          color: const Color(0x00000000),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: LyraRadius.mdRadius,
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

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, tokens),
          if (widget.tracks.isNotEmpty) _buildTableHeader(tokens),
          if (widget.tracks.isEmpty)
            _buildEmptyState(tokens)
          else
            _buildTracksList(context, tokens),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LyraThemeTokens tokens) {
    final hasDescription =
        widget.playlist.description != null &&
        widget.playlist.description!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.xl,
        vertical: LyraSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back navigation button
          LyraButton.ghost(
            key: const Key('playlist_detail_back_button'),
            size: LyraButtonSize.sm,
            onPressed: widget.onBack,
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.sm,
              vertical: LyraSpacing.xs,
            ),
            leading: const Icon(LucideIcons.arrowLeft, size: 16.0),
            child: const Text('Playlists'),
          ),
          const SizedBox(height: LyraSpacing.md),

          // Playlist Artwork + Meta row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Artwork placeholder
              Container(
                width: 140.0,
                height: 140.0,
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: LyraRadius.lgRadius,
                  border: Border.all(color: tokens.border, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x1A000000),
                      blurRadius: 12.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.listMusic,
                    size: 56.0,
                    color: tokens.primary,
                  ),
                ),
              ),
              const SizedBox(width: LyraSpacing.xl),

              // Metadata & Actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PLAYLIST',
                      style: LyraTypography.small(tokens).copyWith(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      widget.playlist.displayTitle,
                      style: LyraTypography.h2(tokens),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasDescription) ...[
                      const SizedBox(height: 6.0),
                      Text(
                        widget.playlist.description!,
                        style: LyraTypography.muted(tokens),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8.0),
                    // Metadata summary row
                    Row(
                      children: [
                        Text(
                          '${widget.tracks.length} ${widget.tracks.length == 1 ? 'track' : 'tracks'}',
                          style: LyraTypography.small(tokens).copyWith(
                            color: tokens.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: LyraTypography.small(
                            tokens,
                          ).copyWith(color: tokens.textMuted),
                        ),
                        Text(
                          _formatTotalDuration(widget.tracks),
                          style: LyraTypography.small(tokens).copyWith(
                            color: tokens.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LyraSpacing.md),
                    // Action buttons: Play All, Shuffle All
                    Row(
                      children: [
                        LyraButton(
                          key: const Key('playlist_play_all_button'),
                          size: LyraButtonSize.sm,
                          onPressed: widget.tracks.isEmpty
                              ? null
                              : _handlePlayAll,
                          leading: const Icon(LucideIcons.play, size: 16.0),
                          child: const Text('Play All'),
                        ),
                        const SizedBox(width: LyraSpacing.sm),
                        LyraButton.outline(
                          key: const Key('playlist_shuffle_all_button'),
                          size: LyraButtonSize.sm,
                          onPressed: widget.tracks.isEmpty
                              ? null
                              : _handleShuffleAll,
                          leading: const Icon(LucideIcons.shuffle, size: 16.0),
                          child: const Text('Shuffle All'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(TrackColumn col, LyraThemeTokens tokens) {
    Widget cellContent;
    final headerTextStyle = LyraTypography.small(
      tokens,
    ).copyWith(color: tokens.textMuted, fontWeight: FontWeight.w600);

    if (col == TrackColumn.index) {
      cellContent = Align(
        alignment: Alignment.centerLeft,
        child: Text(col.headerLabel, style: headerTextStyle),
      );
    } else if (col == TrackColumn.duration ||
        col == TrackColumn.trackNumber ||
        col == TrackColumn.year) {
      cellContent = Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text(
            col.headerLabel,
            style: headerTextStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else {
      cellContent = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text(
            col.headerLabel,
            style: headerTextStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (col.width != null) {
      return SizedBox(width: col.width, child: cellContent);
    } else {
      return Expanded(flex: col.flex ?? 1, child: cellContent);
    }
  }

  Widget _buildTableHeader(LyraThemeTokens tokens) {
    return DraggableColumnsOverlay(
      key: const Key('playlist_tracks_table_header_context_menu'),
      controller: _columnsOverlayController,
      positionNotifier: _columnsPositionNotifier,
      estimatedCardHeight: 60.0 + _effectiveColumnOrder.length * 36.0,
      onReset: _resetColumns,
      cardKey: const Key('playlist_tracks_columns_window'),
      headerKey: const Key('playlist_tracks_columns_window_header'),
      resetKey: const Key('playlist_tracks_columns_reset_button'),
      closeKey: const Key('playlist_tracks_columns_close_button'),
      tokens: tokens,
      content: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) =>
            DraggableColumnsOverlay.proxyDecorator(
              child,
              index,
              animation,
              tokens,
            ),
        itemCount: _effectiveColumnOrder.length,
        onReorder: _onReorder,
        itemBuilder: (context, index) {
          final col = _effectiveColumnOrder[index];
          final isVisible = _effectiveVisibleColumns.contains(col);
          final canToggle =
              !col.isMandatory &&
              (!isVisible || _effectiveVisibleColumns.length > 1);
          return _PlaylistColumnMenuItem(
            key: Key('playlist_track_col_menu_${col.name}'),
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
        key: const Key('playlist_tracks_table_header'),
        padding: const EdgeInsets.symmetric(
          horizontal: LyraSpacing.xl,
          vertical: LyraSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tokens.background,
          border: Border(bottom: BorderSide(color: tokens.border, width: 1.0)),
        ),
        child: Row(
          children: [
            for (final col in _effectiveColumnOrder)
              if (_effectiveVisibleColumns.contains(col))
                _buildHeaderCell(col, tokens),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(LyraThemeTokens tokens) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(LyraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.listMusic, size: 48.0, color: tokens.textMuted),
              const SizedBox(height: LyraSpacing.md),
              Text(
                'No tracks in this playlist',
                style: LyraTypography.h3(tokens),
              ),
              const SizedBox(height: LyraSpacing.xs),
              Text(
                'Add tracks to this playlist from your library.',
                style: LyraTypography.muted(tokens),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTracksList(BuildContext context, LyraThemeTokens tokens) {
    final itemKeys = <Key>[];
    final countMap = <String, int>{};
    for (var i = 0; i < widget.tracks.length; i++) {
      final id = widget.tracks[i].id;
      final count = countMap.update(id, (v) => v + 1, ifAbsent: () => 0);
      itemKeys.add(ValueKey('playlist_track_${id}_$count'));
    }

    return Expanded(
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          LyraContextMenuCoordinator.hideActive();
          return false;
        },
        child: ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
          buildDefaultDragHandles: false,
          itemCount: widget.tracks.length,
          itemExtent: 56.0,
          proxyDecorator: (child, index, animation) =>
              _proxyDecorator(child, index, animation, tokens),
          onReorder: (oldIndex, newIndex) {
            widget.onReorderTracks?.call(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final track = widget.tracks[index];
            final isCurrent = widget.currentTrack?.id == track.id;
            final isPlaying = isCurrent && widget.isPlaying;

            return _PlaylistTrackRow(
              key: itemKeys[index],
              index: index,
              track: track,
              isCurrent: isCurrent,
              isPlaying: isPlaying,
              columnOrder: _effectiveColumnOrder,
              visibleColumns: _effectiveVisibleColumns,
              tokens: tokens,
              canReorder: widget.tracks.length > 1,
              onTap: () => _handlePlayTrack(track),
              onPlayNow: () => _handlePlayTrack(track),
              onPlayNext: () => _handlePlayNext(track),
              onAddToQueue: () => _handleAddToQueue(track),
              onRemove: widget.onRemoveTrack != null
                  ? () => widget.onRemoveTrack!(index, track)
                  : null,
              onInspectAudio: widget.onInspectAudio != null
                  ? () => widget.onInspectAudio!(track)
                  : null,
              onGoToAlbum: widget.onGoToAlbum,
              onGoToArtist: widget.onGoToArtist,
            );
          },
        ),
      ),
    );
  }
}

class _PlaylistTrackRow extends StatefulWidget {
  final int index;
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final List<TrackColumn> columnOrder;
  final Set<TrackColumn> visibleColumns;
  final LyraThemeTokens tokens;
  final bool canReorder;
  final VoidCallback onTap;
  final VoidCallback onPlayNow;
  final VoidCallback onPlayNext;
  final VoidCallback onAddToQueue;
  final VoidCallback? onRemove;
  final VoidCallback? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;

  const _PlaylistTrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.columnOrder,
    required this.visibleColumns,
    required this.tokens,
    this.canReorder = true,
    required this.onTap,
    required this.onPlayNow,
    required this.onPlayNext,
    required this.onAddToQueue,
    this.onRemove,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
  });

  @override
  State<_PlaylistTrackRow> createState() => _PlaylistTrackRowState();
}

class _PlaylistTrackRowState extends State<_PlaylistTrackRow> {
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

  Widget _buildRowCell(TrackColumn col, LyraThemeTokens tokens) {
    final track = widget.track;
    final isCurrent = widget.isCurrent;
    final isPlaying = widget.isPlaying;

    switch (col.name) {
      case 'index':
        return SizedBox(
          width: col.width ?? 40.0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: isPlaying
                ? Icon(LucideIcons.volume2, size: 16.0, color: tokens.primary)
                : Text(
                    '${widget.index + 1}',
                    style: LyraTypography.small(tokens).copyWith(
                      color: isCurrent ? tokens.primary : tokens.textMuted,
                      fontWeight: isCurrent
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        );
      case 'trackNumber':
        return SizedBox(
          width: col.width ?? 66.0,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                track.trackNumber != null ? '${track.trackNumber}' : '-',
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  track.displayTitle,
                  style: LyraTypography.p(tokens).copyWith(
                    fontSize: 13.0,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: isCurrent ? tokens.primary : tokens.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  track.artist.isNotEmpty ? track.artist : 'Unknown Artist',
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(fontSize: 12.0, color: tokens.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      case 'album':
        return Expanded(
          flex: col.flex ?? 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                track.album.isNotEmpty ? track.album : 'Unknown Album',
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                track.formattedDuration,
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
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
              child: MouseRegion(
                cursor: widget.onInspectAudio != null
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onInspectAudio,
                  child: LyraBadge.outline(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      track.formattedQuality,
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(fontSize: 10.0, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      case 'work':
        return Expanded(
          flex: col.flex ?? 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              track.workTitle ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'year':
        return SizedBox(
          width: col.width ?? 74.0,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                track.year != null ? '${track.year}' : '-',
                style: LyraTypography.small(tokens).copyWith(
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      case 'genre':
        return Expanded(
          flex: col.flex ?? 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              track.genre ?? '-',
              style: LyraTypography.small(
                tokens,
              ).copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case 'iswc':
        final val = track.iswc;
        return SizedBox(
          width: col.width ?? 140.0,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: (val != null && val.isNotEmpty)
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            val,
                            style: LyraTypography.mono(
                              tokens,
                              fontSize: 11.0,
                            ).copyWith(color: tokens.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        LyraCopyButton(text: val, tooltip: 'Copy ISWC'),
                      ],
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
        final val = track.isrc;
        return SizedBox(
          width: col.width ?? 130.0,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: (val != null && val.isNotEmpty)
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            val,
                            style: LyraTypography.mono(
                              tokens,
                              fontSize: 11.0,
                            ).copyWith(color: tokens.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        LyraCopyButton(text: val, tooltip: 'Copy ISRC'),
                      ],
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
        final val = track.musicbrainzId;
        return SizedBox(
          width: col.width ?? 260.0,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: (val != null && val.isNotEmpty)
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            val,
                            style: LyraTypography.mono(
                              tokens,
                              fontSize: 11.0,
                            ).copyWith(color: tokens.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        LyraCopyButton(
                          text: val,
                          tooltip: 'Copy MusicBrainz ID',
                        ),
                      ],
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
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final track = widget.track;
    final isCurrent = widget.isCurrent;
    final index = widget.index;

    return ThresholdReorderableDragStartListener(
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
            onPressed: widget.onPlayNow,
            child: const Text('Play Now'),
          ),
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.listStart, size: 16.0),
            onPressed: widget.onPlayNext,
            child: const Text('Play Next'),
          ),
          ShadContextMenuItem(
            leading: const Icon(LucideIcons.listEnd, size: 16.0),
            onPressed: widget.onAddToQueue,
            child: const Text('Add to Queue'),
          ),
          if (widget.onGoToAlbum != null && track.album.trim().isNotEmpty)
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.disc, size: 16.0),
              onPressed: () => widget.onGoToAlbum!(track.album),
              child: const Text('Go to Album'),
            ),
          if (widget.onGoToArtist != null && track.artist.trim().isNotEmpty)
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.mic2, size: 16.0),
              onPressed: () => widget.onGoToArtist!(track.artist),
              child: const Text('Go to Artist'),
            ),
          if (widget.onRemove != null)
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.trash2, size: 16.0),
              onPressed: widget.onRemove,
              child: const Text('Remove from Playlist'),
            ),
          if (widget.onInspectAudio != null)
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.info, size: 16.0),
              onPressed: widget.onInspectAudio,
              child: const Text('Inspect Audio'),
            ),
        ],
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              LyraContextMenuCoordinator.hideActive();
              widget.onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: LyraSpacing.xl,
                vertical: LyraSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isCurrent
                    ? (tokens.isDark
                          ? const Color(0xFF27272A)
                          : const Color(0xFFE4E4E7))
                    : (_isHovered || _contextMenuController.isOpen
                          ? tokens.secondary.withValues(alpha: 0.5)
                          : const Color(0x00000000)),
                border: Border(
                  bottom: BorderSide(
                    color: tokens.border.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  for (final col in widget.columnOrder)
                    if (widget.visibleColumns.contains(col))
                      _buildRowCell(col, tokens),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistColumnMenuItem extends StatefulWidget {
  final int index;
  final TrackColumn col;
  final bool isVisible;
  final bool canToggle;
  final LyraThemeTokens tokens;
  final VoidCallback onToggle;

  const _PlaylistColumnMenuItem({
    super.key,
    required this.index,
    required this.col,
    required this.isVisible,
    this.canToggle = true,
    required this.tokens,
    required this.onToggle,
  });

  @override
  State<_PlaylistColumnMenuItem> createState() =>
      _PlaylistColumnMenuItemState();
}

class _PlaylistColumnMenuItemState extends State<_PlaylistColumnMenuItem> {
  bool _isHovered = false;
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.isVisible;
  }

  @override
  void didUpdateWidget(covariant _PlaylistColumnMenuItem oldWidget) {
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
                key: Key('track_col_menu_${col.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.canToggle ? _handleToggle : null,
                child: Row(
                  children: [
                    IgnorePointer(
                      child: ShadCheckbox(
                        key: Key('playlist_track_col_checkbox_${col.name}'),
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
