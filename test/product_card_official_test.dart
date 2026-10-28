import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickorbeet/core/providers/core_providers.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/repositories/catalog_repository.dart';
import 'package:pickorbeet/features/catalog/view/widgets/product_card.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProductSummary _product({required bool official, int discount = 0, String? compare}) {
  return ProductSummary(
    id: 'official-1',
    name: 'Oraimo Necklace Lite',
    slug: 'oraimo-necklace-lite',
    shortDescription: '',
    price: '1080',
    comparePrice: compare,
    discountPercentage: discount,
    stockQuantity: 4,
    isOutOfStock: false,
    isFeatured: false,
    categoryName: 'Electronics',
    variants: const [],
    isOfficial: official,
  );
}

const _settings = StoreSettings(
  popularSearches: [],
  address: '',
  phones: [],
  emails: [],
  businessHours: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home and list cards show the official badge beside a discount', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storeSettingsProvider.overrideWith((ref) async => _settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: _product(official: true, discount: 10, compare: '1200'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Official'), findsOneWidget);
    expect(find.text('10% OFF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards without the official mark stay unmarked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storeSettingsProvider.overrideWith((ref) async => _settings),
        ],
        child: MaterialApp(
          home: Scaffold(body: ProductCard(product: _product(official: false))),
        ),
      ),
    );

    expect(find.text('Official'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
