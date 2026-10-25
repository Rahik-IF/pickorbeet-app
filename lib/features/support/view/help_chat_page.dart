import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/routes.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';
import 'package:pickorbeet/core/widgets/bottom_nav.dart';
import 'package:pickorbeet/core/widgets/header_actions.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/view/orders_palette.dart';
import 'package:pickorbeet/features/support/help_chat_controller.dart';
import 'package:pickorbeet/features/support/help_models.dart';
import 'package:url_launcher/url_launcher.dart';

const _tabs = <String>[
  Routes.home,
  Routes.categories,
  Routes.wishlist,
  Routes.account,
  Routes.cart,
];

const _topics = <(String, String, IconData)>[
  ('track_order', 'Track my order', PhosphorIconsRegular.package),
  ('payment', 'Payment issue', PhosphorIconsRegular.creditCard),
  ('return', 'Return or refund', PhosphorIconsRegular.arrowUUpLeft),
  ('product', 'Product question', PhosphorIconsRegular.question),
];

const _emojis = ['😊', '👍', '🙏', '❤️', '😍', '🎉', '😢', '🤔'];

/// Live support chat. History comes from the API; the socket adds replies as they are sent.
class HelpChatPage extends ConsumerStatefulWidget {
  const HelpChatPage({super.key, this.orderNumber = ''});

  final String orderNumber;

  @override
  ConsumerState<HelpChatPage> createState() => _HelpChatPageState();
}

class _HelpChatPageState extends ConsumerState<HelpChatPage> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  Timer? _typingIdle;
  var _nearBottom = true;
  var _opened = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      _nearBottom = position.maxScrollExtent - position.pixels < 80;
    });
  }

  @override
  void dispose() {
    _typingIdle?.cancel();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openOnce() {
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(helpChatProvider.notifier).open(widget.orderNumber));
    });
  }

  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_nearBottom) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _onDraft(String value) {
    final chat = ref.read(helpChatProvider.notifier);
    chat.setTyping(value.trim().isNotEmpty);
    _typingIdle?.cancel();
    _typingIdle = Timer(
      const Duration(seconds: 2),
      () => chat.setTyping(false),
    );
  }

  Future<void> _sendText() async {
    final text = _draft.text.trim();
    if (text.isEmpty) return;
    _draft.clear();
    _nearBottom = true;
    final error = await ref.read(helpChatProvider.notifier).sendText(text);
    if (!mounted) return;
    if (error != null) {
      _draft.text = text;
      showToast(context, error, kind: ToastKind.error);
      return;
    }
    _follow();
  }

  Future<void> _sendTopic(String topic) async {
    _nearBottom = true;
    final error = await ref.read(helpChatProvider.notifier).sendTopic(topic);
    if (!mounted) return;
    if (error != null) showToast(context, error, kind: ToastKind.error);
    _follow();
  }

  Future<void> _attach() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 84,
    );
    if (photo == null || !mounted) return;
    final bytes = await photo.readAsBytes();
    final name = photo.name.trim().isEmpty ? 'photo.jpg' : photo.name.trim();
    final caption = _draft.text.trim();
    _draft.clear();
    _nearBottom = true;
    final error = await ref
        .read(helpChatProvider.notifier)
        .sendPhoto(bytes, name, caption: caption);
    if (!mounted) return;
    if (error != null) {
      _draft.text = caption;
      showToast(context, error, kind: ToastKind.error);
      return;
    }
    _follow();
  }

  void _insertEmoji(String emoji) {
    final text = _draft.value;
    final selection = text.selection;
    final start = selection.start < 0 ? text.text.length : selection.start;
    final end = selection.end < 0 ? text.text.length : selection.end;
    final next = text.text.replaceRange(start, end, emoji);
    _draft.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _onDraft(next);
  }

  void _info(HelpProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPallete.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          8,
          12,
          8,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppPallete.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'PickOrbeet Support',
              style: AppTypography.titleMedium.copyWith(fontSize: 16),
            ),
            ListTile(
              leading: const Icon(
                PhosphorIconsRegular.envelope,
                color: AppPallete.primary,
              ),
              title: const Text('Email'),
              subtitle: Text(
                profile.email.isEmpty ? 'Not listed' : profile.email,
              ),
              onTap: profile.email.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      unawaited(
                        launchUrl(Uri(scheme: 'mailto', path: profile.email)),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _openOnce();
    final chat = ref.watch(helpChatProvider);
    ref.listen(helpChatProvider, (previous, next) {
      final grew =
          (previous?.messages.length ?? 0) != next.messages.length ||
          previous?.agentTyping != next.agentTyping;
      if (grew) _follow();
    });
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnLight,
      child: Scaffold(
        backgroundColor: AppPallete.background,
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: keyboardOpen
            ? null
            : AppBottomNav(
                currentIndex: 3,
                cartCount: ref.watch(cartCountProvider),
                onSelect: (index) => context.go(_tabs[index]),
              ),
        body: Column(
          children: [
            _Header(
              profile: chat.profile,
              online: chat.agentOnline,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go(Routes.account),
              onInfo: () => _info(chat.profile),
            ),
            _Topics(onSelect: _sendTopic, enabled: !chat.sending),
            Expanded(
              child: _Thread(
                chat: chat,
                scroll: _scroll,
                onRetry: () => unawaited(
                  ref.read(helpChatProvider.notifier).open(widget.orderNumber),
                ),
              ),
            ),
            _Composer(
              controller: _draft,
              sending: chat.sending,
              onChanged: _onDraft,
              onSend: _sendText,
              onAttach: _attach,
              onEmoji: _insertEmoji,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Secure conversation · Your details are protected.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.online,
    required this.onBack,
    required this.onInfo,
  });

  final HelpProfile profile;
  final bool online;
  final VoidCallback onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final status = online ? 'Online' : profile.replyLine;
    return ColoredBox(
      color: AppPallete.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, top + 6, 4, 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                PhosphorIconsRegular.arrowLeft,
                color: AppPallete.ink,
              ),
            ),
            _Avatar(url: profile.avatar, name: profile.name, size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: online
                              ? const Color(0xFF1FA85A)
                              : AppPallete.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: online
                                ? const Color(0xFF1FA85A)
                                : AppPallete.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (online)
                    Text(
                      profile.replyLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                ],
              ),
            ),
            _HeaderIcon(
              icon: PhosphorIconsRegular.info,
              label: 'Support details',
              onPressed: onInfo,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: AppPallete.ink),
      ),
    );
  }
}

class _Topics extends StatelessWidget {
  const _Topics({required this.onSelect, required this.enabled});

  final ValueChanged<String> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPallete.surface,
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          itemCount: _topics.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final topic = _topics[index];
            return Pressable(
              onTap: enabled ? () => onSelect(topic.$1) : null,
              enabled: enabled,
              semanticLabel: topic.$2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPallete.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppPallete.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Icon(topic.$3, size: 14, color: AppPallete.primary),
                      const SizedBox(width: 6),
                      Text(
                        topic.$2,
                        style: AppTypography.label.copyWith(
                          color: AppPallete.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({
    required this.chat,
    required this.scroll,
    required this.onRetry,
  });

  final HelpChatState chat;
  final ScrollController scroll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (chat.loading && chat.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppPallete.primary),
      );
    }
    if (chat.error.isNotEmpty && chat.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chat.error,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    final typing = chat.agentTyping;
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: chat.messages.length + (typing ? 1 : 0),
      itemBuilder: (context, index) {
        if (typing && index == chat.messages.length) {
          return _TypingLine(name: chat.profile.name);
        }
        final message = chat.messages[index];
        final previous = index > 0 ? chat.messages[index - 1] : null;
        return _Bubble(
          message: message,
          showAvatar:
              !message.fromCustomer &&
              (previous == null || previous.fromCustomer),
          avatar: chat.profile.avatar,
          name: chat.profile.name,
        );
      },
    );
  }
}

class _TypingLine extends StatelessWidget {
  const _TypingLine({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text('$name is typing…', style: AppTypography.caption),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.showAvatar,
    required this.avatar,
    required this.name,
  });

  final HelpMessage message;
  final bool showAvatar;
  final String avatar;
  final String name;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromCustomer;
    final time = DateFormat('h:mm a').format(message.createdAt.toLocal());
    final label = message.topicLabel.isNotEmpty
        ? message.topicLabel
        : message.body;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty || message.image.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: mine ? AppPallete.primary : AppPallete.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                border: mine ? null : Border.all(color: AppPallete.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.image.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SizedBox(
                          width: 180,
                          height: 140,
                          child: AppNetworkImage(
                            url: message.image,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    if (label.isNotEmpty)
                      Text(
                        label,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 13,
                          color: mine ? AppPallete.onDark : AppPallete.ink,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (message.order != null) ...[
            const SizedBox(height: 8),
            _OrderCard(order: message.order!),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(time, style: AppTypography.caption),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(
                  PhosphorIconsBold.checks,
                  size: 13,
                  color: message.readAt == null
                      ? AppPallete.textSecondary
                      : AppPallete.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            showAvatar
                ? _Avatar(url: avatar, name: name, size: 28)
                : const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final HelpOrderCard order;

  @override
  Widget build(BuildContext context) {
    final colors = switch (order.status) {
      'shipped' ||
      'out_for_delivery' => (OrdersPalette.pillBlue, OrdersPalette.blue),
      'delivered' => (OrdersPalette.pillGreen, OrdersPalette.green),
      'cancelled' || 'refunded' => (OrdersPalette.pillRed, OrdersPalette.red),
      _ => (OrdersPalette.pillOrange, OrdersPalette.orangeDeep),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPallete.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPallete.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final width = !available.isFinite || available > 260
                ? 260.0
                : available;
            return SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: AppNetworkImage(
                          url: order.productImage,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order ${order.displayNumber}',
                              style: AppTypography.label.copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppPallete.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.$1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        order.statusLabel,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.$2,
                        ),
                      ),
                    ),
                  ),
                  if (order.expectedDelivery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Expected Delivery', style: AppTypography.caption),
                    Text(
                      order.expectedDelivery,
                      style: AppTypography.label.copyWith(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Pressable(
                    onTap: () => context.push(
                      Uri(
                        path: Routes.trackOrder,
                        queryParameters: {
                          'order': order.orderNumber,
                          'id': order.id,
                        },
                      ).toString(),
                    ),
                    semanticLabel: 'Track order ${order.displayNumber}',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppPallete.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            'Track order',
                            style: AppTypography.label.copyWith(
                              color: AppPallete.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
    required this.onEmoji,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPallete.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          children: [
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                separatorBuilder: (_, _) => const SizedBox(width: 2),
                itemBuilder: (_, index) => Pressable(
                  onTap: () => onEmoji(_emojis[index]),
                  semanticLabel: 'Insert ${_emojis[index]}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      _emojis[index],
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: sending ? null : onAttach,
                  icon: const Icon(
                    PhosphorIconsRegular.paperclip,
                    color: AppPallete.ink,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSend(),
                    style: AppTypography.bodyLarge.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      hintStyle: AppTypography.bodyLarge.copyWith(
                        fontSize: 14,
                        color: AppPallete.searchHint,
                      ),
                      filled: true,
                      fillColor: AppPallete.background,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Pressable(
                  onTap: sending ? null : onSend,
                  enabled: !sending,
                  semanticLabel: 'Send message',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppPallete.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      sending
                          ? PhosphorIconsRegular.circleNotch
                          : PhosphorIconsRegular.paperPlaneTilt,
                      color: AppPallete.onDark,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.size});

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'N' : name.trim()[0].toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? ColoredBox(
                color: AppPallete.primarySoft,
                child: Center(
                  child: Text(
                    initial,
                    style: AppTypography.label.copyWith(
                      color: AppPallete.primary,
                    ),
                  ),
                ),
              )
            : AppNetworkImage(url: url),
      ),
    );
  }
}
