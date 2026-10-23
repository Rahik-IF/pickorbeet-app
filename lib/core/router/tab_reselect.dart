import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pickorbeet/core/motion/motion.dart';

/// Tapping the tab that is already open. Tab pages listen and scroll back to the top.
final tabReselectProvider = NotifierProvider<TabReselect, TabReselectEvent>(TabReselect.new);

@immutable
class TabReselectEvent {
  const TabReselectEvent(this.tab, this.serial);

  final int tab;

  /// Increases on every reselect, so two taps in a row are two events.
  final int serial;
}

class TabReselect extends Notifier<TabReselectEvent> {
  @override
  TabReselectEvent build() => const TabReselectEvent(-1, 0);

  void reselect(int tab) => state = TabReselectEvent(tab, state.serial + 1);
}

/// Scrolls [controller] to the top when [tab] is reselected.
void listenForTabReselect(WidgetRef ref, BuildContext context, int tab, ScrollController controller) {
  ref.listen(tabReselectProvider, (_, event) {
    if (event.tab != tab || !controller.hasClients) return;
    if (controller.offset == 0) return;
    controller.animateTo(0, duration: Motion.of(context, Motion.long), curve: Motion.emphasized);
  });
}
