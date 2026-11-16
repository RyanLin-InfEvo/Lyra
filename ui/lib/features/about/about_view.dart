// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_brand_logo.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../../design_system/widgets/lyra_copy_button.dart';
import '../../design_system/widgets/lyra_tooltip.dart';
import 'lyra_licenses.dart';

/// About view showcasing the animated Lyra brand mark, theme-adaptive banner,
/// and core architectural metadata.
class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  final GlobalKey<LyraBrandLogoState> _logoKey =
      GlobalKey<LyraBrandLogoState>();

  static const String _uiVersion = 'v0.0.1';
  static const String _coreVersion = '—';
  static const String _versionDisplay = 'UI $_uiVersion · Core $_coreVersion';
  static const String _repoDisplay = 'github.com/RyanLin-InfEvo/Lyra';
  static const String _repoUrl = 'https://github.com/RyanLin-InfEvo/Lyra';

  @override
  void initState() {
    super.initState();
    registerLyraLicenses();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LyraDesignSystemScope.of(context).tokens;
    final bannerAsset = tokens.isDark
        ? 'assets/visual-designs/lyra-dark-banner.svg'
        : 'assets/visual-designs/lyra-light-banner.svg';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.xl,
        vertical: LyraSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('About', style: LyraTypography.h2(tokens)),
              const SizedBox(height: LyraSpacing.lg),

              // Hero card with animated brand mark (tap logo to replay)
              LyraCard(
                width: double.infinity,
                padding: const EdgeInsets.all(LyraSpacing.xl),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 480.0;
                    final logo = LyraTooltip(
                      message: 'Try to click me!',
                      child: LyraBrandLogo(
                        key: _logoKey,
                        size: 112.0,
                        animated: true,
                        borderRadius: 22.0,
                        onTap: () => _logoKey.currentState?.replay(),
                      ),
                    );

                    final details = Column(
                      crossAxisAlignment: isCompact
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lyra',
                          style: LyraTypography.h1(
                            tokens,
                          ).copyWith(letterSpacing: -0.5),
                        ),
                        const SizedBox(height: LyraSpacing.xs),
                        Text(
                          'The Ultimate Music Hub',
                          textAlign: isCompact
                              ? TextAlign.center
                              : TextAlign.start,
                          style: LyraTypography.p(
                            tokens,
                          ).copyWith(color: tokens.textMuted),
                        ),
                        const SizedBox(height: LyraSpacing.md),
                        LyraButton.outline(
                          key: const Key('about_licenses_button'),
                          size: LyraButtonSize.sm,
                          onPressed: () {
                            final baseColorScheme = tokens.isDark
                                ? ColorScheme.dark(
                                    surface: tokens.background,
                                    onSurface: tokens.text,
                                    primary: tokens.primary,
                                    onPrimary: tokens.primaryForeground,
                                  )
                                : ColorScheme.light(
                                    surface: tokens.background,
                                    onSurface: tokens.text,
                                    primary: tokens.primary,
                                    onPrimary: tokens.primaryForeground,
                                  );
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => Theme(
                                  data: ThemeData(
                                    useMaterial3: true,
                                    brightness: tokens.isDark
                                        ? Brightness.dark
                                        : Brightness.light,
                                    colorScheme: baseColorScheme,
                                    scaffoldBackgroundColor: tokens.background,
                                  ),
                                  child: const LicensePage(
                                    applicationName: 'Lyra',
                                    applicationVersion: _versionDisplay,
                                  ),
                                ),
                              ),
                            );
                          },
                          leading: Icon(
                            LucideIcons.fileText,
                            size: 14.0,
                            color: tokens.text,
                          ),
                          child: const Text('Licenses'),
                        ),
                      ],
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          logo,
                          const SizedBox(height: LyraSpacing.lg),
                          details,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        logo,
                        const SizedBox(width: LyraSpacing.xl),
                        Expanded(child: details),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: LyraSpacing.lg),

              // Theme-adaptive brand banner
              LyraCard(
                width: double.infinity,
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(LyraRadius.lg),
                  child: AspectRatio(
                    aspectRatio: 16.0 / 9.0,
                    child: SvgPicture.asset(
                      bannerAsset,
                      key: ValueKey(bannerAsset),
                      fit: BoxFit.contain,
                      semanticsLabel: 'Lyra brand banner',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: LyraSpacing.lg),

              // System & Project info
              LyraCard(
                width: double.infinity,
                padding: const EdgeInsets.all(LyraSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoRow(
                      tokens: tokens,
                      label: 'Version',
                      value: _versionDisplay,
                    ),
                    _InfoDivider(tokens: tokens),
                    _InfoRow(
                      tokens: tokens,
                      label: 'Architecture',
                      value: 'C++20 Core · Flutter UI',
                    ),
                    _InfoDivider(tokens: tokens),
                    _InfoRow(
                      tokens: tokens,
                      label: 'License',
                      value: 'AGPL-3.0-or-later',
                    ),
                    _InfoDivider(tokens: tokens),
                    _InfoRow(
                      tokens: tokens,
                      label: 'Repository',
                      value: _repoDisplay,
                      trailing: const LyraCopyButton(
                        text: _repoUrl,
                        tooltip: 'Copy repository URL',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final LyraThemeTokens tokens;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.tokens,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LyraSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420.0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted),
                ),
                const SizedBox(height: 2.0),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: LyraTypography.small(
                          tokens,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: LyraSpacing.sm),
                      trailing!,
                    ],
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 132.0,
                child: Text(
                  label,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(color: tokens.textMuted),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: LyraTypography.small(
                    tokens,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: LyraSpacing.sm),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  final LyraThemeTokens tokens;

  const _InfoDivider({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1.0, color: tokens.border);
  }
}
