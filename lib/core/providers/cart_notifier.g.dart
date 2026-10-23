// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cartNotifierHash() => r'd2c77b00b7c9e7af65b3a8c68dd9fe2a3caa4e1f';

/// The cart for the whole session; drives the badge, the cart tab, and checkout.
///
/// Quantity changes and removals apply immediately and reconcile with the server. Writes run one
/// at a time and only the newest response is applied, so fast stepper taps settle correctly.
///
/// Copied from [CartNotifier].
@ProviderFor(CartNotifier)
final cartNotifierProvider =
    AsyncNotifierProvider<CartNotifier, CartModel>.internal(
      CartNotifier.new,
      name: r'cartNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$cartNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CartNotifier = AsyncNotifier<CartModel>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
