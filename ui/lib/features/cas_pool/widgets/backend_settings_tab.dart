// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart'
    show LinearProgressIndicator, SelectableText, showDialog;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadSlider, ShadSliderController;

import '../../../design_system/contracts/lyra_contracts.dart';
import '../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../design_system/tokens/lyra_tokens.dart';
import '../../../design_system/widgets/lyra_button.dart';
import '../../../design_system/widgets/lyra_card.dart';
import '../../../design_system/widgets/lyra_checkbox.dart';
import '../../../design_system/widgets/lyra_copy_button.dart';
import '../../../design_system/widgets/lyra_input.dart';
import '../../../design_system/widgets/lyra_settings_layout.dart';
import '../../../design_system/widgets/lyra_spinner.dart';
import '../../../design_system/widgets/lyra_switch.dart';
import '../../../design_system/widgets/lyra_toast.dart';
import '../controllers/backend_settings_controller.dart';
import '../controllers/cas_controller.dart';
import '../models/engine_config.dart';
import 'engine_config_diff_dialog.dart';

/// Available sections in the backend engine settings master-detail navigation.
enum BackendSettingsSection {
  audioHardware,
  databaseEngine,
  ingestionPipeline,
  storageMaintenance,
}

/// Tab view displaying core backend engine settings: storage information and diagnostics,
/// audio hardware and bit-perfect parameters, SQLite engine tuning, and ingestion pipeline concurrency.
class BackendSettingsTab extends StatefulWidget {
  final BackendSettingsController controller;
  final CasController? casController;
  final VoidCallback? onVerifyAll;
  final VoidCallback? onRequestPrune;
  final VoidCallback? onRequestClearWaveforms;
  final BackendSettingsSection initialSection;
  final ValueChanged<BackendSettingsSection>? onSectionChanged;

  const BackendSettingsTab({
    super.key,
    required this.controller,
    this.casController,
    this.onVerifyAll,
    this.onRequestPrune,
    this.onRequestClearWaveforms,
    this.initialSection = BackendSettingsSection.audioHardware,
    this.onSectionChanged,
  });

  @override
  State<BackendSettingsTab> createState() => _BackendSettingsTabState();
}

class _BackendSettingsTabState extends State<BackendSettingsTab> {
  static const int _minBusyTimeoutMs = 1000;
  static const int _maxBusyTimeoutMs = 300000;
  static const int _maxParallelThreads = 1024;

  late BackendSettingsSection _currentSection = widget.initialSection;
  late final ShadSliderController _sliderController;
  late final TextEditingController _busyTimeoutController;
  late final TextEditingController _walAutocheckpointController;
  late final FocusNode _busyTimeoutFocusNode;
  late final FocusNode _walAutocheckpointFocusNode;

  int? _lastSyncedBusyTimeout;
  int? _lastSyncedWalAutocheckpoint;
  int? _lastBufferFrames;
  bool? _lastExclusiveMode;
  int _lastDraftResetEpoch = 0;
  bool _lastIsRestartPending = false;
  bool _restartBannerDismissedByUser = false;

  String? _busyTimeoutError;
  String? _walAutocheckpointError;

  bool get _hasValidationErrors =>
      _busyTimeoutError != null || _walAutocheckpointError != null;

  int _effectiveMaxThreads(IngestionPipelineConfig ingestion) {
    final committedThreads = controller.config.ingestion.parallelThreads;
    final maxConfigured = committedThreads > ingestion.parallelThreads
        ? committedThreads
        : ingestion.parallelThreads;
    final rawMax = ingestion.detectedCpuCores > maxConfigured
        ? ingestion.detectedCpuCores
        : maxConfigured;
    return rawMax.clamp(1, _maxParallelThreads);
  }

  BackendSettingsController get controller => widget.controller;
  CasController? get casController => widget.casController;
  VoidCallback? get onVerifyAll => widget.onVerifyAll;
  VoidCallback? get onRequestPrune => widget.onRequestPrune;
  VoidCallback? get onRequestClearWaveforms => widget.onRequestClearWaveforms;

  @override
  void initState() {
    super.initState();
    _busyTimeoutFocusNode = FocusNode();
    _walAutocheckpointFocusNode = FocusNode();

    _busyTimeoutFocusNode.addListener(_onFocusChanged);
    _walAutocheckpointFocusNode.addListener(_onFocusChanged);

    final ingestion = widget.controller.pendingConfig.ingestion;
    final initialVal =
        (ingestion.parallelThreads <= 0
                ? ingestion.detectedCpuCores
                : ingestion.parallelThreads)
            .toDouble()
            .clamp(1.0, _effectiveMaxThreads(ingestion).toDouble());
    _sliderController = ShadSliderController(initialValue: initialVal);

    final pending = widget.controller.pendingConfig;
    final db = pending.database;
    _lastSyncedBusyTimeout = db.busyTimeoutMs;
    _lastSyncedWalAutocheckpoint = db.walAutocheckpoint;
    _lastBufferFrames = pending.audio.bufferSizeFrames;
    _lastExclusiveMode = pending.audio.exclusiveMode;
    _lastDraftResetEpoch = widget.controller.draftResetEpoch;
    _lastIsRestartPending = widget.controller.isRestartPending;

    _busyTimeoutController = TextEditingController(text: '${db.busyTimeoutMs}');
    _walAutocheckpointController = TextEditingController(
      text: '${db.walAutocheckpoint}',
    );

    widget.controller.addListener(_onControllerChanged);
    widget.casController?.addListener(_onCasControllerChanged);
  }

  void _onFocusChanged() {
    if (!_busyTimeoutFocusNode.hasFocus && _busyTimeoutError == null) {
      final dbVal = controller.pendingConfig.database.busyTimeoutMs;
      if (_busyTimeoutController.text != '$dbVal') {
        _busyTimeoutController.text = '$dbVal';
      }
    }
    if (!_walAutocheckpointFocusNode.hasFocus &&
        _walAutocheckpointError == null) {
      final dbVal = controller.pendingConfig.database.walAutocheckpoint;
      if (_walAutocheckpointController.text != '$dbVal') {
        _walAutocheckpointController.text = '$dbVal';
      }
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final pending = controller.pendingConfig;

    final isAuto = pending.ingestion.parallelThreads <= 0;
    final targetSliderVal =
        (isAuto
                ? pending.ingestion.detectedCpuCores
                : pending.ingestion.parallelThreads)
            .toDouble()
            .clamp(1.0, _effectiveMaxThreads(pending.ingestion).toDouble());
    if (_sliderController.value != targetSliderVal) {
      _sliderController.value = targetSliderVal;
    }

    final bool draftWasReset =
        controller.draftResetEpoch != _lastDraftResetEpoch;
    if (draftWasReset) {
      _lastDraftResetEpoch = controller.draftResetEpoch;
      _lastSyncedBusyTimeout = pending.database.busyTimeoutMs;
      _busyTimeoutController.text = '$_lastSyncedBusyTimeout';
      _busyTimeoutError = null;
      _lastSyncedWalAutocheckpoint = pending.database.walAutocheckpoint;
      _walAutocheckpointController.text = '$_lastSyncedWalAutocheckpoint';
      _walAutocheckpointError = null;
    } else {
      if (!_busyTimeoutFocusNode.hasFocus) {
        if (pending.database.busyTimeoutMs != _lastSyncedBusyTimeout) {
          _lastSyncedBusyTimeout = pending.database.busyTimeoutMs;
          _busyTimeoutController.text = '$_lastSyncedBusyTimeout';
          _busyTimeoutError = null;
        } else if (!controller.isDirty) {
          _lastSyncedBusyTimeout = pending.database.busyTimeoutMs;
          if (_busyTimeoutController.text != '$_lastSyncedBusyTimeout') {
            _busyTimeoutController.text = '$_lastSyncedBusyTimeout';
          }
          _busyTimeoutError = null;
        }
      }

      if (!_walAutocheckpointFocusNode.hasFocus) {
        if (pending.database.walAutocheckpoint !=
            _lastSyncedWalAutocheckpoint) {
          _lastSyncedWalAutocheckpoint = pending.database.walAutocheckpoint;
          _walAutocheckpointController.text = '$_lastSyncedWalAutocheckpoint';
          _walAutocheckpointError = null;
        } else if (!controller.isDirty) {
          _lastSyncedWalAutocheckpoint = pending.database.walAutocheckpoint;
          if (_walAutocheckpointController.text !=
              '$_lastSyncedWalAutocheckpoint') {
            _walAutocheckpointController.text = '$_lastSyncedWalAutocheckpoint';
          }
          _walAutocheckpointError = null;
        }
      }
    }

    if (pending.audio.bufferSizeFrames != _lastBufferFrames ||
        pending.audio.exclusiveMode != _lastExclusiveMode ||
        (controller.isRestartPending && !_lastIsRestartPending)) {
      _lastBufferFrames = pending.audio.bufferSizeFrames;
      _lastExclusiveMode = pending.audio.exclusiveMode;
      _restartBannerDismissedByUser = false;
    }
    _lastIsRestartPending = controller.isRestartPending;

    setState(() {});
  }

  void _onCasControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant BackendSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _currentSection = widget.initialSection;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _syncControllers();
    }
    if (oldWidget.casController != widget.casController) {
      oldWidget.casController?.removeListener(_onCasControllerChanged);
      widget.casController?.addListener(_onCasControllerChanged);
    }
  }

  void _syncControllers() {
    final pending = widget.controller.pendingConfig;
    final db = pending.database;
    _lastSyncedBusyTimeout = db.busyTimeoutMs;
    _lastSyncedWalAutocheckpoint = db.walAutocheckpoint;
    _lastBufferFrames = pending.audio.bufferSizeFrames;
    _lastExclusiveMode = pending.audio.exclusiveMode;
    _lastDraftResetEpoch = widget.controller.draftResetEpoch;
    _lastIsRestartPending = widget.controller.isRestartPending;
    _restartBannerDismissedByUser = false;
    _busyTimeoutError = null;
    _walAutocheckpointError = null;
    _busyTimeoutController.text = '${db.busyTimeoutMs}';
    _walAutocheckpointController.text = '${db.walAutocheckpoint}';

    final ingestion = pending.ingestion;
    final initialVal =
        (ingestion.parallelThreads <= 0
                ? ingestion.detectedCpuCores
                : ingestion.parallelThreads)
            .toDouble()
            .clamp(1.0, _effectiveMaxThreads(ingestion).toDouble());
    _sliderController.value = initialVal;
  }

  void _handleDiscardChanges() {
    controller.resetDraft();
    _busyTimeoutError = null;
    _walAutocheckpointError = null;
    _restartBannerDismissedByUser = false;
    _syncControllers();
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.casController?.removeListener(_onCasControllerChanged);
    _busyTimeoutFocusNode.removeListener(_onFocusChanged);
    _walAutocheckpointFocusNode.removeListener(_onFocusChanged);
    _busyTimeoutFocusNode.dispose();
    _walAutocheckpointFocusNode.dispose();
    _sliderController.dispose();
    _busyTimeoutController.dispose();
    _walAutocheckpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final pending = controller.pendingConfig;

    return LyraSettingsLayout<BackendSettingsSection>(
      sidebarWidth: 250.0,
      selectedSection: _currentSection,
      onSectionChanged: (section) {
        setState(() => _currentSection = section);
        widget.onSectionChanged?.call(section);
      },
      contentPadding: const EdgeInsets.only(
        left: LyraSpacing.xl,
        right: LyraSpacing.xl,
        top: LyraSpacing.sm,
        bottom: LyraSpacing.xl,
      ),
      bottomBar: _buildStickyActionBar(tokens),
      sections: [
        LyraSettingsSection<BackendSettingsSection>(
          id: BackendSettingsSection.audioHardware,
          label: 'Audio Hardware',
          icon: LucideIcons.volume2,
          builder: (context) =>
              _buildAudioHardwareCard(context, tokens, pending),
        ),
        LyraSettingsSection<BackendSettingsSection>(
          id: BackendSettingsSection.databaseEngine,
          label: 'Database Engine',
          icon: LucideIcons.database,
          builder: (context) =>
              _buildDatabaseTuningCard(context, tokens, pending),
        ),
        LyraSettingsSection<BackendSettingsSection>(
          id: BackendSettingsSection.ingestionPipeline,
          label: 'Ingestion Pipeline',
          icon: LucideIcons.cpu,
          builder: (context) => _buildIngestionCard(context, tokens, pending),
        ),
        LyraSettingsSection<BackendSettingsSection>(
          id: BackendSettingsSection.storageMaintenance,
          label: 'Storage & Maintenance',
          icon: LucideIcons.wrench,
          builder: (context) => _buildStorageCard(context, tokens),
        ),
      ],
    );
  }

  // --- Card 1: Storage & Maintenance ---

  Widget _buildStorageCard(BuildContext context, LyraThemeTokens tokens) {
    final cas = casController;

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(LyraSpacing.sm),
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Icon(
                  LucideIcons.wrench,
                  size: 20.0,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(width: LyraSpacing.md),
              Expanded(
                child: Text(
                  'Storage & Cache Maintenance',
                  style: LyraTypography.h4(tokens),
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.md),

          // File path info chips
          Container(
            padding: const EdgeInsets.all(LyraSpacing.md),
            decoration: BoxDecoration(
              color: tokens.secondary.withValues(alpha: 0.5),
              borderRadius: LyraRadius.mdRadius,
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPathRow(
                  tokens,
                  'Storage Root',
                  controller.pendingConfig.storage.storageRoot,
                ),
                const SizedBox(height: LyraSpacing.xs),
                _buildPathRow(
                  tokens,
                  'Database File',
                  controller.pendingConfig.storage.databasePath,
                ),
                const SizedBox(height: LyraSpacing.xs),
                _buildPathRow(
                  tokens,
                  'CAS Objects',
                  controller.pendingConfig.storage.casObjectsDir,
                ),
              ],
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Maintenance Action Buttons
          Wrap(
            spacing: LyraSpacing.sm,
            runSpacing: LyraSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LyraButton.outline(
                size: LyraButtonSize.sm,
                height: 32.0,
                onPressed: (cas == null || cas.isVerifying)
                    ? null
                    : () async {
                        await cas.verifyIntegrity();
                        onVerifyAll?.call();
                      },
                child: const Text('Verify Integrity'),
              ),
              LyraButton.outline(
                size: LyraButtonSize.sm,
                height: 32.0,
                onPressed:
                    (cas == null || cas.isPruning || cas.orphanedCount == 0)
                    ? null
                    : () => onRequestPrune?.call(),
                child: Text(
                  cas != null && cas.orphanedBytes > 0
                      ? 'Prune Orphans (${cas.formattedOrphanedBytes})'
                      : 'Prune Orphans',
                ),
              ),
              LyraButton.outline(
                size: LyraButtonSize.sm,
                height: 32.0,
                onPressed: (cas == null || cas.isClearingWaveforms)
                    ? null
                    : () => onRequestClearWaveforms?.call(),
                child: const Text('Clear Waveform Cache'),
              ),
            ],
          ),

          // Verification Progress Indicator
          if (cas != null && cas.isVerifying) ...[
            const SizedBox(height: LyraSpacing.md),
            Container(
              padding: const EdgeInsets.all(LyraSpacing.sm),
              decoration: BoxDecoration(
                color: tokens.secondary,
                borderRadius: LyraRadius.mdRadius,
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Verifying Storage Integrity...',
                        style: LyraTypography.small(tokens).copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.primary,
                        ),
                      ),
                      Text(
                        '${(cas.verificationProgress * 100).toInt()}%',
                        style: LyraTypography.small(tokens).copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: LyraSpacing.xs),
                  ClipRRect(
                    borderRadius: LyraRadius.smRadius,
                    child: LinearProgressIndicator(
                      value: cas.verificationProgress > 0.0
                          ? cas.verificationProgress
                          : null,
                      backgroundColor: tokens.card,
                      valueColor: AlwaysStoppedAnimation<Color>(tokens.primary),
                      minHeight: 4.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPathRow(LyraThemeTokens tokens, String label, String path) {
    return Row(
      children: [
        SizedBox(
          width: 100.0,
          child: Text(label, style: LyraTypography.muted(tokens)),
        ),
        Expanded(
          child: SelectableText(
            path,
            style: LyraTypography.small(
              tokens,
            ).copyWith(fontFamily: 'monospace', color: tokens.text),
            maxLines: 1,
          ),
        ),
        const SizedBox(width: LyraSpacing.xs),
        LyraCopyButton(
          text: path,
          iconSize: 13.0,
          size: 24.0,
          tooltip: 'Copy $label',
        ),
      ],
    );
  }

  // --- Card 2: Audio Hardware & Bit-Perfect Engine ---

  Widget _buildAudioHardwareCard(
    BuildContext context,
    LyraThemeTokens tokens,
    EngineConfig pending,
  ) {
    final devices = controller.audioDevices;
    final defaultItem = LyraSelectItem<String>(
      value: 'default',
      label: 'Default System Audio',
      leading: Icon(LucideIcons.volume2, size: 16.0, color: tokens.primary),
    );

    final physicalItems = devices
        .where((d) => d.id != 'default')
        .map(
          (d) => LyraSelectItem<String>(
            value: d.id,
            label: d.name,
            leading: Icon(
              d.isDefault ? LucideIcons.volume2 : LucideIcons.speaker,
              size: 16.0,
              color: tokens.primary,
            ),
          ),
        );

    final selectItems = [defaultItem, ...physicalItems];

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(LyraSpacing.sm),
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Icon(
                  LucideIcons.volume2,
                  size: 20.0,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(width: LyraSpacing.md),
              Expanded(
                child: Text(
                  'Audio Hardware & Bit-Perfect Engine',
                  style: LyraTypography.h4(tokens),
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.xl),

          // Output Device Dropdown
          _buildFormSection(
            tokens: tokens,
            label: 'Output Device',
            child: LyraSelect<String>(
              width: double.infinity,
              value: pending.audio.outputDeviceId,
              items: selectItems,
              onChanged: (id) => controller.setOutputDevice(id),
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Exclusive Mode Switch
          Container(
            padding: const EdgeInsets.all(LyraSpacing.md),
            decoration: BoxDecoration(
              color: tokens.secondary.withValues(alpha: 0.3),
              borderRadius: LyraRadius.mdRadius,
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exclusive Mode',
                        style: LyraTypography.p(
                          tokens,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: LyraSpacing.xs),
                      Text(
                        'Bypass OS mixer and direct bit-perfect stream to hardware',
                        style: LyraTypography.muted(tokens),
                      ),
                    ],
                  ),
                ),
                LyraSwitch(
                  value: pending.audio.exclusiveMode,
                  onChanged: (val) => controller.setExclusiveMode(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Buffer Size Pills
          _buildFormSection(
            tokens: tokens,
            label: 'Buffer Size (Frames)',
            child: Wrap(
              spacing: LyraSpacing.xs,
              runSpacing: LyraSpacing.xs,
              children: [64, 128, 256, 512, 1024].map((size) {
                final isSelected = pending.audio.bufferSizeFrames == size;
                return LyraButton(
                  height: 32.0,
                  size: LyraButtonSize.sm,
                  variant: isSelected
                      ? LyraButtonVariant.secondary
                      : LyraButtonVariant.outline,
                  onPressed: () => controller.setBufferSize(size),
                  child: Text('$size'),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Volume Strategy Pills
          _buildFormSection(
            tokens: tokens,
            label: 'Volume Strategy',
            child: Wrap(
              spacing: LyraSpacing.xs,
              runSpacing: LyraSpacing.xs,
              children: AudioVolumeMode.values.map((mode) {
                final isSelected = pending.audio.volumeMode == mode;
                return LyraButton(
                  height: 32.0,
                  size: LyraButtonSize.sm,
                  variant: isSelected
                      ? LyraButtonVariant.secondary
                      : LyraButtonVariant.outline,
                  onPressed: () => controller.setVolumeMode(mode),
                  child: Text(mode.label),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Resampler Engine Dropdown
          _buildFormSection(
            tokens: tokens,
            label: 'Resampler Engine',
            child: LyraSelect<ResamplerQuality>(
              width: double.infinity,
              value: pending.audio.resamplerQuality,
              items: ResamplerQuality.values
                  .map(
                    (q) => LyraSelectItem<ResamplerQuality>(
                      value: q,
                      label: q.label,
                    ),
                  )
                  .toList(),
              onChanged: (q) => controller.setResamplerQuality(q),
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // DSD Decoding Strategy Pills
          _buildFormSection(
            tokens: tokens,
            label: 'DSD Decoding',
            child: Wrap(
              spacing: LyraSpacing.xs,
              runSpacing: LyraSpacing.xs,
              children: DsdMode.values.map((mode) {
                final isSelected = pending.audio.dsdMode == mode;
                return LyraButton(
                  height: 32.0,
                  size: LyraButtonSize.sm,
                  variant: isSelected
                      ? LyraButtonVariant.secondary
                      : LyraButtonVariant.outline,
                  onPressed: () => controller.setDsdMode(mode),
                  child: Text(mode.label),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- Card 3: Database Engine Tuning ---

  Widget _buildDatabaseTuningCard(
    BuildContext context,
    LyraThemeTokens tokens,
    EngineConfig pending,
  ) {
    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(LyraSpacing.sm),
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Icon(
                  LucideIcons.database,
                  size: 20.0,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(width: LyraSpacing.md),
              Expanded(
                child: Text(
                  'Database Engine Tuning',
                  style: LyraTypography.h4(tokens),
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.xl),

          // SQLite Page Cache Size
          _buildFormSection(
            tokens: tokens,
            label: 'Page Cache Size',
            child: Wrap(
              spacing: LyraSpacing.xs,
              runSpacing: LyraSpacing.xs,
              children:
                  [
                    (64 * 1024, '64 MB'),
                    (128 * 1024, '128 MB'),
                    (256 * 1024, '256 MB'),
                    (512 * 1024, '512 MB'),
                  ].map((opt) {
                    final isSelected = pending.database.cacheSizeKb == opt.$1;
                    return LyraButton(
                      height: 32.0,
                      size: LyraButtonSize.sm,
                      variant: isSelected
                          ? LyraButtonVariant.secondary
                          : LyraButtonVariant.outline,
                      onPressed: () => controller.setDatabaseCacheSize(opt.$1),
                      child: Text(opt.$2),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Memory Mapped I/O (MMAP)
          _buildFormSection(
            tokens: tokens,
            label: 'Memory-Mapped I/O (MMAP)',
            child: Wrap(
              spacing: LyraSpacing.xs,
              runSpacing: LyraSpacing.xs,
              children:
                  [
                    (0, 'Off'),
                    (256 * 1024 * 1024, '256 MB'),
                    (512 * 1024 * 1024, '512 MB'),
                    (1024 * 1024 * 1024, '1 GB'),
                  ].map((opt) {
                    final isSelected = pending.database.mmapSizeBytes == opt.$1;
                    return LyraButton(
                      height: 32.0,
                      size: LyraButtonSize.sm,
                      variant: isSelected
                          ? LyraButtonVariant.secondary
                          : LyraButtonVariant.outline,
                      onPressed: () => controller.setDatabaseMmapSize(opt.$1),
                      child: Text(opt.$2),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Busy Timeout
          _buildFormSection(
            tokens: tokens,
            label: 'Busy Timeout',
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LyraInput(
                    key: const ValueKey('busy_timeout_input'),
                    controller: _busyTimeoutController,
                    focusNode: _busyTimeoutFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    trailing: Text(
                      'ms',
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(color: tokens.textMuted),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val.trim().isEmpty) {
                          _busyTimeoutError =
                              'Value must be between 1,000 and 300,000 ms';
                        } else {
                          final parsed = int.tryParse(val);
                          if (parsed == null ||
                              parsed < _minBusyTimeoutMs ||
                              parsed > _maxBusyTimeoutMs) {
                            _busyTimeoutError =
                                'Value must be between 1,000 and 300,000 ms';
                          } else {
                            _busyTimeoutError = null;
                            _lastSyncedBusyTimeout = parsed;
                            controller.setBusyTimeout(parsed);
                          }
                        }
                      });
                    },
                  ),
                  if (_busyTimeoutError != null) ...[
                    const SizedBox(height: LyraSpacing.xs),
                    Text(
                      _busyTimeoutError!,
                      key: const ValueKey('busy_timeout_error'),
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(color: tokens.destructive, fontSize: 12.0),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // WAL Checkpoint Threshold
          _buildFormSection(
            tokens: tokens,
            label: 'WAL Autocheckpoint',
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LyraInput(
                    key: const ValueKey('wal_autocheckpoint_input'),
                    controller: _walAutocheckpointController,
                    focusNode: _walAutocheckpointFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    trailing: Text(
                      'pages',
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(color: tokens.textMuted),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val.trim().isEmpty) {
                          _walAutocheckpointError =
                              'Value must be between 10 and 100,000 pages';
                        } else {
                          final parsed = int.tryParse(val);
                          if (parsed == null ||
                              parsed < 10 ||
                              parsed > 100000) {
                            _walAutocheckpointError =
                                'Value must be between 10 and 100,000 pages';
                          } else {
                            _walAutocheckpointError = null;
                            _lastSyncedWalAutocheckpoint = parsed;
                            controller.setWalAutocheckpoint(parsed);
                          }
                        }
                      });
                    },
                  ),
                  if (_walAutocheckpointError != null) ...[
                    const SizedBox(height: LyraSpacing.xs),
                    Text(
                      _walAutocheckpointError!,
                      key: const ValueKey('wal_autocheckpoint_error'),
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(color: tokens.destructive, fontSize: 12.0),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Card 4: Ingestion Pipeline ---

  Widget _buildIngestionCard(
    BuildContext context,
    LyraThemeTokens tokens,
    EngineConfig pending,
  ) {
    final isAuto = pending.ingestion.parallelThreads <= 0;
    final maxThreads = _effectiveMaxThreads(pending.ingestion);
    final safeDetectedCores = pending.ingestion.detectedCpuCores.clamp(
      1,
      _maxParallelThreads,
    );
    final displayThreads = pending.ingestion.parallelThreads.clamp(
      1,
      maxThreads,
    );
    final canSlide = !isAuto && maxThreads > 1;

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(LyraSpacing.sm),
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Icon(LucideIcons.cpu, size: 20.0, color: tokens.primary),
              ),
              const SizedBox(width: LyraSpacing.md),
              Expanded(
                child: Text(
                  'Ingestion Pipeline',
                  style: LyraTypography.h4(tokens),
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.xl),

          // Worker Threads
          _buildFormSection(
            tokens: tokens,
            label: 'Worker Threads',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: LyraSpacing.md,
                    runSpacing: LyraSpacing.xs,
                    children: [
                      LyraCheckbox(
                        value: isAuto,
                        onChanged: (checked) {
                          controller.setParallelThreads(
                            checked ? 0 : safeDetectedCores,
                          );
                        },
                        label: Text(
                          'Auto (Detected $safeDetectedCores CPU cores)',
                          style: LyraTypography.p(tokens),
                        ),
                      ),
                      Text(
                        isAuto
                            ? 'Auto ($safeDetectedCores threads)'
                            : '$displayThreads / $maxThreads threads',
                        style: LyraTypography.small(tokens).copyWith(
                          fontFamily: 'monospace',
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LyraSpacing.sm),
                Opacity(
                  opacity: canSlide ? 1.0 : 0.4,
                  child: ShadSlider(
                    key: const ValueKey('worker_threads_slider'),
                    min: 1.0,
                    max: maxThreads > 1 ? maxThreads.toDouble() : 2.0,
                    controller: _sliderController,
                    enabled: canSlide,
                    onChanged: (val) {
                      if (canSlide) {
                        controller.setParallelThreads(val.round());
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Ingestion Mode Strategy
          _buildFormSection(
            tokens: tokens,
            label: 'Ingestion Mode',
            child: Wrap(
              spacing: LyraSpacing.xs,
              runSpacing: LyraSpacing.xs,
              children: IngestionMode.values.map((mode) {
                final isSelected = pending.ingestion.mode == mode;
                return LyraButton(
                  height: 32.0,
                  size: LyraButtonSize.sm,
                  variant: isSelected
                      ? LyraButtonVariant.secondary
                      : LyraButtonVariant.outline,
                  onPressed: () => controller.setIngestionMode(mode),
                  child: Flexible(
                    child: Text(mode.label, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sticky Bottom Action Bar ---

  Widget? _buildStickyActionBar(LyraThemeTokens tokens) {
    final isDirty = controller.isDirty;
    final errorMsg = controller.errorMessage;
    final showRestartBanner =
        (controller.restartRequired || controller.isRestartPending) &&
        !_restartBannerDismissedByUser;
    final showActions = isDirty || _hasValidationErrors;

    if (!showActions && errorMsg == null && !showRestartBanner) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.lg,
        vertical: LyraSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(top: BorderSide(color: tokens.border)),
        boxShadow: [
          BoxShadow(
            color: tokens.border.withValues(alpha: 0.2),
            offset: const Offset(0, -4),
            blurRadius: 12.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showRestartBanner) ...[
            Container(
              margin: const EdgeInsets.only(bottom: LyraSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: LyraSpacing.md,
                vertical: LyraSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: tokens.secondary.withValues(alpha: 0.5),
                borderRadius: LyraRadius.smRadius,
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.triangleAlert,
                    size: 16.0,
                    color: tokens.warning,
                  ),
                  const SizedBox(width: LyraSpacing.sm),
                  Expanded(
                    child: Text(
                      'Audio engine will restart to apply hardware buffer or exclusive mode changes.',
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: LyraSpacing.sm),
                  LyraButton.ghost(
                    key: const ValueKey('dismiss_restart_banner'),
                    size: LyraButtonSize.sm,
                    height: 24.0,
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    onPressed: () {
                      setState(() {
                        _restartBannerDismissedByUser = true;
                      });
                      controller.acknowledgeRestart();
                    },
                    child: Icon(
                      LucideIcons.x,
                      size: 14.0,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final messageWidget = errorMsg != null
                  ? Text(
                      errorMsg,
                      style: LyraTypography.small(tokens).copyWith(
                        fontWeight: FontWeight.w600,
                        color: tokens.destructive,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  : null;

              if (!showActions) {
                return messageWidget ?? const SizedBox.shrink();
              }

              final discardButton = LyraButton.outline(
                size: LyraButtonSize.sm,
                height: 32.0,
                onPressed: controller.isSaving ? null : _handleDiscardChanges,
                child: const Text('Discard Changes'),
              );
              final saveButton = LyraButton.primary(
                size: LyraButtonSize.sm,
                height: 32.0,
                onPressed:
                    (controller.isSaving || !isDirty || _hasValidationErrors)
                    ? null
                    : () => _handleSave(context),
                child: controller.isSaving
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LyraSpinner(
                            size: 14.0,
                            color: tokens.primaryForeground,
                          ),
                          const SizedBox(width: LyraSpacing.xs),
                          const Text('Saving...'),
                        ],
                      )
                    : const Text('Save Engine Settings'),
              );

              if (constraints.maxWidth >= 560.0) {
                return Row(
                  children: [
                    if (messageWidget != null)
                      Expanded(child: messageWidget)
                    else
                      const Spacer(),
                    if (messageWidget != null)
                      const SizedBox(width: LyraSpacing.md),
                    discardButton,
                    const SizedBox(width: LyraSpacing.sm),
                    saveButton,
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (messageWidget != null) ...[
                    messageWidget,
                    const SizedBox(height: LyraSpacing.sm),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: LyraSpacing.sm,
                      runSpacing: LyraSpacing.sm,
                      children: [discardButton, saveButton],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    if (!controller.isDirty || controller.isSaving || _hasValidationErrors) {
      return;
    }

    final diffs = computeEngineConfigDiff(
      controller.config,
      controller.pendingConfig,
      devices: controller.audioDevices,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      builder: (dialogCtx) => LyraDesignSystemScope(
        factory: LyraDesignSystemScope.of(context).factory,
        tokens: LyraDesignSystemScope.of(context).tokens,
        themeModeNotifier: LyraDesignSystemScope.of(context).themeModeNotifier,
        child: EngineConfigDiffDialog(
          diffs: diffs,
          restartRequired: controller.restartRequired,
          onConfirm: () => Navigator.of(dialogCtx).pop(true),
          onCancel: () => Navigator.of(dialogCtx).pop(false),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final saved = await controller.saveConfig();
      if (saved && context.mounted) {
        LyraToaster.maybeOf(context)?.show(
          LyraToast(
            title: 'Engine settings saved',
            message: 'Configuration changes have been applied.',
            variant: LyraToastVariant.success,
          ),
        );
      }
    }
  }

  Widget _buildFormSection({
    required LyraThemeTokens tokens,
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: LyraTypography.small(
            tokens,
          ).copyWith(fontWeight: FontWeight.w600, color: tokens.textMuted),
        ),
        const SizedBox(height: LyraSpacing.xs),
        child,
      ],
    );
  }
}
