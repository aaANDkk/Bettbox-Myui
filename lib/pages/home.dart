import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OnSelected = void Function(int index);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<int, FocusNode> _navFocusNodes = {};
  int _currentNavIndex = 0;

  FocusNode _getNavFocusNode(int index) {
    return _navFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  void _requestNavFocus(int index) {
    if (!globalState.isAndroidTV) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _getNavFocusNode(index).requestFocus();
      }
    });
  }

  bool get isNavFocused =>
      _navFocusNodes.values.any((node) => node.hasFocus);

  void focusNav() {
    if (!globalState.isAndroidTV || !mounted) return;
    _getNavFocusNode(_currentNavIndex).requestFocus();
  }

  @override
  void initState() {
    super.initState();
    if (globalState.isAndroidTV) {
      _requestNavFocus(0);
    }
  }

  @override
  void dispose() {
    for (final node in _navFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeBackScope(
      onTvBack: () {
        final currentPage = globalState.appState.pageLabel;
        final isNav = isNavFocused;

        if (isNav) {
          if (currentPage == PageLabel.dashboard) {
            return false;
          }
          globalState.appController.toPage(PageLabel.dashboard);
          return true;
        }

        focusNav();
        return true;
      },
      child: Consumer(
        builder: (context, ref, child) {
          final (isMobile, navigationItems, currentIndex) = ref.watch(
            navigationStateProvider.select(
              (state) => (
                state.viewMode == ViewMode.mobile,
                state.navigationItems,
                state.currentIndex,
              ),
            ),
          );
          final bottomNavigationBar = globalState.isAndroidTV
              ? _buildTVBottomNavBar(
                  context,
                  navigationItems: navigationItems,
                  currentIndex: currentIndex,
                )
              : GoogleBottomNavBar(
                  navigationItems: navigationItems,
                  selectedIndex: currentIndex,
                  onTabChange: (index) {
                    globalState.appController.toPage(
                      navigationItems[index].label,
                    );
                  },
                );
          if (child == null) {
            return const SizedBox();
          }
          Widget bodyWidget = child;
          if (isMobile) {
            final pageContent = MediaQuery.removePadding(
              removeTop: false,
              removeBottom: false,
              removeLeft: true,
              removeRight: true,
              context: context,
              child: child,
            );
            final navBar = MediaQuery.removePadding(
              removeTop: true,
              removeBottom: false,
              removeLeft: true,
              removeRight: true,
              context: context,
              child: bottomNavigationBar,
            );
            bodyWidget = Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(child: pageContent),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RepaintBoundary(child: navBar),
                ),
              ],
            );
          }
          return Material(
            color: isMobile
                ? context.colorScheme.surfaceContainer
                : Colors.transparent,
            child: bodyWidget,
          );
        },
        child: Consumer(
          builder: (_, ref, _) {
            final navigationItems = ref
                .watch(currentNavigationItemsStateProvider)
                .value;
            final isMobile = ref.watch(isMobileViewProvider);
            return _HomePageView(
              navigationItems: navigationItems,
              pageBuilder: (_, index) {
                final navigationItem = navigationItems[index];
                return _NavigationPage(
                  key: ValueKey(navigationItem.label),
                  item: navigationItem,
                  isMobile: isMobile,
                  view: navigationItem.builder(context),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTVBottomNavBar(
    BuildContext context, {
    required List<NavigationItem> navigationItems,
    required int currentIndex,
  }) {
    if (_currentNavIndex != currentIndex) {
      _currentNavIndex = currentIndex;
      _requestNavFocus(currentIndex);
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withValues(alpha: 0.15),
          ),
        ],
      ),
      child: SafeArea(
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final focusedIndex = navigationItems.indexWhere(
                (item) =>
                    _navFocusNodes[navigationItems.indexOf(item)]?.hasFocus ==
                    true,
              );
              if (focusedIndex > 0) {
                _getNavFocusNode(focusedIndex - 1).requestFocus();
                return KeyEventResult.handled;
              } else if (focusedIndex == 0) {
                return KeyEventResult.handled;
              }
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              final focusedIndex = navigationItems.indexWhere(
                (item) =>
                    _navFocusNodes[navigationItems.indexOf(item)]?.hasFocus ==
                    true,
              );
              if (focusedIndex >= 0 &&
                  focusedIndex < navigationItems.length - 1) {
                _getNavFocusNode(focusedIndex + 1).requestFocus();
                return KeyEventResult.handled;
              } else if (focusedIndex == navigationItems.length - 1) {
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;
              final focusNode = _getNavFocusNode(index);
              return FocusTraversalOrder(
                order: NumericFocusOrder(index.toDouble()),
                child: AnimatedBuilder(
                  animation: focusNode,
                  builder: (context, child) {
                    final isFocused = focusNode.hasFocus;
                    return InkWell(
                      focusNode: focusNode,
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        globalState.appController.toPage(item.label);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 120),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.colorScheme.primary.withValues(
                                  alpha:
                                      context.colorScheme.brightness ==
                                              Brightness.light
                                          ? 0.20
                                          : 0.26,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: isFocused
                              ? Border.all(
                                  color: context.colorScheme.primary,
                                  width: 2,
                                )
                              : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconTheme(
                              data: IconThemeData(
                                color: isSelected
                                    ? context.colorScheme.primary
                                    : context.colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              child: item.icon,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label.localizedName,
                              style: TextStyle(
                                color: isSelected
                                    ? context.colorScheme.onSecondaryContainer
                                    : context.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavigationPage extends StatelessWidget {
  const _NavigationPage({
    super.key,
    required this.item,
    required this.isMobile,
    required this.view,
  });

  final NavigationItem item;
  final bool isMobile;
  final Widget view;

  @override
  Widget build(BuildContext context) {
    final keptView = KeepScope(
      key: ValueKey(item.label),
      keep: item.keep,
      child: isMobile
          ? view
          : Navigator(
              key: ValueKey('${item.label.name}_navigator'),
              pages: [MaterialPage(child: view)],
              onDidRemovePage: (_) {},
            ),
    );
    return Consumer(
      builder: (_, ref, child) {
        final isActive = ref.watch(
          currentPageLabelProvider.select((label) => label == item.label),
        );
        return TickerMode(
          enabled: isActive,
          child: ExcludeFocus(
            excluding: !isActive,
            child: child!,
          ),
        );
      },
      child: keptView,
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final ProviderSubscription<PageLabel> _pageLabelSubscription;
  late int _currentIndex;
  int _previousIndex = 0;
  bool _animating = false;
  bool _preparing = false;
  final Set<int> _mountedPages = {};
  int _warmUpCursor = 0;
  final Map<int, Widget> _pageCache = {};
  bool? _cacheIsMobile;
  List<PageLabel> _cacheLabels = const [];

  @override
  void initState() {
    super.initState();
    _currentIndex = _pageIndex;
    _previousIndex = _currentIndex;
    _mountedPages.add(_currentIndex);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _animating) {
          setState(() {
            _animating = false;
            _prunePages();
          });
        }
      });
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _pageLabelSubscription = ref.listenManual(currentPageLabelProvider, (
      prev,
      next,
    ) {
      if (prev != next) {
        _toPage(next);
        if (next == PageLabel.dashboard && !system.isDesktop) {
          dashboardRefreshManager.triggerImmediateTick();
          globalState.appController.updateTraffic();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmUpStep());
  }

  void _warmUpStep() {
    if (!mounted) return;
    if (_animating || _preparing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _warmUpStep());
      return;
    }
    if (!ref.read(isMobileViewProvider)) return;
    final items = widget.navigationItems;
    while (_warmUpCursor < items.length &&
        (_mountedPages.contains(_warmUpCursor) ||
            !items[_warmUpCursor].keep)) {
      _warmUpCursor++;
    }
    if (_warmUpCursor >= items.length) return;
    setState(() => _mountedPages.add(_warmUpCursor));
    _warmUpCursor++;
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmUpStep());
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLabels = [
      for (final item in oldWidget.navigationItems) item.label,
    ];
    final newLabels = [for (final item in widget.navigationItems) item.label];
    if (!listEquals(oldLabels, newLabels)) {
      _animating = false;
      _preparing = false;
      _controller.value = 1.0;
      _currentIndex = _pageIndex;
      _previousIndex = _currentIndex;
      _mountedPages
        ..clear()
        ..add(_currentIndex);
      _pageCache.clear();
      _warmUpCursor = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _warmUpStep());
    }
  }

  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    return index < 0 ? 0 : index;
  }

  void _toPage(PageLabel pageLabel, [bool ignoreAnimateTo = false]) {
    if (!mounted) return;
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1 || index == _currentIndex) return;

    if (!globalState.isAndroidTV) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    final isMobile = ref.read(isMobileViewProvider);
    final animate = isMobile && !ignoreAnimateTo;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      _mountedPages.add(index);
      _animating = false;
      _preparing = animate;
    });
    if (!animate) {
      _controller.value = 1.0;
      _prunePages();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_preparing) return;
      setState(() {
        _preparing = false;
        _animating = true;
      });
      _controller.forward(from: 0);
    });
  }

  void _prunePages() {
    _mountedPages.removeWhere((index) {
      if (index == _currentIndex) return false;
      final prune =
          index >= widget.navigationItems.length ||
          !widget.navigationItems[index].keep;
      if (prune) _pageCache.remove(index);
      return prune;
    });
  }

  @override
  void dispose() {
    _pageLabelSubscription.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.navigationItems;
    final direction = (_currentIndex - _previousIndex).sign.toDouble();
    final isMobile = ref.read(isMobileViewProvider);
    final labels = [for (final item in items) item.label];
    if (_cacheIsMobile != isMobile || !listEquals(_cacheLabels, labels)) {
      _pageCache.clear();
      _cacheIsMobile = isMobile;
      _cacheLabels = labels;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final index in _mountedPages)
          if (index < items.length)
            IgnorePointer(
              key: ValueKey(items[index].label),
              ignoring: index != _currentIndex,
              child: AnimatedBuilder(
                animation: _animation,
                child: _pageCache.putIfAbsent(
                  index,
                  () => RepaintBoundary(
                    child: widget.pageBuilder(context, index),
                  ),
                ),
                builder: (context, child) {
                  final progress = _animating
                      ? _animation.value
                      : (_preparing ? 0.0 : 1.0);
                  final bool visible;
                  final double dx;
                  if (index == _currentIndex) {
                    visible = true;
                    dx = direction * (1 - progress);
                  } else if ((_animating || _preparing) &&
                      index == _previousIndex) {
                    visible = true;
                    dx = -direction * progress;
                  } else {
                    visible = false;
                    dx = 0;
                  }
                  return Offstage(
                    offstage: !visible,
                    child: FractionalTranslation(
                      translation: Offset(dx, 0),
                      child: child,
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

class HomeBackScope extends ConsumerWidget {
  final Widget child;
  final bool Function()? onTvBack;

  const HomeBackScope({super.key, required this.child, this.onTvBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (system.isAndroid) {
      final backBlock = ref.watch(backBlockProvider);
      final currentPage = ref.watch(currentPageLabelProvider);
      final rootPageLabels = ref.watch(
        currentNavigationItemsStateProvider.select(
          (state) => state.value.map((item) => item.label).toSet(),
        ),
      );
      final morePageLabels = ref.watch(
        moreToolsSelectorStateProvider.select(
          (state) => state.navigationItems.map((item) => item.label).toSet(),
        ),
      );
      final isCurrentRootPage = rootPageLabels.contains(currentPage);

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || backBlock) return;
          final navigatorState = globalState.navigatorKey.currentState;
          if (navigatorState?.userGestureInProgress == true) return;

          if (globalState.isAndroidTV) {
            final tvBack = onTvBack;
            if (tvBack != null && tvBack()) return;
          }

          if (!isCurrentRootPage) {
            globalState.appController.toPage(
              morePageLabels.contains(currentPage)
                  ? PageLabel.tools
                  : PageLabel.dashboard,
            );
            return;
          }
          if (navigatorState != null && navigatorState.canPop()) {
            navigatorState.pop();
            return;
          }
          await globalState.appController.handleBackOrExit();
        },
        child: child,
      );
    }
    return child;
  }
}
