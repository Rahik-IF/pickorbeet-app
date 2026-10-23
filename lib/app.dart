import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/app_router.dart';
import 'package:pickorbeet/core/theme/theme.dart';

class PickOrbeetApp extends ConsumerWidget {
  const PickOrbeetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts session restore at launch.
    ref.watch(sessionNotifierProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'PickOrbeet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
