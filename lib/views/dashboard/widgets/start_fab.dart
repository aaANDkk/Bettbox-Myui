import 'dart:math';
import 'dart:ui';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

const startFabWidthAnimationDuration = Duration(milliseconds: 200);

TextStyle startFabLabelStyle(BuildContext context) {
  final theme = Theme.of(context);
  final base =
      theme.floatingActionButtonTheme.extendedTextStyle ??
      theme.textTheme.labelLarge ??
      DefaultTextStyle.of(context).style;
  final foregroundColor =
      theme.floatingActionButtonTheme.foregroundColor ??
      theme.colorScheme.onPrimaryContainer;
  final fontFamily =
      theme.textTheme.labelLarge?.fontFamily ??
      theme.floatingActionButtonTheme.extendedTextStyle?.fontFamily;
  return base.copyWith(
    color: foregroundColor,
    fontFamily: fontFamily,
    fontWeight: FontWeight.bold,
    fontVariations: const [FontVariation('wght', 700)],
    height: 1.25,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

double startFabTextWidth(BuildContext context, String text) {
  return globalState.measure
      .computeTextSize(Text(text, style: startFabLabelStyle(context)))
      .width;
}

double startFabLabelWidth(BuildContext context, String text) {
  return startFabTextWidth(context, text) + 12.0;
}

@immutable
class StartFabData {
  const StartFabData({
    required this.icon,
    required this.labelText,
    required this.labelWidth,
    required this.showLoading,
    this.isRunTime = false,
    this.isExtended = true,
    this.onPressed,
    this.onLongPress,
  });

  final IconData icon;
  final String labelText;
  final double labelWidth;
  final bool showLoading;
  final bool isRunTime;
  final bool isExtended;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
}

class StartFabDataProvider extends ConsumerStatefulWidget {
  const StartFabDataProvider({super.key, required this.builder});

  final Widget Function(BuildContext context, StartFabData data) builder;

  @override
  ConsumerState<StartFabDataProvider> createState() =>
      _StartFabDataProviderState();
}

class _StartFabDataProviderState extends ConsumerState<StartFabDataProvider> {
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

  double? _twoDigitTextWidth;
  double? _threeDigitTextWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _twoDigitTextWidth = null;
    _threeDigitTextWidth = null;
  }

  double _getRunTimeTextWidth(
    BuildContext context, {
    required bool hasThreeDigitHours,
  }) {
    if (hasThreeDigitHours) {
      return _threeDigitTextWidth ??= _computeRunTimeWidth(
        context,
        isThreeDigit: true,
      );
    }
    return _twoDigitTextWidth ??= _computeRunTimeWidth(
      context,
      isThreeDigit: false,
    );
  }

  double _computeRunTimeWidth(
    BuildContext context, {
    required bool isThreeDigit,
  }) {
    final style = startFabLabelStyle(context);
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    final isRestarting = ref.watch(isRestartingCoreProvider);
    final isSmartStopped = ref.watch(isSmartStoppedProvider);
    final showLoading = _isDisabled || isRestarting || !state.isInit;
    final canPress = !showLoading && !isSmartStopped;

    return ValueListenableBuilder<int>(
      valueListenable: dashboardRefreshManager.tick1s,
      builder: (_, _, _) {
        final runTime = ref.read(runTimeProvider);
        final isStart = runTime != null;
        final displayStart = isSmartStopped
            ? false
            : (_optimisticStart ?? isStart);
        final hasThreeDigitHours = (runTime ?? 0) >= _threeDigitHourThreshold;

        return widget.builder(
          context,
          StartFabData(
            icon: displayStart
                ? FluentIcons.align_space_around_vertical_20_filled
                : FluentIcons.play_24_filled,
            labelText: displayStart ? _formatRunTime(runTime) : '',
            labelWidth: displayStart
                ? _getRunTimeTextWidth(
                    context,
                    hasThreeDigitHours: hasThreeDigitHours,
                  )
                : 0.0,
            showLoading: showLoading,
            isRunTime: displayStart,
            isExtended: displayStart,
            onPressed: !canPress
                ? null
                : state.hasProfile
                ? _handleStart
                : _handleNoProfile,
            onLongPress: isStart && !showLoading && !isSmartStopped
                ? _handleLongPress
                : null,
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

Widget buildStartFabBody(BuildContext context, StartFabData data) {
  return GestureDetector(
    onLongPress: data.onLongPress,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: getCommonFabDecoration(context),
          child: FloatingActionButton.extended(
            extendedIconLabelSpacing: 0.0,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            elevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            focusElevation: 0,
            clipBehavior: Clip.none,
            heroTag: null,
            onPressed: data.onPressed,
            icon: Opacity(
              opacity: data.showLoading ? 0.0 : 1.0,
              child: Icon(data.icon),
            ),
            label: Opacity(
              opacity: data.showLoading ? 0.0 : 1.0,
              child: AnimatedContainer(
                duration: startFabWidthAnimationDuration,
                curve: Curves.easeOut,
                width: data.isExtended ? (data.labelWidth + 12.0) : 0.0,
                alignment: data.isRunTime
                    ? Alignment.centerLeft
                    : Alignment.center,
                padding: EdgeInsets.only(
                  left: data.isExtended ? (data.isRunTime ? 14.0 : 8.0) : 0.0,
                  right: data.isExtended ? 4.0 : 0.0,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    fit: OverflowBoxFit.deferToChild,
                    alignment: data.isRunTime
                        ? Alignment.centerLeft
                        : Alignment.center,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: Text(
                      data.labelText,
                      maxLines: 1,
                      textAlign: data.isRunTime
                          ? TextAlign.left
                          : TextAlign.center,
                      overflow: TextOverflow.visible,
                      style: startFabLabelStyle(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (data.showLoading)
          IgnorePointer(
            child: SizedBox(
              width: 30,
              height: 16,
              child: OverflowBox(
                maxWidth: 30,
                maxHeight: 16,
                child: SpinKitThreeBounce(
                  color:
                      Theme.of(
                        context,
                      ).floatingActionButtonTheme.foregroundColor ??
                      context.colorScheme.onPrimaryContainer,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class StartFab extends StatelessWidget {
  const StartFab({super.key});

  @override
  Widget build(BuildContext context) {
    return StartFabDataProvider(
      builder: (context, data) => buildStartFabBody(context, data),
    );
  }
}
