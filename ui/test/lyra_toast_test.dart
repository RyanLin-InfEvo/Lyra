// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_toast.dart';
import 'package:ui/features/settings/services/preferences_service.dart';

Widget _buildToastTestApp({
  required LyraToastController controller,
  Widget? child,
}) {
  final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();
  final tokens = deriveLyraThemeTokens('zinc', true);

  return ShadApp(
    debugShowCheckedModeBanner: false,
    home: LyraDesignSystemScope(
      factory: factory,
      tokens: tokens,
      themeModeNotifier: themeNotifier,
      child: LyraToastScope(
        controller: controller,
        child: Scaffold(
          body: SizedBox.expand(
            child: Stack(
              children: [
                child ?? const SizedBox.expand(),
                const Positioned(
                  left: 20.0,
                  bottom: 24.0,
                  child: LyraToastStack(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('LyraToastController Unit Tests', () {
    test('show adds toast to list and dismiss removes it', () {
      final controller = LyraToastController();
      expect(controller.toasts, isEmpty);

      controller.show(
        LyraToast(
          id: 'toast-1',
          title: 'Notification 1',
          autoDismiss: false, // manual dismiss
        ),
      );

      expect(controller.toasts.length, 1);
      expect(controller.toasts.first.id, 'toast-1');

      controller.dismiss('toast-1', immediate: true);
      expect(controller.toasts, isEmpty);
      controller.dispose();
    });

    test('dismissAll clears all active toasts and resets expanded state', () {
      final controller = LyraToastController();
      controller.show(
        LyraToast(id: 't1', title: '1', duration: null),
      );
      controller.show(
        LyraToast(id: 't2', title: '2', duration: null),
      );
      controller.setExpanded(true);

      expect(controller.toasts.length, 2);
      expect(controller.isExpanded, isTrue);

      controller.dismissAll(immediate: true);
      expect(controller.toasts, isEmpty);
      expect(controller.isExpanded, isFalse);
      controller.dispose();
    });

    test('auto-dismiss timer removes toast after specified duration', () async {
      final controller = LyraToastController();
      controller.show(
        LyraToast(
          id: 'auto-1',
          title: 'Auto dismiss',
          duration: const Duration(milliseconds: 50),
        ),
      );

      expect(controller.toasts.length, 1);
      // Wait for auto-dismiss timer (50ms) + exit animation timer (200ms)
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(controller.toasts, isEmpty);
      controller.dispose();
    });

    test('pauseTimers and resumeTimers suspend and restart countdown', () async {
      final controller = LyraToastController();
      controller.show(
        LyraToast(
          id: 'pause-1',
          title: 'Pause test',
          duration: const Duration(milliseconds: 100),
        ),
      );

      controller.pauseTimers();
      expect(controller.isPaused, isTrue);

      // Wait longer than initial duration while paused; should not be dismissed
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.toasts.length, 1);

      controller.resumeTimers();
      expect(controller.isPaused, isFalse);

      // Wait for resumed timer (100ms) + exit animation (200ms)
      await Future<void>.delayed(const Duration(milliseconds: 380));
      expect(controller.toasts, isEmpty);
      controller.dispose();
    });

    test('respects toastAutoDismiss = false in PreferencesService', () async {
      final prefs = InMemoryPreferencesService(toastAutoDismiss: false);
      final controller = LyraToastController(preferencesService: prefs);

      controller.show(
        LyraToast(
          id: 'no-expire',
          title: 'No expire notification',
          duration: const Duration(milliseconds: 50),
        ),
      );

      expect(controller.toasts.length, 1);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      // Should not have expired because auto-dismiss is disabled
      expect(controller.toasts.length, 1);

      controller.dispose();
    });

    test(
      'respects toastShowProgressBar in PreferencesService and setter',
      () async {
        final prefs = InMemoryPreferencesService(toastShowProgressBar: false);
        final controller = LyraToastController(preferencesService: prefs);

        expect(controller.showProgressBar, isFalse);
        await prefs.setToastShowProgressBar(true);
        expect(controller.showProgressBar, isTrue);

        controller.setShowProgressBar(false);
        expect(controller.showProgressBar, isFalse);

        controller.dispose();
      },
    );

    test('dismissing toasts in expanded mode resets isExpanded when length <= 1', () {
      final controller = LyraToastController();
      controller.show(LyraToast(id: 't1', title: '1'));
      controller.show(LyraToast(id: 't2', title: '2'));
      controller.toggleExpanded();
      expect(controller.isExpanded, isTrue);

      controller.dismiss('t2', immediate: true);
      expect(controller.toasts.length, 1);
      expect(controller.isExpanded, isFalse);

      controller.dispose();
    });
  });

  group('LyraToastStack Widget Tests', () {
    testWidgets(
      'renders single toast with title, tag, and individual dismiss button',
      (tester) async {
        final controller = LyraToastController();
        await tester.pumpWidget(_buildToastTestApp(controller: controller));

        expect(find.byType(LyraToastCard), findsNothing);

        controller.show(
          LyraToast(
            id: 't-success',
            title: 'Audio Export Completed',
            tag: 'FLAC 24/96',
            variant: LyraToastVariant.success,
            autoDismiss: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LyraToastCard), findsOneWidget);
        expect(find.text('Audio Export Completed'), findsOneWidget);
        expect(find.text('FLAC 24/96'), findsOneWidget);
        expect(find.byIcon(LucideIcons.check), findsOneWidget);

        // Single toast does not show "Show more" header
        expect(find.byKey(const Key('toast_stack_toggle_button')), findsNothing);

        // Dismiss individual toast
        final dismissBtn =
            find.byKey(const Key('toast_dismiss_t-success')).first;
        expect(dismissBtn, findsOneWidget);
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();

        expect(find.byType(LyraToastCard), findsNothing);
        controller.dispose();
      },
    );

    testWidgets(
      'renders TradingView stacked deck when multiple toasts exist',
      (tester) async {
        final controller = LyraToastController();
        await tester.pumpWidget(_buildToastTestApp(controller: controller));

        controller.show(
          LyraToast(
            id: 't1',
            title: 'First Notification',
            autoDismiss: false,
          ),
        );
        controller.show(
          LyraToast(
            id: 't2',
            title: 'Second Notification',
            tag: 'BTC/USD',
            autoDismiss: false,
          ),
        );
        await tester.pumpAndSettle();

        // Top notification is visible
        expect(find.text('Second Notification'), findsOneWidget);
        expect(find.text('BTC/USD'), findsOneWidget);

        // Header row with "Show more 2" and dismiss all 'X' button
        expect(
          find.byKey(const Key('toast_stack_toggle_button')),
          findsOneWidget,
        );
        expect(find.text('Show more'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(
          find.byKey(const Key('toast_stack_dismiss_all_button')).first,
          findsOneWidget,
        );

        // Tap "Show more 2" to expand stack
        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();

        expect(find.text('Show less'), findsOneWidget);
        expect(find.text('First Notification'), findsOneWidget);
        expect(find.text('Second Notification'), findsOneWidget);

        // Tap "Show less 2" to collapse back
        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();
        expect(find.text('Show more'), findsOneWidget);

        // Tap Dismiss All button
        await tester.tap(
          find.byKey(const Key('toast_stack_dismiss_all_button')).first,
        );
        await tester.pumpAndSettle();

        expect(find.byType(LyraToastCard), findsNothing);
        controller.dispose();
      },
    );

    testWidgets('supports horizontal swipe to dismiss card', (tester) async {
      final controller = LyraToastController();
      await tester.pumpWidget(_buildToastTestApp(controller: controller));

      controller.show(
        LyraToast(
          id: 'swipe-card',
          title: 'Swipeable Alert',
          autoDismiss: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Swipeable Alert'), findsOneWidget);

      // Swipe horizontally to dismiss
      await tester.drag(
        find.byKey(const Key('toast_card_swipe-card')),
        const Offset(500.0, 0.0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Swipeable Alert'), findsNothing);
      controller.dispose();
    });
  });
}
