import 'package:flutter/material.dart';

/// Store-wide look of the Official mark: size, accent color, and photo corner.
@immutable
class OfficialBadgeStyle {
  const OfficialBadgeStyle({
    this.size = 'medium',
    this.color = const Color(0xFF2864E8),
    this.position = 'top-left',
  });

  static const standard = OfficialBadgeStyle();

  factory OfficialBadgeStyle.parse({required String size, required String color, required String position}) {
    return OfficialBadgeStyle(
      size: _sizes.contains(size) ? size : 'medium',
      color: _color(color) ?? const Color(0xFF2864E8),
      position: _positions.contains(position) ? position : 'top-left',
    );
  }

  static const _sizes = {'small', 'medium', 'large'};
  static const _positions = {'top-left', 'top-right', 'bottom-left', 'bottom-right'};

  final String size;
  final Color color;
  final String position;

  bool get isTop => position.startsWith('top');
  bool get isLeft => position.endsWith('left');

  double scaleFor(double base) {
    final factor = switch (size) {
      'small' => 0.82,
      'large' => 1.22,
      _ => 1.0,
    };
    return base * factor;
  }

  /// Extra space so a sale chip or heart can sit clear of a badge in the same corner.
  double dropFor(double base) {
    final factor = switch (size) {
      'small' => 0.85,
      'large' => 1.25,
      _ => 1.0,
    };
    return base * factor;
  }

  Color get checkColor => color.computeLuminance() > 0.7 ? const Color(0xFF172033) : Colors.white;

  static Color? _color(String value) {
    final text = value.trim();
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(text)) return null;
    return Color(int.parse(text.substring(1), radix: 16) + 0xFF000000);
  }
}
