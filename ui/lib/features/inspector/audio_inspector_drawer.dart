// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../models/asset.dart';
import '../models/audio.dart';
import '../models/source_data.dart';
import '../models/track.dart';
import '../services/music_service.dart';

/// Audio entity-centric property inspector drawer displaying deep acoustic specifications,
/// Single-Level Star Topology audio versions, CAS storage properties, and digital provenance.
class AudioInspectorDrawer extends StatefulWidget {
  final Track? track;
  final Asset? asset;
  final Audio? initialAudio;
  final SourceData? initialSourceData;
  final MusicService? musicService;
  final VoidCallback onClose;
  final Future<bool> Function(String hash)? onVerifyIntegrity;
  final void Function(String newPcmHash)? onActiveAudioChanged;
  final double width;

  const AudioInspectorDrawer({
    super.key,
    this.track,
    this.asset,
    this.initialAudio,
    this.initialSourceData,
    this.musicService,
    required this.onClose,
    this.onVerifyIntegrity,
    this.onActiveAudioChanged,
    this.width = 420.0,
  });

  @override
  State<AudioInspectorDrawer> createState() => _AudioInspectorDrawerState();
}

class _AudioInspectorDrawerState extends State<AudioInspectorDrawer> {
  Track? _track;
  List<Audio> _audioVersions = [];
  Audio? _selectedAudio;
  SourceData? _sourceData;
  Asset? _resolvedAsset;
  bool _isLoading = false;
  bool _isSwitchingActive = false;
  bool _isVerifying = false;
  bool? _verificationResult;
  String? _copiedField;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    _track = widget.track;
    _selectedAudio = widget.initialAudio;
    _sourceData = widget.initialSourceData;
    _resolvedAsset = widget.asset;
    _fetchDetails();
  }

  @override
  void didUpdateWidget(covariant AudioInspectorDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track?.id != widget.track?.id ||
        oldWidget.track?.pcmHash != widget.track?.pcmHash ||
        oldWidget.asset?.fileHash != widget.asset?.fileHash ||
        oldWidget.initialAudio != widget.initialAudio ||
        oldWidget.initialSourceData != widget.initialSourceData) {
      _track = widget.track;
      _selectedAudio = widget.initialAudio;
      _sourceData = widget.initialSourceData;
      _resolvedAsset = widget.asset;
      _verificationResult = null;
      _fetchDetails();
    }
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  String get _currentActivePcmHash =>
      _track?.pcmHash ?? widget.initialAudio?.pcmHash ?? '';

  Future<void> _fetchDetails() async {
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

      if (!mounted) return;

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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectVersion(Audio version) async {
    if (_selectedAudio?.pcmHash == version.pcmHash) return;

    setState(() {
      _selectedAudio = version;
      _verificationResult = null;
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

  Future<void> _handleVerifyIntegrity() async {
    final fileHash =
        _resolvedAsset?.fileHash ??
        widget.asset?.fileHash ??
        (_selectedAudio != null && _selectedAudio!.assets.isNotEmpty
            ? _selectedAudio!.assets.first.fileHash
            : null);

    if (fileHash == null || fileHash.isEmpty) return;

    setState(() {
      _isVerifying = true;
    });

    bool verified = false;
    try {
      if (widget.onVerifyIntegrity != null) {
        verified = await widget.onVerifyIntegrity!(fileHash);
      } else if (widget.musicService != null) {
        verified = await widget.musicService!.verifyCasHash(fileHash);
      }
    } catch (_) {
      verified = false;
    }

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _verificationResult = verified;
    });
  }

  void _copyToClipboard(String text, String fieldIdentifier) {
    Clipboard.setData(ClipboardData(text: text));
    _copyResetTimer?.cancel();
    setState(() {
      _copiedField = fieldIdentifier;
    });
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copiedField = null;
        });
      }
    });
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
      return Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border(left: BorderSide(color: tokens.border, width: 1.0)),
        ),
        child: Column(
          children: [
            _buildDrawerHeader(tokens),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(LyraSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.fileSearch,
                        size: 48.0,
                        color: tokens.textMuted,
                      ),
                      const SizedBox(height: LyraSpacing.md),
                      Text(
                        'No Entity Selected',
                        style: LyraTypography.h3(tokens),
                      ),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        'Select a track or CAS storage object to inspect acoustic specifications and digital notarization records.',
                        style: LyraTypography.muted(tokens),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(left: BorderSide(color: tokens.border, width: 1.0)),
      ),
      child: Column(
        children: [
          // Drawer Header
          _buildDrawerHeader(tokens),

          // Scrollable Content Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LyraSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Entity Overview (Track / Asset Summary)
                  _buildEntitySummaryCard(tokens),

                  // Audio Version Selector (Star Topology)
                  if (_audioVersions.isNotEmpty) ...[
                    const SizedBox(height: LyraSpacing.md),
                    _buildAudioVersionSelector(tokens),
                  ],

                  const SizedBox(height: LyraSpacing.md),

                  // Section 1: Acoustic Specifications (Audio - Tier 3)
                  _buildAcousticSpecificationsCard(tokens),

                  const SizedBox(height: LyraSpacing.md),

                  // Section 2: Content Addressable Storage (CAS Asset Reference - Tier 4)
                  _buildCasAssetCard(tokens),

                  const SizedBox(height: LyraSpacing.md),

                  // Section 3: Digital Provenance & Notarization (SourceData - Tier 4)
                  _buildProvenanceCard(tokens),

                  const SizedBox(height: LyraSpacing.lg),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.md),
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
            onPressed: widget.onClose,
            child: Icon(LucideIcons.x, size: 16.0, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEntitySummaryCard(LyraThemeTokens tokens) {
    final track = _track;
    final asset = _resolvedAsset ?? widget.asset;

    if (track != null) {
      return LyraCard(
        padding: const EdgeInsets.all(LyraSpacing.md),
        child: Column(
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
              ],
            ),
            const SizedBox(height: LyraSpacing.xs),
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
        ),
      );
    }

    if (asset != null) {
      return LyraCard(
        padding: const EdgeInsets.all(LyraSpacing.md),
        child: Column(
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
                        'CAS Physical File Blob',
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
            const SizedBox(height: LyraSpacing.xs),
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
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAudioVersionSelector(LyraThemeTokens tokens) {
    final activePcmHash = _currentActivePcmHash;
    final isInspectingActive = _selectedAudio?.pcmHash == activePcmHash;

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.layers, size: 15.0, color: tokens.primary),
              const SizedBox(width: LyraSpacing.xs),
              Expanded(
                child: Text(
                  'Audio Versions',
                  style: LyraTypography.small(tokens).copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.textMuted,
                    fontSize: 13.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              LyraBadge.outline(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                child: Text(
                  '${_audioVersions.length} ${_audioVersions.length == 1 ? "version" : "versions"}',
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(fontSize: 11.0, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.sm),
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
                      color: isInspected ? tokens.secondary : tokens.card,
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
                          color: isInspected
                              ? tokens.primary
                              : tokens.textMuted,
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
                                            color: isInspected
                                                ? tokens.text
                                                : tokens.text,
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
      ),
    );
  }

  Widget _buildAcousticSpecificationsCard(LyraThemeTokens tokens) {
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

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.activity, size: 15.0, color: tokens.primary),
              const SizedBox(width: LyraSpacing.xs),
              Expanded(
                child: Text(
                  'Acoustic Specifications',
                  style: LyraTypography.small(tokens).copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.textMuted,
                    fontSize: 13.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 14.0,
                  height: 14.0,
                  child: Center(child: Icon(LucideIcons.loader2, size: 14.0)),
                ),
            ],
          ),
          const SizedBox(height: LyraSpacing.sm),
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
              label: 'Decoded PCM Stream Hash',
              hash: pcmHash,
              fieldId: 'pcm_hash',
              tokens: tokens,
            ),
          ] else ...[
            _buildPropertyRow(
              label: 'Decoded PCM Stream Hash',
              value: '—',
              subtitle: 'Not available',
              tokens: tokens,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCasAssetCard(LyraThemeTokens tokens) {
    final asset = _resolvedAsset ?? widget.asset;
    final fileHash =
        asset?.fileHash ??
        (_selectedAudio != null && _selectedAudio!.assets.isNotEmpty
            ? _selectedAudio!.assets.first.fileHash
            : '');

    final hasAsset = asset != null;

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.database, size: 15.0, color: tokens.primary),
              const SizedBox(width: LyraSpacing.xs),
              Expanded(
                child: Text(
                  'Storage & File Container',
                  style: LyraTypography.small(tokens).copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.textMuted,
                    fontSize: 13.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.sm),
          _buildPropertyRow(
            label: 'File Size',
            value: hasAsset && asset.fileSize > 0 ? asset.formattedSize : '—',
            tokens: tokens,
          ),
          _buildPropertyRow(
            label: 'Container MIME',
            value: hasAsset && asset.mimeType.isNotEmpty ? asset.mimeType : '—',
            tokens: tokens,
          ),
          if (fileHash.isNotEmpty) ...[
            const SizedBox(height: LyraSpacing.sm),
            _buildHashBox(
              label: 'Physical File Digest',
              hash: fileHash,
              fieldId: 'cas_hash',
              tokens: tokens,
            ),
          ] else ...[
            _buildPropertyRow(
              label: 'Physical File Digest',
              value: '—',
              subtitle: 'Not registered in CAS',
              tokens: tokens,
            ),
          ],
          const SizedBox(height: LyraSpacing.sm),
          _buildIntegrityStatusRow(
            fileHash: fileHash.isNotEmpty ? fileHash : null,
            tokens: tokens,
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceCard(LyraThemeTokens tokens) {
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

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 15.0, color: tokens.primary),
              const SizedBox(width: LyraSpacing.xs),
              Expanded(
                child: Text(
                  'Digital Provenance',
                  style: LyraTypography.small(tokens).copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.textMuted,
                    fontSize: 13.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.sm),
          _buildPropertyRow(
            label: 'Source Type',
            value: sourceType.isNotEmpty ? _formatSourceType(sourceType) : '—',
            tokens: tokens,
          ),
          _buildPropertyRow(
            label: 'Notarization Timestamp',
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
              'Curator & Ingestion Log',
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
      ),
    );
  }

  Widget _buildIntegrityStatusRow({
    required String? fileHash,
    required LyraThemeTokens tokens,
  }) {
    final hasFile = fileHash != null && fileHash.isNotEmpty;
    final isVerified =
        hasFile &&
        (_verificationResult ??
            _resolvedAsset?.verified ??
            widget.asset?.verified ??
            _track?.verified ??
            false);

    Color statusColor;
    Color bgColor;
    Color borderColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    if (!hasFile) {
      statusColor = tokens.textMuted;
      bgColor = tokens.secondary.withValues(alpha: 0.3);
      borderColor = tokens.border;
      statusIcon = LucideIcons.fileQuestion;
      statusTitle = 'Integrity: Unregistered';
      statusSubtitle = 'No physical file registered in CAS';
    } else if (!isVerified) {
      statusColor = tokens.destructive;
      bgColor = tokens.destructive.withValues(alpha: 0.08);
      borderColor = tokens.destructive.withValues(alpha: 0.3);
      statusIcon = LucideIcons.shieldAlert;
      statusTitle = 'Verification Failed';
      statusSubtitle = 'Checksum Mismatch';
    } else {
      statusColor = tokens.success;
      bgColor = tokens.success.withValues(alpha: 0.08);
      borderColor = tokens.success.withValues(alpha: 0.3);
      statusIcon = LucideIcons.shieldCheck;
      statusTitle = 'Integrity: Verified';
      statusSubtitle = 'Checksum Match';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.md,
        vertical: LyraSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: LyraRadius.smRadius,
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 18.0, color: statusColor),
          const SizedBox(width: LyraSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusTitle,
                  style: LyraTypography.small(tokens).copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 13.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  statusSubtitle,
                  style: LyraTypography.muted(tokens).copyWith(fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: LyraSpacing.sm),
          LyraButton.outline(
            size: LyraButtonSize.sm,
            onPressed: (!hasFile || _isVerifying)
                ? null
                : _handleVerifyIntegrity,
            leading: _isVerifying
                ? const Icon(LucideIcons.loader2, size: 12.0)
                : const Icon(LucideIcons.refreshCw, size: 12.0),
            child: Text(_isVerifying ? 'Checking...' : 'Re-verify'),
          ),
        ],
      ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155.0,
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
                                  ? LyraTypography.mono(tokens, fontSize: 12.0)
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
              _buildCopyButton(hash, fieldId, tokens),
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
              _buildCopyButton(path, 'orig_path', tokens),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCopyButton(String text, String fieldId, LyraThemeTokens tokens) {
    final isCopied = _copiedField == fieldId;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _copyToClipboard(text, fieldId),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCopied ? LucideIcons.check : LucideIcons.copy,
              size: 13.0,
              color: isCopied ? tokens.success : tokens.textMuted,
            ),
            if (isCopied) ...[
              const SizedBox(width: 4.0),
              Text(
                'Copied',
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.success, fontSize: 11.0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
