import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/views/access.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// 首页仪表盘「访问控制」小部件（仅 Android 平台提供）
///
/// 排版与「亮屏锁 / DNS 覆写 / 脚本覆写」等小部件完全一致：
/// 左上角为「访问控制」标题与功能图标（`FluentIcons.shield_checkmark_24_regular`，与
/// 更多页面「访问控制」入口一致），左下角文案为「开关」，右侧为开关按钮。
///
/// 开关直接对应 `VpnProps.accessControl.enable`，与「访问控制」页面里的
/// 开关共用同一份状态，两处操作实时同步。
class AccessControlSwitch extends ConsumerWidget {
  const AccessControlSwitch({super.key});

  Future<void> _openAccessControl(BuildContext context) async {
    await showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: appLocalizations.appAccessControl,
          body: const AccessView(),
          showScrollGradient: false,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      vpnSettingProvider.select((state) => state.accessControl.enable),
    );

    return RepaintBoundary(
      child: SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          info: Info(
            // 卡片标题用短标题键（英文只写 Access）；「更多」页入口与
            // 应用访问控制页面标题仍用 accessControl / appAccessControl
            label: appLocalizations.accessControlShort,
            iconData: FluentIcons.shield_checkmark_24_regular,
          ),
          onPressed: () {
            _openAccessControl(context);
          },
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 1,
                  child: TooltipText(
                    text: Text(
                      appLocalizations.switchLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.adjustSize(-2).toLight,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -3),
                  child: Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: enabled,
                    onChanged: (value) {
                      ref
                          .read(vpnSettingProvider.notifier)
                          .updateState(
                            (state) =>
                                state.copyWith.accessControl(enable: value),
                          );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
