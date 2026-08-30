// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../ffi/lyra_native_bridge.dart';

/// Base repository providing bridge communication and response decoding utilities.
abstract class BaseRepository {
  /// Underlying bridge instance.
  final LyraBridge bridge;

  BaseRepository([LyraBridge? bridge])
    : bridge = bridge ?? LyraNativeBridge.instance;

  /// Checks the bridge response and throws [LyraBridgeException] if an error occurred.
  Map<String, dynamic> checkResponse(Map<String, dynamic> response) {
    final rawCode = response['code'];
    final int? code = rawCode is num
        ? rawCode.toInt()
        : (rawCode is String ? int.tryParse(rawCode) : null);
    final status = response['status']?.toString();

    if ((code != null && code >= 400) || status == 'error') {
      final errorMap = response['error'];
      final errorMsg = errorMap is Map
          ? errorMap['message']?.toString()
          : response['message']?.toString();
      throw LyraBridgeException(
        errorMsg ?? 'Command failed with status: $status (code: $code)',
        code: code,
        details: response,
      );
    }
    return response;
  }

  /// Extracts a list of items from a paginated or collection backend response.
  List<dynamic> unpackList(Map<String, dynamic> response) {
    checkResponse(response);
    final dynamic data = response['data'];
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'] as List;
    return const [];
  }

  /// Extracts a single entity map from a backend response.
  Map<String, dynamic> unpackMap(Map<String, dynamic> response) {
    checkResponse(response);
    if (!response.containsKey('data')) {
      return response;
    }
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }
}
