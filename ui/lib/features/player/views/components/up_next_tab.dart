// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/contracts/lyra_contracts.dart';
import '../../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../../design_system/tokens/lyra_tokens.dart';
import '../../../../design_system/widgets/lyra_button.dart';
import '../../../models/track.dart';
import '../../controllers/playback_queue_controller.dart';

/// Up Next tab component displaying the active playback queue, track items, and queue actions.
class UpNextTab extends StatefulWidget {
  final PlaybackQueueController playbackController;
  final String? queueSource;

  const UpNextTab({
    super.key,
    required this.playbackController,
    this.queueSource,
  });

  @override
  State<UpNextTab> createState() => _UpNextTabState();
}

class _UpNextTabState extends State<UpNextTab> {
  late final ScrollController _scrollController;
  int? _hoveredIndex;

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
                      : widget.playbackController.toggleShuffle,
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
                      : widget.playbackController.clearQueue,
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
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: queue.length,
                    padding: const EdgeInsets.symmetric(
                      vertical: LyraSpacing.xs,
                      horizontal: LyraSpacing.sm,
                    ),
                    itemBuilder: (context, index) {
                      final track = queue[index];
                      final isCurrent = index == currentIndex;
                      final isHovered = _hoveredIndex == index;

                      return _QueueItemRow(
                        key: ValueKey('queue_track_${track.id}_$index'),
                        track: track,
                        index: index,
                        isCurrent: isCurrent,
                        isHovered: isHovered,
                        tokens: tokens,
                        onHoverChanged: (hovered) {
                          if (mounted) {
                            setState(() {
                              _hoveredIndex = hovered ? index : null;
                            });
                          }
                        },
                        onTap: () {
                          widget.playbackController.play(
                            track,
                            contextQueue: widget.playbackController.queue,
                          );
                        },
                        onRemove: () {
                          widget.playbackController.removeFromQueue(index);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueItemRow extends StatelessWidget {
  final Track track;
  final int index;
  final bool isCurrent;
  final bool isHovered;
  final LyraThemeTokens tokens;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueItemRow({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.isHovered,
    required this.tokens,
    required this.onHoverChanged,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHoverChanged(true),
        onExit: (_) => onHoverChanged(false),
        child: GestureDetector(
          onTap: onTap,
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
                  : (isHovered
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

                const SizedBox(width: LyraSpacing.sm),

                // Remove from Queue Action
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onRemove,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        LucideIcons.x,
                        size: 16.0,
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
