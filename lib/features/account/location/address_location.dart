import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Pieces of an address read from the device location.
class LocatedPlace {
  const LocatedPlace({
    this.line1 = '',
    this.line2 = '',
    this.city = '',
    this.district = '',
    this.postalCode = '',
    this.country = 'Bangladesh',
  });

  final String line1;
  final String line2;
  final String city;
  final String district;
  final String postalCode;
  final String country;

  bool get isEmpty => line1.isEmpty && city.isEmpty && district.isEmpty;
}

/// Asks for location permission, then reverse-geocodes the current position.
Future<LocatedPlace> locateCurrentPlace() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    throw const LocationFailure('Turn on location services, then try again.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw const LocationFailure('Location permission is off. You can still type the address.');
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 12)),
  );
  final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
    'lat': position.latitude.toString(),
    'lon': position.longitude.toString(),
    'format': 'json',
    'addressdetails': '1',
  });
  final response = await http
      .get(uri, headers: const {'User-Agent': 'PickOrbeet/1.0 (delivery addresses)', 'Accept': 'application/json'})
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) {
    throw const LocationFailure('Could not read this location. Enter the address instead.');
  }
  final body = jsonDecode(response.body);
  if (body is! Map) return const LocatedPlace();
  final address = body['address'];
  final map = address is Map ? address.cast<String, dynamic>() : const <String, dynamic>{};
  String pick(List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  final house = pick(const ['house_number']);
  final road = pick(const ['road', 'pedestrian', 'footway']);
  final line1 = [house, road].where((part) => part.isNotEmpty).join(' ');
  final area = pick(const ['suburb', 'neighbourhood', 'quarter']);
  return LocatedPlace(
    line1: line1.isEmpty ? pick(const ['amenity', 'building']) : line1,
    line2: area,
    city: pick(const ['city', 'town', 'municipality', 'village']),
    district: pick(const ['state_district', 'county', 'state']),
    postalCode: pick(const ['postcode']),
    country: pick(const ['country']).isEmpty ? 'Bangladesh' : pick(const ['country']),
  );
}

class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
}
