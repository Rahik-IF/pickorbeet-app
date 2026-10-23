import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:pickorbeet/core/constants/server_constant.dart';
import 'package:pickorbeet/core/theme/app_pallete.dart';

/// A banner that fills its slot. Banner artwork carries its own text, so an image whose shape is
/// far from the slot's is shown whole over a blurred fill of itself instead of being cropped.
class BannerImage extends StatefulWidget {
  const BannerImage({super.key, required this.url, required this.slotAspect, this.semanticLabel});

  final String url;
  final double slotAspect;
  final String? semanticLabel;

  /// How far an image's aspect may differ from the slot's before cropping would cut content.
  static const _tolerance = 0.08;

  @override
  State<BannerImage> createState() => _BannerImageState();
}

class _BannerImageState extends State<BannerImage> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);
  double? _imageAspect;
  bool _failed = false;

  ImageProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(BannerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _imageAspect = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final url = ServerConstant.mediaUrl(widget.url);
    if (url.isEmpty) {
      _provider = null;
      return;
    }
    final provider = CachedNetworkImageProvider(url);
    if (provider == _provider && _stream != null) return;
    _provider = provider;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
  }

  void _onImage(ImageInfo info, bool _) {
    final aspect = info.image.width / info.image.height;
    info.dispose();
    if (mounted && aspect != _imageAspect) setState(() => _imageAspect = aspect);
  }

  void _onError(Object _, StackTrace? _) {
    if (mounted) setState(() => _failed = true);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final aspect = _imageAspect;
    final Widget child;
    if (provider == null || _failed) {
      child = const ColoredBox(color: AppPallete.headerMid, child: SizedBox.expand());
    } else if (aspect == null) {
      child = const ColoredBox(color: AppPallete.skeleton, child: SizedBox.expand());
    } else if ((aspect / widget.slotAspect - 1).abs() <= BannerImage._tolerance) {
      child = Image(image: provider, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      child = Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: TileMode.mirror),
            child: Image(image: provider, fit: BoxFit.cover),
          ),
          Image(image: provider, fit: BoxFit.contain),
        ],
      );
    }
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: KeyedSubtree(key: ValueKey((aspect != null, _failed)), child: child),
      ),
    );
  }
}
