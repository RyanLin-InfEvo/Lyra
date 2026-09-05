// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../models/playlist.dart';
import '../models/tag.dart';

/// Navigation tabs available in Lyra Desktop.
enum AppTab {
  tracks,
  works,
  albums,
  artists,
  playlists,
  tags,
  casStorage,
  settings,
}

/// Collapsible desktop sidebar navigation with Library, Playlists, Tags, and System sections.
class LyraSidebar extends StatefulWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final List<Playlist> playlists;
  final String? selectedPlaylistId;
  final ValueChanged<Playlist>? onPlaylistSelected;
  final List<Tag> tags;
  final String? selectedTagId;
  final ValueChanged<Tag>? onTagSelected;
  final VoidCallback? onTagsHeaderSelected;
  final bool defaultPlaylistsExpanded;
  final bool defaultTagsExpanded;

  const LyraSidebar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.playlists = const [],
    this.selectedPlaylistId,
    this.onPlaylistSelected,
    this.tags = const [],
    this.selectedTagId,
    this.onTagSelected,
    this.onTagsHeaderSelected,
    this.defaultPlaylistsExpanded = true,
    this.defaultTagsExpanded = true,
  });

  @override
  State<LyraSidebar> createState() => _LyraSidebarState();
}

class _LyraSidebarState extends State<LyraSidebar> {
  late bool _isPlaylistsExpanded;
  late bool _isTagsExpanded;

  @override
  void initState() {
    super.initState();
    _isPlaylistsExpanded = widget.defaultPlaylistsExpanded;
    _isTagsExpanded = widget.defaultTagsExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.isCollapsed ? 64.0 : 210.0,
      child: Container(
        key: const Key('sidebar_inner_container'),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border(right: BorderSide(color: tokens.border, width: 1.0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / Logo
            Container(
              height: 64.0,
              padding: widget.isCollapsed
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: LyraSpacing.md),
              alignment: widget.isCollapsed
                  ? Alignment.center
                  : Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tokens.border, width: 1.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: widget.isCollapsed
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
                  if (!widget.isCollapsed) ...[
                    const SizedBox(width: LyraSpacing.sm),
                    Expanded(
                      child: Text(
                        'Lyra Audio',
                        style: LyraTypography.h4(tokens),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Navigation Sections
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: LyraSpacing.sm,
                  vertical: LyraSpacing.xs,
                ),
                children: [
                  // 1. LIBRARY SECTION
                  if (!widget.isCollapsed)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: LyraSpacing.sm,
                        top: LyraSpacing.xs,
                        bottom: 2.0,
                      ),
                      child: Text(
                        'LIBRARY',
                        style: LyraTypography.small(tokens).copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontSize: 10.0,
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
                    tab: AppTab.works,
                    icon: LucideIcons.layers,
                    label: 'Works',
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

                  // PLAYLISTS (First-class nav button with expandable sub-items)
                  if (!widget.isCollapsed) ...[
                    _buildExpandableNavItem(
                      context: context,
                      tokens: tokens,
                      tab: AppTab.playlists,
                      icon: LucideIcons.listPlus,
                      label: 'Playlists',
                      isExpanded: _isPlaylistsExpanded,
                      hasSubItems: widget.playlists.isNotEmpty,
                      onToggle: () {
                        setState(() {
                          _isPlaylistsExpanded = !_isPlaylistsExpanded;
                        });
                      },
                      chevronKey: const Key('playlists_header_chevron'),
                    ),
                    if (_isPlaylistsExpanded) ...[
                      for (final playlist in widget.playlists)
                        _buildPlaylistItem(
                          context: context,
                          tokens: tokens,
                          playlist: playlist,
                        ),
                    ],
                  ] else ...[
                    _buildNavItem(
                      context: context,
                      tokens: tokens,
                      tab: AppTab.playlists,
                      icon: LucideIcons.listPlus,
                      label: 'Playlists',
                    ),
                  ],

                  // TAGS (First-class nav button with expandable sub-items)
                  if (!widget.isCollapsed) ...[
                    _buildExpandableNavItem(
                      context: context,
                      tokens: tokens,
                      tab: AppTab.tags,
                      icon: LucideIcons.tag,
                      label: 'Tags',
                      isExpanded: _isTagsExpanded,
                      hasSubItems: widget.tags.isNotEmpty,
                      onToggle: () {
                        setState(() {
                          _isTagsExpanded = !_isTagsExpanded;
                        });
                      },
                      chevronKey: const Key('tags_header_chevron'),
                      onHeaderClick: widget.onTagsHeaderSelected,
                    ),
                    if (_isTagsExpanded) ...[
                      for (final tag in widget.tags)
                        _buildTagItem(
                          context: context,
                          tokens: tokens,
                          tag: tag,
                        ),
                    ],
                  ] else ...[
                    _buildNavItem(
                      context: context,
                      tokens: tokens,
                      tab: AppTab.tags,
                      icon: LucideIcons.tag,
                      label: 'Tags',
                    ),
                  ],

                  const SizedBox(height: LyraSpacing.sm),

                  // 2. SYSTEM SECTION
                  if (!widget.isCollapsed)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: LyraSpacing.sm,
                        top: LyraSpacing.xs,
                        bottom: 2.0,
                      ),
                      child: Text(
                        'SYSTEM',
                        style: LyraTypography.small(tokens).copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontSize: 10.0,
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
            Container(
              padding: const EdgeInsets.all(LyraSpacing.sm),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: tokens.border, width: 1.0),
                ),
              ),
              child: LyraButton.ghost(
                width: double.infinity,
                size: LyraButtonSize.sm,
                mainAxisAlignment: widget.isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                padding: widget.isCollapsed
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(
                        horizontal: LyraSpacing.sm,
                        vertical: LyraSpacing.xs,
                      ),
                onPressed: widget.onToggleCollapse,
                leading: Icon(
                  widget.isCollapsed
                      ? LucideIcons.chevronRight
                      : LucideIcons.chevronLeft,
                  size: 16.0,
                  color: tokens.textMuted,
                ),
                child: widget.isCollapsed
                    ? null
                    : Flexible(
                        child: Text(
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
      ),
    );
  }

  Widget _buildExpandableNavItem({
    required BuildContext context,
    required LyraThemeTokens tokens,
    required AppTab tab,
    required IconData icon,
    required String label,
    required bool isExpanded,
    required bool hasSubItems,
    required VoidCallback onToggle,
    required Key chevronKey,
    VoidCallback? onHeaderClick,
  }) {
    final isSelected = widget.currentTab == tab;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          LyraButton(
            width: double.infinity,
            size: LyraButtonSize.sm,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            variant: isSelected
                ? LyraButtonVariant.secondary
                : LyraButtonVariant.ghost,
            padding: EdgeInsets.only(
              left: LyraSpacing.sm,
              right: hasSubItems ? 28.0 : LyraSpacing.sm,
              top: LyraSpacing.xs,
              bottom: LyraSpacing.xs,
            ),
            onPressed: onHeaderClick ?? () => widget.onTabSelected(tab),
            leading: Icon(
              icon,
              size: 16.0,
              color: isSelected ? tokens.text : tokens.textMuted,
            ),
            child: Flexible(
              child: Text(
                label,
                style: LyraTypography.small(tokens).copyWith(
                  fontSize: 13.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? tokens.text : tokens.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (hasSubItems)
            Positioned(
              right: 4.0,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: chevronKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      isExpanded
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronRight,
                      size: 14.0,
                      color: tokens.textMuted,
                    ),
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
    final isSelected = widget.currentTab == tab;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: LyraButton(
        width: double.infinity,
        size: LyraButtonSize.sm,
        mainAxisAlignment: widget.isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        variant: isSelected
            ? LyraButtonVariant.secondary
            : LyraButtonVariant.ghost,
        padding: widget.isCollapsed
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(
                horizontal: LyraSpacing.sm,
                vertical: LyraSpacing.xs,
              ),
        onPressed: () => widget.onTabSelected(tab),
        leading: Icon(
          icon,
          size: 16.0,
          color: isSelected ? tokens.text : tokens.textMuted,
        ),
        child: widget.isCollapsed
            ? null
            : Flexible(
                child: Text(
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

  Widget _buildPlaylistItem({
    required BuildContext context,
    required LyraThemeTokens tokens,
    required Playlist playlist,
  }) {
    final isSelected =
        widget.currentTab == AppTab.playlists &&
        widget.selectedPlaylistId == playlist.id;

    return Padding(
      padding: const EdgeInsets.only(
        left: LyraSpacing.sm,
        top: 1.0,
        bottom: 1.0,
      ),
      child: LyraButton(
        width: double.infinity,
        size: LyraButtonSize.sm,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        variant: isSelected
            ? LyraButtonVariant.secondary
            : LyraButtonVariant.ghost,
        padding: const EdgeInsets.symmetric(
          horizontal: LyraSpacing.sm,
          vertical: LyraSpacing.xs,
        ),
        onPressed: () {
          widget.onPlaylistSelected?.call(playlist);
          widget.onTabSelected(AppTab.playlists);
        },
        leading: Icon(
          LucideIcons.list,
          size: 14.0,
          color: isSelected ? tokens.text : tokens.textMuted,
        ),
        child: Flexible(
          child: Text(
            playlist.displayTitle,
            style: LyraTypography.small(tokens).copyWith(
              fontSize: 13.0,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? tokens.text : tokens.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildTagItem({
    required BuildContext context,
    required LyraThemeTokens tokens,
    required Tag tag,
  }) {
    final isSelected =
        widget.currentTab == AppTab.tracks && widget.selectedTagId == tag.id;

    return Padding(
      padding: const EdgeInsets.only(
        left: LyraSpacing.sm,
        top: 1.0,
        bottom: 1.0,
      ),
      child: LyraButton(
        width: double.infinity,
        size: LyraButtonSize.sm,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        variant: isSelected
            ? LyraButtonVariant.secondary
            : LyraButtonVariant.ghost,
        padding: const EdgeInsets.symmetric(
          horizontal: LyraSpacing.sm,
          vertical: LyraSpacing.xs,
        ),
        onPressed: () {
          widget.onTagSelected?.call(tag);
        },
        leading: Icon(
          LucideIcons.tag,
          size: 14.0,
          color: isSelected ? tokens.text : tokens.textMuted,
        ),
        child: Flexible(
          child: Text(
            tag.displayName,
            style: LyraTypography.small(tokens).copyWith(
              fontSize: 13.0,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? tokens.text : tokens.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
