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

  Widget _buildIpTile(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(FluentIcons.location_24_regular),
      title: Text(appLocalizations.ipAddress),
      subtitle: Text(
        widget.ip,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontVariations: const [FontVariation('wght', 700)],
        ),
      ),
      trailing: IconButton(
        icon: const Icon(FluentIcons.copy_24_regular, size: 18),
        tooltip: appLocalizations.copy,
        onPressed: () => _copyIp(context),
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(FluentIcons.protocol_handler_24_regular),
            title: Text(appLocalizations.tunVirtualAddress),
            subtitle: Text(
              'TUN Virtual Network Adapter',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    } else if (_category == IpCategory.lan) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIpTile(context),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(FluentIcons.arrow_shuffle_24_regular),
            title: Text(appLocalizations.privateIp),
            subtitle: Text(
              'LAN / Private Network',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    } else if (_errorMessage != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIpTile(context),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(FluentIcons.error_circle_24_regular, color: Colors.red),
            title: Text(
              _errorMessage!,
              style: context.textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIpTile(context),
          if (countryText.isNotEmpty || flagEmoji.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.flag_24_regular),
              title: Text(appLocalizations.countryOrRegion),
              subtitle: EmojiText(
                flagEmoji.isNotEmpty ? '$flagEmoji $countryText' : countryText,
                style: context.textTheme.bodyMedium,
              ),
            ),
          if (provinceCity.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.city_24_regular),
              title: Text(appLocalizations.provinceAndCity),
              subtitle: Text(provinceCity),
            ),
          if (operatorText.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.building_24_regular),
              title: Text(appLocalizations.operatorOrAsn),
              subtitle: Text(operatorText),
            ),
          if (ispText.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.router_24_regular),
              title: Text(appLocalizations.isp),
              subtitle: Text(ispText),
            ),
          if (domainText.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(FluentIcons.link_24_regular),
              title: Text(appLocalizations.domain),
              subtitle: Text(domainText),
            ),
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
