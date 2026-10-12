import 'package:flutter/material.dart';

/// Rounded superellipse that always paints through a [Path].
///
/// Skia (windows / linux / macos) has no native rounded superellipse: the
/// engine falls back to a plain rounded rectangle for filled
/// [Canvas.drawRSuperellipse] calls, so solid [ShapeDecoration] surfaces lose
/// their continuous corners on desktop while Impeller keeps them. Building the
/// outline as a path renders the exact curve on every backend.
class SuperellipseBorder extends RoundedSuperellipseBorder {
  const SuperellipseBorder({super.side, super.borderRadius});

  /// The outline only depends on the rect, the radius and the direction, so the
  /// built path is reused across frames instead of being rebuilt for every
  /// filled decoration on every paint.
  static final Map<Object, Path> _outerPathCache = <Object, Path>{};
  static const int _outerPathCacheLimit = 256;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final key = Object.hash(rect, borderRadius, textDirection);
    final cached = _outerPathCache[key];
    if (cached != null) {
      return cached;
    }
    final path = super.getOuterPath(rect, textDirection: textDirection);
    if (_outerPathCache.length >= _outerPathCacheLimit) {
      _outerPathCache.remove(_outerPathCache.keys.first);
    }
    _outerPathCache[key] = path;
    return path;
  }

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
