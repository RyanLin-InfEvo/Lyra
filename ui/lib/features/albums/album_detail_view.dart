// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../common/collection_detail_view.dart';
import '../models/album.dart';
import '../models/track.dart';
import '../player/controllers/playback_queue_controller.dart';
import '../settings/services/preferences_service.dart';
import '../tracks/tracks_view.dart';

/// Detailed view for a single album, showing cover art, release metadata,
/// clickable artist link, and tracks ordered by disc and track number.
class AlbumDetailView extends StatelessWidget {
  final Album album;
  final List<Track> tracks;
  final VoidCallback onBack;
  final String backLabel;
  final VoidCallback? onArtistTap;
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
    TrackColumn.trackNumber,
    TrackColumn.title,
    TrackColumn.resolution,
    TrackColumn.duration,
  };

  const AlbumDetailView({
    super.key,
    required this.album,
    required this.tracks,
    required this.onBack,
    this.backLabel = 'Albums',
    this.onArtistTap,
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

  List<Track> _sortedTracks() {
    final sorted = List<Track>.from(tracks);
    sorted.sort((a, b) {
      final discCompare = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
      if (discCompare != 0) return discCompare;
      final trackCompare = (a.trackNumber ?? 9999).compareTo(
        b.trackNumber ?? 9999,
      );
      if (trackCompare != 0) return trackCompare;
      return a.displayTitle.compareTo(b.displayTitle);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final orderedTracks = _sortedTracks();
    final releaseDate = album.formattedReleaseDate;
    final metadataItems = <String>[
      if (releaseDate.isNotEmpty) releaseDate,
      if ((album.totalDiscs ?? 1) > 1) '${album.totalDiscs} discs',
      '${orderedTracks.length} ${orderedTracks.length == 1 ? 'track' : 'tracks'}',
      formatCollectionDuration(orderedTracks),
      if (album.format != null && album.format!.trim().isNotEmpty)
        album.format!.trim(),
      if (album.createdAt != null)
        'Added ${formatMetadataDate(album.createdAt!)}',
    ];

    return CollectionDetailView(
      entityId: album.id,
      keyPrefix: 'album',
      backLabel: backLabel,
      eyebrowLabel: 'ALBUM',
      title: album.displayTitle,
      subtitle: album.displayArtist,
      onSubtitleTap: album.artist.trim().isNotEmpty ? onArtistTap : null,
      metadataItems: metadataItems,
      artworkIcon: LucideIcons.disc,
      artworkBuilder: (context) {
        final tokens = LyraDesignSystemScope.of(context).tokens;
        return Container(
          decoration: BoxDecoration(
            color: album.coverColor.withValues(alpha: 0.22),
          ),
          child: Center(
            child: Icon(LucideIcons.disc, size: 52.0, color: tokens.primary),
          ),
        );
      },
      emptyIcon: LucideIcons.disc,
      emptyTitle: 'No tracks in this album',
      emptySubtitle: 'Tracks belonging to this album will appear here.',
      allowReorder: false,
      defaultVisibleColumns: defaultVisibleColumns,
      tracks: orderedTracks,
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
