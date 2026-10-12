import 'package:flutter/material.dart';

/// Mirrors bett_box's `lib/common/superellipse.dart`; 2.12-compatible syntax.
class SuperellipseBorder extends RoundedSuperellipseBorder {
  const SuperellipseBorder({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) : super(
         side: side ?? BorderSide.none,
         borderRadius: borderRadius ?? BorderRadius.zero,
       );

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }

  @override
  SuperellipseBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) {
    return SuperellipseBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return SuperellipseBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    return _keepSuperellipse(super.lerpFrom(a, t));
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    return _keepSuperellipse(super.lerpTo(b, t));
  }

  static ShapeBorder? _keepSuperellipse(ShapeBorder? border) {
    if (border is RoundedSuperellipseBorder) {
      return SuperellipseBorder(
        side: border.side,
        borderRadius: border.borderRadius,
      );
    }
    return border;
  }
}
