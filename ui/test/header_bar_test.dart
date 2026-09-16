// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/shell/header_bar.dart';

Widget _buildHeaderBarTest({
  required TextEditingController searchController,
  ValueChanged<String>? onSearchChanged,
  ValueChanged<String>? onSearchSubmitted,
  VoidCallback? onImportPressed,
  VoidCallback? onToggleSidebar,
  bool isSidebarCollapsed = false,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
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
            child: Scaffold(
              body: LyraHeaderBar(
                searchController: searchController,
                onSearchChanged: onSearchChanged ?? (_) {},
                onSearchSubmitted: onSearchSubmitted,
                onImportPressed: onImportPressed ?? () {},
                onToggleSidebar: onToggleSidebar,
                isSidebarCollapsed: isSidebarCollapsed,
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  testWidgets('LyraHeaderBar renders search, theme toggle, and import audio', (
    tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    String? searchedQuery;
    bool importPressed = false;
    final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
    addTearDown(themeNotifier.dispose);

    await tester.pumpWidget(
      _buildHeaderBarTest(
        searchController: searchController,
        onSearchChanged: (q) => searchedQuery = q,
        onImportPressed: () => importPressed = true,
        themeNotifier: themeNotifier,
      ),
    );
    await tester.pumpAndSettle();

    // Verify search input
    expect(
      find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == searchController.text,
      ),
      findsOneWidget,
    );

    // Enter search text
    final searchInput = find.byType(EditableText).first;
    await tester.enterText(searchInput, 'Hi-Res Album');
    await tester.pumpAndSettle();
    expect(searchedQuery, equals('Hi-Res Album'));

    // Verify Import Audio button
    final importButton = find.text('Import Audio');
    expect(importButton, findsOneWidget);
    await tester.tap(importButton);
    await tester.pumpAndSettle();
    expect(importPressed, isTrue);

    // Verify Theme toggle toggles dark/light theme
    expect(themeNotifier.value, equals(ThemeMode.dark));
    final themeButton = find.byIcon(LucideIcons.sun);
    expect(themeButton, findsOneWidget);
    await tester.tap(themeButton);
    await tester.pumpAndSettle();
    expect(themeNotifier.value, equals(ThemeMode.light));

    // Toggle back to dark
    final moonButton = find.byIcon(LucideIcons.moon);
    expect(moonButton, findsOneWidget);
    await tester.tap(moonButton);
    await tester.pumpAndSettle();
    expect(themeNotifier.value, equals(ThemeMode.dark));
  });

  testWidgets(
    'LyraHeaderBar renders sidebar toggle button with appropriate tooltip and triggers callback',
    (tester) async {
      final searchController = TextEditingController();
      addTearDown(searchController.dispose);
      bool toggleCalled = false;

      await tester.pumpWidget(
        _buildHeaderBarTest(
          searchController: searchController,
          onToggleSidebar: () => toggleCalled = true,
          isSidebarCollapsed: false,
        ),
      );
      await tester.pumpAndSettle();

      // Tooltip should indicate collapsing when expanded
      expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
      expect(find.byIcon(LucideIcons.panelLeft), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.panelLeft));
      await tester.pumpAndSettle();
      expect(toggleCalled, isTrue);

      // Verify tooltip when collapsed
      await tester.pumpWidget(
        _buildHeaderBarTest(
          searchController: searchController,
          onToggleSidebar: () => toggleCalled = true,
          isSidebarCollapsed: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Expand sidebar'), findsOneWidget);
    },
  );

  testWidgets(
    'LyraHeaderBar triggers onSearchSubmitted when Enter is submitted',
    (tester) async {
      final searchController = TextEditingController();
      addTearDown(searchController.dispose);
      String? submittedQuery;

      await tester.pumpWidget(
        _buildHeaderBarTest(
          searchController: searchController,
          onSearchSubmitted: (q) => submittedQuery = q,
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byType(EditableText).first;
      await tester.enterText(searchInput, 'Desperado');
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submittedQuery, equals('Desperado'));
    },
  );
}
