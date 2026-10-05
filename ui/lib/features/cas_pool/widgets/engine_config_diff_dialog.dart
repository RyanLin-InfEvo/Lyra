// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design_system/contracts/lyra_contracts.dart';
import '../../../design_system/factory/lyra_design_system_scope.dart';
import '../../../design_system/tokens/lyra_tokens.dart';
import '../../../design_system/widgets/lyra_button.dart';
import '../../../design_system/widgets/lyra_dialog.dart';
import '../../audio/models/audio_device.dart';
import '../models/engine_config.dart';

/// Type alias for [AudioDevice] ensuring compatibility with device info references.
typedef AudioDeviceInfo = AudioDevice;

/// Represents a single configuration difference item across sections.
@immutable
class EngineConfigDiffItem {
  final String section;
  final String label;
  final String oldValue;
  final String newValue;

  const EngineConfigDiffItem({
    required this.section,
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineConfigDiffItem &&
          runtimeType == other.runtimeType &&
          section == other.section &&
          label == other.label &&
          oldValue == other.oldValue &&
          newValue == other.newValue;

  @override
  int get hashCode =>
      section.hashCode ^ label.hashCode ^ oldValue.hashCode ^ newValue.hashCode;

  @override
  String toString() =>
      'EngineConfigDiffItem(section: $section, label: $label, oldValue: $oldValue, newValue: $newValue)';
}

/// Computes the list of differences between the [current] and [pending] engine configurations.
List<EngineConfigDiffItem> computeEngineConfigDiff(
  EngineConfig current,
  EngineConfig pending, {
  List<AudioDeviceInfo>? devices,
}) {
  final diffs = <EngineConfigDiffItem>[];

  // 1. Storage Configuration Settings
  if (current.storage.storageRoot != pending.storage.storageRoot) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Storage Engine',
        label: 'Storage Root',
        oldValue: current.storage.storageRoot,
        newValue: pending.storage.storageRoot,
      ),
    );
  }

  if (current.storage.databasePath != pending.storage.databasePath) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Storage Engine',
        label: 'Database Path',
        oldValue: current.storage.databasePath,
        newValue: pending.storage.databasePath,
      ),
    );
  }

  if (current.storage.casObjectsDir != pending.storage.casObjectsDir) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Storage Engine',
        label: 'CAS Objects Dir',
        oldValue: current.storage.casObjectsDir,
        newValue: pending.storage.casObjectsDir,
      ),
    );
  }

  // 2. Database Settings
  if (current.database.cacheSizeKb != pending.database.cacheSizeKb) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Database Engine',
        label: 'Cache Size',
        oldValue: _formatCacheSize(current.database.cacheSizeKb),
        newValue: _formatCacheSize(pending.database.cacheSizeKb),
      ),
    );
  }

  if (current.database.mmapSizeBytes != pending.database.mmapSizeBytes) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Database Engine',
        label: 'MMAP Size',
        oldValue: _formatMmapSize(current.database.mmapSizeBytes),
        newValue: _formatMmapSize(pending.database.mmapSizeBytes),
      ),
    );
  }

  if (current.database.busyTimeoutMs != pending.database.busyTimeoutMs) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Database Engine',
        label: 'Busy Timeout',
        oldValue: '${current.database.busyTimeoutMs} ms',
        newValue: '${pending.database.busyTimeoutMs} ms',
      ),
    );
  }

  if (current.database.walAutocheckpoint !=
      pending.database.walAutocheckpoint) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Database Engine',
        label: 'WAL Autocheckpoint',
        oldValue: '${current.database.walAutocheckpoint} pages',
        newValue: '${pending.database.walAutocheckpoint} pages',
      ),
    );
  }

  // 2. Audio Hardware Settings
  if (current.audio.outputDeviceId != pending.audio.outputDeviceId) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Audio Hardware',
        label: 'Output Device',
        oldValue: _formatDevice(current.audio.outputDeviceId, devices),
        newValue: _formatDevice(pending.audio.outputDeviceId, devices),
      ),
    );
  }

  if (current.audio.exclusiveMode != pending.audio.exclusiveMode) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Audio Hardware',
        label: 'Exclusive Mode',
        oldValue: current.audio.exclusiveMode ? 'Enabled' : 'Disabled',
        newValue: pending.audio.exclusiveMode ? 'Enabled' : 'Disabled',
      ),
    );
  }

  if (current.audio.bufferSizeFrames != pending.audio.bufferSizeFrames) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Audio Hardware',
        label: 'Buffer Size',
        oldValue: '${current.audio.bufferSizeFrames} frames',
        newValue: '${pending.audio.bufferSizeFrames} frames',
      ),
    );
  }

  if (current.audio.volumeMode != pending.audio.volumeMode) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Audio Hardware',
        label: 'Volume Strategy',
        oldValue: current.audio.volumeMode.label,
        newValue: pending.audio.volumeMode.label,
      ),
    );
  }

  if (current.audio.resamplerQuality != pending.audio.resamplerQuality) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Audio Hardware',
        label: 'Resampler Quality',
        oldValue: current.audio.resamplerQuality.label,
        newValue: pending.audio.resamplerQuality.label,
      ),
    );
  }

  if (current.audio.dsdMode != pending.audio.dsdMode) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Audio Hardware',
        label: 'DSD Mode',
        oldValue: current.audio.dsdMode.label,
        newValue: pending.audio.dsdMode.label,
      ),
    );
  }

  // 3. Ingestion Pipeline Settings
  if (current.ingestion.parallelThreads != pending.ingestion.parallelThreads) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Ingestion Pipeline',
        label: 'Worker Threads',
        oldValue: _formatWorkerThreads(current.ingestion),
        newValue: _formatWorkerThreads(pending.ingestion),
      ),
    );
  }

  if (current.ingestion.mode != pending.ingestion.mode) {
    diffs.add(
      EngineConfigDiffItem(
        section: 'Ingestion Pipeline',
        label: 'Ingestion Mode',
        oldValue: current.ingestion.mode.label,
        newValue: pending.ingestion.mode.label,
      ),
    );
  }

  return diffs;
}

String _formatCacheSize(int kb) {
  if (kb >= 1024 && kb % 1024 == 0) {
    return '${kb ~/ 1024} MB';
  }
  return '$kb KB';
}

String _formatMmapSize(int bytes) {
  if (bytes == 0) return 'Off';
  if (bytes >= 1024 * 1024 * 1024 && bytes % (1024 * 1024 * 1024) == 0) {
    return '${bytes ~/ (1024 * 1024 * 1024)} GB';
  }
  if (bytes >= 1024 * 1024 && bytes % (1024 * 1024) == 0) {
    return '${bytes ~/ (1024 * 1024)} MB';
  }
  return '$bytes bytes';
}

String _formatDevice(String id, List<AudioDeviceInfo>? devices) {
  if (id == 'default') return 'Default System Audio';
  if (devices != null) {
    for (final d in devices) {
      if (d.id == id) return d.name;
    }
  }
  return id;
}

String _formatWorkerThreads(IngestionPipelineConfig ingestion) {
  if (ingestion.parallelThreads == 0) {
    final cores = ingestion.detectedCpuCores;
    return 'Auto ($cores ${cores == 1 ? "thread" : "threads"})';
  }
  return '${ingestion.parallelThreads} ${ingestion.parallelThreads == 1 ? "thread" : "threads"}';
}

/// Secondary confirmation dialog displaying a git-diff style comparison of pending engine configuration changes.
class EngineConfigDiffDialog extends StatelessWidget {
  final List<EngineConfigDiffItem> diffs;
  final bool restartRequired;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const EngineConfigDiffDialog({
    super.key,
    required this.diffs,
    this.restartRequired = false,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxContentHeight = (screenHeight - 240.0).clamp(100.0, 360.0);

    return Center(
      key: const Key('engine_config_diff_dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560.0),
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
              Expanded(
                child: Text(
                  'Confirm Engine Configuration Changes',
                  style: LyraTypography.h3(tokens),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          description: Text(
            diffs.isEmpty
                ? 'No settings have been modified.'
                : 'Review the ${diffs.length} modified ${diffs.length == 1 ? "setting" : "settings"} before applying changes to the engine.',
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
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxContentHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (restartRequired) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: LyraSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: LyraSpacing.md,
                        vertical: LyraSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.warning.withValues(alpha: 0.1),
                        borderRadius: LyraRadius.smRadius,
                        border: Border.all(
                          color: tokens.warning.withValues(alpha: 0.3),
                        ),
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
                              'Note: Audio engine will restart to apply hardware buffer or exclusive mode changes.',
                              style: LyraTypography.small(tokens).copyWith(
                                color: tokens.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (diffs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: LyraSpacing.lg,
                      ),
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
                    Column(
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
                                '${diff.section.toUpperCase()} • ${diff.label.toUpperCase()}',
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
                                    child: _buildBeforeCell(
                                      diff.oldValue,
                                      tokens,
                                    ),
                                  ),
                                  const SizedBox(width: LyraSpacing.md),
                                  Expanded(
                                    child: _buildAfterCell(
                                      diff.newValue,
                                      tokens,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeforeCell(String oldValue, LyraThemeTokens tokens) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
              oldValue,
              style: LyraTypography.small(tokens).copyWith(
                color: tokens.destructive,
                decoration: TextDecoration.lineThrough,
                decorationColor: tokens.destructive.withValues(alpha: 0.6),
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfterCell(String newValue, LyraThemeTokens tokens) {
    const emeraldColor = Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.sm,
        vertical: LyraSpacing.xs + 2.0,
      ),
      decoration: BoxDecoration(
        color: emeraldColor.withValues(alpha: 0.08),
        borderRadius: LyraRadius.smRadius,
        border: Border.all(
          color: emeraldColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
            decoration: BoxDecoration(
              color: emeraldColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3.0),
            ),
            child: const Text(
              '+',
              style: TextStyle(
                color: emeraldColor,
                fontWeight: FontWeight.bold,
                fontSize: 12.0,
              ),
            ),
          ),
          const SizedBox(width: LyraSpacing.xs),
          Expanded(
            child: Text(
              newValue,
              style: LyraTypography.small(tokens).copyWith(
                color: emeraldColor,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
