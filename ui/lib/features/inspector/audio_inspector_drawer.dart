// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;
import 'package:flutter/material.dart'
    show
        Colors,
        InkWell,
        Material,
        PopupMenuButton,
        PopupMenuItem,
        RoundSliderOverlayShape,
        RoundSliderThumbShape,
        SelectionArea,
        Slider,
        SliderTheme,
        showDialog;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/waveform_data.dart';
import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_copy_button.dart';
import '../../design_system/widgets/lyra_dialog.dart';
import '../../design_system/widgets/lyra_input.dart';
import '../../design_system/widgets/lyra_skeleton.dart';
import '../../design_system/widgets/lyra_spinner.dart';
import '../../design_system/widgets/lyra_tooltip.dart';
import '../models/asset.dart';
import '../models/audio.dart';
import '../models/image_asset.dart';
import '../models/source_data.dart';
import '../models/track.dart';
import '../player/controllers/playback_queue_controller.dart';
import '../player/views/components/waveform_scrubber.dart';
import '../services/music_service.dart';
import '../settings/services/preferences_service.dart';

/// Audio entity-centric property inspector drawer displaying deep acoustic specifications,
/// Single-Level Star Topology audio versions, CAS storage properties, and digital provenance.
class AudioInspectorDrawer extends StatelessWidget {
  final Track? track;
  final Asset? asset;
  final Audio? initialAudio;
  final SourceData? initialSourceData;
  final MusicService? musicService;
  final PlaybackQueueController? playbackController;
  final PreferencesService? preferencesService;
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
    this.playbackController,
    this.preferencesService,
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
                  playbackController: playbackController,
                  preferencesService: preferencesService,
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
  final PlaybackQueueController? playbackController;
  final PreferencesService? preferencesService;
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
    this.playbackController,
    this.preferencesService,
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
  ImageAsset? _resolvedImageAsset;
  bool _isLoading = false;
  bool _isSwitchingActive = false;

  // Metadata Edit Mode State
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isConfirming = false;
  String? _saveErrorMessage;

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
  WaveformData? _waveform;
  int _waveformCallId = 0;
  int _selectVersionCallId = 0;

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

    widget.playbackController?.addListener(_onPlaybackStateChanged);
    widget.preferencesService?.addListener(_onPreferencesChanged);

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

    final activePcmHash =
        widget.track?.pcmHash ?? widget.initialAudio?.pcmHash ?? '';
    final explicitFileHash = widget.asset?.fileHash;
    final hasEntityToFetch =
        widget.musicService != null &&
        (activePcmHash.isNotEmpty ||
            (explicitFileHash != null && explicitFileHash.isNotEmpty));
    _isLoading = hasEntityToFetch;

    _syncControllersFromTrack(_track);
    _fetchDetails();
    _fetchAutocompleteSuggestions();
    _loadWaveform();
  }

  void _onPlaybackStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPreferencesChanged() {
    if (mounted) {
      _loadWaveform();
      setState(() {});
    }
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
    if (oldWidget.playbackController != widget.playbackController) {
      oldWidget.playbackController?.removeListener(_onPlaybackStateChanged);
      widget.playbackController?.addListener(_onPlaybackStateChanged);
    }
    if (oldWidget.preferencesService != widget.preferencesService) {
      oldWidget.preferencesService?.removeListener(_onPreferencesChanged);
      widget.preferencesService?.addListener(_onPreferencesChanged);
      _loadWaveform();
    }

    final trackChanged = oldWidget.track?.id != widget.track?.id;
    final assetChanged = oldWidget.asset?.fileHash != widget.asset?.fileHash;
    final trackDataChanged = oldWidget.track != widget.track;
    final serviceChanged = oldWidget.musicService != widget.musicService;

    if (serviceChanged) {
      _fetchAutocompleteSuggestions();
    }

    if (trackChanged ||
        oldWidget.track?.pcmHash != widget.track?.pcmHash ||
        assetChanged ||
        oldWidget.initialAudio != widget.initialAudio ||
        oldWidget.initialSourceData != widget.initialSourceData ||
        serviceChanged) {
      if (trackChanged) {
        if (_artistFocusNode.hasFocus) _artistFocusNode.unfocus();
        if (_albumFocusNode.hasFocus) _albumFocusNode.unfocus();
        _isEditing = false;
        _isSaving = false;
        _isSwitchingActive = false;
        _isConfirming = false;
        _saveErrorMessage = null;
        _validationErrors.clear();
      }
      // State Caching / Continuity:
      // Avoid needlessly clearing _audioVersions if the inspected audio entity hasn't changed.
      if (trackChanged || assetChanged) {
        _audioVersions = [];
      }
      _track = widget.track;
      _selectedAudio = widget.initialAudio;
      _sourceData = widget.initialSourceData;
      _resolvedAsset = widget.asset;
      _resolvedImageAsset = null;
      if (!_isEditing) {
        _syncControllersFromTrack(_track);
      }
      _fetchDetails();
      _loadWaveform();
    } else if (trackDataChanged) {
      _track = widget.track;
      if (!_isEditing) {
        _syncControllersFromTrack(_track);
      }
    }
  }

  @override
  void dispose() {
    widget.preferencesService?.removeListener(_onPreferencesChanged);
    widget.playbackController?.removeListener(_onPlaybackStateChanged);
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

  Future<void> _loadWaveform() async {
    final effectiveAsset = _resolvedAsset ?? widget.asset;
    if (_track == null && effectiveAsset?.isImage == true) {
      if (mounted && _waveform != null) {
        setState(() {
          _waveform = null;
        });
      }
      return;
    }

    final showWaveform =
        widget.preferencesService?.showInspectorWaveform ?? true;
    if (!showWaveform) {
      if (mounted && _waveform != null) {
        setState(() {
          _waveform = null;
        });
      }
      return;
    }

    final service = widget.musicService;
    final track = _track;
    final audio = _selectedAudio;
    final activePcmHash = audio?.pcmHash.isNotEmpty == true
        ? audio!.pcmHash
        : (track?.pcmHash.isNotEmpty == true
              ? track!.pcmHash
              : (_currentActivePcmHash.isNotEmpty
                    ? _currentActivePcmHash
                    : ''));
    final key = activePcmHash.isNotEmpty ? activePcmHash : (track?.id ?? '');

    if (service == null || key.isEmpty) {
      if (mounted && _waveform != null) {
        setState(() {
          _waveform = null;
        });
      }
      return;
    }

    final points = widget.preferencesService?.inspectorWaveformPoints ?? 100;
    final callId = ++_waveformCallId;
    try {
      final wf = await service.getWaveform(key, points: points);
      if (!mounted || callId != _waveformCallId) return;
      setState(() {
        _waveform = wf;
      });
    } catch (_) {
      if (!mounted || callId != _waveformCallId) return;
      setState(() {
        _waveform = null;
      });
    }
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
      _saveErrorMessage = null;
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    if (_artistFocusNode.hasFocus) _artistFocusNode.unfocus();
    if (_albumFocusNode.hasFocus) _albumFocusNode.unfocus();
    setState(() {
      _validationErrors.clear();
      _saveErrorMessage = null;
      _isEditing = false;
      _isSaving = false;
      _isConfirming = false;
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

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      errors['title'] = 'Title cannot be empty';
    }

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
    if (_isSaving || _isConfirming) return;

    final targetTrack = _track;
    if (targetTrack == null) return;

    if (!_validateFields()) {
      return;
    }

    final diffs = _computeFieldDiffs();

    FocusScope.of(context).unfocus();
    if (_artistFocusNode.hasFocus) _artistFocusNode.unfocus();
    if (_albumFocusNode.hasFocus) _albumFocusNode.unfocus();

    setState(() {
      _isConfirming = true;
      _saveErrorMessage = null;
    });

    bool? confirmed;
    try {
      bool popped = false;
      confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        builder: (dialogCtx) => LyraDesignSystemScope(
          factory: LyraDesignSystemScope.of(context).factory,
          tokens: LyraDesignSystemScope.of(context).tokens,
          themeModeNotifier: LyraDesignSystemScope.of(
            context,
          ).themeModeNotifier,
          child: _MetadataDiffDialog(
            diffs: diffs,
            onConfirm: () {
              if (popped) return;
              popped = true;
              Navigator.of(dialogCtx).pop(true);
            },
            onCancel: () {
              if (popped) return;
              popped = true;
              Navigator.of(dialogCtx).pop(false);
            },
          ),
        ),
      );
    } catch (_) {
      confirmed = false;
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
          if (confirmed == true && _track?.id == targetTrack.id) {
            _isSaving = true;
          }
        });
      }
    }

    if (confirmed != true || !mounted || _track?.id != targetTrack.id) {
      return;
    }

    final liveTrack =
        (widget.track?.id == targetTrack.id ? widget.track : _track) ??
        targetTrack;

    final yearText = _yearController.text.trim();
    final trackNumberText = _trackNumberController.text.trim();
    final parsedYear = yearText.isNotEmpty ? int.tryParse(yearText) : null;
    final parsedTrackNumber = trackNumberText.isNotEmpty
        ? int.tryParse(trackNumberText)
        : null;

    String? normalize(String s) => s.trim().isEmpty ? null : s.trim();

    final updatedTrack = Track(
      id: liveTrack.id,
      pcmHash: liveTrack.pcmHash,
      workId: liveTrack.workId,
      workTitle: liveTrack.workTitle,
      title: _titleController.text.trim(),
      recordingYear: parsedYear,
      recordingMonth: liveTrack.recordingMonth,
      recordingDay: liveTrack.recordingDay,
      recordingLocation: liveTrack.recordingLocation,
      durationMs: liveTrack.durationMs,
      isrc: normalize(_isrcController.text),
      iswc: normalize(_iswcController.text),
      musicbrainzId: liveTrack.musicbrainzId,
      spotifyId: liveTrack.spotifyId,
      ytmId: liveTrack.ytmId,
      artistName: normalize(_artistController.text),
      albumTitle: normalize(_albumController.text),
      format: liveTrack.format,
      sampleRate: liveTrack.sampleRate,
      bitDepth: liveTrack.bitDepth,
      verified: liveTrack.verified,
      genre: normalize(_genreController.text),
      trackNumber: parsedTrackNumber,
      discNumber: liveTrack.discNumber,
    );

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    FocusScope.of(context).unfocus();
    if (_artistFocusNode.hasFocus) _artistFocusNode.unfocus();
    if (_albumFocusNode.hasFocus) _albumFocusNode.unfocus();

    try {
      Track savedTrack = updatedTrack;
      const minFeedbackDuration = Duration(milliseconds: 350);
      if (widget.musicService != null) {
        final results = await Future.wait([
          widget.musicService!.updateTrack(updatedTrack),
          Future.delayed(minFeedbackDuration),
        ]);
        savedTrack = results.first as Track;
      } else {
        await Future.delayed(minFeedbackDuration);
      }

      if (!mounted || _track?.id != targetTrack.id) {
        return;
      }

      widget.onTrackUpdated?.call(savedTrack);

      FocusScope.of(context).unfocus();
      if (_artistFocusNode.hasFocus) _artistFocusNode.unfocus();
      if (_albumFocusNode.hasFocus) _albumFocusNode.unfocus();

      setState(() {
        _track = savedTrack;
        _validationErrors.clear();
        _saveErrorMessage = null;
        _isEditing = false;
      });
    } catch (e) {
      // If updating track or listener notification fails, do NOT pretend it succeeded.
      // Do NOT set _isEditing = false so user does not lose unsaved input.
      if (mounted && _track?.id == targetTrack.id) {
        setState(() {
          _saveErrorMessage = e.toString();
        });
      }
    } finally {
      if (mounted && _track?.id == targetTrack.id) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
      if (widget.asset?.isImage == true && _resolvedImageAsset == null) {
        setState(() {
          _resolvedImageAsset = ImageAsset(
            imageHash: widget.asset!.fileHash,
            fileHash: widget.asset!.fileHash,
            mimeType: widget.asset!.mimeType,
            fileSize: widget.asset!.fileSize,
          );
        });
      }
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (activePcmHash.isEmpty &&
        (explicitFileHash == null || explicitFileHash.isEmpty)) {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      List<Audio> versions = _audioVersions;
      Audio? resolvedAudio = _selectedAudio;
      SourceData? fetchedSource = _sourceData;
      Asset? fetchedAsset = _resolvedAsset;
      ImageAsset? fetchedImageAsset = _resolvedImageAsset;

      // Accelerated parallel pre-fetch: if explicit file hash is present upfront, fetch concurrently
      Future<Asset?>? explicitAssetFuture;
      Future<SourceData?>? explicitSourceFuture;
      Future<ImageAsset?>? explicitImageFuture;

      if (explicitFileHash != null && explicitFileHash.isNotEmpty) {
        if (fetchedAsset == null) {
          explicitAssetFuture = service
              .getAsset(explicitFileHash)
              .catchError((_) => null);
        }
        if (fetchedSource == null) {
          explicitSourceFuture = service
              .getSourceData(explicitFileHash)
              .catchError((_) => null);
        }
        if (fetchedImageAsset == null &&
            (widget.asset?.isImage == true || fetchedAsset?.isImage == true)) {
          explicitImageFuture = service
              .getImageAsset(explicitFileHash)
              .catchError((_) => null);
        }
      }

      // Tier 3: Fetch Audio versions via Single-Level Star Topology
      if (activePcmHash.isNotEmpty) {
        final fetchedVersions = await service
            .getAudioVersions(activePcmHash)
            .catchError((_) => <Audio>[]);
        if (fetchedVersions.isEmpty) {
          final single = await service
              .getAudioDetails(activePcmHash)
              .catchError((_) => null);
          if (single != null) {
            versions = [single];
          } else {
            versions = [];
          }
        } else {
          versions = fetchedVersions;
        }

        // Set inspected audio version: default to currently active version
        if (versions.isNotEmpty) {
          resolvedAudio = versions.firstWhere(
            (a) => a.pcmHash == activePcmHash,
            orElse: () => versions.first,
          );
        } else {
          resolvedAudio ??= await service
              .getAudioDetails(activePcmHash)
              .catchError((_) => null);
        }

        // Fast state update: update _audioVersions as soon as versions resolve to eliminate sequential waiting
        if (mounted && callId == _fetchDetailsCallId) {
          setState(() {
            _audioVersions = versions.isNotEmpty
                ? versions
                : (resolvedAudio != null ? [resolvedAudio] : []);
            _selectedAudio = resolvedAudio;
          });
        }
      }

      // Resolve physical file hash from selected Audio assets or parent Audio
      String? fileHash = explicitFileHash;
      if (fileHash == null || fileHash.isEmpty) {
        if (resolvedAudio != null && resolvedAudio.assets.isNotEmpty) {
          fileHash = resolvedAudio.assets.first.fileHash;
        } else if (resolvedAudio?.parentHash.isNotEmpty == true) {
          try {
            final parentAudio = await service.getAudioDetails(
              resolvedAudio!.parentHash,
            );
            if (parentAudio != null && parentAudio.assets.isNotEmpty) {
              fetchedAsset ??= parentAudio.assets.first;
              fileHash = parentAudio.assets.first.fileHash;
            }
          } catch (_) {}
        }
      }

      // Concurrently resolve downstream Asset, SourceData, and ImageAsset
      if (fileHash != null && fileHash.isNotEmpty) {
        if (fileHash == explicitFileHash) {
          if (explicitAssetFuture != null) {
            final a = await explicitAssetFuture;
            if (a != null) fetchedAsset = a;
          }
          if (explicitSourceFuture != null) {
            final s = await explicitSourceFuture;
            if (s != null) fetchedSource = s;
          }
          if (explicitImageFuture != null) {
            final img = await explicitImageFuture;
            if (img != null) fetchedImageAsset = img;
          }
        } else {
          final needAsset = fetchedAsset == null;
          final needSource = fetchedSource == null;
          final isImage =
              (fetchedAsset?.isImage == true) ||
              (widget.asset?.isImage == true);
          final needImage = isImage && fetchedImageAsset == null;

          final futures = <Future<void>>[];
          if (needAsset) {
            futures.add(
              service
                  .getAsset(fileHash)
                  .then((val) {
                    if (val != null) fetchedAsset = val;
                  })
                  .catchError((_) {}),
            );
          }
          if (needSource) {
            futures.add(
              service
                  .getSourceData(fileHash)
                  .then((val) {
                    if (val != null) fetchedSource = val;
                  })
                  .catchError((_) {}),
            );
          }
          if (needImage) {
            futures.add(
              service
                  .getImageAsset(fileHash)
                  .then((val) {
                    if (val != null) fetchedImageAsset = val;
                  })
                  .catchError((_) {}),
            );
          }
          if (futures.isNotEmpty) {
            await Future.wait(futures);
          }
        }
      }

      if (fetchedImageAsset == null &&
          (fetchedAsset?.isImage == true || widget.asset?.isImage == true)) {
        final a = fetchedAsset ?? widget.asset!;
        fetchedImageAsset = ImageAsset(
          imageHash: a.fileHash,
          fileHash: a.fileHash,
          mimeType: a.mimeType,
          fileSize: a.fileSize,
        );
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
        _resolvedImageAsset = fetchedImageAsset;
        _sourceData = fetchedSource;
        _isLoading = false;
      });
      _loadWaveform();
    } catch (_) {
      if (!mounted || callId != _fetchDetailsCallId) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectVersion(Audio version) async {
    if (_selectedAudio?.pcmHash == version.pcmHash) return;

    final callId = ++_selectVersionCallId;
    ++_fetchDetailsCallId;
    final currentTrackId = _track?.id;

    setState(() {
      _selectedAudio = version;
      _isLoading = true;
    });
    _loadWaveform();

    final service = widget.musicService;
    String? fileHash;
    Asset? asset = version.assets.isNotEmpty ? version.assets.first : null;
    SourceData? sourceData;

    if (asset != null) {
      fileHash = asset.fileHash;
    } else if (version.parentHash.isNotEmpty && service != null) {
      try {
        final parentAudio = await service.getAudioDetails(version.parentHash);
        if (parentAudio != null && parentAudio.assets.isNotEmpty) {
          asset = parentAudio.assets.first;
          fileHash = asset.fileHash;
        }
      } catch (_) {}
    }

    if (service != null && fileHash != null && fileHash.isNotEmpty) {
      try {
        final results = await Future.wait([
          if (asset != null)
            Future.value(asset)
          else
            service.getAsset(fileHash).catchError((_) => null),
          service.getSourceData(fileHash).catchError((_) => null),
        ]);
        if (results[0] != null) asset = results[0] as Asset;
        sourceData = results[1] as SourceData?;
      } catch (_) {}
    }

    if (!mounted ||
        callId != _selectVersionCallId ||
        _track?.id != currentTrackId) {
      return;
    }

    setState(() {
      _resolvedAsset = asset;
      _sourceData = sourceData;
      _isLoading = false;
    });
  }

  Future<void> _handleSetActiveAudio() async {
    if (_isSwitchingActive) return;
    if (_track == null || _selectedAudio == null) return;
    final trackId = _track!.id;
    final newPcmHash = _selectedAudio!.pcmHash;

    setState(() {
      _isSwitchingActive = true;
    });

    try {
      await widget.musicService?.switchTrackAudio(trackId, newPcmHash);
      if (!mounted || _track?.id != trackId) return;
      widget.onActiveAudioChanged?.call(newPcmHash);

      setState(() {
        _track = _track!.copyWith(
          pcmHash: newPcmHash,
          bitDepth: _selectedAudio!.bitDepth,
          sampleRate: _selectedAudio!.sampleRate,
        );
      });
    } catch (_) {
    } finally {
      if (mounted && _track?.id == trackId) {
        setState(() {
          _isSwitchingActive = false;
        });
      }
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

    final effectiveAsset = _resolvedAsset ?? widget.asset;
    final isImageAsset = _track == null && (effectiveAsset?.isImage == true);

    if (isImageAsset) {
      return SingleChildScrollView(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Surface (Hero Artwork & Lightbox Expand)
            _ImagePreviewSurface(
              asset: effectiveAsset!,
              imageAsset: _resolvedImageAsset,
              tokens: tokens,
            ),
            _buildSectionDivider(tokens),

            // Image Specifications (Tier 3 Image Metadata)
            _buildImageSpecificationsSection(tokens),
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

    final showAudioVersions = _audioVersions.isNotEmpty;
    final hasAudioEntity =
        (_track != null && _track!.pcmHash.isNotEmpty) ||
        _currentActivePcmHash.isNotEmpty;
    final showAudioVersionsSkeleton =
        hasAudioEntity && !isImageAsset && _audioVersions.isEmpty && _isLoading;

    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entity Overview (Track / Asset Summary) or Edit Form with smooth geometric & opacity transition
          if ((_isEditing && _track != null) || hasEntitySummary) ...[
            SizedBox(
              width: double.infinity,
              child: AnimatedSize(
                key: const Key('inspector_edit_mode_animated_size'),
                duration: LyraAnimation.normal,
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: AnimatedSwitcher(
                  key: const Key('inspector_edit_mode_animated_switcher'),
                  duration: LyraAnimation.normal,
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            ...previousChildren.map(
                              (w) => Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(child: w),
                              ),
                            ),
                            currentChild ?? const SizedBox.shrink(),
                          ],
                        );
                      },
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.02),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                  child: (_isEditing && _track != null)
                      ? KeyedSubtree(
                          key: const ValueKey<String>(
                            'inspector_edit_metadata_form',
                          ),
                          child: FocusScope(
                            canRequestFocus: !_isSaving,
                            child: _buildEditMetadataForm(tokens),
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey<String>(
                            'inspector_entity_summary_section',
                          ),
                          child: _buildEntitySummarySection(tokens),
                        ),
                ),
              ),
            ),
            _buildSectionDivider(tokens),
          ],

          // Audio Version Selector (Star Topology) with loading stability & smooth geometric transition
          AnimatedSize(
            key: const Key('audio_versions_animated_size'),
            duration: LyraAnimation.fast,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: showAudioVersions
                ? Column(
                    key: const Key('audio_versions_column'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAudioVersionSection(tokens),
                      _buildSectionDivider(tokens),
                    ],
                  )
                : showAudioVersionsSkeleton
                ? Column(
                    key: const Key('audio_versions_skeleton_column'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAudioVersionSkeleton(tokens),
                      _buildSectionDivider(tokens),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

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
        if (_saveErrorMessage != null) ...[
          const SizedBox(height: LyraSpacing.xs),
          Container(
            key: const Key('inspector_save_error_banner'),
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.sm,
              vertical: LyraSpacing.xs + 2.0,
            ),
            decoration: BoxDecoration(
              color: tokens.destructive.withValues(alpha: 0.1),
              borderRadius: LyraRadius.smRadius,
              border: Border.all(
                color: tokens.destructive.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.alertCircle,
                  size: 15.0,
                  color: tokens.destructive,
                ),
                const SizedBox(width: LyraSpacing.xs),
                Expanded(
                  child: Text(
                    _saveErrorMessage!,
                    style: LyraTypography.small(tokens).copyWith(
                      color: tokens.destructive,
                      fontWeight: FontWeight.w500,
                      fontSize: 11.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        Container(
          decoration: _validationErrors.containsKey('title')
              ? BoxDecoration(
                  borderRadius: LyraRadius.smRadius,
                  border: Border.all(color: tokens.destructive, width: 1.5),
                )
              : null,
          child: LyraInput(
            key: const Key('inspector_edit_title_input'),
            controller: _titleController,
            placeholder: 'Track Title',
            onChanged: (_) => _clearFieldError('title'),
          ),
        ),
        if (_validationErrors.containsKey('title')) ...[
          const SizedBox(height: 4.0),
          Text(
            _validationErrors['title']!,
            key: const Key('inspector_edit_title_error'),
            style: LyraTypography.small(tokens).copyWith(
              color: tokens.destructive,
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
                onPressed: (_isSaving || _isConfirming) ? null : _cancelEditing,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: LyraSpacing.sm),
            Expanded(
              child: LyraButton.primary(
                key: const Key('inspector_save_button'),
                size: LyraButtonSize.sm,
                onPressed: (_isSaving || _isConfirming) ? null : _saveEditing,
                leading: (_isSaving || _isConfirming)
                    ? LyraSpinner(size: 14.0)
                    : null,
                child: Text(
                  (_isSaving || _isConfirming) ? 'Saving...' : 'Save',
                ),
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

  Widget _buildAudioVersionSkeleton(LyraThemeTokens tokens) {
    return Column(
      key: const Key('audio_versions_skeleton'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: LyraSpacing.sm),
          child: Row(
            children: [
              LyraSkeleton(
                width: 15.0,
                height: 15.0,
                borderRadius: LyraRadius.smRadius,
              ),
              const SizedBox(width: LyraSpacing.xs),
              LyraSkeleton(
                width: 100.0,
                height: 13.0,
                borderRadius: LyraRadius.smRadius,
              ),
            ],
          ),
        ),
        LyraSkeleton(
          key: const Key('audio_version_card_skeleton'),
          width: double.infinity,
          height: 48.0,
          borderRadius: LyraRadius.smRadius,
        ),
      ],
    );
  }

  Widget _buildAudioVersionSection(LyraThemeTokens tokens) {
    final activePcmHash = _currentActivePcmHash;
    final isInspectingActive = _selectedAudio?.pcmHash == activePcmHash;

    return Column(
      key: const Key('audio_versions_section'),
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
              cursor: _isSwitchingActive
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isSwitchingActive ? null : () => _selectVersion(v),
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
                                            color: tokens.secondaryForeground,
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
              leading: _isSwitchingActive ? LyraSpinner(size: 14.0) : null,
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

    final currentPlaying = widget.playbackController?.currentTrack;
    final bool isPlayingThis =
        (currentPlaying != null &&
            track != null &&
            currentPlaying.id == track.id) ||
        (pcmHash.isNotEmpty && currentPlaying?.pcmHash == pcmHash);

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
              ? LyraSpinner(size: 14.0, color: tokens.textMuted)
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
        if (widget.preferencesService?.showInspectorWaveform ?? true) ...[
          const SizedBox(height: LyraSpacing.md),
          Container(
            padding: const EdgeInsets.all(LyraSpacing.sm),
            decoration: BoxDecoration(
              color: tokens.secondary.withValues(alpha: 0.4),
              borderRadius: LyraRadius.mdRadius,
              border: Border.all(color: tokens.border, width: 1.0),
            ),
            child: WaveformScrubber(
              waveform: _waveform,
              playbackController: isPlayingThis
                  ? widget.playbackController
                  : null,
              position: isPlayingThis ? null : Duration.zero,
              duration: isPlayingThis
                  ? null
                  : (track?.duration ?? (audio?.duration ?? Duration.zero)),
              height: 56.0,
              isInteractive: isPlayingThis,
              enablePulseAnimation:
                  widget.preferencesService?.inspectorWaveformPulseAnimation ??
                  true,
              enableHoverTimeGuide:
                  widget.preferencesService?.inspectorWaveformHoverTimeGuide ??
                  true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDominantColorRow(String? hexColor, LyraThemeTokens tokens) {
    if (hexColor == null || hexColor.isEmpty) {
      return Text('—', style: LyraTypography.muted(tokens));
    }

    Color? parsedColor;
    final cleanHex = hexColor.replaceFirst('#', '').trim();
    final val = int.tryParse(
      cleanHex.length == 6
          ? 'FF$cleanHex'
          : (cleanHex.length == 8 ? cleanHex : ''),
      radix: 16,
    );
    if (val != null) parsedColor = Color(val);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LyraTooltip(
          message: 'Copy hex $hexColor',
          child: GestureDetector(
            key: const Key('dominant_color_swatch'),
            onTap: () => Clipboard.setData(ClipboardData(text: hexColor)),
            child: Container(
              width: 20.0,
              height: 20.0,
              decoration: BoxDecoration(
                color: parsedColor ?? tokens.muted,
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: tokens.border, width: 1.0),
              ),
            ),
          ),
        ),
        const SizedBox(width: LyraSpacing.sm),
        Text(
          hexColor,
          style: LyraTypography.mono(
            tokens,
            fontSize: 12.0,
          ).copyWith(fontWeight: FontWeight.w600, color: tokens.text),
        ),
        const SizedBox(width: LyraSpacing.xs),
        LyraCopyButton.icon(
          text: hexColor,
          tooltip: 'Copy hex color',
          copiedTooltip: 'Copied hex color',
          size: 24.0,
        ),
      ],
    );
  }

  Widget _buildImageSpecificationsSection(LyraThemeTokens tokens) {
    final image = _resolvedImageAsset;
    final dimensionsText = image != null && image.width > 0 && image.height > 0
        ? '${image.width} × ${image.height} px (${image.megapixels})'
        : '—';

    final aspectRatioText = image?.formattedAspectRatio ?? '—';
    final colorFormatText = image?.displayColorFormat ?? '24-bit RGB';
    final roleText = _formatRoleLabel(image?.role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: LucideIcons.sliders,
          title: 'Image Specifications',
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Dimensions',
          value: dimensionsText,
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Aspect Ratio',
          value: aspectRatioText,
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Color Depth',
          value: colorFormatText,
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Dominant Color',
          value: image?.dominantColor ?? '—',
          customValue: _buildDominantColorRow(image?.dominantColor, tokens),
          tokens: tokens,
        ),
        _buildPropertyRow(
          label: 'Role',
          value: roleText,
          customValue: LyraBadge.secondary(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            child: Text(
              roleText,
              style: LyraTypography.small(
                tokens,
              ).copyWith(fontSize: 11.0, fontWeight: FontWeight.w600),
            ),
          ),
          tokens: tokens,
        ),
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
              ? '${createdAt.toUtc().toIso8601String().replaceAll('T', ' ').substring(0, 19)} UTC'
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

class _MetadataDiffDialog extends StatefulWidget {
  final List<_FieldDiff> diffs;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _MetadataDiffDialog({
    required this.diffs,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_MetadataDiffDialog> createState() => _MetadataDiffDialogState();
}

class _MetadataDiffDialogState extends State<_MetadataDiffDialog> {
  bool _popped = false;

  void _handleConfirm() {
    if (_popped) return;
    setState(() {
      _popped = true;
    });
    widget.onConfirm();
  }

  void _handleCancel() {
    if (_popped) return;
    setState(() {
      _popped = true;
    });
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Center(
      key: const Key('metadata_diff_dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540.0),
        child: LyraDialog(
          onClose: _handleCancel,
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
            widget.diffs.isEmpty
                ? 'No fields have been modified.'
                : 'Review the ${widget.diffs.length} modified ${widget.diffs.length == 1 ? "field" : "fields"} before applying changes to the database.',
            style: LyraTypography.muted(tokens),
          ),
          actions: [
            LyraButton.outline(
              key: const Key('diff_dialog_cancel_button'),
              size: LyraButtonSize.sm,
              onPressed: _popped ? null : _handleCancel,
              child: const Text('Cancel'),
            ),
            LyraButton.primary(
              key: const Key('diff_dialog_confirm_button'),
              size: LyraButtonSize.sm,
              onPressed: _popped ? null : _handleConfirm,
              leading: _popped ? LyraSpinner(size: 14.0) : null,
              child: const Text('Confirm & Save'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.diffs.isEmpty)
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
                      children: widget.diffs.map((diff) {
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

IconData _getRoleIcon(String? role) {
  switch (role?.toLowerCase()) {
    case 'front':
    case 'front_cover':
    case 'cover':
      return LucideIcons.disc;
    case 'back':
    case 'back_cover':
    case 'liner_notes':
    case 'booklet':
      return LucideIcons.bookOpen;
    case 'artist':
    case 'artist_avatar':
    case 'band':
      return LucideIcons.user;
    case 'icon':
    case 'logo':
      return LucideIcons.sparkles;
    case 'illustration':
      return LucideIcons.palette;
    default:
      return LucideIcons.image;
  }
}

String _formatRoleLabel(String? role) {
  if (role == null || role.isEmpty) return 'Artwork';
  switch (role.toLowerCase()) {
    case 'front':
    case 'front_cover':
    case 'cover':
      return 'Front Cover';
    case 'back':
    case 'back_cover':
      return 'Back Cover';
    case 'liner_notes':
    case 'booklet':
      return 'Booklet';
    case 'artist':
    case 'artist_avatar':
    case 'band':
      return 'Artist';
    case 'icon':
    case 'logo':
      return 'Logo';
    case 'illustration':
      return 'Illustration';
    default:
      return role
          .split(RegExp(r'[_\s]+'))
          .where((part) => part.isNotEmpty)
          .map(
            (part) => part[0].toUpperCase() + part.substring(1).toLowerCase(),
          )
          .join(' ');
  }
}

class _SubtleGridPainter extends CustomPainter {
  final Color gridColor;
  static const double cellSize = 16.0;

  const _SubtleGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.clipRect(Offset.zero & size);

    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.fill;

    final numX = (size.width / cellSize).ceil();
    final numY = (size.height / cellSize).ceil();

    for (int i = 0; i < numX; i++) {
      for (int j = 0; j < numY; j++) {
        if ((i + j) % 2 == 0) {
          final w = math.max(
            0.0,
            math.min(cellSize, size.width - i * cellSize),
          );
          final h = math.max(
            0.0,
            math.min(cellSize, size.height - j * cellSize),
          );
          if (w > 0 && h > 0) {
            canvas.drawRect(
              Rect.fromLTWH(i * cellSize, j * cellSize, w, h),
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleGridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor;
}

Widget _buildArtworkGraphic(
  Asset asset,
  ImageAsset? imageAsset,
  LyraThemeTokens tokens, {
  bool isHero = false,
}) {
  Color? dominantColor;
  final hex = imageAsset?.dominantColor;
  if (hex != null) {
    final cleanHex = hex.replaceFirst('#', '').trim();
    final val = int.tryParse(
      cleanHex.length == 6
          ? 'FF$cleanHex'
          : (cleanHex.length == 8 ? cleanHex : ''),
      radix: 16,
    );
    if (val != null) dominantColor = Color(val);
  }

  final icon = _getRoleIcon(imageAsset?.role);
  final iconSize = isHero ? 56.0 : 36.0;
  final roleText = _formatRoleLabel(imageAsset?.role);

  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          (dominantColor ?? tokens.primary).withValues(alpha: 0.20),
          (dominantColor ?? tokens.secondary).withValues(alpha: 0.08),
        ],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isHero ? LyraSpacing.md : LyraSpacing.sm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.card.withValues(alpha: 0.75),
              border: Border.all(
                color: (dominantColor ?? tokens.border).withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: dominantColor ?? tokens.primary,
            ),
          ),
          const SizedBox(height: LyraSpacing.xs),
          Text(
            roleText,
            style: LyraTypography.small(tokens).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: isHero ? 13.0 : 11.5,
              color: tokens.text,
            ),
          ),
          if (imageAsset != null &&
              imageAsset.width > 0 &&
              imageAsset.height > 0) ...[
            const SizedBox(height: 2.0),
            Text(
              '${imageAsset.width} × ${imageAsset.height}',
              style: LyraTypography.mono(
                tokens,
                fontSize: isHero ? 11.0 : 10.0,
              ).copyWith(color: tokens.textMuted),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ImagePreviewSurface extends StatelessWidget {
  final Asset asset;
  final ImageAsset? imageAsset;
  final LyraThemeTokens tokens;

  const _ImagePreviewSurface({
    required this.asset,
    required this.imageAsset,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final aspectRatio =
        (imageAsset != null && imageAsset!.width > 0 && imageAsset!.height > 0)
        ? (imageAsset!.width / imageAsset!.height).clamp(0.75, 1.77)
        : 1.0;

    return Container(
      key: const Key('image_preview_surface'),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: LyraRadius.mdRadius,
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240.0, minHeight: 160.0),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _SubtleGridPainter(
                  gridColor: tokens.border.withValues(alpha: 0.25),
                ),
              ),
              _buildArtworkGraphic(asset, imageAsset, tokens),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('image_preview_inkwell'),
                    borderRadius: LyraRadius.mdRadius,
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: 'Dismiss',
                        builder: (dialogCtx) => LyraDesignSystemScope(
                          factory: LyraDesignSystemScope.of(context).factory,
                          tokens: LyraDesignSystemScope.of(context).tokens,
                          themeModeNotifier: LyraDesignSystemScope.of(
                            context,
                          ).themeModeNotifier,
                          child: _ImageLightboxDialog(
                            asset: asset,
                            imageAsset: imageAsset,
                            tokens: tokens,
                          ),
                        ),
                      );
                    },
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(LyraSpacing.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.card.withValues(alpha: 0.85),
                            borderRadius: LyraRadius.smRadius,
                            border: Border.all(color: tokens.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.maximize2,
                                size: 12.0,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                'Expand',
                                style: LyraTypography.small(tokens).copyWith(
                                  fontSize: 11.0,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class _ImageLightboxDialog extends StatefulWidget {
  final Asset asset;
  final ImageAsset? imageAsset;
  final LyraThemeTokens tokens;

  const _ImageLightboxDialog({
    required this.asset,
    required this.imageAsset,
    required this.tokens,
  });

  @override
  State<_ImageLightboxDialog> createState() => _ImageLightboxDialogState();
}

class _ImageLightboxDialogState extends State<_ImageLightboxDialog> {
  late final TransformationController _transformationController;
  final GlobalKey _viewerKey = GlobalKey();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  double _getScale() {
    final s = _transformationController.value.storage;
    return math.sqrt(s[0] * s[0] + s[1] * s[1]);
  }

  void _onTransformationChanged() {
    if (!mounted) return;
    final scale = _getScale();
    final clamped = scale.clamp(0.25, 8.0);
    if ((_currentScale - clamped).abs() > 0.001) {
      setState(() {
        _currentScale = clamped;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _setScale(double targetScale) {
    final target = targetScale.clamp(0.25, 8.0);
    final current = _getScale();
    if ((current - target).abs() < 0.001) return;

    final renderBox =
        _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.hasSize == true ? renderBox!.size : null;
    if (size != null && size.width > 0 && size.height > 0) {
      final cx = size.width / 2.0;
      final cy = size.height / 2.0;
      final tx = _transformationController.value.storage[12];
      final ty = _transformationController.value.storage[13];
      if (current > 0) {
        final childX = (cx - tx) / current;
        final childY = (cy - ty) / current;
        final newTx = cx - childX * target;
        final newTy = cy - childY * target;
        _transformationController.value = Matrix4.identity()
          ..translateByDouble(newTx, newTy, 0.0, 1.0)
          ..scaleByDouble(target, target, target, 1.0);
      } else {
        _transformationController.value = Matrix4.identity()
          ..translateByDouble(cx, cy, 0.0, 1.0)
          ..scaleByDouble(target, target, target, 1.0)
          ..translateByDouble(-cx, -cy, 0.0, 1.0);
      }
    } else {
      _transformationController.value = Matrix4.diagonal3Values(
        target,
        target,
        target,
      );
    }
  }

  void _zoomIn() {
    final next = (_currentScale + 0.25).clamp(0.25, 8.0);
    _setScale(next);
  }

  void _zoomOut() {
    final next = (_currentScale - 0.25).clamp(0.25, 8.0);
    _setScale(next);
  }

  PopupMenuItem<double> _buildPopupMenuItem(
    LyraThemeTokens tokens,
    String label,
    double value,
  ) {
    final isSelected = value < 0
        ? (_currentScale - 1.0).abs() < 0.05
        : (_currentScale - value).abs() < 0.05;

    return PopupMenuItem<double>(
      value: value,
      height: 36.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: LyraTypography.small(tokens).copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? tokens.primary : tokens.text,
            ),
          ),
          if (isSelected)
            Icon(LucideIcons.check, size: 14.0, color: tokens.primary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 48.0).clamp(280.0, 720.0);
    final dialogHeight = (size.height - 48.0).clamp(280.0, 560.0);

    return Center(
      key: const Key('image_lightbox_dialog'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: LyraRadius.lgRadius,
              border: Border.all(color: tokens.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24.0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Header
                Container(
                  height: 48.0,
                  padding: const EdgeInsets.only(
                    left: LyraSpacing.md,
                    right: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.muted.withValues(alpha: 0.4),
                    border: Border(bottom: BorderSide(color: tokens.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getRoleIcon(widget.imageAsset?.role),
                              size: 16.0,
                              color: tokens.primary,
                            ),
                            const SizedBox(width: LyraSpacing.sm),
                            Flexible(
                              child: Text(
                                _formatRoleLabel(widget.imageAsset?.role),
                                overflow: TextOverflow.ellipsis,
                                style: LyraTypography.small(tokens).copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: tokens.text,
                                ),
                              ),
                            ),
                            if (widget.imageAsset != null &&
                                widget.imageAsset!.width > 0) ...[
                              const SizedBox(width: LyraSpacing.sm),
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  '${widget.imageAsset!.width} × ${widget.imageAsset!.height} px',
                                  overflow: TextOverflow.ellipsis,
                                  style: LyraTypography.small(tokens).copyWith(
                                    color: tokens.textMuted,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: LyraSpacing.sm),
                      LyraButton.ghost(
                        key: const Key('lightbox_close_button'),
                        size: LyraButtonSize.sm,
                        width: 32.0,
                        height: 32.0,
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(LucideIcons.x, size: 16.0),
                      ),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _SubtleGridPainter(
                          gridColor: tokens.border.withValues(alpha: 0.25),
                        ),
                      ),
                      InteractiveViewer(
                        key: _viewerKey,
                        transformationController: _transformationController,
                        boundaryMargin: const EdgeInsets.all(1600.0),
                        minScale: 0.25,
                        maxScale: 8.0,
                        child: Center(
                          child: _buildArtworkGraphic(
                            widget.asset,
                            widget.imageAsset,
                            tokens,
                            isHero: true,
                          ),
                        ),
                      ),
                      // Floating Zoom Toolbar
                      Positioned(
                        bottom: 16.0,
                        left: 16.0,
                        right: 16.0,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              height: 40.0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 6.0,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.card.withValues(alpha: 0.94),
                                borderRadius: LyraRadius.mdRadius,
                                border: Border.all(color: tokens.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 12.0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Fit button
                                  LyraButton.outline(
                                    key: const Key('lightbox_fit_button'),
                                    size: LyraButtonSize.sm,
                                    height: 28.0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0,
                                    ),
                                    onPressed: _resetZoom,
                                    child: const Text('Fit'),
                                  ),
                                  const SizedBox(width: 6.0),
                                  // Zoom-out button
                                  LyraButton.ghost(
                                    key: const Key('lightbox_zoom_out'),
                                    size: LyraButtonSize.sm,
                                    width: 28.0,
                                    height: 28.0,
                                    padding: EdgeInsets.zero,
                                    onPressed: _currentScale > 0.25
                                        ? _zoomOut
                                        : null,
                                    child: Icon(
                                      LucideIcons.zoomOut,
                                      size: 16.0,
                                      color: _currentScale > 0.25
                                          ? tokens.text
                                          : tokens.textMuted.withValues(
                                              alpha: 0.4,
                                            ),
                                    ),
                                  ),
                                  // Slider
                                  SizedBox(
                                    width: 120.0,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3.0,
                                        activeTrackColor: tokens.primary,
                                        inactiveTrackColor: tokens.muted
                                            .withValues(alpha: 0.6),
                                        thumbColor: tokens.textMuted,
                                        overlayColor: tokens.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6.0,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 12.0,
                                            ),
                                      ),
                                      child: Slider(
                                        key: const Key('lightbox_zoom_slider'),
                                        value: _currentScale.clamp(0.25, 8.0),
                                        min: 0.25,
                                        max: 8.0,
                                        onChanged: _setScale,
                                      ),
                                    ),
                                  ),
                                  // Zoom-in button
                                  LyraButton.ghost(
                                    key: const Key('lightbox_zoom_in'),
                                    size: LyraButtonSize.sm,
                                    width: 28.0,
                                    height: 28.0,
                                    padding: EdgeInsets.zero,
                                    onPressed: _currentScale < 8.0
                                        ? _zoomIn
                                        : null,
                                    child: Icon(
                                      LucideIcons.zoomIn,
                                      size: 16.0,
                                      color: _currentScale < 8.0
                                          ? tokens.text
                                          : tokens.textMuted.withValues(
                                              alpha: 0.4,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  // Zoom percentage selector
                                  PopupMenuButton<double>(
                                    key: const Key(
                                      'lightbox_zoom_percentage_button',
                                    ),
                                    tooltip: 'Preset Zoom Levels',
                                    color: tokens.card,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: LyraRadius.mdRadius,
                                      side: BorderSide(color: tokens.border),
                                    ),
                                    onSelected: (val) {
                                      if (val < 0) {
                                        _resetZoom();
                                      } else {
                                        _setScale(val);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      _buildPopupMenuItem(tokens, 'Fit', -1.0),
                                      _buildPopupMenuItem(tokens, '25%', 0.25),
                                      _buildPopupMenuItem(tokens, '50%', 0.50),
                                      _buildPopupMenuItem(
                                        tokens,
                                        '100% (1×)',
                                        1.0,
                                      ),
                                      _buildPopupMenuItem(
                                        tokens,
                                        '200% (2×)',
                                        2.0,
                                      ),
                                      _buildPopupMenuItem(
                                        tokens,
                                        '400% (4×)',
                                        4.0,
                                      ),
                                      _buildPopupMenuItem(
                                        tokens,
                                        '800% (8×)',
                                        8.0,
                                      ),
                                    ],
                                    child: Container(
                                      height: 28.0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.card,
                                        borderRadius: LyraRadius.smRadius,
                                        border: Border.all(
                                          color: tokens.border,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${(_currentScale * 100).round()}%',
                                            key: const Key(
                                              'lightbox_zoom_percentage_text',
                                            ),
                                            style: LyraTypography.small(tokens)
                                                .copyWith(
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w600,
                                                  color: tokens.text,
                                                ),
                                          ),
                                          const SizedBox(width: 4.0),
                                          Icon(
                                            LucideIcons.chevronDown,
                                            size: 13.0,
                                            color: tokens.textMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
  }
}
