import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/providers/cart_notifier.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/theme/theme.dart';
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
      'rating_average': 4.7,
      'review_count': 328,
      'is_official': true,
      'warranty_period': '1 year',
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
      'option_groups': [
        {
          'name': 'Storage',
          'kind': 'text',
          'values': [
            {'label': '128GB'},
          ],
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
    expect(detail.summary.rating, 4.7);
    expect(detail.summary.reviewCount, 328);
    expect(detail.optionGroups.single.name, 'Storage');
    expect(detail.optionGroups.single.values.single.label, '128GB');
    expect(detail.summary.isOfficial, isTrue);
    expect(detail.summary.warrantyPeriod, '1 year');
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
    expect(find.text('Official'), findsNothing);
    expect(find.text('Warranty'), findsNothing);
    expect(find.text('Heart rate and sleep tracking'), findsOneWidget);
    expect(find.text('A light smartwatch for daily wear.'), findsOneWidget);
    expect(find.text('Aluminium'), findsOneWidget);
    expect(find.text('HY-RS4'), findsOneWidget);
    expect(find.text('৳1,890'), findsOneWidget);
    expect(find.text('In stock'), findsOneWidget);
    expect(find.textContaining('Color:'), findsOneWidget);
    expect(find.textContaining('Black'), findsWidgets);
    expect(find.text('XL'), findsNothing);
    expect(find.text('You may also like'), findsOneWidget);
    expect(find.text('Baseus Cable'), findsOneWidget);
    expect(find.text('100% Original'), findsOneWidget);
    expect(find.text('Trusted Quality'), findsOneWidget);
    expect(find.text('Secure Payment'), findsOneWidget);
    expect(find.text('Easy Returns'), findsOneWidget);
    expect(find.textContaining('Product Code:'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
    expect(find.textContaining('You save'), findsOneWidget);
    expect(find.text('Ready to ship'), findsOneWidget);
    expect(find.text('Check delivery availability'), findsOneWidget);
    expect(find.text('Cash on Delivery'), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
    expect(find.text('Buy Now'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('Enter an area or postal code'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Mirpur');
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.textContaining('Inside Dhaka'), findsOneWidget);
    expect(find.textContaining('৳60'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sylhet');
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.textContaining('Outside Dhaka'), findsOneWidget);
    expect(find.textContaining('৳120'), findsOneWidget);

    await tester.tap(find.text('Add to Cart'));
    await tester.pump();
    expect(find.text('Choose a size'), findsOneWidget);
    expect(lastAdded, isNull);

    await tester.tap(find.text('S'));
    await tester.pump();
    expect(find.text('Out of stock'), findsWidgets);
    expect(lastAdded, isNull);

    await tester.tap(find.text('M'));
    await tester.pump();
    expect(find.text('Add to Cart'), findsOneWidget);
    expect(find.text('Only 4 left'), findsOneWidget);
    expect(find.text('৳1,990'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIconsBold.plus));
    await tester.pump();
    await tester.tap(find.text('Add to Cart'));
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

    await tester.tap(find.text('Out of stock').first);
    await tester.pump();
    expect(lastAdded, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('official product shows the badge and warranty period', (tester) async {
    await _show(
      tester,
      detail: _detail(official: true, warranty: '1 year'),
    );

    expect(find.text('Official'), findsOneWidget);
    expect(find.text('Warranty'), findsOneWidget);
    expect(find.text('1 year'), findsOneWidget);
    expect(
      find.textContaining('Covered for 1 year from the day the order is delivered'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom options show storage and the saved swatch color', (tester) async {
    await _show(
      tester,
      detail: const ProductDetail(
        summary: ProductSummary(
          id: 'p3',
          name: 'Oraimo Necklace Lite',
          slug: 'oraimo-necklace',
          shortDescription: 'Neckband',
          sku: 'ORA-OEB-311',
          price: '1080.00',
          discountPercentage: 0,
          stockQuantity: 4,
          isOutOfStock: false,
          isFeatured: false,
          categoryName: 'Electronics',
          variants: [
            ProductVariant(
              id: 'v-neck',
              price: '1080.00',
              stockQuantity: 4,
              isActive: true,
              options: [
                VariantChoice(name: 'Storage', label: '128GB'),
                VariantChoice(name: 'Color', kind: 'swatch', label: 'Midnight', colorHex: '#0B1F3A'),
              ],
            ),
          ],
        ),
        description: 'A neckband.',
        images: [],
        categorySlug: 'electronics',
        optionGroups: [
          OptionGroup(
            name: 'Storage',
            kind: 'text',
            values: [VariantChoice(name: 'Storage', label: '128GB')],
          ),
          OptionGroup(
            name: 'Color',
            kind: 'swatch',
            values: [VariantChoice(name: 'Color', kind: 'swatch', label: 'Midnight', colorHex: '#0B1F3A')],
          ),
        ],
      ),
    );

    expect(find.text('128GB'), findsOneWidget);
    expect(find.textContaining('Storage:'), findsOneWidget);
    expect(find.textContaining('Midnight'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == const Color(0xFF0B1F3A),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

ProductDetail _detail({
  bool soldOut = false,
  List<ProductVariant> variants = const [],
  bool official = false,
  String warranty = '',
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
      isOfficial: official,
      warrantyPeriod: warranty,
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
