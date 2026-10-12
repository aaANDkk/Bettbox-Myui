import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:bett_box/views/config/ntp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class NtpOverride extends ConsumerWidget {
  const NtpOverride({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(overrideNtpProvider);

    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(label: 'NTP', iconData: FluentIcons.access_time_24_regular),
        onPressed: () {
          // Open NTP settings
          showExtend(
            context,
            builder: (_, type) {
              return AdaptiveSheetScaffold(
                type: type,
                title: 'NTP',
                body: const NtpListView(),
              );
            },
          );
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
                    override
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
                  value: override,
                  onChanged: (value) {
                    ref.read(overrideNtpProvider.notifier).value = value;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
