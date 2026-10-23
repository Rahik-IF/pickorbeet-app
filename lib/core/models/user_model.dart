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
    this.orderCount = 0,
    this.totalSpent = '0',
    this.dateJoined,
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
  final int orderCount;
  final String totalSpent;
  final DateTime? dateJoined;

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
      orderCount: map.integer('order_count'),
      totalSpent: map.money('total_spent'),
      dateJoined: map.date('date_joined'),
    );
  }

  /// Login's nested `user` omits phone and verification, so keep what the profile already had.
  UserModel mergeMissing(UserModel? previous) {
    if (previous == null || previous.id != id) return this;
    return copyWith(
      phone: phone ?? previous.phone,
      isVerified: isVerified || previous.isVerified,
      address: address ?? previous.address,
      city: city ?? previous.city,
      postalCode: postalCode ?? previous.postalCode,
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
    int? orderCount,
    String? totalSpent,
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
      orderCount: orderCount ?? this.orderCount,
      totalSpent: totalSpent ?? this.totalSpent,
      dateJoined: dateJoined,
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
      other.orderCount == orderCount &&
      other.totalSpent == totalSpent;

  @override
  int get hashCode => Object.hash(id, email, fullName, phone, isVerified, address, city, postalCode, orderCount, totalSpent);
}
