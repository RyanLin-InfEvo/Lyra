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
  VoidCallback? onTagsHeaderSelected,
  bool defaultPlaylistsExpanded = true,
  bool defaultTagsExpanded = true,
  CasTab selectedCasTab = CasTab.storageOverview,
  ValueChanged<CasTab>? onCasSubTabSelected,
  VoidCallback? onCasHeaderSelected,
  bool defaultCasExpanded = true,
  ThemeMode themeMode = ThemeMode.dark,
  ValueNotifier<ThemeMode>? themeNotifier,
}) {
  final themeModeNotifier =
      themeNotifier ?? ValueNotifier<ThemeMode>(themeMode);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra Test',
    debugShowCheckedModeBanner: false,
    home: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
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
                onTagsHeaderSelected: onTagsHeaderSelected,
                defaultPlaylistsExpanded: defaultPlaylistsExpanded,
                defaultTagsExpanded: defaultTagsExpanded,
                selectedCasTab: selectedCasTab,
                onCasSubTabSelected: onCasSubTabSelected,
                onCasHeaderSelected: onCasHeaderSelected,
                defaultCasExpanded: defaultCasExpanded,
              ),
            ),
          ),
        );
      },
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
    expect(find.text('SYSTEM'), findsOneWidget);

    // Library items
    expect(find.text('Tracks'), findsOneWidget);
    expect(find.text('Works'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);

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
    expect(find.text('Storage Overview'), findsOneWidget);
    expect(find.text('Database Explorer'), findsOneWidget);
    expect(find.text('Engine Settings'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Collapse'), findsNothing);
  });

  testWidgets(
    'LyraSidebar CAS Storage section is expandable, collapsible, and selects sub-tabs cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      CasTab? selectedCasTab;
      AppTab? selectedAppTab;

      await tester.pumpWidget(
        _buildSidebarTest(
          onCasSubTabSelected: (tab) => selectedCasTab = tab,
          onTabSelected: (tab) => selectedAppTab = tab,
        ),
      );
      await tester.pumpAndSettle();

      // Initially expanded
      expect(find.text('Storage Overview'), findsOneWidget);
      expect(find.text('Database Explorer'), findsOneWidget);
      expect(find.text('Engine Settings'), findsOneWidget);

      // Collapse CAS Storage section
      await tester.tap(find.byKey(const Key('cas_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Storage Overview'), findsNothing);
      expect(find.text('Database Explorer'), findsNothing);
      expect(find.text('Engine Settings'), findsNothing);

      // Re-expand CAS Storage section
      await tester.tap(find.byKey(const Key('cas_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Storage Overview'), findsOneWidget);
      expect(find.text('Database Explorer'), findsOneWidget);
      expect(find.text('Engine Settings'), findsOneWidget);

      // Tap Database Explorer sub-item
      await tester.tap(find.text('Database Explorer'));
      await tester.pumpAndSettle();

      expect(selectedCasTab, equals(CasTab.databaseExplorer));
      expect(selectedAppTab, equals(AppTab.casStorage));
    },
  );

  testWidgets(
    'LyraSidebar Playlists and Tags sections are expandable and collapsible',
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

      // Collapse TAGS section by tapping chevron button
      await tester.tap(find.byKey(const Key('tags_header_chevron')));
      await tester.pumpAndSettle();

      expect(find.text('Audiophile'), findsNothing);
      expect(find.text('Hi-Res'), findsNothing);
      expect(find.text('DSD'), findsNothing);
      // Playlists still visible
      expect(find.text('Favorites'), findsOneWidget);

      // Re-expand TAGS section
      await tester.tap(find.byKey(const Key('tags_header_chevron')));
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

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.playlists));

    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(selectedTab, equals(AppTab.tags));
  });

  testWidgets(
    'LyraSidebar Playlists and Tags headers navigate to tab/overview while chevrons toggle collapse independently',
    (tester) async {
      AppTab? selectedTab;
      bool tagsHeaderClicked = false;

      await tester.pumpWidget(
        _buildSidebarTest(
          playlists: samplePlaylists,
          tags: sampleTags,
          onTabSelected: (tab) => selectedTab = tab,
          onTagsHeaderSelected: () => tagsHeaderClicked = true,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tapping Playlists title navigates to AppTab.playlists without collapsing list
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(selectedTab, equals(AppTab.playlists));
      expect(find.text('Favorites'), findsOneWidget);

      // 2. Tapping Playlists chevron toggles collapse without firing onTabSelected
      selectedTab = null;
      await tester.tap(find.byKey(const Key('playlists_header_chevron')));
      await tester.pumpAndSettle();
      expect(selectedTab, isNull);
      expect(find.text('Favorites'), findsNothing);

      // 3. Tapping Tags title calls onTagsHeaderSelected without collapsing tags list
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      expect(tagsHeaderClicked, isTrue);
      expect(find.text('Audiophile'), findsOneWidget);

      // 4. Tapping Tags chevron toggles collapse
      await tester.tap(find.byKey(const Key('tags_header_chevron')));
      await tester.pumpAndSettle();
      expect(find.text('Audiophile'), findsNothing);
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

    // Click tag item
    await tester.tap(find.text('Hi-Res'));
    await tester.pumpAndSettle();
    expect(clickedTag?.name, equals('Hi-Res'));
  });

  testWidgets(
    'LyraSidebar items (Nav, Playlists, Tags) have consistent button sizing and layout',
    (tester) async {
      await tester.pumpWidget(
        _buildSidebarTest(
          playlists: samplePlaylists,
          tags: sampleTags,
          selectedTagId: 't-1',
        ),
      );
      await tester.pumpAndSettle();

      final tracksItem = find.text('Tracks');
      final playlistsItem = find.text('Playlists');
      final tagsItem = find.text('Tags');
      final playlistSubItem = find.text('Favorites');
      final tagSubItem = find.text('Audiophile');

      expect(tracksItem, findsOneWidget);
      expect(playlistsItem, findsOneWidget);
      expect(tagsItem, findsOneWidget);
      expect(playlistSubItem, findsOneWidget);
      expect(tagSubItem, findsOneWidget);

      // All main item texts share 13.0 font size
      final tracksText = tester.widget<Text>(tracksItem);
      final playlistsText = tester.widget<Text>(playlistsItem);
      final tagsText = tester.widget<Text>(tagsItem);

      expect(tracksText.style?.fontSize, equals(13.0));
      expect(playlistsText.style?.fontSize, equals(13.0));
      expect(tagsText.style?.fontSize, equals(13.0));
    },
  );

  testWidgets(
    'LyraSidebar adheres to HIG by not placing collapse toggle at sidebar bottom',
    (tester) async {
      await tester.pumpWidget(_buildSidebarTest());
      await tester.pumpAndSettle();

      expect(find.text('Collapse'), findsNothing);
      expect(find.byIcon(LucideIcons.chevronLeft), findsNothing);
    },
  );

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

      expect(
        find.descendant(
          of: sidebarFinder,
          matching: find.byIcon(LucideIcons.chevronRight),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'LyraSidebar active selection item adapts dynamically between Dark and Light mode in a single frame',
    (tester) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(themeNotifier.dispose);

      await tester.pumpWidget(
        _buildSidebarTest(
          currentTab: AppTab.tracks,
          themeNotifier: themeNotifier,
        ),
      );
      await tester.pump();

      // 1. Dark Mode: Inner Sidebar container background is zinc900 (tokens.card), active item text is zinc50
      final darkInnerContainer = tester.widget<Container>(
        find.byKey(const Key('sidebar_inner_container')),
      );
      final darkDecoration = darkInnerContainer.decoration as BoxDecoration;
      expect(darkDecoration.color, equals(LyraColors.zinc900));

      final activeTextDark = tester.widget<Text>(find.text('Tracks'));
      expect(activeTextDark.style?.color, equals(LyraColors.zinc50));

      // Switch to Light Mode (single frame 0ms)
      themeNotifier.value = ThemeMode.light;
      await tester.pump();

      // 2. Light Mode: Sidebar background is white (Color(0xFFFFFFFF)), active item text is zinc950
      final lightInnerContainer = tester.widget<Container>(
        find.byKey(const Key('sidebar_inner_container')),
      );
      final lightDecoration = lightInnerContainer.decoration as BoxDecoration;
      expect(lightDecoration.color, equals(const Color(0xFFFFFFFF)));

      final activeTextLight = tester.widget<Text>(find.text('Tracks'));
      expect(activeTextLight.style?.color, equals(LyraColors.zinc950));
    },
  );

  testWidgets(
    'LyraSidebar AnimatedContainer uses easeInOutCubic curve with left-aligned text in expanded mode',
    (tester) async {
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: false));
      await tester.pumpAndSettle();

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(animatedContainer.curve, equals(Curves.easeInOutCubic));
      expect(
        animatedContainer.duration,
        equals(const Duration(milliseconds: 200)),
      );

      // In expanded mode, tracks icon is left-aligned at x = 24.0 and label is left-aligned at x = 40.0
      final tracksIconExpanded = find.byIcon(LucideIcons.listMusic);
      expect(tester.getCenter(tracksIconExpanded).dx, equals(24.0));
      expect(tester.getTopLeft(find.text('Tracks')).dx, equals(40.0));

      // Rebuild in collapsed mode
      await tester.pumpWidget(_buildSidebarTest(isCollapsed: true));
      await tester.pumpAndSettle();

      // In collapsed mode, tracks icon is centered at x = 31.5 and text is hidden
      final tracksIconCollapsed = find.byIcon(LucideIcons.listMusic);
      expect(tester.getCenter(tracksIconCollapsed).dx, equals(31.5));
      expect(find.text('Tracks'), findsNothing);
    },
  );

  testWidgets(
    'LyraSidebar expanding from collapsed does not trigger RenderFlex overflow at intermediate widths',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: true,
          playlists: samplePlaylists,
          tags: sampleTags,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to expanded mode and pump through intermediate frames
      await tester.pumpWidget(
        _buildSidebarTest(
          isCollapsed: false,
          playlists: samplePlaylists,
          tags: sampleTags,
        ),
      );
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
