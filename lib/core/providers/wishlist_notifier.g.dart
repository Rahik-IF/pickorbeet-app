// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wishlistNotifierHash() => r'0788f11b48563dfad15799a42b8a59769c0d3caf';

/// Wishlisted product ids, newest first. Like the website, the list lives on the device.
///
/// Copied from [WishlistNotifier].
@ProviderFor(WishlistNotifier)
final wishlistNotifierProvider =
    NotifierProvider<WishlistNotifier, List<String>>.internal(
      WishlistNotifier.new,
      name: r'wishlistNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$wishlistNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WishlistNotifier = Notifier<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
