import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pickorbeet/features/notifications/notification_inbox.dart';

/// Unread staff replies for Help entry badges (from support.reply inbox rows).
final helpUnreadProvider = Provider<int>((ref) {
  final inbox = ref.watch(notificationInboxProvider);
  return inbox.items
      .where((item) => item.unread && item.link == NotificationLink.help)
      .length;
});
