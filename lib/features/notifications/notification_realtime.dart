import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pickorbeet/core/constants/server_constant.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/providers/wishlist_notifier.dart';
import 'package:pickorbeet/core/router/app_router.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/features/account/viewmodel/orders_controller.dart';
import 'package:pickorbeet/features/notifications/in_app_banner.dart';
import 'package:pickorbeet/features/notifications/notification_inbox.dart';
import 'package:pickorbeet/features/notifications/notification_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Channel ids, the icon name and the tray tags must match what the server sends to FCM,
// so a tray entry the app posts and one Android posts from a push replace each other.
const _ordersChannel = AndroidNotificationChannel(
  'orders',
  'Orders and deliveries',
  description: 'Order, payment and delivery updates',
  importance: Importance.high,
);

const _supportChannel = AndroidNotificationChannel(
  'support',
  'Help chat',
  description: 'Replies from PickOrbeet support',
  importance: Importance.high,
);

const _offersChannel = AndroidNotificationChannel(
  'offers',
  'New arrivals and offers',
  description: 'New products, stock alerts and sales',
  importance: Importance.high,
);

const _smallIcon = 'ic_stat_notify';
const _androidInit = AndroidInitializationSettings(_smallIcon);
const _iosInit = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);

/// Android posts FCM tray entries under id 0 when they carry a tag.
const _trayId = 0;

const supportTrayTag = 'support';

String orderTrayTag(String orderId) => 'order-$orderId';

/// The tray tag for a notification: one entry per order, one for the Help chat.
String trayTagFor(AppNotification row) {
  final sent = row.data['tag'];
  if (sent is String && sent.isNotEmpty) return sent;
  if (row.kind.startsWith('support.')) return supportTrayTag;
  final campaignId = row.data['campaign_id'];
  if (campaignId is String && campaignId.isNotEmpty) return 'campaign-$campaignId';
  final orderId = row.data['order_id'];
  if (orderId is String && orderId.isNotEmpty) return orderTrayTag(orderId);
  return 'note-${row.id}';
}

AndroidNotificationChannel _channelFor(AppNotification row) {
  if (row.kind.startsWith('support.')) return _supportChannel;
  if (row.kind.startsWith('product.') || row.kind.startsWith('promo.')) return _offersChannel;
  return _ordersChannel;
}

Future<FlutterLocalNotificationsPlugin> _trayPlugin(
  FlutterLocalNotificationsPlugin plugin, {
  DidReceiveNotificationResponseCallback? onOpen,
}) async {
  await plugin.initialize(
    const InitializationSettings(android: _androidInit, iOS: _iosInit),
    onDidReceiveNotificationResponse: onOpen,
  );
  final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_ordersChannel);
  await android?.createNotificationChannel(_supportChannel);
  await android?.createNotificationChannel(_offersChannel);
  return plugin;
}

/// Posts [row] in the tray the way a push from the server looks. A [quiet] entry
/// makes no sound and no heads-up, for when the banner inside the app already showed it.
Future<void> _postTray(FlutterLocalNotificationsPlugin plugin, AppNotification row, {bool quiet = false}) {
  final channel = _channelFor(row);
  final orderId = row.data['order_id'];
  final target = row.data['target'];
  final productSlug = row.data['product_slug'];
  final chat = channel.id == _supportChannel.id;
  return plugin.show(
    _trayId,
    row.title,
    row.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        color: AppPallete.primary,
        tag: trayTagFor(row),
        when: row.createdAt.millisecondsSinceEpoch,
        category: chat ? AndroidNotificationCategory.message : AndroidNotificationCategory.status,
        styleInformation: BigTextStyleInformation(row.body, contentTitle: row.title),
        ticker: row.title,
        silent: quiet,
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: channel.id,
        presentBanner: !quiet,
        presentList: true,
        presentSound: !quiet,
      ),
    ),
    payload:
        '${row.id}|${orderId is String ? orderId : ''}|${target is String ? target : ''}|${productSlug is String ? productSlug : ''}',
  );
}

/// Runs when a push arrives while the app is not in the foreground.
///
/// Pushes from the server carry a notification payload, which Android and iOS post
/// themselves. This handler only fills the gap for data-only pushes.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.notification != null) return;
  final row = _fromRemote(message);
  if (row == null) return;
  final plugin = await _trayPlugin(FlutterLocalNotificationsPlugin());
  await _postTray(plugin, row);
}

bool _firebaseReady = false;

/// Starts Firebase when the platform config files are present. Missing files leave push off.
Future<void> startFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // Channels exist before the first push, so FCM never falls back to its own.
    await _trayPlugin(FlutterLocalNotificationsPlugin());
    _firebaseReady = true;
  } on Object {
    _firebaseReady = false;
  }
}

/// The last order a live notification was about, so an open order page can reload.
typedef OrderPing = ({String orderId, int seq});

class OrderPings extends Notifier<OrderPing?> {
  var _seq = 0;

  @override
  OrderPing? build() => null;

  void ping(String orderId) => state = (orderId: orderId, seq: ++_seq);
}

final orderPingProvider = NotifierProvider<OrderPings, OrderPing?>(OrderPings.new);

/// Keeps the live socket and the phone token in step with the signed-in session,
/// and shows each new notification once: a banner in the app, or the tray outside it.
class NotificationLifecycle extends Notifier<void> with WidgetsBindingObserver {
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  Timer? _retry;
  int _generation = 0;
  var _stopped = true;
  var _socketConnected = false;
  var _observingLifecycle = false;
  var _pushAllowed = false;
  var _pushRegistered = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  final _presented = <String>{};
  final _local = FlutterLocalNotificationsPlugin();
  var _localReady = false;

  bool get _resumed => _lifecycle == AppLifecycleState.resumed;

  /// Android or iOS post this phone's pushes while the app is in the background.
  bool get _pushActive => _firebaseReady && _pushAllowed && _pushRegistered;

  @override
  void build() {
    final api = ref.read(apiClientProvider);
    final previous = api.beforeSessionExpired;
    api.beforeSessionExpired = () async {
      await ref.read(notificationRepositoryProvider).unregisterThisDevice();
      await previous?.call();
    };
    ref.listen(sessionNotifierProvider, (previousStatus, next) {
      if (next == SessionStatus.signedIn) unawaited(start());
      if (next == SessionStatus.guest) unawaited(stop());
    });
    ref.onDispose(() {
      api.beforeSessionExpired = previous;
      _detachLifecycle();
      unawaited(stop());
    });
    if (ref.read(sessionNotifierProvider) == SessionStatus.signedIn) {
      Future.microtask(start);
    }
  }

  void _attachLifecycle() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
    _lifecycle = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }

  void _detachLifecycle() {
    if (!_observingLifecycle) return;
    WidgetsBinding.instance.removeObserver(this);
    _observingLifecycle = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _resumed;
    _lifecycle = state;
    if (_stopped) return;
    if (state == AppLifecycleState.resumed && !wasResumed) {
      unawaited(_onResumed());
    }
  }

  Future<void> _onResumed() async {
    if (_stopped) return;
    await ref.read(notificationInboxProvider.notifier).reload();
    if (!_socketConnected) {
      await _connect(forceRefresh: false);
    }
  }

  Future<void> start() async {
    if (ref.read(sessionNotifierProvider) != SessionStatus.signedIn) return;
    _stopped = false;
    _attachLifecycle();
    await _prepareLocalNotifications();
    await ref.read(notificationInboxProvider.notifier).reload();
    await _syncOffersPreference();
    unawaited(
      ref.read(notificationRepositoryProvider).replaceWishlist(ref.read(wishlistNotifierProvider)),
    );
    await _connect(forceRefresh: false);
    await _startPush();
  }

  Future<void> _syncOffersPreference() async {
    final result = await ref.read(notificationRepositoryProvider).fetchOffersPreference();
    result.match((_) {}, (offers) {
      ref.read(notificationInboxProvider.notifier).setChannel(InboxChannel.offers, offers, sync: false);
    });
  }

  Future<void> stop() async {
    _stopped = true;
    _generation++;
    _retry?.cancel();
    _socketConnected = false;
    _pushRegistered = false;
    InAppBanner.hide();
    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.sink.close();
    _socket = null;
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    await _foreground?.cancel();
    _foreground = null;
    await _opened?.cancel();
    _opened = null;
    ref.read(notificationInboxProvider.notifier).clear();
  }

  /// Removes the tray entry for [tag], whether the app or a push posted it.
  Future<void> dismissTray(String tag) async {
    if (!_localReady) return;
    try {
      await _local.cancel(_trayId, tag: tag);
    } on Object {
      // Nothing to remove, or the platform does not support tags.
    }
  }

  Future<void> _connect({required bool forceRefresh}) async {
    if (_stopped) return;
    final generation = ++_generation;
    _retry?.cancel();
    await _socketSub?.cancel();
    await _socket?.sink.close();
    _socket = null;
    _socketConnected = false;

    final token = await ref
        .read(apiClientProvider)
        .ensureAccess(force: forceRefresh);
    if (_stopped || generation != _generation) return;
    if (token == null) return;

    final channel = WebSocketChannel.connect(_socketUri(token));
    _socket = channel;
    unawaited(
      channel.ready.then((_) {
        if (!_stopped && generation == _generation) _socketConnected = true;
      }, onError: (_) {}),
    );
    _socketSub = channel.stream.listen(
      (event) {
        _socketConnected = true;
        _onSocket(event);
      },
      onError: (_) => _scheduleRetry(generation),
      onDone: () {
        _socketConnected = false;
        if (_stopped || generation != _generation) return;
        if (channel.closeCode == 4401) {
          unawaited(_connect(forceRefresh: true));
          return;
        }
        _scheduleRetry(generation);
      },
    );
  }

  void _scheduleRetry(int generation) {
    if (_stopped || generation != _generation) return;
    final delay = Duration(
      seconds: (1 << (_generation.clamp(0, 5))).clamp(1, 30),
    );
    _retry?.cancel();
    _retry = Timer(delay, () {
      if (!_stopped) unawaited(_connect(forceRefresh: false));
    });
  }

  void _onSocket(dynamic event) {
    final decoded = event is String ? jsonDecode(event) : null;
    if (decoded is! Map) return;
    final json = asJson(decoded);
    final type = json.str('type');
    if (type == 'notification.read') {
      ref
          .read(notificationInboxProvider.notifier)
          .setUnreadCount(json.integer('unread_count'));
      return;
    }
    if (type != 'notification.created') return;
    final rowJson = json.obj('notification');
    if (rowJson == null) return;
    final row = AppNotification.fromJson(rowJson);
    ref
        .read(notificationInboxProvider.notifier)
        .upsert(row, json.integer('unread_count'));
    _present(row, fromPush: false);
  }

  Future<void> _startPush() async {
    if (!_firebaseReady) {
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      return;
    }
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    _pushAllowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    final token = await messaging.getToken();
    if (token != null) await _register(token);
    await _tokenRefresh?.cancel();
    _tokenRefresh = messaging.onTokenRefresh.listen(_register);
    await _foreground?.cancel();
    _foreground = FirebaseMessaging.onMessage.listen(_onForeground);
    await _opened?.cancel();
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_openRemote);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRemote(initial));
    }
  }

  Future<void> _register(String token) async {
    if (_stopped) return;
    final repo = ref.read(notificationRepositoryProvider);
    final id = await repo.deviceId();
    final result = await repo.registerDevice(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      deviceId: id,
    );
    _pushRegistered = result.isRight();
  }

  Future<void> _prepareLocalNotifications() async {
    if (_localReady) return;
    await _trayPlugin(_local, onOpen: (response) => _openPayload(response.payload));
    _localReady = true;
  }

  void _onForeground(RemoteMessage message) {
    final row = _fromRemote(message);
    if (row == null) return;
    final inbox = ref.read(notificationInboxProvider);
    final known = inbox.items.any((item) => item.id == row.id);
    ref
        .read(notificationInboxProvider.notifier)
        .upsert(row, known ? inbox.unreadCount : inbox.unreadCount + 1);
    _present(row, fromPush: true);
  }

  /// The socket and FCM can both bring the same row; whichever arrives first shows it.
  void _present(AppNotification row, {required bool fromPush}) {
    if (!_presented.add(row.id)) return;
    final orderId = _orderIdOf(row);
    if (orderId != null) {
      ref.read(orderPingProvider.notifier).ping(orderId);
      ref.invalidate(ordersControllerProvider);
    }

    if (!_resumed) {
      // In the background Android or iOS post the push themselves. While the app is
      // only inactive (the shade is open over it) FCM counts it as foreground and does not.
      final systemPostsIt = !fromPush && _pushActive && _lifecycle != AppLifecycleState.inactive;
      if (!systemPostsIt) unawaited(_showTray(row));
      return;
    }

    final navigator = rootNavigatorKey.currentState;
    final context = rootNavigatorKey.currentContext;
    if (navigator == null || context == null || !context.mounted) {
      unawaited(_showTray(row));
      return;
    }
    final location = GoRouter.of(context).state.uri.toString();
    final target = row.data['target'];
    // The open chat or order page already shows the update live.
    if (target == 'support' && location.startsWith(Routes.help)) return;
    if (orderId != null && location.contains(Routes.order(orderId))) return;

    final productSlug = _text(row.data['product_slug']);
    if (productSlug != null && location.contains(Routes.product(productSlug))) return;

    InAppBanner.show(
      navigator.overlay!,
      look: NotificationLook.of(row.kind, parcelStatus: _text(row.data['parcel_status']) ?? ''),
      title: row.title,
      body: row.body,
      imageUrl: _text(row.data['image']),
      onTap: () => _go(row.id, orderId, target is String ? target : null, productSlug),
    );
    unawaited(_showTray(row, quiet: true));
  }

  Future<void> _showTray(AppNotification row, {bool quiet = false}) async {
    await _prepareLocalNotifications();
    await _postTray(_local, row, quiet: quiet);
  }

  void _openRemote(RemoteMessage message) {
    final row = _fromRemote(message);
    if (row == null) return;
    final target = row.data['target'];
    _go(
      row.id,
      _orderIdOf(row),
      target is String ? target : null,
      _text(row.data['product_slug']),
    );
  }

  void _openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    final id = parts.first;
    final orderId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    final target = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
    final productSlug = parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null;
    _go(id, orderId, target, productSlug);
  }

  void _go(String notificationId, String? orderId, String? target, [String? productSlug]) {
    InAppBanner.hide();
    unawaited(
      ref.read(notificationRepositoryProvider).markRead(notificationId),
    );
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    if (target == 'support') {
      unawaited(dismissTray(supportTrayTag));
      context.push(Routes.help);
      return;
    }
    if (orderId != null && orderId.isNotEmpty) {
      unawaited(dismissTray(orderTrayTag(orderId)));
      context.push(Routes.order(orderId));
      return;
    }
    if (target == 'product' && productSlug != null && productSlug.isNotEmpty) {
      context.push(Routes.product(productSlug));
      return;
    }
    if (target == 'products') {
      context.push(Routes.products);
      return;
    }
    context.push(Routes.notifications);
  }
}

final notificationLifecycleProvider =
    NotifierProvider<NotificationLifecycle, void>(NotificationLifecycle.new);

String? _orderIdOf(AppNotification row) => _text(row.data['order_id']);

AppNotification? _fromRemote(RemoteMessage message) {
  final data = message.data;
  final id = _text(data['notification_id']);
  if (id == null) return null;
  return AppNotification(
    id: id,
    kind: _text(data['kind']) ?? '',
    title: message.notification?.title ?? _text(data['title']) ?? 'PickOrbeet',
    body: message.notification?.body ?? _text(data['body']) ?? '',
    data: {
      for (final entry in data.entries)
        if (entry.value is String && (entry.value as String).isNotEmpty) entry.key: entry.value,
    },
    readAt: null,
    createdAt: message.sentTime ?? DateTime.now(),
  );
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Uri _socketUri(String token) {
  final origin = ServerConstant.origin;
  final ws = origin.startsWith('https://')
      ? origin.replaceFirst('https://', 'wss://')
      : origin.replaceFirst('http://', 'ws://');
  return Uri.parse(
    '$ws/ws/notifications/',
  ).replace(queryParameters: {'token': token});
}
