import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/widgets/animated_nav_icon.dart';
import 'package:bett_box/widgets/sidebar_toggle_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _compactWidth = 48.0;
const _itemSize = 40.0;
const _itemGap = 4.0;
const _toggleGap = 8.0;
const _verticalInset = 4.0;
const _maxSideInset = 12.0;
const _iconSize = 24.0;
const _labelGap = 12.0;
const _indicatorWidth = 3.0;
const _indicatorHeight = 16.0;
const _expandDuration = Duration(milliseconds: 250);
const _indicatorDuration = Duration(milliseconds: 320);

final _itemShape = const RoundedSuperellipseBorder(
  borderRadius: BorderRadius.all(Radius.circular(10)),
);

class NavigationSidebar extends StatelessWidget {
  const NavigationSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.expanded,
    required this.onSelected,
    this.onToggle,
    this.windowControls = Size.zero,
  });

  final List<NavigationItem> destinations;
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelected;
  final VoidCallback? onToggle;
  final Size windowControls;

  double _calculateExpandedWidth(BuildContext context) {
    final labelStyle =
        context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    final textScaler = MediaQuery.textScalerOf(context);
    double maxTextWidth = 0.0;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    for (final item in destinations) {
      final text = item.label.localizedName;
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: direction,
        maxLines: 1,
        textScaler: textScaler,
      )..layout();
      if (textPainter.width > maxTextWidth) {
        maxTextWidth = textPainter.width;
      }
      textPainter.dispose();
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final rawCompactWidth = math.max(_compactWidth, windowControls.width);
    final compactWidth = (rawCompactWidth * dpr).ceil() / dpr;
    final sideInset = math.min(_maxSideInset, (compactWidth - _itemSize) / 2);
    final iconInset = (compactWidth - sideInset * 2 - _iconSize) / 2;
    final total =
        sideInset * 2 + iconInset + _iconSize + _labelGap * 2 + maxTextWidth;
    final clamped = math.max(123.0, math.min(240.0, total));
    return (clamped * dpr).ceil() / dpr;
  }

  @override
  Widget build(BuildContext context) {
    final expandedWidth = _calculateExpandedWidth(context);

    return SafeArea(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: expanded ? 1.0 : 0.0),
        duration: _expandDuration,
        curve: Curves.easeInOutCubic,
        builder: (context, progress, _) => _SidebarPane(
          progress: progress,
          windowControls: windowControls,
          expandedWidth: expandedWidth,
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
          onToggle: onToggle ?? () {},
        ),
      ),
    );
  }
}

class _SidebarColors {
  _SidebarColors(ColorScheme scheme)
    : selectedFill = scheme.onSurface.withValues(alpha: 0.08),
      selectedHoverFill = scheme.onSurface.withValues(alpha: 0.12),
      pressedFill = scheme.onSurface.withValues(alpha: 0.08),
      hoverFill = scheme.onSurface.withValues(alpha: 0.06),
      icon = scheme.onSurfaceVariant,
      selectedIcon = scheme.primary,
      indicator = scheme.primary;

  final Color selectedFill;
  final Color selectedHoverFill;
  final Color pressedFill;
  final Color hoverFill;
  final Color icon;
  final Color selectedIcon;
  final Color indicator;
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane({
    required this.progress,
    required this.windowControls,
    required this.expandedWidth,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onToggle,
  });

  final double progress;
  final Size windowControls;
  final double expandedWidth;
  final List<NavigationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = _SidebarColors(context.colorScheme);
    final fontSize = context.textTheme.bodyMedium?.fontSize ?? 14;
    final labelOpacity = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final rawCompactWidth = math.max(_compactWidth, windowControls.width);
    final compactWidth = (rawCompactWidth * dpr).ceil() / dpr;
    final sideInset = math.min(_maxSideInset, (compactWidth - _itemSize) / 2);
    final itemWidth = compactWidth - sideInset * 2;
    final iconInset = (itemWidth - _iconSize) / 2;
    final itemHeight =
        _itemSize + MediaQuery.textScalerOf(context).scale(fontSize) - fontSize;
    final rowWidth = expandedWidth - sideInset * 2;
    final labelStyle = context.textTheme.bodyMedium;

    return SizedBox(
      width: lerpDouble(compactWidth, expandedWidth, progress),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: windowControls.height + _verticalInset),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _SidebarButton(
              colors: colors,
              height: itemHeight,
              sideInset: sideInset,
              onTap: onToggle,
              child: SizedBox(
                width: itemWidth,
                child: Center(
                  child: SidebarToggleIcon(
                    progress: progress,
                    size: _iconSize,
                    color: colors.icon,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _toggleGap),
          Expanded(
            child: ScrollConfiguration(
              behavior: const HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, item) in destinations.indexed)
                          _SidebarButton(
                            key: ValueKey(item.label),
                            colors: colors,
                            height: itemHeight,
                            sideInset: sideInset,
                            selected: index == selectedIndex,
                            onTap: () => onSelected(index),
                            child: _DestinationRow(
                              item: item,
                              selected: index == selectedIndex,
                              width: rowWidth,
                              iconInset: iconInset,
                              style: labelStyle,
                              labelOpacity: labelOpacity,
                              iconColor: index == selectedIndex
                                  ? colors.selectedIcon
                                  : colors.icon,
                            ),
                          ),
                      ],
                    ),
                    if (selectedIndex < destinations.length)
                      _SelectionIndicator(
                        color: colors.indicator,
                        index: selectedIndex,
                        start: sideInset,
                        stride: itemHeight + _itemGap,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: _verticalInset),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatefulWidget {
  const _SidebarButton({
    super.key,
    required this.colors,
    required this.height,
    required this.sideInset,
    required this.onTap,
    required this.child,
    this.selected,
  });

  final _SidebarColors colors;
  final double height;
  final double sideInset;
  final bool? selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<_SidebarButton> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _fill {
    final colors = widget.colors;
    if (widget.selected == true) {
      return _hovered ? colors.selectedHoverFill : colors.selectedFill;
    }
    if (_pressed) {
      return colors.pressedFill;
    }
    if (_hovered) {
      return colors.hoverFill;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.sideInset,
        vertical: _itemGap / 2,
      ),
      child: Semantics(
        container: true,
        button: true,
        selected: widget.selected,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: DecoratedBox(
              decoration: ShapeDecoration(color: _fill, shape: _itemShape),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: _iconSize,
                  color: widget.colors.icon,
                ),
                child: SizedBox(height: widget.height, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.item,
    required this.selected,
    required this.width,
    required this.iconInset,
    required this.style,
    required this.labelOpacity,
    required this.iconColor,
  });

  final NavigationItem item;
  final bool selected;
  final double width;
  final double iconInset;
  final TextStyle? style;
  final double labelOpacity;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style?.copyWith(
      color: iconColor,
      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
    );

    return ClipRect(
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minWidth: width,
        maxWidth: width,
        child: Row(
          children: [
            SizedBox(width: iconInset),
            AnimatedNavIcon(
              label: item.label,
              selected: selected,
              color: iconColor,
            ),
            const SizedBox(width: _labelGap),
            Expanded(
              child: Opacity(
                opacity: labelOpacity,
                alwaysIncludeSemantics: true,
                child: Text(
                  item.label.localizedName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: effectiveStyle,
                ),
              ),
            ),
            const SizedBox(width: _labelGap),
          ],
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatefulWidget {
  const _SelectionIndicator({
    required this.color,
    required this.index,
    required this.start,
    required this.stride,
  });

  final Color color;
  final int index;
  final double start;
  final double stride;

  @override
  State<_SelectionIndicator> createState() => _SelectionIndicatorState();
}

class _SelectionIndicatorState extends State<_SelectionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _indicatorDuration,
    value: 1,
  );
  late int _from = widget.index;

  @override
  void didUpdateWidget(covariant _SelectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _from = oldWidget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _topOf(int index) =>
      index * widget.stride + (widget.stride - _indicatorHeight) / 2;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final from = _topOf(_from);
        final to = _topOf(widget.index);
        final lead = Curves.easeOutCubic.transform(math.min(1, t / 0.6));
        final trail = Curves.easeInOutCubic.transform(
          math.max(0, (t - 0.35) / 0.65),
        );
        final (top, bottom) = to >= from
            ? (lerpDouble(from, to, trail)!, lerpDouble(from, to, lead)!)
            : (lerpDouble(from, to, lead)!, lerpDouble(from, to, trail)!);
        return PositionedDirectional(
          start: widget.start,
          top: top,
          width: _indicatorWidth,
          height: bottom - top + _indicatorHeight,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: widget.color,
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }
}
