// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_badge.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';

/// Settings view managing Theme options, Audio Output, and CAS Storage preferences.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _exclusiveMode = true;
  bool _dopEnabled = false;
  int _bufferSize = 128;
  bool _autoVerify = true;

  @override
  Widget build(BuildContext context) {
    final scope = LyraDesignSystemScope.of(context);
    final tokens = scope.tokens;
    final currentThemeMode = scope.themeModeNotifier.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.xl,
        vertical: LyraSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Settings', style: LyraTypography.h2(tokens)),
          const SizedBox(height: LyraSpacing.xs),
          Text(
            'Appearance, Audio, and Storage preferences',
            style: LyraTypography.muted(tokens),
          ),

          const SizedBox(height: LyraSpacing.xl),

          // Appearance Section
          LyraCard(
            padding: const EdgeInsets.all(LyraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.palette,
                      size: 20.0,
                      color: tokens.primary,
                    ),
                    const SizedBox(width: LyraSpacing.sm),
                    Text('Appearance', style: LyraTypography.h3(tokens)),
                  ],
                ),
                const SizedBox(height: LyraSpacing.xs),
                Text(
                  'Customize the desktop client theme tokens and palette.',
                  style: LyraTypography.muted(tokens),
                ),
                const SizedBox(height: LyraSpacing.lg),
                Row(
                  children: [
                    _ThemeOptionCard(
                      label: 'Zinc Dark',
                      mode: ThemeMode.dark,
                      isSelected: currentThemeMode == ThemeMode.dark,
                      onTap: () => scope.setThemeMode(ThemeMode.dark),
                      tokens: tokens,
                    ),
                    const SizedBox(width: LyraSpacing.md),
                    _ThemeOptionCard(
                      label: 'Zinc Light',
                      mode: ThemeMode.light,
                      isSelected: currentThemeMode == ThemeMode.light,
                      onTap: () => scope.setThemeMode(ThemeMode.light),
                      tokens: tokens,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: LyraSpacing.lg),

          // Audio Output Section
          LyraCard(
            padding: const EdgeInsets.all(LyraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.sliders,
                      size: 20.0,
                      color: tokens.primary,
                    ),
                    const SizedBox(width: LyraSpacing.sm),
                    Text('Audio Output', style: LyraTypography.h3(tokens)),
                    const Spacer(),
                    LyraBadge.success(child: const Text('Exclusive Mode')),
                  ],
                ),
                const SizedBox(height: LyraSpacing.xs),
                Text(
                  'Hardware stream delivery and buffer configuration.',
                  style: LyraTypography.muted(tokens),
                ),
                const SizedBox(height: LyraSpacing.lg),

                // Exclusive Mode toggle
                _SettingRow(
                  title: 'Exclusive Mode',
                  description:
                      'Bypass system mixer for direct hardware stream delivery',
                  trailing: LyraButton(
                    size: LyraButtonSize.sm,
                    variant: _exclusiveMode
                        ? LyraButtonVariant.primary
                        : LyraButtonVariant.outline,
                    onPressed: () =>
                        setState(() => _exclusiveMode = !_exclusiveMode),
                    child: Text(_exclusiveMode ? 'Enabled' : 'Disabled'),
                  ),
                  tokens: tokens,
                ),

                const SizedBox(height: LyraSpacing.md),

                // Buffer Size selector
                _SettingRow(
                  title: 'Buffer Size',
                  description:
                      'Lower buffer decreases latency; higher buffer prevents underruns',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [64, 128, 256, 512].map((buf) {
                      final isSel = _bufferSize == buf;
                      return Padding(
                        padding: const EdgeInsets.only(left: LyraSpacing.xs),
                        child: LyraButton(
                          size: LyraButtonSize.sm,
                          variant: isSel
                              ? LyraButtonVariant.primary
                              : LyraButtonVariant.outline,
                          onPressed: () => setState(() => _bufferSize = buf),
                          child: Text('$buf'),
                        ),
                      );
                    }).toList(),
                  ),
                  tokens: tokens,
                ),

                const SizedBox(height: LyraSpacing.md),

                // DSD over PCM (DoP)
                _SettingRow(
                  title: 'DSD over PCM (DoP)',
                  description:
                      'Encapsulate DSD stream payload inside PCM frames',
                  trailing: LyraButton(
                    size: LyraButtonSize.sm,
                    variant: _dopEnabled
                        ? LyraButtonVariant.primary
                        : LyraButtonVariant.outline,
                    onPressed: () => setState(() => _dopEnabled = !_dopEnabled),
                    child: Text(_dopEnabled ? 'Enabled' : 'Disabled'),
                  ),
                  tokens: tokens,
                ),
              ],
            ),
          ),

          const SizedBox(height: LyraSpacing.lg),

          // CAS Storage Section
          LyraCard(
            padding: const EdgeInsets.all(LyraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.hardDrive,
                      size: 20.0,
                      color: tokens.primary,
                    ),
                    const SizedBox(width: LyraSpacing.sm),
                    Text('CAS Storage', style: LyraTypography.h3(tokens)),
                  ],
                ),
                const SizedBox(height: LyraSpacing.xs),
                Text(
                  'Content-addressable storage block verification and deduplication policies.',
                  style: LyraTypography.muted(tokens),
                ),
                const SizedBox(height: LyraSpacing.lg),

                _SettingRow(
                  title: 'Verify SHA-256 on import',
                  description:
                      'Compute cryptographic checksum when adding audio tracks',
                  trailing: LyraButton(
                    size: LyraButtonSize.sm,
                    variant: _autoVerify
                        ? LyraButtonVariant.primary
                        : LyraButtonVariant.outline,
                    onPressed: () => setState(() => _autoVerify = !_autoVerify),
                    child: Text(_autoVerify ? 'Active' : 'Bypass'),
                  ),
                  tokens: tokens,
                ),

                const SizedBox(height: LyraSpacing.md),

                _SettingRow(
                  title: 'Deduplication Policy',
                  description:
                      'Identical audio files share the same content-addressable storage block',
                  trailing: LyraBadge.secondary(
                    child: const Text('Block-level CAS'),
                  ),
                  tokens: tokens,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String description;
  final Widget trailing;
  final LyraThemeTokens tokens;

  const _SettingRow({
    required this.title,
    required this.description,
    required this.trailing,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: LyraTypography.p(
                  tokens,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                description,
                style: LyraTypography.small(
                  tokens,
                ).copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: LyraSpacing.md),
        trailing,
      ],
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _ThemeOptionCard({
    required this.label,
    required this.mode,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 140.0,
        padding: const EdgeInsets.all(LyraSpacing.md),
        decoration: BoxDecoration(
          color: mode == ThemeMode.dark
              ? LyraColors.zinc950
              : const Color(0xFFFFFFFF),
          borderRadius: LyraRadius.mdRadius,
          border: Border.all(
            color: isSelected ? tokens.ring : tokens.border,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  mode == ThemeMode.dark ? LucideIcons.moon : LucideIcons.sun,
                  size: 16.0,
                  color: mode == ThemeMode.dark
                      ? LyraColors.zinc50
                      : LyraColors.zinc950,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    LucideIcons.check,
                    size: 14.0,
                    color: mode == ThemeMode.dark
                        ? LyraColors.zinc50
                        : LyraColors.zinc950,
                  ),
              ],
            ),
            const SizedBox(height: LyraSpacing.md),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: mode == ThemeMode.dark
                    ? LyraColors.zinc50
                    : LyraColors.zinc950,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
