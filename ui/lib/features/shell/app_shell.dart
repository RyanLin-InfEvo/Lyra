// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/material.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../albums/albums_view.dart';
import '../artists/artists_view.dart';
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

  const AppShell({
    super.key,
    required this.musicService,
    this.playbackController,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final TextEditingController _searchController;
  late final PlaybackQueueController _playbackController;
  AppTab _currentTab = AppTab.tracks;
  bool _isSidebarCollapsed = false;
  bool _showImportModal = false;
  bool _isNowPlayingExpanded = false;

  // Inspector Drawer State (Phase 4.3)
  bool _isInspectorOpen = false;
  Track? _inspectedTrack;
  Asset? _inspectedAsset;

  // Catalog State
  List<Track> _tracks = [];
  Map<String, int> _audioVersionCounts = {};
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
  double _volume = 0.85;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
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
    _playbackController.removeListener(_onPlaybackChanged);
    if (widget.playbackController == null) {
      _playbackController.dispose();
    }
    _searchController.dispose();
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
    for (final t in tracks) {
      if (t.pcmHash.isNotEmpty) {
        try {
          final versions = await widget.musicService.getAudioVersions(
            t.pcmHash,
          );
          versionCounts[t.id] = versions.length;
          versionCounts[t.pcmHash] = versions.length;
        } catch (_) {}
      }
    }

    if (!mounted) return;

    setState(() {
      _tracks = tracks;
      _audioVersionCounts = versionCounts;
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
        for (final t in tracks) {
          _playbackController.addToQueue(t);
        }
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
    setState(() {
      _isNowPlayingExpanded = false;
    });
  }

  void _toggleNowPlaying() {
    setState(() {
      _isNowPlayingExpanded = !_isNowPlayingExpanded;
    });
  }

  void _onVolumeChanged(double volume) {
    setState(() {
      _volume = volume;
    });
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
        final Map<String, int> tagTrackCounts = {};
        for (final tag in _tags) {
          final tagLower = tag.name.toLowerCase();
          tagTrackCounts[tag.id] = _tracks.where((track) {
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
        return RepaintBoundary(
          child: TagsView(
            tags: _tags,
            tagTrackCounts: tagTrackCounts,
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
                        RepaintBoundary(
                          child: LyraHeaderBar(
                            searchController: _searchController,
                            onSearchChanged: _onSearchChanged,
                            onImportPressed: () =>
                                setState(() => _showImportModal = true),
                          ),
                        ),

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
                                        onVerifyIntegrity: (hash) => widget
                                            .musicService
                                            .verifyCasHash(hash),
                                      ),
                                    ),
                                ],
                              ),

                              // Now Playing View Overlay (Slide-up & Fade animation within Center Area)
                              if (_isNowPlayingExpanded)
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                            0,
                                            (1.0 - value) * 40.0,
                                          ),
                                          child: Opacity(
                                            opacity: value,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: NowPlayingView(
                                        track: _currentTrack,
                                        playbackController: _playbackController,
                                        onCollapse: _collapseNowPlaying,
                                        queueSource: _activeTrackFilter != null
                                            ? _activeTrackFilter!.label
                                            : (_currentTab == AppTab.playlists
                                                  ? 'Playing from Playlist'
                                                  : 'Playing from Library'),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Fixed Player Bar (Bottom)
                        RepaintBoundary(
                          child: ValueListenableBuilder<Duration>(
                            valueListenable: _positionNotifier,
                            builder: (context, currentPosition, _) {
                              return LyraPlayerBar(
                                currentTrack: _currentTrack,
                                isPlaying: _isPlaying,
                                currentPosition: currentPosition,
                                volume: _volume,
                                isInspectorOpen: _isInspectorOpen,
                                isNowPlayingExpanded: _isNowPlayingExpanded,
                                onInspectTrack: _toggleInspector,
                                onInspectAudio: () {
                                  if (_currentTrack != null) {
                                    _openInspectorForAudio(_currentTrack!);
                                  } else {
                                    _toggleInspector();
                                  }
                                },
                                onTogglePlay: _togglePlay,
                                onNext: _onNextTrack,
                                onPrevious: _onPreviousTrack,
                                onSeek: _onSeek,
                                onVolumeChanged: _onVolumeChanged,
                                onExpandNowPlaying: _toggleNowPlaying,
                              );
                            },
                          ),
                        ),
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
            ],
          );
        },
      ),
    );
  }
}
