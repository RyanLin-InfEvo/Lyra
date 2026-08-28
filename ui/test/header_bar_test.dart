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
  VoidCallback? onImportPressed,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();

  return ShadApp(
    themeMode: ThemeMode.dark,
    darkTheme: ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(),
    ),
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        final tokens = themeMode == ThemeMode.dark
            ? LyraThemeTokens.dark()
            : LyraThemeTokens.light();
        return LyraDesignSystemScope(
          factory: factory,
          tokens: tokens,
          themeModeNotifier: themeModeNotifier,
          child: Scaffold(
            body: LyraHeaderBar(
              searchController: searchController,
              onSearchChanged: onSearchChanged ?? (_) {},
              onImportPressed: onImportPressed ?? () {},
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
    // The theme button is the outline button
    final themeButton = find.byType(ShadButton).first;
    await tester.tap(themeButton);
    await tester.pumpAndSettle();
    expect(themeNotifier.value, equals(ThemeMode.light));
  });
}
