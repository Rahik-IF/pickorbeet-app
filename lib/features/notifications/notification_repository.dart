import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';

/// One saved inbox row from `GET /notifications/`.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final Json data;
  final DateTime? readAt;
  final DateTime createdAt;

  factory AppNotification.fromJson(Json json) => AppNotification(
        id: json.str('id'),
        kind: json.str('kind'),
        title: json.str('title'),
        body: json.str('body'),
        data: json.obj('data') ?? const {},
        readAt: json.date('read_at'),
        createdAt: json.date('created_at') ?? DateTime.now(),
      );
}

class LoadedInbox {
  const LoadedInbox({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;
}

class NotificationRepository {
  const NotificationRepository(this._api, this._ref);

  final ApiClient _api;
  final Ref _ref;

  static const _deviceKey = 'notification_device_id';

  Future<String> deviceId() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final existing = prefs.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _randomId();
    await prefs.setString(_deviceKey, created);
    return created;
  }

  Future<Either<AppFailure, LoadedInbox>> fetchInbox() async {
    final rows = <AppNotification>[];
    var pageNumber = 1;
    while (pageNumber <= 10) {
      final page = await guardRequest(
        () => _api.get('/notifications/', query: {'page': pageNumber}),
        asJson,
      );
      if (page.isLeft()) return page.map((_) => const LoadedInbox(items: [], unreadCount: 0));
      final json = page.getOrElse((_) => const {});
      rows.addAll(json.listOf('results', AppNotification.fromJson));
      if (json.strOrNull('next') == null) break;
      pageNumber++;
    }
    final unread = await guardRequest(
      () => _api.get('/notifications/unread-count/'),
      (body) => asJson(body).integer('unread_count'),
    );
    return unread.map((count) => LoadedInbox(items: rows, unreadCount: count));
  }

  Future<Either<AppFailure, void>> markRead(String id) => guardRequest(
        () => _api.post('/notifications/$id/read/'),
        (_) {},
      );

  Future<Either<AppFailure, void>> registerDevice({
    required String token,
    required String platform,
    required String deviceId,
  }) =>
      guardRequest(
        () => _api.put('/notifications/devices/', body: {
          'token': token,
          'platform': platform,
          'device_id': deviceId,
        }),
        (_) {},
      );

  Future<Either<AppFailure, void>> unregisterThisDevice() async {
    final id = _ref.read(sharedPreferencesProvider).getString(_deviceKey);
    if (id == null || id.isEmpty) return const Right(null);
    if (_ref.read(authLocalRepositoryProvider).getAccessToken() == null) return const Right(null);
    return guardRequest(
      () => _api.delete('/notifications/devices/$id/'),
      (_) {},
      success: const {204},
    );
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider), ref),
);

String _randomId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
