// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_button.dart';
import 'package:ui/design_system/widgets/lyra_dialog.dart';
import 'package:ui/features/models/tag.dart';
import 'package:ui/features/tags/tags_view.dart';

Widget _buildTagsViewTest({
  List<Tag> tags = const [],
  Map<String, int> tagTrackCounts = const {},
  ValueChanged<Tag>? onTagSelected,
  CreateTagCallback? onCreateTag,
  ValueChanged<Tag>? onDeleteTag,
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
              body: TagsView(
                tags: tags,
                tagTrackCounts: tagTrackCounts,
                onTagSelected: onTagSelected,
                onCreateTag: onCreateTag,
                onDeleteTag: onDeleteTag,
              ),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  final sampleTags = [
    const Tag(id: 'tag-1', name: 'Audiophile Master', category: 'quality'),
    const Tag(id: 'tag-2', name: 'Hi-Res 24/192', category: 'quality'),
    const Tag(id: 'tag-3', name: 'Modern Jazz', category: 'genre'),
    const Tag(id: 'tag-4', name: 'Direct Stream DSD', category: 'format'),
  ];

  final sampleCounts = {'tag-1': 4, 'tag-2': 3, 'tag-3': 2, 'tag-4': 1};

  testWidgets('TagsView renders empty state when tags list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTagsViewTest(
        tags: const [],
        onCreateTag: ({required name, required category}) async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tags created yet'), findsOneWidget);
    expect(
      find.text('Create tags to organize and categorize audio tracks.'),
      findsOneWidget,
    );
    expect(find.text('Create Tag'), findsOneWidget);

    // Open create dialog from empty state
    await tester.tap(find.text('Create Tag'));
    await tester.pumpAndSettle();

    expect(find.text('TAG NAME'), findsOneWidget);
  });

  testWidgets(
    'TagsView renders all tags with category badges and track counts',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTagsViewTest(tags: sampleTags, tagTrackCounts: sampleCounts),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('4 categorization labels'), findsOneWidget);

      // Tag names
      expect(find.text('Audiophile Master'), findsOneWidget);
      expect(find.text('Hi-Res 24/192'), findsOneWidget);
      expect(find.text('Modern Jazz'), findsOneWidget);
      expect(find.text('Direct Stream DSD'), findsOneWidget);

      // Category badges
      expect(find.text('QUALITY'), findsWidgets);
      expect(find.text('GENRE'), findsOneWidget);
      expect(find.text('FORMAT'), findsOneWidget);

      // Track counts
      expect(find.text('4 tracks'), findsOneWidget);
      expect(find.text('3 tracks'), findsOneWidget);
      expect(find.text('2 tracks'), findsOneWidget);
      expect(find.text('1 track'), findsOneWidget);
    },
  );

  testWidgets('TagsView filters tags via search input in real-time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTagsViewTest(tags: sampleTags, tagTrackCounts: sampleCounts),
    );
    await tester.pumpAndSettle();

    // Enter search keyword
    final searchInput = find.byType(EditableText).first;
    await tester.enterText(searchInput, 'Jazz');
    await tester.pumpAndSettle();

    expect(find.text('Modern Jazz'), findsOneWidget);
    expect(find.text('Audiophile Master'), findsNothing);
    expect(find.text('Hi-Res 24/192'), findsNothing);

    // Search keyword yielding no results
    await tester.enterText(searchInput, 'NonExistentKeyword');
    await tester.pumpAndSettle();

    expect(find.text('No matching tags found'), findsOneWidget);
    expect(
      find.text('Try a different search keyword or category filter.'),
      findsOneWidget,
    );
  });

  testWidgets('TagsView category filter chips filter tags correctly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTagsViewTest(tags: sampleTags, tagTrackCounts: sampleCounts),
    );
    await tester.pumpAndSettle();

    // Tap 'Quality' pill
    await tester.tap(find.text('Quality (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Audiophile Master'), findsOneWidget);
    expect(find.text('Hi-Res 24/192'), findsOneWidget);
    expect(find.text('Modern Jazz'), findsNothing);
    expect(find.text('Direct Stream DSD'), findsNothing);

    // Tap 'All' pill
    await tester.tap(find.text('All (4)'));
    await tester.pumpAndSettle();

    expect(find.text('Modern Jazz'), findsOneWidget);
    expect(find.text('Direct Stream DSD'), findsOneWidget);
  });

  testWidgets('TagsView onTagSelected fires when tag card is tapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Tag? selectedTag;

    await tester.pumpWidget(
      _buildTagsViewTest(
        tags: sampleTags,
        tagTrackCounts: sampleCounts,
        onTagSelected: (t) => selectedTag = t,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modern Jazz'));
    await tester.pumpAndSettle();

    expect(selectedTag?.id, equals('tag-3'));
    expect(selectedTag?.name, equals('Modern Jazz'));
  });

  testWidgets('TagsView creates a new tag via modal dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    String? createdName;
    String? createdCategory;

    await tester.pumpWidget(
      _buildTagsViewTest(
        tags: sampleTags,
        tagTrackCounts: sampleCounts,
        onCreateTag: ({required name, required category}) async {
          createdName = name;
          createdCategory = category;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Click 'New Tag' button
    await tester.tap(find.text('New Tag'));
    await tester.pumpAndSettle();

    expect(find.text('Create Tag'), findsWidgets);
    expect(find.text('TAG NAME'), findsOneWidget);
    expect(find.text('CATEGORY'), findsOneWidget);

    // Enter tag name in modal
    final nameInput = find.byType(EditableText).last;
    await tester.enterText(nameInput, 'Reference Acoustics');
    await tester.pumpAndSettle();

    // Select category 'Quality'
    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();

    // Click submit 'Create Tag' button in modal actions
    final submitButton = find.descendant(
      of: find.byType(LyraButton),
      matching: find.text('Create Tag'),
    );
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(createdName, equals('Reference Acoustics'));
    expect(createdCategory, equals('quality'));
  });

  testWidgets('TagsView deletes tag with confirmation dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Tag? deletedTag;

    await tester.pumpWidget(
      _buildTagsViewTest(
        tags: sampleTags,
        tagTrackCounts: sampleCounts,
        onDeleteTag: (t) => deletedTag = t,
      ),
    );
    await tester.pumpAndSettle();

    // Click trash icon on first tag
    final trashIcons = find.byIcon(LucideIcons.trash2);
    expect(trashIcons, findsWidgets);
    await tester.tap(trashIcons.first);
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Delete Tag'), findsOneWidget);
    expect(
      find.text(
        'Are you sure you want to delete "Audiophile Master"? This will remove this tag from all assigned tracks.',
      ),
      findsOneWidget,
    );

    // Click 'Delete' button
    final deleteConfirmBtn = find.descendant(
      of: find.byType(LyraDialog),
      matching: find.text('Delete'),
    );
    await tester.tap(deleteConfirmBtn);
    await tester.pumpAndSettle();

    expect(deletedTag?.id, equals('tag-1'));
  });

  testWidgets(
    'TagsView square cards and dialogs adapt dynamically to Light and Dark mode',
    (tester) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(themeNotifier.dispose);

      await tester.pumpWidget(
        _buildTagsViewTest(
          tags: sampleTags,
          tagTrackCounts: sampleCounts,
          themeNotifier: themeNotifier,
        ),
      );
      await tester.pump();

      // 1. Dark Mode: ShadTheme card is dark
      final tagsElementDark = find.byType(TagsView).evaluate().first;
      final themeDark = ShadTheme.of(tagsElementDark);
      expect(themeDark.brightness, equals(Brightness.dark));
      expect(
        themeDark.colorScheme.card,
        equals(const ShadZincColorScheme.dark().card),
      );

      // Switch to Light Mode (single frame 0ms)
      themeNotifier.value = ThemeMode.light;
      await tester.pump();

      // 2. Light Mode: ShadTheme card is light
      final tagsElementLight = find.byType(TagsView).evaluate().first;
      final themeLight = ShadTheme.of(tagsElementLight);
      expect(themeLight.brightness, equals(Brightness.light));
      expect(
        themeLight.colorScheme.card,
        equals(const ShadZincColorScheme.light().card),
      );
    },
  );
}
