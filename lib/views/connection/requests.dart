import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class RequestsView extends ConsumerStatefulWidget {
  const RequestsView({super.key});

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView>
    with WidgetsBindingObserver, RouteMotionHoldMixin {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    // A filter left over from the last visit would hide rows and fake an
    // empty state, so the page always opens unfiltered.
    ref.read(requestsSearchProvider.notifier).state = '';
    ref.read(requestsKeywordsProvider.notifier).state = [];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await waitRouteSettled(context);
      if (!mounted) return;
      await _updateRequests();
    });
  }

  Future<void> _updateRequests() async {
    clashCore.startTrackRequests();
    final history = await clashCore.getRequests();
    if (!mounted || history.isEmpty) return;
    final newest = history.last.start;
    final pending = ref
        .read(requestsProvider)
        .list
        .where((item) => item.start.isAfter(newest));
    updateWhenRouteSettled(() {
      if (mounted) {
        ref.read(requestsProvider.notifier).setRequests([...history, ...pending]);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      clashCore.stopTrackRequests();
    } else if (state == AppLifecycleState.resumed) {
      clashCore.startTrackRequests();
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

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(filteredRequestsProvider);

    return CommonScaffold(
      title: appLocalizations.requests,
      actions: [
        IconButton(
          onPressed: () {
            ref.read(requestsProvider.notifier).clearRequests();
            clashCore.clearRequests();
          },
          tooltip: appLocalizations.clear,
          icon: const Icon(FluentIcons.delete_dismiss_24_regular),
        ),
      ],
      searchState: AppBarSearchState(onSearch: _onSearch),
      onKeywordsUpdate: _onKeywordsUpdate,
      body: NullStatusSwitcher(
        isEmpty: requests.isEmpty,
        nullStatus: NullStatus(
          label: appLocalizations.nullTip(appLocalizations.requests),
          illustration: NullStatusIllustration.requests,
        ),
        child: CommonScrollBar(
          trackVisibility: false,
          controller: _scrollController,
          child: ListView.builder(
            physics: const NextClampingScrollPhysics(),
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            itemBuilder: (context, index) {
              final trackerInfo = requests[index];
              return TrackerInfoItem(
                key: ValueKey(trackerInfo.id),
                index: index,
                count: requests.length,
                trackerInfo: trackerInfo,
                onClickKeyword: (value) {
                  context.commonScaffoldState?.addKeyword(value);
                },
                detailTitle: appLocalizations.details,
              );
            },
            itemExtentBuilder: (index, _) {
              return TrackerInfoItem.height + 8;
            },
            itemCount: requests.length,
          ),
        ),
      ),
    );
  }
}
