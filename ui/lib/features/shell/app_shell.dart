// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_dialog.dart';
import '../../design_system/widgets/lyra_input.dart';
import '../../design_system/widgets/lyra_spinner.dart';
import '../../design_system/widgets/lyra_toast.dart';
import '../albums/album_detail_view.dart';
import '../albums/albums_view.dart';
import '../artists/artist_detail_view.dart';
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
import '../playlists/playlist_detail_view.dart';
import '../playlists/playlists_view.dart';
import '../services/music_service.dart';
import '../settings/services/preferences_service.dart';
import '../settings/settings_view.dart';
import '../tags/tag_detail_view.dart';
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
  final CasController? casController;
  final DatabaseExplorerController? dbController;
  final BackendSettingsController? backendSettingsController;
  final Curve nowPlayingCurve;
  final Duration nowPlayingDuration;
  final PreferencesService? preferencesService;
  final Map<String, Set<String>>? initialTaggedTrackIds;

  const AppShell({
    super.key,
    required this.musicService,
    this.playbackController,
    this.casController,
    this.dbController,
    this.backendSettingsController,
    this.nowPlayingCurve = LyraAnimation.deceleration,
    this.nowPlayingDuration = LyraAnimation.normal,
    this.preferencesService,
    this.initialTaggedTrackIds,
  });

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final PlaybackQueueController _playbackController;
  late final AudioDeviceController _audioDeviceController;
  late final CasController _casController;
  late final DatabaseExplorerController _dbController;
  late final BackendSettingsController _backendSettingsController;
  AppTab _currentTab = AppTab.tracks;
  CasTab _selectedCasTab = CasTab.storageOverview;
  late bool _isSidebarCollapsed;
  late final ValueNotifier<double> _sidebarWidthNotifier;
  late final ValueNotifier<double> _inspectorWidthNotifier;
  final ValueNotifier<bool> _isNowPlayingExpandedNotifier = ValueNotifier<bool>(
    false,
  );
  bool _isNowPlayingVisible = false;
  final ValueNotifier<int> _nowPlayingTabNotifier = ValueNotifier<int>(0);
  late final ValueNotifier<double> _volumeNotifier;
  Timer? _volumeDebounceTimer;
  Timer? _searchDebounceTimer;

  // Inspector Drawer State (Phase 4.3)
  bool _isInspectorOpen = false;
  bool _isInspectorResizing = false;
  bool _isInspectorVisible = false;
  bool _hasOpenedInspectorOnce = false;
  Track? _inspectedTrack;
  Asset? _inspectedAsset;

  // Catalog State
  List<Track> _tracks = [];
  List<Track> _catalogTracks = [];
  Map<String, int> _audioVersionCounts = {};
  Map<String, int> _tagTrackCounts = {};
  List<Album> _albums = [];
  List<Album> _catalogAlbums = [];
  List<Work> _works = [];
  List<Artist> _artists = [];
  List<Artist> _catalogArtists = [];
  List<Playlist> _sidebarPlaylists = [];
  List<Playlist> _playlists = [];
  List<Tag> _tags = [];
  late final Map<String, Set<String>> _taggedTrackIdsByTag;
  List<CasObject> _casObjects = [];
  String? _selectedPlaylistId;
  String? _selectedAlbumId;
  Album? _transientAlbum;
  String? _albumReturnArtistId;
  Artist? _albumReturnArtist;
  String? _selectedArtistId;
  Artist? _transientArtist;
  String? _selectedTagDetailId;
  String? _selectedTagId;
  Set<String> _selectedTagIds = {};
  TrackFilter? _activeTrackFilter;
  TrackFilterQuery _trackFilterQuery = const TrackFilterQuery();
  bool _isTracksFilterBuilderExpanded = false;
  bool _isLoading = true;
  int _loadCatalogCallId = 0;

  // Table Customization State
  late Set<TrackColumn> _trackVisibleColumns;
  late List<TrackColumn> _trackColumnOrder;
  late Map<String, double> _trackColumnWidths;
  late TrackListViewMode _trackViewMode;
  late bool _showTrackHeader;
  late Set<WorkColumn> _workVisibleColumns;
  late List<WorkColumn> _workColumnOrder;
  late Set<TrackColumn> _playlistVisibleColumns;
  late List<TrackColumn> _playlistColumnOrder;
  late TrackListViewMode _playlistViewMode;
  late bool _showPlaylistHeader;
  late TrackActivationMode _trackActivationMode;
  late NotificationPosition _notificationPosition;
  late final LyraToastController _toastController;

  // Playback State delegation
  Track? get _currentTrack => _playbackController.currentTrack;
  bool get _isPlaying => _playbackController.isPlaying;
  ValueNotifier<Duration> get _positionNotifier =>
      _playbackController.positionNotifier;

  static bool trackMatchesTag(
    Track track,
    Tag tag, [
    Map<String, Set<String>>? taggedTrackIds,
  ]) {
    if (taggedTrackIds?[tag.id]?.contains(track.id) ?? false) {
      return true;
    }
    final tagLower = tag.name.trim().toLowerCase();
    final subLower = tag.subTagName.trim().toLowerCase();
    final hasTagMatch = tagLower.isNotEmpty;
    final hasSubMatch = subLower.isNotEmpty && subLower != tagLower;

    if (tagLower == 'hi-res' || subLower == 'hi-res') {
      return (track.bitDepth != null && track.bitDepth! >= 24) ||
          (track.sampleRate != null && track.sampleRate! > 48000);
    }
    if (tagLower == 'audiophile' ||
        subLower == 'audiophile' ||
        tagLower == 'reference master' ||
        subLower == 'reference master' ||
        tagLower == 'direct stream' ||
        subLower == 'direct stream') {
      return track.verified ||
          (track.bitDepth != null && track.bitDepth! >= 24);
    }
    final genreLower = (track.genre ?? '').toLowerCase();
    final formatLower = (track.format ?? '').toLowerCase();
    final titleLower = track.displayTitle.toLowerCase();
    final artistLower = track.artist.toLowerCase();
    final albumLower = track.album.toLowerCase();

    final groupLower = tag.groupName.trim().toLowerCase();
    if (groupLower == 'artist') {
      return (hasSubMatch && artistLower.contains(subLower)) ||
          (hasTagMatch && artistLower.contains(tagLower));
    }
    if (groupLower == 'genre') {
      return (hasSubMatch && genreLower.contains(subLower)) ||
          (hasTagMatch && genreLower.contains(tagLower));
    }
    if (groupLower == 'album') {
      return (hasSubMatch && albumLower.contains(subLower)) ||
          (hasTagMatch && albumLower.contains(tagLower));
    }

    return (hasTagMatch &&
            (formatLower.contains(tagLower) ||
                genreLower.contains(tagLower) ||
                titleLower.contains(tagLower) ||
                artistLower.contains(tagLower) ||
                albumLower.contains(tagLower))) ||
        (hasSubMatch &&
            (formatLower.contains(subLower) ||
                genreLower.contains(subLower) ||
                titleLower.contains(subLower) ||
                artistLower.contains(subLower) ||
                albumLower.contains(subLower)));
  }

  static Map<String, int> _computeTagTrackCounts(
    List<Tag> tags,
    List<Track> tracks, [
    Map<String, Set<String>>? taggedTrackIds,
  ]) {
    final Map<String, int> counts = {};
    for (final tag in tags) {
      counts[tag.id] = tracks.where((track) {
        return trackMatchesTag(track, tag, taggedTrackIds);
      }).length;
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _isSidebarCollapsed =
        widget.preferencesService?.isSidebarCollapsed ?? false;
    _sidebarWidthNotifier = ValueNotifier<double>(
      (widget.preferencesService?.sidebarWidth ?? 210.0).clamp(160.0, 420.0),
    );
    _inspectorWidthNotifier = ValueNotifier<double>(
      (widget.preferencesService?.inspectorWidth ?? 420.0).clamp(300.0, 1000.0),
    );
    _volumeNotifier = ValueNotifier<double>(
      widget.preferencesService?.volume ?? 0.85,
    );
    _volumeNotifier.addListener(_onVolumeNotifierChanged);
    _trackActivationMode =
        widget.preferencesService?.trackActivationMode ??
        TrackActivationMode.doubleClick;
    _notificationPosition =
        widget.preferencesService?.notificationPosition ??
        NotificationPosition.bottomLeft;
    _toastController = LyraToastController(
      preferencesService: widget.preferencesService,
    );
    widget.preferencesService?.addListener(_onPreferencesChanged);
    _initColumns();
    _isNowPlayingVisible = _isNowPlayingExpandedNotifier.value;
    _isNowPlayingExpandedNotifier.addListener(_onNowPlayingExpandedChanged);
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _audioDeviceController = AudioDeviceController();
    _casController =
        widget.casController ?? CasController(initialObjects: _casObjects);
    _dbController = widget.dbController ?? DatabaseExplorerController();
    _backendSettingsController =
        widget.backendSettingsController ?? BackendSettingsController();
    _playbackController =
        widget.playbackController ??
        PlaybackQueueController(timerInterval: const Duration(seconds: 1));
    _playbackController.addListener(_onPlaybackChanged);
    _taggedTrackIdsByTag = {};
    if (widget.initialTaggedTrackIds != null) {
      widget.initialTaggedTrackIds!.forEach(
        (k, v) => _taggedTrackIdsByTag[k] = Set<String>.from(v),
      );
    }
    _loadCatalog();
  }

  void _onPreferencesChanged() {
    if (!mounted) return;
    final prefs = widget.preferencesService;
    if (prefs == null) return;
    if (_sidebarWidthNotifier.value != prefs.sidebarWidth) {
      _sidebarWidthNotifier.value = prefs.sidebarWidth;
    }
    final clampedInspectorWidth = prefs.inspectorWidth.clamp(300.0, 1000.0);
    if (_inspectorWidthNotifier.value != clampedInspectorWidth) {
      _inspectorWidthNotifier.value = clampedInspectorWidth;
    }
    if ((_volumeNotifier.value - prefs.volume).abs() > 0.001) {
      _volumeNotifier.value = prefs.volume;
    }
    bool needsRebuild = false;
    if (_isSidebarCollapsed != prefs.isSidebarCollapsed) {
      _isSidebarCollapsed = prefs.isSidebarCollapsed;
      needsRebuild = true;
    }
    if (_trackActivationMode != prefs.trackActivationMode) {
      _trackActivationMode = prefs.trackActivationMode;
      needsRebuild = true;
    }
    if (_notificationPosition != prefs.notificationPosition) {
      _notificationPosition = prefs.notificationPosition;
      needsRebuild = true;
    }
    final oldTrackOrder = _trackColumnOrder;
    final oldTrackVisible = _trackVisibleColumns;
    final oldTrackWidths = _trackColumnWidths;
    final oldTrackViewMode = _trackViewMode;
    final oldShowTrackHeader = _showTrackHeader;
    final oldWorkOrder = _workColumnOrder;
    final oldWorkVisible = _workVisibleColumns;
    final oldPlaylistOrder = _playlistColumnOrder;
    final oldPlaylistVisible = _playlistVisibleColumns;
    final oldPlaylistViewMode = _playlistViewMode;
    final oldShowPlaylistHeader = _showPlaylistHeader;
    _initColumns();
    if (!listEquals(oldTrackOrder, _trackColumnOrder) ||
        !setEquals(oldTrackVisible, _trackVisibleColumns) ||
        !mapEquals(oldTrackWidths, _trackColumnWidths) ||
        oldTrackViewMode != _trackViewMode ||
        oldShowTrackHeader != _showTrackHeader ||
        !listEquals(oldWorkOrder, _workColumnOrder) ||
        !setEquals(oldWorkVisible, _workVisibleColumns) ||
        !listEquals(oldPlaylistOrder, _playlistColumnOrder) ||
        !setEquals(oldPlaylistVisible, _playlistVisibleColumns) ||
        oldPlaylistViewMode != _playlistViewMode ||
        oldShowPlaylistHeader != _showPlaylistHeader) {
      needsRebuild = true;
    }
    if (needsRebuild) {
      setState(() {});
    }
  }

  void _onVolumeNotifierChanged() {
    _volumeDebounceTimer?.cancel();
    _volumeDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.preferencesService?.setVolume(_volumeNotifier.value);
    });
  }

  void _initColumns() {
    final trackColumnMap = {
      for (final col in TrackColumn.values) col.name: col,
    };
    final savedTrackOrder = widget.preferencesService?.getTrackColumnOrder();
    if (savedTrackOrder != null) {
      final restored = savedTrackOrder
          .map((name) => trackColumnMap[name])
          .whereType<TrackColumn>()
          .toList();
      for (final col in TrackColumn.values) {
        if (!restored.contains(col)) {
          restored.add(col);
        }
      }
      _trackColumnOrder = restored;
    } else {
      _trackColumnOrder = List<TrackColumn>.from(TrackColumn.values);
    }

    final savedTrackVisible = widget.preferencesService
        ?.getTrackVisibleColumns();
    if (savedTrackVisible != null) {
      final restored = savedTrackVisible
          .map((name) => trackColumnMap[name])
          .whereType<TrackColumn>()
          .toSet();
      if (restored.isEmpty) {
        _trackVisibleColumns = Set<TrackColumn>.from(
          TrackColumn.defaultVisibleColumns,
        );
      } else {
        _trackVisibleColumns = restored;
      }
      for (final col in TrackColumn.values) {
        if (col.isMandatory) {
          _trackVisibleColumns.add(col);
        }
      }
    } else {
      _trackVisibleColumns = Set<TrackColumn>.from(
        TrackColumn.defaultVisibleColumns,
      );
    }

    final workColumnMap = {for (final col in WorkColumn.values) col.name: col};
    final savedWorkOrder = widget.preferencesService?.getWorkColumnOrder();
    if (savedWorkOrder != null) {
      final restored = savedWorkOrder
          .map((name) => workColumnMap[name])
          .whereType<WorkColumn>()
          .toList();
      for (final col in WorkColumn.values) {
        if (!restored.contains(col)) {
          restored.add(col);
        }
      }
      _workColumnOrder = restored;
    } else {
      _workColumnOrder = List<WorkColumn>.from(WorkColumn.values);
    }

    final savedWorkVisible = widget.preferencesService?.getWorkVisibleColumns();
    if (savedWorkVisible != null) {
      final restored = savedWorkVisible
          .map((name) => workColumnMap[name])
          .whereType<WorkColumn>()
          .toSet();
      if (restored.isEmpty) {
        _workVisibleColumns = Set<WorkColumn>.from(
          WorkColumn.defaultVisibleColumns,
        );
      } else {
        _workVisibleColumns = restored;
      }
      for (final col in WorkColumn.values) {
        if (col.isMandatory) {
          _workVisibleColumns.add(col);
        }
      }
    } else {
      _workVisibleColumns = Set<WorkColumn>.from(
        WorkColumn.defaultVisibleColumns,
      );
    }

    final savedPlaylistOrder = widget.preferencesService
        ?.getPlaylistColumnOrder();
    if (savedPlaylistOrder != null) {
      final restored = savedPlaylistOrder
          .map((name) => trackColumnMap[name])
          .whereType<TrackColumn>()
          .toList();
      for (final col in TrackColumn.values) {
        if (!restored.contains(col)) {
          restored.add(col);
        }
      }
      _playlistColumnOrder = restored;
    } else {
      _playlistColumnOrder = List<TrackColumn>.from(TrackColumn.values);
    }

    final savedPlaylistVisible = widget.preferencesService
        ?.getPlaylistVisibleColumns();
    if (savedPlaylistVisible != null) {
      final restored = savedPlaylistVisible
          .map((name) => trackColumnMap[name])
          .whereType<TrackColumn>()
          .toSet();
      if (restored.isEmpty) {
        _playlistVisibleColumns = Set<TrackColumn>.from(
          PlaylistDetailView.defaultVisibleColumns,
        );
      } else {
        _playlistVisibleColumns = restored;
      }
      for (final col in TrackColumn.values) {
        if (col.isMandatory) {
          _playlistVisibleColumns.add(col);
        }
      }
    } else {
      _playlistVisibleColumns = Set<TrackColumn>.from(
        PlaylistDetailView.defaultVisibleColumns,
      );
    }

    _trackColumnWidths = Map<String, double>.from(
      widget.preferencesService?.trackColumnWidths ?? const {},
    );
    _trackViewMode =
        widget.preferencesService?.trackViewMode ?? TrackListViewMode.detail;
    _showTrackHeader = widget.preferencesService?.showTrackHeader ?? true;
    _playlistViewMode =
        widget.preferencesService?.playlistViewMode ?? TrackListViewMode.detail;
    _showPlaylistHeader = widget.preferencesService?.showPlaylistHeader ?? true;
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    widget.preferencesService?.removeListener(_onPreferencesChanged);
    if (_volumeDebounceTimer?.isActive ?? false) {
      _volumeDebounceTimer?.cancel();
      widget.preferencesService?.setVolume(_volumeNotifier.value);
    }
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _searchFocusNode.dispose();
    _audioDeviceController.dispose();
    if (widget.casController == null) {
      _casController.dispose();
    }
    if (widget.dbController == null) {
      _dbController.dispose();
    }
    if (widget.backendSettingsController == null) {
      _backendSettingsController.dispose();
    }
    _volumeNotifier.removeListener(_onVolumeNotifierChanged);
    _volumeNotifier.dispose();
    _nowPlayingTabNotifier.dispose();
    _playbackController.removeListener(_onPlaybackChanged);
    if (widget.playbackController == null) {
      _playbackController.dispose();
    }
    _searchController.dispose();
    _sidebarWidthNotifier.dispose();
    _inspectorWidthNotifier.dispose();
    _isNowPlayingExpandedNotifier.removeListener(_onNowPlayingExpandedChanged);
    _isNowPlayingExpandedNotifier.dispose();
    _toastController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog({String? query}) async {
    final callId = ++_loadCatalogCallId;
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

    if (!mounted || callId != _loadCatalogCallId) return;

    final effectiveCatalogTracks =
        (query == null || query.isEmpty || _catalogTracks.isEmpty)
        ? tracks
        : _catalogTracks;

    final tagTrackCounts = _computeTagTrackCounts(
      tags,
      effectiveCatalogTracks,
      _taggedTrackIdsByTag,
    );

    setState(() {
      _tracks = tracks;
      if (query == null || query.isEmpty) {
        _catalogTracks = tracks;
        _catalogAlbums = albums;
        _catalogArtists = artists;
        _sidebarPlaylists = playlists;
      } else {
        if (_catalogTracks.isEmpty) _catalogTracks = tracks;
        if (_catalogAlbums.isEmpty) _catalogAlbums = albums;
        if (_catalogArtists.isEmpty) _catalogArtists = artists;
      }
      if (_inspectedTrack != null) {
        final synced = tracks
            .where((t) => t.id == _inspectedTrack!.id)
            .firstOrNull;
        if (synced != null) {
          _inspectedTrack = synced;
        }
      }
      _audioVersionCounts = versionCounts;
      _tagTrackCounts = tagTrackCounts;
      _albums = albums;
      _works = works;
      _artists = artists;
      _playlists = playlists;
      _tags = tags;
      _casObjects = casObjects;
      _casController.setCasObjects(casObjects);
      _isLoading = false;

      if (query == null || query.isEmpty) {
        final validTagIds = tags.map((t) => t.id).toSet();
        _taggedTrackIdsByTag.removeWhere((id, _) => !validTagIds.contains(id));
        final removedTagIds = _selectedTagIds.difference(validTagIds);
        if (removedTagIds.isNotEmpty) {
          _selectedTagIds = _selectedTagIds.intersection(validTagIds);
          if (_selectedTagId != null && !validTagIds.contains(_selectedTagId)) {
            _selectedTagId = _selectedTagIds.isEmpty
                ? null
                : _selectedTagIds.last;
          }
          if (_activeTrackFilter != null) {
            _rebuildTagTrackFilterFromSelection();
          }
        }
        _trackFilterQuery = _trackFilterQuery.retainValidTagIds(validTagIds);
      }

      if (_selectedPlaylistId != null &&
          !_sidebarPlaylists.any((p) => p.id == _selectedPlaylistId)) {
        _selectedPlaylistId = null;
      }
      if (_selectedAlbumId != null &&
          _resolveAlbumById(_selectedAlbumId!) == null) {
        _selectedAlbumId = null;
        _transientAlbum = null;
        _albumReturnArtistId = null;
        _albumReturnArtist = null;
      }
      if (_albumReturnArtistId != null &&
          (_albumReturnArtist == null ||
              !_albumReturnArtist!.id.startsWith('virtual-artist:')) &&
          _resolveArtistById(_albumReturnArtistId!) == null) {
        _albumReturnArtistId = null;
        _albumReturnArtist = null;
      }
      if (_selectedArtistId != null &&
          _resolveArtistById(_selectedArtistId!) == null) {
        _selectedArtistId = null;
        _transientArtist = null;
      }
      if (_selectedTagDetailId != null &&
          _resolveTagById(_selectedTagDetailId!) == null) {
        _selectedTagDetailId = null;
      }

      if (_playbackController.queue.isEmpty && tracks.isNotEmpty) {
        _playbackController.addAllToQueue(tracks);
      }
    });
  }

  void _onSearchChanged(String query) {
    if (query.isNotEmpty) {
      _activeTrackFilter = null;
      _trackFilterQuery = const TrackFilterQuery();
      _selectedTagId = null;
      _selectedTagIds = {};
    }
    _searchDebounceTimer?.cancel();
    if (query.isEmpty) {
      _loadCatalog(query: '');
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        _loadCatalog(query: query);
      }
    });
  }

  void _onSearchSubmitted(String query) {
    _searchDebounceTimer?.cancel();
    if (query.isNotEmpty) {
      _activeTrackFilter = null;
      _trackFilterQuery = const TrackFilterQuery();
      _selectedTagId = null;
      _selectedTagIds = {};
    }
    _loadCatalog(query: query);

    if (_isNowPlayingExpandedNotifier.value) {
      _collapseNowPlaying();
    }

    if (_currentTab != AppTab.tracks &&
        _currentTab != AppTab.albums &&
        _currentTab != AppTab.artists &&
        _currentTab != AppTab.works) {
      setState(() {
        _currentTab = AppTab.tracks;
      });
    }
  }

  List<Track> get _trackCatalogSource =>
      _catalogTracks.isNotEmpty ? _catalogTracks : _tracks;

  List<Album> get _albumCatalogSource =>
      _catalogAlbums.isNotEmpty ? _catalogAlbums : _albums;

  List<Artist> get _artistCatalogSource =>
      _catalogArtists.isNotEmpty ? _catalogArtists : _artists;

  TrackFilterContext _buildTrackFilterContext() {
    final catalogTracks = _trackCatalogSource;
    final catalogPlaylists = _sidebarPlaylists.isNotEmpty
        ? _sidebarPlaylists
        : _playlists;
    final effectiveTaggedTrackIds = <String, Set<String>>{};
    for (final tag in _tags) {
      final matched = <String>{
        for (final t in catalogTracks)
          if (_trackMatchesTag(t, tag)) t.id,
      };
      if (matched.isNotEmpty) {
        effectiveTaggedTrackIds[tag.id] = matched;
      }
    }
    return TrackFilterContext.fromLibrary(
      tracks: catalogTracks,
      tags: _tags,
      playlists: catalogPlaylists,
      taggedTrackIdsByTag: effectiveTaggedTrackIds,
    );
  }

  List<Track> _applyTracksFiltering(
    List<Track> source,
    TrackFilterContext context,
  ) {
    var result = source;
    if (_activeTrackFilter != null) {
      result = result.where(_activeTrackFilter!.predicate).toList();
    }
    if (_trackFilterQuery.isActive) {
      result = _trackFilterQuery.apply(result, context);
    }
    return result;
  }

  void _onTrackSelected(Track track) {
    final filterContext = _buildTrackFilterContext();
    final effectiveTracks = _applyTracksFiltering(_tracks, filterContext);
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

  bool get isNowPlayingExpanded => _isNowPlayingExpanded;
  set isNowPlayingExpanded(bool value) => _isNowPlayingExpanded = value;

  bool get isSidebarCollapsed => _isSidebarCollapsed;
  ValueNotifier<double> get sidebarWidthNotifier => _sidebarWidthNotifier;
  ValueNotifier<double> get inspectorWidthNotifier => _inspectorWidthNotifier;
  ValueNotifier<double> get volumeNotifier => _volumeNotifier;
  List<TrackColumn> get trackColumnOrder => _trackColumnOrder;
  Set<TrackColumn> get trackVisibleColumns => _trackVisibleColumns;
  List<WorkColumn> get workColumnOrder => _workColumnOrder;
  Set<WorkColumn> get workVisibleColumns => _workVisibleColumns;
  List<TrackColumn> get playlistColumnOrder => _playlistColumnOrder;
  Set<TrackColumn> get playlistVisibleColumns => _playlistVisibleColumns;
  TrackFilter? get activeTrackFilter => _activeTrackFilter;
  TrackFilterQuery get trackFilterQuery => _trackFilterQuery;
  String? get selectedTagId => _selectedTagId;
  Set<String> get selectedTagIds => _selectedTagIds;
  String? get selectedPlaylistId => _selectedPlaylistId;
  String? get selectedAlbumId => _selectedAlbumId;
  String? get selectedArtistId => _selectedArtistId;
  String? get selectedTagDetailId => _selectedTagDetailId;

  @visibleForTesting
  void setTagAndPlaylistSelectionForTesting({
    String? tagId,
    Set<String>? tagIds,
    String? playlistId,
  }) {
    _selectedTagId = tagId;
    _selectedTagIds = tagIds ?? {};
    _selectedPlaylistId = playlistId;
  }

  @visibleForTesting
  Future<void> reloadCatalogForTesting() => _loadCatalog();

  bool get _isNowPlayingExpanded => _isNowPlayingExpandedNotifier.value;
  set _isNowPlayingExpanded(bool value) {
    if (_isNowPlayingExpandedNotifier.value != value) {
      _isNowPlayingExpandedNotifier.value = value;
    }
  }

  void _collapseNowPlaying() {
    _isNowPlayingExpanded = false;
  }

  void _clearDetailSelections({bool preservePlaylist = false}) {
    if (!preservePlaylist) {
      _selectedPlaylistId = null;
    }
    _selectedAlbumId = null;
    _transientAlbum = null;
    _albumReturnArtistId = null;
    _albumReturnArtist = null;
    _selectedArtistId = null;
    _transientArtist = null;
    _selectedTagDetailId = null;
  }

  void _rebuildTagTrackFilterFromSelection() {
    if (_selectedTagIds.isEmpty) {
      _selectedTagId = null;
      _activeTrackFilter = null;
      return;
    }
    if (_selectedTagId == null || !_selectedTagIds.contains(_selectedTagId)) {
      _selectedTagId = _selectedTagIds.last;
    }
    final selectedTags = [
      for (final id in _selectedTagIds)
        _tags.firstWhere(
          (t) => t.id == id,
          orElse: () => Tag(id: id, name: id),
        ),
    ];
    final label = selectedTags.length == 1
        ? 'Tag: ${selectedTags.first.name}'
        : 'Tags: ${selectedTags.map((t) => t.name).join(', ')}';
    _activeTrackFilter = TrackFilter(
      label: label,
      predicate: (track) => selectedTags.any((t) => _trackMatchesTag(track, t)),
    );
  }

  void _clearTransientNavigationFilter() {
    _activeTrackFilter = null;
  }

  void _onCollectionVisibleColumnsChanged(Set<TrackColumn> columns) {
    setState(() {
      _playlistVisibleColumns = columns;
    });
    widget.preferencesService?.setPlaylistVisibleColumns(
      columns.map((c) => c.name).toSet(),
    );
  }

  void _onCollectionColumnOrderChanged(List<TrackColumn> order) {
    setState(() {
      _playlistColumnOrder = order;
    });
    widget.preferencesService?.setPlaylistColumnOrder(
      order.map((c) => c.name).toList(),
    );
  }

  void _navigateToSettings() {
    _collapseNowPlaying();
    setState(() {
      _clearDetailSelections();
      _clearTransientNavigationFilter();
      _currentTab = AppTab.settings;
    });
  }

  Album? _resolveAlbumById(String id) {
    for (final album in _albums) {
      if (album.id == id) return album;
    }
    for (final album in _catalogAlbums) {
      if (album.id == id) return album;
    }
    if (_transientAlbum?.id == id) return _transientAlbum;
    return null;
  }

  Artist? _resolveArtistById(String id) {
    for (final artist in _artists) {
      if (artist.id == id) return artist;
    }
    for (final artist in _catalogArtists) {
      if (artist.id == id) return artist;
    }
    if (_transientArtist?.id == id) return _transientArtist;
    return null;
  }

  Tag? _resolveTagById(String id) {
    for (final tag in _tags) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  List<Track> _tracksForAlbum(Album album, List<Track> source) {
    final targetTitle = album.title.trim().toLowerCase();
    final targetArtist = album.artist.trim().toLowerCase();
    return source.where((t) {
      if (t.album.trim().toLowerCase() != targetTitle) return false;
      if (targetArtist.isEmpty || t.artist.trim().isEmpty) return true;
      return _artistMatchesName(t.artist, album.artist) ||
          _artistMatchesName(album.artist, t.artist);
    }).toList();
  }

  bool _artistMatchesName(String trackOrAlbumArtist, String artistName) {
    final candidate = trackOrAlbumArtist.trim().toLowerCase();
    final target = artistName.trim().toLowerCase();
    if (candidate.isEmpty || target.isEmpty) return false;
    if (candidate == target) return true;
    final boundaryPattern = RegExp(
      '(^|[^\\p{L}\\p{M}\\p{N}])${RegExp.escape(target)}([^\\p{L}\\p{M}\\p{N}]|\$)',
      unicode: true,
    );
    return boundaryPattern.hasMatch(candidate);
  }

  List<Track> _tracksForArtist(Artist artist, List<Track> source) {
    return source
        .where((t) => _artistMatchesName(t.artist, artist.name))
        .toList();
  }

  List<Album> _albumsForArtist(Artist artist, List<Track> artistTracks) {
    final trackAlbums = artistTracks
        .map((t) => t.album.trim().toLowerCase())
        .where((a) => a.isNotEmpty)
        .toSet();
    return _albumCatalogSource.where((album) {
      if (_artistMatchesName(album.artist, artist.name)) {
        return true;
      }
      return trackAlbums.contains(album.title.trim().toLowerCase());
    }).toList();
  }

  List<Track> _tracksForTag(Tag tag, List<Track> source) {
    return source.where((t) => _trackMatchesTag(t, tag)).toList();
  }

  void _playCollectionAll(List<Track> collectionTracks) {
    if (collectionTracks.isNotEmpty) {
      _playbackController.play(
        collectionTracks.first,
        contextQueue: collectionTracks,
      );
    }
  }

  void _shuffleCollectionAll(List<Track> collectionTracks) {
    if (collectionTracks.isNotEmpty) {
      final shuffled = List<Track>.from(collectionTracks)..shuffle();
      _playbackController.play(shuffled.first, contextQueue: shuffled);
    }
  }

  void _playCollectionTrack(Track track, List<Track> collectionTracks) {
    _playbackController.play(track, contextQueue: collectionTracks);
    _handleInspectorTrackFocus(track);
  }

  void _handleInspectorTrackFocus(Track track) {
    if (_isInspectorOpen) {
      setState(() {
        _inspectedTrack = track;
        _inspectedAsset = null;
      });
    }
  }

  void _openAlbumDetail(Album album, {String? returnArtistId}) {
    _collapseNowPlaying();
    final isKnown = _albumCatalogSource.any((a) => a.id == album.id);
    final returnArtist = returnArtistId != null
        ? _resolveArtistById(returnArtistId)
        : null;
    setState(() {
      _clearDetailSelections();
      _clearTransientNavigationFilter();
      _selectedAlbumId = album.id;
      _transientAlbum = isKnown ? null : album;
      _albumReturnArtistId = returnArtistId;
      _albumReturnArtist = returnArtist;
      _currentTab = AppTab.albums;
    });
  }

  void _openArtistDetail(Artist artist) {
    _collapseNowPlaying();
    final isKnown = _artistCatalogSource.any((a) => a.id == artist.id);
    setState(() {
      _clearDetailSelections();
      _clearTransientNavigationFilter();
      _selectedArtistId = artist.id;
      _transientArtist = isKnown ? null : artist;
      _currentTab = AppTab.artists;
    });
  }

  void _openTagDetail(Tag tag) {
    _collapseNowPlaying();
    setState(() {
      _clearDetailSelections();
      _selectedTagDetailId = tag.id;
      _currentTab = AppTab.tags;
    });
  }

  void _navigateToAlbum(String albumTitle) {
    final title = albumTitle.trim();
    if (title.isEmpty) return;
    final lower = title.toLowerCase();
    final returnArtistId =
        (_currentTab == AppTab.artists && _selectedArtistId != null)
        ? _selectedArtistId
        : null;

    Album? matched;
    for (final album in _albumCatalogSource) {
      if (album.title.trim().toLowerCase() == lower) {
        matched = album;
        break;
      }
    }

    if (matched == null) {
      final matchingTracks = _trackCatalogSource
          .where((t) => t.album.trim().toLowerCase() == lower)
          .toList();
      final first = matchingTracks.isNotEmpty ? matchingTracks.first : null;
      matched = Album(
        id: 'virtual-album:$lower',
        title: title,
        artistName: first?.artistName,
        releaseYear: first?.recordingYear,
        releaseMonth: first?.recordingMonth,
        releaseDay: first?.recordingDay,
        format: first?.format ?? 'FLAC',
        totalTracks: matchingTracks.length,
      );
    }

    _openAlbumDetail(matched, returnArtistId: returnArtistId);
  }

  void _navigateToArtist(String artistName) {
    final name = artistName.trim();
    if (name.isEmpty) return;
    final lower = name.toLowerCase();

    Artist? matched;
    for (final artist in _artistCatalogSource) {
      if (artist.name.trim().toLowerCase() == lower) {
        matched = artist;
        break;
      }
    }
    matched ??= _artistCatalogSource.cast<Artist?>().firstWhere((artist) {
      final candidate = artist!.name.trim().toLowerCase();
      return candidate.isNotEmpty && _artistMatchesName(name, artist.name);
    }, orElse: () => null);
    matched ??= Artist(id: 'virtual-artist:$lower', name: name);

    _openArtistDetail(matched);
  }

  void _toggleNowPlaying() {
    _isNowPlayingExpandedNotifier.value = !_isNowPlayingExpandedNotifier.value;
  }

  void _onNowPlayingExpandedChanged() {
    if (_isNowPlayingExpandedNotifier.value && !_isNowPlayingVisible) {
      setState(() {
        _isNowPlayingVisible = true;
      });
    }
  }

  void _onNowPlayingSlideEnd() {
    if (!_isNowPlayingExpandedNotifier.value && _isNowPlayingVisible) {
      if (mounted) {
        setState(() {
          _isNowPlayingVisible = false;
        });
      }
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
    widget.preferencesService?.setSidebarCollapsed(_isSidebarCollapsed);
  }

  void _toggleAudioInspector() {
    if (_isNowPlayingExpandedNotifier.value) {
      // Toggle between Details (tab 2) and Up Next (tab 0) in NowPlayingView
      if (_nowPlayingTabNotifier.value == 2) {
        _nowPlayingTabNotifier.value = 0;
      } else {
        _nowPlayingTabNotifier.value = 2;
      }
    } else {
      _toggleInspector();
    }
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final isEditingText =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
    final isMetaOrCtrl =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.meta,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.control,
        );

    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (!isEditingText) {
        _togglePlay();
        return true;
      }
      return false;
    }

    if (isMetaOrCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      _searchFocusNode.requestFocus();
      return true;
    }

    if (isMetaOrCtrl && event.logicalKey == LogicalKeyboardKey.keyI) {
      _toggleAudioInspector();
      return true;
    }

    if (isMetaOrCtrl && event.logicalKey == LogicalKeyboardKey.keyB) {
      _toggleSidebar();
      return true;
    }

    if (isMetaOrCtrl && event.logicalKey == LogicalKeyboardKey.comma) {
      _navigateToSettings();
      return true;
    }

    return false;
  }

  void _showImportDialog() {
    final scope = LyraDesignSystemScope.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LyraDesignSystemScope(
        factory: scope.factory,
        tokens: scope.tokens,
        themeModeNotifier: scope.themeModeNotifier,
        child: LyraImportModal(
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
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _showBatchAddToPlaylistDialog(List<Track> tracks) {
    if (tracks.isEmpty) return;
    final scope = LyraDesignSystemScope.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LyraDesignSystemScope(
        factory: scope.factory,
        tokens: scope.tokens,
        themeModeNotifier: scope.themeModeNotifier,
        child: _AddToPlaylistDialog(
          tracks: tracks,
          playlists: _playlists,
          musicService: widget.musicService,
          onPlaylistUpdated: (updatedPlaylist) {
            setState(() {
              _playlists = [
                for (final p in _playlists)
                  if (p.id == updatedPlaylist.id) updatedPlaylist else p,
              ];
              _sidebarPlaylists = [
                for (final p in _sidebarPlaylists)
                  if (p.id == updatedPlaylist.id) updatedPlaylist else p,
              ];
            });
            _loadCatalog();
          },
        ),
      ),
    );
  }

  void _handleTrackUpdated(Track updatedTrack) {
    setState(() {
      if (_inspectedTrack?.id == updatedTrack.id) {
        _inspectedTrack = updatedTrack;
      }
      _tracks = [
        for (final t in _tracks)
          if (t.id == updatedTrack.id) updatedTrack else t,
      ];
      _catalogTracks = [
        for (final t in _catalogTracks)
          if (t.id == updatedTrack.id) updatedTrack else t,
      ];
    });

    _playbackController.updateTrack(updatedTrack);
    _loadCatalog(
      query: _searchController.text.isNotEmpty ? _searchController.text : null,
    );
  }

  void _showAddToPlaylistDialog([Track? track]) {
    final effectiveTrack = track ?? _currentTrack;
    if (effectiveTrack == null) return;
    _showBatchAddToPlaylistDialog([effectiveTrack]);
  }

  void _showBatchTagDialog(List<Track> tracks) {
    if (tracks.isEmpty) return;
    final scope = LyraDesignSystemScope.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LyraDesignSystemScope(
        factory: scope.factory,
        tokens: scope.tokens,
        themeModeNotifier: scope.themeModeNotifier,
        child: _BatchTagDialog(
          tracks: tracks,
          tags: _tags,
          musicService: widget.musicService,
          onTagApplied: (tag) async {
            setState(() {
              if (!_tags.any((t) => t.id == tag.id)) {
                _tags = [..._tags, tag];
              }
              final set = _taggedTrackIdsByTag.putIfAbsent(
                tag.id,
                () => <String>{},
              );
              set.addAll(tracks.map((t) => t.id));
              final effectiveCatalogTracks = _catalogTracks.isNotEmpty
                  ? _catalogTracks
                  : _tracks;
              _tagTrackCounts = _computeTagTrackCounts(
                _tags,
                effectiveCatalogTracks,
                _taggedTrackIdsByTag,
              );
            });
          },
        ),
      ),
    );
  }

  void _onVolumeChanged(double volume) {
    _volumeNotifier.value = volume;
  }

  bool _trackMatchesTag(Track track, Tag tag) {
    return trackMatchesTag(track, tag, _taggedTrackIdsByTag);
  }

  void _filterByTag(Tag tag) {
    _isNowPlayingExpanded = false;
    final updatedTagIds = _currentTab == AppTab.tracks
        ? Set<String>.from(_selectedTagIds)
        : <String>{};
    if (updatedTagIds.contains(tag.id)) {
      updatedTagIds.remove(tag.id);
    } else {
      updatedTagIds.add(tag.id);
    }

    setState(() {
      _selectedTagIds = updatedTagIds;
      _clearDetailSelections();

      if (_selectedTagIds.isEmpty) {
        _trackFilterQuery = const TrackFilterQuery();
      } else {
        _trackFilterQuery = TrackFilterQuery.forTags(_selectedTagIds);
        _currentTab = AppTab.tracks;
      }
      _rebuildTagTrackFilterFromSelection();
    });
  }

  void _filterInTracksForSingleTag(Tag tag) {
    _isNowPlayingExpanded = false;
    setState(() {
      _clearDetailSelections();
      _selectedTagIds = {tag.id};
      _selectedTagId = tag.id;
      _trackFilterQuery = TrackFilterQuery.forTags([tag.id]);
      _activeTrackFilter = TrackFilter(
        label: 'Tag: ${tag.name}',
        predicate: (track) => _trackMatchesTag(track, tag),
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
      _clearDetailSelections();
      _clearTransientNavigationFilter();
      _selectedPlaylistId = newPl.id;
      _currentTab = AppTab.playlists;
    });
  }

  List<Track> _resolveTracksFromPlaylists(List<Playlist> playlists) {
    final trackSource = _catalogTracks.isNotEmpty ? _catalogTracks : _tracks;
    final trackMap = {for (final t in trackSource) t.id: t};
    final tracks = <Track>[];
    for (final playlist in playlists) {
      for (final trackId in playlist.trackIds) {
        final track = trackMap[trackId];
        if (track != null) {
          tracks.add(track);
        }
      }
    }
    return tracks;
  }

  Future<void> _handleBatchDeletePlaylists(List<Playlist> playlists) async {
    final idsToRemove = playlists.map((p) => p.id).toSet();
    await Future.wait(
      idsToRemove.map((id) => widget.musicService.deletePlaylist(id)),
    );
    if (!mounted) return;
    setState(() {
      _playlists = _playlists
          .where((p) => !idsToRemove.contains(p.id))
          .toList();
      _sidebarPlaylists = _sidebarPlaylists
          .where((p) => !idsToRemove.contains(p.id))
          .toList();
      if (_selectedPlaylistId != null &&
          idsToRemove.contains(_selectedPlaylistId)) {
        _selectedPlaylistId = null;
      }
    });
  }

  Future<void> _handleRemoveTrackFromPlaylist(
    String playlistId,
    int index,
    Track track,
  ) async {
    try {
      final plIndex = _playlists.indexWhere((p) => p.id == playlistId);
      final pl = plIndex != -1
          ? _playlists[plIndex]
          : _sidebarPlaylists.firstWhere(
              (p) => p.id == playlistId,
              orElse: () => const Playlist(id: '', title: ''),
            );
      if (pl.id.isEmpty) return;

      int? targetIndex;
      final trackSource = _catalogTracks.isNotEmpty ? _catalogTracks : _tracks;
      final trackMap = {for (final t in trackSource) t.id: t};

      // Map visible index in playlistTracks to position in playlist.trackIds
      final visibleIndices = <int>[];
      for (var i = 0; i < pl.trackIds.length; i++) {
        if (trackMap.containsKey(pl.trackIds[i])) {
          visibleIndices.add(i);
        }
      }

      if (index >= 0 && index < visibleIndices.length) {
        targetIndex = visibleIndices[index];
      }

      await widget.musicService.removeTrackFromPlaylist(
        playlistId,
        track.id,
        atIndex: targetIndex,
      );

      if (!mounted) return;

      setState(() {
        Playlist updatePl(Playlist pl) {
          if (pl.id != playlistId) return pl;
          final updatedTrackIds = List<String>.from(pl.trackIds);
          if (targetIndex != null &&
              targetIndex >= 0 &&
              targetIndex < updatedTrackIds.length) {
            updatedTrackIds.removeAt(targetIndex);
          } else {
            updatedTrackIds.remove(track.id);
          }
          return pl.copyWith(
            trackIds: updatedTrackIds,
            updatedAt: DateTime.now(),
          );
        }

        _playlists = _playlists.map(updatePl).toList();
        _sidebarPlaylists = _sidebarPlaylists.map(updatePl).toList();
      });
    } catch (_) {
      // Async error safety
    }
  }

  Future<void> _handleReorderPlaylistTracks(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      final plIndex = _playlists.indexWhere((p) => p.id == playlistId);
      final pl = plIndex != -1
          ? _playlists[plIndex]
          : _sidebarPlaylists.firstWhere(
              (p) => p.id == playlistId,
              orElse: () => const Playlist(id: '', title: ''),
            );
      if (pl.id.isEmpty) return;

      final trackSource = _catalogTracks.isNotEmpty ? _catalogTracks : _tracks;
      final trackMap = {for (final t in trackSource) t.id: t};

      final visibleToActual = <int>[];
      for (var i = 0; i < pl.trackIds.length; i++) {
        if (trackMap.containsKey(pl.trackIds[i])) {
          visibleToActual.add(i);
        }
      }

      int actualOld = oldIndex;
      int actualNew = newIndex;

      if (visibleToActual.length == pl.trackIds.length) {
        actualOld = oldIndex;
        actualNew = newIndex;
      } else if (visibleToActual.isNotEmpty &&
          oldIndex >= 0 &&
          oldIndex < visibleToActual.length) {
        actualOld = visibleToActual[oldIndex];
        if (newIndex <= 0) {
          actualNew = 0;
        } else if (newIndex >= visibleToActual.length) {
          actualNew = pl.trackIds.length;
        } else if (oldIndex < newIndex) {
          actualNew = visibleToActual[newIndex - 1] + 1;
        } else {
          actualNew = visibleToActual[newIndex];
        }
      }

      await widget.musicService.reorderPlaylistTracks(
        playlistId,
        actualOld,
        actualNew,
      );

      if (!mounted) return;

      setState(() {
        Playlist updatePl(Playlist pl) {
          if (pl.id != playlistId) return pl;
          final updatedTrackIds = List<String>.from(pl.trackIds);
          if (actualOld >= 0 && actualOld < updatedTrackIds.length) {
            var targetIndex = actualNew;
            if (actualOld < targetIndex) {
              targetIndex -= 1;
            }
            if (targetIndex >= 0 &&
                targetIndex < updatedTrackIds.length &&
                actualOld != targetIndex) {
              final id = updatedTrackIds.removeAt(actualOld);
              updatedTrackIds.insert(targetIndex, id);
              return pl.copyWith(
                trackIds: updatedTrackIds,
                updatedAt: DateTime.now(),
              );
            }
          }
          return pl;
        }

        _playlists = _playlists.map(updatePl).toList();
        _sidebarPlaylists = _sidebarPlaylists.map(updatePl).toList();
      });
    } catch (_) {
      // Async error safety
    }
  }

  void _openInspectorForTrack(Track track) {
    setState(() {
      _hasOpenedInspectorOnce = true;
      _inspectedTrack = track;
      _inspectedAsset = null;
      _isInspectorOpen = true;
      _isInspectorVisible = true;
    });
  }

  void _openInspectorForAudio(Track track) {
    setState(() {
      _hasOpenedInspectorOnce = true;
      _inspectedTrack = track;
      _inspectedAsset = null;
      _isInspectorOpen = true;
      _isInspectorVisible = true;
    });
  }

  void _openInspectorForAsset(Asset asset) {
    setState(() {
      _hasOpenedInspectorOnce = true;
      _inspectedAsset = asset;
      _inspectedTrack = null;
      _isInspectorOpen = true;
      _isInspectorVisible = true;
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
      if (_isInspectorOpen) {
        _hasOpenedInspectorOnce = true;
        _isInspectorVisible = true;
        if (_inspectedTrack == null &&
            _inspectedAsset == null &&
            _currentTrack != null) {
          _inspectedTrack = _currentTrack;
        }
      }
    });
  }

  void _onInspectorAnimationEnd() {
    if (!_isInspectorOpen && _isInspectorVisible) {
      setState(() {
        _isInspectorVisible = false;
      });
    }
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
      return const Center(child: LyraSpinner(size: 24.0));
    }

    final filterContext = _buildTrackFilterContext();
    final filterQuerySummary = _trackFilterQuery.formatSummaryLabel(
      filterContext,
    );

    switch (_currentTab) {
      case AppTab.tracks:
        final effectiveTracks = _applyTracksFiltering(_tracks, filterContext);
        final effectiveFilterLabel =
            _activeTrackFilter?.label ??
            filterQuerySummary ??
            (_searchController.text.isNotEmpty
                ? 'Search: "${_searchController.text}"'
                : null);
        return RepaintBoundary(
          child: TracksView(
            preferencesService: widget.preferencesService,
            trackActivationMode: _trackActivationMode,
            tracks: effectiveTracks,
            currentTrack: _currentTrack,
            isPlaying: _isPlaying,
            filterLabel: effectiveFilterLabel,
            filterQuery: _trackFilterQuery,
            isFilterBuilderExpanded: _isTracksFilterBuilderExpanded,
            onFilterBuilderExpandedChanged: (expanded) {
              setState(() {
                _isTracksFilterBuilderExpanded = expanded;
              });
            },
            filterContext: filterContext,
            onFilterQueryChanged: (nextQuery) {
              setState(() {
                _trackFilterQuery = nextQuery;
                _activeTrackFilter = null;
                final syncedTags = nextQuery.referencedTagIds;
                _selectedTagIds = syncedTags;
                _selectedTagId = syncedTags.isEmpty ? null : syncedTags.last;
              });
            },
            audioVersionCounts: _audioVersionCounts,
            visibleColumns: _trackVisibleColumns,
            columnOrder: _trackColumnOrder,
            columnWidths: _trackColumnWidths,
            viewMode: _trackViewMode,
            showHeader: _showTrackHeader,
            onVisibleColumnsChanged: (columns) {
              setState(() {
                _trackVisibleColumns = columns;
              });
              widget.preferencesService?.setTrackVisibleColumns(
                columns.map((c) => c.name).toSet(),
              );
            },
            onColumnOrderChanged: (order) {
              setState(() {
                _trackColumnOrder = order;
              });
              widget.preferencesService?.setTrackColumnOrder(
                order.map((c) => c.name).toList(),
              );
            },
            onColumnWidthsChanged: (widths) {
              setState(() {
                _trackColumnWidths = Map<String, double>.from(widths);
              });
            },
            onClearFilter: () => setState(() {
              _activeTrackFilter = null;
              _trackFilterQuery = const TrackFilterQuery();
              _selectedTagId = null;
              _selectedTagIds = {};
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                _loadCatalog();
              }
            }),
            onTrackSelected: _onTrackSelected,
            onTogglePlay: _togglePlay,
            onPlayNext: (track) => _playbackController.playNext(track),
            onAddToQueue: (track) => _playbackController.addToQueue(track),
            onAddToPlaylist: _showAddToPlaylistDialog,
            onBatchAddToPlaylist: _showBatchAddToPlaylistDialog,
            onBatchAddTag: _showBatchTagDialog,
            onBatchAddToQueue: (tracks) =>
                _playbackController.addAllToQueue(tracks),
            onBatchPlayNext: (tracks) =>
                _playbackController.playAllNext(tracks),
            onInspectTrack: _openInspectorForTrack,
            onInspectAudio: _openInspectorForAudio,
            onTrackFocus: _handleInspectorTrackFocus,
            onGoToAlbum: _navigateToAlbum,
            onGoToArtist: _navigateToArtist,
            onImport: _showImportDialog,
            isNowPlayingExpanded: _isNowPlayingExpanded,
          ),
        );
      case AppTab.works:
        return RepaintBoundary(
          child: WorksView(
            works: _works,
            visibleColumns: _workVisibleColumns,
            columnOrder: _workColumnOrder,
            onVisibleColumnsChanged: (columns) {
              setState(() {
                _workVisibleColumns = columns;
              });
              widget.preferencesService?.setWorkVisibleColumns(
                columns.map((c) => c.name).toSet(),
              );
            },
            onColumnOrderChanged: (order) {
              setState(() {
                _workColumnOrder = order;
              });
              widget.preferencesService?.setWorkColumnOrder(
                order.map((c) => c.name).toList(),
              );
            },
            onWorkSelected: (work) {
              setState(() {
                _clearDetailSelections();
                _selectedTagId = null;
                _selectedTagIds = {};
                _trackFilterQuery = const TrackFilterQuery();
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
        if (_selectedAlbumId != null) {
          final album = _resolveAlbumById(_selectedAlbumId!);
          if (album != null) {
            final albumTracks = _tracksForAlbum(album, _trackCatalogSource);
            final returnArtist =
                _albumReturnArtist ??
                (_albumReturnArtistId != null
                    ? _resolveArtistById(_albumReturnArtistId!)
                    : null);
            return RepaintBoundary(
              child: AlbumDetailView(
                preferencesService: widget.preferencesService,
                trackActivationMode: _trackActivationMode,
                album: album,
                tracks: albumTracks,
                backLabel: returnArtist != null
                    ? returnArtist.displayName
                    : 'Albums',
                onBack: () {
                  setState(() {
                    if (returnArtist != null) {
                      _selectedArtistId = returnArtist.id;
                      _transientArtist =
                          _artistCatalogSource.any(
                            (a) => a.id == returnArtist.id,
                          )
                          ? null
                          : returnArtist;
                      _selectedAlbumId = null;
                      _transientAlbum = null;
                      _albumReturnArtistId = null;
                      _albumReturnArtist = null;
                      _currentTab = AppTab.artists;
                    } else {
                      _selectedAlbumId = null;
                      _transientAlbum = null;
                      _albumReturnArtistId = null;
                      _albumReturnArtist = null;
                    }
                  });
                },
                onArtistTap: album.artist.trim().isNotEmpty
                    ? () => _navigateToArtist(album.artist)
                    : null,
                playbackController: _playbackController,
                currentTrack: _currentTrack,
                isPlaying: _isPlaying,
                visibleColumns: _playlistVisibleColumns,
                onVisibleColumnsChanged: _onCollectionVisibleColumnsChanged,
                columnOrder: _playlistColumnOrder,
                onColumnOrderChanged: _onCollectionColumnOrderChanged,
                viewMode: _playlistViewMode,
                showHeader: _showPlaylistHeader,
                onGoToAlbum: _navigateToAlbum,
                onGoToArtist: _navigateToArtist,
                onPlayAll: () => _playCollectionAll(albumTracks),
                onShuffleAll: () => _shuffleCollectionAll(albumTracks),
                onTrackSelected: (track) =>
                    _playCollectionTrack(track, albumTracks),
                onPlayNext: (track) => _playbackController.playNext(track),
                onAddToQueue: (track) => _playbackController.addToQueue(track),
                onInspectAudio: _openInspectorForAudio,
                onTrackFocus: _handleInspectorTrackFocus,
                onTogglePlay: _togglePlay,
                isNowPlayingExpanded: _isNowPlayingExpanded,
              ),
            );
          }
        }
        return RepaintBoundary(
          child: AlbumsView(
            albums: _albums,
            onAlbumSelected: (album) => _openAlbumDetail(album),
            onBatchPlayNext: (albums) {
              final trackSource = _trackCatalogSource;
              final albumTitles = albums.map((a) => a.title).toSet();
              final tracks = trackSource
                  .where((t) => albumTitles.contains(t.album))
                  .toList();
              if (tracks.isNotEmpty) {
                _playbackController.playAllNext(tracks);
              }
            },
            onBatchAddToQueue: (albums) {
              final trackSource = _trackCatalogSource;
              final albumTitles = albums.map((a) => a.title).toSet();
              final tracks = trackSource
                  .where((t) => albumTitles.contains(t.album))
                  .toList();
              if (tracks.isNotEmpty) {
                _playbackController.addAllToQueue(tracks);
              }
            },
            onBatchAddToPlaylist: (albums) {
              final trackSource = _trackCatalogSource;
              final albumTitles = albums.map((a) => a.title).toSet();
              final tracks = trackSource
                  .where((t) => albumTitles.contains(t.album))
                  .toList();
              if (tracks.isNotEmpty) {
                _showBatchAddToPlaylistDialog(tracks);
              }
            },
            onBatchAddTag: (albums) {
              final trackSource = _trackCatalogSource;
              final albumTitles = albums.map((a) => a.title).toSet();
              final tracks = trackSource
                  .where((t) => albumTitles.contains(t.album))
                  .toList();
              if (tracks.isNotEmpty) {
                _showBatchTagDialog(tracks);
              }
            },
          ),
        );
      case AppTab.artists:
        if (_selectedArtistId != null) {
          final artist = _resolveArtistById(_selectedArtistId!);
          if (artist != null) {
            final artistTracks = _tracksForArtist(artist, _trackCatalogSource);
            final artistAlbums = _albumsForArtist(artist, artistTracks);
            return RepaintBoundary(
              child: ArtistDetailView(
                preferencesService: widget.preferencesService,
                trackActivationMode: _trackActivationMode,
                artist: artist,
                albums: artistAlbums,
                tracks: artistTracks,
                onBack: () {
                  setState(() {
                    _selectedArtistId = null;
                    _transientArtist = null;
                  });
                },
                onAlbumSelected: (album) =>
                    _openAlbumDetail(album, returnArtistId: artist.id),
                playbackController: _playbackController,
                currentTrack: _currentTrack,
                isPlaying: _isPlaying,
                visibleColumns: _playlistVisibleColumns,
                onVisibleColumnsChanged: _onCollectionVisibleColumnsChanged,
                columnOrder: _playlistColumnOrder,
                onColumnOrderChanged: _onCollectionColumnOrderChanged,
                viewMode: _playlistViewMode,
                showHeader: _showPlaylistHeader,
                onGoToAlbum: _navigateToAlbum,
                onGoToArtist: _navigateToArtist,
                onPlayAll: () => _playCollectionAll(artistTracks),
                onShuffleAll: () => _shuffleCollectionAll(artistTracks),
                onTrackSelected: (track) =>
                    _playCollectionTrack(track, artistTracks),
                onPlayNext: (track) => _playbackController.playNext(track),
                onAddToQueue: (track) => _playbackController.addToQueue(track),
                onInspectAudio: _openInspectorForAudio,
                onTrackFocus: _handleInspectorTrackFocus,
                onTogglePlay: _togglePlay,
                isNowPlayingExpanded: _isNowPlayingExpanded,
              ),
            );
          }
        }
        return RepaintBoundary(
          child: ArtistsView(
            artists: _artists,
            onArtistSelected: (artist) => _openArtistDetail(artist),
            onBatchPlayNext: (artists) {
              final trackSource = _trackCatalogSource;
              final artistNames = artists.map((a) => a.name).toSet();
              final tracks = trackSource
                  .where((t) => artistNames.contains(t.artist))
                  .toList();
              if (tracks.isNotEmpty) {
                _playbackController.playAllNext(tracks);
              }
            },
            onBatchAddToQueue: (artists) {
              final trackSource = _trackCatalogSource;
              final artistNames = artists.map((a) => a.name).toSet();
              final tracks = trackSource
                  .where((t) => artistNames.contains(t.artist))
                  .toList();
              if (tracks.isNotEmpty) {
                _playbackController.addAllToQueue(tracks);
              }
            },
            onBatchAddToPlaylist: (artists) {
              final trackSource = _trackCatalogSource;
              final artistNames = artists.map((a) => a.name).toSet();
              final tracks = trackSource
                  .where((t) => artistNames.contains(t.artist))
                  .toList();
              if (tracks.isNotEmpty) {
                _showBatchAddToPlaylistDialog(tracks);
              }
            },
            onBatchAddTag: (artists) {
              final trackSource = _trackCatalogSource;
              final artistNames = artists.map((a) => a.name).toSet();
              final tracks = trackSource
                  .where((t) => artistNames.contains(t.artist))
                  .toList();
              if (tracks.isNotEmpty) {
                _showBatchTagDialog(tracks);
              }
            },
          ),
        );
      case AppTab.playlists:
        if (_selectedPlaylistId != null) {
          final playlist = _playlists.firstWhere(
            (p) => p.id == _selectedPlaylistId,
            orElse: () => _sidebarPlaylists.firstWhere(
              (p) => p.id == _selectedPlaylistId,
              orElse: () => const Playlist(id: '', title: ''),
            ),
          );
          if (playlist.id.isNotEmpty) {
            final trackMap = {for (final t in _trackCatalogSource) t.id: t};
            final playlistTracks = [
              for (final trackId in playlist.trackIds)
                if (trackMap.containsKey(trackId)) trackMap[trackId]!,
            ];
            return RepaintBoundary(
              child: PlaylistDetailView(
                preferencesService: widget.preferencesService,
                trackActivationMode: _trackActivationMode,
                playlist: playlist,
                tracks: playlistTracks,
                playbackController: _playbackController,
                currentTrack: _currentTrack,
                isPlaying: _isPlaying,
                visibleColumns: _playlistVisibleColumns,
                columnOrder: _playlistColumnOrder,
                viewMode: _playlistViewMode,
                showHeader: _showPlaylistHeader,
                onGoToAlbum: _navigateToAlbum,
                onGoToArtist: _navigateToArtist,
                onVisibleColumnsChanged: _onCollectionVisibleColumnsChanged,
                onColumnOrderChanged: _onCollectionColumnOrderChanged,
                onBack: () => setState(() => _selectedPlaylistId = null),
                onPlayAll: () => _playCollectionAll(playlistTracks),
                onShuffleAll: () => _shuffleCollectionAll(playlistTracks),
                onTrackSelected: (track) =>
                    _playCollectionTrack(track, playlistTracks),
                onPlayNext: (track) => _playbackController.playNext(track),
                onAddToQueue: (track) => _playbackController.addToQueue(track),
                onRemoveTrack: (index, track) =>
                    _handleRemoveTrackFromPlaylist(playlist.id, index, track),
                onReorderTracks: (oldIndex, newIndex) =>
                    _handleReorderPlaylistTracks(
                      playlist.id,
                      oldIndex,
                      newIndex,
                    ),
                onInspectAudio: _openInspectorForAudio,
                onTrackFocus: _handleInspectorTrackFocus,
                onTogglePlay: _togglePlay,
                isNowPlayingExpanded: _isNowPlayingExpanded,
              ),
            );
          }
        }
        return RepaintBoundary(
          child: PlaylistsView(
            playlists: _playlists,
            onNewPlaylist: _handleNewPlaylist,
            onPlaylistSelected: (playlist) {
              setState(() {
                _selectedPlaylistId = playlist.id;
              });
            },
            onBatchPlayNext: (playlists) {
              final tracks = _resolveTracksFromPlaylists(playlists);
              if (tracks.isNotEmpty) {
                _playbackController.playAllNext(tracks);
              }
            },
            onBatchAddToQueue: (playlists) {
              final tracks = _resolveTracksFromPlaylists(playlists);
              if (tracks.isNotEmpty) {
                _playbackController.addAllToQueue(tracks);
              }
            },
            onBatchDelete: _handleBatchDeletePlaylists,
            onBatchAddTag: (playlists) {
              final tracks = _resolveTracksFromPlaylists(playlists);
              if (tracks.isNotEmpty) {
                _showBatchTagDialog(tracks);
              }
            },
          ),
        );
      case AppTab.tags:
        if (_selectedTagDetailId != null) {
          final tag = _resolveTagById(_selectedTagDetailId!);
          if (tag != null) {
            final tagTracks = _tracksForTag(tag, _trackCatalogSource);
            return RepaintBoundary(
              child: TagDetailView(
                preferencesService: widget.preferencesService,
                trackActivationMode: _trackActivationMode,
                tag: tag,
                tracks: tagTracks,
                onBack: () => setState(() => _selectedTagDetailId = null),
                onFilterInTracks: () => _filterInTracksForSingleTag(tag),
                playbackController: _playbackController,
                currentTrack: _currentTrack,
                isPlaying: _isPlaying,
                visibleColumns: _playlistVisibleColumns,
                onVisibleColumnsChanged: _onCollectionVisibleColumnsChanged,
                columnOrder: _playlistColumnOrder,
                onColumnOrderChanged: _onCollectionColumnOrderChanged,
                viewMode: _playlistViewMode,
                showHeader: _showPlaylistHeader,
                onGoToAlbum: _navigateToAlbum,
                onGoToArtist: _navigateToArtist,
                onPlayAll: () => _playCollectionAll(tagTracks),
                onShuffleAll: () => _shuffleCollectionAll(tagTracks),
                onTrackSelected: (track) =>
                    _playCollectionTrack(track, tagTracks),
                onPlayNext: (track) => _playbackController.playNext(track),
                onAddToQueue: (track) => _playbackController.addToQueue(track),
                onInspectAudio: _openInspectorForAudio,
                onTrackFocus: _handleInspectorTrackFocus,
                onTogglePlay: _togglePlay,
                isNowPlayingExpanded: _isNowPlayingExpanded,
              ),
            );
          }
        }
        return RepaintBoundary(
          child: TagsView(
            tags: _tags,
            tagTrackCounts: _tagTrackCounts,
            onTagSelected: _openTagDetail,
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
              if (mounted) {
                setState(() {
                  _taggedTrackIdsByTag.remove(tag.id);
                  final wasSelectedTag = _selectedTagIds.remove(tag.id);
                  if (_selectedTagId == tag.id) {
                    _selectedTagId = _selectedTagIds.isEmpty
                        ? null
                        : _selectedTagIds.last;
                  }
                  if (_selectedTagDetailId == tag.id) {
                    _selectedTagDetailId = null;
                  }
                  _trackFilterQuery = _trackFilterQuery.withoutTagId(tag.id);
                  if (wasSelectedTag && _activeTrackFilter != null) {
                    _rebuildTagTrackFilterFromSelection();
                  }
                });
              }
              await _loadCatalog();
            },
          ),
        );
      case AppTab.casStorage:
        return RepaintBoundary(
          child: CasView(
            casObjects: _casObjects,
            activeTab: _selectedCasTab,
            controller: _casController,
            dbController: _dbController,
            backendSettingsController: _backendSettingsController,
            onTabChanged: (tab) {
              setState(() {
                _selectedCasTab = tab;
              });
              _casController.setTab(tab);
            },
            onInspectAsset: (obj) => _openInspectorForAsset(obj),
            onVerifyAll: () async {},
          ),
        );
      case AppTab.settings:
        return RepaintBoundary(
          child: SettingsView(preferencesService: widget.preferencesService),
        );
    }
  }

  Widget _buildHeader() {
    return RepaintBoundary(
      child: LyraHeaderBar(
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        onSearchChanged: _onSearchChanged,
        onSearchSubmitted: _onSearchSubmitted,
        onImportPressed: _showImportDialog,
        onToggleSidebar: _toggleSidebar,
        isSidebarCollapsed: _isSidebarCollapsed,
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
                    : _showAddToPlaylistDialog,
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

    return Focus(
      autofocus: true,
      child: LyraToastScope(
        controller: _toastController,
        child: ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: tokens.background,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    // Top Header Bar (Independent Top Layer across entire width)
                    _buildHeader(),

                    // Lower Content Area (Sidebar on Left, Main Content + Player Bar on Right)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 900;
                          final effectiveSidebarCollapsed =
                              _isSidebarCollapsed || isCompact;

                          return Row(
                            children: [
                              // Sidebar (Left)
                              ValueListenableBuilder<double>(
                                valueListenable: _sidebarWidthNotifier,
                                builder: (context, sidebarWidth, _) {
                                  return RepaintBoundary(
                                    child: LyraSidebar(
                                      expandedWidth: sidebarWidth,
                                      showRightBorder: true,
                                      currentTab: _currentTab,
                                      isCollapsed: effectiveSidebarCollapsed,
                                      playlists: _sidebarPlaylists,
                                      selectedPlaylistId: _selectedPlaylistId,
                                      onPlaylistSelected: (pl) {
                                        _isNowPlayingExpanded = false;
                                        setState(() {
                                          _clearDetailSelections();
                                          _selectedPlaylistId = pl.id;
                                          _clearTransientNavigationFilter();
                                          _currentTab = AppTab.playlists;
                                        });
                                      },
                                      onPlaylistsHeaderSelected: () {
                                        _isNowPlayingExpanded = false;
                                        setState(() {
                                          _clearDetailSelections();
                                          _clearTransientNavigationFilter();
                                          _currentTab = AppTab.playlists;
                                        });
                                      },
                                      tags: _tags,
                                      selectedTagId:
                                          _currentTab == AppTab.tracks
                                          ? _selectedTagId
                                          : null,
                                      selectedTagIds:
                                          _currentTab == AppTab.tracks
                                          ? _selectedTagIds
                                          : const <String>{},
                                      onTagSelected: (tag) {
                                        _isNowPlayingExpanded = false;
                                        _filterByTag(tag);
                                      },
                                      onTagsHeaderSelected: () {
                                        _isNowPlayingExpanded = false;
                                        setState(() {
                                          _clearDetailSelections();
                                          _clearTransientNavigationFilter();
                                          _currentTab = AppTab.tags;
                                        });
                                      },
                                      selectedCasTab: _selectedCasTab,
                                      onCasSubTabSelected: (subTab) {
                                        _isNowPlayingExpanded = false;
                                        setState(() {
                                          _clearDetailSelections();
                                          _clearTransientNavigationFilter();
                                          _selectedCasTab = subTab;
                                          _currentTab = AppTab.casStorage;
                                        });
                                      },
                                      onCasHeaderSelected: () {
                                        _isNowPlayingExpanded = false;
                                        setState(() {
                                          _clearDetailSelections();
                                          _clearTransientNavigationFilter();
                                          _currentTab = AppTab.casStorage;
                                        });
                                      },
                                      onTabSelected: (tab) {
                                        _isNowPlayingExpanded = false;
                                        setState(() {
                                          _clearTransientNavigationFilter();
                                          _clearDetailSelections(
                                            preservePlaylist:
                                                tab == AppTab.playlists,
                                          );
                                          _currentTab = tab;
                                        });
                                      },
                                      onSettingsPressed: _navigateToSettings,
                                      onToggleCollapse: _toggleSidebar,
                                      onResizeDelta: (delta) {
                                        _sidebarWidthNotifier.value =
                                            (_sidebarWidthNotifier.value +
                                                    delta)
                                                .clamp(160.0, 420.0);
                                      },
                                      onResizeEnd: () {
                                        widget.preferencesService
                                            ?.setSidebarWidth(
                                              _sidebarWidthNotifier.value,
                                            );
                                      },
                                      onResetWidth: () {
                                        _sidebarWidthNotifier.value = 210.0;
                                        widget.preferencesService
                                            ?.setSidebarWidth(210.0);
                                      },
                                    ),
                                  );
                                },
                              ),

                              // Right Pane (Main Area + Player Bar)
                              Expanded(
                                child: Column(
                                  children: [
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
                                              ValueListenableBuilder<double>(
                                                key: const ValueKey(
                                                  'inspector_width_builder',
                                                ),
                                                valueListenable:
                                                    _inspectorWidthNotifier,
                                                builder: (context, inspectorWidth, _) {
                                                  final maxInspectorWidth = math
                                                      .max(
                                                        320.0,
                                                        MediaQuery.sizeOf(
                                                              context,
                                                            ).width *
                                                            0.5,
                                                      );
                                                  final effectiveTargetWidth =
                                                      _isInspectorOpen
                                                      ? inspectorWidth
                                                      : 0.0;
                                                  final isVisible =
                                                      _isInspectorOpen ||
                                                      _isInspectorVisible;

                                                  return RepaintBoundary(
                                                    child: AnimatedContainer(
                                                      key: const ValueKey(
                                                        'inspector_animated_container',
                                                      ),
                                                      duration:
                                                          _isInspectorResizing
                                                          ? Duration.zero
                                                          : LyraAnimation
                                                                .normal,
                                                      curve:
                                                          Curves.easeInOutCubic,
                                                      width:
                                                          effectiveTargetWidth,
                                                      decoration: isVisible
                                                          ? BoxDecoration(
                                                              border: Border(
                                                                left: BorderSide(
                                                                  color: tokens
                                                                      .border,
                                                                  width: 1.0,
                                                                ),
                                                              ),
                                                            )
                                                          : null,
                                                      onEnd:
                                                          _onInspectorAnimationEnd,
                                                      child: ClipRect(
                                                        child: OverflowBox(
                                                          key: const ValueKey(
                                                            'inspector_overflow_box',
                                                          ),
                                                          alignment: Alignment
                                                              .topRight,
                                                          minWidth:
                                                              inspectorWidth,
                                                          maxWidth:
                                                              inspectorWidth,
                                                          child: IgnorePointer(
                                                            key: const ValueKey(
                                                              'inspector_ignore_pointer',
                                                            ),
                                                            ignoring:
                                                                !_isInspectorOpen,
                                                            child: ExcludeFocus(
                                                              key: const ValueKey(
                                                                'inspector_exclude_focus',
                                                              ),
                                                              excluding:
                                                                  !_isInspectorOpen,
                                                              child: Visibility(
                                                                key: const ValueKey(
                                                                  'inspector_visibility',
                                                                ),
                                                                visible:
                                                                    isVisible,
                                                                maintainState:
                                                                    true,
                                                                child:
                                                                    _hasOpenedInspectorOnce
                                                                    ? RepaintBoundary(
                                                                        child: AudioInspectorDrawer(
                                                                          width:
                                                                              inspectorWidth,
                                                                          showLeftBorder:
                                                                              false,
                                                                          playbackController:
                                                                              _playbackController,
                                                                          track:
                                                                              _inspectedTrack ??
                                                                              (_inspectedAsset !=
                                                                                      null
                                                                                  ? null
                                                                                  : _currentTrack),
                                                                          asset:
                                                                              _inspectedAsset,
                                                                          musicService:
                                                                              widget.musicService,
                                                                          preferencesService:
                                                                              widget.preferencesService,
                                                                          onClose:
                                                                              _closeInspector,
                                                                          onActiveAudioChanged:
                                                                              (
                                                                                newPcmHash,
                                                                              ) {
                                                                                if (_inspectedTrack !=
                                                                                    null) {
                                                                                  setState(
                                                                                    () {
                                                                                      _inspectedTrack = _inspectedTrack!.copyWith(
                                                                                        pcmHash: newPcmHash,
                                                                                      );
                                                                                    },
                                                                                  );
                                                                                }
                                                                                _loadCatalog();
                                                                              },
                                                                          onTrackUpdated:
                                                                              _handleTrackUpdated,
                                                                          onResizeStart: () {
                                                                            setState(() {
                                                                              _isInspectorResizing = true;
                                                                            });
                                                                          },
                                                                          onResizeDelta:
                                                                              (
                                                                                delta,
                                                                              ) {
                                                                                _inspectorWidthNotifier.value =
                                                                                    (_inspectorWidthNotifier.value -
                                                                                            delta)
                                                                                        .clamp(
                                                                                          300.0,
                                                                                          maxInspectorWidth,
                                                                                        );
                                                                              },
                                                                          onResizeEnd: () {
                                                                            setState(() {
                                                                              _isInspectorResizing = false;
                                                                            });
                                                                            widget.preferencesService?.setInspectorWidth(
                                                                              _inspectorWidthNotifier.value,
                                                                            );
                                                                          },
                                                                          onResetWidth: () {
                                                                            _inspectorWidthNotifier.value =
                                                                                420.0;
                                                                            widget.preferencesService?.setInspectorWidth(
                                                                              420.0,
                                                                            );
                                                                          },
                                                                        ),
                                                                      )
                                                                    : const SizedBox.shrink(),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),

                                          // Now Playing View Overlay (Pre-warmed offscreen and animated via AnimatedSlide)
                                          Positioned.fill(
                                            child: ValueListenableBuilder<bool>(
                                              key: const ValueKey(
                                                'now_playing_expanded_builder',
                                              ),
                                              valueListenable:
                                                  _isNowPlayingExpandedNotifier,
                                              builder: (context, isNowPlayingExpanded, _) {
                                                final bool isVisible =
                                                    _isNowPlayingVisible ||
                                                    isNowPlayingExpanded;

                                                return RepaintBoundary(
                                                  child: AnimatedSlide(
                                                    key: const ValueKey(
                                                      'now_playing_animated_slide',
                                                    ),
                                                    offset: isNowPlayingExpanded
                                                        ? Offset.zero
                                                        : const Offset(
                                                            0.0,
                                                            1.0,
                                                          ),
                                                    duration: widget
                                                        .nowPlayingDuration,
                                                    curve:
                                                        widget.nowPlayingCurve,
                                                    onEnd:
                                                        _onNowPlayingSlideEnd,
                                                    child: IgnorePointer(
                                                      key: const ValueKey(
                                                        'now_playing_ignore_pointer',
                                                      ),
                                                      ignoring:
                                                          !isNowPlayingExpanded,
                                                      child: Visibility(
                                                        key: const ValueKey(
                                                          'now_playing_visibility',
                                                        ),
                                                        visible: isVisible,
                                                        maintainState: true,
                                                        child: RepaintBoundary(
                                                          child: NowPlayingView(
                                                            track:
                                                                _currentTrack,
                                                            playbackController:
                                                                _playbackController,
                                                            onCollapse:
                                                                _collapseNowPlaying,
                                                            isExpanded:
                                                                isNowPlayingExpanded,
                                                            musicService: widget
                                                                .musicService,
                                                            preferencesService:
                                                                widget
                                                                    .preferencesService,
                                                            selectedTabNotifier:
                                                                _nowPlayingTabNotifier,
                                                            onAddToPlaylist:
                                                                _showAddToPlaylistDialog,
                                                            onInspectAudio:
                                                                _openInspectorForAudio,
                                                            onGoToAlbum:
                                                                _navigateToAlbum,
                                                            onGoToArtist:
                                                                _navigateToArtist,
                                                            queueSource:
                                                                _activeTrackFilter
                                                                    ?.label ??
                                                                _trackFilterQuery
                                                                    .formatSummaryLabel(
                                                                      _buildTrackFilterContext(),
                                                                    ) ??
                                                                switch (_currentTab) {
                                                                  AppTab
                                                                      .playlists =>
                                                                    'Playing from Playlist',
                                                                  AppTab
                                                                      .albums =>
                                                                    _selectedAlbumId !=
                                                                            null
                                                                        ? 'Playing from Album'
                                                                        : 'Playing from Library',
                                                                  AppTab
                                                                      .artists =>
                                                                    _selectedArtistId !=
                                                                            null
                                                                        ? 'Playing from Artist'
                                                                        : 'Playing from Library',
                                                                  AppTab.tags =>
                                                                    _selectedTagDetailId !=
                                                                            null
                                                                        ? 'Playing from Tag'
                                                                        : 'Playing from Library',
                                                                  _ =>
                                                                    'Playing from Library',
                                                                },
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left:
                      (_notificationPosition ==
                              NotificationPosition.bottomLeft ||
                          _notificationPosition == NotificationPosition.topLeft)
                      ? 20.0
                      : null,
                  right:
                      (_notificationPosition ==
                              NotificationPosition.bottomRight ||
                          _notificationPosition ==
                              NotificationPosition.topRight)
                      ? 20.0
                      : null,
                  bottom:
                      (_notificationPosition ==
                              NotificationPosition.bottomLeft ||
                          _notificationPosition ==
                              NotificationPosition.bottomRight)
                      ? 24.0
                      : null,
                  top:
                      (_notificationPosition == NotificationPosition.topLeft ||
                          _notificationPosition ==
                              NotificationPosition.topRight)
                      ? 72.0
                      : null,
                  child: const LyraToastStack(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal dialog for adding tracks to an existing playlist or creating a new one.
class _AddToPlaylistDialog extends StatefulWidget {
  final List<Track> tracks;
  final List<Playlist> playlists;
  final MusicService musicService;
  final ValueChanged<Playlist> onPlaylistUpdated;

  _AddToPlaylistDialog({
    List<Track>? tracks,
    Track? track,
    required this.playlists,
    required this.musicService,
    required this.onPlaylistUpdated,
  }) : tracks = tracks ?? (track != null ? [track] : const []);

  @override
  State<_AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<_AddToPlaylistDialog> {
  bool _isCreatingPlaylist = false;
  late final TextEditingController _newPlaylistNameController;

  @override
  void initState() {
    super.initState();
    _newPlaylistNameController = TextEditingController();
  }

  @override
  void dispose() {
    _newPlaylistNameController.dispose();
    super.dispose();
  }

  void _popDialog() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleCreatePlaylistWithName(String rawName) async {
    final trimmed = rawName.trim();
    final title = trimmed.isNotEmpty
        ? trimmed
        : 'New Playlist ${widget.playlists.length + 1}';
    final newPl = await widget.musicService.createPlaylist(
      title: title,
      trackIds: widget.tracks.map((t) => t.id).toList(),
    );
    widget.onPlaylistUpdated(newPl);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    final descriptionText = _isCreatingPlaylist
        ? 'Enter a name for the new playlist'
        : (widget.tracks.length == 1
              ? 'Add "${widget.tracks.first.displayTitle}" to a playlist'
              : 'Add ${widget.tracks.length} tracks to a playlist');

    return Center(
      child: LyraDialog(
        title: Text(
          _isCreatingPlaylist ? 'New Playlist' : 'Add to Playlist',
          style: LyraTypography.h4(tokens),
        ),
        description: Text(descriptionText, style: LyraTypography.muted(tokens)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440.0,
            maxHeight: _isCreatingPlaylist ? double.infinity : 650.0,
          ),
          child: _isCreatingPlaylist
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
                          onPressed: () =>
                              setState(() => _isCreatingPlaylist = false),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: LyraSpacing.sm),
                        LyraButton.primary(
                          size: LyraButtonSize.sm,
                          onPressed: () => _handleCreatePlaylistWithName(
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
                    if (widget.playlists.isEmpty)
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
                        padding: const EdgeInsets.only(bottom: 48.0),
                        itemCount: widget.playlists.length,
                        itemBuilder: (itemContext, index) {
                          final playlist = widget.playlists[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: LyraSpacing.xs,
                            ),
                            child: _PlaylistModalItem(
                              playlist: playlist,
                              tokens: tokens,
                              onTap: () async {
                                final trackIdsToAdd = widget.tracks
                                    .map((t) => t.id)
                                    .toList();
                                final existingIds = playlist.trackIds.toSet();
                                final newTrackIds = trackIdsToAdd
                                    .where((tid) => !existingIds.contains(tid))
                                    .toList();
                                final updatedTrackIds = [
                                  ...playlist.trackIds,
                                  ...newTrackIds,
                                ];
                                final updatedPlaylist = playlist.copyWith(
                                  trackIds: updatedTrackIds,
                                );
                                await Future.wait(
                                  newTrackIds.map(
                                    (tid) => widget.musicService
                                        .addTrackToPlaylist(playlist.id, tid),
                                  ),
                                );
                                _popDialog();
                                widget.onPlaylistUpdated(updatedPlaylist);
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
                              color: tokens.primary.withValues(alpha: 0.35),
                              blurRadius: 10.0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: LyraButton.primary(
                          size: LyraButtonSize.sm,
                          leading: const Icon(LucideIcons.plus, size: 15.0),
                          child: const Text('New Playlist'),
                          onPressed: () {
                            setState(() {
                              _isCreatingPlaylist = true;
                              _newPlaylistNameController.text =
                                  'New Playlist ${widget.playlists.length + 1}';
                              _newPlaylistNameController.selection =
                                  TextSelection(
                                    baseOffset: 0,
                                    extentOffset:
                                        _newPlaylistNameController.text.length,
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
    );
  }
}

/// Modal dialog for applying an existing or new tag to a batch of tracks.
class _BatchTagDialog extends StatefulWidget {
  final List<Track> tracks;
  final List<Tag> tags;
  final MusicService musicService;
  final ValueChanged<Tag> onTagApplied;

  const _BatchTagDialog({
    required this.tracks,
    required this.tags,
    required this.musicService,
    required this.onTagApplied,
  });

  @override
  State<_BatchTagDialog> createState() => _BatchTagDialogState();
}

class _BatchTagDialogState extends State<_BatchTagDialog> {
  late final TextEditingController _newTagNameController;

  @override
  void initState() {
    super.initState();
    _newTagNameController = TextEditingController();
  }

  @override
  void dispose() {
    _newTagNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAndApplyTag(String rawName) async {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return;
    final createdTag = await widget.musicService.createTag(
      name: trimmed,
      category: 'general',
    );
    widget.onTagApplied(createdTag);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Center(
      child: LyraDialog(
        title: Text('Add Tags', style: LyraTypography.h4(tokens)),
        description: Text(
          'Apply a tag to ${widget.tracks.length} selected tracks',
          style: LyraTypography.muted(tokens),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440.0, maxHeight: 520.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: LyraSpacing.sm),
              // New tag input
              Row(
                children: [
                  Expanded(
                    child: LyraInput(
                      controller: _newTagNameController,
                      placeholder: 'Create new tag name...',
                      onSubmitted: (name) => _handleCreateAndApplyTag(name),
                    ),
                  ),
                  const SizedBox(width: LyraSpacing.sm),
                  LyraButton.primary(
                    size: LyraButtonSize.sm,
                    leading: const Icon(LucideIcons.plus, size: 14.0),
                    onPressed: () =>
                        _handleCreateAndApplyTag(_newTagNameController.text),
                    child: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: LyraSpacing.md),
              Text(
                'Existing Tags',
                style: LyraTypography.small(tokens).copyWith(
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: LyraSpacing.xs),
              Flexible(
                child: widget.tags.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: LyraSpacing.lg,
                        ),
                        child: Center(
                          child: Text(
                            'No existing tags. Create one above.',
                            style: LyraTypography.muted(tokens),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.tags.length,
                        itemBuilder: (context, index) {
                          final tag = widget.tags[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: LyraSpacing.xs,
                            ),
                            child: _TagDialogItem(
                              tag: tag,
                              tokens: tokens,
                              onTap: () {
                                widget.onTagApplied(tag);
                                Navigator.of(context).pop();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagDialogItem extends StatefulWidget {
  final Tag tag;
  final LyraThemeTokens tokens;
  final VoidCallback onTap;

  const _TagDialogItem({
    required this.tag,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_TagDialogItem> createState() => _TagDialogItemState();
}

class _TagDialogItemState extends State<_TagDialogItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.md,
            vertical: LyraSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.0),
            color: _isHovered
                ? tokens.secondary.withValues(alpha: 0.6)
                : tokens.secondary.withValues(alpha: 0.2),
            border: Border.all(
              color: _isHovered ? tokens.primary : tokens.border,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.tag, size: 14.0, color: tokens.primary),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  widget.tag.displayName,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(fontWeight: FontWeight.w500, color: tokens.text),
                ),
              ),
              LyraBadge.outline(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                child: Text(
                  widget.tag.displayCategory,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(fontSize: 10.0, color: tokens.textMuted),
                ),
              ),
            ],
          ),
        ),
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
            color: tokens.itemBackground(isHovered: _isHovered),
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
