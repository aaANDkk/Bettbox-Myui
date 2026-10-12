import 'dart:async';
import 'dart:math';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'core_status_dialog.dart';

class CurrentProfile extends ConsumerStatefulWidget {
  const CurrentProfile({super.key});

  @override
  ConsumerState<CurrentProfile> createState() => _CurrentProfileState();
}

class _CurrentProfileState extends ConsumerState<CurrentProfile> {
  late final VoidCallback _tickListener;
  static TrafficValue _lastMemoryValue = TrafficValue(value: 0);
  static int _lastInUse = 0;
  static int _lastReclaimable = 0;

  TrafficValue _memoryValue = _lastMemoryValue;
  int _inUse = _lastInUse;
  int _reclaimable = _lastReclaimable;
  Timer? _initTimer;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tickListener = _updateMemoryStatus;
    dashboardRefreshManager.tick2s.addListener(_tickListener);

    if (_lastMemoryValue.value == 0) {
      _retryUpdateMemory();
    } else {
      _initTimer = Timer(const Duration(milliseconds: 1000), _updateMemoryStatus);
    }
  }

  Future<void> _retryUpdateMemory() async {
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      await _updateMemoryStatus();
      if (_memoryValue.value > 0) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    dashboardRefreshManager.tick2s.removeListener(_tickListener);
    super.dispose();
  }

  Future<void> _updateMemoryStatus() async {
    if (!mounted) return;
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final status = await clashCore.getCoreStatus();
      if (status != null && (status.inUse > 0 || status.physical > 0 || status.reclaimable > 0)) {
        final totalMemory = (status.inUse + status.reclaimable) > 0
            ? (status.inUse + status.reclaimable)
            : (status.inUse > 0 ? status.inUse : status.physical);
        if (mounted) {
          setState(() {
            _inUse = status.inUse;
            _reclaimable = status.reclaimable;
            _memoryValue = TrafficValue(value: totalMemory);
            _lastInUse = _inUse;
            _lastReclaimable = _reclaimable;
            _lastMemoryValue = _memoryValue;
          });
        }
      } else {
        final mem = await clashCore.getMemory();
        if (mem > 0 && mounted) {
          setState(() {
            _inUse = mem;
            _memoryValue = TrafficValue(value: mem);
            _lastInUse = _inUse;
            _lastMemoryValue = _memoryValue;
          });
        }
      }
    } catch (_) {
    } finally {
      _isUpdating = false;
    }
  }

  Future<void> _handleForceGC(BuildContext context) async {
    final result = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.forceGCTitle,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(false);
            },
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(true);
            },
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: Text(appLocalizations.forceGCDesc),
      ),
    );

    if (result == true) {
      await clashCore.requestGc(forceFreeOSMemory: true);
      globalState.showNotifier(appLocalizations.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final totalMem = _inUse + _reclaimable;

    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        padding: EdgeInsets.zero,
        onPressed: () => showCoreStatusDialog(context),
        onLongPress: () => _handleForceGC(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoHeader(
              padding: baseInfoEdgeInsets.copyWith(bottom: 0),
              info: Info(
                label: appLocalizations.currentProfile,
                iconData: FluentIcons.rocket_24_regular,
              ),
              actions: [
                Transform.translate(
                  offset: Offset(2.ap, 0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        FluentIcons.settings_24_regular,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        if (profile != null) {
                          showCurrentProfileDialog();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.ap, 6.ap, 16.ap, 12.ap),
              child: TooltipText(
                text: Text(
                  profile?.label ?? appLocalizations.notAcquired,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17.ap,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.ap),
              child: Container(
                height: 1.0,
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.ap, 12.ap, 16.ap, 16.ap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appLocalizations.memoryInfo,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barHeight = 10.ap;
                        final totalWidth = constraints.maxWidth;
                        final gap = 4.ap;
                        final availableWidth = max(0.0, totalWidth - gap);
                        final minBarWidth = barHeight;

                        final targetInUseRatio = totalMem > 0
                            ? (_inUse / totalMem).clamp(0.0, 1.0)
                            : 1.0;

                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: targetInUseRatio),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeInOutCubic,
                          builder: (context, animatedRatio, _) {
                            double reclaimableW;
                            double inUseW;

                            if (availableWidth > minBarWidth * 2) {
                              final rawInUse = availableWidth * animatedRatio;
                              inUseW = rawInUse.clamp(minBarWidth, availableWidth - minBarWidth);
                              reclaimableW = max(minBarWidth, availableWidth - inUseW);
                            } else {
                              reclaimableW = minBarWidth;
                              inUseW = max(minBarWidth, availableWidth - minBarWidth);
                            }

                            return Row(
                              children: [
                                SizedBox(
                                  width: inUseW,
                                  height: barHeight,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: context.colorScheme.primary,
                                      shape: SuperellipseBorder(
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: gap),
                                SizedBox(
                                  width: reclaimableW,
                                  height: barHeight,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: context.colorScheme.tertiary,
                                      shape: SuperellipseBorder(
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _memoryValue.showValue,
                            style: context.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.normal,
                              fontSize: 22.ap,
                              height: 1.15,
                              color: (context.textTheme.bodyMedium?.color ??
                                      context.colorScheme.onSurface)
                                  .opacity80,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: _memoryValue.showUnit,
                            style: (context.textTheme.bodyMedium?.toLighter ??
                                    context.textTheme.bodyMedium?.copyWith(
                                      color: context.colorScheme.onSurface.opacity60,
                                    ))
                                ?.copyWith(
                              fontWeight: FontWeight.normal,
                              fontSize: 14.ap,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
