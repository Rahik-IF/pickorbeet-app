import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickorbeet/features/account/model/order_detail.dart';
import 'package:pickorbeet/features/account/model/shipment.dart';
import 'package:pickorbeet/features/account/view/widgets/shipment_card.dart';

void main() {
  test('parses a courier parcel and its updates', () {
    final shipment = Shipment.fromMap({
      'courier_name': 'Steadfast Courier',
      'tracking_code': 'SF123456789BD',
      'tracking_url': 'https://steadfast.com.bd/t/SF123456789BD',
      'status': 'in_review',
      'status_group': 'in_review',
      'status_label': 'In review',
      'status_message': 'Parcel booked with Steadfast Courier.',
      'cod_amount': '1080.00',
      'is_final': false,
      'refresh_available_in': 0,
      'events': [
        {
          'source': 'booking',
          'status': 'in_review',
          'status_group': 'in_review',
          'message': 'Consignment has been created successfully.',
          'created_at': '2026-10-24T00:00:00Z',
        },
      ],
    });

    expect(shipment.statusLabel, 'In review');
    expect(shipment.events.single.title, 'In review');
    expect(shipment.hasCode, isTrue);
  });

  test('public tracking accepts a parcel without booking internals', () {
    final result = TrackingResult.fromMap({
      'id': 'order-1',
      'order_number': 'PO1',
      'tracking_number': 'REF1',
      'order_status': 'shipped',
      'payment_status': 'pending',
      'shipment': {
        'courier_name': 'Steadfast Courier',
        'tracking_code': 'SF1',
        'status': 'pending',
        'status_group': 'pending',
        'status_label': 'Pending',
        'events': [],
      },
    });

    expect(result.displayNumber, '#PO1');
    expect(result.shipment!.statusGroup, 'pending');
    expect(result.statusLabel, 'Shipped');
  });

  testWidgets('shipment card shows the code, cash to collect, and refresh', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShipmentCard(
            shipment: Shipment.fromMap({
              'courier_name': 'Steadfast Courier',
              'tracking_code': 'SF123456789BD',
              'tracking_url': 'https://steadfast.com.bd/t/SF123456789BD',
              'status': 'pending',
              'status_group': 'pending',
              'status_label': 'Pending',
              'cod_amount': '540.00',
              'events': [
                {'source': 'poll', 'status': 'pending', 'message': 'Out for delivery'},
              ],
            }),
            onRefresh: () {},
            onOpenTracking: () {},
            onCopy: () {},
          ),
        ),
      ),
    );

    expect(find.text('Steadfast Courier'), findsOneWidget);
    expect(find.text('SF123456789BD'), findsOneWidget);
    expect(find.text('Pending'), findsNWidgets(2));
    expect(find.textContaining('Cash to pay the rider'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Open Steadfast'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
