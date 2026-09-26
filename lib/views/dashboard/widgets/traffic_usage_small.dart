import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class TrafficUsageSmall extends ConsumerStatefulWidget {
  const TrafficUsageSmall({super.key});

  @override
  ConsumerState<TrafficUsageSmall> createState() => _TrafficUsageSmallState();
}

class _TrafficUsageSmallState extends ConsumerState<TrafficUsageSmall> {
  static const double _donutSize = 47;

  static double get _donutEdge => (getWidgetHeight(1) - _donutSize) / 2;

  bool _showUpload = false;

  @override
  void initState() {
    super.initState();
    preferences.getTrafficUsageShowUpload().then((value) {
      if (!mounted || value == _showUpload) {
        return;
      }
      setState(() {
        _showUpload = value;
      });
    });
  }

  void _showDisplaySettings() {
    globalState.showCommonDialog<void>(
      child: CommonDialog(
        title: appLocalizations.trafficUsage,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(FluentIcons.arrow_circle_up_24_regular),
              title: Text(appLocalizations.upload),
              trailing: OptionRadioIcon(selected: _showUpload),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _setShowUpload(true);
              },
            ),
            ListTile(
              leading: const Icon(FluentIcons.arrow_circle_down_24_regular),
              title: Text(appLocalizations.download),
              trailing: OptionRadioIcon(selected: !_showUpload),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _setShowUpload(false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setShowUpload(bool value) {
    if (_showUpload != value) {
      setState(() {
        _showUpload = value;
      });
    }
    preferences.setTrafficUsageShowUpload(value);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = globalState.theme.darken3PrimaryContainer;
    final secondaryColor = globalState.theme.darken2SecondaryContainer;
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: _showDisplaySettings,
        child: ValueListenableBuilder<int>(
          valueListenable: dashboardRefreshManager.tick1s,
          builder: (_, _, _) {
            final totalTraffic = ref.read(totalTrafficProvider);
            final value = _showUpload ? totalTraffic.up : totalTraffic.down;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: baseInfoEdgeInsets.left,
                      top: baseInfoEdgeInsets.top,
                      bottom: baseInfoEdgeInsets.bottom,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FluentIcons.data_pie_24_regular,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TooltipText(
                                text: Text(
                                  appLocalizations.trafficUsage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.titleSmall?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: globalState.measure.bodyMediumHeight + 2,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: value.showValue),
                                      const TextSpan(text: ' '),
                                      TextSpan(
                                        text: value.showUnit,
                                        style: context.textTheme.bodyMedium
                                            ?.toLighter
                                            .adjustSize(-4),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.bodyMedium?.toLight
                                      .adjustSize(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    top: _donutEdge,
                    right: _donutEdge,
                    bottom: _donutEdge,
                  ),
                  child: SizedBox(
                    width: _donutSize,
                    height: _donutSize,
                    child: DonutChart(
                      trackColor: context.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      data: [
                        DonutChartData(
                          value: totalTraffic.up.value.toDouble(),
                          color: primaryColor,
                        ),
                        DonutChartData(
                          value: totalTraffic.down.value.toDouble(),
                          color: secondaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
