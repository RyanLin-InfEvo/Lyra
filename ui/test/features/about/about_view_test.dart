// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ui/design_system/factory/lyra_design_system_scope.dart';
import 'package:ui/design_system/factory/shadcn_factory.dart';
import 'package:ui/design_system/tokens/lyra_tokens.dart';
import 'package:ui/design_system/widgets/lyra_brand_logo.dart';
import 'package:ui/design_system/widgets/lyra_copy_button.dart';
import 'package:ui/design_system/widgets/lyra_tooltip.dart';
import 'package:ui/features/about/about_view.dart';
import 'package:ui/features/about/lyra_licenses.dart';
import 'package:ui/features/shell/sidebar.dart';

Widget _wrapWithScope({
  required Widget child,
  ThemeMode initialTheme = ThemeMode.dark,
  bool disableAnimations = false,
}) {
  final themeModeNotifier = ValueNotifier<ThemeMode>(initialTheme);
  const factory = ShadcnFactory();

  return ShadApp(
    title: 'Lyra About Test',
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: ValueListenableBuilder<ThemeMode>(
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
                  child: Scaffold(body: child),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

void main() {
  group('LyraBrandLogo', () {
    testWidgets(
      'renders mini/animated modes, supports onTap, and disposes mid-animation',
      (tester) async {
        final key = GlobalKey<LyraBrandLogoState>();
        var tapCount = 0;

        await tester.pumpWidget(
          _wrapWithScope(
            child: Column(
              children: [
                const LyraBrandLogo(size: 24.0),
                LyraBrandLogo(
                  key: key,
                  size: 112.0,
                  animated: true,
                  onTap: () => tapCount++,
                ),
              ],
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.byKey(key));
        expect(tapCount, 1);

        expect(find.bySemanticsLabel('Lyra logo'), findsNWidgets(2));

        // Trigger replay and unmount mid-animation to verify ticker disposal.
        key.currentState?.replay();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpWidget(_wrapWithScope(child: const SizedBox.shrink()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('respects disableAnimations in init and replay()', (
      tester,
    ) async {
      final key = GlobalKey<LyraBrandLogoState>();

      await tester.pumpWidget(
        _wrapWithScope(
          disableAnimations: true,
          child: LyraBrandLogo(key: key, size: 112.0, animated: true),
        ),
      );

      // Should settle immediately to 1.0 without running the 940ms timeline.
      expect(key.currentState!.animationProgress, 1.0);
      key.currentState?.replay();
      await tester.pump();
      expect(key.currentState!.animationProgress, 1.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('registerLyraLicenses', () {
    testWidgets('registers Lyra AGPL and C++ Core dependency licenses once', (
      tester,
    ) async {
      await tester.runAsync(() async {
        LicenseRegistry.reset();
        resetLyraLicensesForTesting();

        registerLyraLicenses();
        // Calling twice must remain idempotent without adding duplicate entries.
        registerLyraLicenses();

        final packageCounts = <String, int>{};
        final packageBodies = <String, String>{};
        await for (final entry in LicenseRegistry.licenses) {
          final body = entry.paragraphs.map((p) => p.text).join('\n');
          for (final pkg in entry.packages) {
            packageCounts[pkg] = (packageCounts[pkg] ?? 0) + 1;
            packageBodies[pkg] = body;
          }
        }

        const expectedPackages = <String>[
          'Lyra',
          'miniaudio (C++ Core)',
          'nlohmann_json (C++ Core)',
          'fmt (C++ Core)',
          'SQLiteCpp (C++ Core)',
          'stduuid (C++ Core)',
          'tl-expected (C++ Core)',
          'FFmpeg (C++ Core)',
          'SQLite (C++ Core)',
        ];

        for (final pkg in expectedPackages) {
          expect(packageCounts[pkg], 1, reason: '$pkg should appear once');
        }

        expect(
          packageBodies['Lyra'],
          contains('GNU AFFERO GENERAL PUBLIC LICENSE'),
        );
        expect(
          packageBodies['tl-expected (C++ Core)'],
          contains('CC0 1.0 Universal'),
        );
        expect(
          packageBodies['miniaudio (C++ Core)'],
          contains('miniaudio - v0.11.25'),
        );
        expect(
          packageBodies['nlohmann_json (C++ Core)'],
          contains('2013 - 2025 Niels Lohmann'),
        );
        expect(
          packageBodies['SQLiteCpp (C++ Core)'],
          contains('2012-2025 Sebastien Rombauts'),
        );
      });
    });
  });

  group('AboutView', () {
    testWidgets(
      'renders updated copy, tooltips, tap-to-replay logo, banner, copy URL, and themed licenses',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copiedText = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await tester.pumpWidget(
          _wrapWithScope(
            child: const AboutView(),
            initialTheme: ThemeMode.dark,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('About'), findsOneWidget);
        expect(find.text('Lyra'), findsOneWidget);
        expect(find.text('The Ultimate Music Hub'), findsOneWidget);
        expect(find.text('Replay Animation'), findsNothing);
        expect(find.text('Storage Model'), findsNothing);

        expect(find.text('Version'), findsOneWidget);
        expect(find.text('UI v0.0.1 · Core —'), findsOneWidget);
        expect(find.text('Architecture'), findsOneWidget);
        expect(find.text('C++20 Core · Flutter UI'), findsOneWidget);
        expect(find.text('AGPL-3.0-or-later'), findsOneWidget);
        expect(find.text('github.com/RyanLin-InfEvo/Lyra'), findsOneWidget);

        expect(
          find.byWidgetPredicate(
            (w) => w is LyraTooltip && w.message == 'Try to click me!',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is LyraTooltip && w.message == 'Copy repository URL',
          ),
          findsOneWidget,
        );

        expect(find.byType(LyraBrandLogo), findsOneWidget);
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey('assets/visual-designs/lyra-dark-banner.svg'),
          ),
          findsOneWidget,
        );

        // Tap brand logo to replay animation
        final logoFinder = find.byType(LyraBrandLogo);
        await tester.tap(logoFinder);
        await tester.pump(const Duration(milliseconds: 100));
        final logoState = tester.state<LyraBrandLogoState>(logoFinder);
        expect(logoState.animationProgress, lessThan(1.0));
        await tester.pumpAndSettle();
        expect(logoState.animationProgress, 1.0);

        // Copy repository URL button
        final copyButton = find.byType(LyraCopyButton);
        await tester.ensureVisible(copyButton);
        await tester.tap(copyButton);
        await tester.pump();
        expect(copiedText, 'https://github.com/RyanLin-InfEvo/Lyra');

        // Licenses button opens themed LicensePage and lists registered entries
        final licensesButton = find.text('Licenses');
        await tester.ensureVisible(licensesButton);
        await tester.tap(licensesButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        final licensePageFinder = find.byType(LicensePage);
        expect(licensePageFinder, findsOneWidget);
        expect(
          Theme.of(tester.element(licensePageFinder)).brightness,
          Brightness.dark,
        );
        expect(find.text('UI v0.0.1 · Core —'), findsOneWidget);
        expect(find.text('miniaudio (C++ Core)'), findsOneWidget);
      },
    );

    testWidgets('uses light banner in light mode and stacks at compact width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithScope(child: const AboutView(), initialTheme: ThemeMode.light),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('assets/visual-designs/lyra-light-banner.svg'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('assets/visual-designs/lyra-dark-banner.svg'),
        ),
        findsNothing,
      );

      // Verify Hero card stacks logo vertically above title at compact width
      final logoRect = tester.getRect(find.byType(LyraBrandLogo));
      final titleRect = tester.getRect(find.text('Lyra'));
      expect(logoRect.bottom, lessThan(titleRect.top));

      // Verify _InfoRow stacks label vertically above value at compact width
      final versionLabelRect = tester.getRect(find.text('Version'));
      final versionValueRect = tester.getRect(find.text('UI v0.0.1 · Core —'));
      expect(versionLabelRect.bottom, lessThanOrEqualTo(versionValueRect.top));
    });
  });

  group('LyraSidebar About tab', () {
    testWidgets(
      'displays About item and triggers onTabSelected(AppTab.about)',
      (tester) async {
        AppTab? selected;
        await tester.pumpWidget(
          _wrapWithScope(
            child: LyraSidebar(
              currentTab: AppTab.tracks,
              isCollapsed: false,
              onTabSelected: (tab) => selected = tab,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final aboutFinder = find.text('About');
        expect(aboutFinder, findsOneWidget);
        await tester.ensureVisible(aboutFinder);
        await tester.tap(aboutFinder);
        await tester.pumpAndSettle();

        expect(selected, AppTab.about);
      },
    );
  });
}
