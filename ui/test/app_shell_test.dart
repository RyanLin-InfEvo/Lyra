// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/shell/app_shell.dart';
import 'package:ui/features/shell/player_bar.dart';
import 'package:ui/features/shell/sidebar.dart';
import 'package:ui/features/tracks/tracks_view.dart';

Widget _buildAppShellTest() {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();
  final service = MockMusicService();

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
          child: AppShell(musicService: service),
        );
      },
    ),
  );
}

void main() {
  testWidgets('AppShell renders sidebar, header, tracks, and player bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // Verify Brand / Sidebar
    expect(find.text('Lyra Audio'), findsOneWidget);
    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('CAS Storage'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Tracks table loaded
    expect(find.text('Tracks Library'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('Hotel California (Live on MTV 1994)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('So What'),
      ),
      findsOneWidget,
    );

    // Verify Player Bar
    expect(find.byType(LyraPlayerBar), findsOneWidget);

    // Verify redundant status badges are removed
    expect(find.text('Bit-Perfect Engine'), findsNothing);
    expect(find.text('CAS Validated'), findsNothing);
    expect(find.text('Direct Out'), findsNothing);
  });

  testWidgets('AppShell navigates between sidebar tabs', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // Switch to Albums
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(find.text('Kind of Blue'), findsOneWidget);
    expect(find.text('Hell Freezes Over'), findsOneWidget);

    // Switch to CAS Storage
    await tester.tap(find.text('CAS Storage'));
    await tester.pumpAndSettle();
    expect(find.text('Content Addressable Storage'), findsOneWidget);
    expect(find.text('INTEGRITY HASH'), findsOneWidget);

    // Switch to Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Audio Output'), findsOneWidget);
    expect(find.text('Zinc Dark'), findsOneWidget);
  });

  testWidgets('AppShell search bar filters tracks in real-time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // Enter search query
    final searchInput = find.byType(EditableText).first;
    await tester.enterText(searchInput, 'Daft Punk');
    await tester.pumpAndSettle();

    // Should find Giorgio by Moroder in TracksView but not Hotel California
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('Giorgio by Moroder'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TracksView),
        matching: find.text('Hotel California (Live on MTV 1994)'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'AppShell responsive sidebar collapses automatically on small screens and allows toggle',
    (tester) async {
      // 1. Wide Desktop (1280px) -> Sidebar expanded by default
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      expect(find.text('Lyra Audio'), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(find.text('Collapse'), findsOneWidget);

      // 2. Toggle collapse manually on wide desktop
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();

      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('Collapse'), findsNothing);

      // 3. Small Screen (< 900px, e.g. 800px) -> Effective collapsed
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpAndSettle();

      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
    },
  );

  testWidgets(
    'LyraSidebar icons and logo are precisely centered when collapsed',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Collapse sidebar
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();

      // 1. Sidebar width is 64.0
      final sidebarFinder = find.byType(LyraSidebar);
      expect(sidebarFinder, findsOneWidget);
      final sidebarSize = tester.getSize(sidebarFinder);
      expect(sidebarSize.width, 64.0);

      // 2. Logo icon is centered at x = 31.5 (64px width - 1px right border = 63px content width)
      final musicIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.music),
      );
      expect(musicIcon, findsOneWidget);
      expect(tester.getCenter(musicIcon).dx, 31.5);

      // 3. Navigation icons are centered at x = 31.5
      final tracksIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.listMusic),
      );
      expect(tracksIcon, findsOneWidget);
      expect(tester.getCenter(tracksIcon).dx, 31.5);

      final albumsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.disc),
      );
      expect(albumsIcon, findsOneWidget);
      expect(tester.getCenter(albumsIcon).dx, 31.5);

      final artistsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.mic),
      );
      expect(artistsIcon, findsOneWidget);
      expect(tester.getCenter(artistsIcon).dx, 31.5);

      final casIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.hardDrive),
      );
      expect(casIcon, findsOneWidget);
      expect(tester.getCenter(casIcon).dx, 31.5);

      final settingsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.settings),
      );
      expect(settingsIcon, findsOneWidget);
      expect(tester.getCenter(settingsIcon).dx, 31.5);

      // 4. Collapse toggle icon is centered at x = 31.5
      final toggleIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.chevronRight),
      );
      expect(toggleIcon, findsOneWidget);
      expect(tester.getCenter(toggleIcon).dx, 31.5);

      // 5. Verify text labels are hidden
      expect(find.text('Tracks'), findsNothing);
      expect(find.text('Albums'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
    },
  );
}
