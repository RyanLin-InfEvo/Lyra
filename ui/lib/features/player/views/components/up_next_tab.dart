// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart' show Material, ReorderableListView;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../design_system/contracts/lyra_contracts.dart';
import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../../../design_system/widgets/lyra_button.dart';
import '../../../common/context_menu_coordinator.dart';
import '../../../models/track.dart';
import '../../controllers/playback_queue_controller.dart';
import '../../../../widgets/threshold_reorderable_drag_start_listener.dart';

export '../../../../widgets/threshold_reorderable_drag_start_listener.dart';

/// Up Next tab component displaying the active playback queue, track items, and queue actions.
class UpNextTab extends StatefulWidget {
  final PlaybackQueueController playbackController;
  final String? queueSource;
  final void Function(Track track)? onAddToPlaylist;
  final void Function(Track track)? onInspectAudio;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;

  const UpNextTab({
    super.key,
    required this.playbackController,
    this.queueSource,
    this.onAddToPlaylist,
    this.onInspectAudio,
    this.onGoToAlbum,
    this.onGoToArtist,
  });

  @override
  State<UpNextTab> createState() => _UpNextTabState();
}

class _UpNextTabState extends State<UpNextTab> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.playbackController.addListener(_onPlaybackChanged);
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant UpNextTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackController != widget.playbackController) {
      oldWidget.playbackController.removeListener(_onPlaybackChanged);
      widget.playbackController.addListener(_onPlaybackChanged);
    }
  }

  @override
  void dispose() {
    widget.playbackController.removeListener(_onPlaybackChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final queue = widget.playbackController.queue;
    final currentIndex = widget.playbackController.currentIndex;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Queue Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LyraSpacing.lg,
              LyraSpacing.md,
              LyraSpacing.lg,
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
                          Text('Up next', style: LyraTypography.h4(tokens)),
                          const SizedBox(width: LyraSpacing.sm),
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

                // Shuffle Queue Toggle
                LyraButton.ghost(
                  size: LyraButtonSize.sm,
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

                const SizedBox(width: LyraSpacing.xs),

                // Clear Queue Action
                LyraButton.ghost(
                  size: LyraButtonSize.sm,
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

          Container(height: 1.0, color: tokens.border),

          // Queue List Body or Empty State
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
                : NotificationListener<ScrollStartNotification>(
                    onNotification: (notification) {
                      LyraContextMenuCoordinator.hideActive();
                      return false;
                    },
                    child: ReorderableListView.builder(
                      scrollController: _scrollController,
                      itemCount: queue.length,
                      itemExtent: 64.0,
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, index, animation) =>
                          _proxyDecorator(child, index, animation, tokens),
                      onReorder: (oldIndex, newIndex) {
                        widget.playbackController.reorderQueue(
                          oldIndex,
                          newIndex,
                        );
                      },
                      padding: const EdgeInsets.symmetric(
                        vertical: LyraSpacing.xs,
                        horizontal: LyraSpacing.sm,
                      ),
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        final isCurrent = index == currentIndex;
                        final queueItemIds =
                            widget.playbackController.queueItemIds;
                        final itemId = index < queueItemIds.length
                            ? queueItemIds[index]
                            : 'qi_${track.id}_$index';

                        return _QueueItemRow(
                          key: ValueKey('queue_item_$itemId'),
                          track: track,
                          index: index,
                          isCurrent: isCurrent,
                          canReorder: queue.length > 1,
                          tokens: tokens,
                          onTap: () {
                            widget.playbackController.playQueueItem(index);
                          },
                          playbackController: widget.playbackController,
                          onAddToPlaylist: widget.onAddToPlaylist,
                          onInspectAudio: widget.onInspectAudio,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: LyraSpacing.md,
                  vertical: 8.0,
                ),
                margin: const EdgeInsets.symmetric(vertical: 2.0),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? tokens.secondary
                      : (_isHovered || _contextMenuController.isOpen
                            ? tokens.secondary.withValues(alpha: 0.5)
                            : const Color(0x00000000)),
                  borderRadius: LyraRadius.mdRadius,
                  border: isCurrent
                      ? Border.all(color: tokens.border, width: 1.0)
                      : null,
                ),
                child: Row(
                  children: [
                    // Track Index or Animated Wave / Volume Playing Indicator
                    SizedBox(
                      width: 28.0,
                      child: Center(
                        child: isCurrent
                            ? Icon(
                                LucideIcons.volume2,
                                size: 16.0,
                                color: tokens.primary,
                              )
                            : Text(
                                '${index + 1}',
                                style: LyraTypography.small(tokens).copyWith(
                                  color: tokens.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(width: LyraSpacing.xs),

                    // Mini Album Art Thumbnail
                    Container(
                      width: 38.0,
                      height: 38.0,
                      decoration: BoxDecoration(
                        color: tokens.secondary,
                        borderRadius: LyraRadius.smRadius,
                        border: Border.all(color: tokens.border, width: 0.5),
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.music,
                          size: 16.0,
                          color: isCurrent ? tokens.primary : tokens.textMuted,
                        ),
                      ),
                    ),

                    const SizedBox(width: LyraSpacing.md),

                    // Track Title & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          const SizedBox(height: 2.0),
                          Text(
                            '${track.artist.isNotEmpty ? track.artist : "Unknown Artist"} • ${track.album.isNotEmpty ? track.album : "Unknown Album"}',
                            style: LyraTypography.small(
                              tokens,
                            ).copyWith(color: tokens.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: LyraSpacing.sm),

                    // Duration
                    Text(
                      track.formattedDuration,
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
