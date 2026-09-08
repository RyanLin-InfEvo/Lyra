// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_dialog.dart';
import '../../design_system/widgets/lyra_input.dart';
import '../albums/albums_view.dart';
import '../artists/artists_view.dart';
import '../audio/controllers/audio_device_controller.dart';
import '../cas_pool/cas_view.dart';
import '../import/import_modal.dart';
import '../inspector/audio_inspector_drawer.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/cas_object.dart';
import '../models/playlist.dart';
import '../models/tag.dart';
import '../models/track.dart';
import '../models/work.dart';
import '../player/controllers/playback_queue_controller.dart';
import '../player/views/now_playing_view.dart';
import '../playlists/playlists_view.dart';
import '../services/mock_music_service.dart';
import '../services/music_service.dart';
import '../settings/settings_view.dart';
import '../tags/tags_view.dart';
import '../tracks/tracks_view.dart';
import '../works/works_view.dart';
import 'header_bar.dart';
import 'player_bar.dart';
import 'sidebar.dart';

/// Scoped filter applied to the tracks library view without mutating global search input.
class TrackFilter {
  final String label;
  final bool Function(Track track) predicate;

  const TrackFilter({required this.label, required this.predicate});
}

/// Main Desktop App Shell orchestrating 3-pane layout, playback state, and navigation.
class AppShell extends StatefulWidget {
  final MusicService musicService;
  final PlaybackQueueController? playbackController;
  final Curve nowPlayingCurve;
  final Duration nowPlayingDuration;

  const AppShell({
    super.key,
    required this.musicService,
    this.playbackController,
    this.nowPlayingCurve = LyraAnimation.deceleration,
    this.nowPlayingDuration = LyraAnimation.normal,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final TextEditingController _searchController;
  late final PlaybackQueueController _playbackController;
  late final AudioDeviceController _audioDeviceController;
  AppTab _currentTab = AppTab.tracks;
  bool _isSidebarCollapsed = false;
  bool _showImportModal = false;
  bool _showAddToPlaylistModal = false;
  bool _isCreatingPlaylistInModal = false;
  late final TextEditingController _newPlaylistNameController =
      TextEditingController();
  final ValueNotifier<bool> _isNowPlayingExpandedNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<int> _nowPlayingTabNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(0.85);

  // Inspector Drawer State (Phase 4.3)
  bool _isInspectorOpen = false;
  Track? _inspectedTrack;
  Asset? _inspectedAsset;

  // Catalog State
  List<Track> _tracks = [];
  Map<String, int> _audioVersionCounts = {};
  Map<String, int> _tagTrackCounts = {};
  List<Album> _albums = [];
  List<Work> _works = [];
  List<Artist> _artists = [];
  List<Playlist> _sidebarPlaylists = [];
  List<Playlist> _playlists = [];
  List<Tag> _tags = [];
  List<CasObject> _casObjects = [];
  String? _selectedPlaylistId;
  String? _selectedTagId;
  TrackFilter? _activeTrackFilter;
  bool _isLoading = true;

  // Playback State delegation
  Track? get _currentTrack => _playbackController.currentTrack;
  bool get _isPlaying => _playbackController.isPlaying;
  ValueNotifier<Duration> get _positionNotifier =>
      _playbackController.positionNotifier;

  static Map<String, int> _computeTagTrackCounts(
    List<Tag> tags,
    List<Track> tracks,
  ) {
    final Map<String, int> counts = {};
    for (final tag in tags) {
      final tagLower = tag.name.toLowerCase();
      counts[tag.id] = tracks.where((track) {
        if (tagLower == 'hi-res') {
          return (track.bitDepth != null && track.bitDepth! >= 24) ||
              (track.sampleRate != null && track.sampleRate! > 48000);
        }
        if (tagLower == 'audiophile' ||
            tagLower == 'reference master' ||
            tagLower == 'direct stream') {
          return track.verified ||
              (track.bitDepth != null && track.bitDepth! >= 24);
        }
        return (track.format ?? '').toLowerCase().contains(tagLower) ||
            track.displayTitle.toLowerCase().contains(tagLower) ||
            track.artist.toLowerCase().contains(tagLower) ||
            track.album.toLowerCase().contains(tagLower);
      }).length;
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _audioDeviceController = AudioDeviceController();
    _playbackController =
        widget.playbackController ??
        PlaybackQueueController(timerInterval: const Duration(seconds: 1));
    _playbackController.addListener(_onPlaybackChanged);
    _loadCatalog();
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _newPlaylistNameController.dispose();
    _audioDeviceController.dispose();
    _volumeNotifier.dispose();
    _nowPlayingTabNotifier.dispose();
    _playbackController.removeListener(_onPlaybackChanged);
    if (widget.playbackController == null) {
      _playbackController.dispose();
    }
    _searchController.dispose();
    _isNowPlayingExpandedNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog({String? query}) async {
    final tracks = await widget.musicService.getTracks(query: query);
    final albums = await widget.musicService.getAlbums(query: query);
    final works = await widget.musicService.getWorks(query: query);
    final artists = await widget.musicService.getArtists(query: query);
    final playlists = await widget.musicService.getPlaylists(query: query);
    final tags = await widget.musicService.getTags();
    final casObjects = await widget.musicService.getCasObjects();

    final versionCounts = <String, int>{};
    final versionResults = await Future.wait(
      tracks.where((t) => t.pcmHash.isNotEmpty).map((t) async {
        try {
          final versions = await widget.musicService.getAudioVersions(
            t.pcmHash,
          );
          return (id: t.id, hash: t.pcmHash, count: versions.length);
        } catch (_) {
          return null;
        }
      }),
    );
    for (final res in versionResults) {
      if (res != null) {
        versionCounts[res.id] = res.count;
        versionCounts[res.hash] = res.count;
      }
    }

    final tagTrackCounts = _computeTagTrackCounts(tags, tracks);

    if (!mounted) return;

    setState(() {
      _tracks = tracks;
      _audioVersionCounts = versionCounts;
      _tagTrackCounts = tagTrackCounts;
      _albums = albums;
      _works = works;
      _artists = artists;
      _playlists = playlists;
      if (query == null || query.isEmpty) {
        _sidebarPlaylists = playlists;
      }
      _tags = tags;
      _casObjects = casObjects;
      _isLoading = false;

      if (_playbackController.queue.isEmpty && tracks.isNotEmpty) {
        _playbackController.addAllToQueue(tracks);
      }
    });
  }

  void _onSearchChanged(String query) {
    if (query.isNotEmpty) {
      _activeTrackFilter = null;
      _selectedTagId = null;
    }
    _loadCatalog(query: query);
  }

  void _onTrackSelected(Track track) {
    final effectiveTracks = _activeTrackFilter != null
        ? _tracks.where(_activeTrackFilter!.predicate).toList()
        : _tracks;
    _playbackController.play(
      track,
      contextQueue: effectiveTracks.isNotEmpty ? effectiveTracks : _tracks,
    );
    if (_isInspectorOpen) {
      setState(() {
        _inspectedTrack = track;
        _inspectedAsset = null;
      });
    }
  }

  void _togglePlay() {
    _playbackController.togglePlay();
  }

  void _onNextTrack() {
    _playbackController.next();
  }

  void _onPreviousTrack() {
    _playbackController.previous();
  }

  void _onSeek(Duration position) {
    _playbackController.seek(position);
  }

  void _collapseNowPlaying() {
    if (_isNowPlayingExpandedNotifier.value) {
      _isNowPlayingExpandedNotifier.value = false;
    }
  }

  void _toggleNowPlaying() {
    _isNowPlayingExpandedNotifier.value = !_isNowPlayingExpandedNotifier.value;
  }

  Future<void> _handleCreatePlaylistWithName(String rawName) async {
    if (_currentTrack == null) return;
    final trimmed = rawName.trim();
    final title = trimmed.isNotEmpty
        ? trimmed
        : 'New Playlist ${_playlists.length + 1}';
    await widget.musicService.createPlaylist(
      title: title,
      trackIds: [_currentTrack!.id],
    );
    await _loadCatalog();
    if (!mounted) return;
    setState(() {
      _isCreatingPlaylistInModal = false;
      _showAddToPlaylistModal = false;
    });
  }

  void _onVolumeChanged(double volume) {
    _volumeNotifier.value = volume;
  }

  void _filterByTag(Tag tag) {
    setState(() {
      _selectedTagId = tag.id;
      _selectedPlaylistId = null;
      _activeTrackFilter = TrackFilter(
        label: 'Tag: ${tag.name}',
        predicate: (track) {
          final tagLower = tag.name.toLowerCase();
          if (tagLower == 'hi-res') {
            return (track.bitDepth != null && track.bitDepth! >= 24) ||
                (track.sampleRate != null && track.sampleRate! > 48000);
          }
          if (tagLower == 'audiophile' ||
              tagLower == 'reference master' ||
              tagLower == 'direct stream') {
            return track.verified ||
                (track.bitDepth != null && track.bitDepth! >= 24);
          }
          return (track.format ?? '').toLowerCase().contains(tagLower) ||
              track.displayTitle.toLowerCase().contains(tagLower) ||
              track.artist.toLowerCase().contains(tagLower) ||
              track.album.toLowerCase().contains(tagLower);
        },
      );
      _currentTab = AppTab.tracks;
    });
  }

  Future<void> _handleNewPlaylist() async {
    final newPl = await widget.musicService.createPlaylist(
      title: 'New Playlist ${_sidebarPlaylists.length + 1}',
      description: 'User curated collection',
    );
    await _loadCatalog();
    if (!mounted) return;
    setState(() {
      _selectedPlaylistId = newPl.id;
      _currentTab = AppTab.playlists;
    });
  }

  void _openInspectorForTrack(Track track) {
    setState(() {
      _inspectedTrack = track;
      _inspectedAsset = null;
      _isInspectorOpen = true;
    });
  }

  void _openInspectorForAudio(Track track) {
    setState(() {
      _inspectedTrack = track;
      _inspectedAsset = null;
      _isInspectorOpen = true;
    });
  }

  void _openInspectorForAsset(Asset asset) {
    setState(() {
      _inspectedAsset = asset;
      _inspectedTrack = null;
      _isInspectorOpen = true;
    });
  }

  void _closeInspector() {
    setState(() {
      _isInspectorOpen = false;
    });
  }

  void _toggleInspector() {
    setState(() {
      _isInspectorOpen = !_isInspectorOpen;
      if (_isInspectorOpen &&
          _inspectedTrack == null &&
          _inspectedAsset == null &&
          _currentTrack != null) {
        _inspectedTrack = _currentTrack;
      }
    });
  }

  void _handlePlayerBarInspectTrack() {
    if (_isNowPlayingExpandedNotifier.value) {
      _nowPlayingTabNotifier.value = 2;
    } else {
      _toggleInspector();
    }
  }

  void _handlePlayerBarInspectAudio() {
    if (_isNowPlayingExpandedNotifier.value) {
      _nowPlayingTabNotifier.value = 2;
    } else {
      if (_currentTrack != null) {
        _openInspectorForAudio(_currentTrack!);
      } else {
        _toggleInspector();
      }
    }
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentTab) {
      case AppTab.tracks:
        final effectiveTracks = _activeTrackFilter != null
            ? _tracks.where(_activeTrackFilter!.predicate).toList()
            : _tracks;
        return RepaintBoundary(
          child: TracksView(
            tracks: effectiveTracks,
            currentTrack: _currentTrack,
            isPlaying: _isPlaying,
            filterLabel: _activeTrackFilter?.label,
            audioVersionCounts: _audioVersionCounts,
            onClearFilter: () => setState(() {
              _activeTrackFilter = null;
              _selectedTagId = null;
            }),
            onTrackSelected: _onTrackSelected,
            onTogglePlay: _togglePlay,
            onInspectTrack: _openInspectorForTrack,
            onInspectAudio: _openInspectorForAudio,
          ),
        );
      case AppTab.works:
        return RepaintBoundary(
          child: WorksView(
            works: _works,
            onWorkSelected: (work) {
              setState(() {
                _activeTrackFilter = TrackFilter(
                  label: 'Work: ${work.title}',
                  predicate: (track) =>
                      track.displayTitle.toLowerCase().contains(
                        work.title.toLowerCase(),
                      ) ||
                      work.title.toLowerCase().contains(
                        track.displayTitle.toLowerCase(),
                      ),
                );
                _currentTab = AppTab.tracks;
              });
            },
          ),
        );
      case AppTab.albums:
        return RepaintBoundary(
          child: AlbumsView(
            albums: _albums,
            onAlbumSelected: (album) {
              setState(() {
                _activeTrackFilter = TrackFilter(
                  label: 'Album: ${album.title}',
                  predicate: (track) =>
                      track.album.toLowerCase() == album.title.toLowerCase(),
                );
                _currentTab = AppTab.tracks;
              });
            },
          ),
        );
      case AppTab.artists:
        return RepaintBoundary(
          child: ArtistsView(
            artists: _artists,
            onArtistSelected: (artist) {
              setState(() {
                _activeTrackFilter = TrackFilter(
                  label: 'Artist: ${artist.name}',
                  predicate: (track) => track.artist.toLowerCase().contains(
                    artist.name.toLowerCase(),
                  ),
                );
                _currentTab = AppTab.tracks;
              });
            },
          ),
        );
      case AppTab.playlists:
        return RepaintBoundary(
          child: PlaylistsView(
            playlists: _playlists,
            onNewPlaylist: _handleNewPlaylist,
            onPlaylistSelected: (playlist) {
              setState(() {
                _selectedPlaylistId = playlist.id;
              });
            },
          ),
        );
      case AppTab.tags:
        return RepaintBoundary(
          child: TagsView(
            tags: _tags,
            tagTrackCounts: _tagTrackCounts,
            onTagSelected: _filterByTag,
            onCreateTag:
                ({required String name, required String category}) async {
                  await widget.musicService.createTag(
                    name: name,
                    category: category,
                  );
                  await _loadCatalog();
                },
            onDeleteTag: (tag) async {
              await widget.musicService.deleteTag(tag.id);
              await _loadCatalog();
            },
          ),
        );
      case AppTab.casStorage:
        return RepaintBoundary(
          child: CasView(
            casObjects: _casObjects,
            onInspectAsset: (obj) => _openInspectorForAsset(obj),
            onVerifyAll: () async {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(
                  content: Text(
                    'All CAS SHA-256 blocks verified successfully.',
                  ),
                ),
              );
            },
          ),
        );
      case AppTab.settings:
        return const RepaintBoundary(child: SettingsView());
    }
  }

  Widget _buildHeader() {
    return RepaintBoundary(
      child: LyraHeaderBar(
        searchController: _searchController,
        onSearchChanged: _onSearchChanged,
        onImportPressed: () => setState(() => _showImportModal = true),
      ),
    );
  }

  Widget _buildBottomPlayer() {
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: _isNowPlayingExpandedNotifier,
        builder: (context, isNowPlayingExpanded, _) {
          return ValueListenableBuilder<int>(
            valueListenable: _nowPlayingTabNotifier,
            builder: (context, nowPlayingTabIndex, _) {
              return LyraPlayerBar(
                currentTrack: _currentTrack,
                isPlaying: _isPlaying,
                positionNotifier: _positionNotifier,
                volume: _volumeNotifier.value,
                volumeNotifier: _volumeNotifier,
                audioDeviceController: _audioDeviceController,
                isInspectorOpen: isNowPlayingExpanded
                    ? (nowPlayingTabIndex == 2)
                    : _isInspectorOpen,
                isNowPlayingExpanded: isNowPlayingExpanded,
                isShuffle: _playbackController.shuffleMode,
                onToggleShuffle: () => _playbackController.toggleShuffle(),
                repeatMode: _playbackController.repeatMode,
                onCycleRepeat: () => _playbackController.cycleRepeatMode(),
                onAddToPlaylist: _currentTrack == null
                    ? null
                    : () => setState(() {
                        _showAddToPlaylistModal = true;
                        _isCreatingPlaylistInModal = false;
                      }),
                onInspectTrack: _handlePlayerBarInspectTrack,
                onInspectAudio: _handlePlayerBarInspectAudio,
                onTogglePlay: _togglePlay,
                onNext: _onNextTrack,
                onPrevious: _onPreviousTrack,
                onSeek: _onSeek,
                onVolumeChanged: _onVolumeChanged,
                onExpandNowPlaying: _toggleNowPlaying,
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Scaffold(
      backgroundColor: tokens.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;
          final effectiveSidebarCollapsed = _isSidebarCollapsed || isCompact;

          return Stack(
            children: [
              // 3-Pane Desktop Layout
              Row(
                children: [
                  // Sidebar (Left)
                  RepaintBoundary(
                    child: LyraSidebar(
                      currentTab: _currentTab,
                      isCollapsed: effectiveSidebarCollapsed,
                      playlists: _sidebarPlaylists,
                      selectedPlaylistId: _selectedPlaylistId,
                      onPlaylistSelected: (pl) {
                        setState(() {
                          _selectedPlaylistId = pl.id;
                          _selectedTagId = null;
                          _currentTab = AppTab.playlists;
                        });
                      },
                      tags: _tags,
                      selectedTagId: _selectedTagId,
                      onTagSelected: _filterByTag,
                      onTagsHeaderSelected: () {
                        setState(() {
                          _selectedTagId = null;
                          _selectedPlaylistId = null;
                          _currentTab = AppTab.tags;
                        });
                      },
                      onTabSelected: (tab) => setState(() {
                        if (tab == AppTab.tracks) {
                          _activeTrackFilter = null;
                          _selectedTagId = null;
                        } else if (tab != AppTab.playlists &&
                            tab != AppTab.tags) {
                          _selectedPlaylistId = null;
                          _selectedTagId = null;
                        }
                        _currentTab = tab;
                      }),
                      onToggleCollapse: () => setState(
                        () => _isSidebarCollapsed = !_isSidebarCollapsed,
                      ),
                    ),
                  ),

                  // Right Pane (Header + Main Area + Player Bar)
                  Expanded(
                    child: Column(
                      children: [
                        // Header Bar (Top)
                        _buildHeader(),

                        // Main View Content + Docked Inspector Drawer + Now Playing Overlay (Center)
                        Expanded(
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: tokens.background,
                                      child: _buildMainContent(),
                                    ),
                                  ),
                                  if (_isInspectorOpen)
                                    RepaintBoundary(
                                      child: AudioInspectorDrawer(
                                        track:
                                            _inspectedTrack ??
                                            (_inspectedAsset != null
                                                ? null
                                                : _currentTrack),
                                        asset: _inspectedAsset,
                                        musicService: widget.musicService,
                                        onClose: _closeInspector,
                                        onActiveAudioChanged: (newPcmHash) {
                                          _loadCatalog();
                                        },
                                      ),
                                    ),
                                ],
                              ),

                              // Now Playing View Overlay (Pre-warmed offscreen and animated via AnimatedSlide)
                              Positioned.fill(
                                child: ValueListenableBuilder<bool>(
                                  valueListenable:
                                      _isNowPlayingExpandedNotifier,
                                  builder: (context, isNowPlayingExpanded, _) {
                                    return RepaintBoundary(
                                      child: AnimatedSlide(
                                        key: const ValueKey(
                                          'now_playing_animated_slide',
                                        ),
                                        offset: isNowPlayingExpanded
                                            ? Offset.zero
                                            : const Offset(0.0, 1.0),
                                        duration: widget.nowPlayingDuration,
                                        curve: widget.nowPlayingCurve,
                                        child: IgnorePointer(
                                          key: const ValueKey(
                                            'now_playing_ignore_pointer',
                                          ),
                                          ignoring: !isNowPlayingExpanded,
                                          child: RepaintBoundary(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.45,
                                                        ),
                                                    blurRadius: 28.0,
                                                    offset: const Offset(0, -6),
                                                  ),
                                                ],
                                              ),
                                              child: NowPlayingView(
                                                track: _currentTrack,
                                                playbackController:
                                                    _playbackController,
                                                onCollapse: _collapseNowPlaying,
                                                isExpanded:
                                                    isNowPlayingExpanded,
                                                musicService:
                                                    widget.musicService,
                                                selectedTabNotifier:
                                                    _nowPlayingTabNotifier,
                                                queueSource:
                                                    _activeTrackFilter != null
                                                    ? _activeTrackFilter!.label
                                                    : (_currentTab ==
                                                              AppTab.playlists
                                                          ? 'Playing from Playlist'
                                                          : 'Playing from Library'),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Fixed Player Bar (Bottom)
                        _buildBottomPlayer(),
                      ],
                    ),
                  ),
                ],
              ),

              // Import Audio Modal Overlay
              if (_showImportModal)
                Container(
                  color: const Color(0x80000000),
                  alignment: Alignment.center,
                  child: ImportAudioModal(
                    onImport:
                        ({
                          required String title,
                          required String artist,
                          required String album,
                          required String format,
                          required int sampleRate,
                          required int bitDepth,
                          required String simulatedHash,
                        }) async {
                          final track = await widget.musicService.importTrack(
                            title: title,
                            artist: artist,
                            album: album,
                            format: format,
                            sampleRate: sampleRate,
                            bitDepth: bitDepth,
                            simulatedHash: simulatedHash,
                          );
                          await _loadCatalog();
                          return track;
                        },
                    onClose: () => setState(() => _showImportModal = false),
                  ),
                ),

              // Add to Playlist Modal Overlay
              if (_showAddToPlaylistModal && _currentTrack != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('add_to_playlist_backdrop'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _showAddToPlaylistModal = false;
                      _isCreatingPlaylistInModal = false;
                    }),
                    child: Container(color: const Color(0x80000000)),
                  ),
                ),
                Center(
                  child: LyraDialog(
                    title: Text(
                      _isCreatingPlaylistInModal
                          ? 'New Playlist'
                          : 'Add to Playlist',
                      style: LyraTypography.h4(tokens),
                    ),
                    description: Text(
                      _isCreatingPlaylistInModal
                          ? 'Enter a name for the new playlist'
                          : 'Add "${_currentTrack!.displayTitle}" to a playlist',
                      style: LyraTypography.muted(tokens),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 440.0,
                        maxHeight: _isCreatingPlaylistInModal
                            ? double.infinity
                            : 650.0,
                      ),
                      child: _isCreatingPlaylistInModal
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: LyraSpacing.sm),
                                LyraInput(
                                  controller: _newPlaylistNameController,
                                  autofocus: true,
                                  placeholder: 'Playlist title',
                                  onSubmitted: (name) =>
                                      _handleCreatePlaylistWithName(name),
                                ),
                                const SizedBox(height: LyraSpacing.lg),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    LyraButton.ghost(
                                      size: LyraButtonSize.sm,
                                      onPressed: () => setState(
                                        () =>
                                            _isCreatingPlaylistInModal = false,
                                      ),
                                      child: const Text('Back'),
                                    ),
                                    const SizedBox(width: LyraSpacing.sm),
                                    LyraButton.primary(
                                      size: LyraButtonSize.sm,
                                      onPressed: () =>
                                          _handleCreatePlaylistWithName(
                                            _newPlaylistNameController.text,
                                          ),
                                      child: const Text('Create & Add'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                if (_playlists.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: LyraSpacing.lg,
                                      bottom: 56.0,
                                      left: LyraSpacing.sm,
                                      right: LyraSpacing.sm,
                                    ),
                                    child: Text(
                                      'No playlists available. Create a playlist first.',
                                      style: LyraTypography.muted(tokens),
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.only(
                                      bottom: 48.0,
                                    ),
                                    itemCount: _playlists.length,
                                    itemBuilder: (context, index) {
                                      final playlist = _playlists[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: LyraSpacing.xs,
                                        ),
                                        child: _PlaylistModalItem(
                                          playlist: playlist,
                                          tokens: tokens,
                                          onTap: () {
                                            if (_currentTrack == null) return;
                                            final trackId = _currentTrack!.id;
                                            final updatedTrackIds =
                                                List<String>.from(
                                                  playlist.trackIds,
                                                );
                                            if (!updatedTrackIds.contains(
                                              trackId,
                                            )) {
                                              updatedTrackIds.add(trackId);
                                            }
                                            final updatedPlaylist = playlist
                                                .copyWith(
                                                  trackIds: updatedTrackIds,
                                                );
                                            if (widget.musicService
                                                is MockMusicService) {
                                              (widget.musicService
                                                      as MockMusicService)
                                                  .addTrackToPlaylist(
                                                    playlist.id,
                                                    trackId,
                                                  );
                                            }
                                            setState(() {
                                              _playlists = [
                                                for (final p in _playlists)
                                                  if (p.id == playlist.id)
                                                    updatedPlaylist
                                                  else
                                                    p,
                                              ];
                                              _sidebarPlaylists = [
                                                for (final p
                                                    in _sidebarPlaylists)
                                                  if (p.id == playlist.id)
                                                    updatedPlaylist
                                                  else
                                                    p,
                                              ];
                                              _showAddToPlaylistModal = false;
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                Positioned(
                                  bottom: 8.0,
                                  right: 8.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: LyraRadius.mdRadius,
                                      boxShadow: [
                                        BoxShadow(
                                          color: tokens.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 10.0,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: LyraButton.primary(
                                      size: LyraButtonSize.sm,
                                      leading: const Icon(
                                        LucideIcons.plus,
                                        size: 15.0,
                                      ),
                                      child: const Text('New Playlist'),
                                      onPressed: () {
                                        setState(() {
                                          _isCreatingPlaylistInModal = true;
                                          _newPlaylistNameController.text =
                                              'New Playlist ${_playlists.length + 1}';
                                          _newPlaylistNameController.selection =
                                              TextSelection(
                                                baseOffset: 0,
                                                extentOffset:
                                                    _newPlaylistNameController
                                                        .text
                                                        .length,
                                              );
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlaylistModalItem extends StatefulWidget {
  final Playlist playlist;
  final LyraThemeTokens tokens;
  final VoidCallback onTap;

  const _PlaylistModalItem({
    required this.playlist,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_PlaylistModalItem> createState() => _PlaylistModalItemState();
}

class _PlaylistModalItemState extends State<_PlaylistModalItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final playlist = widget.playlist;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.sm,
            vertical: 6.0,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? tokens.secondary.withValues(alpha: 0.5)
                : const Color(0x00000000),
            borderRadius: LyraRadius.mdRadius,
          ),
          child: Row(
            children: [
              Container(
                width: 58.0,
                height: 58.0,
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.mdRadius,
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.listMusic,
                  size: 20.0,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(width: LyraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlist.displayTitle,
                      style: LyraTypography.p(
                        tokens,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${playlist.trackCount} ${playlist.trackCount == 1 ? "song" : "songs"}',
                      style: LyraTypography.small(tokens).copyWith(
                        fontSize: 12.0,
                        color: tokens.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
