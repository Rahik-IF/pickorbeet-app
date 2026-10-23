// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_user_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentUserNotifierHash() =>
    r'58abbc6e9db7eeab154bc9cc8414b0102ca6fcb4';

/// The signed-in customer's profile for the whole session. Tokens live in `AuthLocalRepository`.
///
/// Copied from [CurrentUserNotifier].
@ProviderFor(CurrentUserNotifier)
final currentUserNotifierProvider =
    NotifierProvider<CurrentUserNotifier, UserModel?>.internal(
      CurrentUserNotifier.new,
      name: r'currentUserNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentUserNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentUserNotifier = Notifier<UserModel?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
