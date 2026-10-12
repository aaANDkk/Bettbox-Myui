import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

const speedTestUrl = 'https://ptclspeed.speedtestcustom.com';

Future<void> showSpeedTestConfirm(BuildContext context) async {
  final result = await globalState.showCommonDialog<bool>(
    child: CommonDialog(
      title: appLocalizations.speedTest,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop(false);
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop(true);
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Text(appLocalizations.speedTestDesc),
    ),
  );
  if (result == true) {
    globalState.openUrl(speedTestUrl);
  }
}

class NetworkSpeed extends ConsumerWidget {
  const NetworkSpeed({super.key});

  // Cache as const
  static const _initPoints = [Point(0, 0), Point(1, 0)];

  static List<Point> _getPoints(List<Traffic> traffics) {
    if (traffics.isEmpty) return _initPoints;

    // Pre-allocate array capacity
    final totalLength = traffics.length + _initPoints.length;
    final result = List<Point>.filled(totalLength, Point(0, 0));

    // Assign init points
    result[0] = _initPoints[0];
    result[1] = _initPoints[1];

    // Assign traffic points
    for (int i = 0; i < traffics.length; i++) {
      result[i + 2] = Point((i + 2).toDouble(), traffics[i].speed.toDouble());
    }

    return result;
  }

  static Traffic _getLastTraffic(List<Traffic> traffics) {
    if (traffics.isEmpty) return Traffic();
    return traffics.last;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = context.colorScheme.onSurfaceVariant.opacity80;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        onPressed: () {
          showSpeedTestConfirm(context);
        },
        info: Info(
          label: appLocalizations.networkSpeed,
          iconData: FluentIcons.gauge_24_regular,
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: dashboardRefreshManager.tick1s,
            builder: (_, _, _) {
              final traffic = _getLastTraffic(ref.read(trafficsProvider).list);
              final style = context.textTheme.bodySmall?.copyWith(color: color);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.arrow_up_24_filled, size: 14, color: color),
                  const SizedBox(width: 3),
                  Text('${traffic.up}/s', style: style),
                  const SizedBox(width: 8),
                  Icon(
                    FluentIcons.arrow_down_24_filled,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 3),
                  Text('${traffic.down}/s', style: style),
                ],
              );
            },
          ),
        ],
        child: RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: dashboardRefreshManager.tick1s,
            builder: (_, _, _) {
              final traffics = ref.read(trafficsProvider).list;
              final points = _getPoints(traffics);
              return Padding(
                padding: const EdgeInsets.only(
                  top: 16,
                  left: 0,
                  right: 0,
                  bottom: 0,
                ),
                child: RepaintBoundary(
                  child: LineChart(
                    gradient: true,
                    color: primaryColor,
                    points: points,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
