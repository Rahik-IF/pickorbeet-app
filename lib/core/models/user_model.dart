import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/network/json.dart';

/// The signed-in customer, from `/auth/profile/` or the `user` object returned by login.
@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.phone,
    this.role = 'customer',
    this.isVerified = false,
    this.address,
    this.city,
    this.postalCode,
    this.avatar,
    this.fromProfile = false,
    this.orderCount = 0,
    this.totalSpent = '0',
    this.dateJoined,
    this.twoFactorEnabled = false,
    this.recoveryEmail,
    this.recoveryEmailVerified = false,
    this.hasPassword = true,
    this.includesSecurity = false,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? phone;
  final String role;
  final bool isVerified;
  final String? address;
  final String? city;
  final String? postalCode;

  /// Absolute or media URL. Null when the customer has no photo.
  final String? avatar;

  /// True when this object came from `/auth/profile/`, which always includes [avatar].
  /// Login's nested user omits it, so a later login must not wipe a photo that is already loaded.
  final bool fromProfile;

  final int orderCount;
  final String totalSpent;
  final DateTime? dateJoined;

  /// Email codes are required at sign-in. Comes from the profile, not the login payload.
  final bool twoFactorEnabled;
  final String? recoveryEmail;
  final bool recoveryEmailVerified;

  /// False for a Google account that has never set a password.
  final bool hasPassword;

  /// True when [fromMap] saw the security fields, so a thinner login payload does not wipe them.
  final bool includesSecurity;

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : email;
  }

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String head(String word) => String.fromCharCode(word.runes.first);
    final last = parts.length > 1 ? head(parts.last) : '';
    return (head(parts.first) + last).toUpperCase();
  }

  factory UserModel.fromMap(Json map) {
    final first = map.str('first_name');
    final last = map.str('last_name');
    return UserModel(
      id: map.str('id'),
      email: map.str('email'),
      firstName: first,
      lastName: last,
      fullName: map.strOrNull('full_name') ?? '$first $last'.trim(),
      phone: map.strOrNull('phone'),
      role: map.str('role', 'customer'),
      isVerified: map.boolean('is_verified'),
      address: map.strOrNull('address'),
      city: map.strOrNull('city'),
      postalCode: map.strOrNull('postal_code'),
      avatar: map.strOrNull('avatar'),
      fromProfile: map.containsKey('avatar'),
      orderCount: map.integer('order_count'),
      totalSpent: map.money('total_spent'),
      dateJoined: map.date('date_joined'),
      twoFactorEnabled: map.containsKey('two_factor_enabled') && map.boolean('two_factor_enabled'),
      recoveryEmail: map.containsKey('recovery_email') ? map.strOrNull('recovery_email') : null,
      recoveryEmailVerified: map.containsKey('recovery_email_verified') && map.boolean('recovery_email_verified'),
      hasPassword: map.containsKey('has_password') ? map.boolean('has_password') : true,
      includesSecurity: map.containsKey('two_factor_enabled'),
    );
  }

  /// Login's nested `user` omits phone, address, and the photo, so keep what the profile already had.
  /// A profile response includes `avatar` even when it is null, and that null must stick.
  UserModel mergeMissing(UserModel? previous) {
    if (previous == null || previous.id != id || fromProfile) return this;
    return copyWith(
      phone: phone ?? previous.phone,
      isVerified: isVerified || previous.isVerified,
      address: address ?? previous.address,
      city: city ?? previous.city,
      postalCode: postalCode ?? previous.postalCode,
      avatar: previous.avatar,
      twoFactorEnabled: includesSecurity ? twoFactorEnabled : previous.twoFactorEnabled,
      recoveryEmail: includesSecurity ? recoveryEmail : previous.recoveryEmail,
      recoveryEmailVerified: includesSecurity ? recoveryEmailVerified : previous.recoveryEmailVerified,
      hasPassword: includesSecurity ? hasPassword : previous.hasPassword,
      includesSecurity: includesSecurity || previous.includesSecurity,
    );
  }

  UserModel copyWith({
    String? email,
    String? firstName,
    String? lastName,
    String? fullName,
    String? phone,
    bool? isVerified,
    String? address,
    String? city,
    String? postalCode,
    Object? avatar = _keep,
    int? orderCount,
    String? totalSpent,
    bool? twoFactorEnabled,
    Object? recoveryEmail = _keep,
    bool? recoveryEmailVerified,
    bool? hasPassword,
    bool? includesSecurity,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role,
      isVerified: isVerified ?? this.isVerified,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      avatar: identical(avatar, _keep) ? this.avatar : avatar as String?,
      fromProfile: fromProfile,
      orderCount: orderCount ?? this.orderCount,
      totalSpent: totalSpent ?? this.totalSpent,
      dateJoined: dateJoined,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      recoveryEmail: identical(recoveryEmail, _keep) ? this.recoveryEmail : recoveryEmail as String?,
      recoveryEmailVerified: recoveryEmailVerified ?? this.recoveryEmailVerified,
      hasPassword: hasPassword ?? this.hasPassword,
      includesSecurity: includesSecurity ?? this.includesSecurity,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserModel &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName &&
      other.phone == phone &&
      other.isVerified == isVerified &&
      other.address == address &&
      other.city == city &&
      other.postalCode == postalCode &&
      other.avatar == avatar &&
      other.orderCount == orderCount &&
      other.totalSpent == totalSpent &&
      other.twoFactorEnabled == twoFactorEnabled &&
      other.recoveryEmail == recoveryEmail &&
      other.recoveryEmailVerified == recoveryEmailVerified &&
      other.hasPassword == hasPassword;

  @override
  int get hashCode => Object.hash(
        id,
        email,
        fullName,
        phone,
        isVerified,
        address,
        city,
        postalCode,
        avatar,
        orderCount,
        totalSpent,
        twoFactorEnabled,
        recoveryEmail,
        recoveryEmailVerified,
        hasPassword,
      );
}

const _keep = Object();
