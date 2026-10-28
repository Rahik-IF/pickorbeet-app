import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/checkout/checkout_args.dart';
import 'package:pickorbeet/features/checkout/checkout_logic.dart';
import 'package:pickorbeet/features/checkout/checkout_repository.dart';
import 'package:pickorbeet/features/checkout/view/checkout_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _powerBank = CartItemModel(
  id: 'line-1',
  productId: 'power',
  productName: 'Hoco J154A 22.5W + PD20W 20000mAh Power Bank',
  productSlug: 'hoco-j154a',
  quantity: 1,
  unitPrice: '1450',
  totalPrice: '1450',
  shortDescription: '22.5W and PD 20W Output',
  comparePrice: '1850',
  discountPercentage: 21,
  stockQuantity: 8,
);

const _cart = CartModel(
  id: 'cart',
  items: [_powerBank],
  totalItems: 1,
  subtotal: '1450',
);

const _home = AddressModel(
  id: 'home',
  fullName: 'Sayed Muhit Al Rafi',
  phone: '01712345678',
  addressLine1: '544/2B, Nandonik Dream Tower, 6th floor',
  addressLine2: 'East Kazipara, Mirpur',
  city: 'Dhaka',
  district: 'Dhaka',
  postalCode: '1216',
  label: 'Home',
  isDefault: true,
  isInsideDhaka: true,
);

const _office = AddressModel(
  id: 'office',
  fullName: 'Sayed Muhit Al Rafi',
  phone: '01712345678',
  addressLine1: 'Orbeetal, House 12, Road 3, Block B',
  addressLine2: 'Niketon, Gulshan',
  city: 'Dhaka',
  district: 'Dhaka',
  postalCode: '1212',
  label: 'Office',
);

class _SignedIn extends SessionNotifier {
  @override
  SessionStatus build() => SessionStatus.signedIn;
}

class _CheckoutCart extends CartNotifier {
  @override
  Future<CartModel> build() async => _cart;
}

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String name) async =>
      ByteData.view((await File(name).readAsBytes()).buffer);
  final inter = FontLoader('Inter')
    ..addFont(bytes('assets/fonts/Inter-Regular.ttf'))
    ..addFont(bytes('assets/fonts/Inter-Medium.ttf'))
    ..addFont(bytes('assets/fonts/Inter-SemiBold.ttf'))
    ..addFont(bytes('assets/fonts/Inter-Bold.ttf'))
    ..addFont(bytes('assets/fonts/Inter-ExtraBold.ttf'));
  final display = FontLoader('InterDisplay')
    ..addFont(bytes('assets/fonts/InterDisplay-Bold.ttf'));
  final icons = FontLoader('packages/phosphor_flutter/PhosphorRegular')
    ..addFont(
      rootBundle.load('packages/phosphor_flutter/lib/fonts/Phosphor.ttf'),
    );
  final iconsBold = FontLoader('packages/phosphor_flutter/PhosphorBold')
    ..addFont(
      rootBundle.load('packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf'),
    );
  final iconsFill = FontLoader('packages/phosphor_flutter/PhosphorFill')
    ..addFont(
      rootBundle.load('packages/phosphor_flutter/lib/fonts/Phosphor-Fill.ttf'),
    );
  final bengali = FontLoader('NotoSansBengali')
    ..addFont(bytes('assets/fonts/NotoSansBengali-Regular.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-Medium.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-SemiBold.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-Bold.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-ExtraBold.ttf'));
  await Future.wait([
    inter.load(),
    display.load(),
    icons.load(),
    iconsBold.load(),
    iconsFill.load(),
    bengali.load(),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('address lines and the checkout body match the design', () {
    expect(checkoutAddressLines(_home), [
      '544/2B, Nandonik Dream Tower, 6th floor',
      'East Kazipara, Mirpur, Dhaka-1216',
    ]);
    expect(
      checkoutContactLine(_home),
      'Sayed Muhit Al Rafi | +880 1712-345678',
    );
    expect(shipsInsideDhaka(city: 'Dhaka', district: 'Dhaka'), isTrue);
    expect(
      shipsInsideDhaka(city: 'Chattogram', district: 'Chattogram'),
      isFalse,
    );

    final body = checkoutPayload(
      name: _home.fullName,
      phone: _home.phone,
      line1: _home.addressLine1,
      line2: _home.addressLine2,
      city: _home.city,
      district: _home.district,
      postalCode: _home.postalCode,
      itemIds: const ['line-1'],
      payment: CheckoutPayment.bkash,
      couponCode: 'SAVE10',
    );
    expect(body['shipping_phone'], '01712345678');
    expect(body['payment_method'], 'bkash');
    expect(body['item_ids'], ['line-1']);
    expect(body['coupon_code'], 'SAVE10');
    expect(body.containsKey('guest_name'), isFalse);
    expect(Formatters.money('1510'), '৳ 1,510');
  });

  test('checkout keeps the cart selection on the url', () {
    const args = CheckoutArgs(
      itemIds: ['line-1', 'line-2'],
      couponCode: 'SAVE10',
    );
    final uri = Uri.parse('https://pickorbeet.com${args.location}');
    final restored = CheckoutArgs.fromUri(uri);
    expect(restored.itemIds, ['line-1', 'line-2']);
    expect(restored.couponCode, 'SAVE10');
  });

  testWidgets('checkout page matches the delivery design', (tester) async {
    await tester.runAsync(_loadFonts);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(411, 1700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 1700);
    tester.view.padding = const FakeViewPadding(top: 47);
    tester.view.viewPadding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionNotifierProvider.overrideWith(_SignedIn.new),
          checkoutAddressesProvider.overrideWith(
            (ref) async => const [_home, _office],
          ),
          cartNotifierProvider.overrideWith(_CheckoutCart.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CheckoutPage(args: CheckoutArgs(itemIds: ['line-1'])),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(CheckoutPage));
      await precacheImage(
        const AssetImage('assets/brand/bag_mark_on_dark.png'),
        context,
      );
      await precacheImage(
        const AssetImage('assets/brand/bkash.png'),
        context,
      );
      await precacheImage(
        const AssetImage('assets/brand/nagad.png'),
        context,
      );
    });
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Delivery Address'), findsOneWidget);
    expect(
      find.text('Select a delivery address for your order'),
      findsOneWidget,
    );
    expect(find.text('Add New'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(
      find.text('544/2B, Nandonik Dream Tower, 6th floor'),
      findsOneWidget,
    );
    expect(find.text('East Kazipara, Mirpur, Dhaka-1216'), findsOneWidget);
    expect(find.text('Sayed Muhit Al Rafi | +880 1712-345678'), findsWidgets);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Orbeetal, House 12, Road 3, Block B'), findsOneWidget);
    expect(find.text('Niketon, Gulshan, Dhaka-1212'), findsOneWidget);
    expect(find.text('Order Items (1)'), findsOneWidget);
    expect(find.text('Edit Cart'), findsOneWidget);
    expect(
      find.text('Hoco J154A 22.5W + PD20W 20000mAh Power Bank'),
      findsOneWidget,
    );
    expect(find.text('22.5W and PD 20W Output'), findsOneWidget);
    expect(find.text('21% OFF'), findsOneWidget);
    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('Select a payment method'), findsOneWidget);
    expect(find.text('Secure Payment'), findsOneWidget);
    expect(find.text('bKash'), findsOneWidget);
    expect(find.text('Pay with bKash'), findsOneWidget);
    expect(find.text('Nagad'), findsOneWidget);
    expect(find.text('Pay with Nagad'), findsOneWidget);
    expect(find.text('Card Payment'), findsOneWidget);
    expect(find.text('Visa, MasterCard, AMEX'), findsOneWidget);
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(find.text('Pay when you receive'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(3));
    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text('Items (1)'), findsOneWidget);
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('Delivery Charge'), findsOneWidget);
    expect(find.text('Total Amount'), findsOneWidget);
    expect(find.text('Place Order'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.textContaining('1,450'), findsWidgets);
    expect(find.textContaining('1,850'), findsOneWidget);
    expect(find.textContaining('1,510'), findsOneWidget);
    expect(find.text('৳ 60'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Pressable && widget.semanticLabel == 'Home, selected',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Pressable &&
            widget.semanticLabel == 'Cash on Delivery, selected',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _capture(tester, '/tmp/checkout-page.png');

    await tester.tap(find.text('Office'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Pressable && widget.semanticLabel == 'Office, selected',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Nagad'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Pressable &&
            widget.semanticLabel == 'Cash on Delivery, selected',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, String path) async {
  final boundaries = tester.renderObjectList<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  RenderRepaintBoundary? largest;
  var area = 0.0;
  for (final boundary in boundaries) {
    if (!boundary.hasSize ||
        boundary.size.isEmpty ||
        boundary.debugNeedsPaint) {
      continue;
    }
    final next = boundary.size.width * boundary.size.height;
    if (next > area) {
      area = next;
      largest = boundary;
    }
  }
  final boundary = largest!;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
