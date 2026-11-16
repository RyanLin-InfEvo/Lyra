// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _lyraLicensesRegistered = false;
String? _cachedAgplText;
String? _cachedCc0Text;

const String _agplFallbackText =
    'Licensed under the GNU Affero General Public License v3.0 or later '
    '(AGPL-3.0-or-later). See LICENSES/AGPL-3.0-or-later.txt for full terms.';
const String _cc0FallbackText =
    'Released under CC0 1.0 Universal (CC0-1.0). '
    'See LICENSES/CC0-1.0.txt for full terms.';

Future<String> _loadAssetOrFallback(String assetPath, String fallback) async {
  try {
    return await rootBundle.loadString(assetPath);
  } catch (_) {
    return fallback;
  }
}

/// Resets registration state for isolated unit tests after `LicenseRegistry.reset()`.
@visibleForTesting
void resetLyraLicensesForTesting() {
  _lyraLicensesRegistered = false;
  _cachedAgplText = null;
  _cachedCc0Text = null;
}

/// Registers Lyra and its C++ Core third-party licenses with [LicenseRegistry]
/// so `showLicensePage` reflects both Dart/Flutter packages and native Core dependencies.
void registerLyraLicenses() {
  if (_lyraLicensesRegistered) return;
  _lyraLicensesRegistered = true;

  LicenseRegistry.addLicense(() async* {
    _cachedAgplText ??= await _loadAssetOrFallback(
      'assets/licenses/AGPL-3.0-or-later.txt',
      _agplFallbackText,
    );

    yield LicenseEntryWithLineBreaks(const <String>[
      'Lyra',
    ], 'Copyright (C) 2026 Tzu-Ting Lin\n\n$_cachedAgplText');

    yield const LicenseEntryWithLineBreaks(
      <String>['miniaudio (C++ Core)'],
      '''miniaudio - v0.11.25 - Audio playback and capture library
David Reid - mackron@gmail.com
Choice of Public Domain (www.unlicense.org) or MIT No Attribution:

Copyright 2026 David Reid

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''',
    );

    _cachedCc0Text ??= await _loadAssetOrFallback(
      'assets/licenses/CC0-1.0.txt',
      _cc0FallbackText,
    );

    yield LicenseEntryWithLineBreaks(const <String>[
      'tl-expected (C++ Core)',
    ], 'Sy Brand — CC0-1.0 Universal\n\n$_cachedCc0Text');

    yield const LicenseEntryWithLineBreaks(
      <String>['nlohmann_json (C++ Core)'],
      '''JSON for Modern C++
Copyright (c) 2013 - 2025 Niels Lohmann

Licensed under the MIT License (https://opensource.org/licenses/MIT).
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''',
    );

    yield const LicenseEntryWithLineBreaks(
      <String>['fmt (C++ Core)'],
      '''{fmt} Formatting Library
Copyright (c) 2012 - present, Victor Zverovich and {fmt} contributors

Licensed under the MIT License (https://opensource.org/licenses/MIT).
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''',
    );

    yield const LicenseEntryWithLineBreaks(
      <String>['SQLiteCpp (C++ Core)'],
      '''SQLiteCpp
Copyright (c) 2012-2025 Sebastien Rombauts

Licensed under the MIT License (https://opensource.org/licenses/MIT).
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''',
    );

    yield const LicenseEntryWithLineBreaks(
      <String>['stduuid (C++ Core)'],
      '''stduuid
Copyright (c) 2017 Marius Bancila

Licensed under the MIT License (https://opensource.org/licenses/MIT).
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''',
    );

    yield const LicenseEntryWithLineBreaks(
      <String>['FFmpeg (C++ Core)'],
      '''FFmpeg (libavformat, libavcodec, libswresample, libavutil)
Copyright (c) FFmpeg developers

FFmpeg is licensed under the GNU Lesser General Public License (LGPL) version 2.1 or later (https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html). Some optional components are licensed under the GNU General Public License (GPL) version 2 or later depending on system build configuration.''',
    );

    yield const LicenseEntryWithLineBreaks(
      <String>['SQLite (C++ Core)'],
      '''SQLite
The author disclaims copyright to this source code. In place of a legal notice, here is a blessing:

May you do good and not evil.
May you find forgiveness for yourself and others.
May you share freely, never taking more than you give.''',
    );
  });
}
