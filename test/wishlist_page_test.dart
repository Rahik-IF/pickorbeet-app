import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/wishlist/view/pages/wishlist_page.dart';
import 'package:pickorbeet/features/wishlist/viewmodel/wishlist_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProductVariant _color(String color) => ProductVariant(
      id: 'variant-$color',
      price: '1',
      stockQuantity: 4,
      isActive: true,
      color: color,
    );

ProductSummary _product({
  required String id,
  required String name,
  required String category,
  required String price,
  required String compare,
  required int discount,
  required double rating,
  required int reviews,
  String sku = '',
  String? color,
}) {
  return ProductSummary(
    id: id,
    name: name,
    slug: id,
    shortDescription: '',
    sku: sku,
    price: price,
    comparePrice: compare,
    discountPercentage: discount,
    stockQuantity: 8,
    isOutOfStock: false,
    isFeatured: false,
    categoryName: category,
    variants: [if (color != null) _color(color)],
    rating: rating,
    reviewCount: reviews,
  );
}

final _saved = [
  _product(
    id: '1',
    name: 'Oraimo Necklace Lite (OEB-311)',
    category: 'Audio',
    price: '1080',
    compare: '1500',
    discount: 28,
    rating: 4.5,
    reviews: 320,
    sku: 'ORA-OEB-311',
  ),
  _product(
    id: '2',
    name: 'Baseus Bowie E3 TWS Earbuds',
    category: 'Electronics',
    price: '1650',
    compare: '1950',
    discount: 15,
    rating: 4.6,
    reviews: 812,
    color: 'White',
  ),
  _product(
    id: '3',
    name: 'Anker 10000mAh Power Bank',
    category: 'Electronics',
    price: '2200',
    compare: '2750',
    discount: 20,
    rating: 4.7,
    reviews: 1200,
    color: 'Black',
  ),
  _product(
    id: '4',
    name: 'JBL Tune 520BT Wireless Headphones',
    category: 'Electronics',
    price: '4200',
    compare: '6000',
    discount: 30,
    rating: 4.5,
    reviews: 950,
    color: 'Black',
  ),
  _product(
    id: '5',
    name: 'UGREEN 25W PD Fast Charger',
    category: 'Accessories',
    price: '1150',
    compare: '1300',
    discount: 12,
    rating: 4.4,
    reviews: 420,
    color: 'Black',
  ),
];

class _EmptyCart extends CartNotifier {
  @override
  Future<CartModel> build() async => const CartModel(id: 'cart', items: [], totalItems: 3, subtotal: '0');
}

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String name) async => ByteData.view((await File(name).readAsBytes()).buffer);

  final inter = FontLoader('Inter')
    ..addFont(bytes('assets/fonts/Inter-Regular.ttf'))
    ..addFont(bytes('assets/fonts/Inter-Medium.ttf'))
    ..addFont(bytes('assets/fonts/Inter-SemiBold.ttf'))
    ..addFont(bytes('assets/fonts/Inter-Bold.ttf'))
    ..addFont(bytes('assets/fonts/Inter-ExtraBold.ttf'));
  final display = FontLoader('InterDisplay')..addFont(bytes('assets/fonts/InterDisplay-Bold.ttf'));
  final icons = FontLoader('packages/phosphor_flutter/PhosphorRegular')
    ..addFont(rootBundle.load('packages/phosphor_flutter/lib/fonts/Phosphor.ttf'));
  final iconsBold = FontLoader('packages/phosphor_flutter/PhosphorBold')
    ..addFont(rootBundle.load('packages/phosphor_flutter/lib/fonts/Phosphor-Bold.ttf'));
  final iconsFill = FontLoader('packages/phosphor_flutter/PhosphorFill')
    ..addFont(rootBundle.load('packages/phosphor_flutter/lib/fonts/Phosphor-Fill.ttf'));
  final bengali = FontLoader('NotoSansBengali')
    ..addFont(bytes('assets/fonts/NotoSansBengali-Regular.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-Medium.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-SemiBold.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-Bold.ttf'))
    ..addFont(bytes('assets/fonts/NotoSansBengali-ExtraBold.ttf'));
  await Future.wait([inter.load(), display.load(), icons.load(), iconsBold.load(), iconsFill.load(), bengali.load()]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wishlist page matches the saved-product layout', (tester) async {
    await tester.runAsync(_loadFonts);
    SharedPreferences.setMockInitialValues({'wishlist_ids': _saved.map((product) => product.id).toList()});
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.padding = const FakeViewPadding(top: 47);
    tester.view.viewPadding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          wishlistProductsProvider.overrideWith((ref) async => _saved),
          cartNotifierProvider.overrideWith(_EmptyCart.new),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const WishlistPage()),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('My Wishlist'), findsOneWidget);
    expect(find.text('Save your favorite products and shop them later.'), findsOneWidget);
    expect(find.text('Move All to Cart'), findsOneWidget);
    expect(find.text('All (5)'), findsOneWidget);
    expect(find.text('Electronics (3)'), findsOneWidget);
    expect(find.text('Oraimo Necklace Lite (OEB-311)'), findsOneWidget);
    expect(find.text('ORA-OEB-311'), findsOneWidget);
    expect(find.text('Baseus | White'), findsOneWidget);
    expect(find.text('4.5 (320 reviews)'), findsOneWidget);
    expect(find.text('4.7 (1.2K reviews)'), findsOneWidget);
    expect(find.text('-28%'), findsOneWidget);
    expect(find.text('Add to Cart'), findsWidgets);
    expect(find.text('View Details'), findsWidgets);
    expect(tester.takeException(), isNull);

    await _capture(tester, '/tmp/wishlist-page.png');

    await tester.tap(find.bySemanticsLabel('Remove Oraimo Necklace Lite (OEB-311) from wishlist'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Removed from wishlist'), findsOneWidget);
    expect(find.text('Oraimo Necklace Lite (OEB-311)'), findsNothing);
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byType(SnackBarAction));
    await tester.pump();
    expect(find.text('Oraimo Necklace Lite (OEB-311)'), findsOneWidget);

    await tester.tap(find.text('Electronics (3)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Anker 10000mAh Power Bank'), findsOneWidget);
    expect(find.text('Oraimo Necklace Lite (OEB-311)'), findsNothing);
    expect(tester.takeException(), isNull);

    await _capture(tester, '/tmp/wishlist-filtered.png');
  });
}

Future<void> _capture(WidgetTester tester, String path) async {
  final boundaries = tester.renderObjectList<RenderRepaintBoundary>(find.byType(RepaintBoundary));
  RenderRepaintBoundary? largest;
  var area = 0.0;
  for (final boundary in boundaries) {
    if (!boundary.hasSize || boundary.size.isEmpty || boundary.debugNeedsPaint) continue;
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
