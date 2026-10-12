import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/views/access.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

///
///
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
                      enabled
                          ? appLocalizations.enabled
                          : appLocalizations.disabled,
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
