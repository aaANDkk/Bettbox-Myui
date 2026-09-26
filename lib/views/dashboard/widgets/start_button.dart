import 'dart:async';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/add_profile.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton> {
  bool _isDisabled = false;
  bool? _optimisticStart;

  void _handleStart() async {
    if (_isDisabled) return;
    final isStart = ref.read(runTimeProvider) != null;
    final newState = !isStart;
    setState(() {
      _isDisabled = true;
      _optimisticStart = newState;
    });

    try {
      await globalState.appController.updateStatus(newState);
    } catch (e) {
      commonPrint.log('updateStatus failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _optimisticStart = null;
        });
      }
    }
  }

  Future<void> _handleLongPress() async {
    final isStart = ref.read(runTimeProvider) != null;
    if (!isStart) return;

    final result = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.restartCoreTitle,
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
        child: Text(appLocalizations.restartCoreDesc),
      ),
    );

    if (result == true) {
      await globalState.appController.restartCore();
      globalState.showNotifier(appLocalizations.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    final isSmartStopped = ref.watch(isSmartStoppedProvider);
    final isRestarting = ref.watch(isRestartingCoreProvider);
    final showLoading = _isDisabled || isRestarting || !state.isInit;
    final canPress = !showLoading && !isSmartStopped && state.hasProfile;
    final hasNoProfile = !showLoading && !isSmartStopped && !state.hasProfile;

    return ValueListenableBuilder<int>(
      valueListenable: dashboardRefreshManager.tick1s,
      builder: (_, _, _) {
        final runTime = ref.read(runTimeProvider);
        final isStart = runTime != null;
        final displayStart = isSmartStopped
            ? false
            : (_optimisticStart ?? isStart);
        return SizedBox(
          height: getWidgetHeight(1),
          child: CommonCard(
            info: Info(
              label: isRestarting
                  ? appLocalizations.restartCoreTitle
                  : displayStart
                  ? appLocalizations.runTime
                  : appLocalizations.powerSwitch,
              iconData: FluentIcons.power_24_regular,
            ),
            onPressed: canPress
                ? _handleStart
                : hasNoProfile
                    ? showAddProfileExtend
                    : null,
            onLongPress: isStart && canPress ? _handleLongPress : null,
            child: Container(
              padding: baseInfoEdgeInsets.copyWith(top: 0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: globalState.measure.bodyMediumHeight + 2,
                    child: FadeThroughBox(
                      child: _buildContent(
                        context,
                        ref,
                        state,
                        displayStart,
                        runTime,
                        isRestarting,
                        showLoading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    StartButtonSelectorState state,
    bool isStart,
    int? runTime,
    bool isRestarting,
    bool showLoading,
  ) {
    if (showLoading && !isRestarting) {
      return Container(
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
      );
    }

    if (!state.hasProfile) {
      return Text(
        appLocalizations.checkOrAddProfile,
        style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (isRestarting) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 16,
          height: 16,
          child: OverflowBox(
            maxWidth: 30,
            maxHeight: 16,
            child: SpinKitThreeBounce(
              color: context.colorScheme.primary,
              size: 16,
            ),
          ),
        ),
      );
    }

    if (!isStart) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            size: 16,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              appLocalizations.serviceReady,
              style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final timeText = _formatRunTime(runTime);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          Icons.pause_rounded,
          size: 16,
          color: context.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        const Text('  '),
        Expanded(
          child: Text(
            timeText,
            style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatRunTime(int? timeStamp) {
    if (timeStamp == null) return '00:00:00';

    final diff = timeStamp / 1000;
    int inHours = (diff / 3600).floor();
    int inMinutes = (diff / 60 % 60).floor();
    int inSeconds = (diff % 60).floor();

    if (inHours > 999) {
      inHours = 999;
      inMinutes = 59;
      inSeconds = 59;
    }

    final hourStr = inHours < 100
        ? inHours.toString().padLeft(2, '0')
        : inHours.toString().padLeft(3, '0');

    return '$hourStr:${inMinutes.toString().padLeft(2, '0')}:${inSeconds.toString().padLeft(2, '0')}';
  }
}
