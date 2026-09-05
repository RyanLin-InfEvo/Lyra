// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/albums/albums_view.dart';
import 'package:ui/features/artists/artists_view.dart';
import 'package:ui/features/cas_pool/cas_view.dart';
import 'package:ui/features/inspector/asset_inspector_drawer.dart';
import 'package:ui/features/player/views/now_playing_view.dart';
import 'package:ui/features/playlists/playlists_view.dart';
import 'package:ui/features/services/mock_music_service.dart';
import 'package:ui/features/settings/settings_view.dart';
import 'package:ui/features/shell/app_shell.dart';
import 'package:ui/features/shell/header_bar.dart';
import 'package:ui/features/shell/player_bar.dart';
import 'package:ui/features/shell/sidebar.dart';
import 'package:ui/features/tags/tags_view.dart';
import 'package:ui/features/tracks/tracks_view.dart';
import 'package:ui/features/works/works_view.dart';

Widget _buildAppShellTest({
  MockMusicService? service,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();
  final musicService = service ?? MockMusicService();

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
            child: AppShell(musicService: musicService),
          ),
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
    expect(find.text('Works'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('All Playlists'), findsNothing);
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

    // Verify redundant status badges are removed per Rule 3
    expect(find.text('Bit-Perfect Engine'), findsNothing);
    expect(find.text('CAS Validated'), findsNothing);
    expect(find.text('Direct Out'), findsNothing);
    expect(find.text('Bit-Perfect CAS'), findsNothing);
  });

  testWidgets('AppShell navigates between all sidebar tabs', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildAppShellTest());
    await tester.pumpAndSettle();

    // 1. Switch to Works
    await tester.tap(find.text('Works'));
    await tester.pumpAndSettle();
    expect(find.byType(WorksView), findsOneWidget);
    expect(find.text('Musical Works'), findsOneWidget);
    expect(find.text('Hotel California'), findsOneWidget);

    // 2. Switch to Albums
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumsView), findsOneWidget);
    expect(find.text('Kind of Blue'), findsOneWidget);
    expect(find.text('Hell Freezes Over'), findsOneWidget);

    // 3. Switch to Artists
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtistsView), findsOneWidget);
    expect(find.text('Miles Davis'), findsWidgets);
    expect(find.text('Pink Floyd'), findsWidgets);

    // 4. Switch to Playlists
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistsView), findsOneWidget);
    expect(find.text('Audiophile Reference Master'), findsWidgets);
    expect(find.text('Late Night Jazz'), findsWidgets);

    // 5. Switch to Tags
    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(find.byType(TagsView), findsOneWidget);
    expect(find.text('Tags'), findsWidgets);
    expect(find.text('Audiophile'), findsWidgets);
    expect(find.text('Hi-Res'), findsWidgets);

    // 6. Switch to CAS Storage
    await tester.tap(find.text('CAS Storage'));
    await tester.pumpAndSettle();
    expect(find.byType(CasView), findsOneWidget);
    expect(find.text('Content Addressable Storage'), findsOneWidget);
    expect(find.text('INTEGRITY HASH'), findsOneWidget);

    // 7. Switch to Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.text('Audio Output'), findsOneWidget);
    expect(find.text('Zinc Dark'), findsOneWidget);

    // 8. Switch back to Tracks
    await tester.tap(find.text('Tracks'));
    await tester.pumpAndSettle();
    expect(find.byType(TracksView), findsOneWidget);
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
    'AppShell sidebar tag click filters tracks library with badge and Tags header opens TagsView',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Switch to Albums first
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumsView), findsOneWidget);

      // Click 'Audiophile' tag in sidebar
      expect(find.text('Audiophile'), findsOneWidget);
      await tester.tap(find.text('Audiophile'));
      await tester.pumpAndSettle();

      // Should navigate to TracksView with filter badge 'Tag: Audiophile'
      expect(find.byType(TracksView), findsOneWidget);
      expect(find.text('Tag: Audiophile'), findsOneWidget);

      // Search controller must NOT be mutated
      final searchInput = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(searchInput.controller.text, isEmpty);

      // Clear filter via X button
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(find.text('Tag: Audiophile'), findsNothing);

      // Click 'Tags' header in sidebar -> navigates to TagsView
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      expect(find.byType(TagsView), findsOneWidget);
      expect(find.text('Tags'), findsWidgets);
    },
  );

  testWidgets(
    'AppShell PlaylistsView "New Playlist" action creates playlist and sidebar has no redundant button',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Verify no "+ New Playlist" button in sidebar
      expect(find.text('+ New Playlist'), findsNothing);

      // Navigate to Playlists tab
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistsView), findsOneWidget);

      // Click top-right 'New Playlist' button in PlaylistsView
      final newPlaylistBtn = find.descendant(
        of: find.byType(PlaylistsView),
        matching: find.text('New Playlist'),
      );
      expect(newPlaylistBtn, findsOneWidget);
      await tester.tap(newPlaylistBtn);
      await tester.pumpAndSettle();

      // Should have newly created playlist in the list
      expect(find.text('New Playlist 4'), findsWidgets);
    },
  );

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
      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('Collapse'), findsOneWidget);

      // 2. Toggle collapse manually on wide desktop
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();

      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('Playlists'), findsNothing);
      expect(find.text('Collapse'), findsNothing);

      // 3. Small Screen (< 900px, e.g. 800px) -> Effective collapsed
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpAndSettle();

      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('Playlists'), findsNothing);
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

      final worksIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.layers),
      );
      expect(worksIcon, findsOneWidget);
      expect(tester.getCenter(worksIcon).dx, 31.5);

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

      final playlistsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.listPlus),
      );
      expect(playlistsIcon, findsOneWidget);
      expect(tester.getCenter(playlistsIcon).dx, 31.5);

      final tagIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.tag),
      );
      expect(tagIcon, findsOneWidget);
      expect(tester.getCenter(tagIcon).dx, 31.5);

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
      expect(find.text('Works'), findsNothing);
      expect(find.text('Albums'), findsNothing);
      expect(find.text('Artists'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
    },
  );

  testWidgets(
    'AppShell search bar query does not filter or wipe out left sidebar playlists',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Verify sidebar contains initial playlists
      final sidebarFinder = find.byType(LyraSidebar);
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.text('Audiophile Reference Master'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.text('Late Night Jazz'),
        ),
        findsOneWidget,
      );

      // Perform a search query that matches a track but NO playlist
      final searchInput = find.byType(EditableText).first;
      await tester.enterText(searchInput, 'Daft Punk');
      await tester.pumpAndSettle();

      // Main content filtered
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

      // Left sidebar navigation playlists remain intact and visible
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.text('Audiophile Reference Master'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.text('Late Night Jazz'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AppShell AlbumsView navigation to TracksView scopes tracks cleanly without mutating search input',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // Navigate to Albums
      await tester.tap(find.text('Albums'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumsView), findsOneWidget);

      // Click 'Hell Freezes Over' album card
      await tester.tap(find.text('Hell Freezes Over'));
      await tester.pumpAndSettle();

      // Should be in TracksView
      expect(find.byType(TracksView), findsOneWidget);
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
        findsNothing,
      );
      expect(find.text('Album: Hell Freezes Over'), findsOneWidget);

      // Search controller must NOT be mutated
      final searchInput = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(searchInput.controller.text, isEmpty);

      // Clear filter via X button
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      // All tracks restored
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
      expect(find.text('Album: Hell Freezes Over'), findsNothing);
    },
  );

  testWidgets(
    'AppShell WorksView and ArtistsView navigation to TracksView scopes tracks cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Works navigation
      await tester.tap(find.text('Works'));
      await tester.pumpAndSettle();
      expect(find.byType(WorksView), findsOneWidget);

      await tester.tap(find.text('Hotel California'));
      await tester.pumpAndSettle();

      expect(find.byType(TracksView), findsOneWidget);
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
        findsNothing,
      );
      expect(find.text('Work: Hotel California'), findsOneWidget);

      // Search text still empty
      var searchInput = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(searchInput.controller.text, isEmpty);

      // 2. Artists navigation
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistsView), findsOneWidget);

      await tester.tap(find.text('Miles Davis'));
      await tester.pumpAndSettle();

      expect(find.byType(TracksView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('So What'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TracksView),
          matching: find.text('Blue in Green'),
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
      expect(find.text('Artist: Miles Davis'), findsOneWidget);

      // Search text still empty
      searchInput = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(searchInput.controller.text, isEmpty);

      // 3. Clicking Tracks in sidebar clears scoped filter
      await tester.tap(find.text('Tracks'));
      await tester.pumpAndSettle();

      expect(find.text('Artist: Miles Davis'), findsNothing);
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
    },
  );

  testWidgets(
    'Toggling theme from header updates background, sidebar, playlist cards, and tags in real-time',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(themeNotifier.dispose);

      await tester.pumpWidget(_buildAppShellTest(themeNotifier: themeNotifier));
      await tester.pumpAndSettle();

      // 1. Initial dark mode
      expect(themeNotifier.value, equals(ThemeMode.dark));
      final scaffoldDark = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldDark.backgroundColor, equals(LyraColors.zinc950));

      // Toggle to Light Mode via theme button in HeaderBar (shows sun icon in dark mode)
      final themeToggleBtn = find.byIcon(LucideIcons.sun);
      expect(themeToggleBtn, findsOneWidget);
      await tester.tap(themeToggleBtn);
      await tester.pumpAndSettle();

      expect(themeNotifier.value, equals(ThemeMode.light));
      expect(find.byIcon(LucideIcons.moon), findsOneWidget);
      final scaffoldLight = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldLight.backgroundColor, equals(const Color(0xFFFFFFFF)));

      // 2. Check PlaylistsView in Light Mode
      await tester.tap(find.text('Playlists').first);
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistsView), findsOneWidget);

      // Verify that ShadTheme inside PlaylistsView is light
      final playlistsElement = find.byType(PlaylistsView).evaluate().first;
      final playlistsShadTheme = ShadTheme.of(playlistsElement);
      expect(playlistsShadTheme.brightness, equals(Brightness.light));
      expect(
        playlistsShadTheme.colorScheme.card,
        equals(const ShadZincColorScheme.light().card),
      );

      // 3. Check TagsView in Light Mode
      await tester.tap(find.text('Tags').first);
      await tester.pumpAndSettle();
      expect(find.byType(TagsView), findsOneWidget);

      final tagsElement = find.byType(TagsView).evaluate().first;
      final tagsShadTheme = ShadTheme.of(tagsElement);
      expect(tagsShadTheme.brightness, equals(Brightness.light));
      expect(
        tagsShadTheme.colorScheme.card,
        equals(const ShadZincColorScheme.light().card),
      );

      // 4. Check SettingsView and switch back to Dark Mode via Settings card
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsView), findsOneWidget);

      // Tap the Zinc Dark theme option card
      await tester.tap(find.text('Zinc Dark'));
      await tester.pumpAndSettle();

      expect(themeNotifier.value, equals(ThemeMode.dark));
      final scaffoldBackDark = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffoldBackDark.backgroundColor, equals(LyraColors.zinc950));
    },
  );

  testWidgets(
    'AppShell opens AssetInspectorDrawer from PlayerBar, track info icon, track CAS badge, and dynamically updates on track switch',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Initial State: Inspector is closed
      expect(find.byType(AssetInspectorDrawer), findsNothing);

      // 2. Open Inspector via PlayerBar inspect button
      final playerBarFinder = find.byType(LyraPlayerBar);
      final playerBarInspectBtn = find.descendant(
        of: playerBarFinder,
        matching: find.byIcon(LucideIcons.fileSearch),
      );
      expect(playerBarInspectBtn, findsOneWidget);
      await tester.tap(playerBarInspectBtn);
      await tester.pumpAndSettle();

      // Drawer is opened
      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(find.text('Inspector'), findsOneWidget);
      expect(find.text('Acoustic Specifications'), findsOneWidget);
      expect(find.text('Digital Provenance'), findsOneWidget);

      // 3. Dynamic track update: while inspector is open, select a different track ('So What')
      final soWhatTrack = find.descendant(
        of: find.byType(TracksView),
        matching: find.text('So What'),
      );
      expect(soWhatTrack, findsOneWidget);
      await tester.tap(soWhatTrack);
      await tester.pumpAndSettle();

      // Inspector dynamically updates to 'So What'
      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AssetInspectorDrawer),
          matching: find.text('So What'),
        ),
        findsWidgets,
      );

      // 4. Toggle Inspector off via PlayerBar button
      await tester.tap(playerBarInspectBtn);
      await tester.pumpAndSettle();
      expect(find.byType(AssetInspectorDrawer), findsNothing);

      // 5. Open Inspector via Track row info icon
      final trackInfoIcons = find.descendant(
        of: find.byType(TracksView),
        matching: find.byIcon(LucideIcons.info),
      );
      expect(trackInfoIcons, findsWidgets);
      await tester.tap(trackInfoIcons.first);
      await tester.pumpAndSettle();

      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(find.text('Hotel California (Live on MTV 1994)'), findsWidgets);

      // 6. Close Drawer via X button in header
      final drawerCloseBtn = find.descendant(
        of: find.byType(AssetInspectorDrawer),
        matching: find.byIcon(LucideIcons.x),
      );
      expect(drawerCloseBtn, findsOneWidget);
      await tester.tap(drawerCloseBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AssetInspectorDrawer), findsNothing);

      // 7. Open Inspector via PlayerBar inspect button again
      await tester.tap(playerBarInspectBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AssetInspectorDrawer), findsOneWidget);

      // 8. Close Drawer again
      await tester.tap(drawerCloseBtn);
      await tester.pumpAndSettle();
      expect(find.byType(AssetInspectorDrawer), findsNothing);

      // 9. Open Inspector by clicking on a Track CAS Hash Badge
      final trackCasBadge = find.text('7f83b1...9069');
      expect(trackCasBadge, findsWidgets);
      await tester.tap(trackCasBadge.first);
      await tester.pumpAndSettle();

      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(find.text('Hotel California (Live on MTV 1994)'), findsWidgets);
      expect(find.text('CD-Rip'), findsOneWidget);

      // 10. Navigate to CAS Storage and click a blob to inspect
      await tester.tap(find.text('CAS Storage'));
      await tester.pumpAndSettle();
      expect(find.byType(CasView), findsOneWidget);

      // Tap on a CAS object row in CasView
      final casRow = find.text(
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(casRow, findsOneWidget);
      await tester.tap(casRow);
      await tester.pumpAndSettle();

      // Verify inspector switches to CAS Physical File Blob mode
      expect(find.byType(AssetInspectorDrawer), findsOneWidget);
      expect(find.text('CAS Physical File Blob'), findsOneWidget);
    },
  );

  testWidgets(
    'AppShell keeps Sidebar, HeaderBar, and PlayerBar visible and interactive when NowPlaying is expanded',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildAppShellTest());
      await tester.pumpAndSettle();

      // 1. Play a track by tapping the first track in TracksView
      final trackFinder = find
          .text('Hotel California (Live on MTV 1994)')
          .first;
      await tester.tap(trackFinder);
      await tester.pumpAndSettle();

      // Verify NowPlayingView is initially not present
      expect(find.byType(NowPlayingView), findsNothing);

      // PlayerBar toggle button is chevronUp
      expect(find.byIcon(LucideIcons.chevronUp), findsOneWidget);
      expect(find.byTooltip('Expand Now Playing'), findsOneWidget);

      // 2. Expand NowPlaying by tapping the expand button on PlayerBar
      await tester.tap(find.byTooltip('Expand Now Playing'));
      await tester.pumpAndSettle();

      // NowPlayingView is now visible in the center area
      expect(find.byType(NowPlayingView), findsOneWidget);

      // 3. Verify Sidebar, HeaderBar, and PlayerBar remain fully visible!
      expect(find.byType(LyraSidebar), findsOneWidget);
      expect(find.byType(LyraHeaderBar), findsOneWidget);
      expect(find.byType(LyraPlayerBar), findsOneWidget);

      // PlayerBar now shows chevronDown with Collapse tooltip
      expect(find.byTooltip('Collapse Now Playing'), findsOneWidget);

      // Sidebar items remain visible
      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Artists'), findsWidgets);

      // HeaderBar search input remains interactive
      final searchInput = find.byType(EditableText).first;
      await tester.enterText(searchInput, 'Miles');
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(searchInput);
      expect(editable.controller.text, equals('Miles'));

      // 4. Collapse NowPlaying by tapping the Collapse button on PlayerBar
      await tester.tap(find.byTooltip('Collapse Now Playing'));
      await tester.pumpAndSettle();

      // NowPlayingView is collapsed
      expect(find.byType(NowPlayingView), findsNothing);
      expect(find.byTooltip('Expand Now Playing'), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronUp), findsOneWidget);

      // 5. Expand again and collapse via Escape keyboard shortcut
      await tester.tap(find.byTooltip('Expand Now Playing'));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingView), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingView), findsNothing);
    },
  );
}
