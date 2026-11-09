import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/providers/preferences_notifier.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/core/widgets/toast.dart';
import 'package:pickorbeet/features/account/security/security_chrome.dart';
import 'package:pickorbeet/features/account/security/security_repository.dart';

class ManageDevicesPage extends ConsumerWidget {
  const ManageDevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SecurityTone.of(ref.watch(preferencesProvider).darkMode);
    final devices = ref.watch(_devicesProvider);
    return SecuritySubpage(
      tone: tone,
      title: 'Manage Devices',
      child: devices.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _DevicesMessage(
          tone: tone,
          text: error is AppFailure ? error.message : 'Could not load devices.',
          onRetry: () => ref.invalidate(_devicesProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return _DevicesMessage(tone: tone, text: 'No other sessions yet. This sign-in will show up after the next login.');
          }
          final others = rows.where((row) => !row.current).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'These devices are signed in to your account. Signing one out blocks it immediately.',
                style: AppTypography.bodySmall.copyWith(color: tone.meta, height: 1.4),
              ),
              const SizedBox(height: 14),
              for (final device in rows) ...[
                SecurityCard(
                  tone: tone,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsFill.deviceMobile, color: Color(0xFF3B6FE8), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(device.deviceName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700, color: tone.ink)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (device.platform.isNotEmpty) device.platform,
                                  if (device.ipAddress != null) device.ipAddress,
                                  if (device.lastSeen != null) 'Seen ${DateFormat('d MMM, h:mm a').format(device.lastSeen!.toLocal())}',
                                ].whereType<String>().join(' · '),
                                style: AppTypography.bodySmall.copyWith(color: tone.meta, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (device.current)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFE8F8EE), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              'This device',
                              style: AppTypography.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF168A45)),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => _revoke(context, ref, device),
                            child: const Text('Sign out'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (others > 0) ...[
                const SizedBox(height: 8),
                AppButton(
                  label: 'Sign out other devices',
                  variant: AppButtonVariant.outline,
                  onPressed: () => _revokeOthers(context, ref),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, SignedInDevice device) async {
    final result = await ref.read(securityRepositoryProvider).revokeSession(device.id);
    if (!context.mounted) return;
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (message) {
        showToast(context, message, kind: ToastKind.success);
        ref.invalidate(_devicesProvider);
      },
    );
  }

  Future<void> _revokeOthers(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(securityRepositoryProvider).revokeOtherSessions();
    if (!context.mounted) return;
    result.fold(
      (failure) => showToast(context, failure.message, kind: ToastKind.error),
      (message) {
        showToast(context, message, kind: ToastKind.success);
        ref.invalidate(_devicesProvider);
      },
    );
  }
}

final _devicesProvider = FutureProvider.autoDispose<List<SignedInDevice>>((ref) async {
  final result = await ref.watch(securityRepositoryProvider).sessions();
  return result.fold((failure) => throw failure, (devices) => devices);
});

class _DevicesMessage extends StatelessWidget {
  const _DevicesMessage({required this.tone, required this.text, this.onRetry});

  final SecurityTone tone;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center, style: AppTypography.bodySmall.copyWith(color: tone.meta, height: 1.4)),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
