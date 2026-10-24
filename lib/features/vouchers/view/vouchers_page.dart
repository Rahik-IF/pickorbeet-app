import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/core/widgets/search_pill.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/vouchers/model/store_voucher.dart';
import 'package:pickorbeet/features/vouchers/view/voucher_card.dart';

/// My Vouchers, matching the offer-wallet design: banner, filter chips, and ticket cards.
class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});

  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage> {
  static const _page = Color(0xFFF4F7FE);

  VoucherFilter _filter = VoucherFilter.all;

  void _select(VoucherFilter filter) {
    if (filter == _filter) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = filter);
  }

  void _use(StoreVoucher voucher) {
    showToast(context, 'Use ${voucher.code} at checkout', kind: ToastKind.success);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      context.go(Routes.cart);
    });
  }

  void _terms(StoreVoucher voucher) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPallete.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _TermsSheet(voucher: voucher),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vouchers = vouchersFor(_filter);
    return Scaffold(
      backgroundColor: _page,
      body: Column(
        children: [
          const _VoucherHeader(),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 24),
              children: [
                const _Hero().entrance(rise: 10),
                const SizedBox(height: 12),
                _Filters(selected: _filter, onSelect: _select).entrance(index: 1, rise: 8),
                const SizedBox(height: 12),
                AnimatedSize(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.emphasizedDecelerate,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      for (var i = 0; i < vouchers.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        VoucherCard(
                          key: ValueKey('${_filter.name}-${vouchers[i].id}'),
                          voucher: vouchers[i],
                          onUse: () => _use(vouchers[i]),
                          onTerms: () => _terms(vouchers[i]),
                        ).entrance(index: i, rise: 12),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherHeader extends StatelessWidget {
  const _VoucherHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: HeaderBackground(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: SizedBox(
          height: top + TabHeader.contentHeight,
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      HeaderBackButton(
                        onPressed: () => context.canPop() ? context.pop() : context.go(Routes.account),
                      ),
                      const BrandLockup(markSize: Size(30, 31), wordmarkSize: 19.5, gap: 6),
                      const Spacer(),
                      const HeaderCartButton(showZero: true),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(15.6, 0, 15.6, 0),
                  child: _Search(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search();

  @override
  Widget build(BuildContext context) {
    return SearchPill(heroTag: 'search-vouchers', onTap: () => context.push(Routes.search));
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFDFB), Color(0xFFFFF4EA), Color(0xFFFFE7D2)],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF14289A).withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: const Stack(
        children: [
          Positioned(right: -6, bottom: -8, child: _HeroArt()),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 132, 12),
            child: _HeroCopy(),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 13,
              decoration: BoxDecoration(color: const Color(0xFFFF7A12), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
            Text(
              'My Vouchers',
              style: AppTypography.labelSmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFF7A12),
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Save More\nEverytime You Shop',
          style: AppTypography.titleLarge.copyWith(
            fontSize: 18.5,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            color: const Color(0xFF07133A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Collect vouchers, apply at checkout\nand enjoy extra discounts.',
          style: AppTypography.bodySmall.copyWith(fontSize: 11, height: 1.3, color: const Color(0xFF6A738C)),
        ),
      ],
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    const art = SizedBox(width: 150, height: 118, child: _ArtScene());
    if (Motion.reduced(context)) return art;
    return art
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -5, duration: 2400.ms, curve: Curves.easeInOut);
  }
}

class _ArtScene extends StatelessWidget {
  const _ArtScene();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 18,
          bottom: 10,
          child: Container(
            width: 78,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFD7E8FF),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const Positioned(left: 8, bottom: 18, child: _GiftBox()),
        const Positioned(right: 6, bottom: 14, child: _ShoppingBag()),
        Positioned(
          right: 28,
          top: 22,
          child: Transform.rotate(angle: 0.22, child: const _MiniTicket(color: Color(0xFFFFB15A))),
        ),
        Positioned(
          right: 8,
          top: 6,
          child: Transform.rotate(
            angle: -0.14,
            child: const _MiniTicket(
              color: Color(0xFFFF7A12),
              mark: '%',
            ),
          ),
        ),
        const Positioned(left: 46, top: 8, child: _Confetti(color: Color(0xFFFF7A12), angle: 0.6)),
        const Positioned(right: 18, top: 2, child: _Confetti(color: Color(0xFF7DB2FE), angle: -0.4)),
        const Positioned(left: 70, top: 28, child: _Confetti(color: Color(0xFFFFD08A), angle: 0.2, size: Size(7, 4))),
      ],
    );
  }
}

class _MiniTicket extends StatelessWidget {
  const _MiniTicket({required this.color, this.mark});

  final Color color;
  final String? mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: mark == null
          ? null
          : Text(
              mark!,
              style: AppTypography.titleLarge.copyWith(fontSize: 26, color: AppPallete.onDark, fontWeight: FontWeight.w800, height: 1),
            ),
    );
  }
}

class _GiftBox extends StatelessWidget {
  const _GiftBox();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30,
            height: 26,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(color: const Color(0xFF3D7DFF), borderRadius: BorderRadius.circular(4)),
          ),
          Positioned(
            top: 4,
            child: Container(
              width: 34,
              height: 8,
              decoration: BoxDecoration(color: const Color(0xFF5B93FF), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Container(width: 4, height: 34, color: const Color(0xFFFFD36A)),
          Positioned(top: 2, child: Container(width: 34, height: 4, color: const Color(0xFFFFD36A))),
        ],
      ),
    );
  }
}

class _ShoppingBag extends StatelessWidget {
  const _ShoppingBag();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 40,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 28,
            height: 30,
            decoration: BoxDecoration(color: const Color(0xFFFF8A1E), borderRadius: BorderRadius.circular(6)),
          ),
          Positioned(
            top: 2,
            child: Container(
              width: 16,
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFD7A8), width: 2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Confetti extends StatelessWidget {
  const _Confetti({required this.color, required this.angle, this.size = const Size(8, 4)});

  final Color color;
  final double angle;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(width: size.width, height: size.height, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelect});

  final VoucherFilter selected;
  final ValueChanged<VoucherFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          for (final filter in VoucherFilter.values) ...[
            if (filter != VoucherFilter.all) const SizedBox(width: 8),
            _FilterChip(
              filter: filter,
              count: voucherCount(filter),
              selected: filter == selected,
              onTap: () => onSelect(filter),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.filter, required this.count, required this.selected, required this.onTap});

  final VoucherFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (filter) {
      VoucherFilter.all => const _ChipTone(Color(0xFFFF7A12), Color(0xFFFF7A12), PhosphorIconsFill.ticket),
      VoucherFilter.available => const _ChipTone(Color(0xFF16A34A), Color(0xFFD8F5E3), PhosphorIconsFill.checkCircle),
      VoucherFilter.used => const _ChipTone(Color(0xFF6B7280), Color(0xFFE6E8EE), PhosphorIconsFill.clock),
      VoucherFilter.expired => const _ChipTone(Color(0xFFE11D48), Color(0xFFFCD5DC), PhosphorIconsFill.xCircle),
    };
    final duration = Motion.of(context, Motion.short);
    return Pressable(
      semanticLabel: '${_label(filter)}, $count',
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Motion.emphasizedDecelerate,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? tone.accent : AppPallete.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? tone.accent : tone.border, width: 1.4),
          boxShadow: selected
              ? [BoxShadow(color: tone.accent.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          children: [
            Icon(tone.icon, size: 14, color: selected ? AppPallete.onDark : tone.accent),
            const SizedBox(width: 5),
            Text(
              _label(filter),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppPallete.onDark : tone.accent,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: duration,
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppPallete.surface : tone.border.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: tone.accent,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(VoucherFilter filter) => switch (filter) {
        VoucherFilter.all => 'All Vouchers',
        VoucherFilter.available => 'Available',
        VoucherFilter.used => 'Used',
        VoucherFilter.expired => 'Expired',
      };
}

class _ChipTone {
  const _ChipTone(this.accent, this.border, this.icon);

  final Color accent;
  final Color border;
  final IconData icon;
}

class _TermsSheet extends StatelessWidget {
  const _TermsSheet({required this.voucher});

  final StoreVoucher voucher;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE3E7EF), borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          Text(voucher.title, style: AppTypography.titleLarge.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Code ${voucher.code}', style: AppTypography.bodyMedium.copyWith(color: voucher.tone.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(voucher.terms, style: AppTypography.bodyMedium.copyWith(color: const Color(0xFF4C556E), height: 1.4)),
          const SizedBox(height: 8),
          Text(voucher.when, style: AppTypography.bodySmall.copyWith(color: const Color(0xFF8B93A7))),
        ],
      ),
    );
  }
}
