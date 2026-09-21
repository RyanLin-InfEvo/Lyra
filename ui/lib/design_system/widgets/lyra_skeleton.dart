// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../factory/lyra_design_system_scope.dart';
import '../factory/shadcn_factory.dart';

/// Facade skeleton placeholder loader widget delegating to the active Design System Factory.
class LyraSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;

  const LyraSkeleton({super.key, this.width, this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final factory =
        LyraDesignSystemScope.maybeOf(context)?.factory ??
        const ShadcnFactory();
    return factory.createSkeleton(
      key: key,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}
