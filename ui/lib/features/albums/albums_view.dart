// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../models/album.dart';

/// Responsive grid view of audiophile albums.
class AlbumsView extends StatelessWidget {
  final List<Album> albums;
  final ValueChanged<Album>? onAlbumSelected;

  const AlbumsView({super.key, required this.albums, this.onAlbumSelected});

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.disc, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text('No albums found', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Import audio tracks to populate your album library.',
              style: LyraTypography.muted(tokens),
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
                  Text('Albums', style: LyraTypography.h2(tokens)),
                  const SizedBox(height: LyraSpacing.xs),
                  Text(
                    '${albums.length} releases in master quality',
                    style: LyraTypography.muted(tokens),
                  ),
                ],
              ),
              const Spacer(),
              LyraBadge.secondary(child: Text('${albums.length} Total')),
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
                crossAxisCount = 5;
              } else if (width > 900) {
                crossAxisCount = 4;
              } else if (width > 600) {
                crossAxisCount = 3;
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
                  childAspectRatio: 0.78,
                ),
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return _AlbumCard(
                    album: album,
                    onTap: () => onAlbumSelected?.call(album),
                    tokens: tokens,
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

/// Single album card item.
class _AlbumCard extends StatefulWidget {
  final Album album;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _AlbumCard({
    required this.album,
    required this.onTap,
    required this.tokens,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final album = widget.album;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: LyraCard(
            padding: const EdgeInsets.all(LyraSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Album Art Placeholder
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: album.coverColor,
                      borderRadius: LyraRadius.mdRadius,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x33000000),
                          blurRadius: 8.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            LucideIcons.disc,
                            size: 48.0,
                            color: const Color(0x66FFFFFF),
                          ),
                        ),
                        Positioned(
                          top: LyraSpacing.sm,
                          right: LyraSpacing.sm,
                          child: LyraBadge(
                            variant: LyraBadgeVariant.secondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            child: Text(
                              album.format ?? 'FLAC',
                              style: LyraTypography.small(tokens).copyWith(
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: LyraSpacing.md),

                // Title
                Text(
                  album.title,
                  style: LyraTypography.h4(tokens),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2.0),

                // Artist & Year
                Text(
                  '${album.artist} • ${album.year}',
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: LyraSpacing.xs),

                // Track Count
                Text(
                  '${album.trackCount} tracks',
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted, fontSize: 11.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
