// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../../design_system/widgets/lyra_dialog.dart';
import '../models/cas_object.dart';
import 'controllers/cas_controller.dart';
import 'controllers/database_explorer_controller.dart';
import 'widgets/cas_storage_tab.dart';
import 'widgets/database_explorer_tab.dart';

export 'controllers/cas_controller.dart';
export 'controllers/database_explorer_controller.dart';
export 'models/database_stats.dart';
export 'widgets/cas_storage_tab.dart';
export 'widgets/database_explorer_tab.dart';

/// Top-level workbench view for Content Addressable Storage, SQLite explorer, and backend settings.
class CasView extends StatefulWidget {
  final List<CasObject> casObjects;
  final VoidCallback? onVerifyAll;
  final ValueChanged<CasObject>? onInspectAsset;
  final CasController? controller;
  final DatabaseExplorerController? dbController;
  final CasTab? activeTab;
  final ValueChanged<CasTab>? onTabChanged;

  const CasView({
    super.key,
    required this.casObjects,
    this.onVerifyAll,
    this.onInspectAsset,
    this.controller,
    this.dbController,
    this.activeTab,
    this.onTabChanged,
  });

  @override
  State<CasView> createState() => _CasViewState();
}

class _CasViewState extends State<CasView> {
  CasController? _internalController;
  DatabaseExplorerController? _internalDbController;
  bool _showPruneDialog = false;
  bool _showClearWaveformsDialog = false;

  CasController get _effectiveController =>
      widget.controller ?? _internalController!;

  DatabaseExplorerController get _effectiveDbController =>
      widget.dbController ?? _internalDbController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = CasController(
        initialTab: widget.activeTab ?? CasTab.storageOverview,
        initialObjects: widget.casObjects,
      );
    } else if (widget.activeTab != null) {
      widget.controller!.setTab(widget.activeTab!);
    }

    if (widget.dbController == null) {
      _internalDbController = DatabaseExplorerController();
    }
  }

  @override
  void didUpdateWidget(covariant CasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTab != null &&
        widget.activeTab != _effectiveController.activeTab) {
      _effectiveController.setTab(widget.activeTab!);
    }
    if (widget.controller == null) {
      if (_internalController == null) {
        _internalController = CasController(
          initialTab: widget.activeTab ?? CasTab.storageOverview,
          initialObjects: widget.casObjects,
        );
      } else if (oldWidget.casObjects != widget.casObjects) {
        _internalController!.setCasObjects(widget.casObjects);
      }
    } else if (_internalController != null) {
      _internalController!.dispose();
      _internalController = null;
    }

    if (widget.dbController == null) {
      _internalDbController ??= DatabaseExplorerController();
    } else if (_internalDbController != null) {
      _internalDbController!.dispose();
      _internalDbController = null;
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    _internalDbController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final controller = _effectiveController;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final title = switch (controller.activeTab) {
          CasTab.storageOverview => 'CAS Storage',
          CasTab.databaseExplorer => 'Database Explorer',
          CasTab.backendSettings => 'Engine Settings',
        };

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header (Apple HIG: Clean title)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LyraSpacing.xl,
                    vertical: LyraSpacing.lg,
                  ),
                  child: Text(
                    title,
                    style: LyraTypography.h2(tokens),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Active Tab Content (Navigation driven by Left Sidebar)
                Expanded(
                  child: switch (controller.activeTab) {
                    CasTab.storageOverview => CasStorageTab(
                      controller: controller,
                      onInspectAsset: widget.onInspectAsset,
                      onVerifyAll: widget.onVerifyAll,
                    ),
                    CasTab.databaseExplorer => DatabaseExplorerTab(
                      controller: _effectiveDbController,
                    ),
                    CasTab.backendSettings => _buildEngineSettingsPlaceholder(
                      tokens,
                      controller,
                    ),
                  },
                ),
              ],
            ),

            // Prune Orphans Confirmation Dialog
            if (_showPruneDialog) _buildPruneDialog(tokens, controller),

            // Clear Waveforms Confirmation Dialog
            if (_showClearWaveformsDialog)
              _buildClearWaveformsDialog(tokens, controller),
          ],
        );
      },
    );
  }

  Widget _buildPruneDialog(LyraThemeTokens tokens, CasController controller) {
    void dismiss() => setState(() => _showPruneDialog = false);
    return BlockSemantics(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): dismiss},
        child: Focus(
          autofocus: true,
          child: Container(
            color: const Color(0x80000000),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440.0),
              child: LyraDialog(
                onClose: dismiss,
                title: Text(
                  'Prune Orphaned Blobs',
                  style: LyraTypography.h3(tokens),
                ),
                description: Text(
                  'Are you sure you want to prune unreferenced orphaned blobs? '
                  'This will permanently reclaim ${controller.formattedOrphanedBytes} '
                  'across ${controller.orphanedCount} blobs from the storage pool.',
                  style: LyraTypography.muted(tokens),
                ),
                actions: [
                  LyraButton.ghost(
                    size: LyraButtonSize.sm,
                    onPressed: dismiss,
                    child: const Text('Cancel'),
                  ),
                  LyraButton.destructive(
                    size: LyraButtonSize.sm,
                    onPressed: () async {
                      dismiss();
                      await controller.pruneOrphans();
                    },
                    child: const Text('Confirm Prune'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearWaveformsDialog(
    LyraThemeTokens tokens,
    CasController controller,
  ) {
    void dismiss() => setState(() => _showClearWaveformsDialog = false);
    return BlockSemantics(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): dismiss},
        child: Focus(
          autofocus: true,
          child: Container(
            color: const Color(0x80000000),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440.0),
              child: LyraDialog(
                onClose: dismiss,
                title: Text(
                  'Clear Waveform Cache',
                  style: LyraTypography.h3(tokens),
                ),
                description: Text(
                  'Are you sure you want to clear the precomputed waveform cache '
                  '(${controller.formattedWaveformCacheBytes})? Waveforms will '
                  'be recomputed on demand during audio playback.',
                  style: LyraTypography.muted(tokens),
                ),
                actions: [
                  LyraButton.ghost(
                    size: LyraButtonSize.sm,
                    onPressed: dismiss,
                    child: const Text('Cancel'),
                  ),
                  LyraButton.destructive(
                    size: LyraButtonSize.sm,
                    onPressed: () async {
                      dismiss();
                      await controller.clearWaveforms();
                    },
                    child: const Text('Clear Cache'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngineSettingsPlaceholder(
    LyraThemeTokens tokens,
    CasController controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Storage & Cache Maintenance Card
          LyraCard(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Storage & Cache Maintenance',
                            style: LyraTypography.h4(tokens),
                          ),
                          const SizedBox(height: LyraSpacing.xs),
                          Text(
                            'Perform diagnostic verification, prune unreferenced blobs, or clear precomputed waveform caches.',
                            style: LyraTypography.muted(tokens),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LyraSpacing.lg),
                Wrap(
                  spacing: LyraSpacing.sm,
                  runSpacing: LyraSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LyraButton.outline(
                      size: LyraButtonSize.sm,
                      onPressed: controller.isVerifying
                          ? null
                          : () async {
                              await controller.verifyIntegrity();
                              if (mounted) {
                                widget.onVerifyAll?.call();
                              }
                            },
                      child: const Text('Verify Integrity'),
                    ),
                    LyraButton.outline(
                      size: LyraButtonSize.sm,
                      onPressed: controller.isPruning
                          ? null
                          : () => setState(() => _showPruneDialog = true),
                      child: Text(
                        controller.orphanedBytes > 0
                            ? 'Prune Orphans (${controller.formattedOrphanedBytes})'
                            : 'Prune Orphans',
                      ),
                    ),
                    LyraButton.outline(
                      size: LyraButtonSize.sm,
                      onPressed: controller.isClearingWaveforms
                          ? null
                          : () => setState(
                              () => _showClearWaveformsDialog = true,
                            ),
                      child: const Text('Clear Waveform Cache'),
                    ),
                  ],
                ),
                if (controller.isVerifying) ...[
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
                              '${(controller.verificationProgress * 100).toInt()}%',
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
                            value: controller.verificationProgress > 0.0
                                ? controller.verificationProgress
                                : null,
                            backgroundColor: tokens.card,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              tokens.primary,
                            ),
                            minHeight: 4.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Backend Engine Settings Overview Card
          LyraCard(
            padding: const EdgeInsets.all(LyraSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.settings, size: 36.0, color: tokens.textMuted),
                const SizedBox(height: LyraSpacing.md),
                Text(
                  'Backend Engine Settings',
                  style: LyraTypography.h3(tokens),
                ),
                const SizedBox(height: LyraSpacing.xs),
                Text(
                  'Audio hardware buffers, exclusive mode, database tuning, and ingestion pipeline.',
                  style: LyraTypography.muted(tokens),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: LyraSpacing.xl),
        ],
      ),
    );
  }
}
