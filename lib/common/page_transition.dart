import 'dart:async';
import 'dart:math' as math;

import 'package:bett_box/common/system.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;
import 'package:flutter/material.dart';

const _duration = Duration(milliseconds: 500);
const double _dimAmount = 0.55;
const double _fallbackCornerRadius = 28.0;

/// Fraction of the exit after which the dimming is gone: leaving should clear
/// the dim early instead of holding it until the very end.
const double _dimExitFraction = 0.55;

double _screenCornerRadius = 0;

double get screenCornerRadius =>
    _screenCornerRadius > 0 ? _screenCornerRadius : _fallbackCornerRadius;

Future<void> loadScreenCornerRadius() async {
  if (!system.isAndroid) return;
  final int radiusPx;
  try {
    radiusPx = await app.getDisplayCornerRadius();
  } catch (_) {
    return;
  }
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (radiusPx <= 0 || views.isEmpty) return;
  _screenCornerRadius = radiusPx / views.first.devicePixelRatio;
}

/// Completes once the enclosing route finished its enter transition.
Future<void> waitRouteSettled(BuildContext context) {
  final animation = ModalRoute.of(context)?.animation;
  if (animation == null || animation.status == AnimationStatus.completed) {
    return Future.value();
  }
  final completer = Completer<void>();

  void listener(AnimationStatus status) {
    if (!status.isCompleted && !status.isDismissed) return;
    animation.removeStatusListener(listener);
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  animation.addStatusListener(listener);
  return completer.future;
}

/// Step response of an underdamped spring (response 0.8, damping 0.95).
class PageTransitionCurve extends Curve {
  const PageTransitionCurve();

  static const double _response = 0.8;
  static const double _damping = 0.95;

  static final double _omega = 2 * math.pi / _response;
  static final double _k = _omega * _omega;
  static final double _c = _damping * 4 * math.pi / _response;
  static final double _w = math.sqrt(4 * _k - _c * _c) / 2;
  static final double _r = -_c / 2;
  static final double _c2 = _r / _w;

  @override
  double transformInternal(double t) =>
      math.exp(_r * t) * (-math.cos(_w * t) + _c2 * math.sin(_w * t)) + 1;
}

/// Cupertino transition + leading corner rounding + covered page dimming.
Widget buildPageTransition<T>(
  PageRoute<T> route,
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final double radius =
      system.isAndroid && animation.isAnimating ? screenCornerRadius : 0.0;
  final Widget clipped = ClipRRect(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(radius),
      bottomLeft: Radius.circular(radius),
    ),
    child: child,
  );
  // The covered page is kept still: the slide owns the movement only.
  final Widget slide = CupertinoRouteTransitionMixin.buildPageTransitions<T>(
    route,
    context,
    animation,
    kAlwaysDismissedAnimation,
    clipped,
  );
  return Stack(
    fit: StackFit.expand,
    children: <Widget>[
      _DimScrim(animation: animation),
      slide,
    ],
  );
}

/// Dims the page below while this route is moving. Driven by the route's own
/// animation, so it never follows a proxy animation that swaps mid-flight.
///
/// Entering follows the spring curve. Leaving does not run that curve backwards
/// and does not switch to another curve either: the route's reverse is
/// compressed to `duration × value`, so a transition interrupted right after it
/// started would take the dim down with it in a few dozen milliseconds — and a
/// curve switch on the flip frame drops it from the spring's value to nothing at
/// all in that same frame, which is what flashed the page below back to full
/// brightness. Instead the exit keeps the depth that is on screen right now (the
/// first reverse frame is exactly the last enter frame) and fades from there on
/// a clock of its own, gone after [_dimExitFraction] of it.
class _DimScrim extends StatefulWidget {
  const _DimScrim({required this.animation});

  final Animation<double> animation;

  @override
  State<_DimScrim> createState() => _DimScrimState();
}

class _DimScrimState extends State<_DimScrim>
    with SingleTickerProviderStateMixin {
  static const Curve _curve = PageTransitionCurve();

  /// The exit clock: it runs the full `_duration`, so an interrupted enter
  /// still gets a real fade instead of the few milliseconds its reverse takes.
  late final AnimationController _exit;

  @override
  void initState() {
    super.initState();
    _exit = AnimationController(vsync: this, duration: _duration);
    widget.animation.addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(covariant _DimScrim oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_handleStatus);
      widget.animation.addStatusListener(_handleStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleStatus);
    _exit.dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      // Leaving: start the exit clock at zero, so the factor is exactly 1 on
      // this frame and the dim keeps the depth it already has.
      _exit.forward(from: 0);
      return;
    }
    _exit.stop();
    _exit.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _exit]),
      builder: (context, _) {
        final Animation<double> animation = widget.animation;
        if (!animation.isAnimating) return const SizedBox.shrink();
        double progress = _curve.transform(animation.value);
        if (animation.status == AnimationStatus.reverse) {
          progress *= 1 -
              Curves.easeOutCubic.transform(
                math.min(_exit.value / _dimExitFraction, 1),
              );
        }
        if (progress <= 0) return const SizedBox.shrink();
        return IgnorePointer(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: _dimAmount * progress),
          ),
        );
      },
    );
  }
}

class PageTransitionBuilder extends PageTransitionsBuilder {
  const PageTransitionBuilder();

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildPageTransition<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
