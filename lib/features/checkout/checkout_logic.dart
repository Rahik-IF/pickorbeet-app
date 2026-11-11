import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/features/checkout/checkout_args.dart';

/// Cities treated as inside Dhaka when an address has no district. Matches
/// `is_inside_dhaka` on the server.
const dhakaDeliveryAreas = {
  'dhaka',
  'mirpur',
  'uttara',
  'gulshan',
  'banani',
  'dhanmondi',
  'mohammadpur',
};

/// Only Dhaka district ships at the inside rate; the division never decides.
bool shipsInsideDhaka({
  required String city,
  required String district,
  String division = '',
}) {
  final zone = district.trim().toLowerCase();
  if (zone.isNotEmpty) return zone == 'dhaka';
  return dhakaDeliveryAreas.contains(city.trim().toLowerCase());
}

/// The address checkout starts with: the default one, else the first saved.
AddressModel? startingAddress(List<AddressModel> addresses) {
  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.isEmpty ? null : addresses.first;
}

/// Zone the cart estimates delivery with, from the address checkout will start
/// with. Null until the customer has saved one.
bool? estimateInsideDhaka(List<AddressModel> addresses) {
  final home = startingAddress(addresses);
  if (home == null) return null;
  return shipsInsideDhaka(city: home.city, district: home.district);
}

/// `01712345678` -> `+880 1712-345678`, the form on the checkout design.
String checkoutPhone(String? raw) {
  final formatted = Formatters.phone(raw);
  return formatted.replaceFirstMapped(
    RegExp(r'^(\+880 \d{4}) (\d+)$'),
    (match) => '${match[1]}-${match[2]}',
  );
}

/// Street, then area and city, wrapped the way the delivery card shows them.
List<String> checkoutAddressLines(AddressModel address) {
  final line1 = address.addressLine1.trim();
  final line2 = address.addressLine2.trim();
  final city = address.city.trim();
  final district = address.district.trim();
  final division = address.division.trim();
  final postOffice = address.postOffice.trim();
  final postal = address.postalCode.trim();
  final place = <String>[
    if (city.isNotEmpty) city,
    if (postOffice.isNotEmpty) postal.isEmpty ? postOffice : '$postOffice-$postal',
    if (postOffice.isEmpty && postal.isNotEmpty) postal,
    if (district.isNotEmpty && district.toLowerCase() != city.toLowerCase()) district,
    if (division.isNotEmpty && division.toLowerCase() != district.toLowerCase()) division,
  ].join(', ');
  final second = [line2, place].where((part) => part.isNotEmpty).join(', ');
  return [if (line1.isNotEmpty) line1, if (second.isNotEmpty) second];
}

/// `Sayed Muhit Al Rafi | +880 1712-345678`
String checkoutContactLine(AddressModel address) {
  final name = address.fullName.trim();
  final phone = checkoutPhone(address.phone);
  if (name.isEmpty) return phone;
  if (phone.isEmpty) return name;
  return '$name | $phone';
}

/// Body for `POST /orders/checkout/`.
Map<String, Object?> checkoutPayload({
  required String name,
  required String phone,
  required String line1,
  String line2 = '',
  required String division,
  required String city,
  required String district,
  String postOffice = '',
  String postalCode = '',
  String? couponCode,
  List<String> itemIds = const [],
  required CheckoutPayment payment,
  bool asGuest = false,
  String? email,
}) {
  final apiPhone = Formatters.phoneForApi(phone);
  final coupon = couponCode?.trim() ?? '';
  return {
    'shipping_name': name.trim(),
    'shipping_phone': apiPhone,
    'shipping_address_line1': line1.trim(),
    if (line2.trim().isNotEmpty) 'shipping_address_line2': line2.trim(),
    'shipping_division': division.trim(),
    'shipping_city': city.trim(),
    'shipping_district': district.trim(),
    if (postOffice.trim().isNotEmpty) 'shipping_post_office': postOffice.trim(),
    if (postalCode.trim().isNotEmpty) 'shipping_postal_code': postalCode.trim(),
    if (coupon.isNotEmpty) 'coupon_code': coupon,
    if (itemIds.isNotEmpty) 'item_ids': itemIds,
    'payment_method': payment.apiValue,
    'platform': 'app',
    if (asGuest) 'guest_name': name.trim(),
    if (asGuest) 'guest_phone': apiPhone,
    if (asGuest) 'guest_email': (email ?? '').trim(),
  };
}
