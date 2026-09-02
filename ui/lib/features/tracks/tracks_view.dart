// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../models/track.dart';

/// High-density tracks table view with audiophile format badges and CAS verification.
class TracksView extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.searchX, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text(
              filterLabel != null
                  ? 'No matching tracks found'
                  : 'No tracks found',
              style: LyraTypography.h3(tokens),
            ),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              filterLabel != null
                  ? 'No tracks found matching "$filterLabel".'
                  : 'Try adjusting your search query or import new audio files.',
              style: LyraTypography.muted(tokens),
            ),
            if (filterLabel != null && onClearFilter != null) ...[
              const SizedBox(height: LyraSpacing.md),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onClearFilter,
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
                    '${tracks.length} tracks',
                    style: LyraTypography.muted(tokens),
                  ),
                ],
              ),
              if (filterLabel != null) ...[
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
                        filterLabel!,
                        style: LyraTypography.small(
                          tokens,
                        ).copyWith(fontSize: 11.0, fontWeight: FontWeight.w500),
                      ),
                      if (onClearFilter != null) ...[
                        const SizedBox(width: 6.0),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onClearFilter,
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

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.xl,
            vertical: LyraSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.border, width: 1.0),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40.0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '#',
                    style: LyraTypography.small(tokens).copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'TITLE & ARTIST',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'ALBUM',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'RESOLUTION',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'CAS HASH',
                  style: LyraTypography.small(tokens).copyWith(
                    color: tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 60.0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'TIME',
                    style: LyraTypography.small(tokens).copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: LyraSpacing.xs),
            itemCount: tracks.length,
            separatorBuilder: (context, index) => Container(
              height: 1.0,
              color: tokens.border.withValues(alpha: 0.4),
            ),
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isCurrent = currentTrack?.id == track.id;
              final versionCount =
                  audioVersionCounts?[track.id] ??
                  audioVersionCounts?[track.pcmHash] ??
                  1;

              return RepaintBoundary(
                child: _TrackRow(
                  index: index + 1,
                  track: track,
                  isCurrent: isCurrent,
                  isPlaying: isCurrent && isPlaying,
                  versionCount: versionCount,
                  onTap: () {
                    if (isCurrent) {
                      onTogglePlay();
                    } else {
                      onTrackSelected(track);
                    }
                  },
                  onInspect: onInspectTrack != null
                      ? () => onInspectTrack!(track)
                      : null,
                  onInspectAudio: onInspectAudio != null
                      ? () => onInspectAudio!(track)
                      : (onInspectTrack != null
                            ? () => onInspectTrack!(track)
                            : null),
                  tokens: tokens,
                ),
              );
            },
          ),
        ),
      ],
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
  });

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _isHovered = false;

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
            ),
            child: Row(
              children: [
                // Index or Play Icon
                SizedBox(
                  width: 40.0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _isHovered || widget.isPlaying
                        ? Icon(
                            widget.isPlaying
                                ? LucideIcons.volume2
                                : LucideIcons.play,
                            size: 16.0,
                            color: widget.isCurrent
                                ? tokens.primary
                                : tokens.text,
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
                ),

                // Title & Artist
                Expanded(
                  flex: 4,
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
                          color: widget.isCurrent
                              ? tokens.primary
                              : tokens.text,
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

                // Album
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.track.album,
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Resolution / Version Badge (Interactive)
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
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
                ),

                // CAS Hash Tag & Inspect Action
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: MouseRegion(
                            cursor: widget.onInspect != null
                                ? SystemMouseCursors.click
                                : SystemMouseCursors.basic,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onInspect,
                              child: LyraBadge.outline(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 2.0,
                                ),
                                child: Text(
                                  widget.track.shortCasHash,
                                  style: LyraTypography.mono(
                                    tokens,
                                    fontSize: 10.0,
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

                // Duration
                SizedBox(
                  width: 60.0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.track.formattedDuration,
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(color: tokens.textMuted),
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
