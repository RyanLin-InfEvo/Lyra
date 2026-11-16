// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart' show Scrollbar;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../common/collection_detail_view.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../player/controllers/playback_queue_controller.dart';
import '../settings/services/preferences_service.dart';
import '../tracks/tracks_view.dart';

/// Detailed view for a single artist, showing metadata, a horizontal album
/// shelf, and all tracks performed by the artist.
class ArtistDetailView extends StatelessWidget {
  final Artist artist;
  final List<Album> albums;
  final List<Track> tracks;
  final VoidCallback onBack;
  final ValueChanged<Album>? onAlbumSelected;
  final PlaybackQueueController? playbackController;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffleAll;
  final ValueChanged<Track>? onTrackSelected;
  final ValueChanged<Track>? onPlayNext;
  final ValueChanged<Track>? onAddToQueue;
  final ValueChanged<Track>? onInspectAudio;
  final ValueChanged<Track>? onTrackFocus;
  final ValueChanged<String>? onGoToAlbum;
  final ValueChanged<String>? onGoToArtist;
  final Track? currentTrack;
  final bool isPlaying;
  final Set<TrackColumn>? visibleColumns;
  final ValueChanged<Set<TrackColumn>>? onVisibleColumnsChanged;
  final List<TrackColumn>? columnOrder;
  final ValueChanged<List<TrackColumn>>? onColumnOrderChanged;
  final PreferencesService? preferencesService;
  final TrackActivationMode? trackActivationMode;
  final VoidCallback? onTogglePlay;
  final bool isNowPlayingExpanded;
  final TrackListViewMode? viewMode;
  final bool? showHeader;

  static final Set<TrackColumn> defaultVisibleColumns = {
    TrackColumn.index,
    TrackColumn.cover,
    TrackColumn.title,
    TrackColumn.album,
    TrackColumn.duration,
  };

  const ArtistDetailView({
    super.key,
    required this.artist,
    required this.albums,
    required this.tracks,
    required this.onBack,
    this.onAlbumSelected,
    this.playbackController,
    this.onPlayAll,
    this.onShuffleAll,
    this.onTrackSelected,
    this.onPlayNext,
    this.onAddToQueue,
    this.onInspectAudio,
    this.onTrackFocus,
    this.onGoToAlbum,
    this.onGoToArtist,
    this.currentTrack,
    this.isPlaying = false,
    this.visibleColumns,
    this.onVisibleColumnsChanged,
    this.columnOrder,
    this.onColumnOrderChanged,
    this.preferencesService,
    this.trackActivationMode,
    this.onTogglePlay,
    this.isNowPlayingExpanded = false,
    this.viewMode,
    this.showHeader,
  });

  @override
  Widget build(BuildContext context) {
    final metadataItems = <String>[
      '${albums.length} ${albums.length == 1 ? 'album' : 'albums'}',
      '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
      formatCollectionDuration(tracks),
      if (artist.role != null && artist.role!.trim().isNotEmpty)
        artist.role!.trim(),
      if (artist.createdAt != null)
        'Added ${formatMetadataDate(artist.createdAt!)}',
    ];

    return CollectionDetailView(
      entityId: artist.id,
      keyPrefix: 'artist',
      backLabel: 'Artists',
      eyebrowLabel: 'ARTIST',
      title: artist.displayName,
      metadataItems: metadataItems,
      artworkIcon: LucideIcons.mic2,
      middleSection: albums.isEmpty
          ? null
          : _ArtistAlbumsShelf(
              albums: albums,
              onAlbumSelected: onAlbumSelected,
            ),
      emptyIcon: LucideIcons.mic2,
      emptyTitle: 'No tracks for this artist',
      emptySubtitle: 'Tracks by this artist will appear here.',
      allowReorder: false,
      defaultVisibleColumns: defaultVisibleColumns,
      tracks: tracks,
      onBack: onBack,
      playbackController: playbackController,
      onPlayAll: onPlayAll,
      onShuffleAll: onShuffleAll,
      onTrackSelected: onTrackSelected,
      onPlayNext: onPlayNext,
      onAddToQueue: onAddToQueue,
      onInspectAudio: onInspectAudio,
      onTrackFocus: onTrackFocus,
      onGoToAlbum: onGoToAlbum,
      onGoToArtist: onGoToArtist,
      currentTrack: currentTrack,
      isPlaying: isPlaying,
      visibleColumns: visibleColumns,
      onVisibleColumnsChanged: onVisibleColumnsChanged,
      columnOrder: columnOrder,
      onColumnOrderChanged: onColumnOrderChanged,
      preferencesService: preferencesService,
      trackActivationMode: trackActivationMode,
      onTogglePlay: onTogglePlay,
      isNowPlayingExpanded: isNowPlayingExpanded,
      viewMode: viewMode,
      showHeader: showHeader,
    );
  }
}

class _ArtistAlbumsShelf extends StatefulWidget {
  final List<Album> albums;
  final ValueChanged<Album>? onAlbumSelected;

  const _ArtistAlbumsShelf({required this.albums, this.onAlbumSelected});

  @override
  State<_ArtistAlbumsShelf> createState() => _ArtistAlbumsShelfState();
}

class _ArtistAlbumsShelfState extends State<_ArtistAlbumsShelf> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Container(
      key: const Key('artist_albums_shelf'),
      padding: const EdgeInsets.only(bottom: LyraSpacing.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.xl),
            child: Text(
              'Albums',
              style: LyraTypography.small(tokens).copyWith(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: LyraSpacing.sm),
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: widget.albums.length > 4,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: LyraSpacing.xl,
                vertical: 2.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.albums.length; i++) ...[
                    if (i > 0) const SizedBox(width: LyraSpacing.md),
                    _ArtistAlbumCard(
                      album: widget.albums[i],
                      onTap: widget.onAlbumSelected != null
                          ? () => widget.onAlbumSelected!(widget.albums[i])
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistAlbumCard extends StatefulWidget {
  final Album album;
  final VoidCallback? onTap;

  const _ArtistAlbumCard({required this.album, this.onTap});

  @override
  State<_ArtistAlbumCard> createState() => _ArtistAlbumCardState();
}

class _ArtistAlbumCardState extends State<_ArtistAlbumCard> {
  bool _isHovered = false;
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final album = widget.album;
    final releaseDate = album.formattedReleaseDate;
    final subtitleText = releaseDate.isNotEmpty
        ? releaseDate
        : (album.format ?? '');
    final isHighlighted = _isHovered || _isFocused;

    return Semantics(
      button: widget.onTap != null,
      label: album.displayTitle,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: widget.onTap != null,
        onFocusChange: (focused) {
          if (mounted) setState(() => _isFocused = focused);
        },
        onKeyEvent: (_, event) {
          if (widget.onTap != null &&
              event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onTap!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            key: Key('artist_album_card_${album.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.onTap != null) {
                _focusNode.requestFocus();
                widget.onTap!();
              }
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 164.0,
                maxWidth: 220.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(LyraSpacing.sm),
                decoration: BoxDecoration(
                  color: isHighlighted ? tokens.surfaceElevated : tokens.card,
                  borderRadius: LyraRadius.mdRadius,
                  border: Border.all(
                    color: isHighlighted
                        ? tokens.primary.withValues(alpha: 0.6)
                        : tokens.border,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44.0,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: album.coverColor.withValues(alpha: 0.2),
                        borderRadius: LyraRadius.smRadius,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Icon(
                        LucideIcons.disc,
                        size: 20.0,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(width: LyraSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            album.displayTitle,
                            style: LyraTypography.small(tokens).copyWith(
                              fontWeight: FontWeight.w600,
                              color: tokens.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitleText.isNotEmpty) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              subtitleText,
                              style: LyraTypography.small(tokens).copyWith(
                                fontSize: 11.0,
                                color: tokens.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
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
