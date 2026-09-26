import 'dart:async';
import 'dart:math' as math;

import 'package:bett_box/clash/core.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/manager/window_manager.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/plugins/app.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  bool _isRefreshActive = false;
  bool _wasPaused = false;
  Timer? _dashboardRefreshDebounceTimer;
  Timer? _missedUpdateCheckTimer;
  DateTime? _lastMissedUpdateCheck;
  late final VoidCallback _dashboardTickListener;

  static const _missedUpdateCheckDelay = Duration(seconds: 5);
  static const _missedUpdateCheckThrottle = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardTickListener = () {
      if (!globalState.isStart) {
        return;
      }
      unawaited(globalState.appController.updateRunTime());
    };
    dashboardRefreshManager.tick1s.addListener(_dashboardTickListener);
    ref.listenManual(layoutChangeProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prev != next) {
          globalState.computeHeightMapCache = {};
        }
      });
    });
    ref.listenManual(checkIpProvider, (prev, next) {
      if (next.b && (prev?.a != next.a)) {
        detectionState.startCheck();
      }
    });
    ref.listenManual(checkMediaUnlockProvider, (prev, next) {
      if (next.b && (prev?.a != next.a)) {
        mediaUnlockState.startCheckOnNodeChange();
      }
    });
    ref.listenManual(configStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.savePreferencesDebounce();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDashboardRefreshState();
      detectionState.tryStartCheck();
      mediaUnlockState.tryStartCheck();
      globalState.appController.updateGroupsDebounce();
    });
    if (window == null) {
      return;
    }
    ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
      if (prev == next) {
        return;
      }
      final shouldSet = next.a == true && next.b == true;
      await macOS?.updateDns(!shouldSet);
      await system.setupLinuxTunDns(shouldSet);
    });
    ref.listenManual(currentBrightnessProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      window?.updateMacOSBrightness(next);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _dashboardRefreshDebounceTimer?.cancel();
    _missedUpdateCheckTimer?.cancel();
    dashboardRefreshManager.tick1s.removeListener(_dashboardTickListener);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _updateDashboardRefreshState() async {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    var isVisible = true;
    var isMinimized = false;
    if (system.isDesktop) {
      final visible = await window?.isVisible;
      if (visible == false) {
        isVisible = false;
      }
      isMinimized = await window?.isMinimized ?? false;
    }
    final isPinned =
        system.isDesktop &&
        ref.read(windowSettingProvider.select((s) => s.isPinned));
    final shouldRun = system.isDesktop
        ? (isPinned || (isVisible && !isMinimized))
        : isForeground;

    if (!shouldRun) {
      _dashboardRefreshDebounceTimer?.cancel();
      _dashboardRefreshDebounceTimer = null;
      if (_isRefreshActive) {
        dashboardRefreshManager.stop();
        _isRefreshActive = false;
      }
      return;
    }

    if (_isRefreshActive) {
      return;
    }

    _dashboardRefreshDebounceTimer?.cancel();
    _dashboardRefreshDebounceTimer = Timer(
      const Duration(milliseconds: 1000),
      () {
        if (!mounted) return;
        if (_isRefreshActive) return;
        dashboardRefreshManager.start();
        _isRefreshActive = true;
      },
    );
  }

  bool get _shouldCheckMissedUpdates {
    if (_lastMissedUpdateCheck == null) return true;
    return DateTime.now().difference(_lastMissedUpdateCheck!) >
        _missedUpdateCheckThrottle;
  }

  void _scheduleMissedUpdateCheck() {
    if (!_shouldCheckMissedUpdates) return;
    _missedUpdateCheckTimer?.cancel();
    _missedUpdateCheckTimer = Timer(_missedUpdateCheckDelay, () {
      _lastMissedUpdateCheck = DateTime.now();
      globalState.appController.checkAndUpdateMissedProfiles();
    });
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasPaused = true;
    }

    final isBackgroundState =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state == AppLifecycleState.inactive && !system.isDesktop);

    if (isBackgroundState) {
      _missedUpdateCheckTimer?.cancel();
      globalState.appController.savePreferences();
      await globalState.handleBackground();
    } else if (state == AppLifecycleState.resumed) {
      globalState.handleForeground();
      render?.resume();
      await globalState.resumeForegroundUpdates();
      await globalState.appController.syncWakelockIfNeeded();
      _scheduleMissedUpdateCheck();
      final isInit = await clashCore.isInit;
      if (isInit) {
        globalState.appController.updateGroupsDebounce();
      }

      if (_wasPaused) {
        _wasPaused = false;
        final hasDetection = ref
            .read(dashboardStateProvider)
            .dashboardWidgets
            .contains(DashboardWidget.networkDetection);
        if (hasDetection) {
          detectionState.tryStartCheck();
        }
        mediaUnlockState.tryStartCheck();
      }
    }
    if (state == AppLifecycleState.resumed && system.isAndroid) {
      final hidden = ref.read(appSettingProvider.select((s) => s.hidden));
      app.updateExcludeFromRecents(hidden);
      SystemChrome.setSystemUIOverlayStyle(
        globalState.appState.systemUiOverlayStyle,
      );
    }
    _updateDashboardRefreshState();
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.updateBrightness();
    globalState.appController.updateTray();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  Widget _buildLoading() {
    return Consumer(
      builder: (_, ref, _) {
        final loading = ref.watch(loadingProvider);
        final isMobileView = ref.watch(isMobileViewProvider);
        if (!loading || isMobileView) return const SizedBox.shrink();
        return const Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 2.0,
          child: IgnorePointer(
            child: RotatedBox(
              quarterTurns: 1,
              child: LinearProgressIndicator(backgroundColor: Colors.transparent),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground({
    required BuildContext context,
    required Widget child,
  }) {
    final colorScheme = context.colorScheme;
    return Material(
      color: colorScheme.surfaceContainer,
      shape: BorderDirectional(
        end: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  void _handleToPage(
    List<NavigationItem> items,
    int currentIndex,
    int targetIndex,
  ) {
    final label = items[targetIndex].label;
    if (currentIndex == targetIndex) {
      final pageContext = GlobalObjectKey(label).currentContext;
      if (pageContext != null) {
        Navigator.of(pageContext).popUntil((route) => route.isFirst);
      }
    }
    globalState.appController.toPage(label);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    final showLabel = ref.watch(appSettingProvider).showLabel;

    return Container(
      color: context.colorScheme.surfaceContainer,
      child: Row(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              _buildBackground(
                context: context,
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                      if (currentIndex > 0) {
                        _handleToPage(
                          navigationItems,
                          currentIndex,
                          currentIndex - 1,
                        );
                      }
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                      if (currentIndex < navigationItems.length - 1) {
                        _handleToPage(
                          navigationItems,
                          currentIndex,
                          currentIndex + 1,
                        );
                      }
                    },
                  },
                  child: Focus(
                    autofocus: true,
                    child: NavigationSidebar(
                      destinations: navigationItems,
                      selectedIndex: currentIndex,
                      expanded: showLabel,
                      windowControls: Size(
                        system.isMacOS ? 72.0 : 0.0,
                        system.isMacOS ? 24.0 : 0.0,
                      ),
                      onSelected: (index) {
                        _handleToPage(navigationItems, currentIndex, index);
                      },
                      onToggle: () {
                        ref
                            .read(appSettingProvider.notifier)
                            .updateState(
                              (state) => state.copyWith(
                                showLabel: !state.showLabel,
                              ),
                            );
                      },
                    ),
                  ),
                ),
              ),
              _buildLoading(),
            ],
          ),
          Expanded(
            flex: 1,
            child: ClipRect(
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
