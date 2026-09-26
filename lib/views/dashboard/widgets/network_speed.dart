import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// 浏览器测速网站地址（网络速度小部件点击后跳转）
const speedTestUrl = 'https://ptclspeed.speedtestcustom.com';

/// 点击网络速度小部件时的确认弹窗：格式与「长按内存小部件」的强制 GC 弹窗一致，
/// 确认后才跳转浏览器测速。
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
              final traffics = ref.read(trafficsProvider).list;
              final speedText = _getLastTraffic(traffics).toSpeedText();
              return Text(
                speedText,
                style: context.textTheme.bodySmall?.copyWith(
                  color: color,
                ),
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
