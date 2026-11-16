// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../common/collection_detail_view.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../player/controllers/playback_queue_controller.dart';
import '../settings/services/preferences_service.dart';
import '../tracks/tracks_view.dart';

export '../settings/services/preferences_service.dart' show TrackActivationMode;
export '../tracks/tracks_view.dart' show TrackColumn;

/// Detailed view for a single playlist, featuring metadata header, playback actions,
/// and reorderable track list with context menu support and customizable table columns.
class PlaylistDetailView extends StatelessWidget {
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
  final PreferencesService? preferencesService;
  final TrackActivationMode? trackActivationMode;
  final VoidCallback? onTogglePlay;
  final ValueChanged<Track>? onTrackFocus;
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
      '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
      formatCollectionDuration(tracks),
      if (playlist.createdAt != null)
        'Created ${formatMetadataDate(playlist.createdAt!)}',
    ];

    return CollectionDetailView(
      entityId: playlist.id,
      keyPrefix: 'playlist',
      backLabel: 'Playlists',
      eyebrowLabel: 'PLAYLIST',
      title: playlist.displayTitle,
      description: playlist.description,
      metadataItems: metadataItems,
      artworkIcon: LucideIcons.listMusic,
      emptyIcon: LucideIcons.listMusic,
      emptyTitle: 'No tracks in this playlist',
      emptySubtitle: 'Add tracks to this playlist from your library.',
      allowReorder: true,
      usePlaylistColumnPreferences: true,
      defaultVisibleColumns: defaultVisibleColumns,
      tracks: tracks,
      onBack: onBack,
      playbackController: playbackController,
      onPlayAll: onPlayAll,
      onShuffleAll: onShuffleAll,
      onTrackSelected: onTrackSelected,
      onPlayNext: onPlayNext,
      onAddToQueue: onAddToQueue,
      onRemoveTrack: onRemoveTrack,
      removeTrackLabel: 'Remove from Playlist',
      onReorderTracks: onReorderTracks,
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
