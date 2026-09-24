// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_switch.dart';
import 'package:ui/features/settings/services/preferences_service.dart';
import 'package:ui/features/settings/settings_view.dart';
import 'package:ui/main.dart';

Widget _buildSettingsTestApp(PreferencesService prefs) {
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
            child: Scaffold(body: SettingsView(preferencesService: prefs)),
          ),
        );
      },
    ),
  );
}

void main() {
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
      'Master-Detail layout has sub-navigation and maxWidth 720 constrained content',
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

        // Sub-navigation width is ~200px
        final navFinder = find.ancestor(
          of: find.text('Waveform Visualization'),
          matching: find.byType(Container),
        );
        expect(navFinder, findsWidgets);

        // Right content constrained box has maxWidth 720
        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.byType(ConstrainedBox),
        );
        final has720Constraint = constrainedBoxes.any(
          (cb) => cb.constraints.maxWidth == 720.0,
        );
        expect(has720Constraint, isTrue);

        // Verify Layout & Workbench is completely removed
        expect(find.text('Layout & Workbench'), findsNothing);
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

        // Enter new points in input field
        await tester.enterText(densityInput, '200');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 200);

        // 3. Switch target to Audio Inspector Drawer via ShadSelect
        await tester.tap(find.text('Now Playing Bar'));
        await tester.pumpAndSettle();

        expect(find.text('Audio Inspector Drawer'), findsWidgets);
        await tester.tap(find.text('Audio Inspector Drawer').last);
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

        // Update Inspector density
        await tester.enterText(densityInput, '60');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.inspectorWaveformPoints, 60);
        expect(prefs.nowPlayingWaveformPoints, 200); // Remained 200
      },
    );

    testWidgets(
      'deriveShadColorScheme and deriveLyraThemeTokens handle presets and custom hex correctly',
      (tester) async {
        // Presets in Dark Mode
        final zincDark = deriveLyraThemeTokens('zinc', true);
        expect(zincDark.primary, LyraColors.zinc50);

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
      'Dark mode accent colors strictly preserve pure Zinc neutral canvas',
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
            const Color(0xFF09090B),
            reason: '$preset background',
          );
          expect(scheme.card, const Color(0xFF18181B), reason: '$preset card');
          expect(
            scheme.border,
            const Color(0xFF27272A),
            reason: '$preset border',
          );
          expect(
            scheme.foreground,
            const Color(0xFFFAFAFA),
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
          const Color(0xFF09090B),
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
      'Now Playing bar supports up to 1200 density and clamps to 300 on Inspector target switch',
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
        expect(slider.max, 1200.0);

        // Enter 1200 into density input
        final densityInput = find.byType(ShadInput);
        await tester.enterText(densityInput, '1200');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.nowPlayingWaveformPoints, 1200);

        // Switch to Inspector
        await tester.tap(find.text('Now Playing Bar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Audio Inspector Drawer').last);
        await tester.pumpAndSettle();

        // Inspector slider max is 300
        final inspectorSlider = tester.widget<ShadSlider>(
          find.byType(ShadSlider),
        );
        expect(inspectorSlider.max, 300.0);

        // Inspector initial was 100
        expect(prefs.inspectorWaveformPoints, 100);

        // Enter 500 in Inspector input -> should clamp to 300
        await tester.enterText(densityInput, '500');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(prefs.inspectorWaveformPoints, 300);
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
  });
}
