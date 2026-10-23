import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';

/// Hosts the tab navigators and fade-throughs between them, keeping every tab's state alive.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() => _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer> with SingleTickerProviderStateMixin {
  late final AnimationController _switch = AnimationController(vsync: this, duration: Motion.medium, value: 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _previous = null);
    });

  int? _previous;

  @override
  void didUpdateWidget(AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    if (Motion.reduced(context)) {
      _previous = null;
      _switch.value = 1;
      return;
    }
    _previous = oldWidget.currentIndex;
    _switch.forward(from: 0);
  }

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppPallete.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++) _branch(i),
        ],
      ),
    );
  }

  Widget _branch(int index) {
    final isCurrent = index == widget.currentIndex;
    final isLeaving = index == _previous;
    final child = RepaintBoundary(child: widget.children[index]);
    return Offstage(
      offstage: !isCurrent && !isLeaving,
      child: TickerMode(
        enabled: isCurrent || isLeaving,
        child: IgnorePointer(
          ignoring: !isCurrent,
          child: FadeThroughTransition(
            animation: isCurrent ? _switch : kAlwaysCompleteAnimation,
            secondaryAnimation: isLeaving ? _switch : kAlwaysDismissedAnimation,
            fillColor: Colors.transparent,
            child: child,
          ),
        ),
      ),
    );
  }
}
