// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../ffi/lyra_native_bridge.dart';

/// Native bridge factory creating a native FFI/isolate bridge instance.
LyraBridge createBridge() => LyraNativeBridge();
