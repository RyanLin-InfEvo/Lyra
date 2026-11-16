// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../common/collection_detail_view.dart';
import '../models/tag.dart';
import '../models/track.dart';
import '../player/controllers/playback_queue_controller.dart';
import '../settings/services/preferences_service.dart';
import '../tracks/tracks_view.dart';

/// Detailed view for a single tag, displaying category, creation date, matching
/// track summary, and optional jump action to filter in the main Tracks view.
class TagDetailView extends StatelessWidget {
  final Tag tag;
  final List<Track> tracks;
  final VoidCallback onBack;
  final VoidCallback? onFilterInTracks;
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

  const TagDetailView({
    super.key,
    required this.tag,
    required this.tracks,
    required this.onBack,
    this.onFilterInTracks,
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
      'Category: ${tag.groupName}',
      '${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
      formatCollectionDuration(tracks),
      if (tag.createdAt != null)
        'Created ${formatMetadataDate(tag.createdAt!)}',
    ];

    return CollectionDetailView(
      entityId: tag.id,
      keyPrefix: 'tag',
      backLabel: 'Tags',
      eyebrowLabel: 'TAG',
      title: tag.displayName,
      metadataItems: metadataItems,
      artworkIcon: LucideIcons.tag,
      extraHeaderActions: [
        if (onFilterInTracks != null)
          LyraButton.outline(
            key: const Key('tag_filter_in_tracks_button'),
            size: LyraButtonSize.sm,
            onPressed: onFilterInTracks,
            leading: const Icon(LucideIcons.listFilter, size: 15.0),
            child: const Text('Filter in Tracks'),
          ),
      ],
      emptyIcon: LucideIcons.tag,
      emptyTitle: 'No tracks with this tag',
      emptySubtitle: 'Assign this tag to tracks from your library.',
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
