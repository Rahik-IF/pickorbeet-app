import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pickorbeet/core/providers/preferences_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/app_router.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/features/notifications/notification_realtime.dart';

class PickOrbeetApp extends ConsumerWidget {
  const PickOrbeetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts session restore, then the inbox socket and phone push.
    ref.watch(sessionNotifierProvider);
    ref.watch(notificationLifecycleProvider);
    final router = ref.watch(appRouterProvider);
    final darkMode = ref.watch(preferencesProvider.select((prefs) => prefs.darkMode));

    return MaterialApp.router(
      title: 'PickOrbeet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
