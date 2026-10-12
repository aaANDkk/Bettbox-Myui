import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Starts a push transition once the incoming page finished its first heavy
/// frames, so a long first build cannot swallow the start of the transition.
mixin DeferredPushRouteMixin<T> on TransitionRoute<T> {
  /// Frame budget plus slack: anything slower still counts as first-build work.
  static const Duration _settledFrame = Duration(milliseconds: 34);
  static const int _maxHeldFrames = 5;

  _TickerCapture? _vsync;

  @override
  AnimationController createAnimationController() {
    final vsync = _vsync = _TickerCapture(navigator!);
    return AnimationController(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      debugLabel: debugLabel,
      vsync: vsync,
    );
  }

  @override
  TickerFuture didPush() {
    final ticker = _vsync?.ticker;
    if (ticker == null || ticker.muted) {
      return super.didPush();
    }
    ticker.muted = true;
    final pushed = super.didPush();
    final context = navigator!.context;
    Duration? lastStamp;
    var heldFrames = 0;

    void resumeWhenSettled(Duration stamp) {
      if (navigator == null) return;
      final delta = lastStamp == null ? null : stamp - lastStamp!;
      lastStamp = stamp;
      heldFrames++;
      final settled =
          (delta != null && delta <= _settledFrame) ||
          heldFrames >= _maxHeldFrames;
      if (!settled) {
        SchedulerBinding.instance.addPostFrameCallback(resumeWhenSettled);
        return;
      }
      ticker.muted = !TickerMode.of(context);
    }

    SchedulerBinding.instance.addPostFrameCallback(resumeWhenSettled);
    return pushed;
  }
}

class _TickerCapture implements TickerProvider {
  _TickerCapture(this._parent);

  final TickerProvider _parent;
  Ticker? ticker;

  @override
  Ticker createTicker(TickerCallback onTick) {
    return ticker = _parent.createTicker(onTick);
  }
}
