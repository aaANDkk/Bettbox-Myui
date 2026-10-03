import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom two-dimensional viewport for the code editor.
///
/// This viewport is used internally by [CodeForge] to enable both vertical
/// and horizontal scrolling within the editor. It delegates to a
/// [Render2DCodeField] for layout and painting.
class CustomViewport extends TwoDimensionalViewport {
  final bool lineWrap;

  /// Creates a [CustomViewport] with the required scroll offsets and axes.
  const CustomViewport({
    super.key,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required TwoDimensionalChildBuilderDelegate super.delegate,
    required super.mainAxis,
    required this.lineWrap,
  });

  @override
  RenderTwoDimensionalViewport createRenderObject(BuildContext context) {
    return Render2DCodeField(
      horizontalOffset: horizontalOffset,
      horizontalAxisDirection: horizontalAxisDirection,
      verticalOffset: verticalOffset,
      verticalAxisDirection: verticalAxisDirection,
      delegate: delegate,
      mainAxis: mainAxis,
      childManager: context as TwoDimensionalChildManager,
      lineWrap: lineWrap,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderTwoDimensionalViewport renderObject,
  ) {
    (renderObject as Render2DCodeField).lineWrap = lineWrap;
    renderObject
      ..horizontalOffset = horizontalOffset
      ..horizontalAxisDirection = horizontalAxisDirection
      ..verticalOffset = verticalOffset
      ..verticalAxisDirection = verticalAxisDirection
      ..delegate = delegate
      ..mainAxis = mainAxis;
  }
}

/// The render object for the code editor's two-dimensional viewport.
///
/// This class handles the layout of the code editor content and manages
/// the content dimensions for both vertical and horizontal scrolling.
class Render2DCodeField extends RenderTwoDimensionalViewport {
  bool lineWrap;

  /// Creates a [Render2DCodeField] with the required scroll configuration.
  Render2DCodeField({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    required super.childManager,
    required this.lineWrap,
  });

  @override
  void layoutChildSequence() {
    final child = buildOrObtainChildFor(ChildVicinity(xIndex: 0, yIndex: 0));

    if (child != null) {
      child.layout(
        BoxConstraints(
          minHeight: 0,
          minWidth: 0,
          maxWidth: lineWrap ? viewportDimension.width : double.infinity,
          maxHeight: double.infinity,
        ),
        parentUsesSize: true,
      );
      parentDataOf(child).layoutOffset = Offset.zero;

      verticalOffset.applyContentDimensions(
        0.0,
        math.max(0.0, child.size.height - viewportDimension.height),
      );
      horizontalOffset.applyContentDimensions(
        0.0,
        math.max(0.0, child.size.width - viewportDimension.width),
      );
    }
  }
}

class CustomScrollbar extends RawScrollbar {
  final TextStyle lineNumberStyle;
  final bool showLineNumberIndicator;
  final ValueNotifier<int> lineNumberNotifier;
  final BorderRadius borderRadius;
  final TextDirection textDirection;

  const CustomScrollbar({
    super.key,
    required super.child,
    required super.controller,
    required this.lineNumberStyle,
    required this.lineNumberNotifier,
    required this.showLineNumberIndicator,
    required this.borderRadius,
    required this.textDirection,
    super.thumbVisibility,
    super.interactive,
    super.thumbColor,
    super.thickness,
    super.crossAxisMargin,
    super.mainAxisMargin,
    super.scrollbarOrientation,
    super.trackBorderColor,
    super.fadeDuration,
    super.timeToFade,
    super.trackRadius,
    super.trackVisibility,
    super.minOverscrollLength,
    super.minThumbLength,
    super.padding,
    super.pressDuration,
    super.trackColor,
    super.notificationPredicate,
  });

  @override
  RawScrollbarState<RawScrollbar> createState() => _CustomScrollbarState();
}

class _CustomScrollbarState extends RawScrollbarState<CustomScrollbar> {
  late final AnimationController _expansionController;
  late final CurvedAnimation _expansionCurve;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(updateScrollbarPainter);
    _expansionCurve = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeOutCubic,
    );
    widget.lineNumberNotifier.addListener(_onLineNumberChanged);
  }

  @override
  void dispose() {
    _expansionCurve.dispose();
    _expansionController.dispose();
    widget.lineNumberNotifier.removeListener(_onLineNumberChanged);
    super.dispose();
  }

  void _onLineNumberChanged() {
    if (!widget.showLineNumberIndicator) return;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    setState(() => _isDragging = true);
    _expansionController.forward();
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    setState(() => _isDragging = false);
    _expansionController.reverse();
  }

  @override
  void updateScrollbarPainter() {
    final t = _expansionCurve.value;
    final baseThickness = widget.thickness ?? 6.0;
    final activeThickness = math.max(baseThickness * 1.8, 12.0);
    final currentThickness =
        ui.lerpDouble(baseThickness, activeThickness, t) ?? baseThickness;

    final baseColor = widget.thumbColor ?? Colors.grey.withAlpha(100);
    final currentColor = Color.lerp(
          baseColor.withValues(alpha: (baseColor.a * 0.75).clamp(0.0, 1.0)),
          baseColor.withValues(alpha: math.min(1.0, baseColor.a * 1.4)),
          t,
        ) ??
        baseColor;

    scrollbarPainter
      ..color = currentColor
      ..textDirection = Directionality.of(context)
      ..thickness = currentThickness
      ..shape = _CustomThumbBorder(
        isDragging: _isDragging || t > 0.05,
        dragProgress: t,
        showLineNumberIndicator: widget.showLineNumberIndicator,
        color: currentColor,
        lineNumber: widget.lineNumberNotifier.value,
        lineNumberStyle: widget.lineNumberStyle,
        borderRadius: widget.borderRadius == BorderRadius.zero
            ? BorderRadius.circular(currentThickness / 2)
            : widget.borderRadius,
        textDirection: widget.textDirection,
        thickness: currentThickness,
      );
  }
}

class _CustomThumbBorder extends RoundedRectangleBorder {
  final bool isDragging, showLineNumberIndicator;
  final double dragProgress;
  final Color color;
  final int lineNumber;
  final TextStyle lineNumberStyle;
  final TextDirection textDirection;
  final double thickness;

  final TextPainter? _lineNumberPainter;

  _CustomThumbBorder({
    required this.isDragging,
    this.dragProgress = 1.0,
    required this.color,
    required this.lineNumber,
    required this.lineNumberStyle,
    required this.showLineNumberIndicator,
    required this.textDirection,
    required this.thickness,
    required super.borderRadius,
  })  : _lineNumberPainter = showLineNumberIndicator
            ? (TextPainter(
                text: TextSpan(
                  text: lineNumber.toString(),
                  style: lineNumberStyle,
                ),
              )
                ..textDirection = textDirection
                ..layout())
            : null,
        super(side: BorderSide.none);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (!showLineNumberIndicator || _lineNumberPainter == null || !isDragging) {
      return;
    }
    final painter = _lineNumberPainter;
    final opacity = dragProgress.clamp(0.0, 1.0);
    if (opacity <= 0.01) return;

    final double bubbleWidth = math.max(painter.width + 20.0, 42.0);
    final double bubbleHeight = painter.height + 10.0;

    final isLtr = this.textDirection == TextDirection.ltr;
    final bubbleOffset = 12.0;
    final bubbleLeft = isLtr
        ? rect.left - bubbleWidth - bubbleOffset
        : rect.right + bubbleOffset;
    final bubbleTop = (rect.center.dy - bubbleHeight / 2);

    final bubbleRect = Rect.fromLTWH(
      bubbleLeft,
      bubbleTop,
      bubbleWidth,
      bubbleHeight,
    );
    final rrect = RRect.fromRectAndRadius(
      bubbleRect,
      Radius.circular(bubbleHeight / 2),
    );

    final bgPaint = Paint()
      ..color = color.withValues(alpha: (color.a * 0.95 * opacity).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.18 * opacity).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(rrect, borderPaint);

    canvas.saveLayer(
      bubbleRect,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    painter.paint(
      canvas,
      Offset(
        bubbleRect.left + (bubbleRect.width - painter.width) / 2,
        bubbleRect.top + (bubbleRect.height - painter.height) / 2,
      ),
    );
    canvas.restore();
  }

  @override
  bool operator ==(Object other) {
    return other is _CustomThumbBorder &&
        other.isDragging == isDragging &&
        other.dragProgress == dragProgress &&
        other.showLineNumberIndicator == showLineNumberIndicator &&
        other.color == color &&
        other.lineNumber == lineNumber &&
        other.lineNumberStyle == lineNumberStyle &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(
    isDragging,
    dragProgress,
    showLineNumberIndicator,
    color,
    lineNumber,
    lineNumberStyle,
    borderRadius,
  );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));

  @override
  ShapeBorder scale(double t) => this;
}
