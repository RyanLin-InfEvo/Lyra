// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_input.dart';

/// Top header bar containing search bar, theme switcher, and quick import action.
class LyraHeaderBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onImportPressed;

  const LyraHeaderBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onImportPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scope = LyraDesignSystemScope.of(context);
    final tokens = scope.tokens;

    return Container(
      height: 64.0,
      padding: const EdgeInsets.symmetric(horizontal: LyraSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(bottom: BorderSide(color: tokens.border, width: 1.0)),
      ),
      child: Row(
        children: [
          // Search Input
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420.0),
              child: LyraInput(
                controller: searchController,
                placeholder: 'Search library, tracks, albums, artists...',
                onChanged: onSearchChanged,
                leading: Icon(
                  LucideIcons.search,
                  size: 16.0,
                  color: tokens.textMuted,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Theme Toggle
          LyraButton.outline(
            size: LyraButtonSize.sm,
            onPressed: () => scope.toggleTheme(),
            child: Icon(
              tokens.isDark ? LucideIcons.sun : LucideIcons.moon,
              size: 16.0,
              color: tokens.text,
            ),
          ),

          const SizedBox(width: LyraSpacing.md),

          // Import Audio Button
          LyraButton(
            size: LyraButtonSize.sm,
            onPressed: onImportPressed,
            leading: const Icon(LucideIcons.upload, size: 16.0),
            child: const Text('Import Audio'),
          ),
        ],
      ),
    );
  }
}
