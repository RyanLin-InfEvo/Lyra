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
  bool isDark = true,
  Widget? child,
}) {
  final themeNotifier = ValueNotifier<ThemeMode>(
    isDark ? ThemeMode.dark : ThemeMode.light,
  );
  const factory = ShadcnFactory();
  final tokens = deriveLyraThemeTokens('zinc', isDark);

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
      controller.show(LyraToast(id: 't1', title: '1', duration: null));
      controller.show(LyraToast(id: 't2', title: '2', duration: null));
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

    test(
      'dismissing toasts in expanded mode resets isExpanded when length <= 1',
      () {
        final controller = LyraToastController();
        controller.show(LyraToast(id: 't1', title: '1'));
        controller.show(LyraToast(id: 't2', title: '2'));
        controller.toggleExpanded();
        expect(controller.isExpanded, isTrue);

        controller.dismiss('t2', immediate: true);
        expect(controller.toasts.length, 1);
        expect(controller.isExpanded, isFalse);

        controller.dispose();
      },
    );

    test(
      'buildScrollFadeGradient handles all (fadeTop, fadeBottom) combinations',
      () {
        // (false, false): solid pass-through
        final none = LyraToastStack.buildScrollFadeGradient(
          fadeTop: false,
          fadeBottom: false,
          height: 200.0,
        );
        expect(none.colors, [Colors.white, Colors.white]);
        expect(none.stops, [0.0, 1.0]);

        // (true, false): top fade only (16 / 200 = 0.08)
        final topOnly = LyraToastStack.buildScrollFadeGradient(
          fadeTop: true,
          fadeBottom: false,
          height: 200.0,
        );
        expect(topOnly.colors, [
          Colors.transparent,
          Colors.white,
          Colors.white,
        ]);
        expect(topOnly.stops.length, 3);
        expect(topOnly.stops[0], 0.0);
        expect(topOnly.stops[1], closeTo(0.08, 1e-6));
        expect(topOnly.stops[2], 1.0);

        // (true, true): both top and bottom fade
        final both = LyraToastStack.buildScrollFadeGradient(
          fadeTop: true,
          fadeBottom: true,
          height: 200.0,
        );
        expect(both.colors, [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ]);
        expect(both.stops.length, 4);
        expect(both.stops[0], 0.0);
        expect(both.stops[1], closeTo(0.08, 1e-6));
        expect(both.stops[2], closeTo(0.92, 1e-6));
        expect(both.stops[3], 1.0);

        // (false, true): bottom fade only
        final bottomOnly = LyraToastStack.buildScrollFadeGradient(
          fadeTop: false,
          fadeBottom: true,
          height: 200.0,
        );
        expect(bottomOnly.colors, [
          Colors.white,
          Colors.white,
          Colors.transparent,
        ]);
        expect(bottomOnly.stops.length, 3);
        expect(bottomOnly.stops[0], 0.0);
        expect(bottomOnly.stops[1], closeTo(0.92, 1e-6));
        expect(bottomOnly.stops[2], 1.0);

        // Clamping when height is very small or zero
        final tiny = LyraToastStack.buildScrollFadeGradient(
          fadeTop: true,
          fadeBottom: true,
          height: 10.0,
        );
        expect(tiny.stops, [0.0, 0.45, 0.55, 1.0]);

        final zero = LyraToastStack.buildScrollFadeGradient(
          fadeTop: true,
          fadeBottom: true,
          height: 0.0,
        );
        expect(zero.stops, [0.0, 0.0, 1.0, 1.0]);
      },
    );
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
        expect(
          find.byKey(const Key('toast_stack_toggle_button')),
          findsNothing,
        );

        // Dismiss individual toast
        final dismissBtn = find
            .byKey(const Key('toast_dismiss_t-success'))
            .first;
        expect(dismissBtn, findsOneWidget);
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();

        expect(find.byType(LyraToastCard), findsNothing);
        controller.dispose();
      },
    );

    testWidgets('renders TradingView stacked deck when multiple toasts exist', (
      tester,
    ) async {
      final controller = LyraToastController();
      await tester.pumpWidget(_buildToastTestApp(controller: controller));

      controller.show(
        LyraToast(id: 't1', title: 'First Notification', autoDismiss: false),
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
    });

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

    testWidgets(
      'light and dark mode apply theme-aware shadows to toast cards and deck layers',
      (tester) async {
        List<BoxShadow> cardShadows(String id) {
          final container = tester.widget<Container>(
            find.byKey(Key('toast_card_$id')),
          );
          final decoration = container.decoration as BoxDecoration;
          return decoration.boxShadow ?? const [];
        }

        List<BoxDecoration> dummyDeckDecorations() {
          final containers = tester.widgetList<Container>(
            find.descendant(
              of: find.byType(LyraToastStack),
              matching: find.byType(Container),
            ),
          );
          return containers
              .where((c) => c.key == null && c.decoration is BoxDecoration)
              .map((c) => c.decoration as BoxDecoration)
              .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty)
              .toList();
        }

        // Light mode
        final lightController = LyraToastController();
        await tester.pumpWidget(
          _buildToastTestApp(controller: lightController, isDark: false),
        );
        for (var i = 1; i <= 3; i++) {
          lightController.show(
            LyraToast(id: 'light-$i', title: 'Light $i', autoDismiss: false),
          );
        }
        await tester.pumpAndSettle();

        final lightCardShadows = cardShadows('light-3');
        expect(lightCardShadows, isNotEmpty);
        for (final shadow in lightCardShadows) {
          expect(shadow.color.a, lessThanOrEqualTo(0.12));
        }

        final lightDeckDecorations = dummyDeckDecorations();
        expect(lightDeckDecorations.length, 2);
        for (final dec in lightDeckDecorations) {
          expect(dec.color!.a, greaterThanOrEqualTo(0.90));
          for (final shadow in dec.boxShadow!) {
            expect(shadow.color.a, lessThanOrEqualTo(0.12));
          }
        }

        // Expand in light mode
        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();
        for (var i = 1; i <= 3; i++) {
          final shadows = cardShadows('light-$i');
          expect(shadows, isNotEmpty);
          for (final shadow in shadows) {
            expect(shadow.color.a, lessThanOrEqualTo(0.12));
          }
        }
        lightController.dispose();

        // Dark mode
        final darkController = LyraToastController();
        await tester.pumpWidget(
          _buildToastTestApp(controller: darkController, isDark: true),
        );
        for (var i = 1; i <= 3; i++) {
          darkController.show(
            LyraToast(id: 'dark-$i', title: 'Dark $i', autoDismiss: false),
          );
        }
        await tester.pumpAndSettle();

        final darkCardShadows = cardShadows('dark-3');
        expect(darkCardShadows, isNotEmpty);
        expect(darkCardShadows.first.color.a, greaterThanOrEqualTo(0.20));

        final darkDeckDecorations = dummyDeckDecorations();
        expect(darkDeckDecorations.length, 2);
        for (final dec in darkDeckDecorations) {
          expect(dec.boxShadow!.first.color.a, greaterThanOrEqualTo(0.20));
        }

        // Expand in dark mode
        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();
        for (var i = 1; i <= 3; i++) {
          final shadows = cardShadows('dark-$i');
          expect(shadows, isNotEmpty);
          expect(shadows.first.color.a, greaterThanOrEqualTo(0.20));
        }
        darkController.dispose();
      },
    );

    testWidgets(
      'expanded list and collapsed deck reserve shadow gutters and inter-card spacing',
      (tester) async {
        final controller = LyraToastController();
        await tester.pumpWidget(
          _buildToastTestApp(controller: controller, isDark: false),
        );
        for (var i = 1; i <= 3; i++) {
          controller.show(
            LyraToast(id: 'g-$i', title: 'Toast $i', autoDismiss: false),
          );
        }
        await tester.pumpAndSettle();

        // AnimatedSize must clip during transitions so expanding content cannot
        // paint over the header bar while steady-state shadows remain inside padding.
        final animatedSize = tester.widget<AnimatedSize>(
          find.descendant(
            of: find.byType(LyraToastStack),
            matching: find.byType(AnimatedSize),
          ),
        );
        expect(animatedSize.clipBehavior, Clip.hardEdge);

        // Collapsed deck enclosing Padding reserves horizontal & bottom shadow/deck room
        final collapsedPadding = tester.widget<Padding>(
          find
              .descendant(
                of: find.byType(AnimatedSize),
                matching: find.byType(Padding),
              )
              .first,
        );
        final collapsedInsets = collapsedPadding.padding.resolve(
          TextDirection.ltr,
        );
        expect(collapsedInsets.left, greaterThanOrEqualTo(16.0));
        expect(collapsedInsets.right, greaterThanOrEqualTo(16.0));
        expect(collapsedInsets.top, greaterThanOrEqualTo(14.0));
        expect(collapsedInsets.bottom, 20.0);

        // Expand stack
        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();

        final scrollView = tester.widget<SingleChildScrollView>(
          find.descendant(
            of: find.byType(LyraToastStack),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        expect(scrollView.padding, isNotNull);
        final scrollInsets = scrollView.padding!.resolve(TextDirection.ltr);
        expect(scrollInsets.left, greaterThanOrEqualTo(16.0));
        expect(scrollInsets.right, greaterThanOrEqualTo(16.0));
        expect(scrollInsets.top, greaterThanOrEqualTo(14.0));
        expect(scrollInsets.bottom, 20.0);

        final listColumn = tester.widget<Column>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Column),
              )
              .first,
        );
        final spacers = listColumn.children.whereType<SizedBox>().toList();
        expect(spacers.length, 2);
        for (final spacer in spacers) {
          expect(spacer.height, greaterThanOrEqualTo(12.0));
        }

        controller.dispose();
      },
    );

    testWidgets(
      'mid-expand AnimatedSize clips and stays strictly below header bar',
      (tester) async {
        final controller = LyraToastController();
        await tester.pumpWidget(_buildToastTestApp(controller: controller));

        for (var i = 1; i <= 3; i++) {
          controller.show(
            LyraToast(id: 'm-$i', title: 'Toast $i', autoDismiss: false),
          );
        }
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final animatedSize = tester.widget<AnimatedSize>(
          find.descendant(
            of: find.byType(LyraToastStack),
            matching: find.byType(AnimatedSize),
          ),
        );
        expect(animatedSize.clipBehavior, Clip.hardEdge);

        final toggleRect = tester.getRect(
          find.byKey(const Key('toast_stack_toggle_button')),
        );
        final animatedRect = tester.getRect(
          find.descendant(
            of: find.byType(LyraToastStack),
            matching: find.byType(AnimatedSize),
          ),
        );
        expect(toggleRect.bottom, lessThanOrEqualTo(animatedRect.top + 0.01));

        await tester.pumpAndSettle();
        controller.dispose();
      },
    );

    testWidgets(
      'preserves toast subtree state across overflow threshold without remounting ShaderMask',
      (tester) async {
        final controller = LyraToastController();
        await tester.pumpWidget(_buildToastTestApp(controller: controller));

        controller.show(
          LyraToast(id: 't1', title: 'Toast 1', autoDismiss: false),
        );
        controller.show(
          LyraToast(id: 't2', title: 'Toast 2', autoDismiss: false),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();

        double t1Opacity() {
          final fade = tester.widget<FadeTransition>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('list_t1')),
                  matching: find.byType(FadeTransition),
                )
                .first,
          );
          return fade.opacity.value;
        }

        expect(t1Opacity(), 1.0);

        // Exceed _maxHeight while expanded so overflow fade activates
        for (var i = 3; i <= 7; i++) {
          controller.show(
            LyraToast(
              id: 't$i',
              title: 'Toast $i',
              message: 'Details for notification $i',
              autoDismiss: false,
            ),
          );
        }
        await tester.pump();
        expect(t1Opacity(), 1.0);
        await tester.pump(const Duration(milliseconds: 16));
        expect(t1Opacity(), 1.0);
        await tester.pump(const Duration(milliseconds: 16));
        expect(t1Opacity(), 1.0);

        await tester.pumpAndSettle();

        // Dismiss back below overflow threshold so overflow fade deactivates
        for (var i = 3; i <= 7; i++) {
          controller.dismiss('t$i', immediate: true);
        }
        await tester.pump();
        expect(t1Opacity(), 1.0);
        await tester.pump(const Duration(milliseconds: 16));
        expect(t1Opacity(), 1.0);
        await tester.pump(const Duration(milliseconds: 16));
        expect(t1Opacity(), 1.0);

        await tester.pumpAndSettle();
        controller.dispose();
      },
    );

    testWidgets(
      'expanded list keeps ShaderMask mounted with dst/dstIn across scroll positions and disposes cleanly',
      (tester) async {
        final controller = LyraToastController();
        await tester.pumpWidget(
          _buildToastTestApp(controller: controller, isDark: false),
        );

        // 2 toasts fit without scrolling -> ShaderMask stays mounted as pass-through dst
        controller.show(
          LyraToast(id: 'f-1', title: 'Toast 1', autoDismiss: false),
        );
        controller.show(
          LyraToast(id: 'f-2', title: 'Toast 2', autoDismiss: false),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();

        final shaderFinder = find.descendant(
          of: find.byType(LyraToastStack),
          matching: find.byType(ShaderMask),
        );
        expect(shaderFinder, findsOneWidget);
        expect(
          tester.widget<ShaderMask>(shaderFinder).blendMode,
          BlendMode.dst,
        );

        // Add 5 more toasts (7 total) so expanded list overflows maxHeight
        for (var i = 3; i <= 7; i++) {
          controller.show(
            LyraToast(
              id: 'f-$i',
              title: 'Toast $i',
              message: 'Details for notification $i',
              autoDismiss: false,
            ),
          );
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(shaderFinder, findsOneWidget);
        expect(
          tester.widget<ShaderMask>(shaderFinder).blendMode,
          BlendMode.dstIn,
        );

        // Verify scrolling at bottom (0.0), mid (60.0), and top (maxScrollExtent)
        final scrollFinder = find.descendant(
          of: find.byType(LyraToastStack),
          matching: find.byType(SingleChildScrollView),
        );
        final scrollView = tester.widget<SingleChildScrollView>(scrollFinder);
        final scrollController = scrollView.controller;
        expect(scrollController, isNotNull);
        final maxExtent = scrollController!.position.maxScrollExtent;
        expect(maxExtent, greaterThan(60.0));
        expect(scrollController.position.pixels, 0.0);

        // Mid scroll (both top and bottom overflow)
        scrollController.jumpTo(60.0);
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(scrollController.position.pixels, 60.0);
        expect(
          tester.widget<ShaderMask>(shaderFinder).blendMode,
          BlendMode.dstIn,
        );

        // Top scroll (maxScrollExtent -> only bottom overflows)
        scrollController.jumpTo(maxExtent);
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(scrollController.position.pixels, maxExtent);
        expect(
          tester.widget<ShaderMask>(shaderFinder).blendMode,
          BlendMode.dstIn,
        );

        // Scroll back to 0.0
        scrollController.jumpTo(0.0);
        await tester.pumpAndSettle();
        expect(scrollController.position.pixels, 0.0);

        // Dismiss back down to 2 toasts: overflow disappears and ShaderMask switches back to dst
        for (var i = 3; i <= 7; i++) {
          controller.dismiss('f-$i', immediate: true);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(shaderFinder, findsOneWidget);
        expect(
          tester.widget<ShaderMask>(shaderFinder).blendMode,
          BlendMode.dst,
        );

        // Verify clean unmount and disposal without controller leaks
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        controller.dispose();
      },
    );

    testWidgets(
      'dark mode shadows have full tail clearance and bottom card has zero vertical jump on toggle',
      (tester) async {
        final controller = LyraToastController();
        await tester.pumpWidget(
          _buildToastTestApp(controller: controller, isDark: true),
        );

        controller.show(
          LyraToast(id: 't1', title: 'First Toast', autoDismiss: false),
        );
        controller.show(
          LyraToast(id: 't2', title: 'Second Toast', autoDismiss: false),
        );
        await tester.pumpAndSettle();

        // Check dark mode primary shadow blurRadius <= 10.0 & deck blurRadius <= 6.0
        final cardContainer = tester.widget<Container>(
          find.byKey(const Key('toast_card_t2')),
        );
        final cardBoxShadows =
            (cardContainer.decoration as BoxDecoration).boxShadow!;
        expect(cardBoxShadows.first.blurRadius, lessThanOrEqualTo(10.0));

        final deckContainers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(LyraToastStack),
                matching: find.byType(Container),
              ),
            )
            .where((c) => c.key == null && c.decoration is BoxDecoration)
            .map((c) => c.decoration as BoxDecoration)
            .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty)
            .toList();
        expect(deckContainers, isNotEmpty);
        for (final dec in deckContainers) {
          expect(dec.boxShadow!.first.blurRadius, lessThanOrEqualTo(6.0));
        }

        final collapsedBottomY = tester
            .getRect(find.byKey(const Key('toast_card_t2')))
            .bottom;

        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();

        final expandedBottomY = tester
            .getRect(find.byKey(const Key('toast_card_t2')))
            .bottom;
        expect(expandedBottomY, closeTo(collapsedBottomY, 0.01));

        controller.dispose();
      },
    );

    testWidgets(
      'short viewport caps expanded scroll maxHeight so toast stack fits without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(800, 360);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = LyraToastController();
        await tester.pumpWidget(_buildToastTestApp(controller: controller));

        for (var i = 1; i <= 7; i++) {
          controller.show(
            LyraToast(
              id: 'short-$i',
              title: 'Toast $i',
              message: 'Details for notification $i',
              autoDismiss: false,
            ),
          );
        }
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('toast_stack_toggle_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final scrollConstrainedBox = tester.widget<ConstrainedBox>(
          find
              .ancestor(
                of: find.descendant(
                  of: find.byType(LyraToastStack),
                  matching: find.byType(SingleChildScrollView),
                ),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(
          scrollConstrainedBox.constraints.maxHeight,
          lessThanOrEqualTo(220.0),
        );

        final stackRect = tester.getRect(find.byType(LyraToastStack));
        expect(stackRect.top, greaterThanOrEqualTo(0.0));
        expect(stackRect.bottom, lessThanOrEqualTo(360.0));

        controller.dispose();
      },
    );

    testWidgets(
      'dark and light mode toast body text have legible size and WCAG contrast',
      (tester) async {
        for (final isDark in [true, false]) {
          final controller = LyraToastController();
          await tester.pumpWidget(
            _buildToastTestApp(controller: controller, isDark: isDark),
          );

          controller.show(
            LyraToast(
              id: 'contrast-$isDark',
              title: 'Metadata Updated',
              tag: 'FLAC',
              message: 'Track tags committed to CAS pool.',
              autoDismiss: false,
            ),
          );
          await tester.pumpAndSettle();

          final titleWidget = tester.widget<Text>(
            find.text('Metadata Updated'),
          );
          final messageWidget = tester.widget<Text>(
            find.text('Track tags committed to CAS pool.'),
          );
          final tagWidget = tester.widget<Text>(find.text('FLAC'));

          expect(titleWidget.style?.fontSize, greaterThanOrEqualTo(13.0));
          expect(messageWidget.style?.fontSize, greaterThanOrEqualTo(11.5));
          expect(tagWidget.style?.fontSize, greaterThanOrEqualTo(11.0));

          final tagMessageWrap = tester.widget<Wrap>(
            find.ancestor(
              of: find.text('Track tags committed to CAS pool.'),
              matching: find.byType(Wrap),
            ),
          );
          expect(tagMessageWrap.spacing, greaterThanOrEqualTo(8.0));
          expect(tagMessageWrap.runSpacing, greaterThanOrEqualTo(6.0));

          final tokens = isDark
              ? LyraThemeTokens.dark()
              : LyraThemeTokens.light();
          final fg = Color.alphaBlend(messageWidget.style!.color!, tokens.card);
          final l1 = fg.computeLuminance();
          final l2 = tokens.card.computeLuminance();
          final contrast = l1 > l2
              ? (l1 + 0.05) / (l2 + 0.05)
              : (l2 + 0.05) / (l1 + 0.05);
          expect(contrast, greaterThanOrEqualTo(isDark ? 7.0 : 4.5));

          controller.dispose();
        }
      },
    );

    testWidgets(
      'stack header label and multi-digit count badge remain legible without clipping',
      (tester) async {
        final controller = LyraToastController();
        await tester.pumpWidget(
          _buildToastTestApp(controller: controller, isDark: true),
        );

        for (var i = 1; i <= 12; i++) {
          controller.show(
            LyraToast(
              id: 'multi-$i',
              title: 'Notification $i',
              autoDismiss: false,
            ),
          );
        }
        await tester.pumpAndSettle();

        final labelWidget = tester.widget<Text>(find.text('Show more'));
        final countWidget = tester.widget<Text>(find.text('12'));
        expect(labelWidget.style?.fontSize, greaterThanOrEqualTo(12.0));
        expect(countWidget.style?.fontSize, greaterThanOrEqualTo(11.0));
        expect(tester.takeException(), isNull);

        controller.dispose();
      },
    );

    testWidgets(
      'LyraToastStack caps width at 420px on wide viewports and shrinks cleanly on narrow viewports',
      (tester) async {
        // Wide desktop viewport: capped at 420.0
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final wideController = LyraToastController();
        await tester.pumpWidget(
          _buildToastTestApp(controller: wideController, isDark: true),
        );
        wideController.show(
          LyraToast(
            id: 'wide-1',
            title: 'Wide Viewport Toast',
            message: 'Should cap at 420 logical pixels.',
            autoDismiss: false,
          ),
        );
        await tester.pumpAndSettle();

        final wideRect = tester.getRect(find.byType(LyraToastStack));
        expect(wideRect.width, 420.0);
        wideController.dispose();

        // Narrow viewport (360px): shrinks to viewportWidth - 40.0 = 320.0 without overflow
        tester.view.physicalSize = const Size(360, 640);
        final narrowController = LyraToastController();
        await tester.pumpWidget(
          _buildToastTestApp(controller: narrowController, isDark: true),
        );
        narrowController.show(
          LyraToast(
            id: 'narrow-1',
            title: 'Narrow Viewport Toast',
            message: 'Should shrink to fit within 360px viewport.',
            autoDismiss: false,
          ),
        );
        await tester.pumpAndSettle();

        final narrowRect = tester.getRect(find.byType(LyraToastStack));
        expect(narrowRect.width, 320.0);
        expect(narrowRect.right, lessThanOrEqualTo(360.0));
        expect(tester.takeException(), isNull);
        narrowController.dispose();
      },
    );
  });
}
