typedef Json = Map<String, dynamic>;

/// Narrows a decoded body to a JSON object.
Json asJson(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a JSON object');
}

/// Narrows a decoded body to a list of JSON objects, skipping anything else.
List<Json> asJsonList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) asJson(item)];
}

/// Lenient readers that match how DRF serializes values.
extension JsonRead on Json {
  String str(String key, [String fallback = '']) {
    final value = this[key];
    if (value == null) return fallback;
    return value is String ? value : '$value';
  }

  String? strOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    final text = value is String ? value : '$value';
    return text.isEmpty ? null : text;
  }

  int integer(String key, [int fallback = 0]) => intOrNull(key) ?? fallback;

  int? intOrNull(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    return null;
  }

  bool boolean(String key, [bool fallback = false]) {
    final value = this[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return fallback;
  }

  /// Decimal fields arrive as strings such as `"1599.00"`. Numbers are normalized to strings.
  String money(String key, [String fallback = '0']) => moneyOrNull(key) ?? fallback;

  String? moneyOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is num) return value.toString();
    return null;
  }

  DateTime? date(String key) {
    final value = this[key];
    return value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
  }

  Json? obj(String key) {
    final value = this[key];
    return value is Map ? asJson(value) : null;
  }

  List<T> listOf<T>(String key, T Function(Json json) parse) =>
      [for (final item in asJsonList(this[key])) parse(item)];

  List<String> strings(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return [for (final item in value) if (item != null) '$item'];
  }
}
