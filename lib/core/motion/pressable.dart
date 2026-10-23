import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:pickorbeet/core/motion/motion.dart';

/// Spring press-scale for anything tappable. A quick tap still shows a visible dip.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptic = false,
    this.semanticLabel,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;
  final String? semanticLabel;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);
  DateTime? _downAt;

  bool get _active => widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _springTo(double target) {
    if (Motion.reduced(context)) {
      _scale.value = 1;
      return;
    }
    _scale.animateWith(SpringSimulation(Motion.pressSpring, _scale.value, target, _scale.velocity));
  }

  void _down(TapDownDetails _) {
    _downAt = DateTime.now();
    _springTo(widget.pressedScale);
  }

  Future<void> _up() async {
    final downAt = _downAt;
    _downAt = null;
    if (!mounted || Motion.reduced(context)) return;
    final heldFor = downAt == null ? Duration.zero : DateTime.now().difference(downAt);
    if (heldFor < const Duration(milliseconds: 90)) {
      await _scale.animateTo(widget.pressedScale, duration: const Duration(milliseconds: 70), curve: Curves.easeOut);
    }
    if (mounted) _springTo(1);
  }

  void _tap() {
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ScaleTransition(scale: _scale, child: widget.child);
    if (!_active) return child;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: _down,
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        onTap: widget.onTap == null ? null : _tap,
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
  }
}
