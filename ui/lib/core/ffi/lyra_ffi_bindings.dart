// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Low-level C Native Function Signatures
typedef LyraInitNative = Int32 Function(Pointer<Utf8> storageRoot);
typedef LyraDispatchNative = Pointer<Utf8> Function(Pointer<Utf8> jsonRequest);
typedef LyraFreeStringNative = Void Function(Pointer<Utf8> str);

/// Low-level Dart Function Signatures
typedef LyraInitDart = int Function(Pointer<Utf8> storageRoot);
typedef LyraDispatchDart = Pointer<Utf8> Function(Pointer<Utf8> jsonRequest);
typedef LyraFreeStringDart = void Function(Pointer<Utf8> str);

/// Exception thrown on FFI loading or invocation errors.
class LyraFfiException implements Exception {
  final String message;
  final dynamic details;

  const LyraFfiException(this.message, [this.details]);

  @override
  String toString() => details != null
      ? 'LyraFfiException: $message ($details)'
      : 'LyraFfiException: $message';
}

/// Dynamic library loader and raw FFI bindings wrapper for `lyra_core`.
class LyraFfiBindings {
  final DynamicLibrary dynamicLibrary;

  late final LyraInitDart _lyraInit;
  late final LyraDispatchDart _lyraDispatch;
  late final LyraFreeStringDart _lyraFreeString;

  /// Creates a bindings wrapper over an already opened [DynamicLibrary].
  LyraFfiBindings(this.dynamicLibrary) {
    _resolveSymbols();
  }

  /// Factory constructor to load and bind the dynamic library in one step.
  factory LyraFfiBindings.load({String? customPath}) {
    final dylib = loadDynamicLibrary(customPath: customPath);
    return LyraFfiBindings(dylib);
  }

  /// Resolve candidate dynamic library file names based on the current operating system.
  static List<String> getLibraryFileNames() {
    if (Platform.isLinux || Platform.isAndroid) {
      return const ['liblyra_core.so', 'liblyra.so'];
    } else if (Platform.isMacOS || Platform.isIOS) {
      return const ['liblyra_core.dylib', 'liblyra.dylib'];
    } else if (Platform.isWindows) {
      return const ['lyra_core.dll', 'lyra.dll'];
    }
    return const ['liblyra_core.so', 'liblyra.so'];
  }

  /// Resolve potential lookup paths for the native library.
  static List<String> getSearchPaths({String? customPath}) {
    if (customPath != null && customPath.isNotEmpty) {
      return [customPath];
    }

    final paths = <String>[];

    // Check environment variables
    final envPath =
        Platform.environment['LYRA_CORE_LIB_PATH'] ??
        Platform.environment['LYRA_LIB_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      paths.add(envPath);
    }

    final envDir = Platform.environment['LYRA_LIB_DIR'];
    final libNames = getLibraryFileNames();

    if (envDir != null && envDir.isNotEmpty) {
      for (final name in libNames) {
        paths.add('$envDir/$name');
      }
    }

    // Relative project paths for development & testing
    final currentDir = Directory.current.path;
    final devDirs = [
      currentDir,
      '$currentDir/core/build',
      '$currentDir/../core/build',
      '$currentDir/../../core/build',
      '$currentDir/../../../core/build',
      '$currentDir/build',
      '$currentDir/lib',
    ];

    for (final dir in devDirs) {
      for (final name in libNames) {
        paths.add('$dir/$name');
      }
    }

    // Executable-adjacent directories for desktop bundles
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      paths.add('$exeDir/lib');
      paths.add(exeDir);
      for (final name in libNames) {
        paths.add('$exeDir/lib/$name');
        paths.add('$exeDir/$name');
        if (Platform.isMacOS) {
          paths.add('$exeDir/../Frameworks/$name');
        }
      }
    } catch (_) {
      // Ignore Platform.resolvedExecutable errors in test harness
    }

    // System standard library names for fallback DynamicLibrary.open
    for (final name in libNames) {
      paths.add(name);
    }

    return paths.toSet().toList();
  }

  /// Attempts to load the dynamic library, returning `null` if not found or failed.
  static DynamicLibrary? tryLoadDynamicLibrary({String? customPath}) {
    final candidatePaths = getSearchPaths(customPath: customPath);

    for (final path in candidatePaths) {
      try {
        if (path.contains('/') || path.contains('\\')) {
          final file = File(path);
          if (file.existsSync()) {
            return DynamicLibrary.open(file.absolute.path);
          }
        } else {
          return DynamicLibrary.open(path);
        }
      } catch (_) {
        // Continue searching other candidates
      }
    }

    return null;
  }

  /// Loads the dynamic library or throws a descriptive [LyraFfiException].
  static DynamicLibrary loadDynamicLibrary({String? customPath}) {
    final dylib = tryLoadDynamicLibrary(customPath: customPath);
    if (dylib != null) {
      return dylib;
    }

    final triedPaths = getSearchPaths(customPath: customPath);
    throw LyraFfiException(
      'Failed to load Lyra native library on ${Platform.operatingSystem}.',
      'Checked search locations:\n  - ${triedPaths.join('\n  - ')}',
    );
  }

  /// Resolves the exported C API symbols from the loaded [DynamicLibrary].
  void _resolveSymbols() {
    try {
      _lyraInit = dynamicLibrary
          .lookup<NativeFunction<LyraInitNative>>('lyra_init')
          .asFunction<LyraInitDart>();
    } catch (e) {
      throw LyraFfiException('Failed to lookup symbol "lyra_init"', e);
    }

    try {
      try {
        _lyraDispatch = dynamicLibrary
            .lookup<NativeFunction<LyraDispatchNative>>('lyra_dispatch')
            .asFunction<LyraDispatchDart>();
      } catch (_) {
        _lyraDispatch = dynamicLibrary
            .lookup<NativeFunction<LyraDispatchNative>>('lyra_execute_command')
            .asFunction<LyraDispatchDart>();
      }
    } catch (e) {
      throw LyraFfiException(
        'Failed to lookup symbol "lyra_dispatch" or "lyra_execute_command"',
        e,
      );
    }

    try {
      _lyraFreeString = dynamicLibrary
          .lookup<NativeFunction<LyraFreeStringNative>>('lyra_free_string')
          .asFunction<LyraFreeStringDart>();
    } catch (e) {
      throw LyraFfiException('Failed to lookup symbol "lyra_free_string"', e);
    }
  }

  /// Initialize database context at [storageRoot].
  ///
  /// Returns 0 on success, or non-zero on failure.
  int init(String storageRoot) {
    final nativePath = storageRoot.toNativeUtf8();
    try {
      return _lyraInit(nativePath);
    } finally {
      calloc.free(nativePath);
    }
  }

  /// Dispatch raw JSON request payload and return JSON string response.
  ///
  /// Memory allocated by the C core is safely freed via [lyra_free_string].
  String dispatch(String jsonRequest) {
    final nativeRequest = jsonRequest.toNativeUtf8();
    Pointer<Utf8>? nativeResponse;
    try {
      nativeResponse = _lyraDispatch(nativeRequest);
      if (nativeResponse.address == 0) {
        throw const LyraFfiException(
          'Native core returned a null pointer for dispatch request.',
        );
      }
      return nativeResponse.toDartString();
    } finally {
      calloc.free(nativeRequest);
      if (nativeResponse != null && nativeResponse.address != 0) {
        _lyraFreeString(nativeResponse);
      }
    }
  }

  /// Alias for [dispatch] matching command execution terminology.
  String executeCommand(String jsonRequest) => dispatch(jsonRequest);

  /// Free a native C string pointer directly.
  void freeString(Pointer<Utf8> ptr) {
    if (ptr.address != 0) {
      _lyraFreeString(ptr);
    }
  }
}
