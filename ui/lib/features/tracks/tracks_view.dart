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

  const TracksView({
    super.key,
    required this.tracks,
    required this.currentTrack,
    required this.isPlaying,
    required this.onTrackSelected,
    required this.onTogglePlay,
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
            Text('No tracks found', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Try adjusting your search query or import new audio files.',
              style: LyraTypography.muted(tokens),
            ),
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

              return RepaintBoundary(
                child: _TrackRow(
                  index: index + 1,
                  track: track,
                  isCurrent: isCurrent,
                  isPlaying: isCurrent && isPlaying,
                  onTap: () {
                    if (isCurrent) {
                      onTogglePlay();
                    } else {
                      onTrackSelected(track);
                    }
                  },
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
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _TrackRow({
    required this.index,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
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
                        widget.track.title,
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

                // Resolution Badge
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LyraBadge.secondary(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      child: Text(
                        widget.track.formattedQuality,
                        style: LyraTypography.small(
                          tokens,
                        ).copyWith(fontSize: 10.0, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),

                // CAS Hash Tag
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LyraBadge.outline(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      child: Text(
                        widget.track.shortCasHash,
                        style: LyraTypography.mono(tokens, fontSize: 10.0),
                      ),
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
