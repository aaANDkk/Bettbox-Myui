import 'dart:ui';

import 'package:bett_box/common/color.dart';
import 'package:bett_box/common/constant.dart' as constants;
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const Duration _bottomSheetEnterDuration = Duration(milliseconds: 300);
const Duration _bottomSheetExitDuration = Duration(milliseconds: 300);
const Curve _modalBottomSheetCurve = Easing.standardDecelerate;
const double _defaultScrollControlDisabledMaxHeightRatio = 9.0 / 16.0;

class SideSheet extends StatefulWidget {
  const SideSheet({
    super.key,
    this.animationController,
    this.enableDrag = true,
    this.showDragHandle,
    this.dragHandleColor,
    this.dragHandleSize,
    this.onDragStart,
    this.onDragEnd,
    this.backgroundColor,
    this.shadowColor,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    required this.onClosing,
    required this.builder,
  }) : assert(elevation == null || elevation >= 0.0);

  final AnimationController? animationController;

  final VoidCallback onClosing;

  final WidgetBuilder builder;

  final bool enableDrag;

  final bool? showDragHandle;

  final Color? dragHandleColor;

  final Size? dragHandleSize;

  final BottomSheetDragStartHandler? onDragStart;

  final BottomSheetDragEndHandler? onDragEnd;

  final Color? backgroundColor;

  final Color? shadowColor;

  final double? elevation;

  final ShapeBorder? shape;

  final Clip? clipBehavior;

  final BoxConstraints? constraints;

  @override
  State<SideSheet> createState() => _SideSheetState();

  static AnimationController createAnimationController(TickerProvider vsync) {
    return AnimationController(
      duration: _bottomSheetEnterDuration,
      reverseDuration: _bottomSheetExitDuration,
      debugLabel: 'SideSheet',
      vsync: vsync,
    );
  }
}

class _SideSheetState extends State<SideSheet> {
  final GlobalKey _childKey = GlobalKey(debugLabel: 'SideSheet child');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color color = widget.backgroundColor ?? colorScheme.surface;
    final Color surfaceTintColor = colorScheme.surfaceTint;
    final Color shadowColor = widget.shadowColor ?? Colors.transparent;
    final double elevation = widget.elevation ?? 0;
    final ShapeBorder shape =
        widget.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(0));

    final BoxConstraints constraints =
        widget.constraints ??
        const BoxConstraints(maxWidth: 320, minWidth: 320);

    final Clip clipBehavior = widget.clipBehavior ?? Clip.none;

    Widget sideSheet = Material(
      key: _childKey,
      color: color,
      elevation: elevation,
      surfaceTintColor: surfaceTintColor,
      shadowColor: shadowColor,
      shape: shape,
      clipBehavior: clipBehavior,
      child: widget.builder(context),
    );

    return ConstrainedBox(constraints: constraints, child: sideSheet);
  }
}

class _ModalSideSheet<T> extends StatefulWidget {
  const _ModalSideSheet({
    super.key,
    required this.route,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    this.isScrollControlled = false,
    this.scrollControlDisabledMaxHeightRatio =
        _defaultScrollControlDisabledMaxHeightRatio,
    this.enableDrag = true,
    this.showDragHandle = false,
  });

  final ModalSideSheetRoute<T> route;
  final bool isScrollControlled;
  final double scrollControlDisabledMaxHeightRatio;
  final Color? backgroundColor;
  final double? elevation;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;
  final bool enableDrag;
  final bool showDragHandle;

  @override
  _ModalSideSheetState<T> createState() => _ModalSideSheetState<T>();
}

class _ModalSideSheetState<T> extends State<_ModalSideSheet<T>> {
  Curve animationCurve = _modalBottomSheetCurve;

  String _getRouteLabel(MaterialLocalizations localizations) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return '';
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return localizations.dialogLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasMaterialLocalizations(context));
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String routeLabel = _getRouteLabel(localizations);

    final curvedAnimation = CurvedAnimation(
      parent: widget.route.animation!,
      curve: animationCurve,
      reverseCurve: animationCurve.flipped,
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: routeLabel,
      explicitChildNodes: true,
      child: Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: RepaintBoundary(
            child: SideSheet(
              animationController: widget.route._animationController,
              onClosing: () {
                if (widget.route.isCurrent) {
                  Navigator.pop(context);
                }
              },
              builder: widget.route.builder,
              backgroundColor: widget.backgroundColor,
              elevation: widget.elevation,
              shape: widget.shape,
              clipBehavior: widget.clipBehavior,
              constraints: widget.constraints,
              enableDrag: widget.enableDrag,
              showDragHandle: widget.showDragHandle,
            ),
          ),
        ),
      ),
    );
  }
}

class ModalSideSheetRoute<T> extends PopupRoute<T> {
  ModalSideSheetRoute({
    required this.builder,
    this.capturedThemes,
    this.barrierLabel,
    this.barrierOnTapHint,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.constraints,
    this.modalBarrierColor,
    this.isDismissible = true,
    this.isScrollControlled = false,
    this.scrollControlDisabledMaxHeightRatio =
        _defaultScrollControlDisabledMaxHeightRatio,
    super.settings,
    this.transitionAnimationController,
    this.anchorPoint,
    this.useSafeArea = false,
    ImageFilter? filter,
  }) : _filter = filter;

  final WidgetBuilder builder;

  final CapturedThemes? capturedThemes;

  final bool isScrollControlled;

  final double scrollControlDisabledMaxHeightRatio;

  final Color? backgroundColor;

  final double? elevation;

  final ShapeBorder? shape;

  final Clip? clipBehavior;

  final BoxConstraints? constraints;

  final Color? modalBarrierColor;

  final bool isDismissible;

  final AnimationController? transitionAnimationController;

  final Offset? anchorPoint;

  final bool useSafeArea;

  final String? barrierOnTapHint;

  final ImageFilter? _filter;

  final ValueNotifier<EdgeInsets> _clipDetailsNotifier =
      ValueNotifier<EdgeInsets>(EdgeInsets.zero);

  @override
  void dispose() {
    _clipDetailsNotifier.dispose();
    super.dispose();
  }

  @override
  Duration get transitionDuration => _bottomSheetEnterDuration;

  @override
  Duration get reverseTransitionDuration => _bottomSheetExitDuration;

  @override
  bool get barrierDismissible => isDismissible;

  @override
  final String? barrierLabel;

  @override
  Color get barrierColor => modalBarrierColor ?? Colors.black26;

  AnimationController? _animationController;

  @override
  AnimationController createAnimationController() {
    assert(_animationController == null);
    if (transitionAnimationController != null) {
      _animationController = transitionAnimationController;
      willDisposeAnimationController = false;
    } else {
      _animationController = SideSheet.createAnimationController(navigator!);
    }
    return _animationController!;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget content = DisplayFeatureSubScreen(
      anchorPoint: anchorPoint,
      child: Builder(
        builder: (BuildContext context) {
          final colorScheme = Theme.of(context).colorScheme;
          return _ModalSideSheet<T>(
            route: this,
            backgroundColor: backgroundColor ?? colorScheme.surface,
            elevation: elevation ?? 0,
            shape: shape,
            clipBehavior: clipBehavior,
            constraints: constraints,
            isScrollControlled: isScrollControlled,
            scrollControlDisabledMaxHeightRatio:
                scrollControlDisabledMaxHeightRatio,
          );
        },
      ),
    );

    final Widget sideSheet = content;

    return capturedThemes?.wrap(sideSheet) ?? sideSheet;
  }

  @override
  Widget buildModalBarrier() {
    final Widget barrier;
    if (barrierColor.a != 0 && !offstage) {
      assert(barrierColor != barrierColor.opacity0);
      final Animation<Color?> color = animation!.drive(
        ColorTween(
          begin: barrierColor.opacity0,
          end: barrierColor,
        ).chain(CurveTween(curve: barrierCurve)),
      );
      barrier = AnimatedModalBarrier(
        color: color,
        dismissible: barrierDismissible,
        semanticsLabel: barrierLabel,
        barrierSemanticsDismissible: semanticsDismissible,
        clipDetailsNotifier: _clipDetailsNotifier,
        semanticsOnTapHint: barrierOnTapHint,
      );
    } else {
      barrier = ModalBarrier(
        dismissible: barrierDismissible,
        semanticsLabel: barrierLabel,
        barrierSemanticsDismissible: semanticsDismissible,
        clipDetailsNotifier: _clipDetailsNotifier,
        semanticsOnTapHint: barrierOnTapHint,
      );
    }
    if (_filter == null) {
      return barrier;
    }
    // 模糊强度由动画驱动（sigma 0 → 目标值，观感等同淡入，省掉 FadeTransition 每帧的整屏 saveLayer）；
    // 并且只模糊「面板还没盖住的那一条」：面板完全不透明，被盖住的区域不需要模糊，
    // 于是模糊面积随面板推进不断缩小，展开全程的合成开销大幅下降。
    final anim = animation!;
    final panelWidth = constraints?.maxWidth ?? 360;
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final fullWidth = box.maxWidth;
            final covered = panelWidth.clamp(0.0, fullWidth);
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                final t = _modalBottomSheetCurve.transform(anim.value);
                final sigma = constants.CommonFilters.blurSigma * t;
                if (sigma <= 0.05) {
                  return const SizedBox.expand();
                }
                final visible = ((fullWidth - covered * t) / fullWidth).clamp(
                  0.0,
                  1.0,
                );
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: visible,
                    heightFactor: 1,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: sigma,
                        sigmaY: sigma,
                        tileMode: TileMode.clamp,
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: const SizedBox.expand(),
            );
          },
        ),
        barrier,
      ],
    );
  }
}

/// 抽屉/侧边弹层只保留最底层那一层背景模糊：下面已经有模糊路由（另一层弹层或弹窗）时不再叠加。
ImageFilter? resolveSheetFilter(BuildContext context, ImageFilter? filter) {
  if (filter == null) return null;
  final route = ModalRoute.of(context);
  if (route == null) return filter;
  if (route is ModalBottomSheetRoute ||
      route is ModalSideSheetRoute ||
      route is RawDialogRoute) {
    return null;
  }
  if (route.filter != null) return null;
  return filter;
}

Future<T?> showModalSideSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio =
      _defaultScrollControlDisabledMaxHeightRatio,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  ImageFilter? filter,
}) {
  assert(debugCheckHasMediaQuery(context));
  assert(debugCheckHasMaterialLocalizations(context));

  final NavigatorState navigator = Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  );
  final MaterialLocalizations localizations = MaterialLocalizations.of(context);
  return navigator.push(
    ModalSideSheetRoute<T>(
      builder: builder,
      filter: resolveSheetFilter(context, filter),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: isScrollControlled,
      scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
      barrierLabel: barrierLabel ?? localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      isDismissible: isDismissible,
      modalBarrierColor:
          barrierColor ?? Theme.of(context).bottomSheetTheme.modalBarrierColor,
      settings: routeSettings,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
      useSafeArea: useSafeArea,
    ),
  );
}

// class ModalAppBar extends StatelessWidget {
//   final String title;
//
//   const ModalAppBar({
//     super.key,
//     required this.title,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return AppBar(
//       automaticallyImplyLeading: false,
//       title: Text(title),
//       centerTitle: false,
//       actions: const [
//         SizedBox(
//           height: kToolbarHeight,
//           width: kToolbarHeight,
//           child: CloseButton(),
//         )
//       ],
//     );
//   }
// }
