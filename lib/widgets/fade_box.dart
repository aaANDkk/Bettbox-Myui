import 'package:animations/animations.dart';
import 'package:bett_box/common/common.dart';
import 'package:flutter/material.dart';

class FadeBox extends StatelessWidget {
  final Widget child;
  final Alignment? alignment;

  const FadeBox({super.key, required this.child, this.alignment});

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      transitionBuilder: (child, animation, secondaryAnimation) {
        return Container(
          alignment: alignment ?? Alignment.centerLeft,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: child,
    );
  }
}

class FadeThroughBox extends StatelessWidget {
  final Widget child;
  final Alignment? alignment;
  final EdgeInsets? margin;

  const FadeThroughBox({
    super.key,
    required this.child,
    this.alignment,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      transitionBuilder: (child, animation, secondaryAnimation) {
        return Container(
          margin: margin,
          alignment: alignment ?? Alignment.centerLeft,
          child: FadeThroughTransition(
            animation: animation,
            fillColor: Colors.transparent,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class FadeScaleBox extends StatelessWidget {
  final Widget child;

  const FadeScaleBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      transitionBuilder: (child, animation) {
        return Container(
          alignment: Alignment.bottomRight,
          child: FadeScaleTransition(animation: animation, child: child),
        );
      },
      duration: Duration(milliseconds: 300),
      child: child,
    );
  }
}

class FadeScaleEnterBox extends StatefulWidget {
  final Widget child;
  final bool animate;

  const FadeScaleEnterBox({
    super.key,
    required this.child,
    this.animate = true,
  });

  @override
  State<FadeScaleEnterBox> createState() => _FadeScaleEnterBoxState();
}

class _FadeScaleEnterBoxState extends State<FadeScaleEnterBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: commonDuration,
      value: widget.animate ? 0.0 : 1.0,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant FadeScaleEnterBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key != widget.child.key) {
      if (widget.animate) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1.0;
      }
    } else if (!oldWidget.animate && widget.animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller.view,
      builder: (_, child) {
        if (_controller.value >= 1.0) {
          return child!;
        }
        return FadeScaleEnterTransition(animation: _animation, child: child!);
      },
      child: widget.child,
    );
  }
}

class FadeScaleEnterTransition extends StatelessWidget {
  const FadeScaleEnterTransition({
    super.key,
    required this.animation,
    this.child,
  });

  final Animation<double> animation;
  final Widget? child;

  static final Animatable<double> _fadeInTransition = CurveTween(
    curve: const Interval(0.0, 0.3),
  );
  static final Animatable<double> _scaleInTransition = Tween<double>(
    begin: 0.70,
    end: 1.00,
  ).chain(CurveTween(curve: Easing.legacyDecelerate));

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeInTransition.animate(animation),
      child: ScaleTransition(
        scale: _scaleInTransition.animate(animation),
        child: child,
      ),
    );
  }
}

const _defaultSlideDistance = 24.0;

class FadeSlideEnterBox extends StatefulWidget {
  final Duration delay;
  final double distance;
  final Widget child;

  const FadeSlideEnterBox({
    super.key,
    this.delay = Duration.zero,
    this.distance = _defaultSlideDistance,
    required this.child,
  });

  @override
  State<FadeSlideEnterBox> createState() => _FadeSlideEnterBoxState();
}

class _FadeSlideEnterBoxState extends State<FadeSlideEnterBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final total = commonDuration + widget.delay;
    _controller = AnimationController(vsync: this, duration: total);
    final start = widget.delay.inMicroseconds / total.inMicroseconds;
    _animation = start == 0
        ? _controller.view
        : _controller.drive(CurveTween(curve: Interval(start, 1)));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeSlideEnterTransition(
      animation: _animation,
      distance: widget.distance,
      child: widget.child,
    );
  }
}

class FadeSlideEnterTransition extends StatelessWidget {
  const FadeSlideEnterTransition({
    super.key,
    required this.animation,
    this.distance = _defaultSlideDistance,
    this.child,
  });

  final Animation<double> animation;
  final double distance;
  final Widget? child;

  static final Animatable<double> _fadeInTransition = CurveTween(
    curve: const Interval(0.0, 0.25),
  );
  static final Animatable<double> _slideInCurve = CurveTween(
    curve: Easing.emphasizedDecelerate,
  );

  @override
  Widget build(BuildContext context) {
    final slide = Tween<double>(
      begin: -distance,
      end: 0,
    ).chain(_slideInCurve).animate(animation);
    return FadeTransition(
      opacity: _fadeInTransition.animate(animation),
      child: AnimatedBuilder(
        animation: slide,
        builder: (_, child) {
          return Transform.translate(
            offset: Offset(0, slide.value),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}
