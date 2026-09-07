// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'lyra_bridge.dart';
import 'mock_lyra_bridge.dart';

/// Web bridge factory creating a pure Dart mock bridge instance.
LyraBridge createBridge() => MockLyraBridge();
