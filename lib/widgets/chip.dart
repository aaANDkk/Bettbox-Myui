import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxParentData, RenderShiftedBox;

import 'text.dart';

/// Inline capsule for card subtitles (expiry date, 本地文件…), matching FlClash's
/// ExpireChip: a 15% theme tint, h8/v2 padding and a full superellipse.
class CommonInfoCapsule extends StatelessWidget {
  final String label;
  final Widget? leading;
  final TextStyle? style;
  final Color? color;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const CommonInfoCapsule(
    this.label, {
    super.key,
    this.leading,
    this.style,
    this.color,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.colorScheme.primary;
    final effectiveStyle = (style ?? context.textTheme.labelMedium)?.copyWith(
      color: effectiveColor,
    );
    final locale = Localizations.maybeLocaleOf(context);
    final isAlphabetic = const {'en', 'ru'}.contains(locale?.languageCode);
    final textShift = isAlphabetic ? 0.0 : 1.0;

    final textWidget = _CapCentered(
      fontSize: effectiveStyle?.fontSize ?? 12,
      child: EmojiText(
        label,
        style: effectiveStyle,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final shiftedText = textShift == 0.0
        ? textWidget
        : Transform.translate(
            offset: Offset(textShift, 0),
            child: textWidget,
          );

    final content = leading == null
        ? shiftedText
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading!,
              const SizedBox(width: 5),
              shiftedText,
            ],
          );

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: backgroundColor ?? effectiveColor.withValues(alpha: 0.15),
        shape: SuperellipseBorder(borderRadius: BorderRadius.circular(1000)),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: content,
      ),
    );
  }
}

/// Centers a line's cap height instead of its line box: a font's ascent
/// outweighs its descent, so a line-box centered text sits low.
class _CapCentered extends SingleChildRenderObjectWidget {
  static const _capHeightPerEm = 0.7;

  final double fontSize;

  const _CapCentered({required this.fontSize, required super.child});

  double _capHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(fontSize) * _capHeightPerEm;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCapCentered(_capHeight(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCapCentered renderObject,
  ) {
    renderObject.capHeight = _capHeight(context);
  }
}

class _RenderCapCentered extends RenderShiftedBox {
  _RenderCapCentered(this._capHeight) : super(null);

  double _capHeight;

  set capHeight(double value) {
    if (_capHeight == value) {
      return;
    }
    _capHeight = value;
    markNeedsLayout();
  }

  double _shift(Size size, double alphabeticBaseline) =>
      (size.height + _capHeight) / 2 - alphabeticBaseline;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      child?.getDryLayout(constraints) ?? constraints.smallest;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) {
      return null;
    }
    final alphabetic = child.getDryBaseline(
      constraints,
      TextBaseline.alphabetic,
    );
    final result = child.getDryBaseline(constraints, baseline);
    if (alphabetic == null || result == null) {
      return null;
    }
    return result + _shift(child.getDryLayout(constraints), alphabetic);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = child.size;
    final baseline = child.getDistanceToBaseline(TextBaseline.alphabetic);
    if (baseline == null) {
      return;
    }
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      _shift(size, baseline),
    );
  }
}

class CommonChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ChipType type;
  final Widget? avatar;
  final TextStyle? labelStyle;

  const CommonChip({
    super.key,
    required this.label,
    this.labelStyle,
    this.onPressed,
    this.avatar,
    this.type = ChipType.action,
  });

  @override
  Widget build(BuildContext context) {
    final focusedBorder = WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(
          color: context.colorScheme.primary,
          width: 2,
        );
      }
      return null;
    });
    final focusedColor = WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return context.colorScheme.primary.withValues(alpha: 0.2);
      }
      return null;
    });

    if (type == ChipType.delete) {
      return Chip(
        avatar: avatar,
        side: focusedBorder,
        color: focusedColor,
        labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
        clipBehavior: Clip.antiAlias,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onDeleted: onPressed ?? () {},
        labelStyle: labelStyle,
        label: EmojiText(label),
      );
    }
    return ActionChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: avatar,
      side: focusedBorder,
      color: focusedColor,
      clipBehavior: Clip.antiAlias,
      labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
      onPressed: onPressed ?? () {},
      labelStyle: labelStyle,
      label: EmojiText(label),
    );
  }
}
