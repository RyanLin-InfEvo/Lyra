// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart'
    show Colors, Material, SelectionArea, showDialog;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_copy_button.dart';
import '../../design_system/widgets/lyra_dialog.dart';
import '../../design_system/widgets/lyra_input.dart';
import '../models/asset.dart';
import '../models/audio.dart';
import '../models/source_data.dart';
import '../models/track.dart';
import '../services/music_service.dart';

/// Audio entity-centric property inspector drawer displaying deep acoustic specifications,
/// Single-Level Star Topology audio versions, CAS storage properties, and digital provenance.
class AudioInspectorDrawer extends StatelessWidget {
  final Track? track;
  final Asset? asset;
  final Audio? initialAudio;
  final SourceData? initialSourceData;
  final MusicService? musicService;
  final VoidCallback onClose;
  final void Function(String newPcmHash)? onActiveAudioChanged;
  final void Function(Track updatedTrack)? onTrackUpdated;
  final double? width;
  final bool showLeftBorder;
  final ValueChanged<double>? onResizeDelta;
  final VoidCallback? onResizeStart;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onResetWidth;

  const AudioInspectorDrawer({
    super.key,
    this.track,
    this.asset,
    this.initialAudio,
    this.initialSourceData,
    this.musicService,
    required this.onClose,
    this.onActiveAudioChanged,
    this.onTrackUpdated,
    this.width,
    this.showLeftBorder = true,
    this.onResizeDelta,
    this.onResizeStart,
    this.onResizeEnd,
    this.onResetWidth,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth =
        width ??
        (screenWidth < 1200 ? (screenWidth * 0.35).clamp(320.0, 420.0) : 420.0);

    return Container(
      width: drawerWidth,
      decoration: BoxDecoration(
        color: tokens.card,
        border: showLeftBorder
            ? Border(left: BorderSide(color: tokens.border, width: 1.0))
            : null,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _buildDrawerHeader(tokens),
              Expanded(
                child: AudioInspectorContent(
                  track: track,
                  asset: asset,
                  initialAudio: initialAudio,
                  initialSourceData: initialSourceData,
                  musicService: musicService,
                  onActiveAudioChanged: onActiveAudioChanged,
                  onTrackUpdated: onTrackUpdated,
                ),
              ),
            ],
          ),
          if (onResizeDelta != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6.0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  key: const Key('inspector_resize_handle'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) => onResizeStart?.call(),
                  onHorizontalDragUpdate: (details) =>
                      onResizeDelta?.call(details.delta.dx),
                  onHorizontalDragEnd: (_) => onResizeEnd?.call(),
                  onHorizontalDragCancel: () => onResizeEnd?.call(),
                  onDoubleTap: onResetWidth,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(LyraThemeTokens tokens) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(bottom: BorderSide(color: tokens.border, width: 1.0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(LyraSpacing.xs),
            decoration: BoxDecoration(
              color: tokens.secondary,
              borderRadius: LyraRadius.smRadius,
            ),
            child: Icon(
              LucideIcons.fileSearch,
              size: 16.0,
              color: tokens.primary,
            ),
          ),
          const SizedBox(width: LyraSpacing.sm),
          Expanded(
            child: Text(
              'Inspector',
              style: LyraTypography.h4(
                tokens,
              ).copyWith(fontSize: 16.0, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          LyraButton.ghost(
            size: LyraButtonSize.sm,
            onPressed: onClose,
            child: Icon(LucideIcons.x, size: 16.0, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Standalone audio inspector content view displaying acoustic specifications,
/// audio versions, CAS storage properties, and digital provenance without drawer frame.
class AudioInspectorContent extends StatefulWidget {
  final Track? track;
  final Asset? asset;
  final Audio? initialAudio;
  final SourceData? initialSourceData;
  final MusicService? musicService;
  final void Function(String newPcmHash)? onActiveAudioChanged;
  final void Function(Track updatedTrack)? onTrackUpdated;
  final EdgeInsetsGeometry padding;

  const AudioInspectorContent({
    super.key,
    this.track,
    this.asset,
    this.initialAudio,
    this.initialSourceData,
    this.musicService,
    this.onActiveAudioChanged,
    this.onTrackUpdated,
    this.padding = const EdgeInsets.all(LyraSpacing.lg),
  });

  @override
  State<AudioInspectorContent> createState() => _AudioInspectorContentState();
}

class _AudioInspectorContentState extends State<AudioInspectorContent> {
  Track? _track;
  List<Audio> _audioVersions = [];
  Audio? _selectedAudio;
  SourceData? _sourceData;
  Asset? _resolvedAsset;
  bool _isLoading = false;
  bool _isSwitchingActive = false;

  // Metadata Edit Mode State
  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late final TextEditingController _yearController;
  late final TextEditingController _trackNumberController;
  late final TextEditingController _genreController;
  late final TextEditingController _iswcController;
  late final TextEditingController _isrcController;

  late final FocusNode _artistFocusNode;
  late final FocusNode _albumFocusNode;

  List<String> _availableArtists = [];
  List<String> _availableAlbums = [];
  Map<String, String> _validationErrors = {};
  int _fetchDetailsCallId = 0;

  static final _iswcRegex = RegExp(
    r'^T[-.]?(?:\d{9}|\d{3}[-.]\d{3}[-.]\d{3})[-.]?\d$',
    caseSensitive: false,
  );

  static final _isrcRegex = RegExp(
    r'^[A-Z]{2}-?[A-Z0-9]{3}-?\d{2}-?\d{5}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _track = widget.track;
    _selectedAudio = widget.initialAudio;
    _sourceData = widget.initialSourceData;
    _resolvedAsset = widget.asset;

    _titleController = TextEditingController();
    _artistController = TextEditingController();
    _albumController = TextEditingController();
    _yearController = TextEditingController();
    _trackNumberController = TextEditingController();
    _genreController = TextEditingController();
    _iswcController = TextEditingController();
    _isrcController = TextEditingController();

    _artistFocusNode = FocusNode();
    _albumFocusNode = FocusNode();

    _syncControllersFromTrack(_track);
    _fetchDetails();
    _fetchAutocompleteSuggestions();
  }

  void _syncControllersFromTrack(Track? track) {
    _titleController.text = track?.title ?? '';
    _artistController.text = track?.artistName ?? '';
    _albumController.text = track?.albumTitle ?? '';
    _yearController.text = track?.recordingYear?.toString() ?? '';
    _trackNumberController.text = track?.trackNumber?.toString() ?? '';
    _genreController.text = track?.genre ?? '';
    _iswcController.text = track?.iswc ?? '';
    _isrcController.text = track?.isrc ?? '';
  }

  @override
  void didUpdateWidget(covariant AudioInspectorContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trackChanged = oldWidget.track?.id != widget.track?.id;
    final trackDataChanged = oldWidget.track != widget.track;
    final serviceChanged = oldWidget.musicService != widget.musicService;

    if (serviceChanged) {
      _fetchAutocompleteSuggestions();
    }

    if (trackChanged ||
        oldWidget.track?.pcmHash != widget.track?.pcmHash ||
        oldWidget.asset?.fileHash != widget.asset?.fileHash ||
        oldWidget.initialAudio != widget.initialAudio ||
        oldWidget.initialSourceData != widget.initialSourceData) {
      if (trackChanged) {
        if (_artistFocusNode.hasFocus) _artistFocusNode.unfocus();
        if (_albumFocusNode.hasFocus) _albumFocusNode.unfocus();
        _isEditing = false;
        _isSaving = false;
        _validationErrors.clear();
      }
      _track = widget.track;
      _selectedAudio = widget.initialAudio;
      _sourceData = widget.initialSourceData;
      _resolvedAsset = widget.asset;
      if (!_isEditing && !trackChanged) {
        _syncControllersFromTrack(_track);
      }
      _fetchDetails();
    } else if (trackDataChanged && !_isEditing) {
      _track = widget.track;
      _syncControllersFromTrack(_track);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _trackNumberController.dispose();
    _genreController.dispose();
    _iswcController.dispose();
    _isrcController.dispose();

    _artistFocusNode.dispose();
    _albumFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAutocompleteSuggestions() async {
    final service = widget.musicService;
    if (service == null) return;
    try {
      final artists = await service.getArtists();
      final albums = await service.getAlbums();
      if (!mounted) return;
      setState(() {
        _availableArtists =
            artists
                .map((a) => a.displayName)
                .where((s) => s.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        _availableAlbums =
            albums
                .map((a) => a.title)
                .where((s) => s.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();
      });
    } catch (_) {}
  }

  void _startEditing() {
    _syncControllersFromTrack(_track);
    _fetchAutocompleteSuggestions();
    setState(() {
      _validationErrors.clear();
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    if (_artistFocusNode.hasFocus) _artistFocusNode.unfocus();
    if (_albumFocusNode.hasFocus) _albumFocusNode.unfocus();
    setState(() {
      _validationErrors.clear();
      _isEditing = false;
      _isSaving = false;
    });
  }

  void _clearFieldError(String fieldKey) {
    if (_validationErrors.containsKey(fieldKey)) {
      setState(() {
        _validationErrors.remove(fieldKey);
      });
    }
  }

  bool _validateFields() {
    final errors = <String, String>{};

    final iswc = _iswcController.text.trim();
    if (iswc.isNotEmpty && !_iswcRegex.hasMatch(iswc)) {
      errors['iswc'] = 'Invalid ISWC format (e.g. T-123.456.789-0)';
    }

    final isrc = _isrcController.text.trim();
    if (isrc.isNotEmpty && !_isrcRegex.hasMatch(isrc)) {
      errors['isrc'] = 'Invalid ISRC format (e.g. US-SM1-59-00001)';
    }

    final year = _yearController.text.trim();
    if (year.isNotEmpty) {
      final parsed = int.tryParse(year);
      if (parsed == null || parsed < 1000 || parsed > 2100) {
        errors['year'] = 'Year must be between 1000 and 2100';
      }
    }

    final trackNum = _trackNumberController.text.trim();
    if (trackNum.isNotEmpty) {
      final parsed = int.tryParse(trackNum);
      if (parsed == null || parsed < 1) {
        errors['trackNumber'] = 'Track number must be 1 or greater';
      }
    }

    setState(() {
      _validationErrors = errors;
    });

    return errors.isEmpty;
  }

  List<_FieldDiff> _computeFieldDiffs() {
    if (_track == null) return [];

    final List<_FieldDiff> diffs = [
      _FieldDiff(
        label: 'Title',
        oldValue: _track!.title,
        newValue: _titleController.text.trim(),
      ),
      _FieldDiff(
        label: 'Artist',
        oldValue: _track!.artistName,
        newValue: _artistController.text.trim(),
      ),
      _FieldDiff(
        label: 'Album',
        oldValue: _track!.albumTitle,
        newValue: _albumController.text.trim(),
      ),
      _FieldDiff(
        label: 'Year',
        oldValue: _track!.recordingYear?.toString(),
        newValue: _yearController.text.trim(),
      ),
      _FieldDiff(
        label: 'Track No.',
        oldValue: _track!.trackNumber?.toString(),
        newValue: _trackNumberController.text.trim(),
      ),
      _FieldDiff(
        label: 'Genre',
        oldValue: _track!.genre,
        newValue: _genreController.text.trim(),
      ),
      _FieldDiff(
        label: 'ISWC',
        oldValue: _track!.iswc,
        newValue: _iswcController.text.trim(),
      ),
      _FieldDiff(
        label: 'ISRC',
        oldValue: _track!.isrc,
        newValue: _isrcController.text.trim(),
      ),
    ];

    return diffs.where((d) => d.isChanged).toList();
  }

  Future<void> _saveEditing() async {
    if (_track == null) return;

    if (!_validateFields()) {
      return;
    }

    final diffs = _computeFieldDiffs();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      builder: (dialogCtx) => LyraDesignSystemScope(
        factory: LyraDesignSystemScope.of(context).factory,
        tokens: LyraDesignSystemScope.of(context).tokens,
        themeModeNotifier: LyraDesignSystemScope.of(context).themeModeNotifier,
        child: _MetadataDiffDialog(
          diffs: diffs,
          onConfirm: () => Navigator.of(dialogCtx).pop(true),
          onCancel: () => Navigator.of(dialogCtx).pop(false),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final yearText = _yearController.text.trim();
    final trackNumberText = _trackNumberController.text.trim();
    final parsedYear = yearText.isNotEmpty ? int.tryParse(yearText) : null;
    final parsedTrackNumber = trackNumberText.isNotEmpty
        ? int.tryParse(trackNumberText)
        : null;

    final updatedTrack = Track(
      id: _track!.id,
      pcmHash: _track!.pcmHash,
      workId: _track!.workId,
      workTitle: _track!.workTitle,
      title: _titleController.text.trim(),
      recordingYear: parsedYear,
      recordingMonth: _track!.recordingMonth,
      recordingDay: _track!.recordingDay,
      recordingLocation: _track!.recordingLocation,
      durationMs: _track!.durationMs,
      isrc: _isrcController.text.trim().isNotEmpty
          ? _isrcController.text.trim()
          : null,
      iswc: _iswcController.text.trim().isNotEmpty
          ? _iswcController.text.trim()
          : null,
      musicbrainzId: _track!.musicbrainzId,
      spotifyId: _track!.spotifyId,
      ytmId: _track!.ytmId,
      artistName: _artistController.text.trim(),
      albumTitle: _albumController.text.trim(),
      format: _track!.format,
      sampleRate: _track!.sampleRate,
      bitDepth: _track!.bitDepth,
      verified: _track!.verified,
      genre: _genreController.text.trim().isNotEmpty
          ? _genreController.text.trim()
          : null,
      trackNumber: parsedTrackNumber,
      discNumber: _track!.discNumber,
    );

    setState(() {
      _isSaving = true;
    });

    Track savedTrack = updatedTrack;
    if (widget.musicService != null) {
      try {
        savedTrack = await widget.musicService!.updateTrack(updatedTrack);
      } catch (_) {
        savedTrack = updatedTrack;
      }
    }

    if (!mounted) return;

    widget.onTrackUpdated?.call(savedTrack);

    if (_artistFocusNode.hasFocus) _artistFocusNode.unfocus();
    if (_albumFocusNode.hasFocus) _albumFocusNode.unfocus();

    setState(() {
      _track = savedTrack;
      _validationErrors.clear();
      _isEditing = false;
      _isSaving = false;
    });
  }

  String get _currentActivePcmHash =>
      _track?.pcmHash ?? widget.initialAudio?.pcmHash ?? '';

  Future<void> _fetchDetails() async {
    final callId = ++_fetchDetailsCallId;
    final service = widget.musicService;
    final activePcmHash = _currentActivePcmHash;
    final explicitFileHash = widget.asset?.fileHash;

    if (service == null) {
      if (_selectedAudio != null && _audioVersions.isEmpty) {
        setState(() {
          _audioVersions = [_selectedAudio!];
        });
      }
      return;
    }

    if (activePcmHash.isEmpty &&
        (explicitFileHash == null || explicitFileHash.isEmpty)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<Audio> versions = [];
      Audio? resolvedAudio = _selectedAudio;
      SourceData? fetchedSource = _sourceData;
      Asset? fetchedAsset = _resolvedAsset;

      // Tier 3: Fetch Audio versions via Single-Level Star Topology
      if (activePcmHash.isNotEmpty) {
        versions = await service.getAudioVersions(activePcmHash);
        if (versions.isEmpty) {
          final single = await service.getAudioDetails(activePcmHash);
          if (single != null) versions = [single];
        }

        // Set inspected audio version: default to currently active version
        if (versions.isNotEmpty) {
          resolvedAudio = versions.firstWhere(
            (a) => a.pcmHash == activePcmHash,
            orElse: () => versions.first,
          );
        } else {
          resolvedAudio ??= await service.getAudioDetails(activePcmHash);
        }
      }

      // Resolve physical file hash from selected Audio assets or parentHash
      String? fileHash = explicitFileHash;
      if (fileHash == null || fileHash.isEmpty) {
        if (resolvedAudio != null && resolvedAudio.assets.isNotEmpty) {
          fileHash = resolvedAudio.assets.first.fileHash;
        } else if (resolvedAudio?.parentHash.isNotEmpty == true) {
          fileHash = resolvedAudio!.parentHash;
        }
      }

      // Tier 4: Fetch Asset and SourceData
      if (fileHash != null && fileHash.isNotEmpty) {
        fetchedAsset ??= await service.getAsset(fileHash);
        fetchedSource ??= await service.getSourceData(fileHash);
      }

      // Fallback asset from audio.assets if service didn't return one
      if (fetchedAsset == null &&
          resolvedAudio != null &&
          resolvedAudio.assets.isNotEmpty) {
        fetchedAsset = resolvedAudio.assets.first;
      }

      if (!mounted || callId != _fetchDetailsCallId) return;

      setState(() {
        _audioVersions = versions.isNotEmpty
            ? versions
            : (resolvedAudio != null ? [resolvedAudio] : []);
        _selectedAudio = resolvedAudio;
        _resolvedAsset = fetchedAsset;
        _sourceData = fetchedSource;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || callId != _fetchDetailsCallId) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectVersion(Audio version) async {
    if (_selectedAudio?.pcmHash == version.pcmHash) return;

    setState(() {
      _selectedAudio = version;
      _isLoading = true;
    });

    final service = widget.musicService;
    String? fileHash;
    if (version.assets.isNotEmpty) {
      fileHash = version.assets.first.fileHash;
    } else if (version.parentHash.isNotEmpty) {
      fileHash = version.parentHash;
    }

    Asset? asset = version.assets.isNotEmpty ? version.assets.first : null;
    SourceData? sourceData;

    if (service != null && fileHash != null && fileHash.isNotEmpty) {
      try {
        final fetchedAsset = await service.getAsset(fileHash);
        if (fetchedAsset != null) asset = fetchedAsset;
        sourceData = await service.getSourceData(fileHash);
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _resolvedAsset = asset;
      _sourceData = sourceData;
      _isLoading = false;
    });
  }

  Future<void> _handleSetActiveAudio() async {
    if (_track == null || _selectedAudio == null) return;
    final trackId = _track!.id;
    final newPcmHash = _selectedAudio!.pcmHash;

    setState(() {
      _isSwitchingActive = true;
    });

    try {
      await widget.musicService?.switchTrackAudio(trackId, newPcmHash);
      widget.onActiveAudioChanged?.call(newPcmHash);

      if (!mounted) return;

      setState(() {
        _track = _track!.copyWith(
          pcmHash: newPcmHash,
          bitDepth: _selectedAudio!.bitDepth,
          sampleRate: _selectedAudio!.sampleRate,
        );
        _isSwitchingActive = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSwitchingActive = false;
      });
    }
  }

  String _formatSourceType(String sourceType) {
    switch (sourceType.toLowerCase().replaceAll('-', '_')) {
      case 'cd_rip':
        return 'CD-Rip';
      case 'studio_master':
        return 'Studio Master';
      case 'vinyl_rip':
        return 'Vinyl Rip';
      case 'digital_download':
        return 'Digital Download';
      case 'tape_transfer':
      case 'tape':
        return 'Master Tape';
      case 'streaming':
        return 'Stream Capture';
      default:
        if (sourceType.isEmpty) return '—';
        return sourceType
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (w) =>
                  w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
            )
            .join(' ');
    }
  }

  String _formatChannels(int channels) {
    switch (channels) {
      case 1:
        return '1.0 Mono';
      case 2:
        return '2.0 Stereo';
      case 6:
        return '5.1 Surround';
      case 8:
        return '7.1 Surround';
      default:
        return channels > 0 ? '$channels Channels' : '—';
    }
  }

  String _formatSampleRate(int sampleRate) {
    if (sampleRate <= 0) return '—';
    final khz = (sampleRate / 1000).toStringAsFixed(
      sampleRate % 1000 == 0 ? 0 : 1,
    );
    return '$khz kHz';
  }

  String _formatBitDepth(int bitDepth) {
    if (bitDepth <= 0) return '—';
    if (bitDepth == 32) return '32-bit Float';
    return '$bitDepth-bit PCM';
  }

  String _formatAudioContainer(Audio v) {
    final asset = v.assets.isNotEmpty ? v.assets.first : null;
    final mime = asset?.mimeType.toLowerCase() ?? '';
    if (mime.contains('flac')) return 'FLAC (Lossless)';
    if (mime.contains('wav')) return 'WAV (Lossless)';
    if (mime.contains('alac')) return 'ALAC (Lossless)';
    if (mime.contains('aiff')) return 'AIFF (Lossless)';
    if (mime.contains('mpeg') || mime.contains('mp3')) return 'MP3 (Lossy)';
    if (mime.contains('aac') || mime.contains('m4a') || mime.contains('mp4')) {
      return 'M4A (Lossy)';
    }
    if (mime.contains('ogg')) return 'OGG (Lossy)';

    final trackFormat = _track?.format?.toLowerCase() ?? '';
    if (trackFormat.contains('flac')) return 'FLAC (Lossless)';
    if (trackFormat.contains('wav')) return 'WAV (Lossless)';
    if (trackFormat.contains('alac')) return 'ALAC (Lossless)';
    if (trackFormat.contains('aiff')) return 'AIFF (Lossless)';
    if (trackFormat.contains('mp3') || trackFormat.contains('mpeg')) {
      return 'MP3 (Lossy)';
    }
    if (trackFormat.contains('aac') ||
        trackFormat.contains('m4a') ||
        trackFormat.contains('mp4')) {
      return 'M4A (Lossy)';
    }
    if (trackFormat.contains('ogg')) return 'OGG (Lossy)';

    if (v.bitDepth >= 16) return 'FLAC (Lossless)';
    return v.bitDepth > 0 ? 'Lossless' : 'Lossy';
  }

  String _formatVersionLabel(Audio v) {
    final container = _formatAudioContainer(v);
    if (v.bitDepth > 0 && v.sampleRate > 0) {
      return '$container · ${v.formattedQuality}';
    }
    return container;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    if (_track == null && widget.asset == null && _selectedAudio == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LyraSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.fileSearch, size: 48.0, color: tokens.textMuted),
              const SizedBox(height: LyraSpacing.md),
              Text('No Entity Selected', style: LyraTypography.h3(tokens)),
              const SizedBox(height: LyraSpacing.xs),
              Text(
                'Select a track or CAS storage object to inspect acoustic specifications and digital notarization records.',
                style: LyraTypography.muted(tokens),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final hasEntitySummary =
        _track != null || (_resolvedAsset ?? widget.asset) != null;

    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entity Overview (Track / Asset Summary) or Edit Form
          if (_isEditing && _track != null) ...[
            _buildEditMetadataForm(tokens),
            _buildSectionDivider(tokens),
          ] else if (hasEntitySummary) ...[
            _buildEntitySummarySection(tokens),
            _buildSectionDivider(tokens),
          ],

          // Audio Version Selector (Star Topology)
          if (_audioVersions.isNotEmpty) ...[
            _buildAudioVersionSection(tokens),
            _buildSectionDivider(tokens),
          ],

          // Section 1: Audio Specifications (Audio - Tier 3)
          _buildAcousticSpecificationsSection(tokens),

          _buildSectionDivider(tokens),

          // Section 2: File Storage (CAS Asset Reference - Tier 4)
          _buildCasAssetSection(tokens),

          _buildSectionDivider(tokens),

          // Section 3: Source Information (SourceData - Tier 4)
          _buildProvenanceSection(tokens),

          const SizedBox(height: LyraSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildSectionDivider(LyraThemeTokens tokens) {
    return Container(
      height: 1.0,
      margin: const EdgeInsets.symmetric(vertical: LyraSpacing.lg),
      color: tokens.border,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
    required LyraThemeTokens tokens,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LyraSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 15.0, color: tokens.primary),
          const SizedBox(width: LyraSpacing.xs),
          Expanded(
            child: Text(
              title,
              style: LyraTypography.small(tokens).copyWith(
                fontWeight: FontWeight.bold,
                color: tokens.textMuted,
                fontSize: 13.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildEditMetadataForm(LyraThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: LucideIcons.tag,
          title: 'Edit Metadata',
          tokens: tokens,
        ),
        const SizedBox(height: LyraSpacing.xs),
        Text(
          'TITLE',
          style: LyraTypography.small(tokens).copyWith(
            fontWeight: FontWeight.bold,
            color: tokens.textMuted,
            fontSize: 11.0,
          ),
        ),
        const SizedBox(height: 4.0),
        LyraInput(
          key: const Key('inspector_edit_title_input'),
          controller: _titleController,
          placeholder: 'Track Title',
        ),
        const SizedBox(height: LyraSpacing.sm),
        Text(
          'ARTIST',
          style: LyraTypography.small(tokens).copyWith(
            fontWeight: FontWeight.bold,
            color: tokens.textMuted,
            fontSize: 11.0,
          ),
        ),
        const SizedBox(height: 4.0),
        _MetadataAutocompleteField(
          inputKey: const Key('inspector_edit_artist_input'),
          controller: _artistController,
          focusNode: _artistFocusNode,
          placeholder: 'Artist',
          suggestions: _availableArtists,
          itemIcon: LucideIcons.user,
          tokens: tokens,
        ),
        const SizedBox(height: LyraSpacing.sm),
        Text(
          'ALBUM',
          style: LyraTypography.small(tokens).copyWith(
            fontWeight: FontWeight.bold,
            color: tokens.textMuted,
            fontSize: 11.0,
          ),
        ),
        const SizedBox(height: 4.0),
        _MetadataAutocompleteField(
          inputKey: const Key('inspector_edit_album_input'),
          controller: _albumController,
          focusNode: _albumFocusNode,
          placeholder: 'Album',
          suggestions: _availableAlbums,
          itemIcon: LucideIcons.disc,
          tokens: tokens,
        ),
        const SizedBox(height: LyraSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YEAR',
                    style: LyraTypography.small(tokens).copyWith(
                      fontWeight: FontWeight.bold,
                      color: tokens.textMuted,
                      fontSize: 11.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Container(
                    decoration: _validationErrors.containsKey('year')
                        ? BoxDecoration(
                            borderRadius: LyraRadius.smRadius,
                            border: Border.all(
                              color: tokens.destructive,
                              width: 1.5,
                            ),
                          )
                        : null,
                    child: LyraInput(
                      key: const Key('inspector_edit_year_input'),
                      controller: _yearController,
                      placeholder: 'Year',
                      onChanged: (_) => _clearFieldError('year'),
                    ),
                  ),
                  if (_validationErrors.containsKey('year')) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      _validationErrors['year']!,
                      key: const Key('inspector_edit_year_error'),
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.destructive,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LyraSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRACK NO.',
                    style: LyraTypography.small(tokens).copyWith(
                      fontWeight: FontWeight.bold,
                      color: tokens.textMuted,
                      fontSize: 11.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Container(
                    decoration: _validationErrors.containsKey('trackNumber')
                        ? BoxDecoration(
                            borderRadius: LyraRadius.smRadius,
                            border: Border.all(
                              color: tokens.destructive,
                              width: 1.5,
                            ),
                          )
                        : null,
                    child: LyraInput(
                      key: const Key('inspector_edit_track_number_input'),
                      controller: _trackNumberController,
                      placeholder: 'Track #',
                      onChanged: (_) => _clearFieldError('trackNumber'),
                    ),
                  ),
                  if (_validationErrors.containsKey('trackNumber')) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      _validationErrors['trackNumber']!,
                      key: const Key('inspector_edit_track_number_error'),
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.destructive,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: LyraSpacing.sm),
        Text(
          'GENRE',
          style: LyraTypography.small(tokens).copyWith(
            fontWeight: FontWeight.bold,
            color: tokens.textMuted,
            fontSize: 11.0,
          ),
        ),
        const SizedBox(height: 4.0),
        LyraInput(
          key: const Key('inspector_edit_genre_input'),
          controller: _genreController,
          placeholder: 'Genre',
        ),
        const SizedBox(height: LyraSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ISWC',
                    style: LyraTypography.small(tokens).copyWith(
                      fontWeight: FontWeight.bold,
                      color: tokens.textMuted,
                      fontSize: 11.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Container(
                    decoration: _validationErrors.containsKey('iswc')
                        ? BoxDecoration(
                            borderRadius: LyraRadius.smRadius,
                            border: Border.all(
                              color: tokens.destructive,
                              width: 1.5,
                            ),
                          )
                        : null,
                    child: LyraInput(
                      key: const Key('inspector_edit_iswc_input'),
                      controller: _iswcController,
                      placeholder: 'ISWC',
                      onChanged: (_) => _clearFieldError('iswc'),
                    ),
                  ),
                  if (_validationErrors.containsKey('iswc')) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      _validationErrors['iswc']!,
                      key: const Key('inspector_edit_iswc_error'),
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.destructive,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: LyraSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ISRC',
                    style: LyraTypography.small(tokens).copyWith(
                      fontWeight: FontWeight.bold,
                      color: tokens.textMuted,
                      fontSize: 11.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Container(
                    decoration: _validationErrors.containsKey('isrc')
                        ? BoxDecoration(
                            borderRadius: LyraRadius.smRadius,
                            border: Border.all(
                              color: tokens.destructive,
                              width: 1.5,
                            ),
                          )
                        : null,
                    child: LyraInput(
                      key: const Key('inspector_edit_isrc_input'),
                      controller: _isrcController,
                      placeholder: 'ISRC',
                      onChanged: (_) => _clearFieldError('isrc'),
                    ),
                  ),
                  if (_validationErrors.containsKey('isrc')) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      _validationErrors['isrc']!,
                      key: const Key('inspector_edit_isrc_error'),
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.destructive,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: LyraSpacing.md),
        Row(
          children: [
            Expanded(
              child: LyraButton.outline(
                key: const Key('inspector_cancel_button'),
                size: LyraButtonSize.sm,
                onPressed: _isSaving ? null : _cancelEditing,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: LyraSpacing.sm),
            Expanded(
              child: LyraButton.primary(
                key: const Key('inspector_save_button'),
                size: LyraButtonSize.sm,
                onPressed: _isSaving ? null : _saveEditing,
                leading: _isSaving
                    ? const SizedBox(
                        width: 14.0,
                        height: 14.0,
                        child: Center(
                          child: Icon(LucideIcons.loader2, size: 14.0),
                        ),
                      )
                    : const Icon(LucideIcons.check, size: 14.0),
                child: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntitySummarySection(LyraThemeTokens tokens) {
    final track = _track;
    final asset = _resolvedAsset ?? widget.asset;

    if (track != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: tokens.primary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.music,
                    size: 16.0,
                    color: tokens.primaryForeground,
                  ),
                ),
              ),
              const SizedBox(width: LyraSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.displayTitle,
                      style: LyraTypography.p(
                        tokens,
                      ).copyWith(fontWeight: FontWeight.bold, fontSize: 15.0),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${track.artist.isNotEmpty ? track.artist : "Unknown Artist"} • ${track.album.isNotEmpty ? track.album : "Unknown Album"}',
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(color: tokens.textMuted, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LyraSpacing.xs),
              LyraButton.outline(
                key: const Key('inspector_edit_button'),
                size: LyraButtonSize.sm,
                onPressed: _startEditing,
                leading: const Icon(LucideIcons.pencil, size: 13.0),
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.sm),
          Wrap(
            spacing: LyraSpacing.xs,
            runSpacing: LyraSpacing.xs,
            children: [
              LyraBadge.secondary(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                child: Text(
                  track.formattedQuality,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(fontSize: 11.0, fontWeight: FontWeight.w600),
                ),
              ),
              if (track.durationMs != null && track.durationMs! > 0)
                LyraBadge.outline(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  child: Text(
                    track.formattedDuration,
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(fontSize: 11.0),
                  ),
                ),
              if (track.recordingYear != null)
                LyraBadge.outline(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  child: Text(
                    '${track.recordingYear}',
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(fontSize: 11.0),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    if (asset != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.hardDrive,
                    size: 16.0,
                    color: tokens.primary,
                  ),
                ),
              ),
              const SizedBox(width: LyraSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAS Asset',
                      style: LyraTypography.p(
                        tokens,
                      ).copyWith(fontWeight: FontWeight.bold, fontSize: 15.0),
                    ),
                    Text(
                      asset.shortHash,
                      style: LyraTypography.mono(
                        tokens,
                        fontSize: 12.0,
                      ).copyWith(color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.sm),
          Wrap(
            spacing: LyraSpacing.xs,
            children: [
              if (asset.mimeType.isNotEmpty)
                LyraBadge.secondary(
                  child: Text(
                    asset.mimeType,
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(fontSize: 11.0),
                  ),
                ),
              if (asset.fileSize > 0)
                LyraBadge.outline(
                  child: Text(
                    asset.formattedSize,
                    style: LyraTypography.small(
                      tokens,
                    ).copyWith(fontSize: 11.0),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAudioVersionSection(LyraThemeTokens tokens) {
    final activePcmHash = _currentActivePcmHash;
    final isInspectingActive = _selectedAudio?.pcmHash == activePcmHash;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: LucideIcons.layers,
          title: 'Audio Versions',
          tokens: tokens,
        ),
        ..._audioVersions.map((v) {
          final isMaster = v.parentHash.isEmpty || v.parentHash == v.pcmHash;
          final isActive = v.pcmHash == activePcmHash;
          final isInspected = v.pcmHash == _selectedAudio?.pcmHash;

          final label = _formatVersionLabel(v);

          return Padding(
            padding: const EdgeInsets.only(bottom: LyraSpacing.xs),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _selectVersion(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LyraSpacing.sm,
                    vertical: LyraSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isInspected
                        ? tokens.secondary
                        : tokens.secondary.withValues(alpha: 0.35),
                    borderRadius: LyraRadius.smRadius,
                    border: Border.all(
                      color: isInspected ? tokens.primary : tokens.border,
                      width: isInspected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isMaster ? LucideIcons.disc : LucideIcons.gitFork,
                        size: 16.0,
                        color: isInspected ? tokens.primary : tokens.textMuted,
                      ),
                      const SizedBox(width: LyraSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    label,
                                    style: LyraTypography.small(tokens)
                                        .copyWith(
                                          fontWeight: isInspected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: tokens.text,
                                          fontSize: 13.0,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMaster) ...[
                                  const SizedBox(width: 4.0),
                                  LyraBadge.secondary(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5.0,
                                      vertical: 1.0,
                                    ),
                                    child: Text(
                                      'Master',
                                      style: LyraTypography.small(tokens)
                                          .copyWith(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: tokens.textMuted,
                                          ),
                                    ),
                                  ),
                                ],
                                if (isActive) ...[
                                  const SizedBox(width: 4.0),
                                  LyraBadge.outline(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5.0,
                                      vertical: 1.0,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 5.0,
                                          height: 5.0,
                                          decoration: BoxDecoration(
                                            color: tokens.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 3.0),
                                        Text(
                                          'Active',
                                          style: LyraTypography.small(tokens)
                                              .copyWith(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: tokens.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${_formatChannels(v.channels)} • ${v.shortPcmHash}',
                              style: LyraTypography.mono(
                                tokens,
                                fontSize: 11.5,
                              ).copyWith(color: tokens.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (!isInspectingActive && _track != null) ...[
          const SizedBox(height: LyraSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: LyraButton(
              size: LyraButtonSize.sm,
              onPressed: _isSwitchingActive ? null : _handleSetActiveAudio,
              leading: _isSwitchingActive
                  ? const Icon(LucideIcons.loader2, size: 14.0)
                  : const Icon(LucideIcons.check, size: 14.0),
              child: Text(
                _isSwitchingActive
                    ? 'Switching Audio...'
                    : 'Set as Active Audio',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAcousticSpecificationsSection(LyraThemeTokens tokens) {
    final audio = _selectedAudio;
    final track = _track;

    final sampleRate = audio?.sampleRate ?? track?.sampleRate ?? 0;
    final bitDepth = audio?.bitDepth ?? track?.bitDepth ?? 0;
    final channels = audio?.channels ?? 0;
    final pcmHash = audio?.pcmHash.isNotEmpty == true
        ? audio!.pcmHash
        : (track?.pcmHash.isNotEmpty == true ? track!.pcmHash : '');

    final hasLoudness =
        audio != null &&
        (audio.integratedLoudness != 0.0 || audio.truePeak != 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: LucideIcons.activity,
          title: 'Audio Specifications',
          trailing: _isLoading
              ? const SizedBox(
                  width: 14.0,
                  height: 14.0,
                  child: Center(child: Icon(LucideIcons.loader2, size: 14.0)),
                )
              : null,
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Sample Rate',
          value: sampleRate > 0 ? _formatSampleRate(sampleRate) : '—',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Bit Depth',
          value: bitDepth > 0 ? _formatBitDepth(bitDepth) : '—',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Channels',
          value: channels > 0 ? _formatChannels(channels) : '—',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Integrated Loudness',
          value: hasLoudness
              ? '${audio.integratedLoudness.toStringAsFixed(1)} LUFS'
              : '—',
          subtitle: hasLoudness ? null : 'Not analyzed',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'True Peak',
          value: hasLoudness
              ? '${audio.truePeak >= 0 ? "+" : ""}${audio.truePeak.toStringAsFixed(1)} dBTP'
              : '—',
          subtitle: hasLoudness
              ? (audio.truePeak > 0.0 ? 'Over 0 dBTP' : null)
              : 'Not analyzed',
          valueColor: hasLoudness && audio.truePeak > 0.0
              ? tokens.destructive
              : null,
          tokens: tokens,
        ),
        if (pcmHash.isNotEmpty) ...[
          const SizedBox(height: LyraSpacing.sm),
          _buildHashBox(
            label: 'PCM Hash',
            hash: pcmHash,
            fieldId: 'pcm_hash',
            tokens: tokens,
          ),
        ] else ...[
          _buildPropertyRow(
            label: 'PCM Hash',
            value: '—',
            subtitle: 'Not available',
            tokens: tokens,
          ),
        ],
      ],
    );
  }

  Widget _buildCasAssetSection(LyraThemeTokens tokens) {
    final asset = _resolvedAsset ?? widget.asset;
    final fileHash =
        asset?.fileHash ??
        (_selectedAudio != null && _selectedAudio!.assets.isNotEmpty
            ? _selectedAudio!.assets.first.fileHash
            : '');

    final hasAsset = asset != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: LucideIcons.database,
          title: 'File Storage',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'File Size',
          value: hasAsset && asset.fileSize > 0 ? asset.formattedSize : '—',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'MIME Type',
          value: hasAsset && asset.mimeType.isNotEmpty ? asset.mimeType : '—',
          tokens: tokens,
        ),
        if (fileHash.isNotEmpty) ...[
          const SizedBox(height: LyraSpacing.sm),
          _buildHashBox(
            label: 'File Hash',
            hash: fileHash,
            fieldId: 'cas_hash',
            tokens: tokens,
          ),
        ] else ...[
          _buildPropertyRow(
            label: 'File Hash',
            value: '—',
            subtitle: 'Not registered in CAS',
            tokens: tokens,
          ),
        ],
      ],
    );
  }

  Widget _buildProvenanceSection(LyraThemeTokens tokens) {
    final sourceData = _sourceData;
    final asset = _resolvedAsset ?? widget.asset;
    final track = _track;

    final sourceType = sourceData?.sourceType ?? '';
    final originalPath = sourceData?.originalPath.isNotEmpty == true
        ? sourceData!.originalPath
        : (track?.recordingLocation?.isNotEmpty == true
              ? track!.recordingLocation!
              : '');
    final createdAt = sourceData?.createdAt ?? asset?.createdAt;
    final note = sourceData?.note ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: LucideIcons.shieldCheck,
          title: 'Source Information',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Source Type',
          value: sourceType.isNotEmpty ? _formatSourceType(sourceType) : '—',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Timestamp',
          value: createdAt != null
              ? '${createdAt.toIso8601String().replaceAll('T', ' ').substring(0, 19)} UTC'
              : '—',
          isMono: createdAt != null,
          tokens: tokens,
        ),
        if (originalPath.isNotEmpty) ...[
          const SizedBox(height: 2.0),
          _buildOriginalPathBox(originalPath, tokens),
        ] else ...[
          _buildPropertyRow(
            label: 'Original File Path',
            value: '—',
            tokens: tokens,
          ),
        ],
        if (note.isNotEmpty) ...[
          const SizedBox(height: LyraSpacing.sm),
          Text(
            'Ingestion Note',
            style: LyraTypography.small(tokens).copyWith(
              fontWeight: FontWeight.bold,
              color: tokens.textMuted,
              fontSize: 12.0,
            ),
          ),
          const SizedBox(height: 4.0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(LyraSpacing.sm),
            decoration: BoxDecoration(
              color: tokens.secondary.withValues(alpha: 0.5),
              borderRadius: LyraRadius.smRadius,
              border: Border.all(color: tokens.border, width: 1.0),
            ),
            child: SelectionArea(
              child: Text(
                note,
                style: LyraTypography.mono(
                  tokens,
                  fontSize: 12.0,
                ).copyWith(height: 1.4, color: tokens.text),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPropertyRow({
    required String label,
    required String value,
    String? subtitle,
    Color? valueColor,
    bool isMono = false,
    Widget? customValue,
    required LyraThemeTokens tokens,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = constraints.maxWidth < 280 ? 95.0 : 135.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: LyraTypography.small(tokens).copyWith(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: tokens.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: LyraSpacing.xs),
              Expanded(
                child:
                    customValue ??
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value,
                          style:
                              (isMono
                                      ? LyraTypography.mono(
                                          tokens,
                                          fontSize: 12.0,
                                        )
                                      : LyraTypography.p(tokens).copyWith(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ))
                                  .copyWith(color: valueColor ?? tokens.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 1.0),
                          Text(
                            subtitle,
                            style: LyraTypography.muted(
                              tokens,
                            ).copyWith(fontSize: 11.0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHashBox({
    required String label,
    required String hash,
    required String fieldId,
    required LyraThemeTokens tokens,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: LyraTypography.small(tokens).copyWith(
            fontWeight: FontWeight.bold,
            color: tokens.textMuted,
            fontSize: 12.0,
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.sm,
            vertical: LyraSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: tokens.secondary.withValues(alpha: 0.5),
            borderRadius: LyraRadius.smRadius,
            border: Border.all(color: tokens.border, width: 1.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hash,
                  style: LyraTypography.mono(tokens, fontSize: 12.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: LyraSpacing.xs),
              LyraCopyButton(text: hash),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalPathBox(String path, LyraThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Original File Path',
          style: LyraTypography.small(tokens).copyWith(
            fontWeight: FontWeight.bold,
            color: tokens.textMuted,
            fontSize: 12.0,
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.sm,
            vertical: LyraSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: tokens.secondary.withValues(alpha: 0.5),
            borderRadius: LyraRadius.smRadius,
            border: Border.all(color: tokens.border, width: 1.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  path,
                  style: LyraTypography.mono(tokens, fontSize: 12.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: LyraSpacing.xs),
              LyraCopyButton(text: path),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldDiff {
  final String label;
  final String? oldValue;
  final String? newValue;

  const _FieldDiff({
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  bool get isChanged {
    final oldNorm = (oldValue?.trim().isEmpty ?? true)
        ? null
        : oldValue!.trim();
    final newNorm = (newValue?.trim().isEmpty ?? true)
        ? null
        : newValue!.trim();
    return oldNorm != newNorm;
  }
}

class _MetadataDiffDialog extends StatelessWidget {
  final List<_FieldDiff> diffs;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _MetadataDiffDialog({
    required this.diffs,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Center(
      key: const Key('metadata_diff_dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540.0),
        child: LyraDialog(
          onClose: onCancel,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(LyraSpacing.xs),
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Icon(
                  LucideIcons.gitCompare,
                  size: 18.0,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(width: LyraSpacing.sm),
              Text(
                'Confirm Metadata Changes',
                style: LyraTypography.h3(tokens),
              ),
            ],
          ),
          description: Text(
            diffs.isEmpty
                ? 'No fields have been modified.'
                : 'Review the ${diffs.length} modified ${diffs.length == 1 ? "field" : "fields"} before applying changes to the database.',
            style: LyraTypography.muted(tokens),
          ),
          actions: [
            LyraButton.outline(
              key: const Key('diff_dialog_cancel_button'),
              size: LyraButtonSize.sm,
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
            LyraButton.primary(
              key: const Key('diff_dialog_confirm_button'),
              size: LyraButtonSize.sm,
              onPressed: onConfirm,
              leading: const Icon(LucideIcons.check, size: 14.0),
              child: const Text('Confirm & Save'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (diffs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: LyraSpacing.lg),
                  child: Center(
                    child: Text(
                      'No changes detected.',
                      style: LyraTypography.muted(tokens),
                    ),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LyraSpacing.sm,
                    vertical: LyraSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.secondary.withValues(alpha: 0.5),
                    borderRadius: LyraRadius.smRadius,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ORIGINAL (BEFORE)',
                          style: LyraTypography.small(tokens).copyWith(
                            fontWeight: FontWeight.bold,
                            color: tokens.textMuted,
                            fontSize: 11.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: LyraSpacing.md),
                      Expanded(
                        child: Text(
                          'MODIFIED (AFTER)',
                          style: LyraTypography.small(tokens).copyWith(
                            fontWeight: FontWeight.bold,
                            color: tokens.textMuted,
                            fontSize: 11.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LyraSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: diffs.map((diff) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: LyraSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                diff.label.toUpperCase(),
                                style: LyraTypography.small(tokens).copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: tokens.textMuted,
                                  fontSize: 10.0,
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildBeforeCell(diff, tokens),
                                  ),
                                  const SizedBox(width: LyraSpacing.md),
                                  Expanded(
                                    child: _buildAfterCell(diff, tokens),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeforeCell(_FieldDiff diff, LyraThemeTokens tokens) {
    final oldText = diff.oldValue?.trim();
    final isEmpty = oldText == null || oldText.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.sm,
        vertical: LyraSpacing.xs + 2.0,
      ),
      decoration: BoxDecoration(
        color: tokens.destructive.withValues(alpha: 0.08),
        borderRadius: LyraRadius.smRadius,
        border: Border.all(
          color: tokens.destructive.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
            decoration: BoxDecoration(
              color: tokens.destructive.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3.0),
            ),
            child: Text(
              '-',
              style: TextStyle(
                color: tokens.destructive,
                fontWeight: FontWeight.bold,
                fontSize: 12.0,
              ),
            ),
          ),
          const SizedBox(width: LyraSpacing.xs),
          Expanded(
            child: Text(
              isEmpty ? 'None' : oldText,
              style: LyraTypography.small(tokens).copyWith(
                color: isEmpty ? tokens.textMuted : tokens.destructive,
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                decoration: isEmpty ? null : TextDecoration.lineThrough,
                decorationColor: tokens.destructive.withValues(alpha: 0.6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfterCell(_FieldDiff diff, LyraThemeTokens tokens) {
    final newText = diff.newValue?.trim();
    final isCleared = newText == null || newText.isEmpty;
    const emeraldColor = Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.sm,
        vertical: LyraSpacing.xs + 2.0,
      ),
      decoration: BoxDecoration(
        color: isCleared
            ? tokens.destructive.withValues(alpha: 0.08)
            : emeraldColor.withValues(alpha: 0.08),
        borderRadius: LyraRadius.smRadius,
        border: Border.all(
          color: isCleared
              ? tokens.destructive.withValues(alpha: 0.25)
              : emeraldColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
            decoration: BoxDecoration(
              color: isCleared
                  ? tokens.destructive.withValues(alpha: 0.15)
                  : emeraldColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3.0),
            ),
            child: Text(
              isCleared ? '×' : '+',
              style: TextStyle(
                color: isCleared ? tokens.destructive : emeraldColor,
                fontWeight: FontWeight.bold,
                fontSize: 12.0,
              ),
            ),
          ),
          const SizedBox(width: LyraSpacing.xs),
          Expanded(
            child: Text(
              isCleared ? 'Cleared' : newText,
              style: LyraTypography.small(tokens).copyWith(
                color: isCleared ? tokens.destructive : emeraldColor,
                fontStyle: isCleared ? FontStyle.italic : FontStyle.normal,
                fontWeight: isCleared ? FontWeight.normal : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutocompleteOption {
  final String label;
  final String value;
  final bool isCreate;

  const _AutocompleteOption({
    required this.label,
    required this.value,
    this.isCreate = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AutocompleteOption &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          isCreate == other.isCreate;

  @override
  int get hashCode => Object.hash(value, isCreate);

  @override
  String toString() => isCreate ? 'Create "$value"' : value;
}

class _MetadataAutocompleteField extends StatefulWidget {
  final Key? inputKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final List<String> suggestions;
  final IconData itemIcon;
  final LyraThemeTokens tokens;

  const _MetadataAutocompleteField({
    this.inputKey,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.suggestions,
    required this.itemIcon,
    required this.tokens,
  });

  @override
  State<_MetadataAutocompleteField> createState() =>
      _MetadataAutocompleteFieldState();
}

class _MetadataAutocompleteFieldState
    extends State<_MetadataAutocompleteField> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  final Object _tapRegionGroupId = Object();
  double _fieldWidth = 0.0;
  List<_AutocompleteOption> _options = [];
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _MetadataAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
    if (oldWidget.suggestions != widget.suggestions) {
      _computeOptions();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    widget.focusNode.removeListener(_handleFocusChanged);
    // Note: Do not call _overlayController.hide() here.
    // OverlayPortal automatically unmounts its overlay child when unmounted.
    super.dispose();
  }

  void _handleTextChanged() {
    if (!mounted) return;
    _computeOptions();
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    if (widget.focusNode.hasFocus) {
      _computeOptions();
    } else {
      _closeOptions();
    }
  }

  void _closeOptions() {
    if (!mounted) return;
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    if (_options.isNotEmpty) {
      setState(() {
        _options = [];
        _highlightedIndex = 0;
      });
    }
  }

  void _computeOptions() {
    if (!mounted) return;
    final query = widget.controller.text.trim();
    if (query.isEmpty || !widget.focusNode.hasFocus) {
      _closeOptions();
      return;
    }

    final qLower = query.toLowerCase();
    final matched = widget.suggestions
        .where((s) => s.toLowerCase().contains(qLower))
        .map((s) => _AutocompleteOption(label: s, value: s, isCreate: false))
        .toList();

    final hasExactMatch = widget.suggestions.any(
      (s) => s.toLowerCase() == qLower,
    );

    List<_AutocompleteOption> computed = matched;
    if (!hasExactMatch) {
      computed = [
        ...matched,
        _AutocompleteOption(
          label: 'Create "$query"',
          value: query,
          isCreate: true,
        ),
      ];
    }

    setState(() {
      _options = computed;
      _highlightedIndex = 0;
    });

    if (computed.isNotEmpty && widget.focusNode.hasFocus) {
      if (!_overlayController.isShowing) {
        _overlayController.show();
      }
    } else {
      if (_overlayController.isShowing) {
        _overlayController.hide();
      }
    }
  }

  void _onSelectOption(_AutocompleteOption option) {
    widget.controller.text = option.value;
    widget.controller.selection = TextSelection.collapsed(
      offset: option.value.length,
    );
    _closeOptions();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          return CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4.0),
            child: Align(
              alignment: Alignment.topLeft,
              child: TapRegion(
                groupId: _tapRegionGroupId,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: _fieldWidth > 0 ? _fieldWidth : 320.0,
                    decoration: BoxDecoration(
                      color: tokens.card,
                      borderRadius: LyraRadius.mdRadius,
                      border: Border.all(color: tokens.border, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.text.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: LyraRadius.mdRadius,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200.0),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          shrinkWrap: true,
                          itemCount: _options.length,
                          itemBuilder: (context, index) {
                            final option = _options[index];
                            final isHighlighted = index == _highlightedIndex;
                            return _AutocompleteItemTile(
                              key: Key(
                                'autocomplete_option_${option.isCreate ? "create_" : ""}${option.value}',
                              ),
                              option: option,
                              isHighlighted: isHighlighted,
                              tokens: tokens,
                              icon: option.isCreate
                                  ? LucideIcons.plus
                                  : widget.itemIcon,
                              onTap: () => _onSelectOption(option),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            _fieldWidth = constraints.maxWidth;
            return TapRegion(
              groupId: _tapRegionGroupId,
              onTapOutside: (_) => _closeOptions(),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      if (_options.isNotEmpty) {
                        setState(() {
                          _highlightedIndex =
                              (_highlightedIndex + 1) % _options.length;
                        });
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      if (_options.isNotEmpty) {
                        setState(() {
                          _highlightedIndex =
                              (_highlightedIndex - 1 + _options.length) %
                              _options.length;
                        });
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                      if (_overlayController.isShowing) {
                        _closeOptions();
                        return KeyEventResult.handled;
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: LyraInput(
                  key: widget.inputKey,
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  placeholder: widget.placeholder,
                  onSubmitted: (_) {
                    if (_options.isNotEmpty) {
                      _onSelectOption(
                        _options[_highlightedIndex.clamp(
                          0,
                          _options.length - 1,
                        )],
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AutocompleteItemTile extends StatefulWidget {
  final _AutocompleteOption option;
  final bool isHighlighted;
  final LyraThemeTokens tokens;
  final IconData icon;
  final VoidCallback onTap;

  const _AutocompleteItemTile({
    super.key,
    required this.option,
    required this.isHighlighted,
    required this.tokens,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AutocompleteItemTile> createState() => _AutocompleteItemTileState();
}

class _AutocompleteItemTileState extends State<_AutocompleteItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final option = widget.option;
    final isSelected = widget.isHighlighted || _isHovered;

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
            vertical: LyraSpacing.xs + 2.0,
          ),
          color: isSelected
              ? tokens.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 14.0,
                color: option.isCreate ? tokens.primary : tokens.textMuted,
              ),
              const SizedBox(width: LyraSpacing.sm),
              Expanded(
                child: option.isCreate
                    ? Text.rich(
                        TextSpan(
                          text: 'Create ',
                          style: LyraTypography.small(
                            tokens,
                          ).copyWith(color: tokens.textMuted),
                          children: [
                            TextSpan(
                              text: '"${option.value}"',
                              style: LyraTypography.small(tokens).copyWith(
                                fontWeight: FontWeight.bold,
                                color: tokens.primary,
                              ),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        option.label,
                        style: LyraTypography.small(tokens).copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: tokens.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              if (option.isCreate)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.secondary,
                    borderRadius: LyraRadius.smRadius,
                  ),
                  child: Text(
                    'New',
                    style: LyraTypography.small(tokens).copyWith(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      color: tokens.primary,
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
