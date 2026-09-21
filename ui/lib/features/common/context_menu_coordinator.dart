// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

export 'package:shadcn_ui/shadcn_ui.dart'
    show ShadContextMenuController, ShadContextMenuRegion, ShadContextMenuItem;

typedef LyraContextMenuController = ShadContextMenuController;
typedef LyraContextMenuRegion = ShadContextMenuRegion;
typedef LyraContextMenuItem = ShadContextMenuItem;

/// Unified coordinator to manage active context menu state across all list views
/// and tables in Lyra desktop client.
class LyraContextMenuCoordinator {
  LyraContextMenuCoordinator._();

  static ShadContextMenuController? _activeController;

  static void setActive(ShadContextMenuController controller) {
    if (_activeController != null && _activeController != controller) {
      _activeController!.hide();
    }
    _activeController = controller;
  }

  static void hideActive() {
    if (_activeController != null) {
      _activeController!.hide();
      _activeController = null;
    }
  }

  static void onDisposed(ShadContextMenuController controller) {
    if (controller.isOpen) {
      controller.hide();
    }
    if (_activeController == controller) {
      _activeController = null;
    }
  }

  static bool isActive(ShadContextMenuController controller) =>
      _activeController == controller;

  @visibleForTesting
  static ShadContextMenuController? get activeController => _activeController;

  @visibleForTesting
  static void resetForTesting() {
    _activeController = null;
  }
}
