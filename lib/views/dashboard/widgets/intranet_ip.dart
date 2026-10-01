import 'dart:ui' show FontVariation;
import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/providers/config.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/config/general.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class IntranetIP extends ConsumerWidget {
  const IntranetIP({super.key});

  void _showMoreIpInfoDialog(BuildContext context) {
    globalState.showCommonDialog(
      child: const _IntranetIpInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localIp = ref.watch(localIpProvider);
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(label: appLocalizations.intranetIP, iconData: FluentIcons.phone_laptop_24_regular),
        onPressed: () => _showMoreIpInfoDialog(context),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: FadeThroughBox(
                  child: localIp != null
                      ? TooltipText(
                          text: Text(
                            localIp.isNotEmpty
                                ? localIp
                                : appLocalizations.noNetwork,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(2),
                          child: Center(
                            child: OverflowBox(
                              maxWidth: 30,
                              maxHeight: 16,
                              child: SpinKitThreeBounce(
                                color: context.colorScheme.primary,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cachedNetworkType = '';
List<String> _cachedGateways = [];
List<String> _cachedSystemDns = [];
bool _hasNetworkCache = false;

class _IntranetIpInfoDialog extends ConsumerStatefulWidget {
  const _IntranetIpInfoDialog();

  @override
  ConsumerState<_IntranetIpInfoDialog> createState() =>
      _IntranetIpInfoDialogState();
}

class _IntranetIpInfoDialogState extends ConsumerState<_IntranetIpInfoDialog> {
  late String _networkType;
  late List<String> _gateways;
  late List<String> _systemDns;
  late bool _isLoading;

  @override
  void initState() {
    super.initState();
    if (_hasNetworkCache) {
      _networkType = _cachedNetworkType;
      _gateways = _cachedGateways;
      _systemDns = _cachedSystemDns;
      _isLoading = false;
    } else {
      _networkType = '';
      _gateways = [];
      _systemDns = [];
      _isLoading = true;
    }
    _loadNetworkDetails();
  }

  Future<void> _loadNetworkDetails() async {
    try {
      final results = await Future.wait([
        utils.getNetworkType(),
        utils.getLocalGateways(),
        utils.getSystemDns(),
      ]);
      final networkType = results[0] as String;
      final gateways = results[1] as List<String>;
      final systemDns = results[2] as List<String>;

      _cachedNetworkType = networkType;
      _cachedGateways = gateways;
      _cachedSystemDns = systemDns;
      _hasNetworkCache = true;

      if (!mounted) return;
      setState(() {
        _networkType = networkType;
        _gateways = gateways;
        _systemDns = systemDns;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openLanSettings(BuildContext context) {
    final targetContext = globalState.navigatorKey.currentContext ?? context;
    Navigator.of(context, rootNavigator: true).pop();
    showExtend(
      targetContext,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.general,
        body: const GeneralListView(),
      ),
      props: const ExtendProps(blur: false, forceFull: true),
    );
  }

  Widget _buildSectionHeader(String title, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 2 : 14, bottom: 8),
      child: Text(
        '［ $title ］',
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontVariations: const [FontVariation('wght', 700)],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    String label = '',
    required String value,
    Widget? action,
    Widget? customValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: ShapeDecoration(
        color: context.colorScheme.surfaceContainerLow,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: label.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      customValue ??
                          Text(
                            value,
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontVariations: const [FontVariation('wght', 700)],
                            ),
                          ),
                    ],
                  )
                : (customValue ??
                    Text(
                      value,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    )),
          ),
          if (action != null) ...[
            const SizedBox(width: 4),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildLanSharingTile(bool allowLan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: ShapeDecoration(
        color: context.colorScheme.surfaceContainerLow,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (allowLan ? Colors.green : context.colorScheme.outline)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.flowchart_24_regular,
              size: 14,
              color: allowLan ? Colors.green : context.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appLocalizations.lanSharing,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => _openLanSettings(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: ShapeDecoration(
                        color: allowLan
                            ? context.colorScheme.primaryContainer
                            : context.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: allowLan
                              ? BorderSide.none
                              : BorderSide(
                                  color: context.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                        ),
                      ),
                      child: Text(
                        allowLan
                            ? appLocalizations.enabled
                            : appLocalizations.disabled,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: allowLan
                              ? context.colorScheme.onPrimaryContainer
                              : context.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      FluentIcons.chevron_right_24_regular,
                      size: 14,
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        minimumSize: const Size(28, 28),
        fixedSize: const Size(28, 28),
      ),
      icon: Icon(icon, size: 15, color: context.colorScheme.onSurfaceVariant),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  bool _canOpenGateway(String gateway, String networkType) {
    if (gateway.isEmpty || gateway == '0.0.0.0') return false;

    final lowerType = networkType.toLowerCase();
    if (lowerType.contains('cellular')) {
      return false;
    }

    final parts = gateway.split('.');
    if (parts.length != 4) return false;

    final o1 = int.tryParse(parts[0]);
    final o2 = int.tryParse(parts[1]);
    final o3 = int.tryParse(parts[2]);
    final o4 = int.tryParse(parts[3]);

    if (o1 == null || o2 == null || o3 == null || o4 == null) return false;
    if (o1 < 0 ||
        o1 > 255 ||
        o2 < 0 ||
        o2 > 255 ||
        o3 < 0 ||
        o3 > 255 ||
        o4 < 0 ||
        o4 > 255) {
      return false;
    }

    if (o1 == 127 || (o1 == 169 && o2 == 254)) return false;
    if (o1 == 100 && o2 >= 64 && o2 <= 127) return false;
    if (o1 == 198 && (o2 == 18 || o2 == 19)) return false;

    if (o1 == 192 && o2 == 168) return true;
    if (o1 == 10) return true;
    if (o1 == 172 && o2 >= 16 && o2 <= 31) return true;

    return false;
  }

  IconData _resolveNetworkIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('ethernet')) {
      return FluentIcons.desktop_24_regular;
    }
    if (lower.contains('cellular')) {
      return FluentIcons.cellular_data_1_24_regular;
    }
    return FluentIcons.wifi_1_24_regular;
  }

  @override
  Widget build(BuildContext context) {
    final localIp = ref.watch(localIpProvider) ?? '';
    final allowLan = ref.watch(
      patchClashConfigProvider.select((state) => state.allowLan),
    );
    final mixedPort = ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );

    final displayLocalIp = localIp.isNotEmpty ? localIp : '-';
    final primaryGateway = _gateways.isNotEmpty ? _gateways.first : '';
    final displayGateway = primaryGateway.isNotEmpty ? primaryGateway : '-';
    final sharedAddress = localIp.isNotEmpty ? '$localIp:$mixedPort' : '-';

    final systemDnsText = _systemDns.isNotEmpty
        ? _systemDns.join(', ')
        : (_isLoading ? '...' : '-');

    return CommonDialog(
      title: appLocalizations.moreIpInfo,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              appLocalizations.intranetAndGateway,
              isFirst: true,
            ),
            _buildStatTile(
              icon: _resolveNetworkIcon(_networkType),
              iconColor: context.colorScheme.primary,
              label: appLocalizations.networkType,
              value: _networkType.isNotEmpty
                  ? _networkType
                  : (_isLoading ? '...' : appLocalizations.noNetwork),
            ),
            const SizedBox(height: 8),
            _buildStatTile(
              icon: FluentIcons.phone_laptop_24_regular,
              iconColor: context.colorScheme.secondary,
              label: appLocalizations.intranetIP,
              value: displayLocalIp,
            ),
            const SizedBox(height: 8),
            _buildStatTile(
              icon: FluentIcons.router_24_regular,
              iconColor: context.colorScheme.tertiary,
              label: appLocalizations.defaultGateway,
              value: displayGateway,
              action: _canOpenGateway(primaryGateway, _networkType)
                  ? _buildIconButton(
                      icon: FluentIcons.open_24_regular,
                      tooltip: appLocalizations.openRouterAdmin,
                      onPressed: () {
                        globalState.openUrl('http://$primaryGateway');
                      },
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            _buildStatTile(
              icon: FluentIcons.server_24_regular,
              iconColor: context.colorScheme.primary,
              label: appLocalizations.systemDns,
              value: systemDnsText,
              customValue: Text(
                systemDnsText,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontVariations: const [FontVariation('wght', 700)],
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ),
            _buildSectionHeader(appLocalizations.allowLan),
            _buildLanSharingTile(allowLan),
            if (allowLan) ...[
              const SizedBox(height: 8),
              _buildStatTile(
                icon: FluentIcons.arrow_routing_24_regular,
                iconColor: context.colorScheme.primary,
                value: sharedAddress,
                action: localIp.isNotEmpty
                    ? _buildIconButton(
                        icon: FluentIcons.copy_24_regular,
                        tooltip: appLocalizations.copy,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: sharedAddress),
                          );
                          if (context.mounted) {
                            context.showNotifier(
                              appLocalizations.copySuccess,
                            );
                          }
                        },
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
