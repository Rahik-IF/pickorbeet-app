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
import 'package:pickorbeet/core/router/app_router.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/notifications/notification_inbox.dart';
import 'package:pickorbeet/features/notifications/notification_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _ordersChannel = AndroidNotificationChannel(
  'orders',
  'Orders',
  description: 'Order and payment updates',
  importance: Importance.high,
);

/// Shown by the system when a message arrives and the app is not in the foreground.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

bool _firebaseReady = false;

/// Starts Firebase when the platform config files are present. Missing files leave push off.
Future<void> startFirebase() async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _firebaseReady = true;
  } on Object {
    _firebaseReady = false;
  }
}

/// Keeps the live socket and the phone token in step with the signed-in session.
class NotificationLifecycle extends Notifier<void> {
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  Timer? _retry;
  int _generation = 0;
  var _stopped = true;
  var _socketConnected = false;
  final _presented = <String>{};
  final _local = FlutterLocalNotificationsPlugin();
  var _localReady = false;

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
      unawaited(stop());
    });
    if (ref.read(sessionNotifierProvider) == SessionStatus.signedIn) {
      Future.microtask(start);
    }
  }

  Future<void> start() async {
    if (ref.read(sessionNotifierProvider) != SessionStatus.signedIn) return;
    _stopped = false;
    await ref.read(notificationInboxProvider.notifier).reload();
    await _connect(forceRefresh: false);
    await _startPush();
  }

  Future<void> stop() async {
    _stopped = true;
    _generation++;
    _retry?.cancel();
    _socketConnected = false;
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

  Future<void> _connect({required bool forceRefresh}) async {
    if (_stopped) return;
    final generation = ++_generation;
    _retry?.cancel();
    await _socketSub?.cancel();
    await _socket?.sink.close();
    _socket = null;
    _socketConnected = false;

    final token = await ref.read(apiClientProvider).ensureAccess(force: forceRefresh);
    if (_stopped || generation != _generation) return;
    if (token == null) return;

    final channel = WebSocketChannel.connect(_socketUri(token));
    _socket = channel;
    unawaited(channel.ready.then((_) {
      if (!_stopped && generation == _generation) _socketConnected = true;
    }, onError: (_) {}));
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
    final delay = Duration(seconds: (1 << (_generation.clamp(0, 5))).clamp(1, 30));
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
      ref.read(notificationInboxProvider.notifier).setUnreadCount(json.integer('unread_count'));
      return;
    }
    if (type != 'notification.created') return;
    final rowJson = json.obj('notification');
    if (rowJson == null) return;
    final row = AppNotification.fromJson(rowJson);
    ref.read(notificationInboxProvider.notifier).upsert(row, json.integer('unread_count'));
    _present(row, local: false);
  }

  Future<void> _startPush() async {
    if (!_firebaseReady) return;
    await _prepareLocalNotifications();
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
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
    await repo.registerDevice(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      deviceId: id,
    );
  }

  Future<void> _prepareLocalNotifications() async {
    if (_localReady) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: ios),
      onDidReceiveNotificationResponse: (response) => _openPayload(response.payload),
    );
    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_ordersChannel);
    await androidPlugin?.requestNotificationsPermission();
    _localReady = true;
  }

  void _onForeground(RemoteMessage message) {
    if (_socketConnected) return;
    final row = _fromRemote(message);
    if (row == null) return;
    final inbox = ref.read(notificationInboxProvider);
    final known = inbox.items.any((item) => item.id == row.id);
    ref.read(notificationInboxProvider.notifier).upsert(row, known ? inbox.unreadCount : inbox.unreadCount + 1);
    _present(row, local: true);
  }

  void _present(AppNotification row, {required bool local}) {
    if (!_presented.add(row.id)) return;
    if (local) {
      unawaited(_showLocal(row));
      return;
    }
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final location = GoRouter.of(context).state.uri.toString();
    final orderId = row.data['order_id'];
    if (orderId is String && location.contains('/orders/$orderId')) return;
    showToast(context, row.body.isEmpty ? row.title : row.body);
  }

  Future<void> _showLocal(AppNotification row) async {
    await _prepareLocalNotifications();
    final orderId = row.data['order_id'];
    await _local.show(
      row.id.hashCode,
      row.title,
      row.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'orders',
          'Orders',
          channelDescription: 'Order and payment updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: '${row.id}|${orderId is String ? orderId : ''}',
    );
  }

  void _openRemote(RemoteMessage message) {
    final row = _fromRemote(message);
    if (row == null) return;
    final orderId = row.data['order_id'];
    _go(row.id, orderId is String ? orderId : null);
  }

  void _openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    final id = parts.first;
    final orderId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    _go(id, orderId);
  }

  void _go(String notificationId, String? orderId) {
    unawaited(ref.read(notificationRepositoryProvider).markRead(notificationId));
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    if (orderId != null && orderId.isNotEmpty) {
      context.push(Routes.order(orderId));
      return;
    }
    context.push(Routes.notifications);
  }
}

final notificationLifecycleProvider = NotifierProvider<NotificationLifecycle, void>(NotificationLifecycle.new);

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
      'order_id': _text(data['order_id']),
      'order_number': _text(data['order_number']),
      'target': _text(data['target']),
      'status': _text(data['status']),
    },
    readAt: null,
    createdAt: DateTime.now(),
  );
}

String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;

Uri _socketUri(String token) {
  final origin = ServerConstant.origin;
  final ws = origin.startsWith('https://')
      ? origin.replaceFirst('https://', 'wss://')
      : origin.replaceFirst('http://', 'ws://');
  return Uri.parse('$ws/ws/notifications/').replace(queryParameters: {'token': token});
}
