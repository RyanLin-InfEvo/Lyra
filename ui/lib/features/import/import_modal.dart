// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_dialog.dart';
import '../../design_system/widgets/lyra_input.dart';
import '../models/track.dart';

/// Modal dialog for importing and hashing audio files into CAS storage.
class ImportAudioModal extends StatefulWidget {
  final Future<Track> Function({
    required String title,
    required String artist,
    required String album,
    required String format,
    required int sampleRate,
    required int bitDepth,
    required String simulatedHash,
  })
  onImport;
  final VoidCallback onClose;

  const ImportAudioModal({
    super.key,
    required this.onImport,
    required this.onClose,
  });

  @override
  State<ImportAudioModal> createState() => _ImportAudioModalState();
}

class _ImportAudioModalState extends State<ImportAudioModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;

  String _format = 'FLAC';
  int _sampleRate = 96000;
  int _bitDepth = 24;

  bool _isIngesting = false;
  bool _isVerified = false;
  String _computedHash = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Clair de Lune');
    _artistController = TextEditingController(text: 'Claude Debussy');
    _albumController = TextEditingController(text: 'Suite Bergamasque');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _handleIngest() async {
    setState(() {
      _isIngesting = true;
      _isVerified = false;
      _computedHash = 'Computing SHA-256 CAS hash...';
    });

    // Simulate cryptographic hashing step
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final simulatedHash =
        'a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef${DateTime.now().millisecondsSinceEpoch % 1000}';

    setState(() {
      _isIngesting = false;
      _isVerified = true;
      _computedHash = simulatedHash;
    });

    await widget.onImport(
      title: _titleController.text.trim().isEmpty
          ? 'Untitled Track'
          : _titleController.text.trim(),
      artist: _artistController.text.trim().isEmpty
          ? 'Unknown Artist'
          : _artistController.text.trim(),
      album: _albumController.text.trim().isEmpty
          ? 'Single'
          : _albumController.text.trim(),
      format: _format,
      sampleRate: _sampleRate,
      bitDepth: _bitDepth,
      simulatedHash: simulatedHash,
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520.0),
        child: LyraDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(LyraSpacing.xs),
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Icon(
                  LucideIcons.uploadCloud,
                  size: 18.0,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(width: LyraSpacing.sm),
              Text(
                'Import Audio to CAS Pool',
                style: LyraTypography.h3(tokens),
              ),
            ],
          ),
          description: Text(
            'Ingest raw bitstream into Content Addressable Storage with cryptographic SHA-256 validation.',
            style: LyraTypography.muted(tokens),
          ),
          actions: [
            LyraButton.ghost(
              size: LyraButtonSize.sm,
              onPressed: widget.onClose,
              child: const Text('Cancel'),
            ),
            LyraButton(
              size: LyraButtonSize.sm,
              onPressed: _isIngesting ? null : _handleIngest,
              leading: _isIngesting
                  ? const Icon(LucideIcons.loader2, size: 14.0)
                  : const Icon(LucideIcons.check, size: 14.0),
              child: Text(_isIngesting ? 'Ingesting...' : 'Ingest & Verify'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: LyraSpacing.md),

              // Title input
              Text(
                'TRACK TITLE',
                style: LyraTypography.small(tokens).copyWith(
                  fontWeight: FontWeight.bold,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: LyraSpacing.xs),
              LyraInput(
                controller: _titleController,
                placeholder: 'e.g. Hotel California',
              ),

              const SizedBox(height: LyraSpacing.md),

              // Artist and Album Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARTIST',
                          style: LyraTypography.small(tokens).copyWith(
                            fontWeight: FontWeight.bold,
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: LyraSpacing.xs),
                        LyraInput(
                          controller: _artistController,
                          placeholder: 'e.g. Eagles',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LyraSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALBUM',
                          style: LyraTypography.small(tokens).copyWith(
                            fontWeight: FontWeight.bold,
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: LyraSpacing.xs),
                        LyraInput(
                          controller: _albumController,
                          placeholder: 'e.g. Hell Freezes Over',
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: LyraSpacing.md),

              // Format & Resolution
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FORMAT',
                          style: LyraTypography.small(tokens).copyWith(
                            fontWeight: FontWeight.bold,
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: LyraSpacing.xs),
                        Wrap(
                          spacing: LyraSpacing.xs,
                          runSpacing: LyraSpacing.xs,
                          children: ['FLAC', 'WAV', 'AAC'].map((fmt) {
                            final isSel = _format == fmt;
                            return LyraButton(
                              variant: isSel
                                  ? LyraButtonVariant.primary
                                  : LyraButtonVariant.outline,
                              size: LyraButtonSize.sm,
                              onPressed: () => setState(() => _format = fmt),
                              child: Text(fmt),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LyraSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESOLUTION',
                          style: LyraTypography.small(tokens).copyWith(
                            fontWeight: FontWeight.bold,
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(height: LyraSpacing.xs),
                        Wrap(
                          spacing: LyraSpacing.xs,
                          runSpacing: LyraSpacing.xs,
                          children:
                              [
                                (sr: 96000, bd: 24, label: '24/96'),
                                (sr: 192000, bd: 24, label: '24/192'),
                                (sr: 44100, bd: 16, label: '16/44.1'),
                              ].map((res) {
                                final isSel =
                                    _sampleRate == res.sr &&
                                    _bitDepth == res.bd;
                                return LyraButton(
                                  variant: isSel
                                      ? LyraButtonVariant.primary
                                      : LyraButtonVariant.outline,
                                  size: LyraButtonSize.sm,
                                  onPressed: () {
                                    setState(() {
                                      _sampleRate = res.sr;
                                      _bitDepth = res.bd;
                                    });
                                  },
                                  child: Text(res.label),
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_computedHash.isNotEmpty) ...[
                const SizedBox(height: LyraSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(LyraSpacing.md),
                  decoration: BoxDecoration(
                    color: tokens.secondary,
                    borderRadius: LyraRadius.mdRadius,
                    border: Border.all(color: tokens.border, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isVerified
                            ? LucideIcons.shieldCheck
                            : LucideIcons.loader2,
                        size: 18.0,
                        color: _isVerified ? tokens.success : tokens.primary,
                      ),
                      const SizedBox(width: LyraSpacing.sm),
                      Expanded(
                        child: Text(
                          _computedHash,
                          style: LyraTypography.mono(tokens, fontSize: 11.0),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
