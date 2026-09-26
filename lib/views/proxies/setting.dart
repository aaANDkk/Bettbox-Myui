import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';


class ProxiesSetting extends StatelessWidget {
  const ProxiesSetting({super.key});

  IconData _getIconWithProxiesType(ProxiesType type) {
    return switch (type) {
      ProxiesType.tab => FluentIcons.app_recent_24_regular,
      ProxiesType.list => FluentIcons.apps_list_detail_24_regular,
    };
  }

  IconData _getIconWithProxiesSortType(ProxiesSortType type) {
    return switch (type) {
      ProxiesSortType.none => FluentIcons.text_align_left_24_regular,
      ProxiesSortType.delay => FluentIcons.top_speed_24_regular,
      ProxiesSortType.name => FluentIcons.text_sort_ascending_24_regular,
    };
  }

  String _getStringProxiesSortType(ProxiesSortType type) {
    return switch (type) {
      ProxiesSortType.none => appLocalizations.defaultText,
      ProxiesSortType.delay => appLocalizations.delay,
      ProxiesSortType.name => appLocalizations.name,
    };
  }

  String getTextForProxiesLayout(ProxiesLayout proxiesLayout) {
    return switch (proxiesLayout) {
      ProxiesLayout.tight => appLocalizations.tight,
      ProxiesLayout.standard => appLocalizations.standard,
      ProxiesLayout.loose => appLocalizations.loose,
    };
  }

  String _getTextWithProxiesIconStyle(ProxiesIconStyle style) {
    return switch (style) {
      ProxiesIconStyle.standard => appLocalizations.standard,
      ProxiesIconStyle.none => appLocalizations.noIcon,
      ProxiesIconStyle.icon => appLocalizations.onlyIcon,
    };
  }

  List<Widget> _buildStyleSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.style,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final proxiesType = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.type),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxiesType.values)
                    SettingInfoCard(
                      Info(
                        label: Intl.message(item.name),
                        iconData: _getIconWithProxiesType(item),
                      ),
                      isSelected: proxiesType == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(
                                type: item,
                                hasCustomizedStyle: true,
                              );
                            });
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSortSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.sort,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final sortType = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.sortType),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxiesSortType.values)
                    SettingInfoCard(
                      Info(
                        label: _getStringProxiesSortType(item),
                        iconData: _getIconWithProxiesSortType(item),
                      ),
                      isSelected: sortType == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(sortType: item);
                            });
                        ref.read(sortNumProvider.notifier).add();
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Info _getInfoWithProxiesLayout(ProxiesLayout proxiesLayout) {
    return switch (proxiesLayout) {
      ProxiesLayout.tight => Info(
          label: getTextForProxiesLayout(proxiesLayout),
          iconData: FluentIcons.dock_row_24_regular,
        ),
      ProxiesLayout.standard => Info(
          label: getTextForProxiesLayout(proxiesLayout),
          iconData: FluentIcons.grid_24_regular,
        ),
      ProxiesLayout.loose => Info(
          label: getTextForProxiesLayout(proxiesLayout),
          icon: const RotatedBox(
            quarterTurns: 1,
            child: Icon(FluentIcons.pause_24_regular),
          ),
        ),
    };
  }

  Info _getInfoWithProxyCardType(ProxyCardType cardType) {
    return switch (cardType) {
      ProxyCardType.expand => Info(
          label: Intl.message(cardType.name),
          iconData: FluentIcons.maximize_24_regular,
        ),
      ProxyCardType.shrink => Info(
          label: Intl.message(cardType.name),
          iconData: FluentIcons.system_24_regular,
        ),
      ProxyCardType.min => Info(
          label: Intl.message(cardType.name),
          iconData: IconsExt.storageMin,
        ),
    };
  }

  Info _getInfoWithProxiesIconStyle(ProxiesIconStyle style) {
    return switch (style) {
      ProxiesIconStyle.standard => Info(
          label: _getTextWithProxiesIconStyle(style),
          iconData: FluentIcons.image_border_24_regular,
        ),
      ProxiesIconStyle.none => Info(
          label: _getTextWithProxiesIconStyle(style),
          iconData: FluentIcons.image_off_24_regular,
        ),
      ProxiesIconStyle.icon => Info(
          label: _getTextWithProxiesIconStyle(style),
          iconData: FluentIcons.image_24_regular,
        ),
    };
  }


  List<Widget> _buildSizeSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.size,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final cardType = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.cardType),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxyCardType.values)
                    SettingInfoCard(
                      _getInfoWithProxyCardType(item),
                      isSelected: item == cardType,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(cardType: item);
                            });
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLayoutSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.layout,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final layout = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.layout),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxiesLayout.values)
                    SettingInfoCard(
                      _getInfoWithProxiesLayout(item),
                      isSelected: item == layout,
                      onPressed: () {
                        ref
                            .watch(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(layout: item);
                            });
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroupStyleSetting() {
    return generateSection(
      plain: true,
      title: appLocalizations.iconStyle,
      items: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          child: Consumer(
            builder: (_, ref, _) {
              final iconStyle = ref.watch(
                proxiesStyleSettingProvider.select((state) => state.iconStyle),
              );
              return Wrap(
                spacing: 16,
                children: [
                  for (final item in ProxiesIconStyle.values)
                    SettingInfoCard(
                      _getInfoWithProxiesIconStyle(item),
                      isSelected: iconStyle == item,
                      onPressed: () {
                        ref
                            .read(proxiesStyleSettingProvider.notifier)
                            .updateState((state) {
                              return state.copyWith(
                                iconStyle: item,
                                hasCustomizedStyle: true,
                              );
                            });
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildStyleSetting(),
          ..._buildSortSetting(),
          ..._buildLayoutSetting(),
          ..._buildSizeSetting(),
          Consumer(
            builder: (_, ref, child) {
              final isList = ref.watch(
                proxiesStyleSettingProvider.select(
                  (state) => state.type == ProxiesType.list,
                ),
              );
              if (isList) {
                return child!;
              }
              return Container();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [..._buildGroupStyleSetting()],
            ),
          ),
        ],
      ),
    );
  }
}
