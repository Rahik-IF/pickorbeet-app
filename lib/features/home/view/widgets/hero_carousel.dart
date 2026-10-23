import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/router/web_link.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';
import 'package:pickorbeet/core/widgets/banner_image.dart';
import 'package:pickorbeet/features/catalog/models/catalog_models.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// The rotating hero banners with arrow buttons and expanding dots.
///
/// Autoplay pauses while the user touches it, while its tab is hidden, while the app is in the
/// background, and when the platform asks for reduced motion.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.banners});

  final List<BannerModel> banners;

  /// Matches the design's 790 x 320 banner artwork.
  static const aspect = 790 / 320;
  static const radius = 11.7;
  static const autoplayInterval = Duration(seconds: 5);

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> with WidgetsBindingObserver {
  /// Pages are virtual so swiping past the last banner wraps around.
  static const _loopSpan = 10000;

  late final PageController _controller = PageController(initialPage: _startPage);
  late int _page = _startPage;
  Timer? _timer;
  bool _touching = false;
  bool _visible = true;
  bool _foreground = true;

  int get _count => widget.banners.length;
  int get _startPage => _count <= 1 ? 0 : _loopSpan ~/ 2 - (_loopSpan ~/ 2) % _count;
  int get _index => _count == 0 ? 0 : _page % _count;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.of(context);
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  @override
  void didUpdateWidget(HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length && _controller.hasClients) {
      _controller.jumpToPage(_startPage);
      _page = _startPage;
    }
  }

  void _syncTimer() {
    final shouldRun = _count > 1 && _visible && _foreground && !_touching && !Motion.reduced(context);
    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(HeroCarousel.autoplayInterval, (_) => _go(1));
    } else if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    _syncTimer();
  }

  void _go(int delta) {
    if (!_controller.hasClients || _count < 2) return;
    _controller.animateToPage(
      _page + delta,
      duration: Motion.of(context, const Duration(milliseconds: 620)),
      curve: Motion.emphasized,
    );
  }

  void _arrow(int delta) {
    HapticFeedback.selectionClick();
    _go(delta);
    _restartTimer();
  }

  void _open(BannerModel banner) {
    final location = WebLink.resolve(banner.link, title: banner.title.isEmpty ? null : banner.title);
    if (location != null) context.push(location);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final reduced = Motion.reduced(context);
    return Column(
      children: [
        AspectRatio(
          aspectRatio: HeroCarousel.aspect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HeroCarousel.radius),
              boxShadow: [
                BoxShadow(color: AppPallete.shadow.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HeroCarousel.radius),
              child: Stack(
                children: [
                  Listener(
                    onPointerDown: (_) {
                      _touching = true;
                      _syncTimer();
                    },
                    onPointerUp: (_) {
                      _touching = false;
                      _syncTimer();
                    },
                    onPointerCancel: (_) {
                      _touching = false;
                      _syncTimer();
                    },
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _count == 1 ? 1 : _loopSpan,
                      onPageChanged: (page) => setState(() => _page = page),
                      itemBuilder: (context, page) {
                        final banner = widget.banners[page % _count];
                        return Semantics(
                          button: banner.link.isNotEmpty,
                          label: banner.title.isEmpty ? 'Banner ${page % _count + 1} of $_count' : banner.title,
                          child: GestureDetector(
                            onTap: () => _open(banner),
                            child: reduced
                                ? BannerImage(url: banner.image, slotAspect: HeroCarousel.aspect)
                                : _Parallax(
                                    controller: _controller,
                                    page: page,
                                    child: BannerImage(url: banner.image, slotAspect: HeroCarousel.aspect),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_count > 1) ...[
                    Align(
                      alignment: const Alignment(-1, 0.342),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4.2),
                        child: _ArrowButton(previous: true, onTap: () => _arrow(-1)),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(1, 0.342),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.2),
                        child: _ArrowButton(previous: false, onTap: () => _arrow(1)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_count > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6.25),
            child: AnimatedSmoothIndicator(
              activeIndex: _index,
              count: _count,
              duration: Motion.of(context, Motion.medium),
              curve: Motion.emphasized,
              onDotClicked: (index) {
                _go(index - _index);
                _restartTimer();
              },
              effect: const ExpandingDotsEffect(
                dotWidth: 5.1,
                dotHeight: 5.1,
                expansionFactor: 7.3 / 5.1,
                spacing: 4.55,
                radius: 2.55,
                activeDotColor: Color(0xFFFA8726),
                dotColor: AppPallete.dotInactive,
              ),
            ),
          )
        else
          const SizedBox(height: 11.35),
      ],
    );
  }
}

/// Slides the artwork a little slower than the page while swiping, for depth.
class _Parallax extends StatelessWidget {
  const _Parallax({required this.controller, required this.page, required this.child});

  final PageController controller;
  final int page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          var delta = 0.0;
          if (controller.hasClients && controller.position.haveDimensions) {
            delta = ((controller.page ?? page.toDouble()) - page).clamp(-1.0, 1.0);
          }
          return ClipRect(
            child: Transform.translate(
              offset: Offset(delta * constraints.maxWidth * 0.22, 0),
              child: Transform.scale(scale: 1 + delta.abs() * 0.04, child: child),
            ),
          );
        },
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.previous, required this.onTap});

  final bool previous;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.88,
      semanticLabel: previous ? 'Previous banner' : 'Next banner',
      onTap: onTap,
      child: Container(
        width: 26.6,
        height: 26.6,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppPallete.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Transform.translate(
          offset: Offset(previous ? -0.35 : 0.55, 0),
          child: Icon(
            previous ? PhosphorIconsBold.caretLeft : PhosphorIconsBold.caretRight,
            size: 12.9,
            color: AppPallete.carouselArrow,
          ),
        ),
      ),
    );
  }
}
