import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../widgets/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    // A filter left over from the last visit would hide rows and fake an
    // empty state, so the page always opens unfiltered.
    ref.read(logsSearchProvider.notifier).state = '';
    ref.read(logsKeywordsProvider.notifier).state = [];
    clashCore.startLog();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      clashCore.stopLog();
    } else if (state == AppLifecycleState.resumed) {
      clashCore.startLog();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clashCore.stopLog();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(logsSearchProvider.notifier).state = value;
  }

  void _onKeywordsUpdate(List<String> keywords) {
    ref.read(logsKeywordsProvider.notifier).state = keywords;
  }

  Future<void> _handleLogLevelSettings() async {
    final currentLogLevel = ref.read(
      patchClashConfigProvider.select((state) => state.logLevel),
    );

    final selectedLogLevel = await globalState.showCommonDialog<LogLevel>(
      child: OptionsDialog<LogLevel>(
        title: appLocalizations.logLevel,
        options: LogLevel.values,
        value: currentLogLevel,
        textBuilder: (logLevel) => logLevel.name,
      ),
    );

    if (selectedLogLevel != null && selectedLogLevel != currentLogLevel) {
      ref
          .read(patchClashConfigProvider.notifier)
          .updateState((state) => state.copyWith(logLevel: selectedLogLevel));
      globalState.appController.updateClashConfigDebounce();
    }
  }

  Future<void> _handleExport() async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        return await globalState.appController.exportLogs();
      },
      needLoading: true,
      title: appLocalizations.exportLogs,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.exportSuccess),
      cancelable: false,
    );
  }

  void _handleClearLogs() {
    ref.read(logsProvider.notifier).clearLogs();
    clashCore.clearLogs();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(filteredLogsProvider);
    return CommonScaffold(
      actions: [
        IconButton(
          onPressed: _handleLogLevelSettings,
          icon: const Icon(FluentIcons.settings_24_regular),
          tooltip: appLocalizations.logLevel,
        ),
        Tooltip(
          message: appLocalizations.export,
          child: InkWell(
            onTap: _handleExport,
            onLongPress: _handleClearLogs,
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(FluentIcons.save_edit_24_regular, size: 24),
            ),
          ),
        ),
      ],
      onKeywordsUpdate: _onKeywordsUpdate,
      searchState: AppBarSearchState(onSearch: _onSearch),
      title: appLocalizations.logs,
      body: NullStatusSwitcher(
        isEmpty: logs.isEmpty,
        nullStatus: NullStatus(
          label: appLocalizations.nullTip(appLocalizations.logs),
          illustration: NullStatusIllustration.logs,
        ),
        child: CommonScrollBar(
          controller: _scrollController,
          child: ListView.builder(
            physics: const NextClampingScrollPhysics(),
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            itemBuilder: (context, index) {
              final log = logs[index];
              return LogItem(
                key: ValueKey(log.dateTime),
                index: index,
                count: logs.length,
                log: log,
                onClick: (value) {
                  context.commonScaffoldState?.addKeyword(value);
                },
              );
            },
            itemCount: logs.length,
          ),
        ),
      ),
    );
  }
}

class LogItem extends StatelessWidget {
  final Log log;
  final Function(String)? onClick;
  final int index;
  final int count;
  final bool reversed;

  const LogItem({
    super.key,
    required this.log,
    this.onClick,
    required this.index,
    required this.count,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ContinuousListItem(
        index: index,
        count: count,
        reversed: reversed,
        standalone: true,
        child: ListItem(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: () {
            globalState.showCommonDialog(child: LogDetailDialog(log: log));
          },
          title: EmojiText(
            log.payload,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyLarge?.copyWith(
              color: log.logLevel.color,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CommonChip(
                  onPressed: () {
                    onClick?.call(log.logLevel.name);
                  },
                  label: log.logLevel.name,
                ),
                Text(
                  log.dateTime,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.opacity80,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LogDetailDialog extends StatelessWidget {
  final Log log;

  const LogDetailDialog({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.details,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          SelectableText(
            log.payload,
            style: context.textTheme.bodyLarge?.copyWith(
              color: log.logLevel.color,
            ),
          ),
          SelectableText(
            log.dateTime,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
