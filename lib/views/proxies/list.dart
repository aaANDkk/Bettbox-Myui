import 'dart:async';
import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'card.dart';
import 'common.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

const _listRevealDuration = Duration(milliseconds: 153);

class ProxiesListView extends ConsumerWidget {
  const ProxiesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proxiesListStateProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);

    if (state.groups.isEmpty) {
      return NullStatus(
        label: appLocalizations.nullTip(appLocalizations.proxies),
        illustration: NullStatusIllustration.proxies,
      );
    }

    return _ProxyGroupsList(
      key: ValueKey('proxy_groups_list_$currentProfileId'),
      groups: state.groups,
      columns: state.columns,
      cardType: state.proxyCardType,
      sortType: state.proxiesSortType,
      sortNum: state.sortNum,
      currentUnfoldSet: state.currentUnfoldSet,
    );
  }
}

class _ProxyGroupsList extends ConsumerStatefulWidget {
  final List<Group> groups;
  final int columns;
  final ProxyCardType cardType;
  final ProxiesSortType sortType;
  final num sortNum;
  final Set<String> currentUnfoldSet;

  const _ProxyGroupsList({
    super.key,
    required this.groups,
    required this.columns,
    required this.cardType,
    required this.sortType,
    required this.sortNum,
    required this.currentUnfoldSet,
  });

  @override
  ConsumerState<_ProxyGroupsList> createState() => _ProxyGroupsListState();
}

final Set<String> _mountedRows = <String>{};

class _ProxyGroupsListState extends ConsumerState<_ProxyGroupsList> {
  final ScrollController _scrollController = ScrollController();
  GroupOffsets _groupOffsets = GroupOffsets.empty;
  double _containerHeight = 0;
  final Set<String> _enterGroups = <String>{};
  final Set<String> _collapsingGroups = <String>{};
  int _toggleToken = 0;
  int _viewGeneration = 0;
  late Set<String> _unfoldSet;

  @override
  void initState() {
    super.initState();
    _unfoldSet = Set<String>.from(widget.currentUnfoldSet);
  }

  @override
  void didUpdateWidget(covariant _ProxyGroupsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!stringSetEquality.equals(oldWidget.currentUnfoldSet, widget.currentUnfoldSet)) {
      _unfoldSet = Set<String>.from(widget.currentUnfoldSet);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleToggle(String groupName) {
    final isExpanding = !_unfoldSet.contains(groupName);
    setState(() {
      if (isExpanding) {
        _unfoldSet.add(groupName);
        _enterGroups.add(groupName);
        _collapsingGroups.remove(groupName);
      } else {
        _unfoldSet.remove(groupName);
        _enterGroups.remove(groupName);
        _collapsingGroups.add(groupName);
      }
    });
    final next = Set<String>.from(_unfoldSet);
    final token = ++_toggleToken;
    globalState.appController.updateCurrentUnfoldSet(next);
    if (!isExpanding) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _toggleToken) return;
      if (_mountedRows.contains(groupName)) return;
      setState(() {
        _viewGeneration += 1;
      });
    });
  }

  GroupOffsets _getGroupOffsets({
    required List<Group> groups,
    required int columns,
    required Set<String> currentUnfoldSet,
    required ProxyCardType cardType,
  }) {
    final offsets = <double>[];
    final rowExtent = getItemHeight(cardType) + 8.0;
    const headerExtent = 72.0;
    var currentOffset = 16.0;
    for (final group in groups) {
      offsets.add(currentOffset);
      currentOffset += headerExtent;
      if (currentUnfoldSet.contains(group.name)) {
        final rowCount = (group.all.length + columns - 1) ~/ columns;
        currentOffset += rowCount * rowExtent;
      }
    }
    return GroupOffsets(groups, offsets);
  }

  void _animateToOffset(double targetOffset) {
    if (!mounted || !_scrollController.hasClients) return;
    final currentOffset = _scrollController.offset;
    final clampedTarget = targetOffset.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    final distance = (clampedTarget - currentOffset).abs();
    if (distance < 1.0) return;

    final durationMs = (240 + (distance * 0.1)).clamp(280, 400).toInt();
    _scrollController.animateTo(
      clampedTarget,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToSelected(String groupName) {
    if (!_scrollController.hasClients) return;
    final selectedName = ref
        .read(getSelectedProxyNameProvider(groupName))
        .getSafeValue('');
    if (selectedName.isEmpty) return;

    final group = widget.groups.getGroup(groupName);
    if (group == null) return;

    final sortedProxies = globalState.appController.getSortProxies(
      proxies: group.all,
      sortType: widget.sortType,
      testUrl: group.testUrl,
    );
    final proxyIndex = sortedProxies.indexWhere((p) => p.name == selectedName);
    if (proxyIndex < 0) return;

    final groupOffset = _groupOffsets.offsetOf(groupName);
    const headerExtent = 72.0;
    final rowExtent = getItemHeight(widget.cardType) + 8.0;
    final rowIndex = proxyIndex ~/ widget.columns;

    final nodeTop = groupOffset + headerExtent + rowIndex * rowExtent;
    final nodeBottom = nodeTop + rowExtent;

    final containerHeight = _containerHeight > 0
        ? _containerHeight
        : MediaQuery.sizeOf(context).height;

    final totalSpan = (nodeBottom + 8.0) - (groupOffset - 16.0);
    double targetOffset;
    if (totalSpan <= containerHeight) {
      targetOffset = groupOffset - 16.0;
    } else {
      targetOffset = (nodeTop - rowExtent - 16.0).clamp(
        groupOffset - 16.0,
        double.infinity,
      );
    }

    _animateToOffset(targetOffset);
  }

  final Map<String, _GroupRows> _rowsCache = <String, _GroupRows>{};

  List<List<Proxy>> _rowsOf({
    required Group group,
    required int columns,
  }) {
    final input = group.all;
    final sortType = widget.sortType;
    final testUrl = group.testUrl;
    final sortNum = widget.sortNum;
    final cached = _rowsCache[group.name];
    if (cached != null &&
        cached.columns == columns &&
        cached.sortType == sortType &&
        cached.testUrl == testUrl &&
        cached.sortNum == sortNum &&
        _sameProxies(cached.input, input)) {
      return cached.rows;
    }
    final sorted = globalState.appController.getSortProxies(
      proxies: input,
      sortType: sortType,
      testUrl: testUrl,
    );
    final rows = <List<Proxy>>[];
    for (var i = 0; i < sorted.length; i += columns) {
      final end = i + columns < sorted.length ? i + columns : sorted.length;
      rows.add(sorted.sublist(i, end));
    }
    _rowsCache[group.name] = _GroupRows(
      input: input,
      sortType: sortType,
      testUrl: testUrl,
      columns: columns,
      sortNum: sortNum,
      rows: rows,
    );
    return rows;
  }

  bool _sameProxies(List<Proxy> a, List<Proxy> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  Widget _buildGroup(
    BuildContext context, {
    required Group group,
    required bool isExpand,
    required bool enterAnimated,
    required bool isLast,
    required int columns,
    required ProxyCardType cardType,
  }) {
    final isCollapsing = _collapsingGroups.contains(group.name);
    final showList = isExpand || isCollapsing;
    final rows = showList
        ? _rowsOf(group: group, columns: columns)
        : const <List<Proxy>>[];

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: SizedBox(
              height: 64.0,
              child: _GroupHeader(
                key: ValueKey('header_${group.name}'),
                group: group,
                isExpand: isExpand,
                enterAnimated: enterAnimated,
                collapsing: isCollapsing,
                onToggle: () => _handleToggle(group.name),
                cardType: cardType,
                columns: columns,
                onScrollToSelected: () => _scrollToSelected(group.name),
              ),
            ),
          ),
        ),
        if (showList)
          _GroupProxyListSliver(
            key: ValueKey('expanded_group_${group.name}'),
            group: group,
            rows: rows,
            columns: columns,
            cardType: cardType,
            enterAnimated: enterAnimated,
            tail: isLast,
            collapseRequested: isCollapsing,
            onCollapsed: () {
              if (!mounted) return;
              setState(() {
                _collapsingGroups.remove(group.name);
              });
            },
            onEntered: () {
              if (!mounted) return;
              setState(() {
                _enterGroups.remove(group.name);
              });
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = ref.watch(isMobileViewProvider);

    return LayoutBuilder(
      key: ValueKey('proxies_list_view#$_viewGeneration'),
      builder: (context, constraints) {
        _containerHeight = max(constraints.maxHeight, 0);
        _groupOffsets = _getGroupOffsets(
          groups: widget.groups,
          columns: widget.columns,
          currentUnfoldSet: _unfoldSet,
          cardType: widget.cardType,
        );

        return CommonScrollBar(
          controller: _scrollController,
          feather: true,
          child: CustomScrollView(
            key: const PageStorageKey<String>('proxies_list'),
            controller: _scrollController,
            cacheExtent: 150.0,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              for (var i = 0; i < widget.groups.length; i++)
                _buildGroup(
                  context,
                  group: widget.groups[i],
                  isExpand: _unfoldSet.contains(widget.groups[i].name),
                  enterAnimated: _enterGroups.contains(widget.groups[i].name),
                  isLast: i == widget.groups.length - 1,
                  columns: widget.columns,
                  cardType: widget.cardType,
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: (globalState.isAndroidTV ? 48.0 : 16.0) +
                      (isMobileView
                          ? getFloatingBottomBarReserveHeight(context)
                          : 0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupProxyListSliver extends StatefulWidget {
  final Group group;
  final List<List<Proxy>> rows;
  final int columns;
  final ProxyCardType cardType;
  final bool enterAnimated;
  final bool tail;
  final bool collapseRequested;
  final VoidCallback? onCollapsed;
  final VoidCallback? onEntered;

  const _GroupProxyListSliver({
    super.key,
    required this.group,
    required this.rows,
    required this.columns,
    required this.cardType,
    this.enterAnimated = true,
    this.tail = false,
    this.collapseRequested = false,
    this.onCollapsed,
    this.onEntered,
  });

  @override
  State<_GroupProxyListSliver> createState() => _GroupProxyListSliverState();
}

class _GroupProxyListSliverState extends State<_GroupProxyListSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _reveal;
  late Widget _list;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _listRevealDuration,
    );
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic.flipped,
    );
    _controller.addStatusListener(_handleStatus);
    _syncList();
    _mountedRows.add(widget.group.name);
    if (widget.enterAnimated) {
      _controller.removeStatusListener(_handleStatus);
      _controller.value = 1;
      _controller.addStatusListener(_handleStatus);
      _runTo(0.0);
    }
  }

  @override
  void didUpdateWidget(covariant _GroupProxyListSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enterAnimated &&
        _controller.value == 1 &&
        !_controller.isAnimating) {
      _runTo(0.0);
    }
    if (widget.collapseRequested && !oldWidget.collapseRequested) {
      _runTo(1.0);
    } else if (!widget.collapseRequested && oldWidget.collapseRequested) {
      if (_controller.value > 0) {
        _runTo(0.0);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onEntered?.call();
        });
      }
    }
    if (!_sameRows(widget.rows, oldWidget.rows) ||
        widget.columns != oldWidget.columns ||
        widget.cardType != oldWidget.cardType ||
        widget.group.type != oldWidget.group.type ||
        widget.group.testUrl != oldWidget.group.testUrl) {
      _syncList();
    }
  }

  void _runTo(double target) {
    _settleTimer?.cancel();
    _settleTimer = null;
    final tickerEnabled = TickerMode.getNotifier(context).value;
    if (!tickerEnabled || _controller.value == target) {
      _snapTo(target);
      return;
    }
    if (target == 0.0) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    _settleTimer = Timer(
      _listRevealDuration + const Duration(milliseconds: 60),
      () {
        _settleTimer = null;
        if (!mounted) return;
        if (_controller.value == target) return;
        _snapTo(target);
      },
    );
  }

  void _snapTo(double target) {
    _settleTimer?.cancel();
    _settleTimer = null;
    _controller.stop();
    _controller.removeStatusListener(_handleStatus);
    if (_controller.value != target) {
      _controller.value = target;
    }
    _controller.addStatusListener(_handleStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleStatus(
        target == 0.0
            ? AnimationStatus.dismissed
            : AnimationStatus.completed,
      );
    });
  }

  bool _sameRows(List<List<Proxy>> a, List<List<Proxy>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final rowA = a[i];
      final rowB = b[i];
      if (rowA.length != rowB.length) return false;
      for (var j = 0; j < rowA.length; j++) {
        if (!identical(rowA[j], rowB[j])) return false;
      }
    }
    return true;
  }

  void _handleStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && widget.collapseRequested) {
      widget.onCollapsed?.call();
    } else if (status == AnimationStatus.dismissed && widget.enterAnimated) {
      widget.onEntered?.call();
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _mountedRows.remove(widget.group.name);
    _controller.dispose();
    super.dispose();
  }

  void _syncList() {
    _list = SliverFixedExtentList(
      itemExtent: getItemHeight(widget.cardType) + 8.0,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildProxyRow(context, index),
        childCount: widget.rows.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }

  Widget _buildProxyRow(BuildContext context, int rowIndex) {
    final proxies = widget.rows[rowIndex];
    final groupName = widget.group.name;
    final cardWidgets = <Widget>[];

    for (var i = 0; i < widget.columns; i++) {
      if (i < proxies.length) {
        final proxy = proxies[i];
        cardWidgets.add(
          Expanded(
            child: ProxyCard(
              key: ValueKey('$groupName.${proxy.name}'),
              proxy: proxy,
              groupName: groupName,
              type: widget.cardType,
              groupType: widget.group.type,
              testUrl: widget.group.testUrl,
            ),
          ),
        );
      } else {
        cardWidgets.add(const Expanded(child: SizedBox()));
      }
    }

    final rowChildren = <Widget>[];
    for (var i = 0; i < cardWidgets.length; i++) {
      rowChildren.add(cardWidgets[i]);
      if (i < cardWidgets.length - 1) {
        rowChildren.add(const SizedBox(width: 8));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: SizedBox(
        height: getItemHeight(widget.cardType),
        child: Row(children: rowChildren),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.collapseRequested ? 1.0 : 0.0;
    if (!_controller.isAnimating && _controller.value != target) {
      _snapTo(target);
    }
    return AnimatedBuilder(
      animation: _controller,
      child: _list,
      builder: (context, list) {
        final factor = 1.0 - _reveal.value;
        final clipContent = !widget.tail;
        final veil = _controller.value;
        return _AnimatedExtentSliver(
          factor: widget.tail && !widget.collapseRequested ? 1.0 : factor,
          clipContent: clipContent,
          veil: veil <= 0
              ? null
              : context.colorScheme.surface.withValues(alpha: veil),
          child: list!,
        );
      },
    );
  }
}

class _AnimatedExtentSliver extends SingleChildRenderObjectWidget {
  final double factor;
  final bool clipContent;
  final Color? veil;

  const _AnimatedExtentSliver({
    required super.child,
    required this.factor,
    required this.clipContent,
    this.veil,
  });

  @override
  _RenderAnimatedExtentSliver createRenderObject(BuildContext context) {
    return _RenderAnimatedExtentSliver(factor, clipContent, veil);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnimatedExtentSliver renderObject,
  ) {
    renderObject
      ..factor = factor
      ..clipContent = clipContent
      ..veil = veil;
  }
}

class _RenderAnimatedExtentSliver extends RenderProxySliver {
  _RenderAnimatedExtentSliver(this._factor, this._clipContent, this._veil);

  static const _edgeGap = 8.0;

  double _factor;
  bool _clipContent;
  Color? _veil;

  bool get clipContent => _clipContent;

  set clipContent(bool value) {
    if (_clipContent == value) return;
    _clipContent = value;
    markNeedsPaint();
  }

  Color? get veil => _veil;

  set veil(Color? value) {
    if (_veil == value) return;
    _veil = value;
    markNeedsPaint();
  }

  double get factor => _factor;

  set factor(double value) {
    final next = value.clamp(0.0, 1.0);
    if (_factor == next) return;
    _factor = next;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final childGeometry = child.geometry ?? SliverGeometry.zero;
    final factor = _factor;
    if (factor >= 1.0) {
      geometry = childGeometry;
      return;
    }
    if (factor <= 0.0) {
      geometry = SliverGeometry.zero;
      return;
    }
    final paintExtent = childGeometry.paintExtent * factor;
    final layoutExtent = childGeometry.layoutExtent * factor;
    final scrollExtent = childGeometry.scrollExtent * factor;
    final maxPaintExtent = childGeometry.maxPaintExtent * factor;
    final hitTestExtent = childGeometry.hitTestExtent * factor;
    geometry = SliverGeometry(
      paintOrigin: childGeometry.paintOrigin,
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      layoutExtent: layoutExtent,
      maxPaintExtent: maxPaintExtent,
      cacheExtent: childGeometry.cacheExtent,
      maxScrollObstructionExtent: childGeometry.maxScrollObstructionExtent,
      visible: childGeometry.visible,
      hitTestExtent: hitTestExtent,
      hasVisualOverflow: true,
      scrollOffsetCorrection: childGeometry.scrollOffsetCorrection,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final factor = _factor;
    if (!_clipContent || factor >= 1.0) {
      layer = null;
      super.paint(context, offset);
      _paintVeil(context, offset);
      return;
    }
    final paintExtent = geometry?.paintExtent ?? 0.0;
    final coreExtent = max(paintExtent - _edgeGap, 0.0);
    if (coreExtent <= 0) {
      layer = null;
      return;
    }
    final crossExtent = constraints.crossAxisExtent;
    final isVertical = constraints.axis == Axis.vertical;
    final coreSize = isVertical
        ? Size(crossExtent, coreExtent)
        : Size(coreExtent, crossExtent);
    layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & coreSize,
      (context, offset) {
        super.paint(context, offset);
        _paintVeil(context, offset);
      },
      oldLayer: layer as ClipRectLayer?,
    );
  }

  void _paintVeil(PaintingContext context, Offset offset) {
    final veil = _veil;
    if (veil == null) return;
    final extent = max(
      geometry?.paintExtent ?? 0.0,
      child?.geometry?.paintExtent ?? 0.0,
    );
    if (extent <= 0) return;
    final crossExtent = constraints.crossAxisExtent;
    final size = constraints.axis == Axis.vertical
        ? Size(crossExtent, extent)
        : Size(extent, crossExtent);
    context.canvas.drawRect(offset & size, Paint()..color = veil);
  }
}

class _GroupHeader extends ConsumerWidget {
  final Group group;
  final bool isExpand;
  final bool enterAnimated;
  final bool collapsing;
  final VoidCallback onToggle;
  final ProxyCardType cardType;
  final int columns;
  final VoidCallback? onScrollToSelected;

  const _GroupHeader({
    super.key,
    required this.group,
    required this.isExpand,
    this.enterAnimated = false,
    this.collapsing = false,
    required this.onToggle,
    required this.cardType,
    required this.columns,
    this.onScrollToSelected,
  });

  static final _circleButtonStyle = IconButton.styleFrom(
    shape: const CircleBorder(),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.all(2),
    fixedSize: const Size(32, 32),
    minimumSize: const Size(32, 32),
  );

  static final _circleFilledTonalStyle = IconButton.styleFrom(
    shape: const CircleBorder(),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.all(2),
    fixedSize: const Size(32, 32),
    minimumSize: const Size(32, 32),
  );

  static const _expandButtonWidth = 32.0;
  static const _actionsGap = 6.0;
  static const _actionsRightOffset = _expandButtonWidth + _actionsGap;

  static const _actionsDuration = Duration(milliseconds: 160);

  Widget _buildActionTransition(double value, Widget? child) {
    return Opacity(
      opacity: value,
      child: Transform.scale(
        scale: 0.7 + 0.3 * value,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _wrapAction({required Widget child, required String key}) {
    if (collapsing) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        duration: _actionsDuration,
        curve: Curves.fastOutSlowIn,
        child: child,
        builder: (_, value, c) => _buildActionTransition(value, c),
      );
    }
    if (!enterAnimated) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(key),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: _actionsDuration,
      curve: Curves.fastOutSlowIn,
      builder: (_, value, c) => _buildActionTransition(value, c),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconStyle = ref.watch(
      proxiesStyleSettingProvider.select((s) => s.iconStyle),
    );
    final icon = ref.watch(proxyIconProvider(group.name));
    final nameEmoji = getFirstEmoji(group.name);
    final useEmojiIcon =
        iconStyle != ProxiesIconStyle.none &&
        icon.isEmpty &&
        nameEmoji.isNotEmpty;
    final selectedProxyName = ref
        .watch(getSelectedProxyNameProvider(group.name))
        .getSafeValue('');

    final selectedProxyIcon = ref.watch(
      proxyIconProvider(selectedProxyName),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _wrapAction(
          key: 'locate_${group.name}',
          child: IconButton(
            key: ValueKey('locate_${group.name}'),
            style: _circleButtonStyle,
            iconSize: 19,
            icon: const Icon(FluentIcons.target_arrow_24_regular),
            onPressed: onScrollToSelected,
            tooltip: appLocalizations.locate,
          ),
        ),
        const SizedBox(width: 2),
        _wrapAction(
          key: 'delay_${group.name}',
          child: AnimatedBuilder(
            key: ValueKey('delay_test_${group.name}'),
            animation: delayTestCoordinator,
            builder: (_, _) {
              final isTestingThisGroup = delayTestCoordinator.isTestingGroup(
                group.name,
              );
              return IconButton(
                style: _circleButtonStyle,
                iconSize: 20,
                icon: isTestingThisGroup
                    ? SizedBox.square(
                        dimension: 18,
                        child: SpinKitFadingCircle(
                          color: context.colorScheme.primary,
                          size: 18,
                        ),
                      )
                    : const Icon(FluentIcons.top_speed_24_regular),
                onPressed: delayTestCoordinator.isTesting
                    ? null
                    : () => _delayTest(context),
                tooltip: appLocalizations.startTest,
              );
            },
          ),
        ),
      ],
    );

    final headerRow = Row(
      children: [
        _buildIcon(
          context,
          iconStyle,
          icon,
          emoji: useEmojiIcon ? nameEmoji : '',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              EmojiText(
                useEmojiIcon ? removeLeadingEmoji(group.name) : group.name,
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    group.type.name,
                    style: context.textTheme.labelMedium?.toLight,
                  ),
                  if (selectedProxyName.isNotEmpty) ...[
                    Text(
                      '  •  ',
                      style: context.textTheme.labelMedium?.toLight,
                    ),
                    if (selectedProxyIcon.isNotEmpty) ...[
                      CommonTargetIcon(
                        src: selectedProxyIcon,
                        size: globalState.measure.labelMediumHeight,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: EmojiText(
                        selectedProxyName,
                        style: context.textTheme.labelMedium?.toLight,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (isExpand && !collapsing) ...[
          actions,
          const SizedBox(width: _actionsGap),
        ],
        IconButton.filledTonal(
          key: ValueKey('expand_${group.name}'),
          style: _circleFilledTonalStyle,
          iconSize: 24,
          icon: CommonExpandIcon(expand: isExpand),
          onPressed: onToggle,
        ),
      ],
    );

    return CommonCard(
      radius: 20,
      type: CommonCardType.filled,
      onPressed: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Stack(
          children: [
            headerRow,
            if (collapsing)
              Positioned(
                top: 0,
                bottom: 0,
                right: _actionsRightOffset,
                child: Center(child: actions),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiIcon(String emoji, double size) {
    return EmojiText(
      emoji,
      style: TextStyle(fontSize: size * 0.75, height: 1.2),
    );
  }

  Widget _buildIcon(
    BuildContext context,
    ProxiesIconStyle style,
    String icon, {
    String emoji = '',
  }) {
    if (style == ProxiesIconStyle.none) return const SizedBox();
    const iconSize = 40.0;
    if (style == ProxiesIconStyle.standard) {
      return Container(
        margin: const EdgeInsets.only(right: 16),
        width: iconSize,
        height: iconSize,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: context.colorScheme.secondaryContainer,
        ),
        clipBehavior: Clip.antiAlias,
        child: emoji.isNotEmpty
            ? _buildEmojiIcon(emoji, iconSize - 12)
            : CommonTargetIcon(src: icon, size: iconSize - 12),
      );
    }
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: iconSize,
      height: iconSize,
      alignment: Alignment.center,
      child: emoji.isNotEmpty
          ? _buildEmojiIcon(emoji, iconSize - 8)
          : CommonTargetIcon(src: icon, size: iconSize - 8),
    );
  }

  Future<void> _delayTest(BuildContext context) async {
    await delayTest(group.all, testUrl: group.testUrl, groupName: group.name);
  }
}

class _GroupRows {
  final List<Proxy> input;
  final ProxiesSortType sortType;
  final String? testUrl;
  final int columns;
  final num sortNum;
  final List<List<Proxy>> rows;

  const _GroupRows({
    required this.input,
    required this.sortType,
    required this.testUrl,
    required this.columns,
    required this.sortNum,
    required this.rows,
  });
}
