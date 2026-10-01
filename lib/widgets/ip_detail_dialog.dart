import 'dart:ui' show FontVariation;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

void showIpDetailDialog(
  BuildContext context,
  String rawIp, {
  IpInfo? initialInfo,
}) {
  var cleanIp = rawIp.trim();
  if (cleanIp.startsWith('[') && cleanIp.contains(']')) {
    cleanIp = cleanIp.substring(1, cleanIp.indexOf(']'));
  } else if (cleanIp.contains(':') && !cleanIp.contains('::')) {
    final parts = cleanIp.split(':');
    if (parts.length == 2 && int.tryParse(parts[1]) != null) {
      cleanIp = parts[0];
    }
  }

  if (cleanIp.isEmpty) return;

  globalState.showCommonDialog(
    child: _IpDetailDialog(
      ip: cleanIp,
      initialInfo: initialInfo,
    ),
  );
}

class _IpDetailDialog extends StatefulWidget {
  final String ip;
  final IpInfo? initialInfo;

  const _IpDetailDialog({
    required this.ip,
    this.initialInfo,
  });

  @override
  State<_IpDetailDialog> createState() => _IpDetailDialogState();
}

class _IpDetailDialogState extends State<_IpDetailDialog> {
  late bool _isLoading;
  String? _errorMessage;
  IpCategory? _category;
  IpInfo? _ipInfo;

  @override
  void initState() {
    super.initState();
    final cat = utils.classifyIp(widget.ip);
    if (cat != IpCategory.public) {
      _category = cat;
      _isLoading = false;
    } else {
      final cached = widget.initialInfo ?? request.getMemoryCachedIp(widget.ip);
      if (cached != null) {
        _ipInfo = cached;
        _isLoading = false;
      } else {
        _isLoading = true;
        _fetchIpDetail();
      }
    }
  }

  Future<void> _fetchIpDetail() async {
    final cat = utils.classifyIp(widget.ip);
    if (cat != IpCategory.public) {
      if (mounted) {
        setState(() {
          _category = cat;
          _isLoading = false;
        });
      }
      return;
    }

    final res = await request.queryIpDetail(widget.ip);
    if (!mounted) return;

    if (res.isError) {
      final msg = res.message;
      if (msg.contains('private') || msg.contains('reserved')) {
        setState(() {
          _category = IpCategory.lan;
          _isLoading = false;
        });
      } else if (_ipInfo == null) {
        setState(() {
          _errorMessage = appLocalizations.networkErrorRetryLater;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _ipInfo = res.data ?? _ipInfo;
        _isLoading = false;
      });
    }
  }

  void _copyIp(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.ip));
    globalState.showNotifier(appLocalizations.copySuccess);
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

  Widget _buildIpTile(BuildContext context) {
    return _buildStatTile(
      icon: FluentIcons.location_24_regular,
      iconColor: context.colorScheme.primary,
      label: appLocalizations.ipAddress,
      value: widget.ip,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconButton(
            icon: FluentIcons.copy_24_regular,
            tooltip: appLocalizations.copy,
            onPressed: () => _copyIp(context),
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: FluentIcons.open_24_regular,
            tooltip: appLocalizations.viewDetailedIpData,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              globalState.openUrl('https://www.ip2location.com/${widget.ip}');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ipInfo = _ipInfo;

    final flagEmoji = (ipInfo != null && ipInfo.countryCode.isNotEmpty)
        ? utils.countryCodeToEmoji(ipInfo.countryCode)
        : '';

    final countryText = ipInfo != null
        ? [
            if (ipInfo.country != null && ipInfo.country!.isNotEmpty)
              ipInfo.country,
            if (ipInfo.countryCode.isNotEmpty)
              ipInfo.countryCode,
          ].join(' · ')
        : '';

    final provinceCity = ipInfo != null
        ? [
            if (ipInfo.province != null && ipInfo.province!.isNotEmpty)
              ipInfo.province,
            if (ipInfo.city != null &&
                ipInfo.city!.isNotEmpty &&
                ipInfo.city != ipInfo.province)
              ipInfo.city,
          ].join(' · ')
        : '';

    final ispText = (ipInfo?.isp != null && ipInfo!.isp!.isNotEmpty)
        ? ipInfo.isp!
        : '';

    final operatorText = ipInfo != null
        ? [
            if (ipInfo.asName != null &&
                ipInfo.asName!.isNotEmpty &&
                ipInfo.asName != ipInfo.isp &&
                ipInfo.asName != ipInfo.asDomain)
              ipInfo.asName,
            if (ipInfo.asn != null && ipInfo.asn!.isNotEmpty)
              ipInfo.asn,
          ].join(' · ')
        : '';

    final domainText = (ipInfo?.asDomain != null && ipInfo!.asDomain!.isNotEmpty)
        ? ipInfo.asDomain!
        : '';

    Widget content;
    if (_isLoading) {
      content = Container(
        height: 120,
        alignment: Alignment.center,
        child: SpinKitThreeBounce(
          color: context.colorScheme.primary,
          size: 24,
        ),
      );
    } else if (_category == IpCategory.tun) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIpTile(context),
          const SizedBox(height: 8),
          _buildStatTile(
            icon: FluentIcons.protocol_handler_24_regular,
            iconColor: context.colorScheme.secondary,
            label: appLocalizations.tunVirtualAddress,
            value: 'TUN Virtual Network Adapter',
          ),
        ],
      );
    } else if (_category == IpCategory.lan) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIpTile(context),
          const SizedBox(height: 8),
          _buildStatTile(
            icon: FluentIcons.flowchart_24_regular,
            iconColor: context.colorScheme.secondary,
            label: appLocalizations.privateIp,
            value: 'LAN / Private Network',
          ),
        ],
      );
    } else if (_errorMessage != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIpTile(context),
          const SizedBox(height: 8),
          _buildStatTile(
            icon: FluentIcons.error_circle_24_regular,
            iconColor: Colors.red,
            value: _errorMessage ?? '',
            customValue: Text(
              _errorMessage ?? '',
              style: context.textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ],
      );
    } else {
      final items = <Widget>[
        _buildIpTile(context),
        if (countryText.isNotEmpty || flagEmoji.isNotEmpty)
          _buildStatTile(
            icon: FluentIcons.flag_24_regular,
            iconColor: context.colorScheme.secondary,
            label: appLocalizations.countryOrRegion,
            value: countryText,
            customValue: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (flagEmoji.isNotEmpty) ...[
                  EmojiText(
                    flagEmoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    countryText,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (provinceCity.isNotEmpty)
          _buildStatTile(
            icon: FluentIcons.city_24_regular,
            iconColor: context.colorScheme.tertiary,
            label: appLocalizations.provinceAndCity,
            value: provinceCity,
          ),
        if (operatorText.isNotEmpty)
          _buildStatTile(
            icon: FluentIcons.building_24_regular,
            iconColor: context.colorScheme.secondary,
            label: appLocalizations.operatorOrAsn,
            value: operatorText,
          ),
        if (ispText.isNotEmpty)
          _buildStatTile(
            icon: FluentIcons.router_24_regular,
            iconColor: context.colorScheme.primary,
            label: appLocalizations.isp,
            value: ispText,
          ),
        if (domainText.isNotEmpty)
          _buildStatTile(
            icon: FluentIcons.link_24_regular,
            iconColor: context.colorScheme.tertiary,
            label: appLocalizations.domain,
            value: domainText,
          ),
      ];

      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    final Widget loadingWidget = Container(
      key: const ValueKey('loading'),
      height: 100,
      alignment: Alignment.center,
      child: SpinKitThreeBounce(
        color: context.colorScheme.primary,
        size: 24,
      ),
    );

    final Widget detailsWidget = SingleChildScrollView(
      key: const ValueKey('details'),
      child: content,
    );

    return CommonDialog(
      title: appLocalizations.moreIpInfo,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      overrideScroll: true,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: AnimatedSize(
        alignment: Alignment.topCenter,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          reverseDuration: Duration.zero,
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _isLoading ? loadingWidget : detailsWidget,
        ),
      ),
    );
  }
}
