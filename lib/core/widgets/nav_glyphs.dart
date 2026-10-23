import 'package:flutter/widgets.dart';

/// The account glyph from the designs: a head above a rounded shoulder arch. Phosphor's `user`
/// has much wider shoulders, so it is drawn here. [filled] gives the solid, heavy-arch version used
/// for the active tab.
class AccountGlyph extends StatelessWidget {
  const AccountGlyph({super.key, required this.color, this.filled = false, this.size = const Size(14.4, 16.4)});

  final Color color;
  final bool filled;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: size, painter: _AccountPainter(color, filled));
  }
}

class _AccountPainter extends CustomPainter {
  _AccountPainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 14.4 x 16.4 grid, then scaled.
    canvas.scale(size.width / 14.4, size.height / 16.4);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    if (filled) {
      canvas.drawCircle(const Offset(7.2, 4.25), 4.25, paint);
      final body = Path()
        ..addRRect(
          RRect.fromLTRBAndCorners(
            0,
            9.9,
            14.4,
            16.4,
            topLeft: const Radius.circular(4.4),
            topRight: const Radius.circular(4.4),
          ),
        );
      final hollow = Path()..addOval(Rect.fromCircle(center: const Offset(7.2, 17), radius: 3.55));
      canvas.drawPath(Path.combine(PathOperation.difference, body, hollow), paint);
      return;
    }

    const stroke = 1.45;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(7.2, 4.2), 4.2 - stroke / 2, paint);

    const left = stroke / 2;
    const right = 14.4 - stroke / 2;
    const top = 9.6 + stroke / 2;
    const bottom = 16.4 - stroke / 2;
    const radius = 2.9;
    final arch = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, top + radius)
      ..arcToPoint(const Offset(left + radius, top), radius: const Radius.circular(radius))
      ..lineTo(right - radius, top)
      ..arcToPoint(const Offset(right, top + radius), radius: const Radius.circular(radius))
      ..lineTo(right, bottom);
    canvas.drawPath(arch, paint);
  }

  @override
  bool shouldRepaint(_AccountPainter old) => old.color != color || old.filled != filled;
}

/// The active home glyph from the designs: a solid house with a round window and a door cut out.
class HomeActiveGlyph extends StatelessWidget {
  const HomeActiveGlyph({super.key, required this.color, this.size = const Size(16.6, 17.6)});

  final Color color;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: size, painter: _HousePainter(color));
  }
}

class _HousePainter extends CustomPainter {
  _HousePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 16.6 x 17.6 grid. The round-joined stroke softens the apex, eaves and corners.
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..scale(size.width / 16.6, size.height / 17.6);
    final house = Path()
      ..moveTo(8.3, 1.2)
      ..lineTo(15.4, 6.2)
      ..lineTo(15.4, 16.4)
      ..lineTo(1.2, 16.4)
      ..lineTo(1.2, 6.2)
      ..close();
    canvas
      ..drawPath(house, Paint()..color = color)
      ..drawPath(
        house,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round,
      );
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas
      ..drawCircle(const Offset(8.3, 7), 1.95, clear)
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          6.35,
          11.2,
          10.25,
          18,
          topLeft: const Radius.circular(1),
          topRight: const Radius.circular(1),
        ),
        clear,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_HousePainter old) => old.color != color;
}

/// The active categories glyph from the designs: four heavy rounded squares, the top two tinted.
class CategoriesActiveGlyph extends StatelessWidget {
  const CategoriesActiveGlyph({super.key, required this.color, this.size = 16.1});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SquaresPainter(color));
  }
}

class _SquaresPainter extends CustomPainter {
  _SquaresPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 16.1 grid: 7.3 squares, 1.5 gap, 2.2 walls.
    canvas.scale(size.width / 16.1);
    const side = 7.3;
    const gap = 1.5;
    const wall = 2.2;
    final ring = Paint()..color = color;
    final tint = Paint()..color = color.withValues(alpha: 0.55);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        final rect = Rect.fromLTWH(col * (side + gap), row * (side + gap), side, side);
        final outer = RRect.fromRectAndRadius(rect, const Radius.circular(2.2));
        final inner = RRect.fromRectAndRadius(rect.deflate(wall), const Radius.circular(0.6));
        canvas.drawDRRect(outer, inner, ring);
        if (row == 0) canvas.drawRRect(inner, tint);
      }
    }
  }

  @override
  bool shouldRepaint(_SquaresPainter old) => old.color != color;
}
