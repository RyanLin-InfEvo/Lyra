// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/tag.dart';
import 'package:ui/features/shell/sidebar.dart';

Widget _buildSidebarTest({
  AppTab currentTab = AppTab.tracks,
  bool isCollapsed = false,
  ValueChanged<AppTab>? onTabSelected,
  VoidCallback? onToggleCollapse,
  List<Playlist> playlists = const [],
  String? selectedPlaylistId,
  ValueChanged<Playlist>? onPlaylistSelected,
  List<Tag> tags = const [],
  String? selectedTagId,
  ValueChanged<Tag>? onTagSelected,
  bool defaultPlaylistsExpanded = true,
  bool defaultTagsExpanded = true,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
  const factory = ShadcnFactory();
  final tokens = LyraThemeTokens.dark();

  return ShadApp(
    themeMode: ThemeMode.dark,
    darkTheme: ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(),
    ),
    home: LyraDesignSystemScope(
      factory: factory,
      tokens: tokens,
      themeModeNotifier: themeModeNotifier,
      child: Scaffold(
        body: LyraSidebar(
          currentTab: currentTab,
          isCollapsed: isCollapsed,
          onTabSelected: onTabSelected ?? (_) {},
          onToggleCollapse: onToggleCollapse ?? () {},
          playlists: playlists,
          selectedPlaylistId: selectedPlaylistId,
          onPlaylistSelected: onPlaylistSelected,
          tags: tags,
          selectedTagId: selectedTagId,
          onTagSelected: onTagSelected,
          defaultPlaylistsExpanded: defaultPlaylistsExpanded,
          defaultTagsExpanded: defaultTagsExpanded,
        ),
      ),
    ),
  );
}

void main() {
  final samplePlaylists = [
    Playlist(id: 'pl-1', title: 'Favorites', trackIds: const ['1', '2']),
    Playlist(id: 'pl-2', title: 'Studio Master', trackIds: const ['3']),
  ];

  final sampleTags = [
    const Tag(id: 't-1', name: 'Audiophile', category: 'quality'),
    const Tag(id: 't-2', name: 'Hi-Res', category: 'quality'),
    const Tag(id: 't-3', name: 'DSD', category: 'format'),
  ];

  testWidgets('LyraSidebar renders all sections in expanded mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildSidebarTest(playlists: samplePlaylists, tags: sampleTags),
    );
    await tester.pumpAndSettle();

    // Section headers
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('PLAYLISTS'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);
    expect(find.text('SYSTEM'), findsOneWidget);

    // Library items
    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('Works'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);

    // Playlists items
    expect(find.text('All Playlists'), findsNothing);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Studio Master'), findsOneWidget);

    // Redundant playlist creation entry points removed from sidebar
    expect(find.text('+ New Playlist'), findsNothing);

    // Tag chips
    expect(find.text('Audiophile'), findsOneWidget);
    expect(find.text('Hi-Res'), findsOneWidget);
    expect(find.text('DSD'), findsOneWidget);

    // System items
    expect(find.text('CAS Storage'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Collapse'), findsOneWidget);
  });

  testWidgets(
    'LyraSidebar PLAYLISTS and TAGS sections are expandable and collapsible',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildSidebarTest(playlists: samplePlaylists, tags: sampleTags),
      );
      await tester.pumpAndSettle();

      // Initially expanded
      expect(find.text('All Playlists'), findsNothing);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Studio Master'), findsOneWidget);
      expect(find.text('Audiophile'), findsOneWidget);
      expect(find.text('Hi-Res'), findsOneWidget);
      expect(find.text('DSD'), findsOneWidget);

      // Collapse PLAYLISTS section by tapping chevron button
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsNothing);
      expect(find.text('Studio Master'), findsNothing);
      // Tags still visible
      expect(find.text('Audiophile'), findsOneWidget);

      // Re-expand PLAYLISTS section
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Studio Master'), findsOneWidget);

      // Collapse TAGS section by tapping header
      await tester.tap(find.text('TAGS'));
      await tester.pumpAndSettle();

      expect(find.text('Audiophile'), findsNothing);
      expect(find.text('Hi-Res'), findsNothing);
      expect(find.text('DSD'), findsNothing);
      // Playlists still visible
      expect(find.text('Favorites'), findsOneWidget);

      // Re-expand TAGS section
      await tester.tap(find.text('TAGS'));
      await tester.pumpAndSettle();

      expect(find.text('Audiophile'), findsOneWidget);
      expect(find.text('Hi-Res'), findsOneWidget);
      expect(find.text('DSD'), findsOneWidget);
    },
  );

  testWidgets('LyraSidebar tab selection triggers onTabSelected callback', (
    tester,
  ) async {
    AppTab? selectedTab;

    await tester.pumpWidget(
      _buildSidebarTest(onTabSelected: (tab) => selectedTab = tab),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Works'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.works));

    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.artists));

    await tester.tap(find.text('PLAYLISTS'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.playlists));
  });

  testWidgets(
    'LyraSidebar PLAYLISTS header title navigates to tab while chevron toggles collapse independently',
    (tester) async {
      AppTab? selectedTab;

      await tester.pumpWidget(
        _buildSidebarTest(
          playlists: samplePlaylists,
          onTabSelected: (tab) => selectedTab = tab,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tapping PLAYLISTS title navigates to AppTab.playlists without collapsing list
      await tester.tap(find.text('PLAYLISTS'));
      await tester.pumpAndSettle();
      expect(selectedTab, equals(AppTab.playlists));
      expect(find.text('Favorites'), findsOneWidget);

      // 2. Tapping chevron toggles collapse without firing onTabSelected
      selectedTab = null;
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();
      expect(selectedTab, isNull);
      expect(find.text('Favorites'), findsNothing);

      // 3. Tapping chevron again re-expands list
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();
      expect(selectedTab, isNull);
      expect(find.text('Favorites'), findsOneWidget);
    },
  );

  testWidgets('LyraSidebar playlist and tag clicks trigger callbacks', (
    tester,
  ) async {
    Playlist? clickedPlaylist;
    Tag? clickedTag;

    await tester.pumpWidget(
      _buildSidebarTest(
        playlists: samplePlaylists,
        tags: sampleTags,
        onPlaylistSelected: (pl) => clickedPlaylist = pl,
        onTagSelected: (t) => clickedTag = t,
      ),
    );
    await tester.pumpAndSettle();

    // Click playlist item
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(clickedPlaylist?.id, equals('pl-1'));

    // Click tag chip
    await tester.tap(find.text('Hi-Res'));
    await tester.pumpAndSettle();
    expect(clickedTag?.name, equals('Hi-Res'));
  });

  testWidgets('LyraSidebar collapse toggle callback triggers on click', (
    tester,
  ) async {
    bool toggleCalled = false;

    await tester.pumpWidget(
      _buildSidebarTest(onToggleCollapse: () => toggleCalled = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Collapse'));
    await tester.pumpAndSettle();
    expect(toggleCalled, isTrue);
  });

  testWidgets(
    'LyraSidebar in collapsed mode has 64px width and centered icons',
    (tester) async {
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: true,
          playlists: samplePlaylists,
          tags: sampleTags,
        ),
      );
      await tester.pumpAndSettle();

      final sidebarFinder = find.byType(LyraSidebar);
      expect(tester.getSize(sidebarFinder).width, 64.0);

      // Text labels should be hidden
      expect(find.text('LIBRARY'), findsNothing);
      expect(find.text('PLAYLISTS'), findsNothing);
      expect(find.text('TAGS'), findsNothing);
      expect(find.text('SYSTEM'), findsNothing);
      expect(find.text('Tracks'), findsNothing);
      expect(find.text('Collapse'), findsNothing);

      // Centered icons check at dx = 31.5
      final musicIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.music),
      );
      expect(tester.getCenter(musicIcon).dx, 31.5);

      final tracksIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.listMusic),
      );
      expect(tester.getCenter(tracksIcon).dx, 31.5);

      final worksIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.layers),
      );
      expect(tester.getCenter(worksIcon).dx, 31.5);

      final albumsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.disc),
      );
      expect(tester.getCenter(albumsIcon).dx, 31.5);

      final artistsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.mic),
      );
      expect(tester.getCenter(artistsIcon).dx, 31.5);

      final playlistsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.listPlus),
      );
      expect(tester.getCenter(playlistsIcon).dx, 31.5);

      final tagIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.tag),
      );
      expect(tester.getCenter(tagIcon).dx, 31.5);

      final casIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.hardDrive),
      );
      expect(tester.getCenter(casIcon).dx, 31.5);

      final settingsIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.settings),
      );
      expect(tester.getCenter(settingsIcon).dx, 31.5);

      final toggleIcon = find.descendant(
        of: sidebarFinder,
        matching: find.byIcon(LucideIcons.chevronRight),
      );
      expect(tester.getCenter(toggleIcon).dx, 31.5);
    },
  );
}
