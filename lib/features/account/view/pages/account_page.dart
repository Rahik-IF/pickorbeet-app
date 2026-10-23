import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/models/user_model.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/router/tab_reselect.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';
import 'package:pickorbeet/core/widgets/section.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/repositories/order_summary_repository.dart';
import 'package:pickorbeet/features/auth/view/widgets/google_sign_in_button.dart';
import 'package:pickorbeet/features/home/view/widgets/category_section_card.dart';

/// Account dashboard: profile, order counts, shortcuts, and sign-out.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  static const tabIndex = 3;
  static const margin = 12.2;

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(orderSummaryProvider);
    await ref.read(sessionNotifierProvider.notifier).refreshProfile();
    if (ref.read(sessionNotifierProvider) == SessionStatus.signedIn) {
      try {
        await ref.read(orderSummaryProvider.future);
      } on Object {
        // The stats card shows the failure; the rest of the page stays.
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in any time. Your cart stays on this device until then.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay signed in')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(sessionNotifierProvider.notifier).signOut();
    if (!mounted) return;
    showToast(context, 'Signed out');
  }

  @override
  Widget build(BuildContext context) {
    listenForTabReselect(ref, context, AccountPage.tabIndex, _scroll);
    final signedIn = ref.watch(sessionNotifierProvider) == SessionStatus.signedIn;
    final user = ref.watch(currentUserNotifierProvider);

    return Scaffold(
      backgroundColor: AppPallete.background,
      body: Column(
        children: [
          const TabHeader(),
          Expanded(
            child: signedIn
                ? RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppPallete.primary,
                    backgroundColor: AppPallete.surface,
                    child: ListView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(AccountPage.margin, 14, AccountPage.margin, 24),
                      children: [
                        _ProfileCard(user: user).entrance(),
                        const SizedBox(height: 12),
                        const _OrdersCard().entrance(index: 1),
                        const SizedBox(height: 12),
                        const _ShortcutGrid().entrance(index: 2),
                        const SizedBox(height: 12),
                        const _MembershipBanner().entrance(index: 3),
                        const SizedBox(height: 12),
                        _AccountList(onSignOut: _signOut).entrance(index: 4),
                      ],
                    ),
                  )
                : const _SignedOutAccount(),
          ),
        ],
      ),
    );
  }
}

/// Shown only while nobody is signed in. Orders, addresses, and settings stay hidden.
class _SignedOutAccount extends StatelessWidget {
  const _SignedOutAccount();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        _WelcomeBackdrop(),
        Padding(
          padding: EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: Column(
            children: [
              Spacer(flex: 2),
              _WelcomeAvatar(),
              SizedBox(height: 18),
              Text(
                'Welcome back',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF07133F), letterSpacing: -0.4),
              ),
              SizedBox(height: 8),
              Text(
                'Sign in to enjoy a smarter shopping experience.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.35, color: Color(0xFF6A7594)),
              ),
              SizedBox(height: 22),
              _PerkRow(),
              SizedBox(height: 26),
              GoogleSignInButton(),
              SizedBox(height: 16),
              _EmailDivider(),
              SizedBox(height: 16),
              _WelcomeAction(
                label: 'Sign in with email',
                filled: true,
                icon: PhosphorIconsBold.envelopeSimple,
                trailing: PhosphorIconsBold.arrowRight,
                onTap: _openEmailSignIn,
              ),
              SizedBox(height: 12),
              _WelcomeAction(
                label: 'Create account',
                icon: PhosphorIconsBold.userPlus,
                onTap: _openRegister,
              ),
              Spacer(),
              _TrustLine(),
              SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

void _openEmailSignIn(BuildContext context) => context.push(Routes.loginFrom(Routes.account));

void _openRegister(BuildContext context) => context.push(Routes.register);

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF7F9FE),
      child: Stack(
        children: [
          Positioned(left: -80, top: 30, child: _Blob(color: Color(0x334C7DFF), size: 220)),
          Positioned(right: -70, top: -10, child: _Blob(color: Color(0x33FF8A3D), size: 200)),
          Positioned(right: 24, top: 150, child: _Blob(color: Color(0x22FFB067), size: 90)),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _WelcomeAvatar extends StatelessWidget {
  const _WelcomeAvatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7EB0FF), Color(0xFF2F6BFF)],
              ),
              boxShadow: [BoxShadow(color: Color(0x332F6BFF), blurRadius: 18, offset: Offset(0, 8))],
            ),
            alignment: Alignment.center,
            child: const Icon(PhosphorIconsFill.user, size: 46, color: Colors.white),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppPallete.accent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF7F9FE), width: 3),
              ),
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsFill.sparkle, size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _Perk(icon: PhosphorIconsBold.package, tint: Color(0xFFE8F0FF), color: Color(0xFF3B6FE8), label: 'Track orders')),
        _PerkDivider(),
        Expanded(child: _Perk(icon: PhosphorIconsBold.heart, tint: Color(0xFFFFF1E8), color: Color(0xFFFF7A2F), label: 'Save favourites')),
        _PerkDivider(),
        Expanded(child: _Perk(icon: PhosphorIconsBold.lightning, tint: Color(0xFFEAF3FF), color: Color(0xFF3B6FE8), label: 'Faster checkout')),
      ],
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.tint, required this.color, required this.label});

  final IconData icon;
  final Color tint;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: Color(0xFF5C6784), fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _PerkDivider extends StatelessWidget {
  const _PerkDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE3E8F2));
  }
}

class _EmailDivider extends StatelessWidget {
  const _EmailDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE3E8F2))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('OR CONTINUE WITH EMAIL', style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: Color(0xFF98A2BE), fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: Color(0xFFE3E8F2))),
      ],
    );
  }
}

class _WelcomeAction extends StatelessWidget {
  const _WelcomeAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final IconData? trailing;
  final bool filled;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : const Color(0xFF1237D6);
    return Pressable(
      pressedScale: 0.98,
      semanticLabel: label,
      onTap: () => onTap(context),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: filled ? AppPallete.accent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: const Color(0xFFD7E2FF)),
          boxShadow: filled
              ? const [BoxShadow(color: Color(0x55FE7818), blurRadius: 16, offset: Offset(0, 8))]
              : const [BoxShadow(color: Color(0x0A14289A), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: foreground),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: foreground),
              ),
            ),
            Icon(trailing ?? icon, size: 18, color: trailing == null ? Colors.transparent : foreground),
          ],
        ),
      ),
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(PhosphorIconsFill.shieldCheck, size: 14, color: Color(0xFF7C8AAB)),
        SizedBox(width: 6),
        Text('Your account, your shopping — all in one place.', style: TextStyle(fontSize: 12, color: Color(0xFF7C8AAB))),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final phone = Formatters.phone(user?.phone);
    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            const _Avatar(),
            const SizedBox(width: 12),
            Expanded(
              child: user == null
                  ? const _ProfileSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user!.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user!.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(phone, style: AppTypography.bodySmall.copyWith(fontSize: 11.5, color: AppPallete.inkSoft)),
                        ],
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            _PillButton(
              icon: PhosphorIconsBold.pencilSimple,
              label: 'Edit Profile',
              onTap: () => context.push(Routes.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(color: Color(0xFFE7EEFB), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(PhosphorIconsRegular.user, size: 28, color: Color(0xFF8AA0C8)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppPallete.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppPallete.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsFill.camera, size: 9, color: AppPallete.onDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 120, height: 14, decoration: _bar),
        const SizedBox(height: 6),
        Container(width: 150, height: 10, decoration: _bar),
      ],
    );
  }

  static final _bar = BoxDecoration(color: AppPallete.skeleton, borderRadius: BorderRadius.circular(4));
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6E2FB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppPallete.primaryText),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.label.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppPallete.primaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersCard extends ConsumerWidget {
  const _OrdersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(orderSummaryProvider);
    return HomeCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'My Orders',
              onViewAll: () => context.push(Routes.orders),
            ),
            const SizedBox(height: 8),
            summary.when(
              loading: () => const _StatRow.loading(),
              error: (error, _) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
                child: Text(
                  error is AppFailure ? error.message : 'Could not load your orders.',
                  style: AppTypography.bodySmall,
                ),
              ),
              data: (value) => _StatRow(summary: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.summary});

  const _StatRow.loading() : summary = null;

  final OrderSummary? summary;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, int?, TileTint, String)>[
      (PhosphorIconsFill.package, 'Pending', summary?.processingCount, DashboardPalette.statPending, 'processing'),
      (PhosphorIconsFill.truck, 'Delivered', summary?.delivered, DashboardPalette.statDelivered, 'delivered'),
      (PhosphorIconsBold.arrowUUpLeft, 'Cancelled', summary?.cancelled, DashboardPalette.statCancelled, 'cancelled'),
      (PhosphorIconsBold.arrowClockwise, 'Returned', summary?.returned, DashboardPalette.statReturned, 'refunded'),
    ];
    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Pressable(
              semanticLabel: item.$3 == null ? item.$2 : '${item.$2}, ${item.$3}',
              onTap: summary == null ? null : () => context.push(Routes.ordersFiltered(item.$5)),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: item.$4.background, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(item.$1, size: 18, color: item.$4.icon),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$3 == null ? '–' : '${item.$3}',
                    style: AppTypography.titleSmall.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 1),
                  Text(item.$2, style: AppTypography.bodySmall.copyWith(fontSize: 10)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid();

  static const _tiles = <_Shortcut>[
    _Shortcut(PhosphorIconsFill.package, 'My Orders', 'Track, return or buy again', DashboardPalette.orders, Routes.orders),
    _Shortcut(PhosphorIconsFill.heart, 'My Wishlist', 'View your saved items', DashboardPalette.wishlist, Routes.wishlist, tab: true),
    _Shortcut(PhosphorIconsFill.mapPin, 'Delivery Addresses', 'Manage your addresses', DashboardPalette.addresses, Routes.addresses),
    _Shortcut(PhosphorIconsFill.creditCard, 'Payment Methods', 'Cards, bKash & more', DashboardPalette.payment, Routes.paymentMethods),
    _Shortcut(PhosphorIconsFill.ticket, 'My Vouchers', 'View available offers', DashboardPalette.vouchers, Routes.vouchers),
    _Shortcut(PhosphorIconsFill.bell, 'Notifications', 'Offers, order updates', DashboardPalette.notifications, Routes.notifications),
    _Shortcut(PhosphorIconsFill.headset, 'Help & Support', 'Get help or contact us', DashboardPalette.help, Routes.help),
    _Shortcut(PhosphorIconsFill.gear, 'Settings', 'App preferences', DashboardPalette.settings, Routes.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ShortcutTile(tile: _tiles[i])),
              const SizedBox(width: 10),
              Expanded(child: _ShortcutTile(tile: _tiles[i + 1])),
            ],
          ),
        ],
      ],
    );
  }
}

class _Shortcut {
  const _Shortcut(this.icon, this.title, this.subtitle, this.tint, this.location, {this.tab = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final TileTint tint;
  final String location;
  final bool tab;
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.tile});

  final _Shortcut tile;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.98,
      semanticLabel: '${tile.title}. ${tile.subtitle}',
      onTap: () => tile.tab ? context.go(tile.location) : context.push(tile.location),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPallete.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: HomeCard.shadow,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: tile.tint.background, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(tile.icon, size: 18, color: tile.tint.icon),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tile.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.titleSmall.copyWith(fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text(
                      tile.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(fontSize: 9.5, height: 1.2),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsBold.caretRight, size: 12, color: tile.tint.icon.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipBanner extends StatelessWidget {
  const _MembershipBanner();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.985,
      semanticLabel: 'Become a PickOrbeet member. Learn more',
      onTap: () => context.push(Routes.membership),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF071A5C), Color(0xFF12307A), Color(0xFF2A1468)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Color(0xFF2C3F86), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(PhosphorIconsFill.crown, size: 18, color: Color(0xFFFFB020)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Become a PickOrbeet Member',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(color: AppPallete.onDark, fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Get exclusive offers, early access and more',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(color: const Color(0xFFD5DFF5), fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppPallete.accent, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'Learn More',
                style: AppTypography.label.copyWith(color: AppPallete.onDark, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final rows = <_AccountRow>[
      const _AccountRow(
        icon: PhosphorIconsRegular.user,
        tint: Color(0xFFEEF3FF),
        iconColor: AppPallete.primary,
        title: 'Account Information',
        subtitle: 'Name, email, phone number',
        location: Routes.profile,
      ),
      const _AccountRow(
        icon: PhosphorIconsRegular.shieldCheck,
        tint: Color(0xFFEEF3FF),
        iconColor: AppPallete.primary,
        title: 'Privacy & Security',
        subtitle: 'Password, data and security settings',
        location: Routes.privacy,
      ),
      _AccountRow(
        icon: PhosphorIconsRegular.signOut,
        tint: const Color(0xFFFFF0F2),
        iconColor: AppPallete.danger,
        title: 'Logout',
        subtitle: 'Sign out from your account',
        titleColor: AppPallete.danger,
        onTap: onSignOut,
      ),
    ];
    return HomeCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56, color: AppPallete.divider),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.location,
    this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? location;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: title,
      onTap: onTap ?? () => context.push(location ?? Routes.login),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleSmall.copyWith(fontSize: 13, color: titleColor ?? AppPallete.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                ],
              ),
            ),
            Icon(PhosphorIconsBold.caretRight, size: 14, color: titleColor ?? AppPallete.textHint),
          ],
        ),
      ),
    );
  }
}
