import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Display formatting for money, dates, phones, and counts.
abstract final class Formatters {
  static const taka = '৳';

  static final _whole = NumberFormat('#,##0', 'en_US');
  static final _fraction = NumberFormat('#,##0.00', 'en_US');
  static final _dateTime = DateFormat('d MMM yyyy, h:mm a', 'en_US');
  static final _date = DateFormat('d MMM yyyy', 'en_US');
  static final _time = DateFormat('h:mm a', 'en_US');
  static final _compact = NumberFormat.compact(locale: 'en_US');

  /// Bangladesh is UTC+6 all year, so a fixed offset is exact.
  static const dhakaOffset = Duration(hours: 6);

  /// Parses an API money string. Returns zero for anything unreadable.
  static Decimal decimal(Object? value) {
    if (value is Decimal) return value;
    if (value is int) return Decimal.fromInt(value);
    if (value is num) return Decimal.parse(value.toString());
    if (value is String) return Decimal.tryParse(value.trim()) ?? Decimal.zero;
    return Decimal.zero;
  }

  /// `"1599.00"` -> `৳ 1,599`. Paisa stay when present: `৳ 1,599.50`.
  static String money(Object? value) => '$taka ${amount(value)}';

  /// The number part only: `1,599`.
  static String amount(Object? value) {
    final number = decimal(value).abs();
    final text = number.isInteger ? _whole.format(number.toBigInt().toInt()) : _fraction.format(number.toDouble());
    return decimal(value) < Decimal.zero ? '-$text' : text;
  }

  /// A deduction such as a voucher: `- ৳ 800`.
  static String deduction(Object? value) => '- $taka ${amount(decimal(value).abs())}';

  static DateTime toDhaka(DateTime value) => value.toUtc().add(dhakaOffset);

  /// `22 Oct 2025, 10:24 AM` in Dhaka time.
  static String dateTime(DateTime? value) => value == null ? '' : _dateTime.format(toDhaka(value));

  /// `22 Oct 2025` in Dhaka time.
  static String date(DateTime? value) => value == null ? '' : _date.format(toDhaka(value));

  /// `10:24 AM` in Dhaka time.
  static String time(DateTime? value) => value == null ? '' : _time.format(toDhaka(value));

  /// `just now`, `5 min ago`, `3 h ago`, then the date.
  static String relative(DateTime? value, {DateTime? now}) {
    if (value == null) return '';
    final elapsed = (now ?? DateTime.now()).difference(value);
    if (elapsed.inSeconds < 45) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes.clamp(1, 59)} min ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours} h ago';
    if (elapsed.inDays < 7) return elapsed.inDays == 1 ? 'yesterday' : '${elapsed.inDays} days ago';
    return date(value);
  }

  /// `01712345678`, `8801712345678`, or `+880 1712-345678` -> `+880 1712 345678`.
  static String phone(String? raw) {
    if (raw == null) return '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final String local;
    if (digits.length == 13 && digits.startsWith('880')) {
      local = digits.substring(3);
    } else if (digits.length == 11 && digits.startsWith('01')) {
      local = digits.substring(1);
    } else if (digits.length == 10 && digits.startsWith('1')) {
      local = digits;
    } else {
      return raw.trim();
    }
    return '+880 ${local.substring(0, 4)} ${local.substring(4)}';
  }

  /// `+880 1712 345678` -> `01712345678`, the form the API stores.
  static String phoneForApi(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('880')) return '0${digits.substring(3)}';
    if (digits.length == 10 && digits.startsWith('1')) return '0$digits';
    return digits;
  }

  /// `1 Item`, `12 Items`, `1,240 Items`.
  static String items(int count) => '${_whole.format(count)} ${count == 1 ? 'Item' : 'Items'}';

  /// `3.2K`, used for compact counters.
  static String compact(int count) => _compact.format(count);

  /// `20% OFF`
  static String discount(int percent) => '$percent% OFF';
}
