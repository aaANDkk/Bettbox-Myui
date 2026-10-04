import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class SliverStickyHeader extends MultiChildRenderObjectWidget {
  SliverStickyHeader({
    super.key,
    required Widget header,
    required Widget sliver,
    this.spacing = 0.0,
    this.pinned = true,
  }) : super(children: [header, sliver]);

  final double spacing;
  final bool pinned;

  @override
  RenderSliverStickyHeader createRenderObject(BuildContext context) {
    return RenderSliverStickyHeader(spacing: spacing, pinned: pinned);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverStickyHeader renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..pinned = pinned;
  }
}

class SliverStickyHeaderParentData extends ParentData
    with ContainerParentDataMixin<RenderObject> {
  Offset paintOffset = Offset.zero;
}

class RenderSliverStickyHeader extends RenderSliver
    with
        ContainerRenderObjectMixin<RenderObject, SliverStickyHeaderParentData>,
        RenderSliverHelpers {
  RenderSliverStickyHeader({double spacing = 0.0, bool pinned = true})
    : _spacing = spacing,
      _pinned = pinned;

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  bool _pinned;
  bool get pinned => _pinned;
  set pinned(bool value) {
    if (_pinned == value) return;
    _pinned = value;
    markNeedsLayout();
  }

  RenderBox get header => firstChild! as RenderBox;
  RenderSliver get content => lastChild! as RenderSliver;

  double _headerExtent = 0.0;
  double _headerOffset = 0.0;

  double get _beforeExtent => _headerExtent + _spacing;

  double get _headerPaintOffset => _headerOffset - constraints.scrollOffset;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverStickyHeaderParentData) {
      child.parentData = SliverStickyHeaderParentData();
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    assert(constraints.axis == Axis.vertical);

    header.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    _headerExtent = header.size.height;
    final beforeExtent = _beforeExtent;

    content.layout(
      constraints.copyWith(
        scrollOffset: math.max(0.0, constraints.scrollOffset - beforeExtent),
        cacheOrigin: math.min(0.0, constraints.cacheOrigin + beforeExtent),
        overlap: 0.0,
        remainingPaintExtent:
            constraints.remainingPaintExtent -
            calculatePaintOffset(constraints, from: 0.0, to: beforeExtent),
        remainingCacheExtent:
            constraints.remainingCacheExtent -
            calculateCacheOffset(constraints, from: 0.0, to: beforeExtent),
        precedingScrollExtent:
            constraints.precedingScrollExtent + beforeExtent,
      ),
      parentUsesSize: true,
    );
    final childGeometry = content.geometry!;
    if (childGeometry.scrollOffsetCorrection != null) {
      geometry = SliverGeometry(
        scrollOffsetCorrection: childGeometry.scrollOffsetCorrection,
      );
      return;
    }

    final scrollExtent = beforeExtent + childGeometry.scrollExtent;
    final beforePaintExtent = calculatePaintOffset(
      constraints,
      from: 0.0,
      to: beforeExtent,
    );
    final paintExtent = math.min(
      beforePaintExtent +
          math.max(childGeometry.paintExtent, childGeometry.layoutExtent),
      constraints.remainingPaintExtent,
    );
    geometry = SliverGeometry(
      paintOrigin: childGeometry.paintOrigin,
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      layoutExtent: math.min(
        beforePaintExtent + childGeometry.layoutExtent,
        paintExtent,
      ),
      cacheExtent: math.min(
        calculateCacheOffset(constraints, from: 0.0, to: beforeExtent) +
            childGeometry.cacheExtent,
        constraints.remainingCacheExtent,
      ),
      maxPaintExtent: beforeExtent + childGeometry.maxPaintExtent,
      hitTestExtent: math.max(
        beforePaintExtent + childGeometry.paintExtent,
        beforePaintExtent + childGeometry.hitTestExtent,
      ),
      hasVisualOverflow: true,
    );

    _headerOffset = !_pinned
        ? 0.0
        : math.min(
            math.max(constraints.scrollOffset, 0.0),
            math.max(0.0, scrollExtent - _headerExtent - _spacing),
          );

    final contentParentData =
        content.parentData! as SliverStickyHeaderParentData;
    contentParentData.paintOffset = Offset(0.0, beforePaintExtent);
  }

  @override
  double childMainAxisPosition(RenderObject child) {
    if (child == header) return _headerPaintOffset;
    return calculatePaintOffset(constraints, from: 0.0, to: _beforeExtent);
  }

  @override
  double? childScrollOffset(RenderObject child) {
    if (child == header) return 0.0;
    return _beforeExtent;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    if (child == header) {
      applyPaintTransformForBoxChild(header, transform);
      return;
    }
    final childParentData = child.parentData! as SliverStickyHeaderParentData;
    transform.translateByDouble(
      childParentData.paintOffset.dx,
      childParentData.paintOffset.dy,
      0,
      1,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (geometry == null || !geometry!.visible) return;
    if (content.geometry!.visible) {
      final contentParentData =
          content.parentData! as SliverStickyHeaderParentData;
      context.pushClipRect(
        needsCompositing,
        offset,
        Rect.fromLTRB(
          0.0,
          _headerPaintOffset + _headerExtent,
          constraints.crossAxisExtent,
          geometry!.paintExtent,
        ),
        (context, offset) {
          context.paintChild(
            content,
            offset + contentParentData.paintOffset,
          );
        },
      );
    }
    context.paintChild(header, offset + Offset(0.0, _headerPaintOffset));
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    assert(geometry!.hitTestExtent > 0.0);
    final headerPaintOffset = _headerPaintOffset;
    if (mainAxisPosition >= headerPaintOffset &&
        mainAxisPosition < headerPaintOffset + _headerExtent) {
      return hitTestBoxChild(
        BoxHitTestResult.wrap(result),
        header,
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
      );
    }
    if (mainAxisPosition < headerPaintOffset + _headerExtent) {
      return false;
    }
    if (content.geometry!.hitTestExtent > 0.0) {
      final contentParentData =
          content.parentData! as SliverStickyHeaderParentData;
      return result.addWithAxisOffset(
        mainAxisPosition: mainAxisPosition,
        crossAxisPosition: crossAxisPosition,
        mainAxisOffset: childMainAxisPosition(content),
        crossAxisOffset: 0.0,
        paintOffset: contentParentData.paintOffset,
        hitTest: content.hitTest,
      );
    }
    return false;
  }
}
