import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/address_model.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/bottom_nav.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/location/address_location.dart';
import 'package:pickorbeet/features/account/repositories/address_repository.dart';

/// Saved delivery addresses, matched to the delivery-address design.
class AddressesPage extends ConsumerStatefulWidget {
  const AddressesPage({super.key, this.startCreating = false, this.editId});

  final bool startCreating;
  final String? editId;

  @override
  ConsumerState<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends ConsumerState<AddressesPage> {
  final _search = TextEditingController();
  String? _busyId;
  var _locating = false;
  var _openedIntent = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openTab(int index) {
    const tabs = [Routes.home, Routes.categories, Routes.wishlist, Routes.account, Routes.cart];
    context.go(tabs[index]);
  }

  List<AddressModel> _visible(List<AddressModel> items) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return [
      for (final item in items)
        if ('${item.placeName} ${item.fullName} ${item.phone} ${item.streetLine} ${item.city} ${item.district} ${item.country}'
            .toLowerCase()
            .contains(query))
          item,
    ];
  }

  Future<void> _openEditor({AddressModel? existing, LocatedPlace? place, required bool makeDefault}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddressEditor(existing: existing, place: place, makeDefault: makeDefault),
    );
    if (saved == true && mounted) {
      ref.invalidate(addressesProvider);
      showToast(context, existing == null ? 'Address saved' : 'Address updated', kind: ToastKind.success);
    }
  }

  void _consumeIntent(List<AddressModel> items) {
    if (_openedIntent) return;
    _openedIntent = true;
    if (widget.startCreating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor(makeDefault: items.isEmpty);
      });
      return;
    }
    final id = widget.editId;
    if (id == null) return;
    AddressModel? match;
    for (final item in items) {
      if (item.id == id) match = item;
    }
    if (match == null) return;
    final address = match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openEditor(existing: address, makeDefault: address.isDefault);
    });
  }

  Future<void> _setDefault(AddressModel address) async {
    if (address.isDefault || _busyId != null) return;
    setState(() => _busyId = address.id);
    final result = await ref.read(addressRepositoryProvider).save(address.copyWith(isDefault: true), id: address.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (_) {
        ref.invalidate(addressesProvider);
        showToast(context, '${address.placeName} is now the default', kind: ToastKind.success);
      },
    );
  }

  Future<void> _delete(AddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text('${address.placeName} will be removed from your saved locations.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE11D2E))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = address.id);
    final result = await ref.read(addressRepositoryProvider).remove(address.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (_) {
        ref.invalidate(addressesProvider);
        showToast(context, 'Address deleted', kind: ToastKind.success);
      },
    );
  }

  Future<void> _useLocation(bool makeDefault) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final place = await locateCurrentPlace();
      if (!mounted) return;
      await _openEditor(place: place, makeDefault: makeDefault);
    } on LocationFailure catch (error) {
      if (!mounted) return;
      showToast(context, error.message, kind: ToastKind.error);
      await _openEditor(makeDefault: makeDefault);
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Could not read this location. Enter the address instead.', kind: ToastKind.error);
      await _openEditor(makeDefault: makeDefault);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFE9EFFD),
      bottomNavigationBar: AppBottomNav(currentIndex: -1, onSelect: _openTab, cartCount: ref.watch(cartCountProvider)),
      body: Column(
        children: [
          _AddressHeader(controller: _search),
          Expanded(
            child: addresses.when(
              loading: () => const _AddressSkeleton(),
              error: (error, _) => _AddressMessage(
                title: error is AppFailure ? error.message : 'Could not load addresses',
                action: 'Try again',
                onAction: () => ref.invalidate(addressesProvider),
              ),
              data: (items) {
                _consumeIntent(items);
                final visible = _visible(items);
                return RefreshIndicator(
                  color: AppPallete.primary,
                  backgroundColor: AppPallete.surface,
                  onRefresh: () async {
                    ref.invalidate(addressesProvider);
                    await ref.read(addressesProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      const _DeliveryHero(),
                      const SizedBox(height: 14),
                      _AddButton(onTap: () => _openEditor(makeDefault: items.isEmpty)),
                      const SizedBox(height: 20),
                      _SectionTitle(count: visible.length),
                      const SizedBox(height: 10),
                      if (visible.isEmpty)
                        _AddressMessage(
                          title: items.isEmpty ? 'No saved addresses yet' : 'No addresses match that search',
                          body: items.isEmpty
                              ? 'Add a home, office, or any place you want orders delivered.'
                              : 'Try a different name, area, or phone number.',
                        )
                      else
                        for (var i = 0; i < visible.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AddressCard(
                              address: visible[i],
                              busy: _busyId == visible[i].id,
                              onSelect: () => _setDefault(visible[i]),
                              onEdit: () => _openEditor(existing: visible[i], makeDefault: visible[i].isDefault),
                              onDelete: () => _delete(visible[i]),
                            ).animate(delay: Motion.staggerDelay(i)).fadeIn(duration: 280.ms).slideY(
                                  begin: 0.08,
                                  end: 0,
                                  duration: 320.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                          ),
                      const SizedBox(height: 4),
                      _CurrentLocationButton(
                        busy: _locating,
                        onTap: () => _useLocation(items.isEmpty),
                      ),
                      const SizedBox(height: 16),
                      const _PrivacyLine(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressHeader extends StatelessWidget {
  const _AddressHeader({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: HeaderBackground(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
        child: Padding(
          padding: EdgeInsets.only(top: top, bottom: 14),
          child: Column(
            children: [
              SizedBox(
                height: 50,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, right: 8),
                  child: Row(
                    children: [
                      HeaderBackButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.account)),
                      const Spacer(),
                      const BrandLockup(markSize: Size(31, 32), wordmarkSize: 20),
                      const Spacer(),
                      const HeaderCartButton(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  style: AppTypography.bodyMedium.copyWith(fontSize: 14, color: AppPallete.ink),
                  cursorColor: AppPallete.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppPallete.surface,
                    hintText: 'Search addresses...',
                    hintStyle: AppTypography.bodyMedium.copyWith(fontSize: 14, color: const Color(0xFF8B93A7)),
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: Color(0xFF5C6578)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryHero extends StatelessWidget {
  const _DeliveryHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
      decoration: BoxDecoration(
        color: AppPallete.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x120F2A62), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where should we deliver?', style: AppTypography.titleLarge.copyWith(fontSize: 16.5, height: 1.15, letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Text(
                  'Manage your saved delivery locations',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 12.5, color: const Color(0xFF6E7890), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 100, height: 70, child: CustomPaint(painter: _HeroScenePainter())),
        ],
      ),
    ).animate().fadeIn(duration: 360.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: 'Add new address',
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFFFF8A1D), Color(0xFFFF5E00)]),
          boxShadow: const [BoxShadow(color: Color(0x40FF6A00), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(PhosphorIconsBold.plus, size: 14, color: Color(0xFFFF6A00)),
            ),
            const SizedBox(width: 10),
            Text(
              'Add New Address',
              style: AppTypography.titleMedium.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 address' : '$count addresses';
    return Row(
      children: [
        Text('Saved addresses', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
        const Spacer(),
        Text(label, style: AppTypography.bodyMedium.copyWith(fontSize: 13, color: const Color(0xFF8A93A8))),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final AddressModel address;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kind = _PlaceKind.of(address.label);
    final parts = [address.streetLine, address.city, address.district, address.country]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final line = [
      for (var i = 0; i < parts.length; i++)
        if (i == 0 || parts[i].toLowerCase() != parts[i - 1].toLowerCase()) parts[i],
    ].join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x100F2A62), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: kind.tint, shape: BoxShape.circle),
                  child: Icon(kind.icon, color: kind.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.placeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppPallete.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address.fullName,
                        style: AppTypography.bodyMedium.copyWith(fontSize: 13, color: const Color(0xFF3C4660)),
                      ),
                      const SizedBox(height: 6),
                      _MetaRow(icon: PhosphorIconsRegular.mapPin, text: line),
                      const SizedBox(height: 3),
                      _MetaRow(icon: PhosphorIconsRegular.phone, text: _displayPhone(address.phone)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    _RadioMark(selected: address.isDefault, busy: busy, onTap: onSelect),
                    const SizedBox(height: 8),
                    const _MapThumb(),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          SizedBox(
            height: 42,
            child: Row(
              children: [
                Expanded(
                  child: _CardAction(
                    icon: PhosphorIconsRegular.pencilSimple,
                    label: 'Edit',
                    color: AppPallete.primary,
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 1, height: 18, child: ColoredBox(color: Color(0xFFE1E6F0))),
                Expanded(
                  child: _CardAction(
                    icon: PhosphorIconsRegular.trash,
                    label: 'Delete',
                    color: const Color(0xFFE11D2E),
                    onTap: onDelete,
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 13, color: const Color(0xFF8B93A7)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(fontSize: 12, height: 1.35, color: const Color(0xFF6A738A)),
          ),
        ),
      ],
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected, required this.busy, required this.onTap});

  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      semanticLabel: selected ? 'Default address' : 'Set as default',
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasized,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppPallete.primary : Colors.transparent,
          border: Border.all(color: selected ? AppPallete.primary : const Color(0xFFC5CDDC), width: 1.6),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(3),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  )
                : null,
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.bodyMedium.copyWith(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      semanticLabel: 'Use current location',
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppPallete.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPallete.primary, width: 1.4),
        ),
        child: Row(
          children: [
            busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppPallete.primary),
                  )
                : const Icon(PhosphorIconsFill.navigationArrow, size: 18, color: AppPallete.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Use current location',
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(color: AppPallete.primary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppPallete.primary),
          ],
        ),
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(PhosphorIconsRegular.shieldCheck, size: 14, color: Color(0xFF9AA3B5)),
        const SizedBox(width: 6),
        Text(
          'Your addresses are kept private and secure.',
          style: AppTypography.bodyMedium.copyWith(fontSize: 12, color: const Color(0xFF9AA3B5)),
        ),
      ],
    );
  }
}

class _AddressMessage extends StatelessWidget {
  const _AddressMessage({required this.title, this.body, this.action, this.onAction});

  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: AppTypography.titleMedium.copyWith(fontSize: 15)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(fontSize: 13, color: const Color(0xFF6E7890)),
            ),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

class _AddressSkeleton extends StatelessWidget {
  const _AddressSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: i == 0 ? 92 : 148,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppPallete.skeleton, borderRadius: BorderRadius.circular(16)),
          ),
      ],
    );
  }
}

class _MapThumb extends StatelessWidget {
  const _MapThumb();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 72, height: 54, child: CustomPaint(painter: _MapThumbPainter()));
  }
}

class _PlaceKind {
  const _PlaceKind(this.icon, this.color, this.tint);

  final IconData icon;
  final Color color;
  final Color tint;

  static _PlaceKind of(String label) {
    final name = label.trim().toLowerCase();
    if (name == 'office' || name.contains('work')) {
      return const _PlaceKind(PhosphorIconsFill.buildings, Color(0xFFE07A1A), Color(0xFFFFF1E0));
    }
    if (name == 'home' || name.isEmpty) {
      return const _PlaceKind(PhosphorIconsFill.house, Color(0xFF3B6BFF), Color(0xFFEAF0FF));
    }
    return const _PlaceKind(PhosphorIconsFill.mapPin, Color(0xFF5B4BDB), Color(0xFFF0ECFF));
  }
}

class _HeroScenePainter extends CustomPainter {
  const _HeroScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFFE7F2FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.62, size.width, size.height * 0.38),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFD7E7F8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.08, size.height * 0.38, 14, 22), const Radius.circular(2)),
      Paint()..color = const Color(0xFFC5D8F2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.24, size.height * 0.28, 12, 30), const Radius.circular(2)),
      Paint()..color = const Color(0xFFB7CEEA),
    );
    final pin = Offset(size.width * 0.62, size.height * 0.34);
    canvas.drawCircle(pin, 10, Paint()..color = const Color(0xFF2F6BFF));
    canvas.drawCircle(pin, 3.5, Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.28, size.height * 0.68, 24, 11), const Radius.circular(3)),
      Paint()..color = const Color(0xFFFF7A1A),
    );
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.3), 6, Paint()..color = const Color(0xFF8FCB7A));
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.28), 5, Paint()..color = const Color(0xFF8FCB7A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapThumbPainter extends CustomPainter {
  const _MapThumbPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xFFE7F6E4),
    );
    final road = Paint()
      ..color = const Color(0xFFF7F4EA)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.55), road);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.55, size.height), road);
    final pin = Paint()..color = const Color(0xFFE23B3B);
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.42), 4.5, pin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _displayPhone(String raw) {
  final formatted = Formatters.phone(raw);
  final match = RegExp(r'^\+880 (\d{4}) (\d+)$').firstMatch(formatted);
  if (match == null) return formatted.isEmpty ? raw : formatted;
  return '+880 ${match.group(1)}-${match.group(2)}';
}

class _AddressEditor extends ConsumerStatefulWidget {
  const _AddressEditor({this.existing, this.place, required this.makeDefault});

  final AddressModel? existing;
  final LocatedPlace? place;
  final bool makeDefault;

  @override
  ConsumerState<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends ConsumerState<_AddressEditor> {
  late final TextEditingController _label;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _postal;
  late bool _defaultAddress;
  var _saving = false;
  String? _error;

  static const _presets = ['Home', 'Office'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final place = widget.place;
    _label = TextEditingController(text: existing?.label ?? '');
    _name = TextEditingController(text: existing?.fullName ?? '');
    _phone = TextEditingController(text: existing == null ? '' : _displayPhone(existing.phone));
    _line1 = TextEditingController(text: existing?.addressLine1 ?? place?.line1 ?? '');
    _line2 = TextEditingController(text: existing?.addressLine2 ?? place?.line2 ?? '');
    _city = TextEditingController(text: existing?.city ?? place?.city ?? '');
    _district = TextEditingController(text: existing?.district ?? place?.district ?? '');
    _postal = TextEditingController(text: existing?.postalCode ?? place?.postalCode ?? '');
    _defaultAddress = existing?.isDefault ?? widget.makeDefault;
  }

  @override
  void dispose() {
    for (final controller in [_label, _name, _phone, _line1, _line2, _city, _district, _postal]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final name = _name.text.trim();
    final phone = Formatters.phoneForApi(_phone.text);
    final line1 = _line1.text.trim();
    final city = _city.text.trim();
    final district = _district.text.trim().isEmpty ? city : _district.text.trim();
    if (label.isEmpty || name.isEmpty || phone.length < 11 || line1.isEmpty || city.isEmpty) {
      setState(() => _error = 'Add a label, name, phone, street, and city.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = AddressModel(
      id: widget.existing?.id ?? '',
      label: label,
      fullName: name,
      phone: phone,
      addressLine1: line1,
      addressLine2: _line2.text.trim(),
      city: city,
      district: district,
      postalCode: _postal.text.trim(),
      country: widget.existing?.country ?? widget.place?.country ?? 'Bangladesh',
      isDefault: _defaultAddress,
    );
    final result = await ref.read(addressRepositoryProvider).save(draft, id: widget.existing?.id);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = failure.fieldErrors.values.isEmpty ? failure.message : failure.fieldErrors.values.first;
      }),
      (_) => Navigator.pop(context, true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final preset = _presets.contains(_label.text.trim()) ? _label.text.trim() : '';
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFD7DEEA), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null ? 'Add New Address' : 'Edit address',
              style: AppTypography.titleLarge.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final name in _presets) ...[
                  _LabelChip(
                    label: name,
                    selected: preset == name,
                    onTap: () => setState(() => _label.text = name),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _Field(controller: _label, label: 'Label', hint: 'Home, Office, Parents…'),
            _Field(controller: _name, label: 'Full name', textCapitalization: TextCapitalization.words),
            _Field(controller: _phone, label: 'Phone', keyboard: TextInputType.phone),
            _Field(controller: _line1, label: 'Street address'),
            _Field(controller: _line2, label: 'Area or landmark', hint: 'Optional'),
            _Field(controller: _city, label: 'City'),
            _Field(controller: _district, label: 'District', hint: 'Same as city if you leave this blank'),
            _Field(controller: _postal, label: 'Postal code', hint: 'Optional', keyboard: TextInputType.number),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _defaultAddress,
              activeThumbColor: AppPallete.primary,
              title: const Text('Use as default delivery address'),
              onChanged: (value) => setState(() => _defaultAddress = value),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D2E), fontSize: 13)),
              ),
            _AddButton(onTap: _saving ? () {} : _save),
            if (_saving) const LinearProgressIndicator(minHeight: 2, color: AppPallete.accent),
          ],
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppPallete.primarySoft : const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppPallete.primary : const Color(0xFFE1E7F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppPallete.primary : AppPallete.ink,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboard,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3E8F1))),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3E8F1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppPallete.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}
