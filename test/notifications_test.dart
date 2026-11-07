import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/features/notifications/in_app_banner.dart';
import 'package:pickorbeet/features/notifications/notification_inbox.dart';
import 'package:pickorbeet/features/notifications/notification_realtime.dart';
import 'package:pickorbeet/features/notifications/notification_repository.dart';

AppNotification _row(String kind, Map<String, dynamic> data, {String id = 'n-1'}) => AppNotification(
      id: id,
      kind: kind,
      title: 'Out for delivery',
      body: 'Parcel is out for delivery\nOrder ORD-1',
      data: data,
      readAt: null,
      createdAt: DateTime.now(),
    );

void main() {
  group('tray tags', () {
    test('updates about one order share a tray entry', () {
      expect(trayTagFor(_row('parcel.update', {'order_id': 'o-1'})), 'order-o-1');
      expect(trayTagFor(_row('order.delivered', {'order_id': 'o-1'})), orderTrayTag('o-1'));
    });

    test('help chat replies share one entry and other notes get their own', () {
      expect(trayTagFor(_row('support.reply', {'target': 'support'})), supportTrayTag);
      expect(trayTagFor(_row('system.notice', {}, id: 'n-9')), 'note-n-9');
    });

    test('the tag the server sent wins', () {
      expect(trayTagFor(_row('parcel.update', {'order_id': 'o-1', 'tag': 'order-o-2'})), 'order-o-2');
    });
  });

  test('parcel updates sit with orders in the inbox', () {
    final item = _row('parcel.update', {'order_id': 'o-1', 'target': 'order'}).toInboxItem();

    expect(item.channel, InboxChannel.orders);
    expect(item.icon, InboxIcon.truck);
    expect(item.orderId, 'o-1');
    expect(item.link, NotificationLink.orders);
  });

  test('a product notification opens that product', () {
    expect(
      routeForNotification(
        kind: 'product.arrival',
        target: 'product',
        productSlug: 'eufy-360-security-indoor-cam',
      ),
      '/product/eufy-360-security-indoor-cam',
    );
    expect(
      routeForNotification(kind: 'promo.sale', productSlug: 'air-max-90'),
      '/product/air-max-90',
    );
    expect(
      routeForNotification(target: 'products'),
      '/products',
    );
  });

  test('an order notification still opens the order', () {
    expect(
      routeForNotification(kind: 'parcel.update', target: 'order', orderId: 'o-1'),
      '/orders/o-1',
    );
    expect(
      routeForNotification(kind: 'support.reply', target: 'support', productSlug: 'air-max-90'),
      '/help',
    );
  });

  test('a new arrival sits with offers and keeps the product photo', () {
    final item = _row('product.arrival', {
      'target': 'product',
      'product_slug': 'air-max-90',
      'image': 'https://example.com/air.jpg',
      'thumb': 'arrivals',
    }).toInboxItem();

    expect(item.channel, InboxChannel.offers);
    expect(item.icon, InboxIcon.star);
    expect(item.productSlug, 'air-max-90');
    expect(item.imageUrl, 'https://example.com/air.jpg');
    expect(item.link, NotificationLink.products);
  });

  test('the banner look follows the parcel status', () {
    expect(NotificationLook.of('support.reply').label, 'Help chat');
    expect(NotificationLook.of('parcel.update', parcelStatus: 'pending').icon, PhosphorIconsFill.truck);
    expect(NotificationLook.of('parcel.update', parcelStatus: 'cancelled').icon, PhosphorIconsFill.warningCircle);
    expect(NotificationLook.of('payment.paid').label, 'Payment');
  });

  group('in-app banner', () {
    Future<OverlayState> pumpHost(WidgetTester tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const Scaffold()));
      return key.currentState!.overlay!;
    }

    void show(OverlayState overlay, VoidCallback onTap) => InAppBanner.show(
          overlay,
          look: NotificationLook.of('parcel.update'),
          title: 'Out for delivery',
          body: 'Parcel is out for delivery',
          onTap: onTap,
        );

    testWidgets('a tap opens it and closes the banner', (tester) async {
      final overlay = await pumpHost(tester);
      var opened = 0;
      show(overlay, () => opened++);
      await tester.pumpAndSettle();

      expect(find.text('Out for delivery'), findsOneWidget);
      expect(find.text('DELIVERY'), findsOneWidget);

      await tester.tap(find.text('Out for delivery'));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.text('Out for delivery'), findsNothing);
    });

    testWidgets('it leaves by itself and on a swipe up', (tester) async {
      final overlay = await pumpHost(tester);
      show(overlay, () {});
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Out for delivery'), findsNothing);

      show(overlay, () {});
      await tester.pumpAndSettle();
      await tester.drag(find.text('Out for delivery'), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(find.text('Out for delivery'), findsNothing);
    });

    testWidgets('a newer banner replaces the one showing', (tester) async {
      final overlay = await pumpHost(tester);
      show(overlay, () {});
      await tester.pumpAndSettle();
      InAppBanner.show(
        overlay,
        look: NotificationLook.of('support.reply'),
        title: 'PickOrbeet Support',
        body: 'Your parcel leaves today',
        onTap: () {},
      );
      await tester.pumpAndSettle();

      expect(find.text('Out for delivery'), findsNothing);
      expect(find.text('PickOrbeet Support'), findsOneWidget);
      InAppBanner.hide();
    });
  });
}
