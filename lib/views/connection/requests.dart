import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';

class RequestsView extends ConsumerStatefulWidget {
  const RequestsView({super.key});

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController;
  late final AppBarSearchState _searchState;
  var _autoScrollToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ReverseScrollController();
    _searchState = AppBarSearchState(onSearch: _onSearch);
    WidgetsBinding.instance.addObserver(this);
    _initRequests();
  }

  bool _isListEqual(List<TrackerInfo> a, List<TrackerInfo> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _initRequests() async {
    clashCore.startTrackRequests();
    final history = await clashCore.getRequests();
    if (!mounted) return;
    if (history.isNotEmpty) {
      final current = ref.read(requestsProvider).list;
      if (!_isListEqual(current, history)) {
        ref.read(requestsProvider.notifier).setRequests(history);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final pos = _scrollController.position;
          if (pos.maxScrollExtent > 0) {
            _scrollController.jumpTo(pos.maxScrollExtent);
          }
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      clashCore.stopTrackRequests();
    } else if (state == AppLifecycleState.resumed) {
      _initRequests();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clashCore.stopTrackRequests();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(requestsSearchProvider.notifier).state = value;
  }

  void _onKeywordsUpdate(List<String> keywords) {
    ref.read(requestsKeywordsProvider.notifier).state = keywords;
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScrollToEnd = !_autoScrollToEnd;
    });
  }

  void _cancelAutoScroll() {
    if (_autoScrollToEnd) {
      setState(() {
        _autoScrollToEnd = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(filteredRequestsProvider);
    final hasRequests = requests.isNotEmpty;

    return CommonScaffold(
      title: appLocalizations.requests,
      actions: [
        IconButton(
          onPressed: () {
            ref.read(requestsProvider.notifier).clearRequests();
            clashCore.clearRequests();
          },
          tooltip: appLocalizations.clear,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        IconButton(
          style: _autoScrollToEnd
              ? ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    context.colorScheme.secondaryContainer,
                  ),
                )
              : null,
          onPressed: _toggleAutoScroll,
          tooltip: appLocalizations.autoScroll,
          icon: const Icon(Icons.vertical_align_top_outlined),
        ),
      ],
      searchState: _searchState,
      onKeywordsUpdate: _onKeywordsUpdate,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: !hasRequests
            ? NullStatus(
                key: const ValueKey('null'),
                label: appLocalizations.nullTip(appLocalizations.requests),
              )
            : LayoutBuilder(
                key: const ValueKey('list'),
                builder: (context, constraints) {
                  final isCompact =
                      requests.length * (TrackerInfoItem.height + 1) + 24 <
                      constraints.maxHeight;
                  return CommonScrollBar(
                    trackVisibility: false,
                    controller: _scrollController,
                    child: ScrollToEndBox(
                      controller: _scrollController,
                      dataSource: requests,
                      enable: _autoScrollToEnd,
                      reverse: true,
                      onCancelToEnd: _cancelAutoScroll,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ListView.builder(
                          reverse: true,
                          shrinkWrap: isCompact,
                          physics: const NextClampingScrollPhysics(),
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 16, top: 8),
                          itemBuilder: (context, index) {
                            final trackerInfo = requests[index];
                            return TrackerInfoItem(
                              key: ValueKey(trackerInfo.id),
                              index: index,
                              count: requests.length,
                              reversed: true,
                              trackerInfo: trackerInfo,
                              onClickKeyword: (value) {
                                context.commonScaffoldState?.addKeyword(value);
                              },
                              detailTitle: appLocalizations.details,
                            );
                          },
                          itemExtent: TrackerInfoItem.height + 1,
                          itemCount: requests.length,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
