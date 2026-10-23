import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/motion/animated_values.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_spacing.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/core/widgets/price_text.dart';
import 'package:pickorbeet/core/widgets/quantity_stepper.dart';
import 'package:pickorbeet/core/widgets/skeleton.dart';
import 'package:pickorbeet/features/cart/models/cart_model.dart';
import 'package:pickorbeet/features/checkout/checkout_args.dart';
import 'package:pickorbeet/features/checkout/checkout_logic.dart';

/// Colors measured from the checkout design (460px art, scaled to the 411dp app width).
abstract final class CheckoutColors {
  static const page = Color(0xFFF8FAFE);
  static const selectedFill = Color(0xFFF0F6FE);
  static const selectedBorder = Color(0xFF1A6FE0);
  static const idleBorder = Color(0xFFE5E9F2);
  static const line = Color(0xFFE4E6EC);
  static const stepIdle = Color(0xFFE8EBF2);
  static const muted = Color(0xFF9AA2B5);
  static const body = Color(0xFF5E6880);
  static const contact = Color(0xFF2C3550);
  static const link = Color(0xFF1A6FE0);
  static const secure = Color(0xFF12A34A);
  static const secureFill = Color(0xFFE7F8EE);
  static const icon = Color(0xFF3E4864);

  static const margin = 14.0;
  static const cardRadius = 16.0;
  static const choiceRadius = 12.0;
}

/// Back, wordmark, bell, and cart — the checkout header on the design.
class CheckoutHeader extends StatelessWidget {
  const CheckoutHeader({super.key});

  static const contentHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: HeaderBackground(
        child: SizedBox(
          height: top + contentHeight,
          child: Padding(
            padding: EdgeInsets.only(top: top, left: 2, right: 6),
            child: const Row(
              children: [
                HeaderBackButton(),
                BrandLockup(markSize: Size(31, 32), wordmarkSize: 20),
                Spacer(),
                HeaderBellButton(),
                SizedBox(width: 2),
                HeaderDivider(),
                SizedBox(width: 2),
                HeaderCartButton(),
                SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Address, Payment, Review, Complete. Only the reached steps are orange.
class CheckoutStepper extends StatelessWidget {
  const CheckoutStepper({super.key, required this.active});

  final int active;

  static const labels = ['Address', 'Payment', 'Review', 'Complete'];

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.short);
    final step = active.clamp(0, labels.length - 1);
    return Semantics(
      label: 'Checkout step ${step + 1} of ${labels.length}, ${labels[step]}',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / labels.length;
              return SizedBox(
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: slot / 2,
                      right: slot / 2,
                      child: Row(
                        children: [
                          for (var i = 0; i < labels.length - 1; i++)
                            Expanded(
                              child: AnimatedContainer(
                                duration: duration,
                                curve: Motion.emphasizedDecelerate,
                                height: 1.6,
                                color: step > i
                                    ? AppPallete.accent
                                    : CheckoutColors.line,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Expanded(
                            child: Center(
                              child: _StepDot(
                                number: i + 1,
                                filled: i <= step,
                                duration: duration,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                      color: i <= step
                          ? AppPallete.accent
                          : CheckoutColors.muted,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.filled,
    required this.duration,
  });

  final int number;
  final bool filled;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: Motion.emphasizedDecelerate,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppPallete.accent : CheckoutColors.stepIdle,
        shape: BoxShape.circle,
        boxShadow: filled
            ? [
                BoxShadow(
                  color: AppPallete.accent.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        '$number',
        textScaler: TextScaler.noScaling,
        style: AppTypography.label.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: filled ? AppPallete.onDark : CheckoutColors.muted,
          height: 1,
        ),
      ),
    );
  }
}

class CheckoutRadio extends StatelessWidget {
  const CheckoutRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.short);
    return AnimatedContainer(
      duration: duration,
      curve: Motion.emphasizedDecelerate,
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPallete.surface,
        border: Border.all(
          color: selected
              ? CheckoutColors.selectedBorder
              : const Color(0xFFD5DCEC),
          width: 1.6,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutBack,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: CheckoutColors.selectedBorder,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 8),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.surface,
        borderRadius: BorderRadius.circular(CheckoutColors.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.titleMedium.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        height: 1.15,
      ),
    );
  }
}

class _SectionSubtitle extends StatelessWidget {
  const _SectionSubtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodyLarge.copyWith(
        fontSize: 11.5,
        height: 1.3,
        color: CheckoutColors.muted,
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: CheckoutColors.link),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.label.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: CheckoutColors.link,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delivery address block: title, add action, and the address list or a form.
class DeliveryAddressCard extends StatelessWidget {
  const DeliveryAddressCard({
    super.key,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.child,
  });

  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  PhosphorIconsFill.mapPin,
                  size: 18,
                  color: AppPallete.accent,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Delivery Address'),
                    SizedBox(height: 2),
                    _SectionSubtitle(
                      'Select a delivery address for your order',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LinkButton(
                icon: actionIcon,
                label: actionLabel,
                onTap: onAction,
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class AddressChoice extends StatelessWidget {
  const AddressChoice({
    super.key,
    required this.address,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
  });

  final AddressModel address;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final title = address.placeName;
    final duration = Motion.of(context, Motion.short);
    final lines = checkoutAddressLines(address);
    final contact = checkoutContactLine(address);
    final icon = _placeIcon(title);
    return Pressable(
      semanticLabel: selected ? '$title, selected' : title,
      pressedScale: 0.985,
      haptic: true,
      onTap: onSelect,
      child: AnimatedContainer(
        duration: duration,
        curve: Motion.emphasizedDecelerate,
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: selected ? CheckoutColors.selectedFill : AppPallete.surface,
          borderRadius: BorderRadius.circular(CheckoutColors.choiceRadius),
          border: Border.all(
            color: selected
                ? CheckoutColors.selectedBorder
                : CheckoutColors.idleBorder,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            CheckoutRadio(selected: selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: CheckoutColors.icon),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (address.isDefault) ...const [
                        SizedBox(width: 6),
                        _DefaultBadge(),
                      ],
                      const Spacer(),
                      _LinkButton(
                        icon: PhosphorIconsRegular.pencilSimple,
                        label: 'Edit',
                        onTap: onEdit,
                      ),
                    ],
                  ),
                  if (lines.isNotEmpty || contact.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in lines)
                            Text(
                              line,
                              style: AppTypography.bodyLarge.copyWith(
                                fontSize: 12,
                                height: 1.45,
                                color: CheckoutColors.body,
                              ),
                            ),
                          if (contact.isNotEmpty)
                            Text(
                              contact,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 12,
                                height: 1.4,
                                color: CheckoutColors.contact,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _placeIcon(String label) {
  final name = label.trim().toLowerCase();
  if (name.contains('office') || name.contains('work')) {
    return PhosphorIconsRegular.buildings;
  }
  if (name.contains('home')) return PhosphorIconsRegular.house;
  return PhosphorIconsRegular.mapPin;
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.accent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          'Default',
          textScaler: TextScaler.noScaling,
          style: AppTypography.labelSmall.copyWith(
            color: AppPallete.onDark,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class OrderItemsCard extends StatelessWidget {
  const OrderItemsCard({
    super.key,
    required this.items,
    required this.onQuantity,
    required this.onEditCart,
  });

  final List<CartItemModel> items;
  final void Function(CartItemModel item, int quantity) onQuantity;
  final VoidCallback onEditCart;

  @override
  Widget build(BuildContext context) {
    final units = items.fold<int>(0, (sum, item) => sum + item.quantity);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.shoppingBag,
                size: 18,
                color: CheckoutColors.link,
              ),
              const SizedBox(width: 8),
              Expanded(child: _SectionTitle('Order Items ($units)')),
              _LinkButton(
                icon: PhosphorIconsRegular.pencilSimple,
                label: 'Edit Cart',
                onTap: onEditCart,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _CheckoutLine(
              item: items[i],
              onQuantity: (quantity) => onQuantity(items[i], quantity),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine({required this.item, required this.onQuantity});

  final CartItemModel item;
  final ValueChanged<int> onQuantity;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.shortDescription.trim().isNotEmpty
        ? item.shortDescription.trim()
        : item.variantLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            children: [
              AppNetworkImage(
                url: item.productImage,
                borderRadius: BorderRadius.circular(10),
                background: const Color(0xFFF3F5FA),
              ),
              if (item.hasDiscount)
                Positioned(
                  left: 4,
                  top: 4,
                  child: DiscountBadge(
                    percent: item.discountPercentage,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: 11.5,
                    height: 1.3,
                    color: CheckoutColors.body,
                  ),
                ),
              if (item.isOutOfStock)
                Text(
                  'Out of stock',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppPallete.danger,
                    fontSize: 11,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PriceText(
                      price: item.unitPrice,
                      comparePrice: item.comparePrice,
                      style: AppTypography.price.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppPallete.ink,
                      ),
                      strikeStyle: AppTypography.strike.copyWith(
                        fontSize: 12,
                        color: const Color(0xFFB0B6C6),
                      ),
                    ),
                  ),
                  QuantityStepper(
                    value: item.quantity,
                    max: item.maxQuantity,
                    enabled: !item.isOutOfStock,
                    height: 28,
                    buttonWidth: 28,
                    valueWidth: 24,
                    radius: 8,
                    onChanged: onQuantity,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final CheckoutPayment selected;
  final ValueChanged<CheckoutPayment> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  PhosphorIconsRegular.creditCard,
                  size: 18,
                  color: Color(0xFF5B6A88),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Payment Method'),
                    SizedBox(height: 2),
                    _SectionSubtitle('Select a payment method'),
                  ],
                ),
              ),
              SizedBox(width: 8),
              _SecureBadge(),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < CheckoutPayment.values.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PaymentRow(
              method: CheckoutPayment.values[i],
              selected: selected == CheckoutPayment.values[i],
              enabled: enabled,
              onTap: () => onChanged(CheckoutPayment.values[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CheckoutColors.secureFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsFill.checkCircle,
              size: 12,
              color: CheckoutColors.secure,
            ),
            const SizedBox(width: 4),
            Text(
              'Secure Payment',
              textScaler: TextScaler.noScaling,
              style: AppTypography.label.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: CheckoutColors.secure,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final CheckoutPayment method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, Motion.short);
    return Pressable(
      semanticLabel: selected ? '${method.label}, selected' : method.label,
      pressedScale: 0.985,
      haptic: true,
      enabled: enabled,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Motion.emphasizedDecelerate,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected ? CheckoutColors.selectedFill : AppPallete.surface,
          borderRadius: BorderRadius.circular(CheckoutColors.choiceRadius),
          border: Border.all(
            color: selected
                ? CheckoutColors.selectedBorder
                : CheckoutColors.idleBorder,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            CheckoutRadio(selected: selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    method.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      fontSize: 11.5,
                      height: 1.3,
                      color: CheckoutColors.body,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PaymentMark(method: method),
          ],
        ),
      ),
    );
  }
}

class _PaymentMark extends StatelessWidget {
  const _PaymentMark({required this.method});

  final CheckoutPayment method;

  @override
  Widget build(BuildContext context) {
    return switch (method) {
      CheckoutPayment.bkash => const CustomPaint(
        size: Size(36, 22),
        painter: _BkashPainter(),
      ),
      CheckoutPayment.nagad => const _NagadMark(),
      CheckoutPayment.card => const _CardMarks(),
      CheckoutPayment.cod => const _CodMark(),
    };
  }
}

class _BkashPainter extends CustomPainter {
  const _BkashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE2136E);
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.78)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.05,
        size.width * 0.62,
        size.height * 0.02,
        size.width * 0.98,
        size.height * 0.22,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.28,
        size.width * 0.58,
        size.height * 0.55,
        size.width * 0.7,
        size.height * 0.96,
      )
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.62,
        size.width * 0.22,
        size.height * 0.7,
        size.width * 0.05,
        size.height * 0.78,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BkashPainter oldDelegate) => false;
}

class _NagadMark extends StatelessWidget {
  const _NagadMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CustomPaint(size: Size(18, 18), painter: _NagadOrbPainter()),
        const SizedBox(width: 3),
        Text(
          'নগদ',
          textScaler: TextScaler.noScaling,
          style: AppTypography.titleSmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFE10600),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _NagadOrbPainter extends CustomPainter {
  const _NagadOrbPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.width / 2,
      Paint()..color = const Color(0xFFFF5A00),
    );
    canvas.drawCircle(
      center.translate(2.4, -0.6),
      size.width / 2.35,
      Paint()..color = AppPallete.onDark,
    );
    canvas.drawCircle(
      center.translate(4.2, -1.1),
      size.width / 3.1,
      Paint()..color = const Color(0xFFFF5A00),
    );
  }

  @override
  bool shouldRepaint(covariant _NagadOrbPainter oldDelegate) => false;
}

class _CardMarks extends StatelessWidget {
  const _CardMarks();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VisaMark(),
        SizedBox(width: 5),
        _MastercardMark(),
        SizedBox(width: 5),
        _AmexMark(),
      ],
    );
  }
}

class _VisaMark extends StatelessWidget {
  const _VisaMark();

  @override
  Widget build(BuildContext context) {
    return Text(
      'VISA',
      textScaler: TextScaler.noScaling,
      style: AppTypography.titleSmall.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.4,
        color: const Color(0xFF1A1F71),
        height: 1,
      ),
    );
  }
}

class _MastercardMark extends StatelessWidget {
  const _MastercardMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 12,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: _Coin(color: Color(0xFFEB001B))),
          Positioned(right: 0, top: 0, child: _Coin(color: Color(0xFFF79E1B))),
        ],
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AmexMark extends StatelessWidget {
  const _AmexMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2E77BC),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Text(
          'AMEX',
          textScaler: TextScaler.noScaling,
          style: AppTypography.labelSmall.copyWith(
            color: AppPallete.onDark,
            fontSize: 7,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _CodMark extends StatelessWidget {
  const _CodMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CheckoutColors.secureFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        PhosphorIconsFill.money,
        size: 16,
        color: CheckoutColors.secure,
      ),
    );
  }
}

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.units,
    required this.itemsTotal,
    required this.discount,
    required this.delivery,
    required this.total,
    required this.insideDhaka,
    required this.outsideDhaka,
  });

  final int units;
  final String itemsTotal;
  final String discount;
  final String delivery;
  final String total;
  final String insideDhaka;
  final String outsideDhaka;

  @override
  Widget build(BuildContext context) {
    final label = AppTypography.bodyMedium.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppPallete.ink,
    );
    final amount = AppTypography.titleSmall.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: AppPallete.ink,
    );
    final hasDiscount = Formatters.decimal(discount) > Formatters.decimal('0');
    return _SectionCard(
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                PhosphorIconsRegular.receipt,
                size: 18,
                color: AppPallete.ink,
              ),
              SizedBox(width: 8),
              Expanded(child: _SectionTitle('Order Summary')),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Items ($units)',
            value: itemsTotal,
            labelStyle: label,
            valueStyle: amount,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Discount',
            value: discount,
            labelStyle: label.copyWith(
              color: CheckoutColors.link,
              fontWeight: FontWeight.w600,
            ),
            valueStyle: amount.copyWith(
              color: hasDiscount ? AppPallete.success : AppPallete.ink,
            ),
            deduction: hasDiscount,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Delivery Charge', style: label),
              const SizedBox(width: 4),
              Tooltip(
                message:
                    '${Formatters.money(insideDhaka)} inside Dhaka, ${Formatters.money(outsideDhaka)} outside.',
                triggerMode: TooltipTriggerMode.tap,
                child: const Icon(
                  PhosphorIconsRegular.info,
                  size: 14,
                  color: CheckoutColors.muted,
                ),
              ),
              const Spacer(),
              AnimatedMoney(delivery, style: amount),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: AppPallete.divider),
          ),
          Row(
            children: [
              Text(
                'Total Amount',
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              AnimatedMoney(
                total,
                style: AppTypography.price.copyWith(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: CheckoutColors.link,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    this.deduction = false,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool deduction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        AnimatedMoney(value, deduction: deduction, style: valueStyle),
      ],
    );
  }
}

class CheckoutSkeleton extends StatelessWidget {
  const CheckoutSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CheckoutColors.margin,
        16,
        CheckoutColors.margin,
        24,
      ),
      children: const [
        SkeletonBox(height: 52, radius: 12),
        SizedBox(height: 14),
        SkeletonBox(height: 210, radius: CheckoutColors.cardRadius),
        SizedBox(height: 12),
        SkeletonBox(height: 150, radius: CheckoutColors.cardRadius),
        SizedBox(height: 12),
        SkeletonBox(height: 280, radius: CheckoutColors.cardRadius),
        SizedBox(height: 12),
        SkeletonBox(height: 160, radius: CheckoutColors.cardRadius),
      ],
    );
  }
}

class AddressListSkeleton extends StatelessWidget {
  const AddressListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 92, radius: CheckoutColors.choiceRadius),
        SizedBox(height: 10),
        SkeletonBox(height: 92, radius: CheckoutColors.choiceRadius),
      ],
    );
  }
}
