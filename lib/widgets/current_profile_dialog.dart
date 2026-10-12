import 'dart:ui' show FontVariation;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showCurrentProfileDialog() async {
  await globalState.showCommonDialog<void>(
    child: const CurrentProfileDialog(),
  );
}

class CurrentProfileDialog extends ConsumerStatefulWidget {
  const CurrentProfileDialog({super.key});

  @override
  ConsumerState<CurrentProfileDialog> createState() =>
      _CurrentProfileDialogState();
}

class _CurrentProfileDialogState extends ConsumerState<CurrentProfileDialog> {
  static const _panelHeight = 110.0;
  static const _pickerHeight = 160.0;

  late final FixedExtentScrollController _scrollController;
  String? _selectedId;
  int _targetIndex = 0;

  @override
  void initState() {
    super.initState();
    final profiles = ref.read(profilesProvider);
    _selectedId = ref.read(currentProfileIdProvider);
    final index = profiles.indexWhere((item) => item.id == _selectedId);
    _targetIndex = index >= 0 ? index : 0;
    _scrollController = FixedExtentScrollController(initialItem: _targetIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerScroll(PointerScrollEvent event) {
    if (event.scrollDelta.dy == 0) return;
    final profiles = ref.read(profilesProvider);
    if (profiles.isEmpty) return;
    final direction = event.scrollDelta.dy > 0 ? 1 : -1;
    final current = _scrollController.hasClients
        ? _scrollController.selectedItem
        : _targetIndex;
    final nextIndex = (current + direction).clamp(0, profiles.length - 1);
    if (nextIndex != _targetIndex || current != nextIndex) {
      _targetIndex = nextIndex;
      _scrollController.animateToItem(
        _targetIndex,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleConfirm() {
    final profileId = _selectedId;
    if (profileId != null && profileId != ref.read(currentProfileIdProvider)) {
      ref.read(currentProfileIdProvider.notifier).value = profileId;
    }
    Navigator.of(context).pop();
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final index = profiles.indexWhere((item) => item.id == _selectedId);
    final panelProfile = index >= 0
        ? profiles[index]
        : ref.watch(currentProfileProvider);

    return CommonDialog(
      title: appLocalizations.currentProfile,
      overrideScroll: true,
      actions: [
        TextButton(
          onPressed: _handleCancel,
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _handleConfirm,
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _panelHeight,
            child: _ProfilePanel(profile: panelProfile),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _pickerHeight,
            child: profiles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: EmojiText(
                        appLocalizations.nullProfileDesc,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall?.toLight,
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned.fill(child: _buildPicker(profiles)),
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerSignal: (pointerSignal) {
                            if (pointerSignal is PointerScrollEvent) {
                              GestureBinding.instance.pointerSignalResolver
                                  .register(pointerSignal, (event) {
                                    if (event is PointerScrollEvent) {
                                      _handlePointerScroll(event);
                                    }
                                  });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker(List<Profile> profiles) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: CupertinoPicker(
        scrollController: _scrollController,
        itemExtent: 40.0,
        magnification: 1.15,
        useMagnifier: true,
        squeeze: 1.15,
        diameterRatio: 1.25,
        selectionOverlay: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: context.colorScheme.primary.withValues(alpha: 0.08),
            shape: SuperellipseBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: context.colorScheme.primary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
        ),
        onSelectedItemChanged: (int index) {
          setState(() {
            _selectedId = profiles[index].id;
            _targetIndex = index;
          });
        },
        children: profiles.map((item) {
          final isSelected = item.id == _selectedId;
          return Center(
            child: EmojiText(
              item.label ?? item.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                fontSize: isSelected ? 16 : 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  final Profile? profile;

  const _ProfilePanel({this.profile});

  String get _updateTimeDesc {
    return profile?.lastUpdateDate?.lastUpdateTimeDesc ??
        appLocalizations.notAcquired;
  }

  String _trafficText(SubscriptionInfo? info) {
    if (info == null) return 'Unlimited';
    final use = info.upload + info.download;
    final total = info.total;
    if (use == 0 && total == 0) return 'Unlimited';
    final useShow = TrafficValue(value: use).show;
    if (total == 0) return '$useShow / Unlimited';
    return '$useShow / ${TrafficValue(value: total).show}';
  }

  Widget _line(String text, TextStyle? style) {
    return SizedBox(
      height: globalState.measure.labelMediumHeight,
      child: Center(
        child: EmojiText(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }

  Widget _barSlot(Widget child) {
    return SizedBox(height: 14, child: Center(child: child));
  }

  Widget _titleRow(BuildContext context, String name, String subtitle) {
    final labelStyle = context.textTheme.labelMedium?.toLight;
    final titleStyle = context.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      fontVariations: const [FontVariation('wght', 700)],
    );
    return SizedBox(
      height: globalState.measure.titleMediumHeight,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Transform.translate(
                offset: const Offset(0, 1),
                child: EmojiText(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                  strutStyle: StrutStyle.fromTextStyle(
                    titleStyle!,
                    forceStrutHeight: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: CommonInfoCapsule(subtitle, style: labelStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noUsageText(BuildContext context) {
    return EmojiText(
      appLocalizations.noUsageData,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.labelSmall?.toLight.copyWith(height: 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    final info = profile?.subscriptionInfo;
    final hasUsage =
        info != null && (info.upload + info.download > 0 || info.total > 0);
    final lineStyle = context.textTheme.labelMedium?.toLight;

    final List<Widget> rows;

    if (profile == null) {
      rows = [_line(appLocalizations.noInfo, lineStyle)];
    } else {
      final isFile = profile.type == ProfileType.file;
      final subtitle = isFile
          ? appLocalizations.localFile
          : (info?.expireDesc ?? appLocalizations.notAcquired);
      rows = [
        _titleRow(context, profile.label ?? profile.id, subtitle),
        _barSlot(
          hasUsage && info != null
              ? _UsageBar(subscriptionInfo: info)
              : _noUsageText(context),
        ),
        _line(
          isFile
              ? '${appLocalizations.lastEdit} · $_updateTimeDesc'
              : '${_trafficText(info)} · $_updateTimeDesc',
          lineStyle,
        ),
      ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ShapeDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        shape: SuperellipseBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: rows,
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final SubscriptionInfo subscriptionInfo;

  const _UsageBar({required this.subscriptionInfo});

  @override
  Widget build(BuildContext context) {
    // Nothing is painted in the trailing 6px padding of the bar.
    return SizedBox(
      height: 5,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 11,
        maxHeight: 11,
        child: SubscriptionInfoView(subscriptionInfo: subscriptionInfo),
      ),
    );
  }
}
