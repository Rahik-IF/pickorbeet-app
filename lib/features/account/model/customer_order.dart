import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/utils/formatters.dart';

/// The five filters on My Orders. Each one is a mutually exclusive slice of the list.
enum OrderFilter {
  all('All Orders'),
  processing('Processing'),
  shipped('Shipped'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const OrderFilter(this.label);

  final String label;

  /// `order_status` query for this chip. Null lists everything.
  String? get apiStatus => switch (this) {
    OrderFilter.all => null,
    OrderFilter.processing => 'pending,confirmed,processing',
    OrderFilter.shipped => 'shipped,out_for_delivery',
    OrderFilter.delivered => 'delivered',
    OrderFilter.cancelled => 'cancelled,refunded',
  };

  static OrderFilter fromQuery(String? raw) => switch (raw) {
    'processing' ||
    'pending' ||
    'confirmed' ||
    'open' => OrderFilter.processing,
    'shipped' || 'out_for_delivery' => OrderFilter.shipped,
    'delivered' => OrderFilter.delivered,
    'cancelled' || 'refunded' => OrderFilter.cancelled,
    _ => OrderFilter.all,
  };
}

/// How a card is drawn. Several API statuses share one visual treatment.
enum OrderStage { processing, shipped, delivered, cancelled }

/// The first product on an order, which is all the card needs to show.
@immutable
class OrderPreview {
  const OrderPreview({
    required this.name,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    this.productId,
    this.variantId,
    this.slug,
    this.image,
    this.size,
    this.color,
    this.comparePrice,
  });

  final String? productId;
  final String? variantId;
  final String name;
  final String sku;
  final String? slug;
  final String? image;
  final String? size;
  final String? color;
  final int quantity;
  final String unitPrice;
  final String? comparePrice;

  bool get hasCompare {
    final compare = comparePrice;
    if (compare == null || compare.isEmpty) return false;
    return Formatters.decimal(compare) > Formatters.decimal(unitPrice);
  }

  /// `OEB-311 | Black | M`
  String get detailLine {
    final parts = <String>[
      if (sku.trim().isNotEmpty) sku.trim(),
      if ((color ?? '').trim().isNotEmpty) color!.trim(),
      if ((size ?? '').trim().isNotEmpty) size!.trim(),
    ];
    return parts.join(' | ');
  }

  factory OrderPreview.fromMap(Json map) => OrderPreview(
    productId: map.strOrNull('product_id'),
    variantId: map.strOrNull('variant_id'),
    name: map.str('product_name'),
    sku: map.str('product_sku'),
    slug: map.strOrNull('product_slug'),
    image: map.strOrNull('product_image'),
    size: map.strOrNull('size'),
    color: map.strOrNull('color'),
    quantity: map.integer('quantity', 1),
    unitPrice: map.money('unit_price'),
    comparePrice: map.moneyOrNull('compare_price'),
  );
}

/// One row of `GET /orders/my-orders/`.
@immutable
class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.itemCount,
    required this.extraItemCount,
    required this.isInsideDhaka,
    this.createdAt,
    this.shippedAt,
    this.deliveredAt,
    this.updatedAt,
    this.trackingCode,
    this.trackingUrl,
    this.preview,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String total;
  final int itemCount;
  final int extraItemCount;
  final bool isInsideDhaka;
  final DateTime? createdAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? updatedAt;
  final String? trackingCode;
  final String? trackingUrl;
  final OrderPreview? preview;

  OrderStage get stage => switch (status) {
    'shipped' || 'out_for_delivery' => OrderStage.shipped,
    'delivered' => OrderStage.delivered,
    'cancelled' || 'refunded' => OrderStage.cancelled,
    _ => OrderStage.processing,
  };

  /// Index on the Processing → Delivered track.
  int get stepperIndex => switch (status) {
    'shipped' => 1,
    'out_for_delivery' => 2,
    'delivered' => 3,
    _ => 0,
  };

  bool get showStepper =>
      stage == OrderStage.processing || stage == OrderStage.shipped;

  bool get canCancel =>
      status == 'pending' || status == 'confirmed' || status == 'processing';

  String get displayNumber {
    final number = orderNumber.trim();
    if (number.isEmpty) return 'Order';
    return number.startsWith('#') ? number : '#$number';
  }

  String get placedLabel =>
      createdAt == null ? '' : 'Placed on ${Formatters.dateTime(createdAt)}';

  String get badgeLabel => switch (status) {
    'pending' => 'Pending',
    'confirmed' => 'Confirmed',
    'processing' => 'Processing',
    'shipped' => 'Shipped',
    'out_for_delivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'cancelled' => 'Cancelled',
    'refunded' => 'Refunded',
    _ => 'Update',
  };

  String get scheduleLabel => switch (stage) {
    OrderStage.processing => 'Arriving by',
    OrderStage.shipped => 'Expected Delivery',
    OrderStage.delivered => 'Delivered on',
    OrderStage.cancelled =>
      status == 'refunded' ? 'Refunded on' : 'Cancelled on',
  };

  /// Courier ETAs are not on the order yet, so in-progress cards estimate from the order date:
  /// two days inside Dhaka, four outside. A date that has already passed moves to tomorrow.
  DateTime? get scheduleAt {
    switch (stage) {
      case OrderStage.delivered:
        return deliveredAt ?? updatedAt ?? createdAt;
      case OrderStage.cancelled:
        return updatedAt ?? createdAt;
      case OrderStage.processing:
      case OrderStage.shipped:
        final placed = createdAt;
        if (placed == null) return null;
        final eta = placed.add(Duration(days: isInsideDhaka ? 2 : 4));
        if (!_day(eta).isBefore(_day(DateTime.now()))) return eta;
        final tomorrow = _day(DateTime.now()).add(const Duration(days: 1));
        return DateTime.utc(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
        ).subtract(Formatters.dhakaOffset);
    }
  }

  String get scheduleText {
    final date = scheduleAt;
    return date == null ? '' : Formatters.date(date);
  }

  String? get statusNote => switch (status) {
    'refunded' => 'Refund completed',
    'cancelled' => switch (paymentStatus) {
      'failed' || 'pending' => 'Payment not completed',
      'refunded' => 'Payment refunded',
      _ => 'Order was cancelled',
    },
    _ => null,
  };

  factory CustomerOrder.fromMap(Json map) {
    final preview = map.obj('preview_item');
    return CustomerOrder(
      id: map.str('id'),
      orderNumber: map.str('order_number'),
      status: map.str('order_status'),
      paymentStatus: map.str('payment_status'),
      total: map.money('total'),
      itemCount: map.integer('item_count'),
      extraItemCount: map.integer('extra_item_count'),
      isInsideDhaka: map.boolean('is_inside_dhaka'),
      createdAt: map.date('created_at'),
      shippedAt: map.date('shipped_at'),
      deliveredAt: map.date('delivered_at'),
      updatedAt: map.date('updated_at'),
      trackingCode: map.strOrNull('tracking_code'),
      trackingUrl: map.strOrNull('tracking_url'),
      preview: preview == null ? null : OrderPreview.fromMap(preview),
    );
  }
}

DateTime _day(DateTime value) {
  final dhaka = Formatters.toDhaka(value);
  return DateTime(dhaka.year, dhaka.month, dhaka.day);
}
