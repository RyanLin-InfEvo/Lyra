// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../models/playlist.dart';

/// Responsive grid view of curated and user playlists.
class PlaylistsView extends StatelessWidget {
  final List<Playlist> playlists;
  final ValueChanged<Playlist>? onPlaylistSelected;
  final VoidCallback? onNewPlaylist;

  const PlaylistsView({
    super.key,
    required this.playlists,
    this.onPlaylistSelected,
    this.onNewPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.listPlus, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text('No playlists created yet', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Create a playlist to organize your favorite master tracks.',
              style: LyraTypography.muted(tokens),
            ),
            const SizedBox(height: LyraSpacing.lg),
            if (onNewPlaylist != null)
              LyraButton(
                onPressed: onNewPlaylist,
                leading: const Icon(LucideIcons.plus, size: 16.0),
                child: const Text('Create Playlist'),
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
                  Text('Playlists', style: LyraTypography.h2(tokens)),
                  const SizedBox(height: LyraSpacing.xs),
                  Text(
                    '${playlists.length} curated collections',
                    style: LyraTypography.muted(tokens),
                  ),
                ],
              ),
              const Spacer(),
              if (onNewPlaylist != null)
                LyraButton(
                  size: LyraButtonSize.sm,
                  onPressed: onNewPlaylist,
                  leading: const Icon(LucideIcons.plus, size: 16.0),
                  child: const Text('New Playlist'),
                ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              int crossAxisCount = 2;
              if (width > 1200) {
                crossAxisCount = 4;
              } else if (width > 900) {
                crossAxisCount = 3;
              } else if (width > 600) {
                crossAxisCount = 2;
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: LyraSpacing.xl,
                  vertical: LyraSpacing.sm,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: LyraSpacing.lg,
                  mainAxisSpacing: LyraSpacing.lg,
                  childAspectRatio: 1.1,
                ),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return RepaintBoundary(
                    child: _PlaylistCard(
                      playlist: playlist,
                      onTap: () => onPlaylistSelected?.call(playlist),
                      tokens: tokens,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaylistCard extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.tokens,
  });

  @override
  State<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<_PlaylistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final playlist = widget.playlist;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovered ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: LyraCard(
              padding: const EdgeInsets.all(LyraSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44.0,
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: tokens.secondary,
                          borderRadius: LyraRadius.mdRadius,
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.listMusic,
                            size: 22.0,
                            color: tokens.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      LyraBadge.secondary(
                        child: Text('${playlist.trackCount} tracks'),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    playlist.displayTitle,
                    style: LyraTypography.h4(tokens),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    playlist.description ?? 'Curated Playlist',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
