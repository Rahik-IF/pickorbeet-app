import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/failure/failure.dart';
import 'package:pickorbeet/core/providers/preferences_notifier.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/features/account/security/security_chrome.dart';
import 'package:pickorbeet/features/account/security/security_repository.dart';

class LoginActivityPage extends ConsumerWidget {
  const LoginActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SecurityTone.of(ref.watch(preferencesProvider).darkMode);
    final activity = ref.watch(_activityProvider);
    return SecuritySubpage(
      tone: tone,
      title: 'Login Activity',
      child: activity.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _Message(
          tone: tone,
          text: error is AppFailure ? error.message : 'Could not load login activity.',
          onRetry: () => ref.invalidate(_activityProvider),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return _Message(tone: tone, text: 'No sign-in attempts yet.');
          }
          return Column(
            children: [
              for (final entry in entries) ...[
                SecurityCard(
                  tone: tone,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        Icon(
                          entry.success ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warningCircle,
                          color: entry.success ? const Color(0xFF22A35A) : const Color(0xFFE23B35),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.success ? 'Signed in' : 'Sign-in failed',
                                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700, color: tone.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.deviceName} · ${entry.methodLabel}',
                                style: AppTypography.bodySmall.copyWith(color: tone.meta),
                              ),
                              if (entry.ipAddress != null)
                                Text(entry.ipAddress!, style: AppTypography.bodySmall.copyWith(color: tone.hint, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _when(entry.createdAt),
                          textAlign: TextAlign.right,
                          style: AppTypography.bodySmall.copyWith(color: tone.hint, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

final _activityProvider = FutureProvider.autoDispose<List<LoginActivityEntry>>((ref) async {
  final result = await ref.watch(securityRepositoryProvider).loginActivity();
  return result.fold((failure) => throw failure, (entries) => entries);
});

class _Message extends StatelessWidget {
  const _Message({required this.tone, required this.text, this.onRetry});

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
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

String _when(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  final now = DateTime.now();
  final clock = DateFormat('h:mm a').format(local);
  if (local.year == now.year && local.month == now.month && local.day == now.day) return 'Today\n$clock';
  return '${DateFormat('d MMM').format(local)}\n$clock';
}
