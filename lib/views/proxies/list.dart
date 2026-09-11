import 'dart:async';
import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'card.dart';
import 'common.dart';

const _staggerRowStepMs = 26;
const _staggerColStepMs = 8;
const _cardDuration = Duration(milliseconds: 320);

class ProxiesListView extends ConsumerWidget {
  const ProxiesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proxiesListStateProvider);

    if (state.groups.isEmpty) {
      return NullStatus(
        label: appLocalizations.nullTip(appLocalizations.proxies),
      );
    }

    return _ProxyGroupsList(
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

class _ProxyGroupsListState extends ConsumerState<_ProxyGroupsList> {
  final ScrollController _scrollController = ScrollController();
  GroupOffsets _groupOffsets = GroupOffsets.empty;
  double _containerHeight = 0;
  String? _enterGroupName;
  Timer? _enterTimer;

  @override
  void dispose() {
    _enterTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  int _calculateMaxVisibleRows() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final rowHeight = getItemHeight(widget.cardType) + 8.0;
    return (screenHeight / rowHeight).ceil() + 2;
  }

  void _startEnterAnimated(String groupName) {
    _enterTimer?.cancel();
    _enterGroupName = groupName;
    const enterWindow = Duration(milliseconds: 600);
    _enterTimer = Timer(enterWindow, () {
      if (mounted) {
        setState(() {
          _enterGroupName = null;
        });
      }
    });
  }

  void _handleToggle(String groupName) {
    final tempUnfoldSet = Set<String>.from(widget.currentUnfoldSet);
    final isExpanding = !tempUnfoldSet.contains(groupName);
    if (isExpanding) {
      tempUnfoldSet.add(groupName);
      _startEnterAnimated(groupName);
      _autoScrollToGroup(groupName);
    } else {
      tempUnfoldSet.remove(groupName);
      _enterTimer?.cancel();
      _enterGroupName = null;
    }
    globalState.appController.updateCurrentUnfoldSet(tempUnfoldSet);
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

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 16.0,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start - padding;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start - padding;
      }
    }

    _animateToOffset(targetScrollOffset);
  }

  void _autoScrollToGroup(String groupName) {
    if (!_scrollController.hasClients || _containerHeight <= 0) return;
    final pixels = _scrollController.position.pixels;
    final offset = _groupOffsets.offsetOf(groupName);
    const headerExtent = 72.0;
    _scrollToMakeVisibleWithPadding(
      containerHeight: _containerHeight,
      pixels: pixels,
      start: offset,
      end: offset + headerExtent,
      padding: 16.0,
    );
  }

  void _scrollToSelected(String groupName) {
    if (!_scrollController.hasClients) return;
    final selectedName = ref
        .read(getSelectedProxyNameProvider(groupName))
        .getSafeValue('');
    if (selectedName.isEmpty) return;

    if (_enterGroupName != null) {
      _enterTimer?.cancel();
      _enterGroupName = null;
    }

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

  Widget _buildGroup(
    BuildContext context, {
    required Group group,
    required bool isExpand,
    required bool enterAnimated,
    required int columns,
    required ProxyCardType cardType,
    required int maxVisibleRows,
  }) {
    final sortedProxies = isExpand
        ? globalState.appController.getSortProxies(
            proxies: group.all,
            sortType: widget.sortType,
            testUrl: group.testUrl,
          )
        : const <Proxy>[];

    final rows = <List<Proxy>>[];
    if (isExpand) {
      for (var i = 0; i < sortedProxies.length; i += columns) {
        final end = (i + columns < sortedProxies.length)
            ? i + columns
            : sortedProxies.length;
        rows.add(sortedProxies.sublist(i, end));
      }
    }

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
                onToggle: () => _handleToggle(group.name),
                cardType: cardType,
                columns: columns,
                onScrollToSelected: () => _scrollToSelected(group.name),
              ),
            ),
          ),
        ),
        if (isExpand)
          _GroupProxyListSliver(
            key: ValueKey('expanded_group_${group.name}'),
            group: group,
            rows: rows,
            columns: columns,
            cardType: cardType,
            maxVisibleRows: maxVisibleRows,
            enterAnimated: enterAnimated,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = ref.watch(isMobileViewProvider);
    final maxVisibleRows = _calculateMaxVisibleRows();

    return LayoutBuilder(
      builder: (context, constraints) {
        _containerHeight = max(constraints.maxHeight, 0);
        _groupOffsets = _getGroupOffsets(
          groups: widget.groups,
          columns: widget.columns,
          currentUnfoldSet: widget.currentUnfoldSet,
          cardType: widget.cardType,
        );

        return CommonScrollBar(
          controller: _scrollController,
          child: CustomScrollView(
            key: const PageStorageKey<String>('proxies_list'),
            controller: _scrollController,
            cacheExtent: 1000.0,
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),
              for (final group in widget.groups)
                _buildGroup(
                  context,
                  group: group,
                  isExpand: widget.currentUnfoldSet.contains(group.name),
                  enterAnimated: _enterGroupName == group.name,
                  columns: widget.columns,
                  cardType: widget.cardType,
                  maxVisibleRows: maxVisibleRows,
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
  final int maxVisibleRows;
  final bool enterAnimated;

  const _GroupProxyListSliver({
    super.key,
    required this.group,
    required this.rows,
    required this.columns,
    required this.cardType,
    required this.maxVisibleRows,
    this.enterAnimated = true,
  });

  @override
  State<_GroupProxyListSliver> createState() => _GroupProxyListSliverState();
}

class _GroupProxyListSliverState extends State<_GroupProxyListSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isAnimationCompleted = false;

  @override
  void initState() {
    super.initState();
    final maxDelayMs =
        widget.maxVisibleRows * _staggerRowStepMs +
        widget.columns * _staggerColStepMs;
    final totalWindow = _cardDuration + Duration(milliseconds: maxDelayMs);
    _controller = AnimationController(vsync: this, duration: totalWindow);
    if (widget.enterAnimated) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _isAnimationCompleted = true;
          });
        }
      });
      _controller.forward();
    } else {
      _isAnimationCompleted = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildProxyRow(BuildContext context, int rowIndex) {
    final proxies = widget.rows[rowIndex];
    final groupName = widget.group.name;
    final totalWindowMs = _controller.duration!.inMilliseconds;
    final cardWidgets = <Widget>[];

    for (var i = 0; i < widget.columns; i++) {
      if (i < proxies.length) {
        final proxy = proxies[i];
        final card = ProxyCard(
          key: ValueKey('$groupName.${proxy.name}'),
          proxy: proxy,
          groupName: groupName,
          type: widget.cardType,
          groupType: widget.group.type,
          testUrl: widget.group.testUrl,
        );
        if (_isAnimationCompleted || rowIndex >= widget.maxVisibleRows) {
          cardWidgets.add(Expanded(child: card));
        } else {
          final delayMs = rowIndex * _staggerRowStepMs + i * _staggerColStepMs;
          final start = delayMs / totalWindowMs;
          final end = (delayMs + _cardDuration.inMilliseconds) / totalWindowMs;
          final itemAnimation = CurvedAnimation(
            parent: _controller,
            curve: Interval(
              start.clamp(0.0, 1.0),
              end.clamp(0.0, 1.0),
              curve: Curves.linear,
            ),
          );
          cardWidgets.add(
            Expanded(
              child: FadeSlideEnterTransition(
                animation: itemAnimation,
                distance: 18.0,
                child: card,
              ),
            ),
          );
        }
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
    return SliverFixedExtentList(
      itemExtent: getItemHeight(widget.cardType) + 8.0,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildProxyRow(context, index),
        childCount: widget.rows.length,
      ),
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  final Group group;
  final bool isExpand;
  final bool enterAnimated;
  final VoidCallback onToggle;
  final ProxyCardType cardType;
  final int columns;
  final VoidCallback? onScrollToSelected;

  const _GroupHeader({
    super.key,
    required this.group,
    required this.isExpand,
    this.enterAnimated = false,
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

  Widget _buildActionScale({
    required Widget child,
    required String key,
  }) {
    if (!enterAnimated) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(key),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
      builder: (_, scale, c) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: c,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconStyle = ref.watch(
      proxiesStyleSettingProvider.select((s) => s.iconStyle),
    );
    final icon = ref.watch(proxyIconProvider(group.name));
    final selectedProxyName = ref
        .watch(getSelectedProxyNameProvider(group.name))
        .getSafeValue('');

    final selectedProxyIcon = ref.watch(
      proxyIconProvider(selectedProxyName),
    );

    return CommonCard(
      radius: 20,
      type: CommonCardType.filled,
      onPressed: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildIcon(context, iconStyle, icon),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiText(group.name, style: context.textTheme.titleMedium),
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
            if (isExpand) ...[
              _buildActionScale(
                key: 'locate_${group.name}',
                child: IconButton(
                  key: ValueKey('locate_${group.name}'),
                  style: _circleButtonStyle,
                  iconSize: 19,
                  icon: const Icon(Icons.adjust),
                  onPressed: onScrollToSelected,
                  tooltip: appLocalizations.locate,
                ),
              ),
              const SizedBox(width: 2),
              _buildActionScale(
                key: 'delay_${group.name}',
                child: AnimatedBuilder(
                  key: ValueKey('delay_test_${group.name}'),
                  animation: delayTestCoordinator,
                  builder: (_, _) {
                    final isTestingThisGroup = delayTestCoordinator
                        .isTestingGroup(group.name);
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
                          : const Icon(Icons.network_ping),
                      onPressed: delayTestCoordinator.isTesting
                          ? null
                          : () => _delayTest(context),
                      tooltip: appLocalizations.startTest,
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
            ],
            IconButton.filledTonal(
              key: ValueKey('expand_${group.name}'),
              style: _circleFilledTonalStyle,
              iconSize: 24,
              icon: CommonExpandIcon(expand: isExpand),
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, ProxiesIconStyle style, String icon) {
    if (style == ProxiesIconStyle.none) return const SizedBox();
    const iconSize = 40.0;
    if (style == ProxiesIconStyle.standard) {
      return Container(
        margin: const EdgeInsets.only(right: 16),
        width: iconSize,
        height: iconSize,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.colorScheme.secondaryContainer,
        ),
        clipBehavior: Clip.antiAlias,
        child: CommonTargetIcon(src: icon, size: iconSize - 12),
      );
    }
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: iconSize,
      height: iconSize,
      alignment: Alignment.center,
      child: CommonTargetIcon(src: icon, size: iconSize - 8),
    );
  }

  Future<void> _delayTest(BuildContext context) async {
    await delayTest(group.all, testUrl: group.testUrl, groupName: group.name);
  }
}
