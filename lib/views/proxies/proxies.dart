import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/proxies/list.dart';
import 'package:bett_box/views/proxies/providers.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../profiles/scripts.dart'
    show showGroupSwitchOptions, showScriptCustomOptions;
import 'advanced_settings.dart';
import 'setting.dart';
import 'tab.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> {
  final GlobalKey<ProxiesTabViewState> _proxiesTabKey = GlobalKey();
  bool _hasProviders = false;
  bool _isTab = false;

  List<Widget> _buildActions() {
    final showHiddenItems = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.showHiddenItems),
    );
    final currentProfile = ref.watch(currentProfileProvider);
    final scriptProps = ref.watch(scriptStateProvider);
    final effectiveScript = currentProfile?.getEffectiveScript(scriptProps);
    final hasScriptCustom =
        effectiveScript != null && effectiveScript.isCompatibleWithBettbox;
    final hasGroupCustom =
        !hasScriptCustom && ref.read(currentProfileIdProvider) != null;
    final hasCustom = hasScriptCustom || hasGroupCustom;
    return [
      if (_isTab)
        IconButton(
          onPressed: () {
            _proxiesTabKey.currentState?.scrollToGroupSelected();
          },
          tooltip: appLocalizations.locate,
          icon: const Icon(FluentIcons.target_arrow_24_regular),
        ),
      if (hasCustom)
        IconButton(
          onPressed: _handleCustomOptions,
          icon: const Icon(FluentIcons.options_24_regular),
          tooltip: appLocalizations.custom,
        ),
      CommonPopupBox(
        targetBuilder: (open) {
          return IconButton(
            onPressed: () {
              open(offset: const Offset(0, 20));
            },
            tooltip: appLocalizations.more,
            icon: const Icon(FluentIcons.symbols_24_regular),
          );
        },
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              icon: FluentIcons.style_guide_24_regular,
              label: appLocalizations.styleSetting,
              onPressed: () {
                showSheet(
                  context: context,
                  props: SheetProps(isScrollControlled: true),
                  builder: (_, type) {
                    return AdaptiveSheetScaffold(
                      type: type,
                      body: const ProxiesSetting(),
                      title: appLocalizations.styleSetting,
                    );
                  },
                );
              },
            ),
            PopupMenuItemData(
              icon: FluentIcons.star_emphasis_24_regular,
              label: appLocalizations.advancedSettings,
              onPressed: () {
                showExtend(
                  context,
                  builder: (_, type) {
                    return AdaptiveSheetScaffold(
                      type: type,
                      body: const ProxiesAdvancedSettings(),
                      title: appLocalizations.advancedSettings,
                    );
                  },
                );
              },
            ),
            if (!_isTab)
              PopupMenuItemData(
                icon: FluentIcons.image_edit_24_regular,
                label: appLocalizations.iconConfiguration,
                onPressed: () {
                  showExtend(
                    context,
                    builder: (_, type) {
                      return AdaptiveSheetScaffold(
                        type: type,
                        body: const _IconConfigView(),
                        title: appLocalizations.iconConfiguration,
                        actions: const [_IconRefreshAction()],
                      );
                    },
                  );
                },
              ),
            if (_hasProviders)
              PopupMenuItemData(
                icon: FluentIcons.calendar_3_day_24_regular,
                label: appLocalizations.providers,
                onPressed: () {
                  showExtend(
                    context,
                    builder: (_, type) {
                      return ProvidersView(type: type);
                    },
                  );
                },
              ),
            PopupMenuItemData(
              icon: showHiddenItems
                  ? FluentIcons.record_24_regular
                  : FluentIcons.circle_24_regular,
              label: appLocalizations.showHiddenItems,
              onPressed: () {
                ref
                    .read(proxiesStyleSettingProvider.notifier)
                    .updateState(
                      (state) =>
                          state.copyWith(showHiddenItems: !showHiddenItems),
                    );
              },
            ),
          ],
        ),
      ),
    ];
  }

  Widget? _buildFAB() {
    if (!_isTab ||
        globalState.isAndroidTV ||
        ref.watch(isMobileViewProvider)) {
      return null;
    }
    return Consumer(
      builder: (_, ref, _) {
        final isMobileView = ref.watch(isMobileViewProvider);
        final currentGroupName = ref.watch(
          proxiesTabControllerStateProvider.select((state) => state.b),
        );
        return Padding(
          padding: EdgeInsets.only(
            bottom: isMobileView
                ? getFloatingBottomBarFABReserveHeight(context)
                : 0,
          ),
          child: DelayTestButton(
            groupName: currentGroupName ?? '',
            onClick: () async {
              await _proxiesTabKey.currentState?.delayTestCurrentGroup();
            },
          ),
        );
      },
    );
  }

  void _onSearch(String value) {
    ref.read(queryProvider.notifier).value = value;
  }

  Future<void> _handleCustomOptions() async {
    final currentProfile = ref.read(currentProfileProvider);
    final scriptProps = ref.read(scriptStateProvider);
    final effectiveScript = currentProfile?.getEffectiveScript(scriptProps);
    if (effectiveScript != null && effectiveScript.isCompatibleWithBettbox) {
      await showScriptCustomOptions(context, ref, script: effectiveScript);
      return;
    }
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId != null) {
      await showGroupSwitchOptions(context, ref, profileId: profileId);
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(residentProxyTestProvider.notifier).state = () {
          _proxiesTabKey.currentState?.delayTestCurrentGroup();
        };
      }
    });
    ref.listenManual(providersProvider.select((state) => state.isNotEmpty), (
      prev,
      next,
    ) {
      if (prev != next) {
        setState(() {
          _hasProviders = next;
        });
      }
    }, fireImmediately: true);
    ref.listenManual(
      proxiesStyleSettingProvider.select(
        (state) => state.type == ProxiesType.tab,
      ),
      (prev, next) {
        if (prev != next) {
          setState(() {
            _isTab = next;
          });
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.type),
    );
    final hasGroups = ref.watch(
      groupsProvider.select((state) => state.isNotEmpty),
    );
    ref.watch(appSettingProvider.select((state) => state.locale));
    return CommonScaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: _buildFAB(),
      actions: _buildActions(),
      title: appLocalizations.proxies,
      searchState: AppBarSearchState(onSearch: _onSearch),
      showScrollGradient: false,
      body: switch (hasGroups) {
        false => NullStatus(
            label: appLocalizations.noProxy,
            illustration: NullStatusIllustration.proxies,
          ),
        true => switch (proxiesType) {
          ProxiesType.tab => ProxiesTabView(key: _proxiesTabKey),
          ProxiesType.list => const ProxiesListView(),
        },
      },
    );
  }
}

class _IconConfigView extends ConsumerWidget {
  const _IconConfigView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconMap = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.iconMap),
    );
    return MapInputPage(
      title: appLocalizations.iconConfiguration,
      map: iconMap,
      keyLabel: appLocalizations.regExp,
      valueLabel: appLocalizations.icon,
      titleBuilder: (item) => EmojiText(item.key),
      leadingBuilder: (item) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: CommonTargetIcon(src: item.value, size: 42),
      ),
      subtitleBuilder: (item) =>
          Text(item.value, maxLines: 2, overflow: TextOverflow.ellipsis),
      onChange: (value) {
        ref
            .read(proxiesStyleSettingProvider.notifier)
            .updateState((state) => state.copyWith(iconMap: value));
      },
    );
  }
}

class _IconRefreshAction extends ConsumerStatefulWidget {
  const _IconRefreshAction();

  @override
  ConsumerState<_IconRefreshAction> createState() => _IconRefreshActionState();
}

class _IconRefreshActionState extends ConsumerState<_IconRefreshAction> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await CommonTargetIcon.refreshAll(
        ref.read(proxiesStyleSettingProvider).iconMap.values,
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _isRefreshing ? null : _handleRefresh,
      tooltip: appLocalizations.update,
      icon: _isRefreshing
          ? SizedBox.square(
              dimension: 18,
              child: SpinKitFadingCircle(
                color: context.colorScheme.primary,
                size: 18,
              ),
            )
          : const Icon(FluentIcons.arrow_sync_24_regular),
    );
  }
}
