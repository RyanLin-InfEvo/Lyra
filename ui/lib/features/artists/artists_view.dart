// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../models/artist.dart';

/// Responsive grid view of musical artists and ensembles.
class ArtistsView extends StatelessWidget {
  final List<Artist> artists;
  final ValueChanged<Artist>? onArtistSelected;

  const ArtistsView({super.key, required this.artists, this.onArtistSelected});

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (artists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.mic, size: 48.0, color: tokens.textMuted),
            const SizedBox(height: LyraSpacing.md),
            Text('No artists found', style: LyraTypography.h3(tokens)),
            const SizedBox(height: LyraSpacing.xs),
            Text(
              'Import audio tracks to populate your artist directory.',
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
                  Text('Artists', style: LyraTypography.h2(tokens)),
                  const SizedBox(height: LyraSpacing.xs),
                  Text(
                    '${artists.length} performers, composers, and ensembles',
                    style: LyraTypography.muted(tokens),
                  ),
                ],
              ),
              const Spacer(),
              LyraBadge.secondary(child: Text('${artists.length} Artists')),
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
                  childAspectRatio: 0.85,
                ),
                itemCount: artists.length,
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  return _ArtistCard(
                    artist: artist,
                    onTap: () => onArtistSelected?.call(artist),
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

class _ArtistCard extends StatefulWidget {
  final Artist artist;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _ArtistCard({
    required this.artist,
    required this.onTap,
    required this.tokens,
  });

  @override
  State<_ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<_ArtistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final artist = widget.artist;

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72.0,
                  height: 72.0,
                  decoration: BoxDecoration(
                    color: tokens.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.border, width: 1.0),
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.mic,
                      size: 32.0,
                      color: tokens.primary,
                    ),
                  ),
                ),
                const SizedBox(height: LyraSpacing.md),
                Text(
                  artist.displayName,
                  style: LyraTypography.h4(tokens),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: LyraSpacing.xs),
                if (artist.role != null)
                  LyraBadge.secondary(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      artist.role!,
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(fontSize: 10.0, fontWeight: FontWeight.w500),
                    ),
                  )
                else
                  Text(
                    'Artist',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(color: tokens.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
