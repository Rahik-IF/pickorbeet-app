import 'package:flutter/material.dart';
import 'package:pickorbeet/core/network/json.dart';
import 'package:pickorbeet/core/utils/formatters.dart';

/// How the left stub draws the offer.
enum VoucherOfferKind { amount, percent, shipping }

/// Whether the shopper can still apply the voucher.
enum VoucherState { available, used, expired }

/// The four chips on the vouchers page. [all] is the design's default.
enum VoucherFilter { all, available, used, expired }

/// Colors for one ticket, sampled from the vouchers design.
@immutable
class VoucherTone {
  const VoucherTone({
    required this.accent,
    required this.stub,
    required this.ink,
    required this.button,
    required this.soft,
  });

  final Color accent;
  final Color stub;
  final Color ink;
  final Color button;
  final Color soft;

  static const orange = VoucherTone(
    accent: Color(0xFFFF7A12),
    stub: Color(0xFFFFF1E6),
    ink: Color(0xFFFF6A00),
    button: Color(0xFFF46D07),
    soft: Color(0xFFFFE4CC),
  );

  static const blue = VoucherTone(
    accent: Color(0xFF2F6BFF),
    stub: Color(0xFFE7F1FF),
    ink: Color(0xFF2F6BFF),
    button: Color(0xFF2F6BFF),
    soft: Color(0xFFD6E6FF),
  );

  static const red = VoucherTone(
    accent: Color(0xFFFF3B4E),
    stub: Color(0xFFFFEBEE),
    ink: Color(0xFFFF2E3F),
    button: Color(0xFFFF2E3F),
    soft: Color(0xFFFFD5DB),
  );

  static const purple = VoucherTone(
    accent: Color(0xFF7C3AED),
    stub: Color(0xFFF3EEFF),
    ink: Color(0xFF7C3AED),
    button: Color(0xFF7C3AED),
    soft: Color(0xFFE4D9FF),
  );

  static const muted = VoucherTone(
    accent: Color(0xFF9AA3B2),
    stub: Color(0xFFF1F2F5),
    ink: Color(0xFF8B93A3),
    button: Color(0xFF9AA3B2),
    soft: Color(0xFFE4E7EE),
  );

  static const _availableCycle = [orange, red, purple, blue];

  static VoucherTone forIndex(int index, VoucherState state) => switch (state) {
        VoucherState.expired => muted,
        VoucherState.used => purple,
        VoucherState.available => _availableCycle[index % _availableCycle.length],
      };
}

/// One shopper voucher card.
@immutable
class StoreVoucher {
  const StoreVoucher({
    required this.id,
    required this.code,
    required this.kind,
    required this.state,
    required this.tone,
    required this.headline,
    required this.caption,
    required this.minimum,
    required this.title,
    required this.detail,
    required this.when,
    required this.terms,
  });

  final String id;
  final String code;
  final VoucherOfferKind kind;
  final VoucherState state;
  final VoucherTone tone;

  /// Large stub line, such as `৳200` or `10%`.
  final String headline;
  final String caption;
  final String minimum;
  final String title;
  final String detail;

  /// `Valid till 31 Oct 2026`, `Used on 12 Oct 2026`, or `Expired on 01 Oct 2026`.
  final String when;
  final String terms;

  bool get canUse => state == VoucherState.available;

  String get actionLabel => switch (state) {
        VoucherState.available => 'Use Now',
        VoucherState.used => 'Used',
        VoucherState.expired => 'Expired',
      };

  String get statusLabel => switch (state) {
        VoucherState.available => 'Available',
        VoucherState.used => 'Used',
        VoucherState.expired => 'Expired',
      };

  /// Maps one row from `GET /orders/coupons/`.
  factory StoreVoucher.fromApi(Json json, {int index = 0}) {
    final state = switch (json.str('state')) {
      'used' => VoucherState.used,
      'expired' => VoucherState.expired,
      _ => VoucherState.available,
    };
    final type = json.str('discount_type');
    final value = json.money('discount_value');
    final min = Formatters.decimal(json.money('minimum_order_amount'));
    final until = json.date('valid_until');
    final usedAt = json.date('used_at');
    final description = json.str('description').trim();
    final name = json.str('name');
    final code = json.str('code');
    final isPercent = type == 'percentage';
    final offer = isPercent
        ? '${Formatters.amount(value)}%'
        : '${Formatters.taka}${Formatters.amount(value)}';
    final when = switch (state) {
      VoucherState.used => 'Used on ${Formatters.date(usedAt)}',
      VoucherState.expired => 'Expired on ${Formatters.date(until)}',
      VoucherState.available => 'Valid till ${Formatters.date(until)}',
    };
    final minimum = min > Formatters.decimal('0')
        ? 'Min. spend ${Formatters.money(min)}'
        : 'No minimum spend';
    final detail = switch (state) {
      VoucherState.used => 'You have already used this voucher',
      VoucherState.expired => 'This voucher has expired',
      VoucherState.available when description.isNotEmpty => description,
      VoucherState.available => isPercent
          ? 'Get $offer off your order'
          : 'Get ${Formatters.money(value)} off your order',
    };
    final terms = description.isNotEmpty
        ? description
        : switch (state) {
            VoucherState.used =>
              'This voucher was applied on ${Formatters.date(usedAt)} and cannot be used again.',
            VoucherState.expired =>
              'This offer ended on ${Formatters.date(until)}. It no longer applies at checkout.',
            VoucherState.available =>
              'Code $code. $minimum. One voucher per order.',
          };

    return StoreVoucher(
      id: json.str('id'),
      code: code,
      kind: isPercent ? VoucherOfferKind.percent : VoucherOfferKind.amount,
      state: state,
      tone: VoucherTone.forIndex(index, state),
      headline: offer,
      caption: 'OFF',
      minimum: minimum,
      title: name.isEmpty ? code : name,
      detail: detail,
      when: when,
      terms: terms,
    );
  }
}

List<StoreVoucher> vouchersFor(List<StoreVoucher> vouchers, VoucherFilter filter) =>
    switch (filter) {
      VoucherFilter.all => vouchers,
      VoucherFilter.available =>
        vouchers.where((voucher) => voucher.state == VoucherState.available).toList(),
      VoucherFilter.used =>
        vouchers.where((voucher) => voucher.state == VoucherState.used).toList(),
      VoucherFilter.expired =>
        vouchers.where((voucher) => voucher.state == VoucherState.expired).toList(),
    };

int voucherCount(List<StoreVoucher> vouchers, VoucherFilter filter) =>
    vouchersFor(vouchers, filter).length;
