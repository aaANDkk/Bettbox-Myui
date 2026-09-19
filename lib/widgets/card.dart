import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/widgets/fade_box.dart';
import 'package:flutter/material.dart';

import 'text.dart';

class Info {
  final String label;
  final IconData? iconData;
  final Widget? icon;
  final TextStyle? style;

  const Info({
    required this.label,
    this.iconData,
    this.icon,
    this.style,
  });
}

class InfoHeader extends StatelessWidget {
  final Info info;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;

  /// 右侧操作区（actions）的高度上限。卡片表头传「一行标题」高
  /// （`globalState.measure.titleSmallHeight`）后，按钮不再撑高整行，
  /// 图标 / 标题 / 按钮落在同一条线上；不传则完全沿用按钮自身尺寸。
  final double? actionsHeight;

  const InfoHeader({
    super.key,
    required this.info,
    this.padding,
    this.actionsHeight,
    List<Widget>? actions,
  }) : actions = actions ?? const [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? baseInfoEdgeInsets,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (info.icon != null) ...[
                  info.icon!,
                  const SizedBox(width: 8),
                ] else if (info.iconData != null) ...[
                  Icon(
                    info.iconData,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  flex: 1,
                  child: TooltipText(
                    text: EmojiText(
                      info.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (info.style ?? Theme.of(context).textTheme.titleSmall)
                              ?.copyWith(
                                color:
                                    info.style?.color ??
                                    context.colorScheme.onSurfaceVariant,
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: actionsHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [...actions],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SmoothRoundedRectangleBorder extends RoundedRectangleBorder {
  const SmoothRoundedRectangleBorder({
    super.side,
    super.borderRadius = BorderRadius.zero,
  });

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    switch (side.style) {
      case BorderStyle.none:
        break;
      case BorderStyle.solid:
        final borderRect = borderRadius.resolve(textDirection).toRRect(rect);
        if (side.width <= 0.0) {
          canvas.drawRRect(borderRect, side.toPaint());
        } else {
          final strokeRect = borderRect.deflate(side.width / 2.0);
          final paint = side.toPaint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = side.width
            ..isAntiAlias = true;
          canvas.drawRRect(strokeRect, paint);
        }
    }
  }

  @override
  SmoothRoundedRectangleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) {
    return SmoothRoundedRectangleBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}

class CommonCard extends StatelessWidget {
  const CommonCard({
    super.key,
    bool? isSelected,
    this.type = CommonCardType.plain,
    this.onPressed,
    this.onLongPress,
    this.selectWidget,
    this.radius,
    required this.child,
    this.padding,
    this.enterAnimated = false,
    this.info,
    this.actions,
  }) : isSelected = isSelected ?? false;

  final bool enterAnimated;
  final bool isSelected;
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final Widget? selectWidget;
  final Widget child;
  final EdgeInsets? padding;
  final Info? info;
  final List<Widget>? actions;
  final CommonCardType type;
  final double? radius;

  // final WidgetStateProperty<Color?>? backgroundColor;
  // final WidgetStateProperty<BorderSide?>? borderSide;

  BorderSide getBorderSide(BuildContext context, Set<WidgetState> states) {
    final colorScheme = context.colorScheme;
    if (type == CommonCardType.filled) {
      return BorderSide.none;
    }
    final hoverColor = isSelected
        ? colorScheme.primary.opacity80
        : colorScheme.primary.opacity60;
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed)) {
      return BorderSide(color: hoverColor);
    }
    final isLight = colorScheme.brightness == Brightness.light;
    return BorderSide(
      color: isSelected
          ? colorScheme.primary
          : colorScheme.outlineVariant.withValues(
              alpha: isLight ? 0.45 : 0.25,
            ),
    );
  }

  Color? getBackgroundColor(BuildContext context, Set<WidgetState> states) {
    final colorScheme = context.colorScheme;
    if (type == CommonCardType.filled) {
      if (isSelected) {
        return colorScheme.secondaryContainer.opacity80;
      }
      return colorScheme.surfaceContainer;
    }
    if (isSelected) {
      return colorScheme.secondaryContainer;
    }
    return colorScheme.surfaceContainerLow;
  }

  @override
  Widget build(BuildContext context) {
    final actualRadius = radius ?? 20.0;
    var childWidget = child;

    if (info != null) {
      childWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoHeader(
            padding: baseInfoEdgeInsets.copyWith(bottom: 0),
            info: info!,
            actions: actions,
          ),
          Flexible(flex: 1, child: child),
        ],
      );
    }

    if (selectWidget != null && isSelected) {
      final List<Widget> children = [];
      children.add(childWidget);
      children.add(Positioned.fill(child: selectWidget!));
      childWidget = Stack(children: children);
    }

    final isInteractive = onPressed != null || onLongPress != null;
    final card = OutlinedButton(
      onLongPress: onLongPress,
      clipBehavior: Clip.antiAlias,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(actualRadius),
          ),
        ),
        iconColor: WidgetStatePropertyAll(context.colorScheme.primary),
        iconSize: WidgetStateProperty.all(20),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => getBackgroundColor(context, states),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => getBorderSide(context, states),
        ),
        minimumSize: WidgetStatePropertyAll(isInteractive ? null : Size.zero),
        tapTargetSize: isInteractive ? null : MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: childWidget,
    );

    return switch (enterAnimated) {
      true => FadeScaleEnterBox(child: card),
      false => card,
    };
  }
}

/// 选中标记：色块上的勾选徽标（第 40 节曾试过换成圆环+实心点，
/// 但在彩色色块上看不清，按需求还原为勾选徽标）。
class SelectIcon extends StatelessWidget {
  const SelectIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.inversePrimary,
      shape: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: const Icon(Icons.check_rounded, size: 16),
      ),
    );
  }
}

/// 「选中 / 未选中」圆形单选指示图标（出站模式部件与各处选项弹窗共用）。
///
/// 用于**选中一次即结束**的单选场合（选项弹窗、单选行、只取一个值的显示设置弹窗）；
/// **可多选**的场合用 [OptionCheckIcon]（方块勾选），见定制规范第 7 节。
class OptionRadioIcon extends StatelessWidget {
  final bool selected;

  /// 外框边长（默认 21；圆环与实心点按比例缩放）
  final double size;

  const OptionRadioIcon({super.key, required this.selected, this.size = 21});

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final idle = context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: size - 2,
          height: size - 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? primary : idle, width: 2),
          ),
          child: selected
              ? Container(
                  width: size * 9 / 21,
                  height: size * 9 / 21,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// 「选中 / 未选中」方块勾选指示图标（**可多选**的场合使用）。
///
/// 与 [OptionRadioIcon] 成对，构成全站选项指示的两套体系（定制规范第 7 节）：
/// - **选中一次即结束**的单选 → 圆形 [OptionRadioIcon]（出站模式同款）；
/// - **可多选**（访问控制列表、连通性测试置顶平台等）→ 本组件（Bettbox 原本的方块勾选）。
///
/// 用 `shrinkWrap` 去掉 Checkbox 自带 48×48 的隐形点击区（整行本身就可点），
/// 并固定 `standard` 视觉密度，避免桌面端被主题压成迷你方块。
class OptionCheckIcon extends StatelessWidget {
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  const OptionCheckIcon({super.key, required this.selected, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: selected,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }
}

class SettingsBlock extends StatelessWidget {
  final String title;
  final List<Widget> settings;

  const SettingsBlock({super.key, required this.title, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        children: [
          InfoHeader(info: Info(label: title)),
          Card(
            color: context.colorScheme.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            child: Column(children: settings),
          ),
        ],
      ),
    );
  }
}
