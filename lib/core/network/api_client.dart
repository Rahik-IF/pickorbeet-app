import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:pickorbeet/core/constants/server_constant.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/features/auth/device_identity.dart';
import 'package:pickorbeet/features/auth/repositories/auth_local_repository.dart';

enum _RefreshResult { refreshed, expired, unavailable }

/// JPEG, PNG, GIF, or WebP from the file header. Null when the bytes are not one of those.
MediaType? imageContentType(List<int> bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return MediaType('image', 'jpeg');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return MediaType('image', 'png');
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38 &&
      (bytes[4] == 0x37 || bytes[4] == 0x39) &&
      bytes[5] == 0x61) {
    return MediaType('image', 'gif');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return MediaType('image', 'webp');
  }
  return null;
}

String _uploadFilename(String filename, List<int> bytes) {
  final type = imageContentType(bytes);
  if (type == null) return filename;
  final lower = filename.toLowerCase();
  const known = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  if (known.any(lower.endsWith)) return filename;
  final ext = type.subtype == 'jpeg' ? '.jpg' : '.${type.subtype}';
  final base = filename.trim().isEmpty ? 'photo' : filename.trim();
  return '$base$ext';
}

/// The one HTTP client for the Django API.
///
/// Sends the Bearer token, keeps the `sessionid` cookie that guest carts depend on, refreshes an
/// expired access token once for every request waiting on it, and retries a GET once on a dropped
/// connection.
class ApiClient {
  final DeviceIdentity? device;

  ApiClient({
    required http.Client client,
    required AuthLocalRepository tokens,
    required CookieJar cookies,
    String? baseUrl,
    this.timeout = const Duration(seconds: 15),
    this.device,
  }) : _client = client,
       _tokens = tokens,
       _cookies = cookies,
       _baseUrl = baseUrl ?? ServerConstant.apiBase;

  final http.Client _client;
  final AuthLocalRepository _tokens;
  final CookieJar _cookies;
  final String _baseUrl;
  final Duration timeout;

  /// Runs after the server rejects the refresh token and the saved tokens are cleared.
  void Function()? onSessionExpired;

  /// Runs while the access token is still valid, just before a dead session is cleared.
  Future<void> Function()? beforeSessionExpired;

  Future<_RefreshResult>? _refreshing;

  Future<http.Response> get(
    String path, {
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _send('GET', path, query: query, authenticated: authenticated);

  Future<http.Response> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send('POST', path, body: body, authenticated: authenticated);

  Future<http.Response> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<http.Response> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<http.Response> delete(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send('DELETE', path, body: body, authenticated: authenticated);

  /// Multipart upload. [bytes] can be sent again if the access token has to be refreshed.
  Future<http.Response> postFile(
    String path, {
    Map<String, String> fields = const {},
    required String fileField,
    required String filename,
    required List<int> bytes,
  }) => postFiles(
    path,
    fields: fields,
    files: [(field: fileField, filename: filename, bytes: bytes)],
  );

  /// Multipart POST with one or more files (same or different field names).
  Future<http.Response> postFiles(
    String path, {
    Map<String, String> fields = const {},
    required List<({String field, String filename, List<int> bytes})> files,
  }) => _upload('POST', path, fields: fields, files: files);

  /// Multipart PATCH. The profile photo is sent with the text fields in one request.
  Future<http.Response> patchFile(
    String path, {
    Map<String, String> fields = const {},
    required String fileField,
    required String filename,
    required List<int> bytes,
  }) => _upload(
    'PATCH',
    path,
    fields: fields,
    files: [(field: fileField, filename: filename, bytes: bytes)],
    timeout: const Duration(seconds: 45),
  );

  Future<http.Response> _upload(
    String method,
    String path, {
    required Map<String, String> fields,
    required List<({String field, String filename, List<int> bytes})> files,
    Duration? timeout,
  }) async {
    final target = uri(path);
    final access = _tokens.getAccessToken();
    final response = await _sendFile(
      method,
      target,
      fields,
      files,
      access,
      timeout,
    );
    if (response.statusCode != HttpStatus.unauthorized || access == null) {
      return response;
    }
    switch (await _refresh(access)) {
      case _RefreshResult.refreshed:
        return _sendFile(
          method,
          target,
          fields,
          files,
          _tokens.getAccessToken(),
          timeout,
        );
      case _RefreshResult.expired:
        return _sendFile(
          method,
          target,
          fields,
          files,
          null,
          timeout,
        );
      case _RefreshResult.unavailable:
        return response;
    }
  }

  /// Builds an API URL. Django needs the trailing slash, and a redirect would drop a POST body.
  Uri uri(String path, [Map<String, Object?>? query]) {
    assert(path.startsWith('/'), 'API paths start with "/": $path');
    assert(path.endsWith('/'), 'API paths end with "/": $path');
    final base = Uri.parse('$_baseUrl$path');
    final params = <String, String>{
      for (final entry in (query ?? const <String, Object?>{}).entries)
        if (entry.value != null && '${entry.value}'.isNotEmpty)
          entry.key: '${entry.value}',
    };
    return params.isEmpty ? base : base.replace(queryParameters: params);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final target = uri(path, query);
    final access = authenticated ? _tokens.getAccessToken() : null;
    final response = await _dispatchWithRetry(method, target, body, access);
    if (response.statusCode != HttpStatus.unauthorized || access == null) {
      return response;
    }

    switch (await _refresh(access)) {
      case _RefreshResult.refreshed:
        return _dispatchWithRetry(
          method,
          target,
          body,
          _tokens.getAccessToken(),
        );
      case _RefreshResult.expired:
        // SimpleJWT rejects a stale token even on public endpoints, so retry as a guest.
        return _dispatchWithRetry(method, target, body, null);
      case _RefreshResult.unavailable:
        return response;
    }
  }

  Future<_RefreshResult> _refresh(String failedAccess) {
    final current = _tokens.getAccessToken();
    if (current != null && current != failedAccess) {
      return Future.value(_RefreshResult.refreshed);
    }
    return _refreshing ??= _performRefresh().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<_RefreshResult> _performRefresh() async {
    final refresh = _tokens.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await _expireSession();
      return _RefreshResult.expired;
    }
    final response = await _dispatch('POST', uri('/auth/token/refresh/'), {
      'refresh': refresh,
    }, null);
    if (response.statusCode == HttpStatus.ok) {
      final body = decodeBody(response);
      if (body is Map && body['access'] is String) {
        // Refresh tokens rotate and the old one is blacklisted, so keep the new one.
        final rotated = body['refresh'] is String
            ? body['refresh'] as String
            : refresh;
        await _tokens.saveSession(body['access'] as String, rotated);
        return _RefreshResult.refreshed;
      }
    }
    if (response.statusCode == HttpStatus.badRequest ||
        response.statusCode == HttpStatus.unauthorized) {
      await _expireSession();
      return _RefreshResult.expired;
    }
    return _RefreshResult.unavailable;
  }

  /// Returns a current access token. [force] asks the server for a new one.
  Future<String?> ensureAccess({bool force = false}) async {
    final current = _tokens.getAccessToken();
    if (!force && current != null && current.isNotEmpty) return current;
    if (!_tokens.hasSession) return null;
    final result = await _refresh(current ?? '');
    if (result == _RefreshResult.refreshed) return _tokens.getAccessToken();
    return null;
  }

  Future<void> _expireSession() async {
    final hook = beforeSessionExpired;
    if (hook != null) {
      try {
        await hook();
      } on Object {
        // Signing out still proceeds when the device unregister fails.
      }
    }
    await _tokens.clear();
    onSessionExpired?.call();
  }

  Future<http.Response> _dispatchWithRetry(
    String method,
    Uri target,
    Object? body,
    String? access,
  ) async {
    try {
      return await _dispatch(method, target, body, access);
    } on Object catch (error) {
      if (method != 'GET' || !_isTransient(error)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return _dispatch(method, target, body, access);
    }
  }

  static bool _isTransient(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;

  Future<http.Response> _sendFile(
    String method,
    Uri target,
    Map<String, String> fields,
    List<({String field, String filename, List<int> bytes})> files,
    String? access,
    Duration? timeout,
  ) async {
    final limit = timeout ?? this.timeout;
    final request = http.MultipartRequest(method, target)
      ..followRedirects = false
      ..fields.addAll(fields)
      ..headers[HttpHeaders.acceptHeader] = 'application/json'
      ..headers['X-Client-Platform'] = 'app';
    _applyDevice(request.headers);
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes(
          file.field,
          file.bytes,
          filename: _uploadFilename(file.filename, file.bytes),
          contentType: imageContentType(file.bytes),
        ),
      );
    }
    if (access != null) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $access';
    }
    final cookies = await _cookies.loadForRequest(target);
    if (cookies.isNotEmpty) {
      request.headers[HttpHeaders.cookieHeader] = cookies
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .join('; ');
    }
    final streamed = await _client.send(request).timeout(limit);
    final response = await http.Response.fromStream(streamed).timeout(limit);
    await _saveCookies(target, response);
    return response;
  }

  void _applyDevice(Map<String, String> headers) {
    final current = device;
    if (current == null || current.id.isEmpty) return;
    headers['X-Device-Id'] = current.id;
    if (current.name.isNotEmpty) headers['X-Device-Name'] = current.name;
  }

  Future<http.Response> _dispatch(
    String method,
    Uri target,
    Object? body,
    String? access,
  ) async {
    final request = http.Request(method, target)
      ..followRedirects = false
      ..headers.addAll({
        HttpHeaders.acceptHeader: 'application/json',
        'X-Client-Platform': 'app',
        if (device != null && device!.id.isNotEmpty) 'X-Device-Id': device!.id,
        if (device != null && device!.name.isNotEmpty) 'X-Device-Name': device!.name,
        if (body != null)
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        if (access != null) HttpHeaders.authorizationHeader: 'Bearer $access',
      });
    final cookies = await _cookies.loadForRequest(target);
    if (cookies.isNotEmpty) {
      request.headers[HttpHeaders.cookieHeader] = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
    }
    if (body != null) request.bodyBytes = utf8.encode(jsonEncode(body));

    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed).timeout(timeout);
    await _saveCookies(target, response);
    return response;
  }

  Future<void> _saveCookies(Uri target, http.Response response) async {
    final header = response.headers[HttpHeaders.setCookieHeader];
    if (header == null || header.isEmpty) return;
    final cookies = <Cookie>[];
    for (final value in splitSetCookieHeader(header)) {
      try {
        cookies.add(Cookie.fromSetCookieValue(value));
      } on FormatException {
        // Skip a cookie we cannot parse rather than failing the request.
      }
    }
    if (cookies.isNotEmpty) await _cookies.saveFromResponse(target, cookies);
  }
}

/// `package:http` joins repeated `Set-Cookie` headers with commas. Split them back apart without
/// breaking `Expires=Wed, 21 Oct 2026 ...` dates.
List<String> splitSetCookieHeader(String header) => header
    .split(RegExp(r',(?=\s*[^;,=\s]+=)'))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

/// Runs a request and maps the outcome to `Either`. Success statuses default to 200 and 201.
Future<Either<AppFailure, T>> guardRequest<T>(
  Future<http.Response> Function() request,
  T Function(Object? body) parse, {
  Set<int> success = const {200, 201},
}) async {
  try {
    final response = await request();
    if (!success.contains(response.statusCode)) {
      return Left(AppFailure.fromResponse(response));
    }
    return Right(parse(decodeBody(response)));
  } on Object catch (error) {
    return Left(AppFailure.fromException(error));
  }
}
