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
  var _autoScrollToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ReverseScrollController();
    WidgetsBinding.instance.addObserver(this);
    _initRequests();
  }

  void _initRequests() async {
    clashCore.startTrackRequests();
    final history = await clashCore.getRequests();
    if (!mounted) return;
    if (history.isNotEmpty) {
      ref.read(requestsProvider.notifier).setRequests(history);
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
      searchState: AppBarSearchState(onSearch: _onSearch),
      onKeywordsUpdate: _onKeywordsUpdate,
      body: !hasRequests
          ? NullStatus(
              label: appLocalizations.nullTip(appLocalizations.requests),
            )
          : CommonScrollBar(
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
                    shrinkWrap: requests.length < 20,
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
                    itemExtentBuilder: (index, _) {
                      return TrackerInfoItem.height + 1;
                    },
                    itemCount: requests.length,
                  ),
                ),
              ),
            ),
    );
  }
}
