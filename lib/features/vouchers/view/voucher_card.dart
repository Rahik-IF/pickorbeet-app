import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/features/vouchers/model/store_voucher.dart';

/// Ticket card: colored stub, notched seam, and the offer on the right.
class VoucherCard extends StatelessWidget {
  const VoucherCard({super.key, required this.voucher, required this.onUse, required this.onTerms});

  final StoreVoucher voucher;
  final VoidCallback onUse;
  final VoidCallback onTerms;

  static const radius = 14.0;
  static const seam = 104.0;
  static const notch = 8.0;

  @override
  Widget build(BuildContext context) {
    final tone = voucher.tone;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14289A).withValues(alpha: voucher.canUse ? 0.07 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipPath(
        clipper: const _TicketClipper(seam: seam, notch: notch, radius: radius),
        child: ColoredBox(
          color: AppPallete.surface,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: seam,
                  child: ColoredBox(
                    color: tone.stub,
                    child: _Stub(voucher: voucher),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                        child: Row(
                          children: [
                            Expanded(child: _Details(voucher: voucher, onTerms: onTerms)),
                            const SizedBox(width: 8),
                            _Action(voucher: voucher, onUse: onUse),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: -6,
                        child: Icon(
                          voucher.kind == VoucherOfferKind.shipping
                              ? PhosphorIconsFill.truck
                              : PhosphorIconsFill.percent,
                          size: 54,
                          color: tone.accent.withValues(alpha: voucher.state == VoucherState.expired ? 0.08 : 0.1),
                        ),
                      ),
                      const Positioned(left: 0, top: notch + 6, bottom: notch + 6, width: 1, child: _Seam()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub({required this.voucher});

  final StoreVoucher voucher;

  @override
  Widget build(BuildContext context) {
    final tone = voucher.tone;
    final shipping = voucher.kind == VoucherOfferKind.shipping;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (shipping) ...[
            Icon(PhosphorIconsFill.truck, size: 22, color: tone.ink),
            const SizedBox(height: 2),
            Text(
              'FREE\nSHIPPING',
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(
                fontSize: 11,
                height: 1.05,
                fontWeight: FontWeight.w800,
                color: tone.ink,
                letterSpacing: 0.2,
              ),
            ),
          ] else ...[
            Text(
              voucher.headline,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
                color: tone.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              voucher.caption,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w800,
                color: tone.ink,
                letterSpacing: 0.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            voucher.minimum,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(fontSize: 8.5, height: 1.15, color: tone.ink.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.voucher, required this.onTerms});

  final StoreVoucher voucher;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatusPill(voucher: voucher),
        const SizedBox(height: 5),
        Text(
          voucher.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleSmall.copyWith(fontSize: 13, height: 1.15, fontWeight: FontWeight.w800, color: const Color(0xFF07133A)),
        ),
        const SizedBox(height: 2),
        Text(
          voucher.detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(fontSize: 10.5, height: 1.25, color: const Color(0xFF6A738C)),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(
              voucher.state == VoucherState.available ? PhosphorIconsRegular.calendarBlank : PhosphorIconsRegular.calendarCheck,
              size: 11,
              color: const Color(0xFF8B93A7),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                voucher.when,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(fontSize: 10, height: 1.1, color: const Color(0xFF8B93A7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Pressable(
          semanticLabel: 'Terms and conditions for ${voucher.title}',
          pressedScale: 0.98,
          onTap: onTerms,
          child: Text(
            'T&C\nApply',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 9,
              height: 1.05,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B93A7),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.voucher});

  final StoreVoucher voucher;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (voucher.state) {
      VoucherState.available => (const Color(0xFFE5F8EC), const Color(0xFF12924A), PhosphorIconsFill.checkCircle),
      VoucherState.used => (const Color(0xFFF1F2F6), const Color(0xFF8B93A3), PhosphorIconsFill.clock),
      VoucherState.expired => (const Color(0xFFFDECEE), const Color(0xFFE11D48), PhosphorIconsFill.xCircle),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            voucher.statusLabel,
            style: AppTypography.labelSmall.copyWith(fontSize: 9, height: 1, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.voucher, required this.onUse});

  final StoreVoucher voucher;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final enabled = voucher.canUse;
    final button = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? voucher.tone.button : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(8),
        border: enabled ? null : Border.all(color: const Color(0xFFE3E7EF)),
        boxShadow: enabled
            ? [BoxShadow(color: voucher.tone.button.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3))]
            : null,
      ),
      child: Text(
        voucher.actionLabel,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 11.5,
          height: 1,
          fontWeight: FontWeight.w700,
          color: enabled ? AppPallete.onDark : const Color(0xFFA0A8B8),
        ),
      ),
    );
    if (!enabled) return Semantics(button: true, enabled: false, label: voucher.actionLabel, child: button);
    return Pressable(semanticLabel: '${voucher.actionLabel}, ${voucher.title}', onTap: onUse, child: button);
  }
}

class _Seam extends StatelessWidget {
  const _Seam();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _DashPainter());
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD5DCEA)
      ..strokeWidth = 1;
    const dash = 3.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, (y + dash).clamp(0, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({required this.seam, required this.notch, required this.radius});

  final double seam;
  final double notch;
  final double radius;

  @override
  Path getClip(Size size) {
    final width = size.width;
    final height = size.height;
    final corner = Radius.circular(radius);
    return Path()
      ..moveTo(radius, 0)
      ..lineTo(seam - notch, 0)
      ..arcTo(Rect.fromCircle(center: Offset(seam, 0), radius: notch), math.pi, math.pi, false)
      ..lineTo(width - radius, 0)
      ..arcToPoint(Offset(width, radius), radius: corner)
      ..lineTo(width, height - radius)
      ..arcToPoint(Offset(width - radius, height), radius: corner)
      ..lineTo(seam + notch, height)
      ..arcTo(Rect.fromCircle(center: Offset(seam, height), radius: notch), 0, -math.pi, false)
      ..lineTo(radius, height)
      ..arcToPoint(Offset(0, height - radius), radius: corner)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: corner)
      ..close();
  }

  @override
  bool shouldReclip(_TicketClipper oldDelegate) => false;
}
