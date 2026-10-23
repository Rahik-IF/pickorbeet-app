import 'package:flutter/material.dart';

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
}

/// One shopper voucher, in the order the design shows them.
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

  /// Large stub line, such as `৳200` or `10%`. Shipping uses the caption instead.
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
}

/// The six offers in the design. Four are still available, one is used, one has expired.
const storeVouchers = <StoreVoucher>[
  StoreVoucher(
    id: 'electronics',
    code: 'ELEC200',
    kind: VoucherOfferKind.amount,
    state: VoucherState.available,
    tone: VoucherTone.orange,
    headline: '৳200',
    caption: 'OFF',
    minimum: 'Min. spend ৳1,500',
    title: 'Electronics Special',
    detail: 'Get ৳200 off on all electronics products',
    when: 'Valid till 31 Oct 2026',
    terms: 'Applies to electronics when your order is at least ৳1,500. One voucher per order.',
  ),
  StoreVoucher(
    id: 'shipping',
    code: 'SHIPFREE',
    kind: VoucherOfferKind.shipping,
    state: VoucherState.available,
    tone: VoucherTone.blue,
    headline: 'FREE',
    caption: 'SHIPPING',
    minimum: 'Min. spend ৳999',
    title: 'Free Shipping Voucher',
    detail: 'Get free shipping on all products',
    when: 'Valid till 15 Nov 2026',
    terms: 'Waives delivery on any order of at least ৳999. It does not apply to cash-on-delivery charges.',
  ),
  StoreVoucher(
    id: 'all',
    code: 'ALL10',
    kind: VoucherOfferKind.percent,
    state: VoucherState.available,
    tone: VoucherTone.red,
    headline: '10%',
    caption: 'OFF',
    minimum: 'Min. spend ৳2,000',
    title: 'All Categories',
    detail: 'Get 10% off on any category',
    when: 'Valid till 30 Nov 2026',
    terms: 'Takes 10% off an order of at least ৳2,000 across any category. One voucher per order.',
  ),
  StoreVoucher(
    id: 'mega',
    code: 'MEGA500',
    kind: VoucherOfferKind.amount,
    state: VoucherState.used,
    tone: VoucherTone.purple,
    headline: '৳500',
    caption: 'OFF',
    minimum: 'Min. spend ৳5,000',
    title: 'Mega Sale Voucher',
    detail: 'You have already used this voucher',
    when: 'Used on 12 Oct 2026',
    terms: 'This voucher was applied on 12 Oct 2026 and cannot be used again.',
  ),
  StoreVoucher(
    id: 'weekend',
    code: 'WEEK15',
    kind: VoucherOfferKind.percent,
    state: VoucherState.expired,
    tone: VoucherTone.muted,
    headline: '15%',
    caption: 'OFF',
    minimum: 'Min. spend ৳3,000',
    title: 'Weekend Special',
    detail: 'This voucher has expired',
    when: 'Expired on 01 Oct 2026',
    terms: 'This offer ended on 01 Oct 2026. It no longer applies at checkout.',
  ),
  StoreVoucher(
    id: 'welcome',
    code: 'APP100',
    kind: VoucherOfferKind.amount,
    state: VoucherState.available,
    tone: VoucherTone.orange,
    headline: '৳100',
    caption: 'OFF',
    minimum: 'Min. spend ৳800',
    title: 'Welcome Offer',
    detail: 'Get ৳100 off on your next order',
    when: 'Valid till 31 Dec 2026',
    terms: 'Takes ৳100 off an order of at least ৳800. One welcome voucher per customer.',
  ),
];

List<StoreVoucher> vouchersFor(VoucherFilter filter) => switch (filter) {
      VoucherFilter.all => storeVouchers,
      VoucherFilter.available => storeVouchers.where((voucher) => voucher.state == VoucherState.available).toList(),
      VoucherFilter.used => storeVouchers.where((voucher) => voucher.state == VoucherState.used).toList(),
      VoucherFilter.expired => storeVouchers.where((voucher) => voucher.state == VoucherState.expired).toList(),
    };

int voucherCount(VoucherFilter filter) => vouchersFor(filter).length;
