import 'dart:math';
import 'dart:ui';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class StartFab extends ConsumerStatefulWidget {
  const StartFab({super.key});

  @override
  ConsumerState<StartFab> createState() => _StartFabState();
}

class _StartFabState extends ConsumerState<StartFab> {
  bool _isDisabled = false;
  bool? _optimisticStart;

  Future<void> _handleStart() async {
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

  void _handleNoProfile() {
    globalState.showNotifier(appLocalizations.nullProfileDesc);
  }

  static const _threeDigitHourThreshold = 100 * 60 * 60 * 1000;
  static const _widthAnimationDuration = Duration(milliseconds: 200);

  double? _twoDigitTextWidth;
  double? _threeDigitTextWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _twoDigitTextWidth = null;
    _threeDigitTextWidth = null;
  }

  TextStyle _labelStyle(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.floatingActionButtonTheme.extendedTextStyle ??
        theme.textTheme.labelLarge ??
        DefaultTextStyle.of(context).style;
    final foregroundColor =
        theme.floatingActionButtonTheme.foregroundColor ??
            theme.colorScheme.onPrimaryContainer;
    return base.copyWith(
      color: foregroundColor,
      height: 1.15,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  double _getRunTimeTextWidth(
    BuildContext context, {
    required bool hasThreeDigitHours,
  }) {
    if (hasThreeDigitHours) {
      return _threeDigitTextWidth ??=
          _computeRunTimeWidth(context, isThreeDigit: true);
    }
    return _twoDigitTextWidth ??=
        _computeRunTimeWidth(context, isThreeDigit: false);
  }

  double _computeRunTimeWidth(
    BuildContext context, {
    required bool isThreeDigit,
  }) {
    final style = _labelStyle(context);
    final prefix = isThreeDigit ? '9' : '';
    final width0 = globalState.measure
        .computeTextSize(Text('${prefix}00:00:00', style: style))
        .width;
    final width8 = globalState.measure
        .computeTextSize(Text('${prefix}88:88:88', style: style))
        .width;
    final width9 = globalState.measure
        .computeTextSize(Text('${prefix}99:99:99', style: style))
        .width;
    final maxTextWidth = [width0, width8, width9].reduce(max);
    return maxTextWidth + 12.0;
  }

  double _computeWidth(BuildContext context, String text) {
    return globalState.measure
            .computeTextSize(Text(text, style: _labelStyle(context)))
            .width +
        12.0;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    final isRestarting = ref.watch(isRestartingCoreProvider);
    final showLoading = _isDisabled || isRestarting || !state.isInit;

    return ValueListenableBuilder<int>(
      valueListenable: dashboardRefreshManager.tick1s,
      builder: (_, _, _) {
        final runTime = ref.read(runTimeProvider);
        final isStart = runTime != null;
        final displayStart = _optimisticStart ?? isStart;
        final labelText = displayStart
            ? _formatRunTime(runTime)
            : appLocalizations.startRunning;
        final icon = displayStart ? Icons.pause : Icons.play_arrow;
        final startRunningWidth =
            _computeWidth(context, appLocalizations.startRunning);
        final hasThreeDigitHours =
            (runTime ?? 0) >= _threeDigitHourThreshold;
        final targetWidth = displayStart
            ? _getRunTimeTextWidth(
                context,
                hasThreeDigitHours: hasThreeDigitHours,
              )
            : startRunningWidth;

        final isDark =
            Theme.of(context).colorScheme.brightness == Brightness.dark;
        return GestureDetector(
          onLongPress: isStart && !showLoading ? _handleLongPress : null,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.14,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.20 : 0.06,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  elevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  clipBehavior: Clip.none,
                  heroTag: null,
                  onPressed: showLoading
                      ? null
                      : state.hasProfile
                          ? _handleStart
                          : _handleNoProfile,
                  icon: Opacity(
                    opacity: showLoading ? 0.0 : 1.0,
                    child: Icon(icon),
                  ),
                  label: Opacity(
                    opacity: showLoading ? 0.0 : 1.0,
                    child: AnimatedContainer(
                      duration: _widthAnimationDuration,
                      curve: Curves.easeOut,
                      width: targetWidth,
                      alignment: Alignment.center,
                      child: Text(
                        labelText,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                        style: _labelStyle(context),
                      ),
                    ),
                  ),
                ),
              ),
              if (showLoading)
                IgnorePointer(
                  child: SizedBox(
                    width: 30,
                    height: 16,
                    child: OverflowBox(
                      maxWidth: 30,
                      maxHeight: 16,
                      child: SpinKitThreeBounce(
                        color: Theme.of(context)
                                .floatingActionButtonTheme
                                .foregroundColor ??
                            context.colorScheme.onPrimaryContainer,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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

