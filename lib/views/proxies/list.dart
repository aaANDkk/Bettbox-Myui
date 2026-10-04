import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';

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
  final Map<String, List<Proxy>> _cachedSortedProxiesMap = {};

  List<Proxy> _getGroupSortedProxies(Group group) {
    return _cachedSortedProxiesMap.putIfAbsent(
      group.name,
      () => globalState.appController.getSortProxies(
        proxies: group.all,
        sortType: widget.sortType,
        testUrl: group.testUrl,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _ProxyGroupsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.groups, oldWidget.groups) ||
        widget.sortType != oldWidget.sortType ||
        widget.sortNum != oldWidget.sortNum) {
      _cachedSortedProxiesMap.clear();
    }
  }

  void _handleToggle(String groupName) {
    final tempUnfoldSet = Set<String>.from(widget.currentUnfoldSet);
    if (tempUnfoldSet.contains(groupName)) {
      tempUnfoldSet.remove(groupName);
    } else {
      tempUnfoldSet.add(groupName);
    }
    globalState.appController.updateCurrentUnfoldSet(tempUnfoldSet);
  }

  double _getHeaderHeight() {
    final measure = globalState.measure;
    final contentRowHeight = [
      40.0,
      measure.titleMediumHeight + 4 + measure.labelMediumHeight,
    ].reduce((a, b) => a > b ? a : b);
    return 28.0 + contentRowHeight;
  }

  void _scrollToSelected(String groupName) {
    if (!_scrollController.hasClients) return;
    final selectedName = ref
        .read(getSelectedProxyNameProvider(groupName))
        .getSafeValue('');
    if (selectedName.isEmpty) return;

    final headerHeight = _getHeaderHeight();
    final itemHeight = getItemHeight(widget.cardType);
    final autoStickyHeader = ref.read(
      proxiesStyleSettingProvider.select((s) => s.autoStickyHeader),
    );

    var targetOffset = 16.0;
    Group? targetGroup;
    for (final group in widget.groups) {
      if (group.name == groupName) {
        targetGroup = group;
        break;
      }
      final isExpand = widget.currentUnfoldSet.contains(group.name);
      final rowCount = isExpand
          ? (_getGroupSortedProxies(group).length / widget.columns).ceil()
          : 0;
      targetOffset += headerHeight + 8.0 + rowCount * (itemHeight + 8.0);
    }
    final group = targetGroup;
    if (group == null) return;

    final sortedProxies = _getGroupSortedProxies(group);
    final proxyIndex = sortedProxies.indexWhere((p) => p.name == selectedName);
    if (proxyIndex >= 0) {
      final rowIndex = proxyIndex ~/ widget.columns;
      if (autoStickyHeader) {
        targetOffset += rowIndex * (itemHeight + 8.0);
      } else {
        targetOffset += headerHeight + 8.0 + rowIndex * (itemHeight + 8.0);
      }
    }

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  Widget _buildRow(
    Group group,
    List<Proxy> sortedProxies,
    int rowIndex,
    double itemHeight,
  ) {
    final start = rowIndex * widget.columns;
    final end = start + widget.columns < sortedProxies.length
        ? start + widget.columns
        : sortedProxies.length;
    final rowProxies = sortedProxies.sublist(start, end);

    final cardWidgets = <Widget>[];
    for (var i = 0; i < widget.columns; i++) {
      if (i < rowProxies.length) {
        final proxy = rowProxies[i];
        cardWidgets.add(
          Expanded(
            child: ProxyCard(
              key: ValueKey('${group.name}.${proxy.name}'),
              proxy: proxy,
              groupName: group.name,
              type: widget.cardType,
              groupType: group.type,
              testUrl: group.testUrl,
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
      key: ValueKey('row_${group.name}_$rowIndex'),
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: itemHeight,
        child: Row(children: rowChildren),
      ),
    );
  }

  Widget _buildGroupSliver(
    Group group,
    double headerHeight,
    double itemHeight,
    bool autoStickyHeader,
  ) {
    final isExpand = widget.currentUnfoldSet.contains(group.name);
    final sortedProxies = isExpand
        ? _getGroupSortedProxies(group)
        : const <Proxy>[];
    final rowCount = (sortedProxies.length / widget.columns).ceil();

    return SliverStickyHeader(
      key: ValueKey('group_${group.name}'),
      pinned: autoStickyHeader,
      spacing: 8,
      header: SizedBox(
        height: headerHeight,
        child: _GroupHeader(
          key: ValueKey('header_${group.name}'),
          group: group,
          isExpand: isExpand,
          onToggle: () => _handleToggle(group.name),
          cardType: widget.cardType,
          columns: widget.columns,
          onScrollToSelected: () => _scrollToSelected(group.name),
        ),
      ),
      sliver: SliverFixedExtentList(
        itemExtent: itemHeight + 8,
        delegate: SliverChildBuilderDelegate(
          (context, rowIndex) =>
              _buildRow(group, sortedProxies, rowIndex, itemHeight),
          childCount: rowCount,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = ref.watch(isMobileViewProvider);
    final autoStickyHeader = ref.watch(
      proxiesStyleSettingProvider.select((s) => s.autoStickyHeader),
    );
    final itemHeight = getItemHeight(widget.cardType);
    final headerHeight = _getHeaderHeight();

    return CommonScrollBar(
      controller: _scrollController,
      child: CustomScrollView(
        key: const PageStorageKey<String>('proxies_list'),
        controller: _scrollController,
        scrollCacheExtent: isMobileView
            ? const ScrollCacheExtent.pixels(120.0)
            : const ScrollCacheExtent.pixels(250.0),
        clipBehavior: Clip.hardEdge,
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
          for (final group in widget.groups)
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              sliver: _buildGroupSliver(
                group,
                headerHeight,
                itemHeight,
                autoStickyHeader,
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom:
                  (globalState.isAndroidTV ? 48.0 : 16.0) +
                  (isMobileView
                      ? getFloatingBottomBarReserveHeight(context)
                      : 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  final Group group;
  final bool isExpand;
  final VoidCallback onToggle;
  final ProxyCardType cardType;
  final int columns;
  final VoidCallback? onScrollToSelected;

  const _GroupHeader({
    super.key,
    required this.group,
    required this.isExpand,
    required this.onToggle,
    required this.cardType,
    required this.columns,
    this.onScrollToSelected,
  });

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
      radius: 16,
      type: CommonCardType.filled,
      onPressed: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildIcon(context, iconStyle, icon),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiText(
                    group.name,
                    style: context.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            _ExpandableGroupActions(
              isExpand: isExpand,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 4),
                  SizedBox.square(
                    dimension: 40,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.adjust),
                      onPressed: onScrollToSelected,
                      tooltip: appLocalizations.locate,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: delayTestCoordinator,
                    builder: (_, _) {
                      final isTestingThisGroup = delayTestCoordinator
                          .isTestingGroup(group.name);
                      return SizedBox(
                        width: 48,
                        height: 40,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: isTestingThisGroup
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.network_ping),
                          onPressed: delayTestCoordinator.isTesting
                              ? null
                              : () => _delayTest(context),
                          tooltip: appLocalizations.startTest,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            SizedBox.square(
              dimension: 40,
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                icon: CommonExpandIcon(expand: isExpand),
                onPressed: onToggle,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused)) {
                      return context.colorScheme.primary.withValues(alpha: 0.2);
                    }
                    return null;
                  }),
                ),
              ),
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

class _ExpandableGroupActions extends StatelessWidget {
  final bool isExpand;
  final Widget child;

  const _ExpandableGroupActions({
    required this.isExpand,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.centerRight,
        widthFactor: isExpand ? 1.0 : 0.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          opacity: isExpand ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !isExpand,
            child: SizedBox(
              width: 100,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
