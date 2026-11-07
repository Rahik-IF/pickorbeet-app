import 'package:flutter_test/flutter_test.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/vouchers/model/store_voucher.dart';

StoreVoucher _voucher(
  String code, {
  String state = 'available',
  bool? applies,
  String? reason,
  String? saving,
}) =>
    StoreVoucher.fromApi({
      'id': code,
      'code': code,
      'name': '$code offer',
      'discount_type': 'fixed',
      'discount_value': '100.00',
      'minimum_order_amount': '0.00',
      'valid_until': '2026-12-31T00:00:00Z',
      'state': state,
      'applies': applies,
      'reason': reason,
      'estimated_discount': saving,
    });

CartItemModel _line(String id, String total) => CartItemModel(
      id: id,
      productId: 'p-$id',
      productName: 'Item $id',
      productSlug: 'item-$id',
      quantity: 1,
      unitPrice: total,
      totalPrice: total,
      maxQuantity: 99,
    );

void main() {
  test('wallet rows carry whether they cover the selected lines', () {
    final voucher = _voucher('BIG', applies: false, reason: 'Minimum order amount of ৳5000 required.');
    expect(voucher.applies, isFalse);
    expect(voucher.reason, contains('Minimum'));
    expect(_voucher('PLAIN').applies, isNull);
  });

  test('the cart sheet lists usable vouchers first, biggest saving first', () {
    final ordered = cartVouchers([
      _voucher('SMALL', applies: true, saving: '50.00'),
      _voucher('NOPE', applies: false, reason: "This voucher doesn't apply to the items you selected."),
      _voucher('USED', state: 'used'),
      _voucher('BIG', applies: true, saving: '300.00'),
      _voucher('OLD', state: 'expired'),
    ]);
    expect([for (final voucher in ordered) voucher.code], ['BIG', 'SMALL', 'NOPE']);
  });

  test('the quote key changes with the selected lines and their totals', () {
    final a = _line('a', '100.00');
    final b = _line('b', '250.00');
    expect(couponQuoteKey([a, b]), couponQuoteKey([a, b]));
    expect(couponQuoteKey([a]), isNot(couponQuoteKey([a, b])));
    expect(couponQuoteKey([a.withQuantity(2), b]), isNot(couponQuoteKey([a, b])));
  });
}
