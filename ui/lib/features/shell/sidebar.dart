// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';

/// Navigation tabs available in Lyra Desktop.
enum AppTab { tracks, albums, artists, casStorage, settings }

/// Collapsible desktop sidebar navigation.
class LyraSidebar extends StatelessWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const LyraSidebar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 64.0 : 210.0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(right: BorderSide(color: tokens.border, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Logo
          RepaintBoundary(
            child: Container(
              height: 64.0,
              padding: isCollapsed
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: LyraSpacing.md),
              alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tokens.border, width: 1.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 32.0,
                    height: 32.0,
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      borderRadius: LyraRadius.mdRadius,
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.music,
                        size: 18.0,
                        color: tokens.primaryForeground,
                      ),
                    ),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: LyraSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lyra Audio',
                            style: LyraTypography.h4(tokens),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Bit-Perfect CAS',
                            style: LyraTypography.small(
                              tokens,
                            ).copyWith(color: tokens.textMuted, fontSize: 10.0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: LyraSpacing.lg),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.sm),
              children: [
                if (!isCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: LyraSpacing.sm,
                      bottom: LyraSpacing.xs,
                    ),
                    child: Text(
                      'LIBRARY',
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                _buildNavItem(
                  context: context,
                  tokens: tokens,
                  tab: AppTab.tracks,
                  icon: LucideIcons.listMusic,
                  label: 'Tracks',
                ),
                _buildNavItem(
                  context: context,
                  tokens: tokens,
                  tab: AppTab.albums,
                  icon: LucideIcons.disc,
                  label: 'Albums',
                ),
                _buildNavItem(
                  context: context,
                  tokens: tokens,
                  tab: AppTab.artists,
                  icon: LucideIcons.mic,
                  label: 'Artists',
                ),
                const SizedBox(height: LyraSpacing.lg),
                if (!isCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: LyraSpacing.sm,
                      bottom: LyraSpacing.xs,
                    ),
                    child: Text(
                      'SYSTEM',
                      style: LyraTypography.small(tokens).copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                _buildNavItem(
                  context: context,
                  tokens: tokens,
                  tab: AppTab.casStorage,
                  icon: LucideIcons.hardDrive,
                  label: 'CAS Storage',
                ),
                _buildNavItem(
                  context: context,
                  tokens: tokens,
                  tab: AppTab.settings,
                  icon: LucideIcons.settings,
                  label: 'Settings',
                ),
              ],
            ),
          ),

          // Collapse Toggle Button
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(LyraSpacing.sm),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: tokens.border, width: 1.0),
                ),
              ),
              child: LyraButton.ghost(
                width: double.infinity,
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                padding: isCollapsed
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(
                        horizontal: LyraSpacing.sm,
                        vertical: LyraSpacing.xs,
                      ),
                onPressed: onToggleCollapse,
                leading: Icon(
                  isCollapsed
                      ? LucideIcons.chevronRight
                      : LucideIcons.chevronLeft,
                  size: 16.0,
                  color: tokens.textMuted,
                ),
                child: isCollapsed
                    ? null
                    : Text(
                        'Collapse',
                        style: LyraTypography.small(
                          tokens,
                        ).copyWith(color: tokens.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required LyraThemeTokens tokens,
    required AppTab tab,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentTab == tab;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: LyraButton(
          width: double.infinity,
          mainAxisAlignment: isCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          variant: isSelected
              ? LyraButtonVariant.secondary
              : LyraButtonVariant.ghost,
          padding: isCollapsed
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: LyraSpacing.sm,
                  vertical: LyraSpacing.xs,
                ),
          onPressed: () => onTabSelected(tab),
          leading: Icon(
            icon,
            size: 18.0,
            color: isSelected ? tokens.text : tokens.textMuted,
          ),
          child: isCollapsed
              ? null
              : Text(
                  label,
                  style: LyraTypography.small(tokens).copyWith(
                    fontSize: 13.0,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? tokens.text : tokens.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}
