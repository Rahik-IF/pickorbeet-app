import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/widgets/quantity_stepper.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';

Map<String, Object?> _line(Map<String, Object?> extra) => {
      'id': 'line-1',
      'product': 'p1',
      'product_name': 'Baseus Cable',
      'product_slug': 'baseus-cable',
      'quantity': 3,
      'unit_price': '500.00',
      'total_price': '1500.00',
      ...extra,
    };

Future<List<int>> _pumpStepper(
  WidgetTester tester, {
  required int value,
  required int max,
  bool canIncrease = true,
}) async {
  final changes = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: QuantityStepper(
            value: value,
            max: max,
            canIncrease: canIncrease,
            onChanged: changes.add,
          ),
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  group('cart line limits', () {
    test('reads max_quantity from the server', () {
      final line = CartItemModel.fromMap(_line({'max_quantity': 99, 'stock_quantity': 99}));
      expect(line.maxQuantity, 99);
      expect(line.isOutOfStock, isFalse);
    });

    test('falls back to stock_quantity, then to the ceiling when available', () {
      expect(CartItemModel.fromMap(_line({'stock_quantity': 7})).maxQuantity, 7);
      expect(CartItemModel.fromMap(_line({})).maxQuantity, CartItemModel.orderCeiling);
      expect(
        CartItemModel.fromMap(_line({'is_out_of_stock': true})).maxQuantity,
        0,
      );
    });

    test('keeps the limit through optimistic quantity changes', () {
      final line = CartItemModel.fromMap(_line({'max_quantity': 99}));
      expect(line.withQuantity(4).maxQuantity, 99);
    });
  });

  group('quantity stepper', () {
    testWidgets('plus and minus both work below the limit', (tester) async {
      final changes = await _pumpStepper(tester, value: 2, max: 99);
      await tester.tap(find.byIcon(PhosphorIconsBold.plus));
      await tester.tap(find.byIcon(PhosphorIconsBold.minus));
      expect(changes, [3, 1]);
    });

    testWidgets('an unavailable line can still go down but not up', (tester) async {
      final changes = await _pumpStepper(tester, value: 3, max: 0, canIncrease: false);
      await tester.tap(find.byIcon(PhosphorIconsBold.plus));
      await tester.tap(find.byIcon(PhosphorIconsBold.minus));
      expect(changes, [2]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('plus stops at the limit', (tester) async {
      final changes = await _pumpStepper(tester, value: 99, max: 99);
      await tester.tap(find.byIcon(PhosphorIconsBold.plus));
      expect(changes, isEmpty);
    });
  });
}
