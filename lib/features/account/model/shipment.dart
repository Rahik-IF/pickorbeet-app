import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/network/json.dart';

/// One courier report: the booking, a status check, or a webhook.
@immutable
class ShipmentEvent {
  const ShipmentEvent({
    required this.source,
    required this.status,
    required this.message,
    this.id,
    this.statusGroup,
    this.occurredAt,
    this.createdAt,
  });

  final String? id;
  final String source;
  final String status;
  final String? statusGroup;
  final String message;
  final DateTime? occurredAt;
  final DateTime? createdAt;

  DateTime? get at => occurredAt ?? createdAt;

  String get title {
    final raw = status.isNotEmpty ? status : source;
    if (raw.isEmpty) return 'Update';
    final words = raw.replaceAll('_', ' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  factory ShipmentEvent.fromMap(Json map) => ShipmentEvent(
    id: map.strOrNull('id'),
    source: map.str('source'),
    status: map.str('status'),
    statusGroup: map.strOrNull('status_group'),
    message: map.str('message'),
    occurredAt: map.date('occurred_at'),
    createdAt: map.date('created_at'),
  );
}

/// A Steadfast parcel. Public tracking omits booking internals, so every extra field is optional.
@immutable
class Shipment {
  const Shipment({
    required this.courierName,
    required this.status,
    required this.statusGroup,
    required this.statusLabel,
    required this.statusMessage,
    required this.isFinal,
    required this.refreshAvailableIn,
    required this.events,
    this.id,
    this.consignmentId,
    this.trackingCode,
    this.trackingUrl,
    this.codAmount,
    this.deliveryCharge,
    this.note,
    this.bookedByName,
    this.bookedAt,
    this.statusUpdatedAt,
  });

  final String? id;
  final String courierName;
  final String? consignmentId;
  final String? trackingCode;
  final String? trackingUrl;
  final String status;
  final String statusGroup;
  final String statusLabel;
  final String statusMessage;
  final bool isFinal;
  final int refreshAvailableIn;
  final String? codAmount;
  final String? deliveryCharge;
  final String? note;
  final String? bookedByName;
  final DateTime? bookedAt;
  final DateTime? statusUpdatedAt;
  final List<ShipmentEvent> events;

  bool get hasCode => (trackingCode ?? '').isNotEmpty;

  factory Shipment.fromMap(Json map) => Shipment(
    id: map.strOrNull('id'),
    courierName: map.str('courier_name', 'Steadfast Courier'),
    consignmentId: map.strOrNull('consignment_id'),
    trackingCode: map.strOrNull('tracking_code'),
    trackingUrl: map.strOrNull('tracking_url'),
    status: map.str('status'),
    statusGroup: map.str('status_group', 'unknown'),
    statusLabel: map.str('status_label', 'Update'),
    statusMessage: map.str('status_message'),
    isFinal: map.boolean('is_final'),
    refreshAvailableIn: map.integer('refresh_available_in'),
    codAmount: map.moneyOrNull('cod_amount'),
    deliveryCharge: map.moneyOrNull('delivery_charge'),
    note: map.strOrNull('note'),
    bookedByName: map.strOrNull('booked_by_name'),
    bookedAt: map.date('booked_at'),
    statusUpdatedAt: map.date('status_updated_at'),
    events: map.listOf('events', ShipmentEvent.fromMap),
  );
}
