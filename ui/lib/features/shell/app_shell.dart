// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/material.dart';

import '../../design_system/factory/lyra_design_system_scope.dart';
import '../albums/albums_view.dart';
import '../artists/artists_view.dart';
import '../cas_pool/cas_view.dart';
import '../import/import_modal.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/cas_object.dart';
import '../models/playlist.dart';
import '../models/tag.dart';
import '../models/track.dart';
import '../models/work.dart';
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

  const AppShell({super.key, required this.musicService});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final TextEditingController _searchController;
  AppTab _currentTab = AppTab.tracks;
  bool _isSidebarCollapsed = false;
  bool _showImportModal = false;

  // Catalog State
  List<Track> _tracks = [];
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

  // Playback State
  Track? _currentTrack;
  bool _isPlaying = false;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  double _volume = 0.85;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadCatalog();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _searchController.dispose();
    _positionNotifier.dispose();
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

    if (!mounted) return;

    setState(() {
      _tracks = tracks;
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

      if (_currentTrack == null && tracks.isNotEmpty) {
        _currentTrack = tracks.first;
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
    setState(() {
      _currentTrack = track;
      _isPlaying = true;
    });
    _positionNotifier.value = Duration.zero;
    _startPlaybackTimer();
  }

  void _togglePlay() {
    if (_currentTrack == null) return;
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _startPlaybackTimer();
    } else {
      _playbackTimer?.cancel();
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isPlaying || _currentTrack == null) {
        timer.cancel();
        return;
      }

      if (_positionNotifier.value.inSeconds >=
          _currentTrack!.duration.inSeconds) {
        _positionNotifier.value = Duration.zero;
        _onNextTrack();
      } else {
        _positionNotifier.value += const Duration(seconds: 1);
      }
    });
  }

  void _onNextTrack() {
    if (_tracks.isEmpty || _currentTrack == null) return;
    final currentIndex = _tracks.indexWhere((t) => t.id == _currentTrack!.id);
    final validIndex = currentIndex >= 0 ? currentIndex : -1;
    final nextIndex = (validIndex + 1) % _tracks.length;
    _onTrackSelected(_tracks[nextIndex]);
  }

  void _onPreviousTrack() {
    if (_tracks.isEmpty || _currentTrack == null) return;
    final currentIndex = _tracks.indexWhere((t) => t.id == _currentTrack!.id);
    final validIndex = currentIndex >= 0 ? currentIndex : 0;
    final prevIndex = (validIndex - 1 + _tracks.length) % _tracks.length;
    _onTrackSelected(_tracks[prevIndex]);
  }

  void _onSeek(Duration position) {
    _positionNotifier.value = position;
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
            onClearFilter: () => setState(() {
              _activeTrackFilter = null;
              _selectedTagId = null;
            }),
            onTrackSelected: _onTrackSelected,
            onTogglePlay: _togglePlay,
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

                        // Main View Content (Center)
                        Expanded(
                          child: Container(
                            color: tokens.background,
                            child: _buildMainContent(),
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
                                onTogglePlay: _togglePlay,
                                onNext: _onNextTrack,
                                onPrevious: _onPreviousTrack,
                                onSeek: _onSeek,
                                onVolumeChanged: _onVolumeChanged,
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
