import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pickorbeet/core/constants/server_constant.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';

/// Soft auto-crossfade of product photos inside list/home cards.
///
/// Single-URL cards stay static. Multi-image cards gently fade + breathe between
/// photos — slower and quieter than Quick View's PageView peek.
class ProductCardGallery extends StatefulWidget {
  const ProductCardGallery({
    super.key,
    required this.urls,
    this.soldOut = false,
    this.fit = BoxFit.contain,
    this.borderRadius = BorderRadius.zero,
    this.background = Colors.transparent,
    this.interval = const Duration(milliseconds: 3800),
    this.transition = const Duration(milliseconds: 980),
  });

  final List<String> urls;
  final bool soldOut;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Color background;

  /// Time each photo is held before the next crossfade begins.
  final Duration interval;

  /// Crossfade / micro-scale duration (soothed further when [Motion.reduced]).
  final Duration transition;

  @override
  State<ProductCardGallery> createState() => _ProductCardGalleryState();
}

class _ProductCardGalleryState extends State<ProductCardGallery> {
  var _index = 0;
  Timer? _timer;
  Timer? _startDelay;

  List<String> get _urls {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in widget.urls) {
      final url = raw.trim();
      if (url.isEmpty || !seen.add(url)) continue;
      out.add(url);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleStart();
    });
  }

  @override
  void didUpdateWidget(covariant ProductCardGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameUrls(oldWidget.urls, widget.urls)) {
      _index = 0;
      _restart();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  bool _sameUrls(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _restart() {
    _startDelay?.cancel();
    _timer?.cancel();
    _timer = null;
    _scheduleStart();
  }

  void _scheduleStart() {
    _startDelay?.cancel();
    if (!mounted || _urls.length < 2 || Motion.reduced(context)) return;
    // Stagger so a grid doesn't flash every tile in lockstep.
    final staggerMs = 350 + (hashCode.abs() % 1600);
    _startDelay = Timer(Duration(milliseconds: staggerMs), () {
      if (!mounted) return;
      _precacheNeighbor();
      _syncTimer();
    });
  }

  void _syncTimer() {
    if (!mounted) return;
    if (_urls.length < 2 || Motion.reduced(context)) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer == null) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!mounted || _urls.length < 2 || Motion.reduced(context)) {
      _timer = null;
      return;
    }
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _urls.length < 2) return;
      setState(() => _index = (_index + 1) % _urls.length);
      _precacheNeighbor();
    });
  }

  void _precacheNeighbor() {
    if (!mounted || _urls.length < 2) return;
    final next = ServerConstant.mediaUrl(_urls[(_index + 1) % _urls.length]);
    if (next.isEmpty) return;
    unawaited(precacheImage(NetworkImage(next), context));
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    final url = urls.isEmpty ? null : urls[_index % urls.length];
    final image = AppNetworkImage(
      key: ValueKey(url ?? 'empty'),
      url: url,
      fit: widget.fit,
      borderRadius: widget.borderRadius,
      background: widget.background,
    );

    Widget framed = urls.length < 2
        ? image
        : AnimatedSwitcher(
            duration: Motion.of(context, widget.transition),
            reverseDuration: Motion.of(context, widget.transition),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                ...previous,
                if (current != null) current,
              ],
            ),
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.035, end: 1).animate(curved),
                  child: child,
                ),
              );
            },
            child: image,
          );

    if (widget.soldOut) {
      framed = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.33, 0.59, 0.11, 0, 0, //
            0.33, 0.59, 0.11, 0, 0, //
            0.33, 0.59, 0.11, 0, 0, //
            0, 0, 0, 1, 0,
          ]),
          child: framed,
        ),
      );
    }

    return framed;
  }
}
