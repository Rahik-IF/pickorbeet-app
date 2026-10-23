import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/entrance.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/providers/session_notifier.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_spacing.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_header.dart';
import 'package:pickorbeet/core/widgets/bottom_nav.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/features/notifications/notification_inbox.dart';

const _canvas = Color(0xFFEEF3FC);
const _ink = Color(0xFF121A3A);
const _muted = Color(0xFF8D95A8);
const _body = Color(0xFF6D768C);
const _time = Color(0xFFA0A8B8);
const _blue = Color(0xFF3B78F2);
const _orange = Color(0xFFFF7E16);

const _tabs = <String>[
  Routes.home,
  Routes.categories,
  Routes.wishlist,
  Routes.account,
  Routes.cart,
];

/// The notifications inbox from the mobile design, including its settings sheet.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(notificationInboxProvider);
    return Scaffold(
      backgroundColor: _canvas,
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3,
        cartCount: ref.watch(cartCountProvider),
        onSelect: (index) => context.go(_tabs[index]),
      ),
      body: Column(
        children: [
          const DetailHeader(),
          Expanded(child: _Inbox(inbox: inbox)),
        ],
      ),
    );
  }
}

class _Inbox extends ConsumerStatefulWidget {
  const _Inbox({required this.inbox});

  final InboxState inbox;

  @override
  ConsumerState<_Inbox> createState() => _InboxState();
}

class _InboxState extends ConsumerState<_Inbox> {
  InboxFilter _filter = InboxFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(sessionNotifierProvider) != SessionStatus.signedIn) return;
      unawaited(ref.read(notificationInboxProvider.notifier).reload());
    });
  }

  List<InboxItem> get _visible => [
        for (final item in widget.inbox.items)
          if (widget.inbox.channelOn(item.channel) && (_filter.channel == null || item.channel == _filter.channel)) item,
      ];

  void _open(InboxItem item) {
    unawaited(ref.read(notificationInboxProvider.notifier).markRead([item.id]));
    final orderId = item.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      context.push(Routes.order(orderId));
      return;
    }
    switch (item.link) {
      case NotificationLink.orders:
        context.push(Routes.orders);
      case NotificationLink.products:
        context.push(Routes.products);
      case NotificationLink.wishlist:
        context.go(Routes.wishlist);
      case NotificationLink.account:
        context.go(Routes.account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      for (final group in InboxGroup.values)
        (group, [for (final item in _visible.where((item) => item.group == group)) item]),
    ].where((section) => section.$2.isNotEmpty).toList();
    var index = 0;

    final loading = widget.inbox.loading && widget.inbox.items.isEmpty;
    final failed = widget.inbox.error != null && sections.isEmpty && !loading;

    return RefreshIndicator(
      color: _blue,
      onRefresh: () => ref.read(notificationInboxProvider.notifier).reload(),
      child: ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      children: [
        const _Heading(),
        const SizedBox(height: 16),
        _Filters(
          selected: _filter,
          onSelect: (filter) {
            if (filter == _filter) return;
            HapticFeedback.selectionClick();
            setState(() => _filter = filter);
          },
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator(color: _blue)),
          )
        else if (ref.watch(sessionNotifierProvider) != SessionStatus.signedIn)
          _Empty(
            title: 'Sign in to see notifications',
            body: 'Order updates, offers and account messages will show up here.',
            action: 'Sign in',
            onAction: () => context.push(Routes.login),
          ).entrance()
        else if (failed)
          _LoadError(
            message: widget.inbox.error!,
            onRetry: () => unawaited(ref.read(notificationInboxProvider.notifier).reload()),
          )
        else if (sections.isEmpty)
          _Empty(title: _emptyTitle(_filter), body: _emptyBody(_filter)).entrance()
        else
          for (final section in sections) ...[
            const SizedBox(height: 18),
            _SectionHead(
              label: section.$1.label,
              unread: [for (final item in section.$2) if (widget.inbox.isUnread(item)) item.id],
            ),
            const SizedBox(height: 10),
            for (final item in section.$2) ...[
              if (item != section.$2.first) const SizedBox(height: 10),
              _Card(
                item: item,
                unread: widget.inbox.isUnread(item),
                onOpen: () => _open(item),
              ).entrance(index: index++),
            ],
          ],
      ],
      ),
    );
  }
}

String _emptyTitle(InboxFilter filter) => switch (filter) {
      InboxFilter.system => 'No system notifications',
      InboxFilter.orders => 'No order updates',
      InboxFilter.offers => 'No offers right now',
      InboxFilter.account => 'No account messages',
      InboxFilter.all => 'You’re all caught up',
    };

String _emptyBody(InboxFilter filter) => switch (filter) {
      InboxFilter.system => 'Security alerts and app updates will land here.',
      InboxFilter.orders => 'Confirmation, delivery and payment messages will show up here.',
      InboxFilter.offers => 'Deals, price drops and new arrivals will show up here.',
      InboxFilter.account => 'Notes about your PickOrbeet account will show up here.',
      InboxFilter.all => 'New orders, offers and account updates will show up here.',
    };

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.4, color: _muted)),
          const SizedBox(height: 12),
          Pressable(
            semanticLabel: 'Try again',
            onTap: onRetry,
            child: const Text('Try again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _blue)),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.45, height: 1.12, color: _ink),
              ),
              SizedBox(height: 4),
              Text(
                'Stay updated with your orders, offers and more.',
                style: TextStyle(fontSize: 13, height: 1.3, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Pressable(
          semanticLabel: 'Notification settings',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (context) => const _SettingsSheet(),
          ),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppPallete.surface,
              borderRadius: AppRadii.pillBorder,
              border: Border.all(color: const Color(0xFFE4E9F2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsRegular.gear, size: 15, color: _ink),
                SizedBox(width: 6),
                Text('Notification Settings', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelect});

  final InboxFilter selected;
  final ValueChanged<InboxFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          for (final filter in InboxFilter.values) ...[
            if (filter != InboxFilter.all) const SizedBox(width: 8),
            _Chip(filter: filter, selected: filter == selected, onTap: () => onSelect(filter)),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.filter, required this.selected, required this.onTap});

  final InboxFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPallete.onDark : const Color(0xFF24304A);
    return Pressable(
      semanticLabel: filter.label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.emphasizedDecelerate,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? _orange : AppPallete.surface,
          borderRadius: AppRadii.pillBorder,
          border: Border.all(color: selected ? _orange : const Color(0xFFE4E9F2)),
          boxShadow: selected ? null : AppShadows.soft,
        ),
        child: Row(
          children: [
            Icon(_filterIcon(filter), size: 16, color: color),
            const SizedBox(width: 6),
            Text(filter.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SectionHead extends ConsumerWidget {
  const _SectionHead({required this.label, required this.unread});

  final String label;
  final List<String> unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.2)),
        const Spacer(),
        AnimatedOpacity(
          opacity: unread.isEmpty ? 0 : 1,
          duration: Motion.of(context, Motion.short),
          child: IgnorePointer(
            ignoring: unread.isEmpty,
            child: Pressable(
              semanticLabel: 'Mark $label as read',
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(notificationInboxProvider.notifier).markRead(unread);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Mark all as read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _blue)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.unread, required this.onOpen});

  final InboxItem item;
  final bool unread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tint = _tint(item.icon);
    return Pressable(
      semanticLabel: unread ? '${item.title}, unread' : item.title,
      onTap: onOpen,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPallete.surface,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: AppShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 28, 12),
          child: Stack(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tint.background, borderRadius: const BorderRadius.all(Radius.circular(12))),
                    child: Icon(tint.icon, size: 22, color: tint.foreground),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _Copy(item: item)),
                  if (item.thumb != null) ...[
                    const SizedBox(width: 8),
                    _Thumb(kind: item.thumb!),
                  ],
                ],
              ),
              const Positioned(
                right: -16,
                top: 0,
                bottom: 0,
                child: Icon(PhosphorIconsRegular.caretRight, size: 16, color: Color(0xFFC5CDD8)),
              ),
              Positioned(
                top: 0,
                right: -14,
                child: AnimatedScale(
                  scale: unread ? 1 : 0,
                  duration: Motion.of(context, Motion.short),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: unread ? 1 : 0,
                    duration: Motion.of(context, Motion.short),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: _blue, shape: BoxShape.circle),
                      child: SizedBox.square(dimension: 8),
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

class _Copy extends StatelessWidget {
  const _Copy({required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final highlight = item.highlight;
    final bodyStyle = AppTypography.bodyLarge.copyWith(fontSize: 12.5, height: 1.35, color: _body);
    final parts = highlight == null ? null : item.body.split(highlight);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: AppTypography.titleSmall.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.2),
        ),
        const SizedBox(height: 2),
        if (parts == null || parts.length != 2)
          Text(item.body, style: bodyStyle)
        else
          Text.rich(
            TextSpan(
              style: bodyStyle,
              children: [
                TextSpan(text: parts[0]),
                TextSpan(text: highlight, style: bodyStyle.copyWith(color: _orange, fontWeight: FontWeight.w700)),
                TextSpan(text: parts[1]),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(item.time, style: AppTypography.bodySmall.copyWith(fontSize: 11.5, color: _time)),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.kind});

  final InboxThumb kind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.circular(10)), gradient: _gradient(kind)),
        child: switch (kind) {
          InboxThumb.save => const _SaveArt(),
          InboxThumb.price => const _PriceArt(),
          InboxThumb.arrivals => const _ArrivalsArt(),
        },
      ),
    );
  }

  Gradient _gradient(InboxThumb kind) => switch (kind) {
        InboxThumb.save => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8D34A), Color(0xFFE8A31C)],
          ),
        InboxThumb.price => const LinearGradient(colors: [Color(0xFFF3F4F7), Color(0xFFF3F4F7)]),
        InboxThumb.arrivals => const LinearGradient(
            colors: [Color(0xFFFFE3B5), Color(0xFFFFF6E4), Color(0xFFD5E5FF)],
            stops: [0, 0.46, 1],
          ),
      };
}

class _SaveArt extends StatelessWidget {
  const _SaveArt();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 7),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SAVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: _ink)),
            Text('৳200', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.05, color: _ink)),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 4, 4),
            child: Image.asset('assets/notifications/neckband.png', fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }
}

class _PriceArt extends StatelessWidget {
  const _PriceArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          child: Image.asset('assets/notifications/neckband.png', fit: BoxFit.contain),
        ),
        const Positioned(
          right: 4,
          bottom: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFEF233C), shape: BoxShape.circle),
            child: SizedBox(
              width: 16,
              height: 16,
              child: Icon(PhosphorIconsBold.arrowDown, size: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrivalsArt extends StatelessWidget {
  const _ArrivalsArt();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 7),
        const Text('NEW\nARRIVALS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, height: 1.05, color: _ink)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 4, 4),
            child: Image.asset('assets/notifications/neckband.png', fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body, this.action, this.onAction});

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: AppPallete.surface, shape: BoxShape.circle, boxShadow: AppShadows.soft),
            child: const SizedBox(
              width: 72,
              height: 72,
              child: Icon(PhosphorIconsRegular.bell, size: 30, color: _blue),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, height: 1.4, color: _muted)),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 14),
            Pressable(
              semanticLabel: action!,
              onTap: onAction!,
              child: Text(action!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _blue)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(notificationInboxProvider).channels;
    final rows = <(InboxChannel, String, String, InboxIcon)>[
      (InboxChannel.orders, 'Order updates', 'Confirmation, delivery and payment', InboxIcon.package),
      (InboxChannel.offers, 'Offers & price drops', 'Deals, new arrivals and wishlist alerts', InboxIcon.tag),
      (InboxChannel.account, 'Account activity', 'Welcome notes and account messages', InboxIcon.user),
      (InboxChannel.system, 'System alerts', 'Security and app updates', InboxIcon.gear),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 18 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notification Settings', style: AppTypography.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Choose which updates PickOrbeet keeps in this inbox.',
            style: AppTypography.bodyLarge.copyWith(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final row in rows) _SettingRow(row: row, on: channels[row.$1] ?? true),
        ],
      ),
    );
  }
}

class _SettingRow extends ConsumerWidget {
  const _SettingRow({required this.row, required this.on});

  final (InboxChannel, String, String, InboxIcon) row;
  final bool on;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = _tint(row.$4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: tint.background, borderRadius: const BorderRadius.all(Radius.circular(12))),
            alignment: Alignment.center,
            child: Icon(tint.icon, size: 22, color: tint.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.$2, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _ink)),
                const SizedBox(height: 2),
                Text(row.$3, style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          Switch.adaptive(
            value: on,
            activeTrackColor: _blue,
            onChanged: (_) => ref.read(notificationInboxProvider.notifier).toggle(row.$1),
          ),
        ],
      ),
    );
  }
}

IconData _filterIcon(InboxFilter filter) => switch (filter) {
      InboxFilter.all => PhosphorIconsRegular.bell,
      InboxFilter.orders => PhosphorIconsRegular.package,
      InboxFilter.offers => PhosphorIconsRegular.tag,
      InboxFilter.account => PhosphorIconsRegular.user,
      InboxFilter.system => PhosphorIconsRegular.gear,
    };

({Color background, Color foreground, IconData icon}) _tint(InboxIcon icon) => switch (icon) {
      InboxIcon.package => (background: const Color(0xFFE7F0FF), foreground: const Color(0xFF3B82F6), icon: PhosphorIconsFill.package),
      InboxIcon.tag => (background: const Color(0xFFFFE8EA), foreground: const Color(0xFFFF4D67), icon: PhosphorIconsFill.tag),
      InboxIcon.truck => (background: const Color(0xFFE5F8EC), foreground: const Color(0xFF1FBE5A), icon: PhosphorIconsFill.truck),
      InboxIcon.heart => (background: const Color(0xFFF3E8FF), foreground: const Color(0xFFA855F7), icon: PhosphorIconsFill.heart),
      InboxIcon.star => (background: const Color(0xFFFFF3DC), foreground: const Color(0xFFF5A018), icon: PhosphorIconsFill.star),
      InboxIcon.clipboard => (
          background: const Color(0xFFE7F0FF),
          foreground: const Color(0xFF3B82F6),
          icon: PhosphorIconsFill.clipboardText,
        ),
      InboxIcon.megaphone => (
          background: const Color(0xFFFFE6EC),
          foreground: const Color(0xFFFF5D7E),
          icon: PhosphorIconsFill.megaphone,
        ),
      InboxIcon.user => (background: const Color(0xFFE7F0FF), foreground: const Color(0xFF3B82F6), icon: PhosphorIconsFill.user),
      InboxIcon.gear => (background: const Color(0xFFEEF1F6), foreground: const Color(0xFF5C6B8A), icon: PhosphorIconsFill.gear),
    };
