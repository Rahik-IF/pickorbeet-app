import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/paginated.dart';
import 'package:pickorbeet/core/network/api_client.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/features/auth/repositories/auth_local_repository.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/repositories/catalog_repository.dart';
import 'package:pickorbeet/features/search/view/pages/search_page.dart';
import 'package:pickorbeet/features/search/viewmodel/recent_searches.dart';
import 'package:pickorbeet/features/search/viewmodel/search_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProductSummary _item({
  required String id,
  required String name,
  required String price,
  String sku = '',
  String? compare,
  int discount = 0,
  bool featured = false,
  double? rating,
  int? reviews,
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
    isFeatured: featured,
    categoryName: 'Electronics',
    variants: const [],
    rating: rating,
    reviewCount: reviews,
  );
}

final _featured = _item(
  id: 'necklace',
  name: 'Oraimo Necklace Lite',
  price: '1080',
  sku: 'ORA-311',
  featured: true,
);

final _power = _item(
  id: 'power',
  name: 'Anker 10000mAh Power Bank',
  price: '1450',
  sku: 'ANK-100',
  compare: '1835',
  discount: 21,
  rating: 4.6,
  reviews: 120,
);

final _earbuds = _item(id: 'earbuds', name: 'Sony Earbuds', price: '990', sku: 'SNY-EB');

class _Catalog extends CatalogRepository {
  _Catalog() : super(_client);

  static final _client = ApiClient(
    client: http.Client(),
    tokens: AuthLocalRepository(),
    cookies: CookieJar(),
  );

  final calls = <ProductQuery>[];
  var failSearch = false;

  @override
  Future<Either<AppFailure, Paginated<ProductSummary>>> products(ProductQuery query, {int page = 1}) async {
    calls.add(query);
    final term = (query.search ?? '').trim().toLowerCase();
    if (failSearch && term.isNotEmpty) return const Left(AppFailure('Could not load products.'));
    if (term == 'none') return const Right(Paginated.empty());
    if (term.isEmpty) return Right(Paginated(count: 1, results: [_featured]));
    if (term == 'earbuds') return Right(Paginated(count: 1, results: [_earbuds]));
    return Right(Paginated(count: 1, results: [_power]));
  }

  @override
  Future<Either<AppFailure, StoreSettings>> storeSettings() async {
    return const Right(
      StoreSettings(
        popularSearches: ['Power bank', 'none', 'Fast charger'],
        address: '',
        phones: [],
        emails: [],
        businessHours: '',
      ),
    );
  }

  @override
  Future<Either<AppFailure, List<CategoryModel>>> categories() async {
    return const Right([
      CategoryModel(
        id: 'electronics',
        name: 'Electronics',
        slug: 'electronics',
        description: '',
        tagline: '',
        isFeatured: true,
        featuredOrder: 0,
        displayOrder: 0,
        subcategories: [],
        productCount: 4,
      ),
    ]);
  }
}

late SharedPreferences prefs;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    await prefs.clear();
  });

  testWidgets('debounce fetches once, and a product row uses catalog fields', (tester) async {
    final catalog = _Catalog();
    await _open(tester, catalog);
    expect(find.textContaining('review'), findsNothing);
    expect(find.text('21% OFF'), findsNothing);
    expect(find.bySemanticsLabel('Voice search'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'p');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.enterText(find.byType(TextField), 'power');
    await tester.pump(const Duration(milliseconds: 120));
    expect(catalog.calls.where((query) => (query.search ?? '').isNotEmpty), isEmpty);

    await tester.pump(searchDebounce);
    await _until(tester, find.text('Anker 10000mAh Power Bank'));

    expect(catalog.calls.where((query) => query.search == 'p'), isEmpty);
    expect(catalog.calls.where((query) => query.search == 'power'), hasLength(1));
    expect(find.text('Anker 10000mAh Power Bank'), findsOneWidget);
    expect(find.text('Anker | ANK-100'), findsOneWidget);
    expect(find.text('4.6 (120 reviews)'), findsOneWidget);
    expect(find.text('৳ 1,450'), findsOneWidget);
    expect(find.text('21% OFF'), findsOneWidget);
    expect(_field(tester), 'power');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a recent chip restores the query and searches', (tester) async {
    await prefs.setStringList(RecentSearches.storageKey, ['earbuds']);
    final catalog = _Catalog();
    await _open(tester, catalog);

    expect(find.text('earbuds'), findsOneWidget);
    await tester.tap(find.text('earbuds'));
    await _until(tester, find.text('Sony Earbuds'));

    expect(find.text('Sony Earbuds'), findsOneWidget);
    expect(_field(tester), 'earbuds');
    expect(catalog.calls.where((query) => query.search == 'earbuds'), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear returns discovery and keeps recent searches', (tester) async {
    final catalog = _Catalog();
    await _open(tester, catalog);
    await tester.enterText(find.byType(TextField), 'power');
    await tester.pump(searchDebounce);
    await _until(tester, find.text('Anker 10000mAh Power Bank'));

    await tester.tap(find.bySemanticsLabel('Clear search'));
    await _until(tester, find.text('Oraimo Necklace Lite'));

    expect(_field(tester), isEmpty);
    expect(find.text('Oraimo Necklace Lite'), findsOneWidget);
    expect(find.text('Anker 10000mAh Power Bank'), findsNothing);
    expect(find.text('power'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed search keeps the query and retry loads products', (tester) async {
    final catalog = _Catalog()..failSearch = true;
    await _open(tester, catalog);
    await tester.enterText(find.byType(TextField), 'power');
    await tester.pump(searchDebounce);
    await _until(tester, find.text('Try again'));

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Anker 10000mAh Power Bank'), findsNothing);
    expect(_field(tester), 'power');

    catalog.failSearch = false;
    await tester.tap(find.text('Try again'));
    await _until(tester, find.text('Anker 10000mAh Power Bank'));

    expect(find.text('Anker 10000mAh Power Bank'), findsOneWidget);
    expect(_field(tester), 'power');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty result offers other popular searches', (tester) async {
    final catalog = _Catalog();
    await _open(tester, catalog);
    await tester.enterText(find.byType(TextField), 'none');
    await tester.pump(searchDebounce);
    await _until(tester, find.text('No matching products'));

    expect(find.text('No matching products'), findsOneWidget);
    expect(find.text('Power bank'), findsOneWidget);
    expect(find.text('Fast charger'), findsOneWidget);
    // The field and the recent chip. The popular term "none" is not offered again.
    expect(find.text('none'), findsNWidgets(2));
    expect(_field(tester), 'none');
    expect(tester.takeException(), isNull);
  });
}

String _field(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

Future<void> _open(WidgetTester tester, _Catalog catalog) async {
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1600);
  addTearDown(() async {
    tester.view.reset();
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        catalogRepositoryProvider.overrideWithValue(catalog),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SearchPage(),
      ),
    ),
  );
  await _until(tester, find.text('Oraimo Necklace Lite'));
  expect(find.text('Oraimo Necklace Lite'), findsOneWidget);
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
