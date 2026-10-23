// Maps API rows onto the designed inbox and keeps channel preferences on the device.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/features/notifications/notification_repository.dart';

/// Where a notification opens when it has no order id.
enum NotificationLink { orders, products, wishlist, account }

enum InboxChannel { orders, offers, account, system }

enum InboxGroup { today, yesterday, week, earlier }

enum InboxIcon { package, tag, truck, heart, star, clipboard, megaphone, user, gear }

enum InboxThumb { save, price, arrivals }

enum InboxFilter { all, orders, offers, account, system }

/// One row in the inbox.
@immutable
class InboxItem {
  const InboxItem({
    required this.id,
    required this.group,
    required this.channel,
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.link,
    required this.unread,
    this.highlight,
    this.thumb,
    this.orderId,
  });

  final String id;
  final InboxGroup group;
  final InboxChannel channel;
  final InboxIcon icon;
  final String title;
  final String body;
  final String? highlight;
  final String time;
  final NotificationLink link;
  final InboxThumb? thumb;
  final bool unread;
  final String? orderId;

  InboxItem copyWith({bool? unread}) => InboxItem(
        id: id,
        group: group,
        channel: channel,
        icon: icon,
        title: title,
        body: body,
        time: time,
        link: link,
        unread: unread ?? this.unread,
        highlight: highlight,
        thumb: thumb,
        orderId: orderId,
      );
}

const _channelKey = 'notification_channels';

@immutable
class InboxState {
  const InboxState({
    this.items = const [],
    this.channels = const {},
    this.unreadCount = 0,
    this.loading = false,
    this.error,
  });

  final List<InboxItem> items;
  final Map<InboxChannel, bool> channels;
  final int unreadCount;
  final bool loading;
  final String? error;

  bool isUnread(InboxItem item) => item.unread;

  bool channelOn(InboxChannel channel) => channels[channel] ?? true;

  InboxState copyWith({
    List<InboxItem>? items,
    Map<InboxChannel, bool>? channels,
    int? unreadCount,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      InboxState(
        items: items ?? this.items,
        channels: channels ?? this.channels,
        unreadCount: unreadCount ?? this.unreadCount,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
      );
}

class NotificationInbox extends Notifier<InboxState> {
  @override
  InboxState build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_channelKey);
    return InboxState(channels: _readChannels(raw));
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, clearError: true);
    final result = await ref.read(notificationRepositoryProvider).fetchInbox();
    result.match(
      (failure) => state = state.copyWith(loading: false, error: failure.message),
      (loaded) => state = state.copyWith(
        loading: false,
        items: [for (final row in loaded.items) row.toInboxItem()],
        unreadCount: loaded.unreadCount,
        clearError: true,
      ),
    );
  }

  /// Insert or replace a live row and trust the server's unread total.
  void upsert(AppNotification row, int unreadCount) {
    final item = row.toInboxItem();
    final rest = [for (final existing in state.items) if (existing.id != item.id) existing];
    state = state.copyWith(items: [item, ...rest], unreadCount: unreadCount, clearError: true);
  }

  void setUnreadCount(int count) => state = state.copyWith(unreadCount: count);

  Future<void> markRead(Iterable<String> ids) async {
    final pending = {
      for (final item in state.items)
        if (ids.contains(item.id) && item.unread) item.id,
    };
    if (pending.isEmpty) return;
    state = state.copyWith(
      items: [
        for (final item in state.items) pending.contains(item.id) ? item.copyWith(unread: false) : item,
      ],
      unreadCount: (state.unreadCount - pending.length).clamp(0, 1 << 30),
    );
    final repo = ref.read(notificationRepositoryProvider);
    for (final id in pending) {
      await repo.markRead(id);
    }
  }

  void toggle(InboxChannel channel) {
    final next = {...state.channels, channel: !(state.channels[channel] ?? true)};
    state = state.copyWith(channels: next);
    unawaited(ref.read(sharedPreferencesProvider).setString(_channelKey, _writeChannels(next)));
  }

  void clear() {
    state = state.copyWith(items: const [], unreadCount: 0, loading: false, clearError: true);
  }
}

final notificationInboxProvider = NotifierProvider<NotificationInbox, InboxState>(NotificationInbox.new);

Map<InboxChannel, bool> _readChannels(String? raw) {
  final channels = {for (final channel in InboxChannel.values) channel: true};
  if (raw == null) return channels;
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return channels;
  for (final channel in InboxChannel.values) {
    final value = decoded[channel.name];
    if (value is bool) channels[channel] = value;
  }
  return channels;
}

String _writeChannels(Map<InboxChannel, bool> channels) =>
    jsonEncode({for (final entry in channels.entries) entry.key.name: entry.value});

extension InboxGroupLabel on InboxGroup {
  String get label => switch (this) {
        InboxGroup.today => 'Today',
        InboxGroup.yesterday => 'Yesterday',
        InboxGroup.week => 'This Week',
        InboxGroup.earlier => 'Earlier',
      };
}

extension InboxFilterLabel on InboxFilter {
  String get label => switch (this) {
        InboxFilter.all => 'All',
        InboxFilter.orders => 'Orders',
        InboxFilter.offers => 'Offers',
        InboxFilter.account => 'Account',
        InboxFilter.system => 'System',
      };

  InboxChannel? get channel => switch (this) {
        InboxFilter.all => null,
        InboxFilter.orders => InboxChannel.orders,
        InboxFilter.offers => InboxChannel.offers,
        InboxFilter.account => InboxChannel.account,
        InboxFilter.system => InboxChannel.system,
      };
}

extension AppNotificationInbox on AppNotification {
  InboxItem toInboxItem() {
    final code = data['code'];
    final highlight = code is String && code.isNotEmpty && body.contains(code) ? code : null;
    final orderId = data['order_id'];
    return InboxItem(
      id: id,
      group: _group(createdAt),
      channel: _channel(kind),
      icon: _icon(kind),
      title: title,
      body: body,
      highlight: highlight,
      time: _timeLabel(createdAt),
      link: _link(data['target']),
      thumb: _thumb(data['thumb']),
      unread: readAt == null,
      orderId: orderId is String && orderId.isNotEmpty ? orderId : null,
    );
  }
}

InboxChannel _channel(String kind) {
  if (kind.startsWith('order.') || kind.startsWith('payment.') || kind.startsWith('refund.')) {
    return InboxChannel.orders;
  }
  if (kind.startsWith('offer.') || kind.startsWith('promo.') || kind.startsWith('price.') || kind.startsWith('arrival.')) {
    return InboxChannel.offers;
  }
  if (kind.startsWith('account.')) return InboxChannel.account;
  return InboxChannel.system;
}

InboxIcon _icon(String kind) => switch (kind) {
      'order.shipped' || 'order.out_for_delivery' || 'order.delivered' => InboxIcon.truck,
      'payment.paid' || 'payment.failed' || 'refund.requested' || 'refund.completed' => InboxIcon.clipboard,
      _ when kind.startsWith('offer.') || kind.startsWith('promo.') => InboxIcon.tag,
      _ when kind.startsWith('price.') => InboxIcon.heart,
      _ when kind.startsWith('arrival.') => InboxIcon.star,
      _ when kind.startsWith('account.') => InboxIcon.megaphone,
      _ when kind.startsWith('system.') => InboxIcon.gear,
      _ => InboxIcon.package,
    };

NotificationLink _link(Object? target) => switch (target) {
      'products' => NotificationLink.products,
      'wishlist' => NotificationLink.wishlist,
      'account' => NotificationLink.account,
      _ => NotificationLink.orders,
    };

InboxThumb? _thumb(Object? value) => switch (value) {
      'save' => InboxThumb.save,
      'price' => InboxThumb.price,
      'arrivals' => InboxThumb.arrivals,
      _ => null,
    };

InboxGroup _group(DateTime created) {
  final days = _dayDiff(created);
  if (days <= 0) return InboxGroup.today;
  if (days == 1) return InboxGroup.yesterday;
  if (days < 7) return InboxGroup.week;
  return InboxGroup.earlier;
}

String _timeLabel(DateTime created) {
  final days = _dayDiff(created);
  if (days <= 0) {
    final elapsed = DateTime.now().difference(created);
    if (elapsed.inSeconds < 45) return 'Just now';
    if (elapsed.inMinutes < 60) {
      final minutes = elapsed.inMinutes.clamp(1, 59);
      return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
    }
    final hours = elapsed.inHours.clamp(1, 23);
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  if (days == 1) return 'Yesterday, ${Formatters.time(created)}';
  return Formatters.dateTime(created);
}

int _dayDiff(DateTime created) {
  final local = Formatters.toDhaka(created);
  final now = Formatters.toDhaka(DateTime.now());
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(day).inDays;
}
