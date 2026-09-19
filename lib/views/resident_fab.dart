import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/views/dashboard/widgets/start_fab.dart';
import 'package:bett_box/views/profiles/add_profile.dart';
import 'package:bett_box/views/proxies/common.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// OverflowBoxFit 没有经由 material/widgets 再导出，需要显式从 rendering 取
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// 移动视图（竖屏）下与底栏伴生的常驻悬浮按钮。
///
/// - 只在这三个根页面出现对应操作：首页 = 启动/停止、代理 = 测速、配置 = 添加配置；
/// - 「更多」页以及代理页切到列表模式（`ProxiesType.list`）时不显示；
/// - 其它页面（脚本、隧道、日志、请求、连接、资源）完全不参与，它们各自的悬浮按钮保持原样；
/// - 页面之间切换时，**外壳（底色 / 圆角 / 阴影 / FAB 本体）全程只存在一个实例、完全不淡出**，
///   只做「内部内容淡出 → 替换 → label 宽度连续变宽 + 内容淡入」，
///   与首页启动/停止按钮（`start_fab.dart` 的 `AnimatedContainer` 200ms easeOut）
///   使用同一时长与同一套测量方式，因此既不会两块按钮叠加变亮，也不会出现直角或闪现位移；
/// - 出现 / 消失（例如切到「更多」页）时才是整体弱隐。
class ResidentFab extends ConsumerStatefulWidget {
  const ResidentFab({super.key});

  @override
  ConsumerState<ResidentFab> createState() => _ResidentFabState();
}

class _ResidentFabState extends ConsumerState<ResidentFab>
    with SingleTickerProviderStateMixin {
  /// 出现 / 消失：整体弱隐
  static const _shellFadeIn = Duration(milliseconds: 180);
  static const _shellFadeOut = Duration(milliseconds: 130);

  late final AnimationController _shellFade = AnimationController(
    vsync: this,
    duration: _shellFadeIn,
    reverseDuration: _shellFadeOut,
    value: 1.0,
  );

  /// 代理页测速时的内容缩放，沿用 DelayTestButton 的实现（1 → 0）
  late final AnimationController _testScaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late final Animation<double> _testScale = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).animate(
    CurvedAnimation(parent: _testScaleController, curve: const Interval(0, 1)),
  );

  PageLabel? _lastResidentPage;
  bool? _lastVisible;

  /// 代理页当前策略组名（测速按钮据此判断是否正在测速）
  String _groupName = '';

  @override
  void initState() {
    super.initState();
    delayTestCoordinator.addListener(_handleTestingChanged);
    _handleTestingChanged();
  }

  void _handleTestingChanged() {
    if (!mounted) return;
    if (delayTestCoordinator.isTestingGroup(_groupName)) {
      _testScaleController.forward();
    } else {
      _testScaleController.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    delayTestCoordinator.removeListener(_handleTestingChanged);
    _shellFade.dispose();
    _testScaleController.dispose();
    super.dispose();
  }

  void _handleProxyTest(VoidCallback? action) {
    if (delayTestCoordinator.isTesting) return;
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final pageLabel = ref.watch(currentPageLabelProvider);
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final residentPage = switch (pageLabel) {
      PageLabel.dashboard => PageLabel.dashboard,
      PageLabel.profiles => PageLabel.profiles,
      PageLabel.proxies => proxiesType == ProxiesType.tab
          ? PageLabel.proxies
          : null,
      _ => null,
    };
    final visible = residentPage != null;
    _groupName =
        ref.watch(proxiesTabControllerStateProvider.select((state) => state.b)) ??
        '';
    final proxyTestAction = ref.watch(residentProxyTestProvider);

    if (_lastVisible != visible) {
      final wasVisible = _lastVisible ?? true;
      _lastVisible = visible;
      if (visible) {
        _shellFade.forward();
      } else if (wasVisible) {
        _shellFade.reverse();
      }
    }

    if (residentPage != null) {
      _lastResidentPage = residentPage;
    }

    final activePage = residentPage ?? _lastResidentPage ?? PageLabel.dashboard;

    return StartFabDataProvider(
      builder: (context, startData) => AnimatedBuilder(
        animation: Listenable.merge([_testScaleController, _shellFade]),
        builder: (context, _) {
          return _ResidentFabShell(
            content: _buildContent(
              context,
              startData,
              proxyTestAction,
              activePage,
            ),
            shellFade: _shellFade,
            visible: visible,
            // 只有屏幕上看得见的时候才连续变宽，不可见期间直接到位
            animateWidth: _shellFade.value > 0,
          );
        },
      ),
    );
  }

  _FabContent _buildContent(
    BuildContext context,
    StartFabData startData,
    VoidCallback? proxyTestAction,
    PageLabel page,
  ) {
    switch (page) {
      case PageLabel.dashboard:
        return _FabContent(
          page: page,
          icon: startData.icon,
          labelText: startData.labelText,
          labelWidth: startData.labelWidth,
          isRunTime: startData.isRunTime,
          onPressed: startData.onPressed,
          onLongPress: startData.onLongPress,
          contentOpacity: startData.showLoading ? 0.0 : 1.0,
          showLoading: startData.showLoading,
        );
      case PageLabel.profiles:
        return _FabContent(
          page: page,
          icon: Icons.add_rounded,
          labelText: appLocalizations.addProfile,
          labelWidth: startFabTextWidth(context, appLocalizations.addProfile),
          isRunTime: false,
          onPressed: showAddProfileExtend,
        );
      case PageLabel.proxies:
        return _FabContent(
          page: page,
          icon: Icons.network_ping_rounded,
          labelText: appLocalizations.startTest,
          labelWidth: startFabTextWidth(context, appLocalizations.startTest),
          isRunTime: false,
          onPressed: (delayTestCoordinator.isTesting || _groupName.isEmpty)
              ? null
              : () => _handleProxyTest(proxyTestAction),
          contentScale: _testScale.value,
          showLoading:
              delayTestCoordinator.isTestingGroup(_groupName) &&
              _testScaleController.isCompleted,
        );
      default:
        return _FabContent(
          page: page,
          icon: startData.icon,
          labelText: startData.labelText,
          labelWidth: startData.labelWidth,
          isRunTime: startData.isRunTime,
          onPressed: startData.onPressed,
          onLongPress: startData.onLongPress,
          contentOpacity: startData.showLoading ? 0.0 : 1.0,
          showLoading: startData.showLoading,
        );
    }
  }
}

/// 常驻悬浮按钮当前要显示的内容
@immutable
class _FabContent {
  const _FabContent({
    required this.page,
    required this.icon,
    required this.labelText,
    required this.labelWidth,
    this.isRunTime = false,
    this.onPressed,
    this.onLongPress,
    this.contentOpacity = 1.0,
    this.contentScale = 1.0,
    this.showLoading = false,
  });

  final PageLabel page;
  final IconData icon;
  final String labelText;
  final double labelWidth;
  final bool isRunTime;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double contentOpacity;
  final double contentScale;
  final bool showLoading;
}

/// 常驻悬浮按钮的外壳。
///
/// 底色、圆角、阴影、FAB 本体全程只渲染这一个实例，页面之间不重建、不淡出；
/// 变化的只有 label 的宽度（`AnimatedContainer`，与启动/停止按钮同款）
/// 以及图标 / 文字的透明度。
class _ResidentFabShell extends StatelessWidget {
  const _ResidentFabShell({
    required this.content,
    required this.shellFade,
    required this.visible,
    required this.animateWidth,
  });

  final _FabContent content;
  final Animation<double> shellFade;
  final bool visible;
  final bool animateWidth;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: shellFade,
      child: IgnorePointer(
        ignoring: !visible,
        child: GestureDetector(
          onLongPress: content.onLongPress,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: getCommonFabDecoration(context),
                child: FloatingActionButton.extended(
                  elevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  clipBehavior: Clip.none,
                  heroTag: null,
                  onPressed: content.onPressed,
                  icon: _buildContentChild(
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: KeyedSubtree(
                        key: ValueKey(content.page),
                        child: Icon(content.icon),
                      ),
                    ),
                  ),
                  label: _buildContentChild(
                    AnimatedContainer(
                      // 看不见的时候宽度直接到位，只有看得见才连续变宽
                      duration: animateWidth
                          ? startFabWidthAnimationDuration
                          : Duration.zero,
                      curve: Curves.easeOut,
                      width: content.labelWidth,
                      alignment: content.isRunTime
                          ? Alignment.centerLeft
                          : Alignment.center,
                      padding: content.isRunTime
                          ? const EdgeInsets.only(left: 6.0)
                          : EdgeInsets.zero,
                      clipBehavior: Clip.none,
                      child: OverflowBox(
                        fit: OverflowBoxFit.deferToChild,
                        alignment: content.isRunTime
                            ? Alignment.centerLeft
                            : Alignment.center,
                        minWidth: 0,
                        maxWidth: double.infinity,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: content.isRunTime
                                    ? Alignment.centerLeft
                                    : Alignment.center,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: KeyedSubtree(
                            key: ValueKey(content.page),
                            child: Text(
                              content.labelText,
                              maxLines: 1,
                              textAlign: content.isRunTime
                                  ? TextAlign.left
                                  : TextAlign.center,
                              overflow: TextOverflow.visible,
                              style: startFabLabelStyle(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (content.showLoading)
                IgnorePointer(
                  child: SizedBox(
                    width: 30,
                    height: 16,
                    child: OverflowBox(
                      maxWidth: 30,
                      maxHeight: 16,
                      child: SpinKitThreeBounce(
                        color:
                            Theme.of(
                              context,
                            ).floatingActionButtonTheme.foregroundColor ??
                            context.colorScheme.onPrimaryContainer,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentChild(Widget child) {
    return Opacity(
      opacity: content.contentOpacity,
      child: Transform.scale(scale: content.contentScale, child: child),
    );
  }
}
