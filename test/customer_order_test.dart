import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickorbeet/features/account/model/customer_order.dart';
import 'package:pickorbeet/features/account/view/orders_palette.dart';
import 'package:pickorbeet/features/account/view/widgets/order_card.dart';

void main() {
  test('parses a processing order and estimates arrival inside Dhaka', () {
    final order = CustomerOrder.fromMap({
      'id': '1',
      'order_number': 'PO783256',
      'order_status': 'processing',
      'payment_status': 'pending',
      'total': '1080.00',
      'item_count': 1,
      'extra_item_count': 0,
      'is_inside_dhaka': true,
      'created_at': '2027-01-20T04:24:00Z',
      'preview_item': {
        'product_id': 'p1',
        'product_name': 'Oraimo Necklace Lite',
        'product_sku': 'OEB-311',
        'color': 'Black',
        'quantity': 1,
        'unit_price': '1080.00',
        'compare_price': '1500.00',
      },
    });

    expect(order.displayNumber, '#PO783256');
    expect(order.stage, OrderStage.processing);
    expect(order.badgeLabel, 'Processing');
    expect(order.scheduleLabel, 'Arriving by');
    expect(order.canCancel, isTrue);
    expect(order.preview!.detailLine, 'OEB-311 | Black');
    expect(order.preview!.hasCompare, isTrue);
    expect(order.placedLabel, 'Placed on 20 Jan 2027, 10:24 AM');
    expect(order.scheduleText, '22 Jan 2027');
  });

  test('cancelled orders explain an unfinished payment', () {
    final order = CustomerOrder.fromMap({
      'id': '2',
      'order_number': 'PO783156',
      'order_status': 'cancelled',
      'payment_status': 'pending',
      'total': '1200.00',
      'updated_at': '2026-10-06T03:30:00Z',
    });

    expect(order.stage, OrderStage.cancelled);
    expect(order.canCancel, isFalse);
    expect(order.statusNote, 'Payment not completed');
    expect(order.scheduleLabel, 'Cancelled on');
  });

  test('filter query maps account shortcuts onto the chips', () {
    expect(OrderFilter.fromQuery(null), OrderFilter.all);
    expect(OrderFilter.fromQuery('open'), OrderFilter.processing);
    expect(OrderFilter.fromQuery('shipped'), OrderFilter.shipped);
    expect(OrderFilter.fromQuery('refunded'), OrderFilter.cancelled);
  });

  testWidgets('processing card shows the design actions and progress', (
    tester,
  ) async {
    final order = CustomerOrder.fromMap({
      'id': '1',
      'order_number': 'PO783256',
      'order_status': 'processing',
      'payment_status': 'pending',
      'total': '1080.00',
      'created_at': '2027-01-20T04:24:00Z',
      'is_inside_dhaka': true,
      'preview_item': {
        'product_name': 'Oraimo Necklace Lite',
        'product_sku': 'OEB-311',
        'color': 'Black',
        'quantity': 1,
        'unit_price': '1080.00',
        'compare_price': '1500.00',
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderCard(
            order: order,
            onDetails: () {},
            onCancel: () {},
            onTrack: () {},
            onBuyAgain: () {},
            onReview: () {},
          ),
        ),
      ),
    );

    expect(find.text('#PO783256'), findsOneWidget);
    expect(find.text('Oraimo Necklace Lite'), findsOneWidget);
    expect(find.text('Arriving by'), findsOneWidget);
    expect(find.text('22 Jan 2027'), findsOneWidget);
    expect(find.text('Cancel Order'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Processing'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('four stages fit a phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    CustomerOrder order(String status, String payment) =>
        CustomerOrder.fromMap({
          'id': status,
          'order_number': 'PO783256',
          'order_status': status,
          'payment_status': payment,
          'total': '1080.00',
          'created_at': '2027-01-20T04:24:00Z',
          'updated_at': '2027-01-22T03:30:00Z',
          'delivered_at': status == 'delivered' ? '2027-01-22T03:30:00Z' : null,
          'is_inside_dhaka': true,
          'preview_item': {
            'product_name': 'Oraimo Necklace Lite',
            'product_sku': 'OEB-311',
            'color': 'Black',
            'quantity': 1,
            'unit_price': '1080.00',
            'compare_price': '1500.00',
          },
        });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            backgroundColor: OrdersPalette.page,
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: const Key('shot'),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    children: [
                      for (final sample in [
                        order('processing', 'pending'),
                        order('shipped', 'pending'),
                        order('delivered', 'paid'),
                        order('cancelled', 'pending'),
                      ]) ...[
                        OrderCard(
                          order: sample,
                          onDetails: () {},
                          onCancel: () {},
                          onTrack: () {},
                          onBuyAgain: () {},
                          onReview: () {},
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cancel Order'), findsOneWidget);
    expect(find.text('Track Order'), findsOneWidget);
    expect(find.text('Buy Again'), findsOneWidget);
    expect(find.text('Write a Review'), findsOneWidget);
    expect(find.text('Payment not completed'), findsOneWidget);
    expect(find.text('View Details'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
