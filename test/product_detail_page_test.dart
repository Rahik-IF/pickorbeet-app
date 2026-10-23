import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/view/pages/product_detail_page.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

CartLine? lastAdded;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('product detail parses the catalog payload', () {
    final detail = ProductDetail.fromMap({
      'id': '1',
      'name': 'Haylou RS4',
      'slug': 'haylou-rs4',
      'short_description': 'Daily watch',
      'description': '<p>Light <strong>watch</strong></p>',
      'sku': 'HY-RS4',
      'price': '1890.00',
      'compare_price': '2360.00',
      'discount_percentage': 20,
      'stock_quantity': 4,
      'is_low_stock': true,
      'is_out_of_stock': false,
      'is_featured': false,
      'size': 'Adjustable',
      'material': 'Aluminium',
      'category': {'id': 'c', 'name': 'Watches', 'slug': 'watches'},
      'subcategory': {'id': 's', 'name': 'Smart', 'slug': 'smart'},
      'images': [
        {
          'id': 'i2',
          'image': '/media/b.jpg',
          'alt_text': 'side',
          'is_primary': false,
        },
        {
          'id': 'i1',
          'image': '/media/a.jpg',
          'alt_text': 'front',
          'is_primary': true,
        },
      ],
      'variants': [
        {
          'id': 'v1',
          'size': 'M',
          'color': 'Black',
          'price': '1890.00',
          'effective_price': '1890.00',
          'stock_quantity': 4,
          'low_stock_threshold': 10,
          'is_active': true,
        },
      ],
    });

    expect(detail.summary.name, 'Haylou RS4');
    expect(detail.summary.categoryName, 'Watches');
    expect(detail.summary.subcategoryName, 'Smart');
    expect(detail.summary.isLowStock, isTrue);
    expect(detail.categorySlug, 'watches');
    expect(detail.subcategorySlug, 'smart');
    expect(detail.gallery, ['/media/a.jpg', '/media/b.jpg']);
    expect(detail.plainDescription, 'Light watch');
    expect(detail.summary.variants.single.isLowStock, isTrue);
    expect(detail.summary.variants.single.lowStockThreshold, 10);
    expect(detail.specs, contains(('Material', 'Aluminium')));
  });

  test('plain description drops scripts and keeps list items', () {
    final script = ProductDetail.fromMap({
      'id': '1',
      'name': 'Tee',
      'description': '<script>alert(1)</script><p>Hi &amp; bye</p>',
    });
    final list = ProductDetail.fromMap({
      'id': '2',
      'name': 'Tee',
      'description': '<ul><li>Soft</li><li>Light</li></ul>',
    });

    expect(script.plainDescription, 'Hi & bye');
    expect(script.summary.categoryName, isEmpty);
    expect(script.gallery, isEmpty);
    expect(list.plainDescription, '• Soft\n• Light');
  });

  testWidgets('product page shows the product and adds the chosen size', (
    tester,
  ) async {
    const variants = [
      ProductVariant(
        id: 'v-s',
        price: '1890.00',
        stockQuantity: 0,
        isActive: true,
        size: 'S',
        color: 'Black',
      ),
      ProductVariant(
        id: 'v-m',
        price: '1990.00',
        stockQuantity: 4,
        isActive: true,
        size: 'M',
        color: 'Black',
      ),
      ProductVariant(
        id: 'v-xl',
        price: '1990.00',
        stockQuantity: 2,
        isActive: false,
        size: 'XL',
        color: 'Black',
      ),
    ];
    final detail = _detail(variants: variants);

    await _show(tester, detail: detail, related: [_related]);

    expect(find.text('Product'), findsNothing);
    expect(find.text('Haylou RS4 Smartwatch'), findsOneWidget);
    expect(find.text('Watches · Smart'), findsOneWidget);
    expect(find.text('Heart rate and sleep tracking'), findsOneWidget);
    expect(find.text('A light smartwatch for daily wear.'), findsOneWidget);
    expect(find.text('Aluminium'), findsOneWidget);
    expect(find.text('HY-RS4'), findsOneWidget);
    expect(find.text('৳ 1,890'), findsOneWidget);
    expect(find.text('In stock'), findsOneWidget);
    expect(find.text('Select a size'), findsOneWidget);
    expect(find.text('Black'), findsOneWidget);
    expect(find.text('XL'), findsNothing);
    expect(find.text('You may also like'), findsOneWidget);
    expect(find.text('Baseus Cable'), findsOneWidget);
    expect(find.text('Fast delivery'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('S'));
    await tester.pump();
    expect(find.widgetWithText(AppButton, 'Out of stock'), findsOneWidget);
    expect(lastAdded, isNull);

    await tester.tap(find.text('M'));
    await tester.pump();
    expect(find.text('Add to cart'), findsOneWidget);
    expect(find.text('Only 4 left'), findsOneWidget);
    expect(find.text('৳ 1,990'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIconsBold.plus));
    await tester.pump();
    await tester.tap(find.text('Add to cart'));
    await tester.pump();
    await tester.pump();

    expect(lastAdded?.productId, 'p1');
    expect(lastAdded?.variantId, 'v-m');
    expect(lastAdded?.quantity, 2);
    expect(find.text('Added to cart'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sold out product cannot be added', (tester) async {
    await _show(tester, detail: _detail(soldOut: true));

    expect(find.text('Haylou RS4 Smartwatch'), findsOneWidget);
    expect(find.text('Out of stock'), findsWidgets);
    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Out of stock'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.widgetWithText(AppButton, 'Out of stock'));
    await tester.pump();
    expect(lastAdded, isNull);
    expect(tester.takeException(), isNull);
  });
}

ProductDetail _detail({
  bool soldOut = false,
  List<ProductVariant> variants = const [],
}) {
  return ProductDetail(
    summary: ProductSummary(
      id: 'p1',
      name: 'Haylou RS4 Smartwatch',
      slug: 'haylou-rs4',
      shortDescription: 'Heart rate and sleep tracking',
      sku: 'HY-RS4',
      price: '1890.00',
      comparePrice: '2360.00',
      discountPercentage: 20,
      stockQuantity: soldOut ? 0 : 12,
      isOutOfStock: soldOut,
      isFeatured: false,
      categoryName: 'Watches',
      subcategoryName: 'Smart',
      variants: variants,
    ),
    description: '<p>A light <strong>smartwatch</strong> for daily wear.</p>',
    images: const [],
    categorySlug: 'watches',
    subcategorySlug: 'smart',
    material: 'Aluminium',
  );
}

const _related = ProductSummary(
  id: 'p2',
  name: 'Baseus Cable',
  slug: 'baseus-cable',
  shortDescription: '',
  price: '500',
  discountPercentage: 0,
  stockQuantity: 5,
  isOutOfStock: false,
  isFeatured: false,
  categoryName: 'Watches',
  variants: [],
);

Future<void> _show(
  WidgetTester tester, {
  required ProductDetail detail,
  List<ProductSummary> related = const [],
}) async {
  lastAdded = null;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1800);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cartNotifierProvider.overrideWith(_RecordingCart.new),
        productDetailProvider(
          detail.summary.slug,
        ).overrideWith((ref) async => detail),
        relatedProductsProvider(
          productId: detail.summary.id,
          categorySlug: detail.categorySlug,
          subcategorySlug: detail.subcategorySlug,
        ).overrideWith((ref) async => related),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        ),
        home: ProductDetailPage(slug: detail.summary.slug),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _RecordingCart extends CartNotifier {
  @override
  Future<CartModel> build() async => CartModel.empty;

  @override
  Future<Either<AppFailure, CartModel>> add(CartLine line) async {
    lastAdded = line;
    return const Right(CartModel.empty);
  }
}
