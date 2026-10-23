import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/features/account/model/shipment.dart';
import 'package:pickorbeet/features/account/view/orders_palette.dart';

StatusPalette courierPalette(String group) => switch (group) {
  'in_review' => CourierPalette.inReview,
  'pending' => CourierPalette.pending,
  'hold' => CourierPalette.hold,
  'delivered' => CourierPalette.delivered,
  'partial_delivered' => CourierPalette.partialDelivered,
  'cancelled' => CourierPalette.cancelled,
  _ => CourierPalette.unknown,
};

/// Steadfast status, tracking code, and the updates Steadfast has sent.
class ShipmentCard extends StatelessWidget {
  const ShipmentCard({
    super.key,
    required this.shipment,
    this.onRefresh,
    this.onOpenTracking,
    this.onCopy,
    this.refreshing = false,
    this.waitSeconds = 0,
  });

  final Shipment shipment;
  final VoidCallback? onRefresh;
  final VoidCallback? onOpenTracking;
  final VoidCallback? onCopy;
  final bool refreshing;
  final int waitSeconds;

  @override
  Widget build(BuildContext context) {
    final palette = courierPalette(shipment.statusGroup);
    final cod = shipment.codAmount;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrdersPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(PhosphorIconsRegular.truck, size: 18, color: palette.icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shipment.courierName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: OrdersPalette.ink,
                      ),
                    ),
                    Text(
                      'Parcel tracking',
                      style: AppTypography.bodySmall.copyWith(color: OrdersPalette.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    shipment.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (shipment.hasCode) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tracking code',
                        style: AppTypography.bodySmall.copyWith(color: OrdersPalette.muted, fontSize: 11),
                      ),
                      Text(
                        shipment.trackingCode!,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: OrdersPalette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCopy != null)
                  Pressable(
                    onTap: onCopy,
                    semanticLabel: 'Copy tracking code',
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(PhosphorIconsRegular.copy, size: 18, color: OrdersPalette.muted),
                    ),
                  ),
              ],
            ),
          ],
          if (shipment.statusMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              shipment.statusMessage,
              style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft),
            ),
          ],
          if (cod != null) ...[
            const SizedBox(height: 8),
            Text(
              Formatters.decimal(cod) > Formatters.decimal('0')
                  ? 'Cash to pay the rider: ${Formatters.money(cod)}'
                  : 'Paid online. Nothing to pay the rider.',
              style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft),
            ),
          ],
          if (shipment.statusUpdatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Updated ${Formatters.relative(shipment.statusUpdatedAt)}',
              style: AppTypography.bodySmall.copyWith(color: OrdersPalette.hint, fontSize: 11),
            ),
          ],
          if (onOpenTracking != null || onRefresh != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onOpenTracking != null)
                  Expanded(
                    child: _MiniButton(
                      label: 'Open Steadfast',
                      icon: PhosphorIconsRegular.arrowSquareOut,
                      onTap: onOpenTracking,
                    ),
                  ),
                if (onOpenTracking != null && onRefresh != null) const SizedBox(width: 8),
                if (onRefresh != null)
                  Expanded(
                    child: _MiniButton(
                      label: refreshing
                          ? 'Checking'
                          : waitSeconds > 0
                          ? 'Wait ${waitSeconds}s'
                          : 'Refresh',
                      icon: PhosphorIconsRegular.arrowsClockwise,
                      spinning: refreshing,
                      onTap: refreshing || waitSeconds > 0 ? null : onRefresh,
                    ),
                  ),
              ],
            ),
          ],
          if (shipment.events.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: OrdersPalette.line),
            const SizedBox(height: 12),
            Text(
              'COURIER UPDATES',
              style: AppTypography.bodySmall.copyWith(
                color: OrdersPalette.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            for (final event in shipment.events) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(color: palette.icon, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: AppTypography.bodySmall.copyWith(
                            color: OrdersPalette.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (event.message.isNotEmpty)
                          Text(
                            event.message,
                            style: AppTypography.bodySmall.copyWith(color: OrdersPalette.inkSoft),
                          ),
                        if (event.at != null)
                          Text(
                            Formatters.dateTime(event.at),
                            style: AppTypography.bodySmall.copyWith(color: OrdersPalette.hint, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.spinning = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: label,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? OrdersPalette.pillBlue : OrdersPalette.countIdle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: enabled ? const Color(0xFFB9D4FF) : OrdersPalette.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            spinning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: OrdersPalette.blue),
                  )
                : Icon(icon, size: 15, color: enabled ? OrdersPalette.blue : OrdersPalette.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: enabled ? OrdersPalette.blue : OrdersPalette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies a tracking code and confirms it with a light tap.
Future<void> copyTrackingCode(BuildContext context, String code, void Function(String message) toast) async {
  await Clipboard.setData(ClipboardData(text: code));
  await HapticFeedback.selectionClick();
  if (!context.mounted) return;
  toast('Tracking code copied');
}
