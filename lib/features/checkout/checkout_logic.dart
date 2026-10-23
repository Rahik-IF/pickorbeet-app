import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/features/checkout/checkout_args.dart';

/// Cities the order total treats as inside Dhaka. Matches `Order.save`.
const dhakaDeliveryAreas = {
  'dhaka',
  'mirpur',
  'uttara',
  'gulshan',
  'banani',
  'dhanmondi',
  'mohammadpur',
};

bool shipsInsideDhaka({required String city, required String district}) {
  return dhakaDeliveryAreas.contains(city.trim().toLowerCase()) ||
      district.trim().toLowerCase() == 'dhaka';
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
  final postal = address.postalCode.trim();
  final place = <String>[
    if (district.isNotEmpty && district.toLowerCase() != city.toLowerCase())
      district,
    if (city.isNotEmpty) postal.isEmpty ? city : '$city-$postal',
    if (city.isEmpty && postal.isNotEmpty) postal,
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
  required String city,
  required String district,
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
    'shipping_city': city.trim(),
    'shipping_district': district.trim(),
    if (postalCode.trim().isNotEmpty) 'shipping_postal_code': postalCode.trim(),
    if (coupon.isNotEmpty) 'coupon_code': coupon,
    if (itemIds.isNotEmpty) 'item_ids': itemIds,
    'payment_method': payment.apiValue,
    if (asGuest) 'guest_name': name.trim(),
    if (asGuest) 'guest_phone': apiPhone,
    if (asGuest && email != null && email.trim().isNotEmpty)
      'guest_email': email.trim(),
  };
}
