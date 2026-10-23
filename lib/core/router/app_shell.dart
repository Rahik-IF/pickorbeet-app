import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pickorbeet/core/router/tab_reselect.dart';
import 'package:pickorbeet/core/widgets/bottom_nav.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';

/// Scaffold for the five tabs. Back on a tab other than Home returns to Home before leaving.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(WidgetRef ref, int index) {
    if (index == shell.currentIndex) ref.read(tabReselectProvider.notifier).reselect(index);
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(ref, 0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: AppBottomNav(
          currentIndex: shell.currentIndex,
          onSelect: (index) => _select(ref, index),
          cartCount: ref.watch(cartCountProvider),
        ),
      ),
    );
  }
}
