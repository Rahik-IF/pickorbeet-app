import 'package:flutter/foundation.dart';

import 'package:pickorbeet/core/network/json.dart';

/// A saved address from `/auth/addresses/`.
@immutable
class AddressModel {
  const AddressModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    required this.city,
    required this.district,
    this.addressType = 'shipping',
    this.label = '',
    this.addressLine2 = '',
    this.postalCode = '',
    this.country = 'Bangladesh',
    this.isDefault = false,
    this.isInsideDhaka = false,
  });

  final String id;
  final String addressType;
  final String label;
  final String fullName;
  final String phone;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String district;
  final String postalCode;
  final String country;
  final bool isDefault;
  final bool isInsideDhaka;

  /// `House 12, Road 4, Malibagh`
  String get streetLine => [addressLine1, addressLine2].where((p) => p.trim().isNotEmpty).join(', ');

  /// `Dhaka 1217, Bangladesh`
  String get localityLine {
    final cityPart = [city, postalCode].where((p) => p.trim().isNotEmpty).join(' ');
    return [cityPart, country].where((p) => p.trim().isNotEmpty).join(', ');
  }

  factory AddressModel.fromMap(Json map) => AddressModel(
        id: map.str('id'),
        addressType: map.str('address_type', 'shipping'),
        label: map.str('label'),
        fullName: map.str('full_name'),
        phone: map.str('phone'),
        addressLine1: map.str('address_line1'),
        addressLine2: map.str('address_line2'),
        city: map.str('city'),
        district: map.str('district'),
        postalCode: map.str('postal_code'),
        country: map.str('country', 'Bangladesh'),
        isDefault: map.boolean('is_default'),
        isInsideDhaka: map.boolean('is_inside_dhaka'),
      );

  /// Body for create and update. The server sets `user` and `is_inside_dhaka`.
  Json toMap() => {
        'address_type': addressType,
        'label': label,
        'full_name': fullName,
        'phone': phone,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'district': district,
        'postal_code': postalCode,
        'country': country,
        'is_default': isDefault,
      };

  String get placeName => label.trim().isEmpty ? 'Address' : label.trim();

  AddressModel copyWith({
    String? label,
    String? fullName,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? district,
    String? postalCode,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id,
      addressType: addressType,
      label: label ?? this.label,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      district: district ?? this.district,
      postalCode: postalCode ?? this.postalCode,
      country: country,
      isDefault: isDefault ?? this.isDefault,
      isInsideDhaka: isInsideDhaka,
    );
  }

  @override
  bool operator ==(Object other) => other is AddressModel && other.id == id && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hash(id, fullName, phone, addressLine1, addressLine2, city, district, postalCode, isDefault);
}
