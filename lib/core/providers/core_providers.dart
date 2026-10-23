import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/features/auth/repositories/auth_local_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'core_providers.g.dart';

/// Loaded before `runApp` and supplied through a `ProviderScope` override.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('sharedPreferencesProvider is overridden in main()');

/// Persistent in the app; tests get an in-memory jar.
@Riverpod(keepAlive: true)
CookieJar cookieJar(Ref ref) => CookieJar();

/// Loaded before `runApp` so token reads stay synchronous.
@Riverpod(keepAlive: true)
AuthLocalRepository authLocalRepository(Ref ref) =>
    throw UnimplementedError('authLocalRepositoryProvider is overridden in main()');

@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => ApiClient(
      client: ref.watch(httpClientProvider),
      tokens: ref.watch(authLocalRepositoryProvider),
      cookies: ref.watch(cookieJarProvider),
    );
