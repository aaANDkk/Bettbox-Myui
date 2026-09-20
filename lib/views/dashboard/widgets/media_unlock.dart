import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/pages/pages.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';

class MediaUnlock extends ConsumerStatefulWidget {
  const MediaUnlock({super.key});

  @override
  ConsumerState<MediaUnlock> createState() => _MediaUnlockState();
}

class _MediaUnlockState extends ConsumerState<MediaUnlock> {
  String _getStatusText(MediaUnlockStatus status, [MediaPlatform? platform]) {
    switch (status) {
      case MediaUnlockStatus.unlocked:
        if (platform?.category == MediaCategory.streaming ||
            platform?.category == MediaCategory.ai) {
          return appLocalizations.mediaUnlocked;
        }
        return appLocalizations.unlocked;
      case MediaUnlockStatus.limited:
        if (platform?.category == MediaCategory.streaming) {
          return appLocalizations.limitedUnlock;
        }
        return appLocalizations.flagged;
      case MediaUnlockStatus.flagged:
        return appLocalizations.flagged;
      case MediaUnlockStatus.blocked:
        return appLocalizations.notUnlocked;
      case MediaUnlockStatus.failed:
        return appLocalizations.checkFailed;
      case MediaUnlockStatus.testing:
        return '...';
      case MediaUnlockStatus.unknown:
        return '-';
    }
  }

  Widget _buildPlatformRow(
    MediaPlatform platform,
    MediaUnlockResult? result,
    bool isLoading,
    BuildContext context, {
    bool isItemTesting = false,
    required bool colorfulIcons,
  }) {
    final isTesting = isItemTesting ||
        (isLoading &&
            (result == null || result.status == MediaUnlockStatus.testing));
    final status = isTesting
        ? MediaUnlockStatus.testing
        : (result?.status ?? (isLoading ? MediaUnlockStatus.testing : MediaUnlockStatus.unknown));
    final color = status.statusColor(context.colorScheme);
    final latency = result?.latency;
    final String statusDisplay;
    if (status == MediaUnlockStatus.unknown) {
      statusDisplay = '-';
    } else if (status == MediaUnlockStatus.testing) {
      statusDisplay = '...';
    } else if (status == MediaUnlockStatus.limited &&
        platform.category == MediaCategory.streaming) {
      statusDisplay = appLocalizations.limitedUnlock;
    } else if (latency != null) {
      statusDisplay = '${latency}ms';
    } else {
      statusDisplay = _getStatusText(status, platform);
    }

    final isError = status == MediaUnlockStatus.blocked ||
        status == MediaUnlockStatus.failed;

    final double iconSize = 16.ap;
    final Widget icon;
    if (platform.isMonochrome) {
      icon = SvgPicture.asset(
        'assets/images/platforms/${platform.name}.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          context.colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      );
    } else if (colorfulIcons) {
      icon = SvgPicture.asset(
        'assets/images/platforms/${platform.name}.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
    } else {
      icon = ColorFiltered(
        colorFilter: monochromeColorFilter,
        child: SvgPicture.asset(
          'assets/images/platforms/${platform.name}.svg',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
      );
    }

    return SizedBox(
      key: ValueKey(platform),
      height: 24.ap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20.ap,
            height: 20.ap,
            child: Center(child: themedPlatformIcon(context, platform, icon)),
          ),
          SizedBox(width: 8.ap),
          SizedBox(
            width: 64.ap,
            child: Text(
              platform.defaultName,
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 12.ap,
                color: context.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 6.ap),
          SizedBox(
            width: 8.ap,
            height: 20.ap,
            child: Center(
              child: Container(
                width: 6.ap,
                height: 6.ap,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.ap),
          Expanded(
            child: _LatencyBar(status: status, latency: latency),
          ),
          SizedBox(width: 10.ap),
          SizedBox(
            width: 52.ap,
            child: Text(
              statusDisplay,
              textAlign: TextAlign.right,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11.5.ap,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isError
                    ? context.colorScheme.error
                    : context.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = ref.watch(
      appSettingProvider.select((state) => state.pinnedMediaPlatforms),
    );
    final colorfulIcons = ref.watch(
      appSettingProvider.select((state) => state.mediaUnlockColorfulIcons),
    );
    final displayedPlatforms =
        (pinned.isNotEmpty ? pinned : defaultPinnedMediaPlatforms)
            .take(4)
            .toList();

    return SizedBox(
      height: getWidgetHeight(2),
      child: ValueListenableBuilder<MediaUnlockState>(
        valueListenable: mediaUnlockState.state,
        builder: (context, state, _) {
          final isWidgetLoading =
              displayedPlatforms.any(state.testingPlatforms.contains);
          return CommonCard(
            onPressed: () {
              showExtend(
                context,
                builder: (_, type) => MediaUnlockPage(type: type),
              );
            },
            child: Column(
              children: [
                InfoHeader(
                  padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                  // 右侧刷新按钮不撑高表头：图标 / 标题 / 按钮同处一行标题高度
                  actionsHeight: globalState.measure.titleSmallHeight,
                  info: Info(
                    // 卡片标题用短标题键（英文只写 Connectivity，去掉后面的 Test）；
                    // 解锁页面标题仍用 mediaUnlock
                    label: appLocalizations.mediaUnlockShort,
                    iconData: Icons.link_rounded,
                  ),
                  actions: [
                    SizedBox(
                      width: 24.ap,
                      height: 24.ap,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: isWidgetLoading
                            ? null
                            : () => mediaUnlockState.checkPlatforms(
                                  displayedPlatforms,
                                  force: true,
                                ),
                        icon: isWidgetLoading
                            ? SizedBox(
                                width: 16.ap,
                                height: 16.ap,
                                child: SpinKitFadingCircle(
                                  color: context.colorScheme.primary,
                                  size: 16.ap,
                                ),
                              )
                            : Icon(
                                Icons.sync_rounded,
                                size: 18.ap,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.ap, 8.ap, 16.ap, 4.ap),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.ap, 2.ap, 16.ap, 8.ap),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final p in displayedPlatforms)
                          _buildPlatformRow(
                            p,
                            state.results[p],
                            state.isLoading,
                            context,
                            isItemTesting:
                                state.testingPlatforms.contains(p),
                            colorfulIcons: colorfulIcons,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 连通性测试小部件的延迟指示条。
///
/// 优化要点（消除「结果出来后闪现再固定」）：
/// - 底层轨道常驻不变，测试中与出结果之间不再整体替换控件；
/// - 测试中叠加官方 `LinearProgressIndicator` 扫描动画（曲线/时序保持原样），
///   仅通过 `borderRadius` 让两个扫描分段的左右两端都成为圆润端帽；
/// - 结果条宽度由 [AnimationController] 从 0（或上一次的值）平滑生长到
///   目标宽度，而不是瞬间跳到最终宽度，彻底消除闪现感。
class _LatencyBar extends StatefulWidget {
  final MediaUnlockStatus status;
  final int? latency;

  const _LatencyBar({required this.status, required this.latency});

  @override
  State<_LatencyBar> createState() => _LatencyBarState();
}

class _LatencyBarState extends State<_LatencyBar>
    with SingleTickerProviderStateMixin {
  static const _fillDuration = Duration(milliseconds: 520);
  static const _fadeDuration = Duration(milliseconds: 200);

  late final AnimationController _controller;
  double _from = 0.0;
  double _to = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _fillDuration);
    _syncFill(animate: false);
  }

  @override
  void didUpdateWidget(covariant _LatencyBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.latency != widget.latency) {
      _syncFill(animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _targetFactor {
    final latency = widget.latency;
    if (latency == null || latency <= 0) {
      return 0.0;
    }
    return (0.10 + (latency / 1000) * 0.90).clamp(0.10, 1.0);
  }

  /// 当前实际显示宽度比例（含缓动），动画被打断时也可平滑接管
  double get _currentFactor {
    final t = Curves.easeOutCubic.transform(_controller.value);
    return (_from + (_to - _from) * t).clamp(0.0, 1.0);
  }

  void _syncFill({required bool animate}) {
    final isTesting = widget.status == MediaUnlockStatus.testing;
    final target = isTesting ? 0.0 : _targetFactor;
    final begin = _currentFactor;
    _from = begin;
    _to = target;
    if (!animate || begin == target) {
      _controller.value = 1.0;
      return;
    }
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isTesting = widget.status == MediaUnlockStatus.testing;
    final trackColor = context.colorScheme.primary.withValues(alpha: 0.12);
    final fillColor = context.colorScheme.primary.withValues(alpha: 0.6);

    // 测试中：官方扫描动画（曲线/时序完全保持原样，仅显式指定 borderRadius
    // 让两个扫描分段的左右两端都成为圆润端帽）；出结果：按延迟平滑生长。
    // 两者尺寸完全一致（满宽 6.ap 轨道），因此淡入淡出重叠不会产生跳变。
    final Widget indicator = RepaintBoundary(
      key: ValueKey<bool>(isTesting),
      child: isTesting
          ? LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
              borderRadius: BorderRadius.circular(3.ap),
            )
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _currentFactor,
                    heightFactor: 1.0,
                    // 填充条自身保持 3.ap 圆角：右端为圆润端帽而非直角
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(3.ap),
                      ),
                    ),
                  ),
                );
              },
            ),
    );

    return SizedBox(
      height: 6.ap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.ap),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: trackColor),
            AnimatedSwitcher(
              duration: _fadeDuration,
              reverseDuration: _fadeDuration,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: indicator,
            ),
          ],
        ),
      ),
    );
  }
}
