// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_dialog.dart';
import '../models/cas_object.dart';
import 'controllers/backend_settings_controller.dart';
import 'controllers/cas_controller.dart';
import 'controllers/database_explorer_controller.dart';
import 'widgets/backend_settings_tab.dart';
import 'widgets/cas_storage_tab.dart';
import 'widgets/database_explorer_tab.dart';

export 'controllers/backend_settings_controller.dart';
export 'controllers/cas_controller.dart';
export 'controllers/database_explorer_controller.dart';
export 'models/database_stats.dart';
export 'models/engine_config.dart';
export 'widgets/backend_settings_tab.dart';
export 'widgets/cas_storage_tab.dart';
export 'widgets/database_explorer_tab.dart';

/// Top-level workbench view for Content Addressable Storage, SQLite explorer, and backend settings.
class CasView extends StatefulWidget {
  final List<CasObject> casObjects;
  final VoidCallback? onVerifyAll;
  final ValueChanged<CasObject>? onInspectAsset;
  final CasController? controller;
  final DatabaseExplorerController? dbController;
  final BackendSettingsController? backendSettingsController;
  final CasTab? activeTab;
  final ValueChanged<CasTab>? onTabChanged;

  const CasView({
    super.key,
    required this.casObjects,
    this.onVerifyAll,
    this.onInspectAsset,
    this.controller,
    this.dbController,
    this.backendSettingsController,
    this.activeTab,
    this.onTabChanged,
  });

  @override
  State<CasView> createState() => _CasViewState();
}

class _CasViewState extends State<CasView> {
  CasController? _internalController;
  DatabaseExplorerController? _internalDbController;
  BackendSettingsController? _internalBackendSettingsController;
  bool _showPruneDialog = false;
  bool _showClearWaveformsDialog = false;

  CasController get _effectiveController =>
      widget.controller ?? _internalController!;

  DatabaseExplorerController get _effectiveDbController =>
      widget.dbController ?? _internalDbController!;

  BackendSettingsController get _effectiveBackendSettingsController =>
      widget.backendSettingsController ?? _internalBackendSettingsController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = CasController(
        initialTab: widget.activeTab ?? CasTab.storageOverview,
        initialObjects: widget.casObjects,
      );
    } else {
      if (widget.activeTab != null) {
        widget.controller!.setTab(widget.activeTab!);
      }
      if (widget.casObjects.isNotEmpty &&
          widget.controller!.casObjects.isEmpty) {
        widget.controller!.setCasObjects(widget.casObjects);
      }
    }

    if (widget.dbController == null) {
      _internalDbController = DatabaseExplorerController();
    }

    if (widget.backendSettingsController == null) {
      _internalBackendSettingsController = BackendSettingsController();
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
    } else {
      if (_internalController != null) {
        _internalController!.dispose();
        _internalController = null;
      }
      if (oldWidget.casObjects != widget.casObjects) {
        _effectiveController.setCasObjects(widget.casObjects);
      }
    }

    if (widget.dbController == null) {
      _internalDbController ??= DatabaseExplorerController();
    } else if (_internalDbController != null) {
      _internalDbController!.dispose();
      _internalDbController = null;
    }

    if (widget.backendSettingsController == null) {
      _internalBackendSettingsController ??= BackendSettingsController();
    } else if (_internalBackendSettingsController != null) {
      _internalBackendSettingsController!.dispose();
      _internalBackendSettingsController = null;
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    _internalDbController?.dispose();
    _internalBackendSettingsController?.dispose();
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
                  child: IndexedStack(
                    index: switch (controller.activeTab) {
                      CasTab.storageOverview => 0,
                      CasTab.databaseExplorer => 1,
                      CasTab.backendSettings => 2,
                    },
                    children: [
                      CasStorageTab(
                        controller: controller,
                        onInspectAsset: widget.onInspectAsset,
                        onVerifyAll: widget.onVerifyAll,
                      ),
                      DatabaseExplorerTab(controller: _effectiveDbController),
                      BackendSettingsTab(
                        controller: _effectiveBackendSettingsController,
                        casController: controller,
                        onVerifyAll: widget.onVerifyAll,
                        onRequestPrune: () =>
                            setState(() => _showPruneDialog = true),
                        onRequestClearWaveforms: () =>
                            setState(() => _showClearWaveformsDialog = true),
                      ),
                    ],
                  ),
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
}
