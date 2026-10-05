// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';
import '../tokens/lyra_tokens.dart';

/// Specification for a single navigation section in [LyraSettingsLayout].
class LyraSettingsSection<T> {
  /// Unique identifier of the section (typically an enum value or string).
  final T id;

  /// Human-readable label displayed in the master navigation list.
  final String label;

  /// Icon representing the section in the navigation list.
  final IconData icon;

  /// Builder returning the detail content widget for this section.
  final WidgetBuilder builder;

  /// Optional secondary description displayed under the section label.
  final String? description;

  /// Optional trailing badge widget (e.g. [LyraBadge] or status indicator).
  final Widget? badge;

  const LyraSettingsSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.description,
    this.badge,
  });
}

/// Generic Master-Detail settings layout adhering to Apple Human Interface Guidelines
/// and Shadcn design principles.
///
/// Features a fixed-width left navigation pane listing [sections], and a right
/// content pane rendering the selected section's content in a scrollable area.
///
/// Supports an optional top [title], [subtitle], and [headerAction], as well as
/// a sticky [bottomBar] slot for action buttons and dirty state notifications.
class LyraSettingsLayout<T> extends StatelessWidget {
  /// Optional primary title for the view header.
  final String? title;

  /// Optional explanatory subtitle under [title].
  final String? subtitle;

  /// List of navigation sections available in the master pane.
  final List<LyraSettingsSection<T>> sections;

  /// The currently active section ID.
  final T selectedSection;

  /// Callback invoked when the user selects a section from the master list.
  final ValueChanged<T> onSectionChanged;

  /// Optional trailing action widget in the header row.
  final Widget? headerAction;

  /// Optional sticky action bar widget pinned to the bottom of the content area.
  final Widget? bottomBar;

  /// Width of the left navigation sidebar. Defaults to `210.0`.
  final double sidebarWidth;

  /// Optional maximum width constraint for the right content container.
  final double? contentMaxWidth;

  /// Custom padding for the right scrollable content area.
  final EdgeInsetsGeometry? contentPadding;

  const LyraSettingsLayout({
    super.key,
    this.title,
    this.subtitle,
    required this.sections,
    required this.selectedSection,
    required this.onSectionChanged,
    this.headerAction,
    this.bottomBar,
    this.sidebarWidth = 210.0,
    this.contentMaxWidth,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final hasHeader =
            title != null || subtitle != null || headerAction != null;

        Widget? headerWidget;
        if (hasHeader) {
          headerWidget = Padding(
            padding: const EdgeInsets.fromLTRB(
              LyraSpacing.xl,
              LyraSpacing.lg,
              LyraSpacing.xl,
              LyraSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(title!, style: LyraTypography.h2(tokens)),
                      if (title != null && subtitle != null)
                        const SizedBox(height: LyraSpacing.xs),
                      if (subtitle != null)
                        Text(subtitle!, style: LyraTypography.muted(tokens)),
                    ],
                  ),
                ),
                ?headerAction,
              ],
            ),
          );
        }

        final divider = Container(height: 1.0, color: tokens.border);

        // Sidebar navigation list
        final sidebarItems = [
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: LyraSpacing.xs),
            _SettingsNavItem(
              label: sections[i].label,
              icon: sections[i].icon,
              description: sections[i].description,
              badge: sections[i].badge,
              isSelected: sections[i].id == selectedSection,
              onTap: () => onSectionChanged(sections[i].id),
              tokens: tokens,
            ),
          ],
        ];

        final leftNav = Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: tokens.border, width: 1.0)),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: LyraSpacing.md,
              vertical: LyraSpacing.md,
            ),
            shrinkWrap: !hasBoundedHeight,
            physics: hasBoundedHeight
                ? null
                : const NeverScrollableScrollPhysics(),
            children: sidebarItems,
          ),
        );

        // Empty sections fallback
        if (sections.isEmpty) {
          if (hasHeader) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerWidget!,
                divider,
                if (hasBoundedHeight)
                  const Expanded(child: SizedBox.shrink())
                else
                  const SizedBox.shrink(),
              ],
            );
          }
          return const SizedBox.shrink();
        }

        // Active detail content
        final activeSection = sections.firstWhere(
          (s) => s.id == selectedSection,
          orElse: () => sections.first,
        );

        Widget content = activeSection.builder(context);
        if (contentMaxWidth != null) {
          content = Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth!),
              child: content,
            ),
          );
        }

        final effectivePadding =
            contentPadding ??
            const EdgeInsets.only(
              left: LyraSpacing.xl,
              right: LyraSpacing.xl,
              top: LyraSpacing.lg,
              bottom: LyraSpacing.xl,
            );

        Widget rightPane;
        if (hasBoundedHeight) {
          rightPane = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: PageStorageKey<T>(activeSection.id),
                  padding: effectivePadding,
                  child: content,
                ),
              ),
              ?bottomBar,
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasHeader) ...[headerWidget!, divider],
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftNav,
                    Expanded(child: rightPane),
                  ],
                ),
              ),
            ],
          );
        } else {
          // Unbounded height container (flex-safe fallback)
          rightPane = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                key: PageStorageKey<T>(activeSection.id),
                padding: effectivePadding,
                child: content,
              ),
              ?bottomBar,
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasHeader) ...[headerWidget!, divider],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leftNav,
                  Expanded(child: rightPane),
                ],
              ),
            ],
          );
        }
      },
    );
  }
}

class _SettingsNavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? description;
  final Widget? badge;
  final bool isSelected;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _SettingsNavItem({
    required this.label,
    required this.icon,
    this.description,
    this.badge,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
  });

  @override
  State<_SettingsNavItem> createState() => _SettingsNavItemState();
}

class _SettingsNavItemState extends State<_SettingsNavItem> {
  bool _isHovered = false;
  bool _isFocused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final bg = tokens.itemBackground(
      isSelected: widget.isSelected,
      isHovered: _isHovered,
      isFocused: _isFocused,
    );

    final fg = widget.isSelected ? tokens.text : tokens.textMuted;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _isHovered = v),
        onShowFocusHighlight: (v) => setState(() => _isFocused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6.0),
              border: _isFocused
                  ? tokens.focusedRingBorder(width: 1.5)
                  : tokens.unfocusedRingBorder(width: 1.5),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 16.0, color: fg),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: fg,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.description != null &&
                          widget.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            widget.description!,
                            style: TextStyle(
                              fontSize: 11.0,
                              color: tokens.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.badge != null) ...[
                  const SizedBox(width: 6.0),
                  widget.badge!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
