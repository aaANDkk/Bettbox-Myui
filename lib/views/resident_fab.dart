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
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ResidentFab extends ConsumerStatefulWidget {
  const ResidentFab({super.key});

  @override
  ConsumerState<ResidentFab> createState() => _ResidentFabState();
}

class _ResidentFabState extends ConsumerState<ResidentFab>
    with SingleTickerProviderStateMixin {
  static const _shellFadeIn = Duration(milliseconds: 180);
  static const _shellFadeOut = Duration(milliseconds: 130);

  late final AnimationController _shellFade = AnimationController(
    vsync: this,
    duration: _shellFadeIn,
    reverseDuration: _shellFadeOut,
    value: 1.0,
  );

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
    final navItems = ref.watch(currentNavigationItemsStateProvider).value;
    final isPageInNav = navItems.any((item) => item.label == pageLabel);
    final effectivePage = isPageInNav
        ? pageLabel
        : (navItems.isNotEmpty ? navItems.first.label : PageLabel.dashboard);
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final showCardStartButton = ref.watch(
      appSettingProvider.select((state) => state.showCardStartButton),
    );
    final residentPage = switch (effectivePage) {
      PageLabel.dashboard => showCardStartButton ? null : PageLabel.dashboard,
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
          isExtended: startData.isExtended,
          onPressed: startData.onPressed,
          onLongPress: startData.onLongPress,
          contentOpacity: startData.showLoading ? 0.0 : 1.0,
          showLoading: startData.showLoading,
        );
      case PageLabel.profiles:
        return _FabContent(
          page: page,
          icon: FluentIcons.add_circle_24_filled,
          labelText: appLocalizations.addProfile,
          labelWidth: startFabTextWidth(context, appLocalizations.addProfile),
          isRunTime: false,
          isExtended: true,
          onPressed: showAddProfileExtend,
        );
      case PageLabel.proxies:
        return _FabContent(
          page: page,
          icon: FluentIcons.flash_24_filled,
          labelText: appLocalizations.startTest,
          labelWidth: startFabTextWidth(context, appLocalizations.startTest),
          isRunTime: false,
          isExtended: true,
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
          isExtended: startData.isExtended,
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
    this.isExtended = true,
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
  final bool isExtended;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double contentOpacity;
  final double contentScale;
  final bool showLoading;
}

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
                  extendedIconLabelSpacing: 0.0,
                  extendedPadding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                      duration: animateWidth
                          ? startFabWidthAnimationDuration
                          : Duration.zero,
                      curve: Curves.easeOut,
                      width: content.isExtended
                          ? (content.labelWidth + 12.0)
                          : 0.0,
                      alignment: content.isRunTime
                          ? Alignment.centerLeft
                          : Alignment.center,
                      padding: EdgeInsets.only(
                        left: content.isExtended
                            ? (content.isRunTime ? 14.0 : 8.0)
                            : 0.0,
                        right: content.isExtended ? 4.0 : 0.0,
                      ),
                      child: ClipRect(
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
