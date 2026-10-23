import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// What went wrong, in a form the UI can branch on.
enum FailureKind { network, timeout, unauthorized, forbidden, notFound, validation, conflict, throttled, server, unknown }

/// A failed request or operation, with a message that is safe to show.
@immutable
class AppFailure {
  const AppFailure([this.message = defaultMessage])
      : kind = FailureKind.unknown,
        statusCode = null,
        code = null,
        fieldErrors = const {},
        retryAfter = null;

  const AppFailure.of(
    this.kind,
    this.message, {
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
    this.retryAfter,
  });

  static const defaultMessage = 'Sorry, an unexpected error occurred!';
  static const offlineMessage = 'You appear to be offline. Check your connection and try again.';
  static const timeoutMessage = 'The server is taking too long to respond. Please try again.';

  final FailureKind kind;
  final String message;
  final int? statusCode;

  /// Machine-readable reason sent by the server, such as `refresh_cooldown`.
  final String? code;

  /// First error per field for 400 responses, keyed by the serializer field name.
  final Map<String, String> fieldErrors;

  /// How long to wait before retrying, from `Retry-After` or `retry_after`.
  final Duration? retryAfter;

  bool get isConnectivity => kind == FailureKind.network || kind == FailureKind.timeout;

  factory AppFailure.fromResponse(http.Response response) {
    final body = decodeBody(response);
    final status = response.statusCode;
    final kind = switch (status) {
      400 || 422 => FailureKind.validation,
      401 => FailureKind.unauthorized,
      403 => FailureKind.forbidden,
      404 => FailureKind.notFound,
      409 => FailureKind.conflict,
      429 => FailureKind.throttled,
      >= 500 => FailureKind.server,
      _ => FailureKind.unknown,
    };
    final message = readError(body) ?? _messageForStatus(status);
    final code = body is Map && body['code'] is String ? body['code'] as String : null;
    return AppFailure.of(
      kind,
      message,
      statusCode: status,
      code: code,
      fieldErrors: readFieldErrors(body),
      retryAfter: _retryAfter(response, body),
    );
  }

  factory AppFailure.fromException(Object error) {
    if (error is AppFailure) return error;
    if (error is TimeoutException) return const AppFailure.of(FailureKind.timeout, timeoutMessage);
    if (error is SocketException || error is http.ClientException || error is HandshakeException) {
      return const AppFailure.of(FailureKind.network, offlineMessage);
    }
    if (error is FormatException || error is TypeError) {
      return const AppFailure.of(FailureKind.server, 'We received an unexpected response from the server.');
    }
    return const AppFailure();
  }

  static String _messageForStatus(int status) => switch (status) {
        401 => 'Please sign in to continue.',
        403 => 'You do not have permission to do that.',
        404 => 'We could not find what you were looking for.',
        429 => 'Too many attempts. Please wait a moment and try again.',
        >= 500 => 'Our server ran into a problem. Please try again shortly.',
        _ => defaultMessage,
      };

  static Duration? _retryAfter(http.Response response, Object? body) {
    final header = int.tryParse(response.headers['retry-after'] ?? '');
    if (header != null) return Duration(seconds: header);
    if (body is Map) {
      final value = body['retry_after'];
      if (value is num) return Duration(seconds: value.ceil());
    }
    if (response.statusCode == 429 && body is Map && body['detail'] is String) {
      final match = RegExp(r'(\d+) seconds?').firstMatch(body['detail'] as String);
      if (match != null) return Duration(seconds: int.parse(match.group(1)!));
    }
    return null;
  }

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      other is AppFailure &&
      other.kind == kind &&
      other.message == message &&
      other.statusCode == statusCode &&
      other.code == code;

  @override
  int get hashCode => Object.hash(kind, message, statusCode, code);
}

/// Decodes a JSON body as UTF-8. DRF omits the charset, and `http` would otherwise read latin-1.
Object? decodeBody(http.Response response) {
  if (response.bodyBytes.isEmpty) return null;
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    return null;
  }
}

const _ignoredKeys = {'code', 'status', 'retry_after', 'valid', 'requires_verification'};
const _messageKeys = ['detail', 'error', 'non_field_errors', 'message'];

/// The first readable error in a DRF body: `detail`, `error`, `non_field_errors`, then field maps.
String? readError(Object? body) {
  if (body is String) {
    final text = body.trim();
    return text.isEmpty ? null : text;
  }
  if (body is List) {
    for (final item in body) {
      final message = readError(item);
      if (message != null) return message;
    }
    return null;
  }
  if (body is Map) {
    for (final key in _messageKeys) {
      final message = readError(body[key]);
      if (message != null) return message;
    }
    for (final entry in body.entries) {
      final key = entry.key.toString();
      if (_ignoredKeys.contains(key)) continue;
      final message = readError(entry.value);
      if (message != null) return _withFieldName(key, message);
    }
  }
  return null;
}

/// First message per field, for showing errors under form inputs.
Map<String, String> readFieldErrors(Object? body) {
  if (body is! Map) return const {};
  final result = <String, String>{};
  for (final entry in body.entries) {
    final key = entry.key.toString();
    if (_ignoredKeys.contains(key) || _messageKeys.contains(key)) continue;
    final message = readError(entry.value);
    if (message != null) result[key] = message;
  }
  return result;
}

String _withFieldName(String field, String message) {
  final label = humanizeField(field);
  if (message.startsWith('This field')) return message.replaceFirst('This field', label);
  if (message.startsWith('Ensure this field')) {
    return message.replaceFirst('Ensure this field', 'Ensure ${label.toLowerCase()}');
  }
  return message;
}

/// `shipping_phone` -> `Shipping phone`.
String humanizeField(String field) {
  final words = field.replaceAll(RegExp('[_-]+'), ' ').trim();
  if (words.isEmpty) return field;
  return words[0].toUpperCase() + words.substring(1);
}
