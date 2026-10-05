// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_settings_layout.dart';

enum TestNavSection { general, audio, advanced }

Widget _buildSettingsLayoutTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  final isDark = themeMode == ThemeMode.dark;
  final tokens = isDark ? LyraThemeTokens.dark() : LyraThemeTokens.light();
  final shadTheme = ShadThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: isDark
        ? const ShadZincColorScheme.dark()
        : const ShadZincColorScheme.light(),
  );

  return ShadApp(
    title: 'LyraSettingsLayout Test',
    debugShowCheckedModeBanner: false,
    home: ShadTheme(
      data: shadTheme,
      child: LyraDesignSystemScope(
        factory: const ShadcnFactory(),
        tokens: tokens,
        themeModeNotifier: ValueNotifier(themeMode),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LyraSettingsLayout Component Tests', () {
    testWidgets('Renders title, subtitle, and headerAction when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSettingsLayoutTestApp(
          child: LyraSettingsLayout<TestNavSection>(
            title: 'Application Settings',
            subtitle: 'Manage your preferences and engine policies',
            headerAction: const Text('Header Action'),
            selectedSection: TestNavSection.general,
            onSectionChanged: (_) {},
            sections: [
              LyraSettingsSection<TestNavSection>(
                id: TestNavSection.general,
                label: 'General',
                icon: LucideIcons.settings,
                builder: (context) => const Text('General Content'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Application Settings'), findsOneWidget);
      expect(
        find.text('Manage your preferences and engine policies'),
        findsOneWidget,
      );
      expect(find.text('Header Action'), findsOneWidget);
      expect(find.text('General Content'), findsOneWidget);
    });

    testWidgets(
      'Omits header row and divider when title, subtitle, and action are null',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsLayoutTestApp(
            child: LyraSettingsLayout<TestNavSection>(
              selectedSection: TestNavSection.general,
              onSectionChanged: (_) {},
              sections: [
                LyraSettingsSection<TestNavSection>(
                  id: TestNavSection.general,
                  label: 'General',
                  icon: LucideIcons.settings,
                  builder: (context) => const Text('General Detail Area'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('General Detail Area'), findsOneWidget);
        expect(find.text('General'), findsOneWidget);
        // No header text widgets found
        expect(find.text('Application Settings'), findsNothing);
      },
    );

    testWidgets(
      'Renders all sidebar sections and switches detail content on tap',
      (tester) async {
        TestNavSection current = TestNavSection.general;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return _buildSettingsLayoutTestApp(
                child: LyraSettingsLayout<TestNavSection>(
                  title: 'Settings',
                  selectedSection: current,
                  onSectionChanged: (s) => setState(() => current = s),
                  sections: [
                    LyraSettingsSection<TestNavSection>(
                      id: TestNavSection.general,
                      label: 'General',
                      icon: LucideIcons.settings,
                      builder: (context) => const Text('General Panel'),
                    ),
                    LyraSettingsSection<TestNavSection>(
                      id: TestNavSection.audio,
                      label: 'Audio Hardware',
                      icon: LucideIcons.volume2,
                      builder: (context) => const Text('Audio Panel'),
                    ),
                    LyraSettingsSection<TestNavSection>(
                      id: TestNavSection.advanced,
                      label: 'Advanced',
                      icon: LucideIcons.cpu,
                      builder: (context) => const Text('Advanced Panel'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // All sections rendered in sidebar
        expect(find.text('General'), findsOneWidget);
        expect(find.text('Audio Hardware'), findsOneWidget);
        expect(find.text('Advanced'), findsOneWidget);

        // Initially general panel is active
        expect(find.text('General Panel'), findsOneWidget);
        expect(find.text('Audio Panel'), findsNothing);

        // Tap Audio Hardware
        await tester.tap(find.text('Audio Hardware'));
        await tester.pumpAndSettle();

        expect(current, equals(TestNavSection.audio));
        expect(find.text('General Panel'), findsNothing);
        expect(find.text('Audio Panel'), findsOneWidget);

        // Tap Advanced
        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();

        expect(current, equals(TestNavSection.advanced));
        expect(find.text('Audio Panel'), findsNothing);
        expect(find.text('Advanced Panel'), findsOneWidget);
      },
    );

    testWidgets(
      'Active section displays FontWeight.w600 and inactive displays normal weight',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsLayoutTestApp(
            child: LyraSettingsLayout<TestNavSection>(
              selectedSection: TestNavSection.general,
              onSectionChanged: (_) {},
              sections: [
                LyraSettingsSection<TestNavSection>(
                  id: TestNavSection.general,
                  label: 'General',
                  icon: LucideIcons.settings,
                  builder: (context) => const SizedBox(),
                ),
                LyraSettingsSection<TestNavSection>(
                  id: TestNavSection.audio,
                  label: 'Audio Hardware',
                  icon: LucideIcons.volume2,
                  builder: (context) => const SizedBox(),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final generalText = tester.widget<Text>(find.text('General'));
        final audioText = tester.widget<Text>(find.text('Audio Hardware'));

        expect(generalText.style?.fontWeight, equals(FontWeight.w600));
        expect(audioText.style?.fontWeight, equals(FontWeight.normal));
      },
    );

    testWidgets('Renders sticky bottomBar slot when provided', (tester) async {
      await tester.pumpWidget(
        _buildSettingsLayoutTestApp(
          child: LyraSettingsLayout<TestNavSection>(
            selectedSection: TestNavSection.general,
            onSectionChanged: (_) {},
            bottomBar: Container(
              height: 48.0,
              color: Colors.amber,
              child: const Text('Sticky Action Bar'),
            ),
            sections: [
              LyraSettingsSection<TestNavSection>(
                id: TestNavSection.general,
                label: 'General',
                icon: LucideIcons.settings,
                builder: (context) => const Text('Main Detail Content'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sticky Action Bar'), findsOneWidget);
      expect(find.text('Main Detail Content'), findsOneWidget);
    });

    testWidgets('Custom sidebarWidth is respected by the sidebar container', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSettingsLayoutTestApp(
          child: LyraSettingsLayout<TestNavSection>(
            sidebarWidth: 260.0,
            selectedSection: TestNavSection.general,
            onSectionChanged: (_) {},
            sections: [
              LyraSettingsSection<TestNavSection>(
                id: TestNavSection.general,
                label: 'General',
                icon: LucideIcons.settings,
                builder: (context) => const SizedBox(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sidebarContainers = tester.widgetList<Container>(
        find.ancestor(
          of: find.text('General'),
          matching: find.byType(Container),
        ),
      );

      final hasWidth260 = sidebarContainers.any(
        (c) => c.constraints?.maxWidth == 260.0,
      );
      expect(hasWidth260, isTrue);
    });

    testWidgets('Applies contentMaxWidth constraint to detail content area', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSettingsLayoutTestApp(
          child: LyraSettingsLayout<TestNavSection>(
            contentMaxWidth: 720.0,
            selectedSection: TestNavSection.general,
            onSectionChanged: (_) {},
            sections: [
              LyraSettingsSection<TestNavSection>(
                id: TestNavSection.general,
                label: 'General',
                icon: LucideIcons.settings,
                builder: (context) => const Text('Constrained Content'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final has720Constraint = constrainedBoxes.any(
        (cb) => cb.constraints.maxWidth == 720.0,
      );
      expect(has720Constraint, isTrue);
    });

    testWidgets('Renders section badge and description when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSettingsLayoutTestApp(
          child: LyraSettingsLayout<TestNavSection>(
            selectedSection: TestNavSection.general,
            onSectionChanged: (_) {},
            sections: [
              LyraSettingsSection<TestNavSection>(
                id: TestNavSection.general,
                label: 'Ingestion Pipeline',
                description: '16 CPU Cores detected',
                badge: const Text('Beta'),
                icon: LucideIcons.cpu,
                builder: (context) => const SizedBox(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ingestion Pipeline'), findsOneWidget);
      expect(find.text('16 CPU Cores detected'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets(
      'Renders cleanly without overflow in both Dark and Light themes',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        for (final themeMode in [ThemeMode.dark, ThemeMode.light]) {
          await tester.pumpWidget(
            _buildSettingsLayoutTestApp(
              themeMode: themeMode,
              child: LyraSettingsLayout<TestNavSection>(
                title: 'Settings',
                subtitle: 'Theme adaptability verification',
                bottomBar: const Text('Bottom Actions'),
                selectedSection: TestNavSection.general,
                onSectionChanged: (_) {},
                sections: [
                  LyraSettingsSection<TestNavSection>(
                    id: TestNavSection.general,
                    label: 'General',
                    icon: LucideIcons.settings,
                    builder: (context) => const Text('General Content'),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Settings'), findsOneWidget);
          expect(find.text('General Content'), findsOneWidget);
        }
      },
    );

    testWidgets('Renders safely under unbounded vertical height constraints', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSettingsLayoutTestApp(
          child: SingleChildScrollView(
            child: LyraSettingsLayout<TestNavSection>(
              title: 'Unbounded Test',
              bottomBar: const Text('Unbounded Bottom Bar'),
              selectedSection: TestNavSection.general,
              onSectionChanged: (_) {},
              sections: [
                LyraSettingsSection<TestNavSection>(
                  id: TestNavSection.general,
                  label: 'General',
                  icon: LucideIcons.settings,
                  builder: (context) =>
                      const SizedBox(height: 500, child: Text('Tall Content')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tall Content'), findsOneWidget);
      expect(find.text('Unbounded Bottom Bar'), findsOneWidget);
    });

    testWidgets(
      'Gracefully handles empty sections without throwing Bad state: No element',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsLayoutTestApp(
            child: LyraSettingsLayout<TestNavSection>(
              selectedSection: TestNavSection.general,
              onSectionChanged: (_) {},
              sections: const [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Gracefully handles empty sections with header under unbounded vertical height',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsLayoutTestApp(
            child: SingleChildScrollView(
              child: LyraSettingsLayout<TestNavSection>(
                title: 'Empty Settings',
                selectedSection: TestNavSection.general,
                onSectionChanged: (_) {},
                sections: const [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SingleChildScrollView uses PageStorageKey with activeSection.id for scroll isolation',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsLayoutTestApp(
            child: LyraSettingsLayout<TestNavSection>(
              selectedSection: TestNavSection.general,
              onSectionChanged: (_) {},
              sections: [
                LyraSettingsSection<TestNavSection>(
                  id: TestNavSection.general,
                  label: 'General',
                  icon: LucideIcons.settings,
                  builder: (context) => const Text('General Content'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollViewFinder = find.byType(SingleChildScrollView);
        expect(scrollViewFinder, findsOneWidget);
        final scrollView = tester.widget<SingleChildScrollView>(
          scrollViewFinder,
        );
        expect(
          scrollView.key,
          equals(const PageStorageKey<TestNavSection>(TestNavSection.general)),
        );
      },
    );

    testWidgets(
      'Eliminates magic 120px padding and places bottomBar in a Column layout',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsLayoutTestApp(
            child: LyraSettingsLayout<TestNavSection>(
              selectedSection: TestNavSection.general,
              onSectionChanged: (_) {},
              bottomBar: const Text('Bottom Actions Bar'),
              sections: [
                LyraSettingsSection<TestNavSection>(
                  id: TestNavSection.general,
                  label: 'General',
                  icon: LucideIcons.settings,
                  builder: (context) => const Text('General Content'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollViewFinder = find.byType(SingleChildScrollView);
        final scrollView = tester.widget<SingleChildScrollView>(
          scrollViewFinder,
        );
        final padding = scrollView.padding as EdgeInsets;

        // Magic 120.0 padding must be eliminated
        expect(padding.bottom, isNot(equals(120.0)));
        expect(padding.bottom, equals(LyraSpacing.xl));

        // bottomBar is in a Column alongside Expanded(SingleChildScrollView)
        final stackFinder = find.descendant(
          of: find.byType(LyraSettingsLayout<TestNavSection>),
          matching: find.byType(Stack),
        );
        expect(stackFinder, findsNothing);
      },
    );

    testWidgets(
      'Navigation items support focus ring, semantics, and keyboard activation via Enter/Space',
      (tester) async {
        TestNavSection? selected;

        await tester.pumpWidget(
          _buildSettingsLayoutTestApp(
            child: LyraSettingsLayout<TestNavSection>(
              selectedSection: TestNavSection.general,
              onSectionChanged: (s) => selected = s,
              sections: [
                LyraSettingsSection<TestNavSection>(
                  id: TestNavSection.general,
                  label: 'General',
                  icon: LucideIcons.settings,
                  builder: (context) => const Text('General Content'),
                ),
                LyraSettingsSection<TestNavSection>(
                  id: TestNavSection.audio,
                  label: 'Audio Hardware',
                  icon: LucideIcons.volume2,
                  builder: (context) => const Text('Audio Content'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must have FocusableActionDetector
        final fadFinder = find.byType(FocusableActionDetector);
        expect(fadFinder, findsNWidgets(2));

        // Focus the second item
        final secondFad = fadFinder.at(1);
        final secondFadWidget = tester.widget<FocusableActionDetector>(
          secondFad,
        );
        secondFadWidget.focusNode?.requestFocus();
        await tester.pumpAndSettle();

        // Activate via Enter key
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(selected, equals(TestNavSection.audio));

        // Semantics verification
        expect(
          tester.getSemantics(find.text('Audio Hardware')),
          matchesSemantics(
            isButton: true,
            isFocused: true,
            isFocusable: true,
            hasSelectedState: true,
            hasTapAction: true,
            hasFocusAction: true,
            label: 'Audio Hardware',
          ),
        );
      },
    );

    testWidgets(
      'Light Theme: sidebar nav items preserve RGB channels during hover transitions without dark gray flash',
      (tester) async {
        final lightTokens = LyraThemeTokens.light();
        TestNavSection current = TestNavSection.general;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return _buildSettingsLayoutTestApp(
                themeMode: ThemeMode.light,
                child: LyraSettingsLayout<TestNavSection>(
                  selectedSection: current,
                  onSectionChanged: (s) => setState(() => current = s),
                  sections: [
                    LyraSettingsSection<TestNavSection>(
                      id: TestNavSection.general,
                      label: 'General',
                      icon: LucideIcons.settings,
                      builder: (context) => const SizedBox(),
                    ),
                    LyraSettingsSection<TestNavSection>(
                      id: TestNavSection.audio,
                      label: 'Audio Hardware',
                      icon: LucideIcons.volume2,
                      builder: (context) => const SizedBox(),
                    ),
                    LyraSettingsSection<TestNavSection>(
                      id: TestNavSection.advanced,
                      label: 'Advanced',
                      icon: LucideIcons.cpu,
                      builder: (context) => const SizedBox(),
                    ),
                  ],
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        BoxDecoration getActiveItemDecoration(String label) {
          final itemFinder = find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          );
          final decoratedBoxFinder = find.descendant(
            of: itemFinder,
            matching: find.byType(DecoratedBox),
          );
          return tester
                  .widget<DecoratedBox>(decoratedBoxFinder.first)
                  .decoration
              as BoxDecoration;
        }

        BoxDecoration getTargetItemDecoration(String label) {
          final itemFinder = find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          );
          return tester.widget<AnimatedContainer>(itemFinder).decoration
              as BoxDecoration;
        }

        // 1. Verify unhovered, unselected nav item preserves secondary RGB with alpha 0.0
        final initialAudioDeco = getTargetItemDecoration('Audio Hardware');
        expect(
          initialAudioDeco.color,
          equals(lightTokens.secondary.withValues(alpha: 0.0)),
        );
        expect(
          initialAudioDeco.border,
          equals(lightTokens.unfocusedRingBorder(width: 1.5)),
        );

        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() {
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic;
        });

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await tester.pump();

        // 2. Hover over item 1 ('Audio Hardware') and settle
        await gesture.moveTo(tester.getCenter(find.text('Audio Hardware')));
        await tester.pumpAndSettle();

        final hoveredAudioDeco = getTargetItemDecoration('Audio Hardware');
        expect(
          hoveredAudioDeco.color,
          equals(lightTokens.secondary.withValues(alpha: 0.5)),
        );

        // 3. Move hover from item 1 ('Audio Hardware') to item 2 ('Advanced')
        await gesture.moveTo(tester.getCenter(find.text('Advanced')));
        await tester.pump(); // Register pointer exit/enter

        // 4. Pump halfway through the 150ms transition (75ms)
        await tester.pump(const Duration(milliseconds: 75));

        // 5. Inspect active mid-transition decorations
        final midAudioDeco = getActiveItemDecoration('Audio Hardware');
        final midAdvancedDeco = getActiveItemDecoration('Advanced');

        final midAudioColor = midAudioDeco.color!;
        final midAdvancedColor = midAdvancedDeco.color!;

        // Preserves the RGB channels matching tokens.secondary (within 0.01 tolerance) with NO dark gray dip
        expect(
          (midAudioColor.r - lightTokens.secondary.r).abs(),
          lessThan(0.01),
          reason:
              'Audio Hardware RGB channels dipped to dark-gray during transition (r=${midAudioColor.r}, expected ~${lightTokens.secondary.r})',
        );
        expect(
          (midAudioColor.g - lightTokens.secondary.g).abs(),
          lessThan(0.01),
        );
        expect(
          (midAudioColor.b - lightTokens.secondary.b).abs(),
          lessThan(0.01),
        );

        expect(
          (midAdvancedColor.r - lightTokens.secondary.r).abs(),
          lessThan(0.01),
          reason:
              'Advanced RGB channels dipped to dark-gray during transition (r=${midAdvancedColor.r}, expected ~${lightTokens.secondary.r})',
        );
        expect(
          (midAdvancedColor.g - lightTokens.secondary.g).abs(),
          lessThan(0.01),
        );
        expect(
          (midAdvancedColor.b - lightTokens.secondary.b).abs(),
          lessThan(0.01),
        );
      },
    );
  });
}
