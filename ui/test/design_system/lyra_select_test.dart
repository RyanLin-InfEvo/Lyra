// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_select.dart';

Widget _buildSelectTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  final isDark = themeMode == ThemeMode.dark;
  final tokens = isDark ? LyraThemeTokens.dark() : LyraThemeTokens.light();
  final shadTheme = ShadThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: isDark
        ? const ShadZincColorScheme.dark()
        : const ShadZincColorScheme.light(),
  );

  return ShadApp(
    title: 'LyraSelect Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: const ShadcnFactory(),
        tokens: tokens,
        themeModeNotifier: ValueNotifier(themeMode),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyraSelect Component Tests', () {
    testWidgets('Renders trigger with placeholder when value is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSelectTestApp(
          child: const LyraSelect<String>(
            placeholder: 'Choose item...',
            items: [
              LyraSelectItem(value: 'a', label: 'Option A'),
              LyraSelectItem(value: 'b', label: 'Option B'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose item...'), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronDown), findsOneWidget);
    });

    testWidgets('Renders selected item label and opens overlay on click', (
      tester,
    ) async {
      String? selectedValue = 'b';

      await tester.pumpWidget(
        _buildSelectTestApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              return LyraSelect<String>(
                key: const Key('test_select'),
                value: selectedValue,
                items: const [
                  LyraSelectItem(value: 'a', label: 'Option A'),
                  LyraSelectItem(value: 'b', label: 'Option B'),
                  LyraSelectItem(value: 'c', label: 'Option C'),
                ],
                onChanged: (val) => setState(() => selectedValue = val),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Option B'), findsOneWidget);

      // Open dropdown
      await tester.tap(find.byKey(const Key('test_select')));
      await tester.pumpAndSettle();

      // All options are now visible in the overlay
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsWidgets); // trigger + overlay
      expect(find.text('Option C'), findsOneWidget);

      // Select Option C
      await tester.tap(find.text('Option C'));
      await tester.pumpAndSettle();

      expect(selectedValue, equals('c'));
      expect(find.text('Option C'), findsOneWidget);
      // Overlay is closed, Option A is no longer visible
      expect(find.text('Option A'), findsNothing);
    });

    testWidgets('Closes overlay on click outside', (tester) async {
      await tester.pumpWidget(
        _buildSelectTestApp(
          child: Stack(
            children: const [
              Positioned(
                top: 50,
                left: 50,
                child: LyraSelect<String>(
                  key: Key('test_select'),
                  value: 'a',
                  items: [
                    LyraSelectItem(value: 'a', label: 'Alpha'),
                    LyraSelectItem(value: 'b', label: 'Beta'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open select
      await tester.tap(find.byKey(const Key('test_select')));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);

      // Tap outside overlay (at bottom-right corner)
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('Closes overlay when Escape key is pressed', (tester) async {
      await tester.pumpWidget(
        _buildSelectTestApp(
          child: const LyraSelect<String>(
            key: Key('test_select'),
            value: 'a',
            items: [
              LyraSelectItem(value: 'a', label: 'Alpha'),
              LyraSelectItem(value: 'b', label: 'Beta'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open select
      await tester.tap(find.byKey(const Key('test_select')));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);

      // Send Escape key event
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('Disabled state does not open overlay on tap', (tester) async {
      await tester.pumpWidget(
        _buildSelectTestApp(
          child: const LyraSelect<String>(
            key: Key('test_select'),
            enabled: false,
            value: 'a',
            items: [
              LyraSelectItem(value: 'a', label: 'Alpha'),
              LyraSelectItem(value: 'b', label: 'Beta'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap disabled select
      await tester.tap(find.byKey(const Key('test_select')));
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('Custom triggerBuilder renders custom trigger widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSelectTestApp(
          child: LyraSelect<String>(
            key: const Key('custom_select'),
            value: 'custom_val',
            items: const [
              LyraSelectItem(value: 'custom_val', label: 'Custom Label'),
              LyraSelectItem(value: 'other_val', label: 'Other Label'),
            ],
            triggerBuilder: (context, selectedItem) {
              return Container(
                key: const Key('custom_trigger_box'),
                child: Text('TRIGGER: ${selectedItem?.label}'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom_trigger_box')), findsOneWidget);
      expect(find.text('TRIGGER: Custom Label'), findsOneWidget);

      // Tap custom trigger
      await tester.tap(find.byKey(const Key('custom_trigger_box')));
      await tester.pumpAndSettle();

      expect(find.text('Other Label'), findsOneWidget);
    });

    testWidgets(
      'Keyboard navigation: Tab focus, Enter to open, ArrowDown to navigate, Enter to select',
      (tester) async {
        String? selectedValue;
        await tester.pumpWidget(
          _buildSelectTestApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                return LyraSelect<String>(
                  key: const Key('kb_select'),
                  value: selectedValue,
                  placeholder: 'Select fruit...',
                  items: const [
                    LyraSelectItem(value: 'apple', label: 'Apple'),
                    LyraSelectItem(value: 'banana', label: 'Banana'),
                    LyraSelectItem(value: 'cherry', label: 'Cherry'),
                  ],
                  onChanged: (val) => setState(() => selectedValue = val),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Tab into the select trigger
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        // 2. Press Enter to open
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('Cherry'), findsOneWidget);

        // 3. Arrow down to navigate to second item ('Banana')
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // 4. Press Enter to select
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(selectedValue, equals('banana'));
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('Cherry'), findsNothing); // overlay closed
      },
    );

    testWidgets(
      'Width constraint safety: renders inside unconstrained horizontal flex without exception',
      (tester) async {
        await tester.pumpWidget(
          _buildSelectTestApp(
            child: Row(
              children: const [
                LyraSelect<String>(
                  key: Key('unconstrained_select'),
                  items: [LyraSelectItem(value: '1', label: 'Item 1')],
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('unconstrained_select')), findsOneWidget);
      },
    );

    testWidgets('Dynamically setting enabled to false closes open overlay', (
      tester,
    ) async {
      bool isEnabled = true;
      await tester.pumpWidget(
        _buildSelectTestApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    key: const Key('toggle_btn'),
                    onPressed: () => setState(() => isEnabled = false),
                    child: const Text('Disable'),
                  ),
                  const SizedBox(height: 100),
                  LyraSelect<String>(
                    key: const Key('dynamic_select'),
                    enabled: isEnabled,
                    value: '1',
                    items: const [
                      LyraSelectItem(value: '1', label: 'Option 1'),
                      LyraSelectItem(value: '2', label: 'Option 2'),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open select
      await tester.tap(find.byKey(const Key('dynamic_select')));
      await tester.pumpAndSettle();
      expect(find.text('Option 2'), findsOneWidget);

      // Disable select
      await tester.tap(find.byKey(const Key('toggle_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Option 2'), findsNothing); // overlay closed
    });
  });
}
