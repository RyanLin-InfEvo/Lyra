// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/models/waveform_data.dart';
import '../../design_system/contracts/lyra_contracts.dart';
import '../../design_system/factory/lyra_design_system_scope.dart';
import '../../design_system/tokens/lyra_tokens.dart';
import '../../design_system/widgets/lyra_button.dart';
import '../../design_system/widgets/lyra_card.dart';
import '../../design_system/widgets/lyra_settings_layout.dart';
import '../../design_system/widgets/lyra_switch.dart';
import '../player/views/components/waveform_scrubber.dart';
import 'services/preferences_service.dart';

const double kNowPlayingReferenceWidth = 780.0;
const double kInspectorReferenceWidth = 380.0;

double densityToBarSpacing(int percent) {
  final clamped = percent.clamp(0, 100);
  return 16.0 * math.pow(2.0 / 16.0, clamped / 100.0);
}

int barSpacingToDensityPercent(double spacing) {
  if (spacing.isNaN || !spacing.isFinite) return 0;
  if (spacing >= 15.8) return 0;
  if (spacing <= 2.0) return 100;
  final clamped = spacing.clamp(2.0, 16.0);
  final ratio = 2.0 / 16.0;
  return ((math.log(clamped / 16.0) / math.log(ratio)) * 100.0).round().clamp(
    0,
    100,
  );
}

int pointsToDensityPercent(int pts, WaveformTarget target) {
  final baseWidth = target == WaveformTarget.nowPlaying
      ? kNowPlayingReferenceWidth
      : kInspectorReferenceWidth;
  if (pts <= 0) return 0;
  final spacing = baseWidth / pts;
  return barSpacingToDensityPercent(spacing);
}

int percentToDensityPoints(int pct, WaveformTarget target) {
  final spacing = densityToBarSpacing(pct);
  final baseWidth = target == WaveformTarget.nowPlaying
      ? kNowPlayingReferenceWidth
      : kInspectorReferenceWidth;
  final maxPts = target == WaveformTarget.nowPlaying ? 1200 : 300;
  return (baseWidth / spacing).round().clamp(10, maxPts);
}

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

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
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
  late ThemeMode _themeMode;
  bool _isDragging = false;

  int _minPercent(WaveformTarget target) => 0;

  int _pointsToPercent(int pts, WaveformTarget target) =>
      pointsToDensityPercent(pts, target);

  int _percentToPoints(int pct, WaveformTarget target) =>
      percentToDensityPoints(pct, target);

  late final TextEditingController _densityController;
  late final FocusNode _densityFocusNode;
  late final ShadSliderController _sliderController;
  late final ShadPopoverController _colorPopoverController;
  AnimationController? _sliderAnimController;
  CurvedAnimation? _sliderCurvedAnimation;
  Animation<double>? _sliderAnimation;

  @override
  void initState() {
    super.initState();
    _densityController = TextEditingController();
    _densityFocusNode = FocusNode();
    _densityFocusNode.addListener(_onDensityFocusChanged);
    _sliderController = ShadSliderController(
      initialValue: _pointsToPercent(140, WaveformTarget.nowPlaying).toDouble(),
    );
    _colorPopoverController = ShadPopoverController();
    _sliderAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _sliderCurvedAnimation = CurvedAnimation(
      parent: _sliderAnimController!,
      curve: Curves.easeOutCubic,
    );
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
    _themeMode = prefs?.themeMode ?? ThemeMode.dark;

    final currentPts = _selectedTarget == WaveformTarget.nowPlaying
        ? _nowPlayingWaveformPoints
        : _inspectorWaveformPoints;
    final pct = _pointsToPercent(currentPts, _selectedTarget);
    _densityController.text = '$pct';
    _sliderController.value = pct.toDouble();
  }

  void _onPreferencesChanged() {
    if (!mounted) return;
    if (_isDragging) return;
    if (_densityFocusNode.hasFocus) return;

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
    final newThemeMode = prefs.themeMode;

    if (_showNowPlayingWaveform != newShowNowPlaying ||
        _showInspectorWaveform != newShowInspector ||
        _nowPlayingWaveformPoints != newNowPlayingPts ||
        _inspectorWaveformPoints != newInspectorPts ||
        _nowPlayingWaveformPulseAnimation != newNowPlayingPulse ||
        _inspectorWaveformPulseAnimation != newInspectorPulse ||
        _nowPlayingWaveformHoverTimeGuide != newNowPlayingHover ||
        _inspectorWaveformHoverTimeGuide != newInspectorHover ||
        _accentColor != newAccent ||
        _themeMode != newThemeMode) {
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
        _themeMode = newThemeMode;

        final currentPts = _selectedTarget == WaveformTarget.nowPlaying
            ? _nowPlayingWaveformPoints
            : _inspectorWaveformPoints;
        final pct = _pointsToPercent(currentPts, _selectedTarget);
        if (_sliderController.value != pct.toDouble()) {
          _sliderController.value = pct.toDouble();
        }
        if (_densityController.text != '$pct') {
          _densityController.text = '$pct';
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
    _densityFocusNode.removeListener(_onDensityFocusChanged);
    _densityFocusNode.dispose();
    _densityController.dispose();
    _sliderController.dispose();
    _sliderAnimController?.removeListener(_onSliderAnimTick);
    _sliderCurvedAnimation?.dispose();
    _sliderAnimController?.dispose();
    _colorPopoverController.dispose();
    super.dispose();
  }

  void _onDensityFocusChanged() {
    if (!_densityFocusNode.hasFocus) {
      final currentPts = _selectedTarget == WaveformTarget.nowPlaying
          ? _nowPlayingWaveformPoints
          : _inspectorWaveformPoints;
      final currentPct = _pointsToPercent(currentPts, _selectedTarget);
      final parsed = int.tryParse(_densityController.text.trim());
      final minPct = _minPercent(_selectedTarget);
      if (parsed == null || parsed < minPct || parsed > 100) {
        _densityController.text = '$currentPct';
      }
    }
  }

  void _animateSliderTo(double target) {
    if (_sliderAnimController == null || _sliderCurvedAnimation == null) return;
    _sliderAnimController!.removeListener(_onSliderAnimTick);
    _sliderAnimController!.stop();
    _sliderAnimController!.reset();
    final startVal = _sliderController.value;
    final minPct = _minPercent(_selectedTarget).toDouble();
    final clampedTarget = target.clamp(minPct, 100.0);
    _sliderAnimation = Tween<double>(
      begin: startVal,
      end: clampedTarget,
    ).animate(_sliderCurvedAnimation!);
    _sliderAnimController!.addListener(_onSliderAnimTick);
    _sliderAnimController!.forward();
  }

  void _onSliderAnimTick() {
    if (_sliderAnimation != null && mounted) {
      final current = _sliderAnimation!.value;
      _sliderController.value = current;
      final pct = current.round().clamp(_minPercent(_selectedTarget), 100);
      if (_densityController.text != '$pct') {
        _densityController.text = '$pct';
      }
      final pts = _percentToPoints(pct, _selectedTarget);
      if (_selectedTarget == WaveformTarget.nowPlaying) {
        if (_nowPlayingWaveformPoints != pts) {
          setState(() => _nowPlayingWaveformPoints = pts);
        }
      } else {
        if (_inspectorWaveformPoints != pts) {
          setState(() => _inspectorWaveformPoints = pts);
        }
      }
      if (_sliderAnimController != null && _sliderAnimController!.isCompleted) {
        _sliderAnimController!.removeListener(_onSliderAnimTick);
        _saveDensity(pts);
      }
    }
  }

  void _onTargetChanged(WaveformTarget target) {
    _sliderAnimController?.removeListener(_onSliderAnimTick);
    _sliderAnimController?.stop();
    _isDragging = false;
    setState(() {
      _selectedTarget = target;
      final maxPoints = target == WaveformTarget.nowPlaying ? 1200 : 300;
      var currentPts = target == WaveformTarget.nowPlaying
          ? _nowPlayingWaveformPoints
          : _inspectorWaveformPoints;
      currentPts = currentPts.clamp(10, maxPoints);
      if (target == WaveformTarget.nowPlaying) {
        _nowPlayingWaveformPoints = currentPts;
      } else {
        _inspectorWaveformPoints = currentPts;
      }
      final pct = _pointsToPercent(currentPts, target);
      _densityController.text = '$pct';
      _sliderController.value = pct.toDouble();
    });
  }

  void _onDensitySliderChanged(double val) {
    final pct = val.round().clamp(_minPercent(_selectedTarget), 100);
    final pts = _percentToPoints(pct, _selectedTarget);
    if (_densityController.text != '$pct') {
      _densityController.text = '$pct';
    }
    if (_isDragging) {
      if (_selectedTarget == WaveformTarget.nowPlaying) {
        if (_nowPlayingWaveformPoints != pts) {
          setState(() => _nowPlayingWaveformPoints = pts);
        }
      } else {
        if (_inspectorWaveformPoints != pts) {
          setState(() => _inspectorWaveformPoints = pts);
        }
      }
    } else if (!(_sliderAnimController?.isAnimating ?? false)) {
      _saveDensity(pts);
    }
  }

  void _onDensityInputSubmitted(String val) {
    final parsed = int.tryParse(val.trim());
    final currentPts = _selectedTarget == WaveformTarget.nowPlaying
        ? _nowPlayingWaveformPoints
        : _inspectorWaveformPoints;
    final currentPct = _pointsToPercent(currentPts, _selectedTarget);
    final minPct = _minPercent(_selectedTarget);
    final clampedPct = (parsed ?? currentPct).clamp(minPct, 100);
    final pts = _percentToPoints(clampedPct, _selectedTarget);
    _densityController.text = '$clampedPct';
    _sliderController.value = clampedPct.toDouble();
    _saveDensity(pts);
  }

  void _saveDensity(int pts) {
    final maxPts = _selectedTarget == WaveformTarget.nowPlaying ? 1200 : 300;
    final clamped = pts.clamp(10, maxPts);
    if (_selectedTarget == WaveformTarget.nowPlaying) {
      setState(() => _nowPlayingWaveformPoints = clamped);
      widget.preferencesService?.setNowPlayingWaveformPoints(clamped);
    } else {
      setState(() => _inspectorWaveformPoints = clamped);
      widget.preferencesService?.setInspectorWaveformPoints(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = LyraDesignSystemScope.of(context);
    final tokens = scope.tokens;

    return LyraSettingsLayout<SettingsNavSection>(
      title: 'Settings',
      sidebarWidth: 250.0,
      contentMaxWidth: 1040.0,
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
          builder: (context) => _buildAppearanceSection(context, tokens, scope),
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
    LyraDesignSystemScope scope,
  ) {
    final isCustom =
        parseHexColor(_accentColor) != null &&
        !kAccentColorOptions.any((o) => o.key == _accentColor);
    final customColor = parseHexColor(_accentColor) ?? const Color(0xFF3B82F6);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 880.0;

        final controlsCard = LyraCard(
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
                    isSelected: _themeMode == ThemeMode.dark,
                    onTap: () {
                      setState(() => _themeMode = ThemeMode.dark);
                      scope.setThemeMode(ThemeMode.dark);
                      widget.preferencesService?.setThemeMode(ThemeMode.dark);
                    },
                    tokens: tokens,
                  ),
                  _ThemeOptionCard(
                    label: 'Zinc Light',
                    mode: ThemeMode.light,
                    icon: LucideIcons.sun,
                    isSelected: _themeMode == ThemeMode.light,
                    onTap: () {
                      setState(() => _themeMode = ThemeMode.light);
                      scope.setThemeMode(ThemeMode.light);
                      widget.preferencesService?.setThemeMode(ThemeMode.light);
                    },
                    tokens: tokens,
                  ),
                  _ThemeOptionCard(
                    label: 'System',
                    mode: ThemeMode.system,
                    icon: LucideIcons.monitor,
                    isSelected: _themeMode == ThemeMode.system,
                    onTap: () {
                      setState(() => _themeMode = ThemeMode.system);
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
                    child: Semantics(
                      button: true,
                      selected: isCustom,
                      label: isCustom
                          ? 'Custom accent color selected'
                          : 'Custom accent color picker',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        final previewCard = _AppearancePreviewCard(
          tokens: tokens,
          accentColor: _accentColor,
          themeMode: _themeMode,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: controlsCard),
              const SizedBox(width: LyraSpacing.lg),
              Expanded(flex: 5, child: previewCard),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              controlsCard,
              const SizedBox(height: LyraSpacing.lg),
              previewCard,
            ],
          );
        }
      },
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

    final currentPts = _selectedTarget == WaveformTarget.nowPlaying
        ? _nowPlayingWaveformPoints
        : _inspectorWaveformPoints;

    final controlsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Configuration',
          style: LyraTypography.p(tokens).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: LyraSpacing.md),

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
                height: 24.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final minPct = _minPercent(_selectedTarget).toDouble();
                    final target =
                        minPct +
                        (details.localPosition.dx / 140.0).clamp(0.0, 1.0) *
                            (100.0 - minPct);
                    _animateSliderTo(target);
                  },
                  child: ShadSlider(
                    min: _minPercent(_selectedTarget).toDouble(),
                    max: 100.0,
                    controller: _sliderController,
                    allowedInteraction: ShadSliderInteraction.slideOnly,
                    onChangeStart: (_) {
                      _sliderAnimController?.stop();
                      _isDragging = true;
                    },
                    onChanged: _onDensitySliderChanged,
                    onChangeEnd: (val) {
                      _isDragging = false;
                      final pct = val.round().clamp(
                        _minPercent(_selectedTarget),
                        100,
                      );
                      _saveDensity(_percentToPoints(pct, _selectedTarget));
                    },
                  ),
                ),
              ),
              const SizedBox(width: LyraSpacing.lg),
              SizedBox(
                width: 68.0,
                height: 32.0,
                child: ShadInput(
                  controller: _densityController,
                  focusNode: _densityFocusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
                  onSubmitted: _onDensityInputSubmitted,
                  onChanged: (val) {
                    final parsed = int.tryParse(val.trim());
                    final minPct = _minPercent(_selectedTarget);
                    if (parsed != null && parsed >= minPct && parsed <= 100) {
                      _sliderController.value = parsed.toDouble();
                      final pts = _percentToPoints(parsed, _selectedTarget);
                      _saveDensity(pts);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4.0),
              Text('%', style: LyraTypography.small(tokens)),
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
                widget.preferencesService?.setNowPlayingWaveformPulseAnimation(
                  val,
                );
              } else {
                setState(() => _inspectorWaveformPulseAnimation = val);
                widget.preferencesService?.setInspectorWaveformPulseAnimation(
                  val,
                );
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
                widget.preferencesService?.setNowPlayingWaveformHoverTimeGuide(
                  val,
                );
              } else {
                setState(() => _inspectorWaveformHoverTimeGuide = val);
                widget.preferencesService?.setInspectorWaveformHoverTimeGuide(
                  val,
                );
              }
            },
          ),
          tokens: tokens,
        ),
      ],
    );

    final previewPanel = WaveformPreviewCard(
      key: const ValueKey('waveform_preview_card'),
      target: _selectedTarget,
      showWaveform: showWaveform,
      points: currentPts,
      enablePulseAnimation: pulseAnim,
      enableHoverTimeGuide: hoverGuide,
      tokens: tokens,
    );

    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.activity, size: 20.0, color: tokens.primary),
              const SizedBox(width: LyraSpacing.sm),
              Text('Waveform Visualization', style: LyraTypography.h3(tokens)),
            ],
          ),
          const SizedBox(height: LyraSpacing.lg),

          // Target Selector
          Text(
            'Visualization Target',
            style: LyraTypography.p(
              tokens,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: LyraSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ShadTabs<WaveformTarget>(
              value: _selectedTarget,
              onChanged: _onTargetChanged,
              gap: 0,
              tabs: const [
                ShadTab(
                  value: WaveformTarget.nowPlaying,
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Flexible(
                    child: Text(
                      'Now Playing Bar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ShadTab(
                  value: WaveformTarget.inspector,
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Flexible(
                    child: Text(
                      'Audio Inspector Drawer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LyraSpacing.lg),
          Container(height: 1.0, color: tokens.border),
          const SizedBox(height: LyraSpacing.lg),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760.0;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: controlsContent),
                    const SizedBox(width: LyraSpacing.xl),
                    Expanded(flex: 5, child: previewPanel),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    controlsContent,
                    const SizedBox(height: LyraSpacing.xl),
                    Container(height: 1.0, color: tokens.border),
                    const SizedBox(height: LyraSpacing.lg),
                    previewPanel,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class WaveformPreviewCard extends StatefulWidget {
  final WaveformTarget target;
  final bool showWaveform;
  final int points;
  final bool enablePulseAnimation;
  final bool enableHoverTimeGuide;
  final LyraThemeTokens tokens;

  const WaveformPreviewCard({
    super.key,
    required this.target,
    required this.showWaveform,
    required this.points,
    required this.enablePulseAnimation,
    required this.enableHoverTimeGuide,
    required this.tokens,
  });

  @override
  State<WaveformPreviewCard> createState() => _WaveformPreviewCardState();
}

class _WaveformPreviewCardState extends State<WaveformPreviewCard> {
  bool _isPlaying = false;
  Timer? _playbackTimer;
  Duration _simulatedPosition = const Duration(seconds: 45);
  final Duration _simulatedDuration = const Duration(minutes: 3, seconds: 45);

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer?.cancel();
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (
          timer,
        ) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            final nextMs = _simulatedPosition.inMilliseconds + 50;
            if (nextMs >= _simulatedDuration.inMilliseconds) {
              _simulatedPosition = Duration.zero;
            } else {
              _simulatedPosition = Duration(milliseconds: nextMs);
            }
          });
        });
      } else {
        _playbackTimer?.cancel();
        _playbackTimer = null;
      }
    });
  }

  @override
  void didUpdateWidget(covariant WaveformPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showWaveform && _isPlaying) {
      _playbackTimer?.cancel();
      _playbackTimer = null;
      _isPlaying = false;
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isNowPlaying = widget.target == WaveformTarget.nowPlaying;

    final containerDeco = BoxDecoration(
      color: tokens.secondary.withValues(alpha: 0.35),
      borderRadius: LyraRadius.lgRadius,
      border: Border.all(color: tokens.border, width: 1.0),
    );

    final densityPercent = pointsToDensityPercent(widget.points, widget.target);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Preview', style: LyraTypography.h3(tokens)),
            const SizedBox(width: LyraSpacing.sm),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: tokens.secondary,
                  borderRadius: LyraRadius.smRadius,
                ),
                child: Text(
                  isNowPlaying ? 'Now Playing' : 'Inspector',
                  style: LyraTypography.muted(
                    tokens,
                  ).copyWith(fontSize: 11.0, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: LyraSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LyraSpacing.md,
            vertical: LyraSpacing.sm,
          ),
          decoration: containerDeco,
          child: !widget.showWaveform
              ? Container(
                  height: 56.0,
                  alignment: Alignment.center,
                  child: Text(
                    'Waveform hidden for ${isNowPlaying ? 'Now Playing Bar' : 'Audio Inspector'}',
                    style: LyraTypography.muted(
                      tokens,
                    ).copyWith(fontSize: 12.0),
                  ),
                )
              : Row(
                  children: [
                    Semantics(
                      button: true,
                      label: _isPlaying ? 'Pause preview' : 'Play preview',
                      child: Tooltip(
                        message: _isPlaying ? 'Pause preview' : 'Play preview',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _togglePlay,
                            child: Container(
                              width: 32.0,
                              height: 32.0,
                              decoration: BoxDecoration(
                                color: tokens.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: tokens.border,
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                _isPlaying
                                    ? LucideIcons.pause
                                    : LucideIcons.play,
                                size: 14.0,
                                color: tokens.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: LyraSpacing.sm),
                    Expanded(
                      child: RepaintBoundary(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final previewWidth = constraints.maxWidth;
                            final spacing = densityToBarSpacing(densityPercent);
                            final previewPoints = previewWidth >= 10.0
                                ? math.max(10, (previewWidth / spacing).round())
                                : (previewWidth > 0
                                      ? math.max(1, previewWidth.round())
                                      : 10);

                            return WaveformScrubber(
                              waveform: WaveformData.mock(
                                points: previewPoints,
                                pcmHash: 'preview-${widget.target.name}',
                              ),
                              desiredBarSpacing: spacing,
                              position: _simulatedPosition,
                              duration: _simulatedDuration,
                              onSeek: (pos) =>
                                  setState(() => _simulatedPosition = pos),
                              height: 56.0,
                              isPlaying: _isPlaying,
                              enablePulseAnimation: widget.enablePulseAnimation,
                              enableHoverTimeGuide: widget.enableHoverTimeGuide,
                              enableAnimation:
                                  _isPlaying && widget.enablePulseAnimation,
                              isInteractive: true,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: LyraSpacing.sm),
        Text(
          '$densityPercent% density (${widget.points} pts) • ${widget.enablePulseAnimation ? 'Pulse on' : 'Pulse off'} • ${widget.enableHoverTimeGuide ? 'Guide on' : 'Guide off'}',
          style: LyraTypography.muted(tokens).copyWith(fontSize: 11.0),
        ),
      ],
    );
  }
}

class _AppearancePreviewCard extends StatelessWidget {
  final LyraThemeTokens tokens;
  final String accentColor;
  final ThemeMode themeMode;

  const _AppearancePreviewCard({
    required this.tokens,
    required this.accentColor,
    required this.themeMode,
  });

  String _formatThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String _formatAccent(String accent) {
    final opt = kAccentColorOptions.where((o) => o.key == accent).firstOrNull;
    if (opt != null) return opt.label;
    if (accent.startsWith('#')) return accent.toUpperCase();
    return accent.isEmpty
        ? accent
        : '${accent[0].toUpperCase()}${accent.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return LyraCard(
      padding: const EdgeInsets.all(LyraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Preview', style: LyraTypography.h3(tokens)),
              const SizedBox(width: LyraSpacing.sm),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.secondary,
                    borderRadius: LyraRadius.smRadius,
                  ),
                  child: Text(
                    '${_formatThemeMode(themeMode)} • ${_formatAccent(accentColor)}',
                    style: LyraTypography.muted(
                      tokens,
                    ).copyWith(fontSize: 11.0, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LyraSpacing.lg),
          Container(
            padding: const EdgeInsets.all(LyraSpacing.md),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: LyraRadius.lgRadius,
              border: Border.all(color: tokens.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.15),
                        borderRadius: LyraRadius.mdRadius,
                      ),
                      child: Icon(
                        LucideIcons.music,
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
                            'Sample Audiophile Stream',
                            style: LyraTypography.p(tokens).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.0,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            '24-bit / 192kHz FLAC • Lossless',
                            style: LyraTypography.muted(
                              tokens,
                            ).copyWith(fontSize: 11.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LyraSpacing.md),
                Container(
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: tokens.muted,
                    borderRadius: LyraRadius.fullRadius,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.65,
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.primary,
                        borderRadius: LyraRadius.fullRadius,
                      ),
                    ),
                  ),
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

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
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
                      color: isDarkCard
                          ? LyraColors.zinc50
                          : LyraColors.zinc950,
                    ),
                    const Spacer(),
                    if (isSelected)
                      Icon(
                        LucideIcons.check,
                        size: 14.0,
                        color: isDarkCard
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
                    color: isDarkCard ? LyraColors.zinc50 : LyraColors.zinc950,
                  ),
                ),
              ],
            ),
          ),
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
    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
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
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? tokens.text : tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
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
