import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class OutboundMode extends StatelessWidget {
  const OutboundMode({super.key});

  @override
  Widget build(BuildContext context) {
    final height = getWidgetHeight(2);
    return SizedBox(
      height: height,
      child: Consumer(
          builder: (_, ref, _) {
            final mode = ref.watch(
              patchClashConfigProvider.select((state) => state.mode),
            );
            return CommonCard(
              info: Info(
                label: appLocalizations.outboundMode,
                iconData: FluentIcons.arrow_split_24_regular,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final item in Mode.values)
                      Flexible(
                        fit: FlexFit.tight,
                        child: Material(
                          color: Colors.transparent,
                          child: Focus(
                            child: Builder(
                              builder: (context) {
                                final isFocused = Focus.of(context).hasFocus;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    globalState.appController.changeMode(item);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: isFocused && globalState.isAndroidTV
                                          ? context.colorScheme.primary
                                              .withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      border: isFocused && globalState.isAndroidTV
                                          ? Border.all(
                                              color: context.colorScheme.primary,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.ap,
                                      vertical: 8.ap,
                                    ),
                                    child: Row(
                                      children: [
                                        // FlClash 出站模式同款单选圆点（圆环 + 选中实心），
                                        // 占位与原来的 Icon 一致（21×21），不改动任何布局
                                        OptionRadioIcon(
                                          selected: item == mode,
                                        ),
                                        SizedBox(width: 12.ap),
                                        Expanded(
                                          child: Text(
                                            Intl.message(item.name),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.toSoftBold,
                                          ),
                                        ),
                                      ],
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
              ),
            );
          },
        ),
    );
  }
}

/// FlClash 出站模式左侧的单选圆点（圆环 + 选中时实心圆点）。
///
/// 外框 21×21，与原来 `Icon(size: 21)` 完全等大，因此不改变任何布局尺寸；
/// 圆环 2 宽、选中时中心 9×9 实心，视觉与 FlClash 的 Material Radio 一致。

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
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    globalState.appController.changeMode(item);
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    height: height - 18,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? thumbColor
                                          : (isFocused
                                              ? context.colorScheme.primary
                                                  .withValues(alpha: 0.12)
                                              : Colors.transparent),
                                      borderRadius: BorderRadius.circular(12),
                                      border: isFocused
                                          ? Border.all(
                                              color:
                                                  context.colorScheme.primary,
                                              width: 2,
                                            )
                                          : Border.all(
                                              color: Colors.transparent,
                                              width: 2,
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
                thumbRadius: const Radius.circular(13),
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
