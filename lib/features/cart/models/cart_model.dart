import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/utils/formatters.dart';

@immutable
class CartOption {
  const CartOption({required this.name, required this.label});

  factory CartOption.fromMap(Json map) => CartOption(
    name: map.str('name'),
    label: map.str('label'),
  );

  final String name;
  final String label;
}

/// One line in `GET /orders/cart/`.
@immutable
class CartItemModel {
  const CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSlug,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.variantId,
    this.productImage,
    this.shortDescription = '',
    this.comparePrice,
    this.discountPercentage = 0,
    this.maxQuantity = 0,
    this.isOutOfStock = false,
    this.size,
    this.color,
    this.options = const [],
  });

  final String id;
  final String productId;
  final String? variantId;
  final String productName;
  final String productSlug;
  final String? productImage;
  final String shortDescription;
  final int quantity;
  final String unitPrice;
  final String totalPrice;
  final String? comparePrice;
  final int discountPercentage;

  /// Most a shopper may pick; 0 when the item can't be bought now. Never the stock count.
  final int maxQuantity;
  final bool isOutOfStock;
  final String? size;
  final String? color;
  final List<CartOption> options;

  /// Customers never see stock counts; this is the ceiling when the server sends none.
  static const orderCeiling = 99;

  bool get hasDiscount => discountPercentage > 0 && comparePrice != null;

  /// `Midnight · 128GB`, or the older color and size pair.
  String get variantLabel {
    if (options.isNotEmpty) {
      return options.map((option) => option.label.trim()).where((label) => label.isNotEmpty).join(' · ');
    }
    return [color, size].whereType<String>().where((v) => v.trim().isNotEmpty).join(' · ');
  }

  factory CartItemModel.fromMap(Json map) {
    final outOfStock = map.boolean('is_out_of_stock');
    return CartItemModel(
      id: map.str('id'),
      productId: map.str('product'),
      variantId: map.strOrNull('variant'),
      productName: map.str('product_name'),
      productSlug: map.str('product_slug'),
      productImage: map.strOrNull('product_image'),
      shortDescription: map.str('short_description'),
      quantity: map.integer('quantity', 1),
      unitPrice: map.money('unit_price'),
      totalPrice: map.money('total_price'),
      comparePrice: map.moneyOrNull('compare_price'),
      discountPercentage: map.integer('discount_percentage'),
      maxQuantity: map.integer(
        'max_quantity',
        map.integer('stock_quantity', outOfStock ? 0 : orderCeiling),
      ),
      isOutOfStock: outOfStock,
      size: map.strOrNull('size'),
      color: map.strOrNull('color'),
      options: map.listOf('options', CartOption.fromMap),
    );
  }

  CartItemModel withQuantity(int value) {
    final total = Formatters.decimal(unitPrice) * Decimal.fromInt(value);
    return CartItemModel(
      id: id,
      productId: productId,
      variantId: variantId,
      productName: productName,
      productSlug: productSlug,
      productImage: productImage,
      shortDescription: shortDescription,
      quantity: value,
      unitPrice: unitPrice,
      totalPrice: total.toString(),
      comparePrice: comparePrice,
      discountPercentage: discountPercentage,
      maxQuantity: maxQuantity,
      isOutOfStock: isOutOfStock,
      size: size,
      color: color,
      options: options,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CartItemModel &&
      other.id == id &&
      other.quantity == quantity &&
      other.unitPrice == unitPrice &&
      other.totalPrice == totalPrice &&
      other.maxQuantity == maxQuantity &&
      other.isOutOfStock == isOutOfStock;

  @override
  int get hashCode => Object.hash(id, quantity, unitPrice, totalPrice, maxQuantity, isOutOfStock);
}

/// The whole cart. Guest carts live in the Django session, signed-in carts on the user.
@immutable
class CartModel {
  const CartModel({
    required this.id,
    required this.items,
    required this.totalItems,
    required this.subtotal,
    this.deliveryInsideDhaka = '70',
    this.deliveryOutsideDhaka = '125',
  });

  static const empty = CartModel(id: '', items: [], totalItems: 0, subtotal: '0');

  final String id;
  final List<CartItemModel> items;

  /// Sum of quantities; drives the badge.
  final int totalItems;
  final String subtotal;
  final String deliveryInsideDhaka;
  final String deliveryOutsideDhaka;

  bool get isEmpty => items.isEmpty;

  factory CartModel.fromMap(Json map) => CartModel(
        id: map.str('id'),
        items: map.listOf('items', CartItemModel.fromMap),
        totalItems: map.integer('total_items'),
        subtotal: map.money('subtotal'),
        deliveryInsideDhaka: map.money('delivery_charge_inside_dhaka', '70'),
        deliveryOutsideDhaka: map.money('delivery_charge_outside_dhaka', '125'),
      );

  /// Rebuilds totals locally for optimistic updates; the server response replaces it.
  CartModel withItems(List<CartItemModel> next) {
    final subtotal = next.fold(Decimal.zero, (sum, item) => sum + Formatters.decimal(item.totalPrice));
    return CartModel(
      id: id,
      items: List.unmodifiable(next),
      totalItems: next.fold(0, (sum, item) => sum + item.quantity),
      subtotal: subtotal.toString(),
      deliveryInsideDhaka: deliveryInsideDhaka,
      deliveryOutsideDhaka: deliveryOutsideDhaka,
    );
  }

  CartItemModel? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CartModel &&
      other.id == id &&
      other.totalItems == totalItems &&
      other.subtotal == subtotal &&
      listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(id, totalItems, subtotal, Object.hashAll(items));
}

/// A coupon the server accepted for a subtotal.
@immutable
class CouponQuote {
  const CouponQuote({required this.code, required this.name, required this.discountAmount});

  factory CouponQuote.fromMap(Json map) {
    final coupon = map.obj('coupon');
    return CouponQuote(
      code: coupon?.str('code') ?? '',
      name: coupon?.str('name') ?? '',
      discountAmount: map.money('discount_amount'),
    );
  }

  final String code;
  final String name;
  final String discountAmount;
}

/// Changes whenever the lines or their totals change, so a voucher quote knows to refresh.
String couponQuoteKey(Iterable<CartItemModel> lines) =>
    [for (final line in lines) '${line.id}:${line.totalPrice}'].join(',');

/// Enough of a cart line to add it again: used for undo and the guest-cart merge.
@immutable
class CartLine {
  const CartLine({required this.productId, required this.quantity, this.variantId});

  final String productId;
  final String? variantId;
  final int quantity;

  factory CartLine.of(CartItemModel item) =>
      CartLine(productId: item.productId, variantId: item.variantId, quantity: item.quantity);
}
