import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/widgets/app_button.dart';
import 'package:pickorbeet/features/account/security/security_chrome.dart';
import 'package:pickorbeet/features/auth/biometric.dart';

/// Covers the app when biometric unlock is on, including after a return from the background.
class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate> with WidgetsBindingObserver {
  var _unlocked = false;
  var _asking = false;
  var _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _backgrounded && ref.read(biometricLockProvider).enabled) {
      _backgrounded = false;
      setState(() => _unlocked = false);
      _promptIfNeeded();
    }
  }

  Future<void> _promptIfNeeded() async {
    if (!mounted || _asking || _unlocked) return;
    if (!ref.read(biometricLockProvider).enabled) return;
    setState(() => _asking = true);
    final preference = ref.read(biometricLockProvider);
    final ok = await ref.read(biometricLockProvider.notifier).prompt(
          preference.usesFace ? 'Unlock PickOrbeet with Face ID' : 'Unlock PickOrbeet with your fingerprint',
        );
    if (!mounted) return;
    setState(() {
      _asking = false;
      if (ok) _unlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricLockProvider).enabled;
    ref.listen(biometricLockProvider, (previous, next) {
      if (next.enabled && previous?.enabled != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _unlocked = true);
        });
      }
      if (!next.enabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _unlocked) setState(() => _unlocked = false);
        });
      }
    });
    final locked = enabled && !_unlocked;
    return Stack(
      children: [
        widget.child,
        if (locked)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF012783),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SecurityShield(size: 120),
                      const SizedBox(height: 22),
                      Text(
                        'PickOrbeet is locked',
                        style: AppTypography.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confirm your fingerprint or Face ID to continue.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.86), height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      AppButton(
                        label: _asking ? 'Waiting…' : 'Unlock',
                        icon: PhosphorIconsFill.fingerprint,
                        onPressed: _asking ? null : _promptIfNeeded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
