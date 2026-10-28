import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/features/account/model/customer_order.dart';
import 'package:pickorbeet/features/account/model/shipment.dart';

/// One line on an order, with the price the customer paid.
@immutable
class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.image,
    this.detail = '',
  });

  final String name;
  final String? image;
  final String detail;
  final int quantity;
  final String unitPrice;
  final String totalPrice;

  factory OrderLine.fromMap(Json map) {
    final chosen = [
      for (final option in map.listOf('options', (json) => json))
        option.str('label').trim(),
    ].where((label) => label.isNotEmpty);
    final parts = <String>[
      if (map.str('product_sku').trim().isNotEmpty) map.str('product_sku').trim(),
      if (chosen.isNotEmpty)
        ...chosen
      else ...[
        if (map.str('color').trim().isNotEmpty) map.str('color').trim(),
        if (map.str('size').trim().isNotEmpty) map.str('size').trim(),
      ],
    ];
    return OrderLine(
      name: map.str('product_name', 'Item'),
      image: map.strOrNull('product_image'),
      detail: parts.join(' | '),
      quantity: map.integer('quantity', 1),
      unitPrice: map.money('unit_price'),
      totalPrice: map.money('total_price'),
    );
  }
}

/// A row in the store's own status history.
@immutable
class StatusEntry {
  const StatusEntry({required this.status, required this.note, this.createdAt, this.changedByName});

  final String status;
  final String note;
  final DateTime? createdAt;
  final String? changedByName;

  String get label => orderStatusLabel(status);

  factory StatusEntry.fromMap(Json map) => StatusEntry(
    status: map.str('status'),
    note: map.str('note'),
    createdAt: map.date('created_at'),
    changedByName: map.strOrNull('changed_by_name'),
  );
}

/// `GET /orders/my-orders/{id}/` and the body returned after a courier refresh.
@immutable
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryCharge,
    required this.discount,
    required this.total,
    required this.shippingName,
    required this.shippingPhone,
    required this.address,
    required this.items,
    required this.history,
    this.paymentMethod,
    this.notes,
    this.createdAt,
    this.shipment,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String subtotal;
  final String deliveryCharge;
  final String discount;
  final String total;
  final String shippingName;
  final String shippingPhone;
  final String address;
  final String? notes;
  final DateTime? createdAt;
  final List<OrderLine> items;
  final List<StatusEntry> history;
  final Shipment? shipment;

  String get displayNumber {
    final number = orderNumber.trim();
    if (number.isEmpty) return 'Order';
    return number.startsWith('#') ? number : '#$number';
  }

  String get statusLabel => orderStatusLabel(status);

  factory OrderDetail.fromMap(Json map) {
    final lines = <String>[
      map.str('shipping_address_line1'),
      map.str('shipping_address_line2'),
      [map.str('shipping_city'), map.str('shipping_district')].where((part) => part.isNotEmpty).join(', '),
      map.str('shipping_postal_code'),
    ].where((part) => part.trim().isNotEmpty);
    return OrderDetail(
      id: map.str('id'),
      orderNumber: map.str('order_number'),
      status: map.str('order_status'),
      paymentStatus: map.str('payment_status'),
      paymentMethod: map.strOrNull('payment_method'),
      subtotal: map.money('subtotal'),
      deliveryCharge: map.money('delivery_charge'),
      discount: map.money('discount'),
      total: map.money('total'),
      shippingName: map.str('shipping_name'),
      shippingPhone: map.str('shipping_phone'),
      address: lines.join('\n'),
      notes: map.strOrNull('notes'),
      createdAt: map.date('created_at'),
      items: map.listOf('items', OrderLine.fromMap),
      history: map.listOf('status_history', StatusEntry.fromMap),
      shipment: map.obj('shipment') == null ? null : Shipment.fromMap(map.obj('shipment')!),
    );
  }
}

/// `POST /orders/track/`. Guests can read it. Refresh needs the signed-in owner and [id].
@immutable
class TrackingResult {
  const TrackingResult({
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.history,
    this.id,
    this.reference,
    this.createdAt,
    this.shippedAt,
    this.deliveredAt,
    this.shipment,
  });

  final String? id;
  final String orderNumber;
  final String? reference;
  final String status;
  final String paymentStatus;
  final DateTime? createdAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final List<StatusEntry> history;
  final Shipment? shipment;

  String get displayNumber {
    final number = orderNumber.trim();
    return number.startsWith('#') ? number : '#$number';
  }

  String get statusLabel => orderStatusLabel(status);

  factory TrackingResult.fromMap(Json map) => TrackingResult(
    id: map.strOrNull('id'),
    orderNumber: map.str('order_number'),
    reference: map.strOrNull('tracking_number'),
    status: map.str('order_status'),
    paymentStatus: map.str('payment_status'),
    createdAt: map.date('created_at'),
    shippedAt: map.date('shipped_at'),
    deliveredAt: map.date('delivered_at'),
    history: map.listOf('status_history', StatusEntry.fromMap),
    shipment: map.obj('shipment') == null ? null : Shipment.fromMap(map.obj('shipment')!),
  );
}
