import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

const _rowGap = 8.0;
const _rowSpacing = 4.0;
const _pillInset = 8.0;
const _rowGlyphSize = 18.0;
const _headerGlyphGap = 8.0;
const _selectDuration = Duration(milliseconds: 320);
const _selectCurve = Curves.easeInOutCubic;

class OutboundMode extends StatelessWidget {
  const OutboundMode({super.key});

  @override
  Widget build(BuildContext context) {
    final height = getWidgetHeight(2);
    final inset = baseInfoEdgeInsets.left;
    final pillInset = min(_pillInset.ap, inset);
    return SizedBox(
      height: height,
      child: Consumer(
        builder: (_, ref, _) {
          final mode = ref.watch(
            patchClashConfigProvider.select((state) => state.mode),
          );
          return Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: CommonCard(
              padding: EdgeInsets.zero,
              // No-op press: only for the shared hover / press feedback.
              onPressed: () {},
              info: Info(
                label: appLocalizations.outboundMode,
                icon: RotatedBox(
                  quarterTurns: 2,
                  child: Icon(
                    FluentIcons.arrow_split_24_regular,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: _rowGap.ap, bottom: pillInset),
                child: _ModeRows(
                  mode: mode,
                  inset: inset,
                  pillInset: pillInset,
                  onSelect: (item) {
                    globalState.appController.changeMode(item);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeRows extends StatelessWidget {
  const _ModeRows({
    required this.mode,
    required this.inset,
    required this.pillInset,
    required this.onSelect,
  });

  final Mode mode;
  final double inset;
  final double pillInset;
  final void Function(Mode mode) onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final count = Mode.values.length;
        final spacing = _rowSpacing.ap;
        final rowHeight = max(
          (constraints.maxHeight - spacing * (count - 1)) / count,
          0.0,
        );
        final contentInset = inset - pillInset;
        final innerRadius = max(
          min(20.0 - pillInset, rowHeight / 3),
          0.0,
        );
        final shape = SuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(innerRadius)),
        );
        final glyphWidth = IconTheme.of(context).size ?? 20.0;
        final colors = [
          for (final item in Mode.values) _ModeColors.of(context, item),
        ];
        return TweenAnimationBuilder<double>(
          tween: Tween(end: Mode.values.indexOf(mode).toDouble()),
          duration: _selectDuration,
          curve: _selectCurve,
          builder: (context, position, _) {
            final from = position.floor().clamp(0, count - 1);
            final to = position.ceil().clamp(0, count - 1);
            final highlight = _ModeColors.lerp(
              colors[from],
              colors[to],
              position - from,
            );
            return Stack(
              children: [
                Positioned(
                  key: const ValueKey('outbound-mode-highlight'),
                  left: pillInset,
                  right: pillInset,
                  top: position * (rowHeight + spacing),
                  height: rowHeight,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: highlight.container,
                      shape: shape,
                    ),
                  ),
                ),
                for (final (index, item) in Mode.values.indexed)
                  Positioned(
                    left: pillInset,
                    right: pillInset,
                    top: index * (rowHeight + spacing),
                    height: rowHeight,
                    child: _ModeRow(
                      title: Intl.message(item.name),
                      icon: _getModeIcon(item),
                      glyphAngle: _getModeGlyphAngle(item),
                      selected: item == mode,
                      foreground: Color.lerp(
                        context.colorScheme.onSurfaceVariant,
                        colors[index].onContainer,
                        (1 - (index - position).abs()).clamp(0.0, 1.0),
                      )!,
                      contentInset: contentInset,
                      glyphWidth: glyphWidth,
                      shape: shape,
                      onTap: () {
                        onSelect(item);
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

IconData _getModeIcon(Mode mode) {
  return switch (mode) {
    Mode.rule => FluentIcons.zoom_fit_24_regular,
    Mode.global => FluentIcons.hexagon_three_24_regular,
    Mode.direct => FluentIcons.cd_16_regular,
  };
}

double _getModeGlyphAngle(Mode mode) {
  return switch (mode) {
    Mode.rule => pi / 4,
    Mode.global => 3 * pi / 2,
    Mode.direct => 0.0,
  };
}

class _ModeColors {
  const _ModeColors(this.container, this.onContainer);

  factory _ModeColors.of(BuildContext context, Mode mode) {
    final colorScheme = context.colorScheme;
    return switch (mode) {
      Mode.rule => _ModeColors(
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
      Mode.global => _ModeColors(
        globalState.theme.darken3PrimaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      Mode.direct => _ModeColors(
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
    };
  }

  factory _ModeColors.lerp(_ModeColors a, _ModeColors b, double t) {
    return _ModeColors(
      Color.lerp(a.container, b.container, t)!,
      Color.lerp(a.onContainer, b.onContainer, t)!,
    );
  }

  final Color container;
  final Color onContainer;
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.title,
    required this.icon,
    required this.glyphAngle,
    required this.selected,
    required this.foreground,
    required this.contentInset,
    required this.glyphWidth,
    required this.shape,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final double glyphAngle;
  final bool selected;
  final Color foreground;
  final double contentInset;
  final double glyphWidth;
  final ShapeBorder shape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Focus(
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return InkWell(
              customBorder: shape,
              onTap: onTap,
              child: Container(
                decoration: isFocused && globalState.isAndroidTV
                    ? ShapeDecoration(
                        color: context.colorScheme.primary.withValues(alpha: 0.15),
                        shape: shape,
                      )
                    : null,
                padding: EdgeInsets.symmetric(horizontal: contentInset),
                child: Row(
                  children: [
                    SizedBox(
                      width: glyphWidth,
                      child: Center(
                        child: Transform.rotate(
                          angle: glyphAngle,
                          child: Icon(
                            icon,
                            size: _rowGlyphSize,
                            color: foreground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _headerGlyphGap),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: foreground,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

///

class OutboundModeV2 extends StatelessWidget {
  const OutboundModeV2({super.key});
  Color _getTextColor(BuildContext context, Mode mode) {
    return switch (mode) {
      Mode.rule => context.colorScheme.onSecondaryContainer,
      Mode.global => context.colorScheme.onPrimaryContainer,
      Mode.direct => context.colorScheme.onTertiaryContainer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final height = getWidgetHeight(0.72);
    return SizedBox(
      height: height,
      child: CommonCard(
        padding: EdgeInsets.zero,
        // No-op press: only for the shared hover / press feedback.
        onPressed: () {},
        child: Consumer(
          builder: (_, ref, _) {
            final mode = ref.watch(
              patchClashConfigProvider.select((state) => state.mode),
            );
            final thumbColor = switch (mode) {
              Mode.rule => context.colorScheme.secondaryContainer,
              Mode.global => globalState.theme.darken3PrimaryContainer,
              Mode.direct => context.colorScheme.tertiaryContainer,
            };
            if (globalState.isAndroidTV) {
              return Container(
                constraints: const BoxConstraints.expand(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    for (final item in Mode.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Focus(
                            child: Builder(
                              builder: (context) {
                                final isFocused = Focus.of(context).hasFocus;
                                final isSelected = item == mode;
                                return InkWell(
                                  customBorder: SuperellipseBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  onTap: () {
                                    globalState.appController.changeMode(item);
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    height: height - 18,
                                    decoration: ShapeDecoration(
                                      color: isSelected
                                          ? thumbColor
                                          : (isFocused
                                              ? context.colorScheme.primary
                                                  .withValues(alpha: 0.12)
                                              : Colors.transparent),
                                      shape: SuperellipseBorder(
                                        borderRadius: BorderRadius.circular(13),
                                        side: isFocused
                                            ? BorderSide(
                                                color:
                                                    context.colorScheme.primary,
                                                width: 2,
                                              )
                                            : BorderSide.none,
                                      ),
                                    ),
                                    child: Text(
                                      Intl.message(item.name),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.adjustSize(1)
                                          .copyWith(
                                            color: isSelected
                                                ? _getTextColor(context, item)
                                                : null,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : null,
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
            return Container(
              constraints: const BoxConstraints.expand(),
              child: CommonTabBar<Mode>(
                children: Map.fromEntries(
                  Mode.values.map(
                    (item) => MapEntry(
                      item,
                      Container(
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(),
                        height: height - 18,
                        child: Text(
                          Intl.message(item.name),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.adjustSize(1)
                              .copyWith(
                                color: item == mode
                                    ? _getTextColor(context, item)
                                    : null,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                thumbRadius: const Radius.circular(14),
                groupValue: mode,
                onValueChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  globalState.appController.changeMode(value);
                },
                thumbColor: thumbColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
