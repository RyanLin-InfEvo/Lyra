// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ui/design_system/widgets/lyra_spinner.dart';

Widget _buildTestApp({required Widget child}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyraSpinner', () {
    testWidgets(
      'renders RotationTransition with LucideIcons.loader2 and default properties',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(child: LyraSpinner()));
        await tester.pump();

        expect(find.byType(LyraSpinner), findsOneWidget);
        final rotationFinder = find.descendant(
          of: find.byType(LyraSpinner),
          matching: find.byType(RotationTransition),
        );
        expect(rotationFinder, findsOneWidget);
        expect(find.byIcon(LucideIcons.loader2), findsOneWidget);

        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.loader2));
        expect(icon.size, equals(16.0));
        expect(icon.color, isNull);

        final size = tester.getSize(find.byType(LyraSpinner));
        expect(size, equals(const Size(16.0, 16.0)));
      },
    );

    testWidgets('respects custom size and color', (tester) async {
      const customColor = Color(0xFF10B981);
      await tester.pumpWidget(
        _buildTestApp(child: LyraSpinner(size: 24.0, color: customColor)),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.loader2));
      expect(icon.size, equals(24.0));
      expect(icon.color, equals(customColor));

      final size = tester.getSize(find.byType(LyraSpinner));
      expect(size, equals(const Size(24.0, 24.0)));
    });

    testWidgets('rotates continuously over time matching duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: LyraSpinner(duration: const Duration(milliseconds: 1000)),
        ),
      );
      await tester.pump();

      final rotationFinder = find.descendant(
        of: find.byType(LyraSpinner),
        matching: find.byType(RotationTransition),
      );
      RotationTransition transition = tester.widget<RotationTransition>(
        rotationFinder,
      );
      expect(transition.turns.value, closeTo(0.0, 0.01));

      // After 250ms, quarter turn (0.25)
      await tester.pump(const Duration(milliseconds: 250));
      transition = tester.widget<RotationTransition>(rotationFinder);
      expect(transition.turns.value, closeTo(0.25, 0.02));

      // After 500ms, half turn (0.50)
      await tester.pump(const Duration(milliseconds: 250));
      transition = tester.widget<RotationTransition>(rotationFinder);
      expect(transition.turns.value, closeTo(0.50, 0.02));

      // After 750ms, three-quarters turn (0.75)
      await tester.pump(const Duration(milliseconds: 250));
      transition = tester.widget<RotationTransition>(rotationFinder);
      expect(transition.turns.value, closeTo(0.75, 0.02));

      // After 1000ms, full rotation loops back around
      await tester.pump(const Duration(milliseconds: 250));
      transition = tester.widget<RotationTransition>(rotationFinder);
      expect(transition.turns.value, closeTo(0.0, 0.02));
    });

    testWidgets(
      'cleanly disposes AnimationController when unmounted without errors or ticker leaks',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(child: LyraSpinner()));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(LyraSpinner), findsOneWidget);

        // Unmount the spinner
        await tester.pumpWidget(_buildTestApp(child: const SizedBox.shrink()));
        await tester.pump();

        expect(find.byType(LyraSpinner), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('adapts to duration changes via didUpdateWidget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: LyraSpinner(duration: const Duration(milliseconds: 2000)),
        ),
      );
      await tester.pump();

      // Update to 500ms duration
      await tester.pumpWidget(
        _buildTestApp(
          child: LyraSpinner(duration: const Duration(milliseconds: 500)),
        ),
      );
      await tester.pump();

      final rotationFinder = find.descendant(
        of: find.byType(LyraSpinner),
        matching: find.byType(RotationTransition),
      );
      // Advance by 250ms (half of 500ms)
      await tester.pump(const Duration(milliseconds: 250));
      final transition = tester.widget<RotationTransition>(rotationFinder);
      expect(transition.turns.value, closeTo(0.5, 0.05));
    });

    test('throws assertion error if duration is zero or negative', () {
      expect(() => LyraSpinner(duration: Duration.zero), throwsAssertionError);
      expect(
        () => LyraSpinner(duration: const Duration(milliseconds: -100)),
        throwsAssertionError,
      );
    });

    testWidgets('provides default semantics label for accessibility', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(child: LyraSpinner()));
      await tester.pump();

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('respects custom semantics label', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(child: LyraSpinner(semanticsLabel: 'Syncing')),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Syncing'), findsOneWidget);
    });

    testWidgets(
      'wraps RotationTransition in RepaintBoundary to isolate 60/120Hz repaint ticks from parent subtree',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(child: LyraSpinner()));
        await tester.pump();

        final repaintBoundaryFinder = find.descendant(
          of: find.byType(LyraSpinner),
          matching: find.byType(RepaintBoundary),
        );
        expect(repaintBoundaryFinder, findsOneWidget);

        final rotationFinder = find.descendant(
          of: repaintBoundaryFinder,
          matching: find.byType(RotationTransition),
        );
        expect(rotationFinder, findsOneWidget);
      },
    );
  });
}
