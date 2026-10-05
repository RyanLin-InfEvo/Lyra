// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../../design_system/widgets/lyra_settings_layout.dart';
import '../../design_system/widgets/lyra_switch.dart';
import 'services/preferences_service.dart';

/// Available accent colors matching Shadcn Zinc design system palette.
class AccentColorOption {
  final String key;
  final String label;
  final Color color;

  const AccentColorOption({
    required this.key,
    required this.label,
    required this.color,
  });
}

const List<AccentColorOption> kAccentColorOptions = [
  AccentColorOption(key: 'zinc', label: 'Zinc', color: LyraColors.zinc400),
  AccentColorOption(key: 'slate', label: 'Slate', color: Color(0xFF64748B)),
  AccentColorOption(key: 'blue', label: 'Blue', color: LyraColors.blue500),
  AccentColorOption(
    key: 'emerald',
    label: 'Emerald',
    color: LyraColors.emerald500,
  ),
  AccentColorOption(key: 'violet', label: 'Violet', color: Color(0xFF8B5CF6)),
  AccentColorOption(key: 'rose', label: 'Rose', color: Color(0xFFF43F5E)),
  AccentColorOption(key: 'amber', label: 'Amber', color: LyraColors.amber500),
];

/// Sub-navigation section identifiers.
enum SettingsNavSection { appearance, waveform }

/// Waveform settings target view.
enum WaveformTarget { nowPlaying, inspector }

/// Settings view providing Master-Detail sub-navigation for Appearance and Waveform Visualization.
class SettingsView extends StatefulWidget {
  final PreferencesService? preferencesService;

  const SettingsView({super.key, this.preferencesService});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  SettingsNavSection _currentSection = SettingsNavSection.appearance;
  WaveformTarget _selectedTarget = WaveformTarget.nowPlaying;

  late bool _showNowPlayingWaveform;
  late bool _showInspectorWaveform;
  late int _nowPlayingWaveformPoints;
  late int _inspectorWaveformPoints;
  late bool _nowPlayingWaveformPulseAnimation;
  late bool _inspectorWaveformPulseAnimation;
  late bool _nowPlayingWaveformHoverTimeGuide;
  late bool _inspectorWaveformHoverTimeGuide;
  late String _accentColor;
  bool _isDragging = false;

  int get _maxDensity =>
      _selectedTarget == WaveformTarget.nowPlaying ? 1200 : 300;

  late final TextEditingController _densityController;
  late final ShadSliderController _sliderController;
  late final ShadPopoverController _colorPopoverController;

  @override
  void initState() {
    super.initState();
    _densityController = TextEditingController();
    _sliderController = ShadSliderController(initialValue: 140.0);
    _colorPopoverController = ShadPopoverController();
    _initPreferences();
    widget.preferencesService?.addListener(_onPreferencesChanged);
  }

  void _initPreferences() {
    final prefs = widget.preferencesService;
    _showNowPlayingWaveform = prefs?.showNowPlayingWaveform ?? true;
    _showInspectorWaveform = prefs?.showInspectorWaveform ?? true;
    _nowPlayingWaveformPoints = prefs?.nowPlayingWaveformPoints ?? 140;
    _inspectorWaveformPoints = prefs?.inspectorWaveformPoints ?? 100;
    _nowPlayingWaveformPulseAnimation =
        prefs?.nowPlayingWaveformPulseAnimation ?? true;
    _inspectorWaveformPulseAnimation =
        prefs?.inspectorWaveformPulseAnimation ?? true;
    _nowPlayingWaveformHoverTimeGuide =
        prefs?.nowPlayingWaveformHoverTimeGuide ?? true;
    _inspectorWaveformHoverTimeGuide =
        prefs?.inspectorWaveformHoverTimeGuide ?? true;
    _accentColor = prefs?.accentColor ?? 'zinc';

    final currentPts = _selectedTarget == WaveformTarget.nowPlaying
        ? _nowPlayingWaveformPoints
        : _inspectorWaveformPoints;
    final clampedCurrent = currentPts.clamp(30, _maxDensity);
    _densityController.text = '$clampedCurrent';
    _sliderController.value = clampedCurrent.toDouble();
  }

  void _onPreferencesChanged() {
    if (!mounted) return;
    if (_isDragging) return;

    final prefs = widget.preferencesService;
    if (prefs == null) return;

    final newShowNowPlaying = prefs.showNowPlayingWaveform;
    final newShowInspector = prefs.showInspectorWaveform;
    final newNowPlayingPts = prefs.nowPlayingWaveformPoints;
    final newInspectorPts = prefs.inspectorWaveformPoints;
    final newNowPlayingPulse = prefs.nowPlayingWaveformPulseAnimation;
    final newInspectorPulse = prefs.inspectorWaveformPulseAnimation;
    final newNowPlayingHover = prefs.nowPlayingWaveformHoverTimeGuide;
    final newInspectorHover = prefs.inspectorWaveformHoverTimeGuide;
    final newAccent = prefs.accentColor;

    if (_showNowPlayingWaveform != newShowNowPlaying ||
        _showInspectorWaveform != newShowInspector ||
        _nowPlayingWaveformPoints != newNowPlayingPts ||
        _inspectorWaveformPoints != newInspectorPts ||
        _nowPlayingWaveformPulseAnimation != newNowPlayingPulse ||
        _inspectorWaveformPulseAnimation != newInspectorPulse ||
        _nowPlayingWaveformHoverTimeGuide != newNowPlayingHover ||
        _inspectorWaveformHoverTimeGuide != newInspectorHover ||
        _accentColor != newAccent) {
      setState(() {
        _showNowPlayingWaveform = newShowNowPlaying;
        _showInspectorWaveform = newShowInspector;
        _nowPlayingWaveformPoints = newNowPlayingPts;
        _inspectorWaveformPoints = newInspectorPts;
        _nowPlayingWaveformPulseAnimation = newNowPlayingPulse;
        _inspectorWaveformPulseAnimation = newInspectorPulse;
        _nowPlayingWaveformHoverTimeGuide = newNowPlayingHover;
        _inspectorWaveformHoverTimeGuide = newInspectorHover;
        _accentColor = newAccent;

        final currentPts = _selectedTarget == WaveformTarget.nowPlaying
            ? _nowPlayingWaveformPoints
            : _inspectorWaveformPoints;
        final clampedCurrent = currentPts.clamp(30, _maxDensity);
        if (_sliderController.value != clampedCurrent.toDouble()) {
          _sliderController.value = clampedCurrent.toDouble();
        }
        if (_densityController.text != '$clampedCurrent') {
          _densityController.text = '$clampedCurrent';
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferencesService != widget.preferencesService) {
      oldWidget.preferencesService?.removeListener(_onPreferencesChanged);
      widget.preferencesService?.addListener(_onPreferencesChanged);
      setState(() {
        _initPreferences();
      });
    }
  }

  @override
  void dispose() {
    widget.preferencesService?.removeListener(_onPreferencesChanged);
    _densityController.dispose();
    _sliderController.dispose();
    _colorPopoverController.dispose();
    super.dispose();
  }

  void _onTargetChanged(WaveformTarget target) {
    setState(() {
      _selectedTarget = target;
      final maxPoints = target == WaveformTarget.nowPlaying ? 1200 : 300;
      var currentPts = target == WaveformTarget.nowPlaying
          ? _nowPlayingWaveformPoints
          : _inspectorWaveformPoints;
      currentPts = currentPts.clamp(30, maxPoints);
      if (target == WaveformTarget.nowPlaying) {
        _nowPlayingWaveformPoints = currentPts;
      } else {
        _inspectorWaveformPoints = currentPts;
      }
      _densityController.text = '$currentPts';
      _sliderController.value = currentPts.toDouble();
    });
  }

  void _onDensitySliderChanged(double val) {
    final pts = val.round().clamp(30, _maxDensity);
    if (_densityController.text != '$pts') {
      _densityController.text = '$pts';
    }
    if (_selectedTarget == WaveformTarget.nowPlaying) {
      _nowPlayingWaveformPoints = pts;
    } else {
      _inspectorWaveformPoints = pts;
    }
  }

  void _onDensityInputSubmitted(String val) {
    final parsed = int.tryParse(val.trim());
    final currentPts = _selectedTarget == WaveformTarget.nowPlaying
        ? _nowPlayingWaveformPoints
        : _inspectorWaveformPoints;
    final clamped = (parsed ?? currentPts).clamp(30, _maxDensity);
    _densityController.text = '$clamped';
    _sliderController.value = clamped.toDouble();
    _saveDensity(clamped);
  }

  void _saveDensity(int pts) {
    final clamped = pts.clamp(30, _maxDensity);
    if (_selectedTarget == WaveformTarget.nowPlaying) {
      if (_nowPlayingWaveformPoints != clamped) {
        setState(() => _nowPlayingWaveformPoints = clamped);
        widget.preferencesService?.setNowPlayingWaveformPoints(clamped);
      }
    } else {
      if (_inspectorWaveformPoints != clamped) {
        setState(() => _inspectorWaveformPoints = clamped);
        widget.preferencesService?.setInspectorWaveformPoints(clamped);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = LyraDesignSystemScope.of(context);
    final tokens = scope.tokens;
    final currentThemeMode = scope.themeModeNotifier.value;

    return LyraSettingsLayout<SettingsNavSection>(
      title: 'Settings',
      subtitle: 'Appearance and Waveform Visualization preferences',
      sidebarWidth: 200.0,
      contentMaxWidth: 720.0,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LyraSpacing.xl,
        vertical: LyraSpacing.lg,
      ),
      selectedSection: _currentSection,
      onSectionChanged: (section) => setState(() => _currentSection = section),
      sections: [
        LyraSettingsSection<SettingsNavSection>(
          id: SettingsNavSection.appearance,
          label: 'Appearance',
          icon: LucideIcons.palette,
          builder: (context) =>
              _buildAppearanceSection(context, tokens, currentThemeMode, scope),
        ),
        LyraSettingsSection<SettingsNavSection>(
          id: SettingsNavSection.waveform,
          label: 'Waveform Visualization',
          icon: LucideIcons.activity,
          builder: (context) => _buildWaveformSection(context, tokens),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    LyraThemeTokens tokens,
    ThemeMode currentThemeMode,
    LyraDesignSystemScope scope,
  ) {
    final isCustom =
        parseHexColor(_accentColor) != null &&
        !kAccentColorOptions.any((o) => o.key == _accentColor);
    final customColor = parseHexColor(_accentColor) ?? const Color(0xFF3B82F6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LyraCard(
          padding: const EdgeInsets.all(LyraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.palette, size: 20.0, color: tokens.primary),
                  const SizedBox(width: LyraSpacing.sm),
                  Text('Appearance', style: LyraTypography.h3(tokens)),
                ],
              ),
              const SizedBox(height: LyraSpacing.lg),

              // Theme Mode Selection
              Text(
                'Theme Mode',
                style: LyraTypography.p(
                  tokens,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: LyraSpacing.sm),
              Wrap(
                spacing: LyraSpacing.md,
                runSpacing: LyraSpacing.sm,
                children: [
                  _ThemeOptionCard(
                    label: 'Zinc Dark',
                    mode: ThemeMode.dark,
                    icon: LucideIcons.moon,
                    isSelected: currentThemeMode == ThemeMode.dark,
                    onTap: () {
                      scope.setThemeMode(ThemeMode.dark);
                      widget.preferencesService?.setThemeMode(ThemeMode.dark);
                    },
                    tokens: tokens,
                  ),
                  _ThemeOptionCard(
                    label: 'Zinc Light',
                    mode: ThemeMode.light,
                    icon: LucideIcons.sun,
                    isSelected: currentThemeMode == ThemeMode.light,
                    onTap: () {
                      scope.setThemeMode(ThemeMode.light);
                      widget.preferencesService?.setThemeMode(ThemeMode.light);
                    },
                    tokens: tokens,
                  ),
                  _ThemeOptionCard(
                    label: 'System',
                    mode: ThemeMode.system,
                    icon: LucideIcons.monitor,
                    isSelected: currentThemeMode == ThemeMode.system,
                    onTap: () {
                      scope.setThemeMode(ThemeMode.system);
                      widget.preferencesService?.setThemeMode(ThemeMode.system);
                    },
                    tokens: tokens,
                  ),
                ],
              ),

              const SizedBox(height: LyraSpacing.lg),
              Container(height: 1.0, color: tokens.border),
              const SizedBox(height: LyraSpacing.lg),

              // Accent Color Selection
              Text(
                'Accent Color',
                style: LyraTypography.p(
                  tokens,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: LyraSpacing.md),
              Wrap(
                spacing: LyraSpacing.sm,
                runSpacing: LyraSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...kAccentColorOptions.map((opt) {
                    final isSelected = _accentColor == opt.key;
                    return _AccentColorCard(
                      option: opt,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() => _accentColor = opt.key);
                        widget.preferencesService?.setAccentColor(opt.key);
                      },
                      tokens: tokens,
                    );
                  }),
                  ShadPopover(
                    controller: _colorPopoverController,
                    popover: (context) {
                      return _CustomColorPopoverContent(
                        initialColor: customColor,
                        tokens: tokens,
                        onApply: (hexStr) {
                          setState(() => _accentColor = hexStr);
                          widget.preferencesService?.setAccentColor(hexStr);
                          _colorPopoverController.hide();
                        },
                      );
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _colorPopoverController.toggle(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LyraSpacing.sm,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: isCustom
                              ? tokens.secondary
                              : Colors.transparent,
                          borderRadius: LyraRadius.mdRadius,
                          border: Border.all(
                            color: isCustom ? tokens.ring : tokens.border,
                            width: isCustom ? 2.0 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12.0,
                              height: 12.0,
                              decoration: BoxDecoration(
                                color: isCustom
                                    ? customColor
                                    : tokens.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              isCustom
                                  ? '#${_accentColor.replaceAll('#', '').toUpperCase()}'
                                  : 'Custom...',
                              style: LyraTypography.small(tokens).copyWith(
                                fontWeight: isCustom
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isCustom
                                    ? tokens.text
                                    : tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformSection(BuildContext context, LyraThemeTokens tokens) {
    final showWaveform = _selectedTarget == WaveformTarget.nowPlaying
        ? _showNowPlayingWaveform
        : _showInspectorWaveform;

    final pulseAnim = _selectedTarget == WaveformTarget.nowPlaying
        ? _nowPlayingWaveformPulseAnimation
        : _inspectorWaveformPulseAnimation;

    final hoverGuide = _selectedTarget == WaveformTarget.nowPlaying
        ? _nowPlayingWaveformHoverTimeGuide
        : _inspectorWaveformHoverTimeGuide;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LyraCard(
          padding: const EdgeInsets.all(LyraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.activity, size: 20.0, color: tokens.primary),
                  const SizedBox(width: LyraSpacing.sm),
                  Text(
                    'Waveform Visualization',
                    style: LyraTypography.h3(tokens),
                  ),
                ],
              ),
              const SizedBox(height: LyraSpacing.lg),

              // Target Selector
              Row(
                children: [
                  Text(
                    'Visualization Target',
                    style: LyraTypography.p(
                      tokens,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 200),
                    child: ShadSelect<WaveformTarget>(
                      initialValue: _selectedTarget,
                      options: const [
                        ShadOption(
                          value: WaveformTarget.nowPlaying,
                          child: Text('Now Playing Bar'),
                        ),
                        ShadOption(
                          value: WaveformTarget.inspector,
                          child: Text('Audio Inspector Drawer'),
                        ),
                      ],
                      selectedOptionBuilder: (context, value) => Text(
                        value == WaveformTarget.nowPlaying
                            ? 'Now Playing Bar'
                            : 'Audio Inspector Drawer',
                      ),
                      onChanged: (val) {
                        if (val != null) _onTargetChanged(val);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: LyraSpacing.lg),
              Container(height: 1.0, color: tokens.border),
              const SizedBox(height: LyraSpacing.lg),

              // 1. Display Waveform Switch
              _SettingRow(
                title: 'Show Waveform',
                trailing: LyraSwitch(
                  value: showWaveform,
                  onChanged: (val) {
                    if (_selectedTarget == WaveformTarget.nowPlaying) {
                      setState(() => _showNowPlayingWaveform = val);
                      widget.preferencesService?.setShowNowPlayingWaveform(val);
                    } else {
                      setState(() => _showInspectorWaveform = val);
                      widget.preferencesService?.setShowInspectorWaveform(val);
                    }
                  },
                ),
                tokens: tokens,
              ),

              const SizedBox(height: LyraSpacing.md),

              // 2. Sampling Density: Slider + Numeric Input
              _SettingRow(
                title: 'Sampling Density',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 140.0,
                      child: ShadSlider(
                        min: 30.0,
                        max: _maxDensity.toDouble(),
                        controller: _sliderController,
                        onChangeStart: (_) => _isDragging = true,
                        onChanged: _onDensitySliderChanged,
                        onChangeEnd: (val) {
                          _isDragging = false;
                          _saveDensity(val.round().clamp(30, _maxDensity));
                        },
                      ),
                    ),
                    const SizedBox(width: LyraSpacing.lg),
                    SizedBox(
                      width: 68.0,
                      height: 32.0,
                      child: ShadInput(
                        controller: _densityController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 2.0,
                        ),
                        onSubmitted: _onDensityInputSubmitted,
                        onChanged: (val) {
                          final parsed = int.tryParse(val.trim());
                          if (parsed != null &&
                              parsed >= 30 &&
                              parsed <= _maxDensity) {
                            _sliderController.value = parsed.toDouble();
                            _saveDensity(parsed);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Text('pts', style: LyraTypography.small(tokens)),
                  ],
                ),
                tokens: tokens,
              ),

              const SizedBox(height: LyraSpacing.md),

              // 3. Pulse Shimmer Animation Switch
              _SettingRow(
                title: 'Pulse Shimmer Animation',
                trailing: LyraSwitch(
                  value: pulseAnim,
                  onChanged: (val) {
                    if (_selectedTarget == WaveformTarget.nowPlaying) {
                      setState(() => _nowPlayingWaveformPulseAnimation = val);
                      widget.preferencesService
                          ?.setNowPlayingWaveformPulseAnimation(val);
                    } else {
                      setState(() => _inspectorWaveformPulseAnimation = val);
                      widget.preferencesService
                          ?.setInspectorWaveformPulseAnimation(val);
                    }
                  },
                ),
                tokens: tokens,
              ),

              const SizedBox(height: LyraSpacing.md),

              // 4. Hover Timecode Guide Switch
              _SettingRow(
                title: 'Hover Timecode Guide',
                trailing: LyraSwitch(
                  value: hoverGuide,
                  onChanged: (val) {
                    if (_selectedTarget == WaveformTarget.nowPlaying) {
                      setState(() => _nowPlayingWaveformHoverTimeGuide = val);
                      widget.preferencesService
                          ?.setNowPlayingWaveformHoverTimeGuide(val);
                    } else {
                      setState(() => _inspectorWaveformHoverTimeGuide = val);
                      widget.preferencesService
                          ?.setInspectorWaveformHoverTimeGuide(val);
                    }
                  },
                ),
                tokens: tokens,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String? description;
  final Widget trailing;
  final LyraThemeTokens tokens;

  const _SettingRow({
    required this.title,
    // ignore: unused_element_parameter
    this.description,
    required this.trailing,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
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
                if (description != null && description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      description!,
                      style: LyraTypography.small(
                        tokens,
                      ).copyWith(color: tokens.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: LyraSpacing.md),
          trailing,
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _ThemeOptionCard({
    required this.label,
    required this.mode,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkCard =
        mode == ThemeMode.dark || (mode == ThemeMode.system && tokens.isDark);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 130.0,
        padding: const EdgeInsets.all(LyraSpacing.md),
        decoration: BoxDecoration(
          color: isDarkCard ? LyraColors.zinc950 : const Color(0xFFFFFFFF),
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
                  icon,
                  size: 16.0,
                  color: isDarkCard ? LyraColors.zinc50 : LyraColors.zinc950,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    LucideIcons.check,
                    size: 14.0,
                    color: isDarkCard ? LyraColors.zinc50 : LyraColors.zinc950,
                  ),
              ],
            ),
            const SizedBox(height: LyraSpacing.md),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: isDarkCard ? LyraColors.zinc50 : LyraColors.zinc950,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentColorCard extends StatelessWidget {
  final AccentColorOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final LyraThemeTokens tokens;

  const _AccentColorCard({
    required this.option,
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
        padding: const EdgeInsets.symmetric(
          horizontal: LyraSpacing.sm,
          vertical: 6.0,
        ),
        decoration: BoxDecoration(
          color: tokens.itemBackground(isSelected: isSelected),
          borderRadius: LyraRadius.mdRadius,
          border: Border.all(
            color: isSelected ? tokens.ring : tokens.border,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.0,
              height: 12.0,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6.0),
            Text(
              option.label,
              style: LyraTypography.small(tokens).copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? tokens.text : tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomColorPopoverContent extends StatefulWidget {
  final Color initialColor;
  final LyraThemeTokens tokens;
  final ValueChanged<String> onApply;

  const _CustomColorPopoverContent({
    required this.initialColor,
    required this.tokens,
    required this.onApply,
  });

  @override
  State<_CustomColorPopoverContent> createState() =>
      _CustomColorPopoverContentState();
}

class _CustomColorPopoverContentState
    extends State<_CustomColorPopoverContent> {
  late double _hue;
  late double _saturation;
  late double _value;
  late Color _previewColor;
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue.clamp(0.0, 360.0);
    _saturation = hsv.saturation > 0.05 ? hsv.saturation : 0.85;
    _value = hsv.value > 0.05 ? hsv.value : 0.90;
    _previewColor = widget.initialColor;
    final hex = _previewColor
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    _hexController = TextEditingController(text: hex);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _onHueChanged(double hue) {
    setState(() {
      _hue = hue.clamp(0.0, 360.0);
      _previewColor = HSVColor.fromAHSV(
        1.0,
        _hue,
        _saturation,
        _value,
      ).toColor();
      final hex = _previewColor
          .toARGB32()
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2)
          .toUpperCase();
      _hexController.text = hex;
    });
  }

  void _onHexChanged(String text) {
    final clean = text.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final parsed = parseHexColor(clean);
      if (parsed != null) {
        setState(() {
          _previewColor = parsed;
          final hsv = HSVColor.fromColor(parsed);
          _hue = hsv.hue.clamp(0.0, 360.0);
          _saturation = hsv.saturation > 0.05 ? hsv.saturation : 0.85;
          _value = hsv.value > 0.05 ? hsv.value : 0.90;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return Container(
      width: 250.0,
      padding: const EdgeInsets.all(LyraSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom Color',
                style: LyraTypography.p(
                  tokens,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              Container(
                width: 28.0,
                height: 28.0,
                decoration: BoxDecoration(
                  color: _previewColor,
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: tokens.border, width: 1.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.md),
          Text('Hue: ${_hue.round()}°', style: LyraTypography.small(tokens)),
          const SizedBox(height: 4.0),
          ShadSlider(
            min: 0.0,
            max: 360.0,
            initialValue: _hue,
            onChanged: _onHueChanged,
          ),
          const SizedBox(height: LyraSpacing.sm),
          Text('Hex Code', style: LyraTypography.small(tokens)),
          const SizedBox(height: 4.0),
          ShadInput(
            controller: _hexController,
            placeholder: const Text('3B82F6'),
            leading: const Padding(
              padding: EdgeInsets.only(right: 4.0),
              child: Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            onChanged: _onHexChanged,
          ),
          const SizedBox(height: LyraSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: LyraButton(
              size: LyraButtonSize.sm,
              onPressed: () {
                final clean = _hexController.text.replaceAll('#', '').trim();
                if (clean.length == 6 && parseHexColor(clean) != null) {
                  widget.onApply('#${clean.toUpperCase()}');
                }
              },
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
