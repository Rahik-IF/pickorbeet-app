import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pickorbeet/core/motion/motion.dart';
import 'package:pickorbeet/core/motion/pressable.dart';
import 'package:pickorbeet/core/theme/app_typography.dart';
import 'package:pickorbeet/core/theme/theme.dart';
import 'package:pickorbeet/core/widgets/app_network_image.dart';

/// Opens a dark, pinch-zoomable full-screen gallery. Returns when the user closes it.
Future<void> openFullscreenImages(
  BuildContext context, {
  required List<String> urls,
  int initial = 0,
}) {
  final cleaned = [for (final url in urls) if (url.trim().isNotEmpty) url.trim()];
  if (cleaned.isEmpty) return Future.value();
  final index = initial.clamp(0, cleaned.length - 1);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: Motion.of(context, Motion.medium),
      reverseTransitionDuration: Motion.of(context, Motion.short),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: FullscreenImageGallery(urls: cleaned, initial: index),
      ),
    ),
  );
}

/// Full-bleed image viewer with pinch-zoom. Shows the entire image (contain), not a crop.
class FullscreenImageGallery extends StatefulWidget {
  const FullscreenImageGallery({
    super.key,
    required this.urls,
    this.initial = 0,
  });

  final List<String> urls;
  final int initial;

  @override
  State<FullscreenImageGallery> createState() => _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery> {
  late final PageController _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayOnDark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, page) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: SizedBox.expand(
                  child: AppNetworkImage(
                    url: widget.urls[page],
                    fit: BoxFit.contain,
                    background: Colors.transparent,
                  ),
                ),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                top: top + 20,
                left: 60,
                right: 60,
                child: IgnorePointer(
                  child: Text(
                    '${_index + 1} / ${widget.urls.length}',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSmall.copyWith(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              top: top + 8,
              left: 8,
              child: Pressable(
                semanticLabel: 'Close',
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(PhosphorIconsRegular.x, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
