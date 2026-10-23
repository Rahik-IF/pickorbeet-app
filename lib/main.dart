import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pickorbeet/app.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/features/auth/repositories/auth_local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayOnDark);

  final prefs = await SharedPreferences.getInstance();
  final supportDir = await getApplicationSupportDirectory();
  final cookies = PersistCookieJar(storage: FileStorage('${supportDir.path}/cookies/'));

  // The iOS keychain outlives an uninstall; a fresh install must not inherit a stale session.
  const installedKey = 'installed';
  final tokens = AuthLocalRepository();
  await tokens.init(clearExisting: !(prefs.getBool(installedKey) ?? false));
  await prefs.setBool(installedKey, true);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cookieJarProvider.overrideWithValue(cookies),
        authLocalRepositoryProvider.overrideWithValue(tokens),
      ],
      child: const PickOrbeetApp(),
    ),
  );
}
