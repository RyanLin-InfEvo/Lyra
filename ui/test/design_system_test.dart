// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_badge.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
import 'package:ui/design_system/widgets/lyra_card.dart';
import 'package:ui/design_system/widgets/lyra_input.dart';

Widget _buildTestApp({
  required Widget child,
  ThemeMode initialThemeMode = ThemeMode.dark,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(initialThemeMode);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final tokens = isDark
            ? LyraThemeTokens.dark()
            : LyraThemeTokens.light();
        final shadTheme = ShadThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          colorScheme: isDark
              ? const ShadZincColorScheme.dark()
              : const ShadZincColorScheme.light(),
        );

        return ShadTheme(
          data: shadTheme,
          child: LyraDesignSystemScope(
            factory: factory,
            tokens: tokens,
            themeModeNotifier: themeModeNotifier,
            child: Scaffold(body: child),
          ),
        );
      },
    ),
  );
}

void main() {
  group('Design System Tokens', () {
    test('LyraThemeTokens dark mode sets zinc palette correctly', () {
      final tokens = LyraThemeTokens.dark();
      expect(tokens.isDark, isTrue);
      expect(tokens.background, equals(LyraColors.zinc950));
      expect(tokens.card, equals(LyraColors.zinc900));
      expect(tokens.border, equals(LyraColors.zinc800));
      expect(tokens.text, equals(LyraColors.zinc50));
      expect(tokens.textMuted, equals(LyraColors.zinc400));
      expect(tokens.ring, equals(LyraColors.blue500));
    });

    test('LyraThemeTokens light mode sets zinc light palette', () {
      final tokens = LyraThemeTokens.light();
      expect(tokens.isDark, isFalse);
      expect(tokens.background, equals(const Color(0xFFFFFFFF)));
      expect(tokens.text, equals(LyraColors.zinc950));
      expect(tokens.border, equals(LyraColors.zinc200));
    });
  });

  group('Facade Widgets with ShadcnFactory', () {
    testWidgets(
      'LyraButton renders primary, secondary, outline, ghost variants',
      (tester) async {
        bool primaryClicked = false;
        bool secondaryClicked = false;

        await tester.pumpWidget(
          _buildTestApp(
            child: Column(
              children: [
                LyraButton(
                  onPressed: () => primaryClicked = true,
                  child: const Text('Primary Action'),
                ),
                LyraButton.secondary(
                  onPressed: () => secondaryClicked = true,
                  child: const Text('Secondary Action'),
                ),
                const LyraButton.outline(child: Text('Outline Action')),
                const LyraButton.ghost(child: Text('Ghost Action')),
                const LyraButton.destructive(child: Text('Destructive Action')),
              ],
            ),
          ),
        );

        expect(find.text('Primary Action'), findsOneWidget);
        expect(find.text('Secondary Action'), findsOneWidget);
        expect(find.text('Outline Action'), findsOneWidget);
        expect(find.text('Ghost Action'), findsOneWidget);
        expect(find.text('Destructive Action'), findsOneWidget);

        await tester.tap(find.text('Primary Action'));
        expect(primaryClicked, isTrue);

        await tester.tap(find.text('Secondary Action'));
        expect(secondaryClicked, isTrue);
      },
    );

    testWidgets('LyraCard renders header, description, child, and footer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const LyraCard(
            title: Text('Card Title'),
            description: Text('Card Description'),
            footer: Text('Card Footer'),
            child: Text('Card Body Content'),
          ),
        ),
      );

      expect(find.text('Card Title'), findsOneWidget);
      expect(find.text('Card Description'), findsOneWidget);
      expect(find.text('Card Body Content'), findsOneWidget);
      expect(find.text('Card Footer'), findsOneWidget);
    });

    testWidgets('LyraBadge renders variants correctly', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              LyraBadge(child: Text('Default Badge')),
              LyraBadge.secondary(child: Text('Secondary Badge')),
              LyraBadge.outline(child: Text('Outline Badge')),
              LyraBadge.destructive(child: Text('Destructive Badge')),
              LyraBadge.success(child: Text('Success Badge')),
            ],
          ),
        ),
      );

      expect(find.text('Default Badge'), findsOneWidget);
      expect(find.text('Secondary Badge'), findsOneWidget);
      expect(find.text('Outline Badge'), findsOneWidget);
      expect(find.text('Destructive Badge'), findsOneWidget);
      expect(find.text('Success Badge'), findsOneWidget);
    });

    testWidgets('LyraInput accepts text and handles controllers', (
      tester,
    ) async {
      final controller = TextEditingController();
      String changedText = '';

      await tester.pumpWidget(
        _buildTestApp(
          child: LyraInput(
            controller: controller,
            placeholder: 'Search test',
            onChanged: (val) => changedText = val,
          ),
        ),
      );

      expect(find.text('Search test'), findsOneWidget);

      await tester.enterText(find.byType(LyraInput), 'FLAC 24/96');
      expect(controller.text, equals('FLAC 24/96'));
      expect(changedText, equals('FLAC 24/96'));
    });
  });

  group('Dynamic Theme Switching', () {
    testWidgets(
      'Toggling theme switches tokens and ShadTheme brightness and colors synchronously in a single frame',
      (tester) async {
        final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
        addTearDown(themeNotifier.dispose);

        late LyraThemeTokens currentTokens;
        late ShadThemeData currentShadTheme;

        final testWidget = Builder(
          builder: (context) {
            currentTokens = LyraDesignSystemScope.of(context).tokens;
            currentShadTheme = ShadTheme.of(context);
            return Column(
              children: [
                LyraButton.secondary(child: Text('Active Selection Item')),
                LyraCard(child: Text('Card Content')),
              ],
            );
          },
        );

        await tester.pumpWidget(
          _buildTestApp(child: testWidget, themeNotifier: themeNotifier),
        );
        await tester.pump();

        // Verify initial Dark Theme
        expect(currentTokens.isDark, isTrue);
        expect(currentTokens.background, equals(LyraColors.zinc950));
        expect(currentTokens.card, equals(LyraColors.zinc900));
        expect(currentTokens.secondary, equals(LyraColors.zinc800));
        expect(currentShadTheme.brightness, equals(Brightness.dark));
        expect(
          currentShadTheme.colorScheme.secondary,
          equals(const ShadZincColorScheme.dark().secondary),
        );
        expect(
          currentShadTheme.colorScheme.card,
          equals(const ShadZincColorScheme.dark().card),
        );

        // Switch to Light Theme (single frame 0ms)
        themeNotifier.value = ThemeMode.light;
        await tester.pump();

        // Verify updated Light Theme synchronously in the exact same frame
        expect(currentTokens.isDark, isFalse);
        expect(currentTokens.background, equals(const Color(0xFFFFFFFF)));
        expect(currentTokens.card, equals(const Color(0xFFFFFFFF)));
        expect(currentTokens.secondary, equals(LyraColors.zinc100));
        expect(currentTokens.text, equals(LyraColors.zinc950));
        expect(currentShadTheme.brightness, equals(Brightness.light));
        expect(
          currentShadTheme.colorScheme.secondary,
          equals(const ShadZincColorScheme.light().secondary),
        );
        expect(
          currentShadTheme.colorScheme.card,
          equals(const ShadZincColorScheme.light().card),
        );

        // Switch back to Dark Theme (single frame 0ms)
        themeNotifier.value = ThemeMode.dark;
        await tester.pump();

        expect(currentTokens.isDark, isTrue);
        expect(currentShadTheme.brightness, equals(Brightness.dark));
      },
    );
  });
}
