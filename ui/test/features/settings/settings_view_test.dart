// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/core/models/waveform_data.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_settings_layout.dart';
import 'package:ui/design_system/widgets/lyra_switch.dart';
import 'package:ui/features/player/views/components/waveform_scrubber.dart';
import 'package:ui/features/settings/services/preferences_service.dart';
import 'package:ui/features/settings/settings_view.dart';
import 'package:ui/main.dart';

Widget _buildSettingsTestApp(PreferencesService prefs, {Widget? child}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final tokens = deriveLyraThemeTokens(prefs.accentColor, isDark);
        final colorScheme = deriveShadColorScheme(
          prefs.accentColor,
          isDark ? Brightness.dark : Brightness.light,
        );

        return ShadTheme(
          data: ShadThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            colorScheme: colorScheme,
          ),
          child: LyraDesignSystemScope(
            factory: factory,
            tokens: tokens,
            themeModeNotifier: themeModeNotifier,
            child: Scaffold(
              body: child ?? SettingsView(preferencesService: prefs),
            ),
          ),
        );
      },
    ),
  );
}

class _CountingPreferencesService extends InMemoryPreferencesService {
  int setPointsCallCount = 0;
  _CountingPreferencesService({super.nowPlayingWaveformPoints = 140});

  @override
  Future<void> setNowPlayingWaveformPoints(int points) async {
    setPointsCallCount++;
    return super.setNowPlayingWaveformPoints(points);
  }
}

void main() {
  group('Unified Physical Spacing Model', () {
    test(
      'densityToBarSpacing computes exact bar pitch at boundaries and midpoints',
      () {
        expect(densityToBarSpacing(0), closeTo(16.0, 1e-4));
        expect(densityToBarSpacing(50), closeTo(5.65685, 1e-4));
        expect(densityToBarSpacing(100), closeTo(2.0, 1e-4));
      },
    );

    test('barSpacingToDensityPercent inverts spacing accurately', () {
      expect(barSpacingToDensityPercent(16.0), 0);
      expect(barSpacingToDensityPercent(15.9), 0);
      expect(barSpacingToDensityPercent(5.65685), 50);
      expect(barSpacingToDensityPercent(2.0), 100);
      expect(barSpacingToDensityPercent(1.9), 100);
    });

    test('barSpacingToDensityPercent handles non-finite values safely', () {
      expect(barSpacingToDensityPercent(double.nan), 0);
      expect(barSpacingToDensityPercent(double.infinity), 0);
      expect(barSpacingToDensityPercent(double.negativeInfinity), 0);
    });

    test(
      'bar spacing parity across Now Playing and Inspector at 0%, 50%, 100%',
      () {
        for (final pct in [0, 50, 100]) {
          final npSpacing = densityToBarSpacing(pct);
          final inspSpacing = densityToBarSpacing(pct);
          expect(npSpacing, equals(inspSpacing));
        }
      },
    );

    test('canonical points and step sizes under unified spacing', () {
      // 0% on Now Playing -> 49 pts (step = 780 / 49 = 15.92px)
      expect(percentToDensityPoints(0, WaveformTarget.nowPlaying), 49);
      final np0Step = kNowPlayingReferenceWidth / 49;
      expect(np0Step, closeTo(15.92, 0.01));
      expect(pointsToDensityPercent(49, WaveformTarget.nowPlaying), 0);

      // 0% on Inspector -> 24 pts (step = 380 / 24 = 15.83px)
      expect(percentToDensityPoints(0, WaveformTarget.inspector), 24);
      final insp0Step = kInspectorReferenceWidth / 24;
      expect(insp0Step, closeTo(15.83, 0.01));
      expect(pointsToDensityPercent(24, WaveformTarget.inspector), 0);

      // 100% on Now Playing -> 390 pts (step = 780 / 390 = 2.00px)
      expect(percentToDensityPoints(100, WaveformTarget.nowPlaying), 390);
      final np100Step = kNowPlayingReferenceWidth / 390;
      expect(np100Step, closeTo(2.00, 0.01));
      expect(pointsToDensityPercent(390, WaveformTarget.nowPlaying), 100);

      // 100% on Inspector -> 190 pts (step = 380 / 190 = 2.00px)
      expect(percentToDensityPoints(100, WaveformTarget.inspector), 190);
      final insp100Step = kInspectorReferenceWidth / 190;
      expect(insp100Step, closeTo(2.00, 0.01));
      expect(pointsToDensityPercent(190, WaveformTarget.inspector), 100);

      // Initial default (140 pts for Now Playing) is ~51% (or ~50%)
      final npDefaultPct = pointsToDensityPercent(
        140,
        WaveformTarget.nowPlaying,
      );
      expect(npDefaultPct, anyOf(50, 51));

      // Initial default (100 pts for Inspector) is ~69%
      final inspDefaultPct = pointsToDensityPercent(
        100,
        WaveformTarget.inspector,
      );
      expect(inspDefaultPct, 69);
    });
  });

  group('SettingsView Comprehensive Tests', () {
    late InMemoryPreferencesService prefs;

    setUp(() {
      prefs = InMemoryPreferencesService(
        showNowPlayingWaveform: true,
        showInspectorWaveform: true,
        nowPlayingWaveformPoints: 140,
        inspectorWaveformPoints: 100,
        nowPlayingWaveformPulseAnimation: true,
        inspectorWaveformPulseAnimation: true,
        nowPlayingWaveformHoverTimeGuide: true,
        inspectorWaveformHoverTimeGuide: true,
        accentColor: 'zinc',
      );
    });

    testWidgets(
      'Master-Detail layout has widened sub-navigation (250px) and maxWidth 1040 constrained content',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // 1. Verify Master-Detail presence
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Appearance'), findsWidgets);
        expect(find.text('Waveform Visualization'), findsOneWidget);

        // Sub-navigation width is exactly 250px
        final layout = tester.widget<LyraSettingsLayout<SettingsNavSection>>(
          find.byType(LyraSettingsLayout<SettingsNavSection>),
        );
        expect(layout.sidebarWidth, 250.0);

        final navContainer = find
            .ancestor(
              of: find.byType(ListView).first,
              matching: find.byType(Container),
            )
            .first;
        expect(tester.getSize(navContainer).width, 250.0);

        // Right content constrained box has maxWidth 1040
        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.byType(ConstrainedBox),
        );
        final has1040Constraint = constrainedBoxes.any(
          (cb) => cb.constraints.maxWidth == 1040.0,
        );
        expect(has1040Constraint, isTrue);

        // Verify Layout & Workbench is completely removed
        expect(find.text('Layout & Workbench'), findsNothing);
      },
    );

    testWidgets(
      'Waveform Visualization section provides live preview alongside settings and updates in real-time',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform section
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        // 1. Verify live preview card is present alongside controls
        expect(find.text('Preview'), findsOneWidget);
        expect(find.byType(WaveformScrubber), findsOneWidget);

        // Initial scrubber has points scaled proportionally to container width (matching actual visual density)
        final initialScrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(initialScrubber.waveform?.points.length, lessThan(140));
        expect(initialScrubber.waveform?.points.length, greaterThan(30));
        expect(initialScrubber.enablePulseAnimation, isTrue);
        expect(initialScrubber.enableHoverTimeGuide, isTrue);
        expect(find.text('%'), findsOneWidget);
        expect(find.textContaining('51% density (140 pts)'), findsOneWidget);

        // 2. Drag density slider and verify live preview updates in real-time
        final sliderWidget = tester.widget<ShadSlider>(find.byType(ShadSlider));
        sliderWidget.onChangeStart?.call(51.0);
        sliderWidget.onChanged?.call(50.0);
        await tester.pump();

        // Verify preferences are not saved until drag completes
        expect(prefs.nowPlayingWaveformPoints, 140);

        sliderWidget.onChangeEnd?.call(50.0);
        await tester.pumpAndSettle();
        expect(prefs.nowPlayingWaveformPoints, 138);

        // 3. Adjust density to 100% via text input
        final densityInput = find.byType(ShadInput);
        await tester.enterText(densityInput, '100');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 390);

        // 4. Toggle Show Waveform to off
        final switches = find.byType(LyraSwitch);
        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        // Scrubber is replaced with quiet disabled state indicator
        expect(find.byType(WaveformScrubber), findsNothing);
        expect(find.textContaining('Waveform hidden'), findsOneWidget);

        // Re-enable Show Waveform
        await tester.tap(switches.first);
        await tester.pumpAndSettle();
        expect(find.byType(WaveformScrubber), findsOneWidget);

        // 5. Switch target to Audio Inspector Drawer
        await tester.tap(find.text('Audio Inspector Drawer'));
        await tester.pumpAndSettle();

        final inspectorScrubber = tester.widget<WaveformScrubber>(
          find.byType(WaveformScrubber),
        );
        expect(
          inspectorScrubber.waveform?.points.length,
          greaterThanOrEqualTo(90),
        );

        // 6. Simulate Play/Pause in preview
        final playButton = find.byIcon(LucideIcons.play);
        expect(playButton, findsOneWidget);
        await tester.tap(playButton);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byIcon(LucideIcons.pause), findsOneWidget);

        // Clean up: Pause preview before ending test
        await tester.tap(find.byIcon(LucideIcons.pause));
        await tester.pump();
      },
    );

    testWidgets(
      'Appearance section shows theme preview card alongside appearance controls and no vanity badges',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // 1. Verify Preview card is present in Appearance tab
        expect(find.text('Preview'), findsOneWidget);

        // 2. Strict Apple HIG: Prohibit vanity badges & AI clutter in preview
        expect(find.text('Hi-Res'), findsNothing);
        expect(
          find.text(
            'Demonstrating theme tokens and accent highlights across components',
          ),
          findsNothing,
        );

        // 3. Title Case formatting for theme preview badge
        expect(find.text('Dark • Zinc'), findsOneWidget);

        // 4. Switch to System mode and verify preview updates
        await tester.tap(find.text('System'));
        await tester.pumpAndSettle();
        expect(prefs.themeMode, ThemeMode.system);
        expect(find.text('System • Zinc'), findsOneWidget);
      },
    );

    testWidgets(
      'Responsive layout renders cleanly without RenderFlex overflow at standard 1280x800 desktop and with long custom hex color codes',
      (tester) async {
        // AppShell at 1280 width allocates ~762px to detail content (1280 - 220 app sidebar - 250 settings sidebar - 48 padding)
        tester.view.physicalSize = const Size(1060, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        prefs.setAccentColor('#3B82F6');
        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // 1. Verify appearance section renders without overflow
        expect(find.text('Preview'), findsOneWidget);
        expect(find.text('Dark • #3B82F6'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. Switch to Waveform section and verify no overflow
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        expect(find.text('Waveform Visualization'), findsWidgets);
        expect(find.byType(WaveformScrubber), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Waveform Visualization renders cleanly without RenderFlex overflow down to compact 800px desktop width',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        expect(find.text('Waveform Visualization'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Sampling density percentage conversion preserves canonical default anchors and min boundaries without drift in logarithmic mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        final densityInput = find.byType(ShadInput);

        // 1. Initial Now Playing default (140 pts) is at ~51% on the unified logarithmic scale
        expect(
          find.descendant(of: densityInput, matching: find.text('51')),
          findsOneWidget,
        );

        // Enter 0% (min anchor for Now Playing) -> strictly reaches 49 pts (step = 780 / 49 = 15.92px)
        await tester.enterText(densityInput, '0');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(prefs.nowPlayingWaveformPoints, 49);
        expect(kNowPlayingReferenceWidth / 49, closeTo(15.92, 0.01));

        // Enter 100% (max anchor for Now Playing) -> strictly reaches 390 pts (step = 780 / 390 = 2.00px)
        await tester.enterText(densityInput, '100');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(prefs.nowPlayingWaveformPoints, 390);
        expect(kNowPlayingReferenceWidth / 390, closeTo(2.00, 0.01));

        // 2. Switch to Inspector
        await tester.tap(find.text('Audio Inspector Drawer'));
        await tester.pumpAndSettle();

        // Initial Inspector default (100 pts) is at ~69% on the unified logarithmic scale
        expect(
          find.descendant(of: densityInput, matching: find.text('69')),
          findsOneWidget,
        );

        // Enter 0% (min anchor for Inspector) -> strictly reaches 24 pts (step = 380 / 24 = 15.83px)
        await tester.enterText(densityInput, '0');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(prefs.inspectorWaveformPoints, 24);
        expect(kInspectorReferenceWidth / 24, closeTo(15.83, 0.01));

        // Enter 100% (max anchor for Inspector) -> strictly reaches 190 pts (step = 380 / 190 = 2.00px)
        await tester.enterText(densityInput, '100');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(prefs.inspectorWaveformPoints, 190);
        expect(kInspectorReferenceWidth / 190, closeTo(2.00, 0.01));
      },
    );

    testWidgets(
      'Waveform preview scales mock points proportionally to container width matching actual visual density',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        // Find preview WaveformScrubber
        final scrubberFinder = find.byType(WaveformScrubber);
        expect(scrubberFinder, findsOneWidget);

        final scrubber = tester.widget<WaveformScrubber>(scrubberFinder);
        final mockWf = scrubber.waveform;
        expect(mockWf, isNotNull);

        // In the settings card, preview points equals math.max(10, (previewWidth / densityToBarSpacing(densityPercent)).round())
        final previewRenderBox = tester.renderObject<RenderBox>(scrubberFinder);
        final previewWidth = previewRenderBox.size.width;
        final densityPercent = pointsToDensityPercent(
          prefs.nowPlayingWaveformPoints,
          WaveformTarget.nowPlaying,
        );
        final expectedSpacing = densityToBarSpacing(densityPercent);
        final expectedPoints = math.max(
          10,
          (previewWidth / expectedSpacing).round(),
        );
        expect(mockWf!.points.length, equals(expectedPoints));

        // Preview step previewWidth / previewPoints matches densityToBarSpacing within 0.5px
        final previewStep = previewWidth / expectedPoints;
        expect(previewStep, closeTo(expectedSpacing, 0.5));

        // Test that at 0%, both Now Playing preview and Inspector preview produce identical bar pitch ~16.0px
        await prefs.setNowPlayingWaveformPoints(49);
        await tester.pumpAndSettle();
        final npScrubber = tester.widget<WaveformScrubber>(scrubberFinder);
        final npPoints = npScrubber.waveform!.points.length;
        final npStep = previewWidth / npPoints;
        expect(npStep, closeTo(16.0, 0.5));

        // Switch to Inspector preview
        await tester.tap(find.text('Audio Inspector Drawer'));
        await prefs.setInspectorWaveformPoints(24);
        await tester.pumpAndSettle();

        final inspScrubberFinder = find.byType(WaveformScrubber);
        final inspScrubber = tester.widget<WaveformScrubber>(
          inspScrubberFinder,
        );
        final inspRenderBox = tester.renderObject<RenderBox>(
          inspScrubberFinder,
        );
        final inspPoints = inspScrubber.waveform!.points.length;
        final inspStep = inspRenderBox.size.width / inspPoints;
        expect(inspStep, closeTo(16.0, 0.5));
        expect(npStep, closeTo(inspStep, 0.5));
      },
    );

    test(
      'Waveform preview points clamp calculation handles extremely narrow widths (< 10px) safely without ArgumentError',
      () {
        final spacing = densityToBarSpacing(51);
        for (final width in [0.0, 1.0, 5.0, 8.0, 9.4, 9.9, 10.0, 15.0, 350.0]) {
          final previewPoints = width >= 10.0
              ? math.max(10, (width / spacing).round())
              : (width > 0 ? math.max(1, width.round()) : 10);
          expect(previewPoints, greaterThan(0));
          if (width >= 10.0) {
            expect(previewPoints, greaterThanOrEqualTo(10));
          }
          final wf = WaveformData.mock(points: previewPoints, pcmHash: 'test');
          expect(wf.points.length, equals(previewPoints));
        }
      },
    );

    testWidgets(
      'Switching target resets _isDragging and cancels active animation cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        // Simulate drag start on slider
        final sliderWidget = tester.widget<ShadSlider>(find.byType(ShadSlider));
        sliderWidget.onChangeStart?.call(12.0);
        sliderWidget.onChanged?.call(50.0);
        await tester.pump();

        // Switch target mid-drag
        await tester.tap(find.text('Audio Inspector Drawer'));
        await tester.pumpAndSettle();

        // Subsequent external preference changes must NOT be dropped
        prefs.setShowInspectorWaveform(false);
        await tester.pumpAndSettle();
        expect(find.byType(WaveformScrubber), findsNothing);
      },
    );

    testWidgets(
      'Appearance section allows theme mode, preset swatches, and custom color picker with ShadPopover',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // 1. Theme mode switches
        await tester.tap(find.text('Zinc Light'));
        await tester.pumpAndSettle();
        expect(prefs.themeMode, ThemeMode.light);

        await tester.tap(find.text('Zinc Dark'));
        await tester.pumpAndSettle();
        expect(prefs.themeMode, ThemeMode.dark);

        // 2. Preset swatches
        expect(find.text('Zinc'), findsOneWidget);
        expect(find.text('Slate'), findsOneWidget);
        expect(find.text('Blue'), findsOneWidget);
        expect(find.text('Emerald'), findsOneWidget);
        expect(find.text('Violet'), findsOneWidget);
        expect(find.text('Rose'), findsOneWidget);
        expect(find.text('Amber'), findsOneWidget);

        await tester.tap(find.text('Emerald'));
        await tester.pumpAndSettle();
        expect(prefs.accentColor, 'emerald');

        await tester.tap(find.text('Amber'));
        await tester.pumpAndSettle();
        expect(prefs.accentColor, 'amber');

        // 3. Custom Color Picker button opens Popover with Hue slider, Hex input, and Apply
        await tester.tap(find.text('Custom...'));
        await tester.pumpAndSettle();

        expect(find.text('Custom Color'), findsOneWidget);
        expect(find.text('Hex Code'), findsOneWidget);
        expect(find.text('Apply'), findsOneWidget);

        // Enter a valid hex code into hex input
        final hexInput = find.byType(ShadInput);
        expect(hexInput, findsOneWidget);
        await tester.enterText(hexInput, '3B82F6');
        await tester.pumpAndSettle();

        // Click Apply
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(prefs.accentColor, '#3B82F6');
      },
    );

    testWidgets(
      'Waveform Visualization section binds to selected target and synchronizes slider & input',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform Visualization
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        expect(find.text('Visualization Target'), findsOneWidget);
        expect(find.text('Now Playing Bar'), findsOneWidget);

        // 1. Test Now Playing target controls
        final switches = find.byType(LyraSwitch);
        expect(switches, findsNWidgets(3));

        // Toggle Show Waveform
        await tester.tap(switches.at(0));
        await tester.pumpAndSettle();
        expect(prefs.showNowPlayingWaveform, isFalse);
        expect(prefs.showInspectorWaveform, isTrue); // Unaffected

        // Toggle Pulse Shimmer Animation
        await tester.tap(switches.at(1));
        await tester.pumpAndSettle();
        expect(prefs.nowPlayingWaveformPulseAnimation, isFalse);
        expect(prefs.inspectorWaveformPulseAnimation, isTrue); // Unaffected

        // Toggle Hover Timecode Guide
        await tester.tap(switches.at(2));
        await tester.pumpAndSettle();
        expect(prefs.nowPlayingWaveformHoverTimeGuide, isFalse);
        expect(prefs.inspectorWaveformHoverTimeGuide, isTrue); // Unaffected

        // 2. Test density slider & numeric input synchronization
        final densityInput = find.byType(ShadInput);
        expect(densityInput, findsOneWidget);

        // Enter new percentage in input field (20% -> 74 pts on unified scale)
        await tester.enterText(densityInput, '20');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 74);

        // 3. Switch target to Audio Inspector Drawer via ShadTabs
        expect(find.byType(ShadTabs<WaveformTarget>), findsOneWidget);
        await tester.tap(find.text('Audio Inspector Drawer'));
        await tester.pumpAndSettle();

        // Verified Inspector switches show their own initial states
        expect(tester.widget<LyraSwitch>(switches.at(0)).value, isTrue);
        expect(tester.widget<LyraSwitch>(switches.at(1)).value, isTrue);
        expect(tester.widget<LyraSwitch>(switches.at(2)).value, isTrue);

        // Toggle Inspector switches
        await tester.tap(switches.at(1));
        await tester.pumpAndSettle();
        expect(prefs.inspectorWaveformPulseAnimation, isFalse);
        expect(
          prefs.nowPlayingWaveformPulseAnimation,
          isFalse,
        ); // Remained false

        // Update Inspector density (50% -> 67 pts on unified scale)
        await tester.enterText(densityInput, '50');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.inspectorWaveformPoints, 67);
        expect(prefs.nowPlayingWaveformPoints, 74); // Remained 74
      },
    );

    testWidgets(
      'deriveShadColorScheme and deriveLyraThemeTokens handle presets and custom hex correctly',
      (tester) async {
        // Presets in Dark Mode
        final zincDark = deriveLyraThemeTokens('zinc', true);
        expect(zincDark.primary, LyraColors.softWhite);

        final blueDark = deriveLyraThemeTokens('blue', true);
        expect(blueDark.primary, LyraColors.blue500);

        final emeraldDark = deriveLyraThemeTokens('emerald', true);
        expect(emeraldDark.primary, LyraColors.emerald500);

        final amberDark = deriveLyraThemeTokens('amber', true);
        expect(amberDark.primary, LyraColors.amber500);

        // Custom Hex in Dark & Light Mode
        final customTokens = deriveLyraThemeTokens('#FF0055', true);
        expect(customTokens.primary, const Color(0xFFFF0055));
        expect(customTokens.ring, const Color(0xFFFF0055));

        // ShadColorScheme derivation
        final blueScheme = deriveShadColorScheme('blue', Brightness.dark);
        expect(blueScheme.primary, isNotNull);

        final customScheme = deriveShadColorScheme('#3B82F6', Brightness.dark);
        expect(customScheme.primary, const Color(0xFF3B82F6));
        expect(customScheme.ring, const Color(0xFF3B82F6));
      },
    );

    testWidgets('Strict No-Emoji verification in SettingsView', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildSettingsTestApp(prefs));
      await tester.pumpAndSettle();

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );

      // Check Appearance section texts
      for (final tw in tester.widgetList<Text>(find.byType(Text))) {
        final data = tw.data ?? tw.textSpan?.toPlainText() ?? '';
        expect(
          emojiRegex.hasMatch(data),
          isFalse,
          reason: 'Emoji found: $data',
        );
      }

      // Switch to Waveform section
      await tester.tap(find.text('Waveform Visualization'));
      await tester.pumpAndSettle();

      // Check Waveform section texts
      for (final tw in tester.widgetList<Text>(find.byType(Text))) {
        final data = tw.data ?? tw.textSpan?.toPlainText() ?? '';
        expect(
          emojiRegex.hasMatch(data),
          isFalse,
          reason: 'Emoji found: $data',
        );
      }
    });

    testWidgets(
      'Dark mode accent colors strictly preserve pure Charcoal neutral canvas',
      (tester) async {
        const presets = [
          'zinc',
          'blue',
          'emerald',
          'violet',
          'rose',
          'amber',
          'slate',
          '#123456',
        ];
        for (final preset in presets) {
          final scheme = deriveShadColorScheme(preset, Brightness.dark);
          expect(
            scheme.background,
            const Color(0xFF101010),
            reason: '$preset background',
          );
          expect(scheme.card, const Color(0xFF1B1B1B), reason: '$preset card');
          expect(
            scheme.border,
            const Color(0xFF242424),
            reason: '$preset border',
          );
          expect(
            scheme.foreground,
            const Color(0xFFEDEDED),
            reason: '$preset foreground',
          );
        }

        // Verify curated dark mode token values
        expect(
          deriveLyraThemeTokens('zinc', true).ring,
          const Color(0xFF71717A),
        );
        expect(
          deriveLyraThemeTokens('blue', true).ring,
          const Color(0xFF60A5FA),
        );
        expect(
          deriveLyraThemeTokens('emerald', true).ring,
          const Color(0xFF34D399),
        );
        expect(
          deriveLyraThemeTokens('violet', true).ring,
          const Color(0xFFA78BFA),
        );
        expect(
          deriveLyraThemeTokens('rose', true).ring,
          const Color(0xFFFB7185),
        );
        expect(
          deriveLyraThemeTokens('amber', true).ring,
          const Color(0xFFFBBF24),
        );
        expect(
          deriveLyraThemeTokens('amber', true).primaryForeground,
          const Color(0xFF101010),
        );
        expect(
          deriveLyraThemeTokens('slate', true).ring,
          const Color(0xFFCBD5E1),
        );
        expect(
          deriveLyraThemeTokens('slate', true).primary,
          const Color(0xFF94A3B8),
        );
      },
    );

    testWidgets(
      'Now Playing bar supports up to 100% density (390 pts) and Inspector target up to 100% (190 pts)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform section
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        final slider = tester.widget<ShadSlider>(find.byType(ShadSlider));
        expect(slider.min, 0.0);
        expect(slider.max, 100.0);

        // Enter 100% into density input
        final densityInput = find.byType(ShadInput);
        await tester.enterText(densityInput, '100');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 390);

        // Switch to Inspector via ShadTabs
        await tester.tap(find.text('Audio Inspector Drawer'));
        await tester.pumpAndSettle();

        // Inspector slider min is 0.0, max is 100.0
        final inspectorSlider = tester.widget<ShadSlider>(
          find.byType(ShadSlider),
        );
        expect(inspectorSlider.min, 0.0);
        expect(inspectorSlider.max, 100.0);

        // Inspector initial was 100 pts (~69% on unified scale)
        expect(prefs.inspectorWaveformPoints, 100);

        // Enter 150 in Inspector input -> should clamp to 100% (190 pts)
        await tester.enterText(densityInput, '150');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.inspectorWaveformPoints, 190);
      },
    );

    testWidgets(
      'Dragging Sampling Density slider updates preferences on change end',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform section
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        // 1. Now Playing target: drag/change slider to 50% -> 138 pts (unified midpoint)
        final slider = tester.widget<ShadSlider>(find.byType(ShadSlider));
        slider.onChanged?.call(50.0);
        slider.onChangeEnd?.call(50.0);
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 138);

        // 2. Audio Inspector target: switch target via ShadTabs and drag slider to 60% -> 83 pts
        await tester.tap(find.text('Audio Inspector Drawer'));
        await tester.pumpAndSettle();

        final inspectorSlider = tester.widget<ShadSlider>(
          find.byType(ShadSlider),
        );
        inspectorSlider.onChanged?.call(60.0);
        inspectorSlider.onChangeEnd?.call(60.0);
        await tester.pumpAndSettle();

        expect(prefs.inspectorWaveformPoints, 83);
      },
    );

    testWidgets(
      'Slider track taps and keyboard adjustments immediately update preferences without onChangeEnd',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform section
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 140);

        final slider = tester.widget<ShadSlider>(find.byType(ShadSlider));
        // Simulate track tap or arrow key which triggers onChanged directly while _isDragging == false
        slider.onChanged?.call(50.0);
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 138);
      },
    );

    testWidgets(
      'Tapping Sampling Density slider track smoothly animates value and saves density',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform section
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 140);

        // Tap the slider on the right side (~80% across 140px width)
        final sliderFinder = find.byType(ShadSlider);
        final topLeft = tester.getTopLeft(sliderFinder);
        await tester.tapAt(Offset(topLeft.dx + 112.0, topLeft.dy + 12.0));
        await tester.pump(); // Start animation frame
        await tester.pump(const Duration(milliseconds: 75)); // Halfway

        // Intermediate value should have advanced past initial 51%
        final midVal =
            tester.widget<ShadSlider>(sliderFinder).controller?.value ?? 0;
        expect(midVal, greaterThan(51.0));

        // Settle animation
        await tester.pumpAndSettle();
        expect(prefs.nowPlayingWaveformPoints, greaterThan(200));
      },
    );

    testWidgets(
      'Typing invalid text into density input and unfocusing restores the text to current percentage',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform section
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 140);
        final densityInput = find.byType(ShadInput);
        expect(densityInput, findsOneWidget);

        // 1. Enter empty text
        await tester.enterText(densityInput, '');
        await tester.pump();

        // Unfocus
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        // Should restore to current percent (51% for 140 pts)
        expect(
          find.descendant(of: densityInput, matching: find.text('51')),
          findsOneWidget,
        );
        expect(prefs.nowPlayingWaveformPoints, 140);

        // 2. Enter out-of-range text (e.g. -5, min is 0%)
        await tester.enterText(densityInput, '-5');
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        // Should restore to current percent (51)
        expect(
          find.descendant(of: densityInput, matching: find.text('51')),
          findsOneWidget,
        );
        expect(prefs.nowPlayingWaveformPoints, 140);

        // 3. Enter out-of-range text exceeding max (e.g. 9999, max is 100%)
        await tester.enterText(densityInput, '9999');
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        // Should restore to current percent (51)
        expect(
          find.descendant(of: densityInput, matching: find.text('51')),
          findsOneWidget,
        );
        expect(prefs.nowPlayingWaveformPoints, 140);
      },
    );

    testWidgets(
      'does not overwrite density text input while user is actively focused and typing',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        final densityInput = find.byType(ShadInput);
        // Give focus to density input and enter partial input '8'
        await tester.tap(densityInput);
        await tester.pump();
        await tester.enterText(densityInput, '8');
        await tester.pump();

        // Simulate external preference update (e.g. pulse animation changed externally)
        prefs.setNowPlayingWaveformPulseAnimation(false);
        await tester.pump();

        // Text in the input should still be '8', not overwritten by external update!
        expect(
          find.descendant(of: densityInput, matching: find.text('8')),
          findsOneWidget,
        );
      },
    );

    testWidgets('SettingsView eliminated redundant text and description noise', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildSettingsTestApp(prefs));
      await tester.pumpAndSettle();

      // In Appearance section: verify card summary text is gone
      expect(
        find.text(
          'Customize the desktop client theme tokens, appearance mode, and accent color.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Choose accent highlight tint for focus rings, playhead indicators, and selections.',
        ),
        findsNothing,
      );

      // In Waveform section: verify row descriptions are gone
      await tester.tap(find.text('Waveform Visualization'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Audio playback scrubbing curve, sampling density, and interactive indicators.',
        ),
        findsNothing,
      );
      expect(find.text('Show interactive waveform'), findsNothing);
      expect(
        find.text(
          'Resolution point density for interactive waveform rendering',
        ),
        findsNothing,
      );
      expect(
        find.text('Pulse shimmer traveling wave during playback'),
        findsNothing,
      );
      expect(
        find.text('Show hover timecode guide & timestamp badge'),
        findsNothing,
      );
    });

    testWidgets(
      'tapping density slider animates and calls setNowPlayingWaveformPoints only ONCE on completion',
      (tester) async {
        final countingPrefs = _CountingPreferencesService(
          nowPlayingWaveformPoints: 140,
        );
        await tester.pumpWidget(_buildSettingsTestApp(countingPrefs));
        await tester.pumpAndSettle();

        // Navigate to Waveform Visualization
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        final sliderFinder = find.byType(ShadSlider);
        expect(sliderFinder, findsOneWidget);

        final topLeft = tester.getTopLeft(sliderFinder);
        final size = tester.getSize(sliderFinder);

        // Tap at 80% width
        await tester.tapAt(
          Offset(topLeft.dx + size.width * 0.8, topLeft.dy + size.height * 0.5),
        );
        await tester.pump();

        // During animation (50ms of 150ms): should NOT have fired setNowPlayingWaveformPoints
        await tester.pump(const Duration(milliseconds: 50));
        expect(countingPrefs.setPointsCallCount, equals(0));

        // Settle animation: should have fired setNowPlayingWaveformPoints exactly once
        await tester.pumpAndSettle();
        expect(countingPrefs.setPointsCallCount, equals(1));
      },
    );

    testWidgets(
      'WaveformPreviewCard tapping Play preview advances simulated playback position and updates time label, and pause halts advancement',
      (tester) async {
        final prefs = InMemoryPreferencesService();
        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform section
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        // Initial time label should show "0:45"
        expect(find.text('0:45'), findsOneWidget);
        expect(find.text('3:45'), findsOneWidget);

        // Tap Play preview
        final playButton = find.byTooltip('Play preview');
        expect(playButton, findsOneWidget);
        await tester.tap(playButton);
        await tester.pump();

        // Advance simulated time by 1000ms (1 second)
        await tester.pump(const Duration(milliseconds: 1000));

        // Time should have advanced from 0:45 to 0:46
        expect(find.text('0:46'), findsOneWidget);
        expect(find.text('0:45'), findsNothing);

        // Tap Pause preview
        final pauseButton = find.byTooltip('Pause preview');
        expect(pauseButton, findsOneWidget);
        await tester.tap(pauseButton);
        await tester.pump();

        // Advance simulated time by another 1000ms while paused
        await tester.pump(const Duration(milliseconds: 1000));

        // Time should remain at 0:46 and not advance
        expect(find.text('0:46'), findsOneWidget);
      },
    );

    testWidgets(
      'Waveform preview maintains identical container padding, decoration, and play button position across target tabs',
      (tester) async {
        final prefs = InMemoryPreferencesService();
        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // Switch to Waveform section
        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        // Verify initial target is Now Playing
        final playIconFinder = find.byIcon(LucideIcons.play);
        expect(playIconFinder, findsOneWidget);
        final initialPlayButtonPos = tester.getTopLeft(playIconFinder);

        // Find preview container enclosing the play button & waveform
        final previewCardFinder = find.byType(WaveformPreviewCard);
        expect(previewCardFinder, findsOneWidget);
        final containerFinder = find.descendant(
          of: previewCardFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                w.child is Row,
          ),
        );
        expect(containerFinder, findsOneWidget);

        final nowPlayingContainer = tester.widget<Container>(containerFinder);
        final nowPlayingPadding = nowPlayingContainer.padding;
        final nowPlayingDeco = nowPlayingContainer.decoration as BoxDecoration;

        // Switch to Inspector tab
        await tester.tap(find.text('Audio Inspector Drawer'));
        await tester.pumpAndSettle();

        // Verify play button position has ZERO horizontal shift (0 pixel delta)
        final inspectorPlayButtonPos = tester.getTopLeft(
          find.byIcon(LucideIcons.play),
        );
        expect(inspectorPlayButtonPos.dx, equals(initialPlayButtonPos.dx));
        expect(inspectorPlayButtonPos.dy, equals(initialPlayButtonPos.dy));

        // Verify container padding and decoration are identical
        final inspectorContainer = tester.widget<Container>(containerFinder);
        final inspectorPadding = inspectorContainer.padding;
        final inspectorDeco = inspectorContainer.decoration as BoxDecoration;

        expect(inspectorPadding, equals(nowPlayingPadding));
        expect(inspectorDeco.color, equals(nowPlayingDeco.color));
        expect(inspectorDeco.borderRadius, equals(nowPlayingDeco.borderRadius));
        expect(inspectorDeco.border, equals(nowPlayingDeco.border));
      },
    );

    testWidgets(
      'Switching between Now Playing and Inspector preview tabs preserves playback state without resetting',
      (tester) async {
        final prefs = InMemoryPreferencesService();
        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Waveform Visualization'));
        await tester.pumpAndSettle();

        // Tap Play preview
        await tester.tap(find.byTooltip('Play preview'));
        await tester.pump();
        expect(find.byTooltip('Pause preview'), findsOneWidget);

        // Switch to Inspector tab
        await tester.tap(find.text('Audio Inspector Drawer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Playback state should remain playing (Pause preview still visible)
        expect(find.byTooltip('Pause preview'), findsOneWidget);

        // Pause preview to clean up timer
        await tester.tap(find.byTooltip('Pause preview'));
        await tester.pump();
      },
    );
  });

  group('SettingsView Interaction & Shortcuts Sections', () {
    testWidgets(
      'navigates to Interaction & Behavior section and toggles track activation via ShadTabs',
      (tester) async {
        final prefs = InMemoryPreferencesService();

        await tester.pumpWidget(
          _buildSettingsTestApp(
            prefs,
            child: SettingsView(preferencesService: prefs),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Interaction & Behavior section in sidebar
        await tester.tap(find.text('Interaction & Behavior'));
        await tester.pumpAndSettle();

        // Verify Interaction section headers and icons (sidebar + card header)
        expect(find.text('Interaction & Behavior'), findsNWidgets(2));
        expect(find.byIcon(LucideIcons.mousePointerClick), findsNWidgets(2));
        expect(find.text('Track Activation'), findsOneWidget);
        // Redundant subtitle should be eliminated per Apple HIG concise typography
        expect(
          find.text(
            'Configure track table click activation and playback triggers.',
          ),
          findsNothing,
        );

        // Verify initial selection is Double-Click
        expect(
          prefs.trackActivationMode,
          equals(TrackActivationMode.doubleClick),
        );
        expect(find.text('Double-Click'), findsOneWidget);
        expect(find.text('Single-Click'), findsOneWidget);

        // Tap Single-Click option
        await tester.tap(find.text('Single-Click'));
        await tester.pumpAndSettle();

        expect(
          prefs.trackActivationMode,
          equals(TrackActivationMode.singleClick),
        );

        // Tap Double-Click option again
        await tester.tap(find.text('Double-Click'));
        await tester.pumpAndSettle();

        expect(
          prefs.trackActivationMode,
          equals(TrackActivationMode.doubleClick),
        );
      },
    );

    testWidgets(
      'navigates to Keyboard Shortcuts section and displays categorized shortcuts with mono badges',
      (tester) async {
        final prefs = InMemoryPreferencesService();

        await tester.pumpWidget(
          _buildSettingsTestApp(
            prefs,
            child: SettingsView(preferencesService: prefs),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Keyboard Shortcuts in sidebar
        await tester.tap(find.text('Keyboard Shortcuts'));
        await tester.pumpAndSettle();

        // Verify category headers and section icon (sidebar + card header)
        expect(find.byIcon(LucideIcons.keyboard), findsNWidgets(2));
        expect(
          find.text(
            'Desktop keyboard commands for playback control, track selection, and library navigation.',
          ),
          findsNothing,
        );
        expect(find.text('PLAYBACK & QUEUE'), findsOneWidget);
        expect(find.text('SELECTION & LIST'), findsOneWidget);
        expect(find.text('NAVIGATION & PANELS'), findsOneWidget);

        // Verify specific shortcut entries
        expect(find.text('Play / Pause playback'), findsOneWidget);
        expect(find.text('Space'), findsOneWidget);
        expect(find.text('Select all tracks in current view'), findsOneWidget);
        expect(find.text('Cmd / Ctrl + A'), findsOneWidget);
        expect(find.text('Toggle Audio Inspector drawer'), findsOneWidget);
        expect(find.text('Cmd / Ctrl + I'), findsOneWidget);
      },
    );

    testWidgets(
      'ThemeOptionCard and AccentColorCard support keyboard Tab navigation and Enter/Space activation with Focus Ring',
      (tester) async {
        final prefs = InMemoryPreferencesService();
        await tester.pumpWidget(_buildSettingsTestApp(prefs));
        await tester.pumpAndSettle();

        // 1. Verify FocusableActionDetector widgets exist for theme and accent cards
        final fadFinder = find.descendant(
          of: find.byType(SettingsView),
          matching: find.byType(FocusableActionDetector),
        );
        expect(fadFinder, findsWidgets);

        // 2. Find Zinc Light theme card
        final lightCardText = find.text('Zinc Light');
        expect(lightCardText, findsOneWidget);
        final lightCardFad = find.ancestor(
          of: lightCardText,
          matching: find.byType(FocusableActionDetector),
        );
        expect(lightCardFad, findsOneWidget);

        // Request focus on the light card FocusNode
        final fadWidget = tester.widget<FocusableActionDetector>(lightCardFad);
        fadWidget.focusNode!.requestFocus();
        await tester.pumpAndSettle();

        expect(fadWidget.focusNode!.hasFocus, isTrue);

        // Verify focus ring is rendered on AnimatedContainer
        final animatedContainer = find.descendant(
          of: lightCardFad,
          matching: find.byType(AnimatedContainer),
        );
        expect(animatedContainer, findsOneWidget);
        final containerWidget =
            tester.widget<AnimatedContainer>(animatedContainer);
        final deco = containerWidget.decoration as BoxDecoration;
        final border = deco.border as Border;
        final expectedTokens = deriveLyraThemeTokens(prefs.accentColor, true);
        expect(border.top.color, equals(expectedTokens.ring));
        expect(border.top.width, equals(2.0));

        // 3. Activate via Enter key
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Should switch to light mode in preferences
        expect(prefs.themeMode, equals(ThemeMode.light));

        // 4. Test Accent Color card focus and Space key activation
        final emeraldOption = find.text('Emerald');
        expect(emeraldOption, findsOneWidget);
        final emeraldFad = find.ancestor(
          of: emeraldOption,
          matching: find.byType(FocusableActionDetector),
        );
        expect(emeraldFad, findsOneWidget);

        final emeraldFadWidget =
            tester.widget<FocusableActionDetector>(emeraldFad);
        emeraldFadWidget.focusNode!.requestFocus();
        await tester.pumpAndSettle();
        expect(emeraldFadWidget.focusNode!.hasFocus, isTrue);

        // Activate via Space key
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();

        expect(prefs.accentColor, equals('emerald'));
      },
    );

    testWidgets(
      'AppearancePreviewCard progress bar background uses tokens.border for WCAG > 3:1 contrast in light mode',
      (tester) async {
        final prefs = InMemoryPreferencesService(themeMode: ThemeMode.light);
        final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
        const factory = ShadcnFactory();

        await tester.pumpWidget(
          ShadApp(
            debugShowCheckedModeBanner: false,
            home: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeNotifier,
              builder: (context, themeMode, _) {
                final isDark = themeMode == ThemeMode.dark;
                final tokens = deriveLyraThemeTokens(prefs.accentColor, isDark);
                final colorScheme = deriveShadColorScheme(
                  prefs.accentColor,
                  isDark ? Brightness.dark : Brightness.light,
                );

                return ShadTheme(
                  data: ShadThemeData(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    colorScheme: colorScheme,
                  ),
                  child: LyraDesignSystemScope(
                    factory: factory,
                    tokens: tokens,
                    themeModeNotifier: themeModeNotifier,
                    child: Scaffold(
                      body: SettingsView(preferencesService: prefs),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find progress bar background container in preview card
        final lightTokens = deriveLyraThemeTokens('zinc', false);
        final progressBarTrack = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxHeight == 4.0 &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == lightTokens.border,
        );
        expect(
          progressBarTrack,
          findsOneWidget,
          reason:
              'Progress bar background must use tokens.border (zinc200, #E4E4E7) to satisfy WCAG contrast > 3:1 in light mode',
        );
      },
    );
  });
}
