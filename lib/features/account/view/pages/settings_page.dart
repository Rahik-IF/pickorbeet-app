import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/models/user_model.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/current_user_notifier.dart';
import 'package:pickorbeet/core/providers/preferences_notifier.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/utils/formatters.dart';
import 'package:pickorbeet/core/widgets/brand_lockup.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/header_background.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/profile_photo.dart';
import 'package:url_launcher/url_launcher.dart';

/// Account settings, measured from the settings design at 576×1024 and scaled to the 411 dp reference.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  /// Label printed on the About row in the design.
  static const versionLabel = 'v1.2.0';

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _photoBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sessionNotifierProvider.notifier).refreshProfile();
    });
  }

  Future<void> _changePhoto() async {
    final user = ref.read(currentUserNotifierProvider);
    if (user == null || _photoBusy) return;
    final choice = await chooseProfilePhoto(context, canRemove: profileHasPhoto(user));
    if (!mounted || choice == null) return;
    if (choice is ProfilePhotoInvalid) {
      showToast(context, choice.message, kind: ToastKind.error);
      return;
    }
    setState(() => _photoBusy = true);
    final error = await saveProfilePhoto(ref, choice);
    if (!mounted) return;
    setState(() => _photoBusy = false);
    if (error != null) {
      showToast(context, error, kind: ToastKind.error);
      return;
    }
    showToast(
      context,
      choice is ProfilePhotoRemove ? 'Profile photo removed' : 'Profile photo updated',
      kind: ToastKind.success,
    );
  }

  Future<void> _chooseLanguage(AppPreferences prefs) async {
    final code = await _openOptions(
      title: 'Language',
      message: 'The store is shown in this language.',
      options: const [_Option('en', 'English (US)')],
      selected: prefs.languageCode,
    );
    if (code == null || code == prefs.languageCode) return;
    await ref.read(preferencesProvider.notifier).setLanguage(code);
  }

  Future<void> _chooseCurrency(AppPreferences prefs) async {
    final code = await _openOptions(
      title: 'Currency',
      message: 'Prices are shown in Bangladeshi Taka.',
      options: const [_Option('BDT', 'Bangladeshi Taka (৳)')],
      selected: prefs.currencyCode,
    );
    if (code == null || code == prefs.currencyCode) return;
    await ref.read(preferencesProvider.notifier).setCurrency(code);
  }

  Future<String?> _openOptions({
    required String title,
    required String message,
    required List<_Option> options,
    required String selected,
  }) {
    final tone = _Tone.of(ref.read(preferencesProvider).darkMode);
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => _OptionSheet(
        tone: tone,
        title: title,
        message: message,
        options: options,
        selected: selected,
      ),
    );
  }

  Future<void> _about() async {
    final tone = _Tone.of(ref.read(preferencesProvider).darkMode);
    final open = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => _AboutSheet(tone: tone),
    );
    if (open == true) await _openSite('/about');
  }

  Future<void> _terms() => _openSite('/terms');

  Future<void> _openSite(String path) async {
    final opened = await launchUrl(Uri.parse('https://pickorbeet.com$path'), mode: LaunchMode.externalApplication);
    if (!opened && mounted) showToast(context, 'Could not open that page', kind: ToastKind.error);
  }

  Future<void> _logOut() async {
    final tone = _Tone.of(ref.read(preferencesProvider).darkMode);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => _LogoutSheet(tone: tone),
    );
    if (confirmed != true || !mounted) return;
    showToast(context, 'Signed out');
    context.go(Routes.home);
    await ref.read(sessionNotifierProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final tone = _Tone.of(prefs.darkMode);
    final user = ref.watch(currentUserNotifierProvider);
    final motion = Motion.of(context, Motion.medium);

    return AnimatedContainer(
      duration: motion,
      curve: Motion.emphasized,
      color: tone.page,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const _SettingsHeader(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 22),
                children: [
                  _ProfileBlock(tone: tone, user: user, photoBusy: _photoBusy, onPhoto: _changePhoto).entrance(rise: 10),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    tone: tone,
                    title: 'Account Settings',
                    hint: 'Manage your account and personal information',
                  ).entrance(index: 1, rise: 8),
                  const SizedBox(height: 8),
                  _Card(
                    tone: tone,
                    children: [
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.user,
                        tile: _Tiles.personal,
                        title: 'Personal Information',
                        subtitle: 'Name, phone, address, and photo',
                        onTap: () => context.push(Routes.profile),
                      ),
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.shieldCheck,
                        tile: _Tiles.security,
                        title: 'Security & Password',
                        subtitle: 'Change password, 2FA, login activity',
                        onTap: () => context.push(Routes.changePassword),
                      ),
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.mapPin,
                        tile: _Tiles.addresses,
                        title: 'Addresses',
                        subtitle: 'Manage your delivery addresses',
                        onTap: () => context.push(Routes.addresses),
                      ),
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.creditCard,
                        tile: _Tiles.payment,
                        title: 'Payment Methods',
                        subtitle: 'Cards, bKash, Nagad and more',
                        onTap: () => context.push(Routes.paymentMethods),
                      ),
                    ],
                  ).entrance(index: 2),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    tone: tone,
                    title: 'App Preferences',
                    hint: 'Customize your shopping experience',
                  ).entrance(index: 3, rise: 8),
                  const SizedBox(height: 8),
                  _Card(
                    tone: tone,
                    children: [
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.bell,
                        tile: _Tiles.notifications,
                        title: 'Notifications',
                        subtitle: 'Order updates, offers, and more',
                        trailing: _SettingsSwitch(value: prefs.notifications, dark: tone.dark),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(preferencesProvider.notifier).setNotifications(!prefs.notifications);
                        },
                      ),
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.moon,
                        tile: _Tiles.darkMode,
                        title: 'Dark Mode',
                        subtitle: 'Switch between light and dark theme',
                        trailing: _SettingsSwitch(value: prefs.darkMode, dark: tone.dark),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(preferencesProvider.notifier).setDarkMode(!prefs.darkMode);
                        },
                      ),
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.globe,
                        tile: _Tiles.language,
                        title: 'Language',
                        subtitle: prefs.languageLabel,
                        onTap: () => _chooseLanguage(prefs),
                      ),
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.money,
                        tile: _Tiles.currency,
                        title: 'Currency',
                        subtitle: prefs.currencyLabel,
                        onTap: () => _chooseCurrency(prefs),
                      ),
                    ],
                  ).entrance(index: 4),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    tone: tone,
                    title: 'Support & About',
                    hint: 'Get help or learn more',
                  ).entrance(index: 5, rise: 8),
                  const SizedBox(height: 8),
                  _Card(
                    tone: tone,
                    children: [
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.headset,
                        tile: _Tiles.help,
                        title: 'Help & Support',
                        subtitle: 'FAQs, contact us, live chat',
                        onTap: () => context.push(Routes.help),
                      ),
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.fileText,
                        tile: _Tiles.terms,
                        title: 'Terms & Conditions',
                        subtitle: 'Read our terms and policies',
                        onTap: _terms,
                      ),
                      _Line(
                        tone: tone,
                        icon: PhosphorIconsFill.info,
                        tile: _Tiles.about,
                        title: 'About PickOrbeet',
                        subtitle: 'App version, legal info',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(SettingsPage.versionLabel, style: _subtitle(tone).copyWith(fontSize: 12.5)),
                            const SizedBox(width: 2),
                            Icon(PhosphorIconsBold.caretRight, size: 14, color: tone.chevron),
                          ],
                        ),
                        onTap: _about,
                      ),
                    ],
                  ).entrance(index: 6),
                  const SizedBox(height: 16),
                  _LogoutButton(tone: tone, onTap: _logOut).entrance(index: 7, rise: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  static const contentHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: HeaderBackground(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: SizedBox(
          height: top + contentHeight,
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: Row(
              children: [
                HeaderBackButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.account)),
                const BrandLockup(markSize: Size(28, 30), wordmarkSize: 18.2, gap: 5.5, markLift: 0.4),
                const Spacer(),
                const HeaderBellButton(),
                const SizedBox(width: 1),
                const HeaderDivider(),
                const SizedBox(width: 1),
                const HeaderCartButton(),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.tone, required this.user, required this.photoBusy, required this.onPhoto});

  final _Tone tone;
  final UserModel? user;
  final bool photoBusy;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final phone = _phone(user?.phone);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(right: -24, top: -8, child: _Blob(size: 148, color: tone.blob)),
        Positioned(right: 28, top: 34, child: _Blob(size: 72, color: tone.blobSoft)),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 0, 2),
          child: Row(
            children: [
              _Avatar(
                tone: tone,
                initials: user?.initials ?? '',
                imageUrl: user?.avatar,
                busy: photoBusy,
                onTap: user == null || photoBusy ? null : onPhoto,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: user == null
                    ? _ProfileSkeleton(tone: tone)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user!.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.15,
                              color: tone.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user!.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _meta(tone),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            phone.isEmpty ? 'Add your phone number' : phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _meta(tone),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              _EditButton(tone: tone, onTap: () => context.push(Routes.profile)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.tone,
    required this.initials,
    required this.imageUrl,
    required this.busy,
    required this.onTap,
  });

  final _Tone tone;
  final String initials;
  final String? imageUrl;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      size: 62,
      imageUrl: imageUrl,
      initials: initials,
      busy: busy,
      onTap: onTap,
      background: Colors.transparent,
      badgeColor: const Color(0xFF2F6BFF),
      badgeBorder: tone.page,
      placeholder: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8EB4FF), Color(0xFF2F6BFF)],
          ),
          boxShadow: [BoxShadow(color: const Color(0xFF14289A).withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            initials,
            style: AppTypography.titleMedium.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.tone, required this.onTap});

  final _Tone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Edit Profile',
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.emphasized,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: tone.editFill,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: tone.edit, width: 1.15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsBold.pencilSimple, size: 13, color: tone.edit),
            const SizedBox(width: 5),
            Text(
              'Edit Profile',
              style: AppTypography.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: tone.edit),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton({required this.tone});

  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final bar = BoxDecoration(color: tone.divider, borderRadius: BorderRadius.circular(4));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 138, height: 14, decoration: bar),
        const SizedBox(height: 8),
        Container(width: 168, height: 10, decoration: bar),
        const SizedBox(height: 6),
        Container(width: 120, height: 10, decoration: bar),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.tone, required this.title, required this.hint});

  final _Tone tone;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
            color: tone.ink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              hint,
              maxLines: 1,
              style: AppTypography.bodySmall.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: tone.hint),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.tone, required this.children});

  final _Tone tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.emphasized,
      decoration: BoxDecoration(
        color: tone.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (tone.dark ? Colors.black : const Color(0xFF14289A)).withValues(alpha: tone.dark ? 0.28 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: tone.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.tone,
    required this.icon,
    required this.tile,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final _Tone tone;
  final IconData icon;
  final _Tile tile;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.985,
      semanticLabel: title,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.of(context, Motion.medium),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.dark ? tile.icon.withValues(alpha: 0.16) : tile.background,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: tile.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.15, color: tone.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _subtitle(tone),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? Icon(PhosphorIconsBold.caretRight, size: 14, color: tone.chevron),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({required this.value, required this.dark});

  final bool value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, const Duration(milliseconds: 240));
    return Semantics(
      toggled: value,
      child: AnimatedContainer(
        duration: duration,
        curve: Motion.emphasized,
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFFF7E14) : (dark ? const Color(0xFF3A445C) : const Color(0xFFE3E6EE)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: duration,
          curve: Motion.emphasizedDecelerate,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 3, offset: const Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.tone, required this.onTap});

  final _Tone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Log Out',
      pressedScale: 0.98,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        curve: Motion.emphasized,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.logoutFill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsBold.signOut, size: 18, color: tone.logoutInk),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: AppTypography.titleSmall.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: tone.logoutInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size * 0.72,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.72), color.withValues(alpha: 0)],
            stops: const [0.05, 1],
          ),
        ),
      ),
    );
  }
}

class _Option {
  const _Option(this.code, this.label);

  final String code;
  final String label;
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({
    required this.tone,
    required this.title,
    required this.message,
    required this.options,
    required this.selected,
  });

  final _Tone tone;
  final String title;
  final String message;
  final List<_Option> options;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 16, color: tone.ink)),
          const SizedBox(height: 4),
          Text(message, style: _subtitle(tone).copyWith(fontSize: 13)),
          const SizedBox(height: 8),
          for (final option in options)
            Pressable(
              semanticLabel: option.label,
              onTap: () => Navigator.pop(context, option.code),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(option.label, style: AppTypography.titleSmall.copyWith(fontSize: 14.5, color: tone.ink)),
                    ),
                    AnimatedScale(
                      scale: option.code == selected ? 1 : 0.6,
                      duration: Motion.of(context, Motion.short),
                      curve: Motion.emphasizedDecelerate,
                      child: AnimatedOpacity(
                        opacity: option.code == selected ? 1 : 0,
                        duration: Motion.of(context, Motion.short),
                        child: const Icon(PhosphorIconsBold.check, size: 18, color: Color(0xFF3B6FE8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.tone});

  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('About PickOrbeet', style: AppTypography.titleMedium.copyWith(fontSize: 16, color: tone.ink)),
          const SizedBox(height: 6),
          Text('Version ${SettingsPage.versionLabel}', style: _subtitle(tone).copyWith(fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            'Shop electronics, fashion, home, and everyday essentials, with delivery across Bangladesh.',
            style: AppTypography.bodyLarge.copyWith(fontSize: 13.5, height: 1.4, color: tone.ink),
          ),
          const SizedBox(height: 16),
          Pressable(
            semanticLabel: 'Read more about PickOrbeet',
            pressedScale: 0.98,
            onTap: () => Navigator.pop(context, true),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFF2F6BFF), borderRadius: BorderRadius.circular(14)),
              child: Text('Learn more', style: AppTypography.titleSmall.copyWith(color: Colors.white, fontSize: 14.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet({required this.tone});

  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Log out?', style: AppTypography.titleMedium.copyWith(fontSize: 16, color: tone.ink)),
          const SizedBox(height: 6),
          Text(
            'You can sign back in any time. Your cart stays on this device until then.',
            style: _subtitle(tone).copyWith(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  semanticLabel: 'Stay signed in',
                  pressedScale: 0.98,
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tone.divider),
                    ),
                    child: Text('Stay', style: AppTypography.titleSmall.copyWith(fontSize: 14.5, color: tone.ink)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  semanticLabel: 'Log out',
                  pressedScale: 0.98,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, true);
                  },
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tone.logoutInk, borderRadius: BorderRadius.circular(14)),
                    child: Text('Log Out', style: AppTypography.titleSmall.copyWith(fontSize: 14.5, color: Colors.white)),
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

class _Tile {
  const _Tile(this.background, this.icon);

  final Color background;
  final Color icon;
}

abstract final class _Tiles {
  static const personal = _Tile(Color(0xFFEAF3FF), Color(0xFF3B82F6));
  static const security = _Tile(Color(0xFFF0EDFF), Color(0xFF7C6AE8));
  static const addresses = _Tile(Color(0xFFFFF1E4), Color(0xFFFF8A1F));
  static const payment = _Tile(Color(0xFFE5F8EE), Color(0xFF22A35A));
  static const notifications = _Tile(Color(0xFFFFF1E6), Color(0xFFFF8A1A));
  static const darkMode = _Tile(Color(0xFFF3EEFF), Color(0xFF8B6CF6));
  static const language = _Tile(Color(0xFFEAF2FF), Color(0xFF3B78F0));
  static const currency = _Tile(Color(0xFFFFEEF1), Color(0xFFF06070));
  static const help = _Tile(Color(0xFFEAF1FF), Color(0xFF3B78E8));
  static const terms = _Tile(Color(0xFFF3EEFF), Color(0xFF7B5CFA));
  static const about = _Tile(Color(0xFFFFF1E6), Color(0xFFFF8A1A));
}

class _Tone {
  const _Tone({
    required this.dark,
    required this.page,
    required this.card,
    required this.ink,
    required this.hint,
    required this.divider,
    required this.chevron,
    required this.edit,
    required this.editFill,
    required this.logoutFill,
    required this.logoutInk,
    required this.blob,
    required this.blobSoft,
    required this.meta,
  });

  factory _Tone.of(bool dark) => dark ? _dark : _light;

  final bool dark;
  final Color page;
  final Color card;
  final Color ink;
  final Color hint;
  final Color divider;
  final Color chevron;
  final Color edit;
  final Color editFill;
  final Color logoutFill;
  final Color logoutInk;
  final Color blob;
  final Color blobSoft;
  final Color meta;

  static const _light = _Tone(
    dark: false,
    page: Color(0xFFF4F7FE),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF0C1440),
    hint: Color(0xFF9AA3B8),
    divider: Color(0xFFEEF1F6),
    chevron: Color(0xFFC5CDD8),
    edit: Color(0xFF3B6FE8),
    editFill: Color(0xFFFFFFFF),
    logoutFill: Color(0xFFFFF4F4),
    logoutInk: Color(0xFFE23B35),
    blob: Color(0xFFD9E7FB),
    blobSoft: Color(0xFFE7F1FC),
    meta: Color(0xFF8B93A6),
  );

  static const _dark = _Tone(
    dark: true,
    page: Color(0xFF0E1628),
    card: Color(0xFF172238),
    ink: Color(0xFFF4F7FF),
    hint: Color(0xFF8E99B3),
    divider: Color(0xFF2C3850),
    chevron: Color(0xFF8B97B0),
    edit: Color(0xFF8EB0FF),
    editFill: Color(0xFF1C2B48),
    logoutFill: Color(0xFF3A1A22),
    logoutInk: Color(0xFFFF8A86),
    blob: Color(0xFF1A2A4A),
    blobSoft: Color(0xFF15243F),
    meta: Color(0xFFA3AEC6),
  );
}

TextStyle _subtitle(_Tone tone) => AppTypography.bodySmall.copyWith(fontSize: 12, height: 1.25, color: tone.meta);

TextStyle _meta(_Tone tone) => AppTypography.bodySmall.copyWith(fontSize: 12, fontWeight: FontWeight.w500, height: 1.25, color: tone.meta);

/// `+880 1712 345678` becomes `+880 1712-345678`, matching the settings design.
String _phone(String? raw) {
  final formatted = Formatters.phone(raw);
  final match = RegExp(r'^\+880 (\d{4}) (\d+)$').firstMatch(formatted);
  if (match == null) return formatted;
  return '+880 ${match.group(1)}-${match.group(2)}';
}
