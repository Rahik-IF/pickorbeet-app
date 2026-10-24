import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/support/help_models.dart';

class SupportRepository {
  const SupportRepository(this._api);

  final ApiClient _api;

  Future<Either<AppFailure, HelpThread>> fetchThread() => guardRequest(
    () => _api.get('/support/conversation/'),
    (body) => HelpThread.fromJson(asJson(body)),
  );

  Future<Either<AppFailure, HelpMessage>> send({
    String body = '',
    String topic = '',
    String orderNumber = '',
    List<int>? imageBytes,
    String? filename,
  }) {
    final fields = <String, String>{
      if (body.isNotEmpty) 'body': body,
      if (topic.isNotEmpty) 'topic': topic,
      if (orderNumber.isNotEmpty) 'order_number': orderNumber,
    };
    if (imageBytes != null && filename != null) {
      return guardRequest(
        () => _api.postFile(
          '/support/messages/',
          fields: fields,
          fileField: 'image',
          filename: filename,
          bytes: imageBytes,
        ),
        (body) => HelpMessage.fromJson(asJson(body)),
        success: const {201},
      );
    }
    return guardRequest(
      () => _api.post('/support/messages/', body: fields),
      (body) => HelpMessage.fromJson(asJson(body)),
      success: const {201},
    );
  }

  Future<void> markRead() async {
    try {
      await _api.post('/support/read/');
    } on Object {
      // The next open marks the thread read if this call does not land.
    }
  }
}

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(ref.watch(apiClientProvider)),
);
