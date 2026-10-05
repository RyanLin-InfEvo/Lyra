// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/contracts/lyra_contracts.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';

Widget _buildTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.dark,
  BorderRadius? customRadius,
}) {
  final tokens = themeMode == ThemeMode.light
      ? LyraThemeTokens.light()
      : LyraThemeTokens.dark();
  final shadTheme = ShadThemeData(
    brightness: themeMode == ThemeMode.light
        ? Brightness.light
        : Brightness.dark,
    colorScheme: themeMode == ThemeMode.light
        ? const ShadZincColorScheme.light()
        : const ShadZincColorScheme.dark(),
    radius: customRadius,
  );

  return ShadApp(
    title: 'Button Shift Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: const ShadcnFactory(),
        tokens: tokens,
        themeModeNotifier: ValueNotifier(themeMode),
        child: Scaffold(body: child),
      ),
    ),
  );
}

class ToggleOptionPill extends StatefulWidget {
  final String label;
  final LyraButtonVariant activeVariant;

  const ToggleOptionPill({
    super.key,
    required this.label,
    this.activeVariant = LyraButtonVariant.secondary,
  });

  @override
  State<ToggleOptionPill> createState() => _ToggleOptionPillState();
}

class _ToggleOptionPillState extends State<ToggleOptionPill> {
  bool isSelected = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: LyraButton(
        height: 32.0,
        size: LyraButtonSize.sm,
        variant: isSelected ? widget.activeVariant : LyraButtonVariant.outline,
        onPressed: () {
          setState(() {
            isSelected = !isSelected;
          });
        },
        child: Text(widget.label),
      ),
    );
  }
}

class MultiOptionPillsRow extends StatefulWidget {
  final List<String> options;

  const MultiOptionPillsRow({super.key, required this.options});

  @override
  State<MultiOptionPillsRow> createState() => _MultiOptionPillsRowState();
}

class _MultiOptionPillsRowState extends State<MultiOptionPillsRow> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: LyraSpacing.xs,
        runSpacing: LyraSpacing.xs,
        children: widget.options.asMap().entries.map((entry) {
          final isSelected = selectedIndex == entry.key;
          return LyraButton(
            height: 32.0,
            size: LyraButtonSize.sm,
            variant: isSelected
                ? LyraButtonVariant.secondary
                : LyraButtonVariant.outline,
            onPressed: () {
              setState(() {
                selectedIndex = entry.key;
              });
            },
            child: Text(entry.value),
          );
        }).toList(),
      ),
    );
  }
}

void main() {
  group('LyraButton Selection Toggle Layout Stability', () {
    testWidgets(
      'Text inside button does NOT shift position when toggling between outline and secondary',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: const ToggleOptionPill(label: '512 MB')),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byType(LyraButton);
        final textFinder = find.text('512 MB');

        expect(buttonFinder, findsOneWidget);
        expect(textFinder, findsOneWidget);

        final initialButtonSize = tester.getSize(buttonFinder);
        final initialTextTopLeft = tester.getTopLeft(textFinder);
        final initialTextCenter = tester.getCenter(textFinder);

        // Verify outline button has the correct border properties
        final containerFinder = find.descendant(
          of: buttonFinder,
          matching: find.byType(Container),
        );
        final container = tester.widget<Container>(containerFinder.first);
        final boxDecoration = container.decoration as BoxDecoration?;
        expect(boxDecoration?.border, isNotNull);
        final border = boxDecoration!.border!;
        expect(border.top.width, equals(1.0));
        expect(border.top.strokeAlign, equals(BorderSide.strokeAlignInside));
        expect(
          border.top.color,
          equals(const ShadZincColorScheme.dark().input),
        );

        // Tap to toggle to secondary (selected)
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        final selectedButtonSize = tester.getSize(buttonFinder);
        final selectedTextTopLeft = tester.getTopLeft(textFinder);
        final selectedTextCenter = tester.getCenter(textFinder);

        // Tap again to toggle back to outline (unselected)
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        final unselectedButtonSize = tester.getSize(buttonFinder);
        final unselectedTextTopLeft = tester.getTopLeft(textFinder);
        final unselectedTextCenter = tester.getCenter(textFinder);

        // Assert zero layout shift on inner text and button dimensions
        expect(
          selectedButtonSize,
          equals(initialButtonSize),
          reason:
              'Button outer dimensions must remain identical between outline and secondary',
        );
        expect(
          selectedTextTopLeft.dx,
          equals(initialTextTopLeft.dx),
          reason: 'Text X coordinate shifted upon selection change',
        );
        expect(
          selectedTextTopLeft.dy,
          equals(initialTextTopLeft.dy),
          reason: 'Text Y coordinate shifted upon selection change',
        );
        expect(
          selectedTextCenter,
          equals(initialTextCenter),
          reason: 'Text Center shifted upon selection change',
        );

        expect(unselectedButtonSize, equals(initialButtonSize));
        expect(unselectedTextTopLeft, equals(initialTextTopLeft));
        expect(unselectedTextCenter, equals(initialTextCenter));
      },
    );

    testWidgets(
      'Text inside button does NOT shift position when toggling between outline and primary',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: const ToggleOptionPill(
              label: 'FLAC',
              activeVariant: LyraButtonVariant.primary,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byType(LyraButton);
        final textFinder = find.text('FLAC');

        final initialButtonSize = tester.getSize(buttonFinder);
        final initialTextTopLeft = tester.getTopLeft(textFinder);
        final initialTextCenter = tester.getCenter(textFinder);

        // Tap to toggle to primary (selected)
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        final selectedButtonSize = tester.getSize(buttonFinder);
        final selectedTextTopLeft = tester.getTopLeft(textFinder);
        final selectedTextCenter = tester.getCenter(textFinder);

        // Assert zero layout shift on inner text and button dimensions
        expect(selectedButtonSize, equals(initialButtonSize));
        expect(selectedTextTopLeft.dx, equals(initialTextTopLeft.dx));
        expect(selectedTextTopLeft.dy, equals(initialTextTopLeft.dy));
        expect(selectedTextCenter, equals(initialTextCenter));
      },
    );

    testWidgets(
      'Multiple option pills in a Wrap maintain stable positions and zero shift when switching selection',
      (tester) async {
        final options = ['Off', '256 MB', '512 MB', '1 GB'];
        await tester.pumpWidget(
          _buildTestApp(child: MultiOptionPillsRow(options: options)),
        );
        await tester.pumpAndSettle();

        // Record positions when 'Off' is selected (index 0)
        final posOff0 = tester.getTopLeft(find.text('Off'));
        final pos256MB0 = tester.getTopLeft(find.text('256 MB'));
        final pos512MB0 = tester.getTopLeft(find.text('512 MB'));
        final pos1GB0 = tester.getTopLeft(find.text('1 GB'));

        // Tap '512 MB' (index 2) to select it
        await tester.tap(find.text('512 MB'));
        await tester.pumpAndSettle();

        // Record positions when '512 MB' is selected (index 2)
        final posOff1 = tester.getTopLeft(find.text('Off'));
        final pos256MB1 = tester.getTopLeft(find.text('256 MB'));
        final pos512MB1 = tester.getTopLeft(find.text('512 MB'));
        final pos1GB1 = tester.getTopLeft(find.text('1 GB'));

        // Assert ALL button positions remain completely rock-solid
        expect(posOff1, equals(posOff0));
        expect(pos256MB1, equals(pos256MB0));
        expect(pos512MB1, equals(pos512MB0));
        expect(pos1GB1, equals(pos1GB0));
      },
    );

    testWidgets(
      'Outline button MUST have strokeAlignInside to prevent clipping and bleeding',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: const LyraButton(
              height: 32.0,
              size: LyraButtonSize.sm,
              variant: LyraButtonVariant.outline,
              child: Text('Test'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final containerFinder = find.descendant(
          of: find.byType(LyraButton),
          matching: find.byType(Container),
        );
        final container = tester.widget<Container>(containerFinder.first);
        final boxDecoration = container.decoration as BoxDecoration?;
        expect(boxDecoration?.border, isNotNull);
        final border = boxDecoration!.border!;

        // The border must be strokeAlignInside so that it is drawn entirely within
        // the button boundaries and is not clipped by parent ClipRects or bleed into spacing.
        expect(
          border.top.strokeAlign,
          equals(BorderSide.strokeAlignInside),
          reason:
              'Border must be strokeAlignInside to prevent clipping in ClipRect and spacing bleeding',
        );
      },
    );

    testWidgets(
      'Outline button dynamically adapts border color in Light mode vs Dark mode',
      (tester) async {
        // Light mode
        await tester.pumpWidget(
          _buildTestApp(
            themeMode: ThemeMode.light,
            child: const LyraButton(
              height: 32.0,
              size: LyraButtonSize.sm,
              variant: LyraButtonVariant.outline,
              child: Text('Light'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        var container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(LyraButton),
                matching: find.byType(Container),
              )
              .first,
        );
        var border = (container.decoration as BoxDecoration).border!;
        expect(
          border.top.color,
          equals(const ShadZincColorScheme.light().input),
          reason: 'Outline button border must adapt to light theme input color',
        );

        // Dark mode
        await tester.pumpWidget(
          _buildTestApp(
            themeMode: ThemeMode.dark,
            child: const LyraButton(
              height: 32.0,
              size: LyraButtonSize.sm,
              variant: LyraButtonVariant.outline,
              child: Text('Dark'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(LyraButton),
                matching: find.byType(Container),
              )
              .first,
        );
        border = (container.decoration as BoxDecoration).border!;
        expect(
          border.top.color,
          equals(const ShadZincColorScheme.dark().input),
          reason: 'Outline button border must adapt to dark theme input color',
        );
      },
    );

    testWidgets(
      'Outline button dynamically respects custom theme radius without losing it',
      (tester) async {
        const customRadius = BorderRadius.all(Radius.circular(14.0));
        await tester.pumpWidget(
          _buildTestApp(
            customRadius: customRadius,
            child: const LyraButton(
              height: 32.0,
              size: LyraButtonSize.sm,
              variant: LyraButtonVariant.outline,
              child: Text('Radius'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(LyraButton),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(customRadius),
          reason: 'Outline button must respect custom theme radius',
        );
      },
    );

    testWidgets(
      'Hovered and disabled outline buttons maintain identical dimensions and zero shift',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: const LyraButton(
              height: 32.0,
              size: LyraButtonSize.sm,
              variant: LyraButtonVariant.outline,
              child: Text('Stable'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byType(LyraButton);
        final initialSize = tester.getSize(buttonFinder);
        final initialPos = tester.getTopLeft(find.text('Stable'));

        // Hover test
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(buttonFinder));
        await tester.pumpAndSettle();

        expect(tester.getSize(buttonFinder), equals(initialSize));
        expect(tester.getTopLeft(find.text('Stable')), equals(initialPos));

        await gesture.removePointer();

        // Disabled test
        await tester.pumpWidget(
          _buildTestApp(
            child: const LyraButton(
              height: 32.0,
              size: LyraButtonSize.sm,
              variant: LyraButtonVariant.outline,
              onPressed: null,
              child: Text('Stable'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.getSize(buttonFinder), equals(initialSize));
        expect(tester.getTopLeft(find.text('Stable')), equals(initialPos));
      },
    );

    testWidgets(
      'Seam integrity: all variants (primary, secondary, outline, ghost, destructive) maintain exact height stability',
      (tester) async {
        final variants = [
          LyraButtonVariant.primary,
          LyraButtonVariant.secondary,
          LyraButtonVariant.outline,
          LyraButtonVariant.ghost,
          LyraButtonVariant.destructive,
        ];

        for (final variant in variants) {
          await tester.pumpWidget(
            _buildTestApp(
              child: Align(
                alignment: Alignment.topLeft,
                child: LyraButton(
                  height: 32.0,
                  size: LyraButtonSize.sm,
                  variant: variant,
                  child: const Text('VariantTest'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final buttonSize = tester.getSize(find.byType(LyraButton));
          expect(
            buttonSize.height,
            equals(32.0),
            reason: 'Variant $variant must have exact height 32.0',
          );
        }
      },
    );
  });
}
