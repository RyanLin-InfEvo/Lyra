// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_copy_button.dart';

Widget _buildTestApp({
  required Widget child,
  ThemeMode initialThemeMode = ThemeMode.dark,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(initialThemeMode);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Copy Button Test',
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
            child: Scaffold(body: Center(child: child)),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> clipboardCalls;

  setUp(() {
    clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardCalls.add(methodCall);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('LyraCopyButton Default Variant', () {
    testWidgets('renders default compact copy button with copy icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: const LyraCopyButton(text: 'default_test_text')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LyraCopyButton), findsOneWidget);
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNothing);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Copied'), findsNothing);

      // Verify transparent border and background in idle state
      final containerFinder = find.descendant(
        of: find.byType(LyraCopyButton),
        matching: find.byType(AnimatedContainer),
      );
      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0x00000000)));
      expect(decoration.border?.top.color, equals(const Color(0x00000000)));
    });

    testWidgets('shows highlighted box ("反白框") on mouse hover', (tester) async {
      final tokens = LyraThemeTokens.dark();

      await tester.pumpWidget(
        _buildTestApp(child: const LyraCopyButton(text: 'hover_test_text')),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      // Hover over the copy button
      await gesture.moveTo(tester.getCenter(find.byType(LyraCopyButton)));
      await tester.pumpAndSettle();

      final containerFinder = find.descendant(
        of: find.byType(LyraCopyButton),
        matching: find.byType(AnimatedContainer),
      );
      final hoveredContainer = tester.widget<AnimatedContainer>(
        containerFinder,
      );
      final hoveredDeco = hoveredContainer.decoration as BoxDecoration;

      // Verify highlighted border box ("反白框")
      expect(
        hoveredDeco.color,
        equals(tokens.secondary.withValues(alpha: 0.5)),
      );
      expect(
        hoveredDeco.border?.top.color,
        equals(tokens.text.withValues(alpha: 0.25)),
      );

      // Verify icon color highlights to tokens.text
      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.copy));
      expect(icon.color, equals(tokens.text));

      // Move mouse away
      await gesture.moveTo(const Offset(10, 10));
      await tester.pumpAndSettle();

      final unhoveredContainer = tester.widget<AnimatedContainer>(
        containerFinder,
      );
      final unhoveredDeco = unhoveredContainer.decoration as BoxDecoration;
      expect(unhoveredDeco.color, equals(const Color(0x00000000)));
      expect(unhoveredDeco.border?.top.color, equals(const Color(0x00000000)));
    });

    testWidgets('copies text to clipboard on tap and triggers onCopied', (
      tester,
    ) async {
      bool onCopiedCalled = false;

      await tester.pumpWidget(
        _buildTestApp(
          child: LyraCopyButton(
            text: 'pcm-hash-12345678',
            onCopied: () => onCopiedCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LyraCopyButton));
      await tester.pump();

      expect(clipboardCalls, isNotEmpty);
      expect(
        clipboardCalls.last.arguments['text'],
        equals('pcm-hash-12345678'),
      );
      expect(onCopiedCalled, isTrue);
    });

    testWidgets(
      'transitions smoothly to green checkmark with emerald tint (no text label in default mode)',
      (tester) async {
        final tokens = LyraThemeTokens.dark();

        await tester.pumpWidget(
          _buildTestApp(
            child: const LyraCopyButton(text: 'transition_test_text'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(LyraCopyButton));
        await tester.pumpAndSettle();

        // Check icon switched to checkmark with tokens.success
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
        final checkIcon = tester.widget<Icon>(find.byIcon(LucideIcons.check));
        expect(checkIcon.color, equals(tokens.success));

        // In default mode, no text label is shown (remains strictly icon-only)
        expect(find.text('Copied'), findsNothing);

        // Container decoration has emerald green tint and border
        final containerFinder = find.descendant(
          of: find.byType(LyraCopyButton),
          matching: find.byType(AnimatedContainer),
        );
        final copiedContainer = tester.widget<AnimatedContainer>(
          containerFinder,
        );
        final copiedDeco = copiedContainer.decoration as BoxDecoration;
        expect(
          copiedDeco.color,
          equals(tokens.success.withValues(alpha: 0.12)),
        );
        expect(
          copiedDeco.border?.top.color,
          equals(tokens.success.withValues(alpha: 0.5)),
        );
      },
    );

    testWidgets('shows "Copied" text when showCopiedLabel is explicitly true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const LyraCopyButton(
            text: 'transition_test_text',
            showCopiedLabel: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LyraCopyButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets(
      'maintains strictly identical size between idle, hover, and copied states',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: const LyraCopyButton(text: 'size_stability_test'),
          ),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byType(LyraCopyButton);
        final initialSize = tester.getSize(buttonFinder);
        expect(initialSize.width, equals(24.0));
        expect(initialSize.height, equals(24.0));

        // 1. Hover state
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(buttonFinder));
        await tester.pumpAndSettle();

        final hoveredSize = tester.getSize(buttonFinder);
        expect(hoveredSize, equals(initialSize));

        // 2. Copied state
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        final copiedSize = tester.getSize(buttonFinder);
        expect(copiedSize, equals(initialSize));

        // 3. During transition animation
        await tester.pump(const Duration(milliseconds: 100));
        final animatingSize = tester.getSize(buttonFinder);
        expect(animatingSize, equals(initialSize));

        // 4. After feedbackDuration reset
        await tester.pump(const Duration(milliseconds: 1800));
        await tester.pumpAndSettle();

        final resetSize = tester.getSize(buttonFinder);
        expect(resetSize, equals(initialSize));
      },
    );

    testWidgets(
      'updates tooltip from "Copy" in idle to "Copied" in copied state',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: const LyraCopyButton(text: 'tooltip_test_text')),
        );
        await tester.pumpAndSettle();

        final tooltipFinder = find.byType(Tooltip);
        expect(tooltipFinder, findsOneWidget);
        Tooltip tooltipWidget = tester.widget<Tooltip>(tooltipFinder);
        expect(tooltipWidget.message, equals('Copy'));

        await tester.tap(find.byType(LyraCopyButton));
        await tester.pumpAndSettle();

        tooltipWidget = tester.widget<Tooltip>(tooltipFinder);
        expect(tooltipWidget.message, equals('Copied'));
      },
    );

    testWidgets('resets back to copy state after feedbackDuration', (
      tester,
    ) async {
      const feedbackDuration = Duration(milliseconds: 1500);

      await tester.pumpWidget(
        _buildTestApp(
          child: const LyraCopyButton(
            text: 'reset_timer_test',
            feedbackDuration: feedbackDuration,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LyraCopyButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.text('Copied'), findsNothing);

      // Advance by feedbackDuration
      await tester.pump(feedbackDuration);
      await tester.pumpAndSettle();

      // State reverted cleanly
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNothing);
      expect(find.text('Copied'), findsNothing);
    });

    testWidgets(
      'unmounting while feedback timer is active does not throw or leak',
      (tester) async {
        final showButton = ValueNotifier<bool>(true);

        await tester.pumpWidget(
          _buildTestApp(
            child: ValueListenableBuilder<bool>(
              valueListenable: showButton,
              builder: (context, show, _) {
                return show
                    ? const LyraCopyButton(text: 'unmount_text')
                    : const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger copy to start the reset timer
        await tester.tap(find.byType(LyraCopyButton));
        await tester.pump();

        // Unmount the widget before timer fires
        showButton.value = false;
        await tester.pumpAndSettle();

        expect(find.byType(LyraCopyButton), findsNothing);

        // Advance clock past timer expiration - no crash or unhandled exception
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('LyraCopyButton.icon Variant', () {
    testWidgets('stays strictly icon-only without label even when copied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: const LyraCopyButton.icon(text: 'icon_only_hash')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Copied'), findsNothing);

      await tester.tap(find.byType(LyraCopyButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.text('Copied'), findsNothing);
    });
  });

  group('LyraCopyButton.labeled Variant', () {
    testWidgets('shows custom label and transitions to custom copiedLabel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const LyraCopyButton.labeled(
            text: 'path/to/flac',
            label: 'Copy Path',
            copiedLabel: 'Path Copied!',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.text('Copy Path'), findsOneWidget);

      await tester.tap(find.byType(LyraCopyButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.text('Path Copied!'), findsOneWidget);
      expect(find.text('Copy Path'), findsNothing);
    });
  });

  group('Theme Adaptation', () {
    testWidgets('adapts border and colors between Dark and Light mode', (
      tester,
    ) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

      await tester.pumpWidget(
        _buildTestApp(
          themeNotifier: themeNotifier,
          child: const LyraCopyButton.labeled(text: 'theme_text'),
        ),
      );
      await tester.pumpAndSettle();

      final darkTokens = LyraThemeTokens.dark();
      final darkLabel = tester.widget<Text>(find.text('Copy'));
      expect(darkLabel.style?.color, equals(darkTokens.textMuted));

      // Switch to light mode
      themeNotifier.value = ThemeMode.light;
      await tester.pumpAndSettle();

      final lightTokens = LyraThemeTokens.light();
      final lightLabel = tester.widget<Text>(find.text('Copy'));
      expect(lightLabel.style?.color, equals(lightTokens.textMuted));
    });
  });

  group('Keyboard and Focus Support', () {
    testWidgets('copies text when activated via Enter or Space key', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _buildTestApp(
          child: LyraCopyButton(
            text: 'keyboard_copy_text',
            focusNode: focusNode,
          ),
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Send Enter key
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(clipboardCalls, isNotEmpty);
      expect(
        clipboardCalls.last.arguments['text'],
        equals('keyboard_copy_text'),
      );
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });
  });
}
