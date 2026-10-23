import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_spacing.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:pickorbeet/features/catalog/repositories/catalog_repository.dart';
import 'package:pickorbeet/features/catalog/viewmodel/catalog_providers.dart';

/// The home header's menu: shortcuts, every category, and how to reach the store.
Future<void> showHomeMenu(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppPallete.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
      builder: (_) => const _HomeMenu(),
    );

class _HomeMenu extends ConsumerWidget {
  const _HomeMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(storeSettingsProvider).valueOrNull;

    void go(String location) {
      Navigator.of(context).pop();
      context.push(location);
    }

    final shortcuts = <(IconData, String, String, TileTint)>[
      (PhosphorIconsBold.package, 'Track Order', Routes.trackOrder, DashboardPalette.orders),
      (PhosphorIconsBold.receipt, 'My Orders', Routes.orders, DashboardPalette.addresses),
      (PhosphorIconsBold.heart, 'Wishlist', Routes.wishlist, DashboardPalette.wishlist),
      (PhosphorIconsBold.headset, 'Help', Routes.help, DashboardPalette.help),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          const Row(
            children: [
              BrandLockup.compact(onDark: false),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < shortcuts.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Shortcut(
                    icon: shortcuts[i].$1,
                    label: shortcuts[i].$2,
                    tint: shortcuts[i].$4,
                    onTap: () => go(shortcuts[i].$3),
                  ).entrance(index: i),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text('Shop by category', style: AppTypography.titleSmall),
          const SizedBox(height: 8),
          ...categories.when(
            data: (items) => [
              for (var i = 0; i < items.length; i++)
                _CategoryRow(category: items[i], onTap: () => go(Routes.category(items[i].slug)))
                    .entrance(index: i + 2),
            ],
            loading: () => const [
              Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            ],
            error: (_, _) => [
              _MenuRow(icon: PhosphorIconsBold.squaresFour, label: 'All categories', onTap: () => go(Routes.categories)),
            ],
          ),
          const Divider(height: 28),
          _MenuRow(icon: PhosphorIconsBold.gearSix, label: 'Settings', onTap: () => go(Routes.settings)),
          _MenuRow(icon: PhosphorIconsBold.chatCircleDots, label: 'Contact us', onTap: () => go(Routes.help)),
          if (settings != null && (settings.phones.isNotEmpty || settings.emails.isNotEmpty)) ...[
            const SizedBox(height: 12),
            _ContactCard(settings: settings),
          ],
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.tint, required this.onTap});

  final IconData icon;
  final String label;
  final TileTint tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: tint.background, borderRadius: AppRadii.xlBorder),
        child: Column(
          children: [
            Icon(icon, size: 22, color: tint.icon),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(color: AppPallete.ink, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onTap});

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.98,
      semanticLabel: '${category.name}, ${Formatters.items(category.productCount)}',
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: AppNetworkImage(url: category.image, borderRadius: AppRadii.lgBorder),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, style: AppTypography.titleSmall.copyWith(fontSize: 13)),
                  Text(
                    category.productCount == 0 ? 'No items yet' : Formatters.items(category.productCount),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.caretRight, size: 14, color: AppPallete.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.98,
      semanticLabel: label,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppPallete.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500))),
            const Icon(PhosphorIconsBold.caretRight, size: 14, color: AppPallete.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.settings});

  final StoreSettings settings;

  @override
  Widget build(BuildContext context) {
    final StoreSettings(:phones, :emails, businessHours: hours) = settings;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: AppPallete.surfaceMuted, borderRadius: AppRadii.xlBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phones.isNotEmpty) _ContactLine(icon: PhosphorIconsBold.phone, text: phones.first),
          if (emails.isNotEmpty) _ContactLine(icon: PhosphorIconsBold.envelopeSimple, text: emails.first),
          if (hours.isNotEmpty) _ContactLine(icon: PhosphorIconsBold.clock, text: hours.replaceAll('\n', ' · ')),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppPallete.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTypography.bodySmall)),
        ],
      ),
    );
  }
}
