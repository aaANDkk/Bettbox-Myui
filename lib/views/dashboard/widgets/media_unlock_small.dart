import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/pages/pages.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class MediaUnlockSmall extends ConsumerStatefulWidget {
  const MediaUnlockSmall({super.key});

  @override
  ConsumerState<MediaUnlockSmall> createState() => _MediaUnlockSmallState();
}

class _MediaUnlockSmallState extends ConsumerState<MediaUnlockSmall> {
  MediaUnlockState? _lastState;
  List<MediaPlatform>? _lastDisplayedPlatforms;
  bool? _lastColorfulIcons;
  Widget? _cachedCard;

  bool _shouldRebuildCard({
    required MediaUnlockState newState,
    required List<MediaPlatform> displayedPlatforms,
    required bool colorfulIcons,
  }) {
    if (_lastState == null ||
        _cachedCard == null ||
        _lastDisplayedPlatforms == null ||
        _lastColorfulIcons == null) {
      return true;
    }
    if (!listEquals(_lastDisplayedPlatforms, displayedPlatforms)) {
      return true;
    }
    if (_lastColorfulIcons != colorfulIcons) {
      return true;
    }
    if (_lastState!.isLoading != newState.isLoading) {
      return true;
    }
    for (final p in displayedPlatforms) {
      if (_lastState!.testingPlatforms.contains(p) !=
          newState.testingPlatforms.contains(p)) {
        return true;
      }
      if (_lastState!.results[p] != newState.results[p]) {
        return true;
      }
    }
    return false;
  }

  Widget _buildPlatformRow(
    MediaPlatform platform,
    MediaUnlockResult? result,
    bool isLoading,
    BuildContext context, {
    bool isItemTesting = false,
    required bool colorfulIcons,
  }) {
    final isTesting = isItemTesting ||
        (isLoading &&
            (result == null || result.status == MediaUnlockStatus.testing));
    final status = isTesting
        ? MediaUnlockStatus.testing
        : (result?.status ?? (isLoading ? MediaUnlockStatus.testing : MediaUnlockStatus.unknown));
    final color = status.statusColor(context.colorScheme);

    final double iconSize = 16.ap;
    final Widget icon;
    if (platform.isMonochrome) {
      icon = SvgPicture.asset(
        'assets/images/platforms/${platform.name}.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          context.colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      );
    } else if (colorfulIcons) {
      icon = SvgPicture.asset(
        'assets/images/platforms/${platform.name}.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
    } else {
      icon = ColorFiltered(
        colorFilter: monochromeColorFilter,
        child: SvgPicture.asset(
          'assets/images/platforms/${platform.name}.svg',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
      );
    }

    return SizedBox(
      key: ValueKey(platform),
      height: 24.ap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20.ap,
            height: 20.ap,
            child: Center(child: themedPlatformIcon(context, platform, icon)),
          ),
          SizedBox(width: 8.ap),
          Expanded(
            child: Text(
              platform.defaultName,
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 12.ap,
                color: context.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8.ap),
          SizedBox(
            width: 24.ap,
            height: 24.ap,
            child: Center(
              child: status == MediaUnlockStatus.testing
                  ? RepaintBoundary(
                      child: SizedBox(
                        width: 10.ap,
                        height: 10.ap,
                        child: SpinKitFadingCircle(
                          color: context.colorScheme.primary,
                          size: 10.ap,
                        ),
                      ),
                    )
                  : Container(
                      width: 7.ap,
                      height: 7.ap,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = ref.watch(
      appSettingProvider.select((state) => state.pinnedMediaPlatforms),
    );
    final colorfulIcons = ref.watch(
      appSettingProvider.select((state) => state.mediaUnlockColorfulIcons),
    );
    final displayedPlatforms =
        (pinned.isNotEmpty ? pinned : defaultPinnedMediaPlatforms)
            .take(4)
            .toList();

    return SizedBox(
      height: getWidgetHeight(2),
      child: ValueListenableBuilder<MediaUnlockState>(
        valueListenable: mediaUnlockState.state,
        builder: (context, state, _) {
          final shouldRebuild = _shouldRebuildCard(
            newState: state,
            displayedPlatforms: displayedPlatforms,
            colorfulIcons: colorfulIcons,
          );
          if (!shouldRebuild) {
            return _cachedCard!;
          }
          _lastState = state;
          _lastDisplayedPlatforms = displayedPlatforms;
          _lastColorfulIcons = colorfulIcons;

          final isWidgetLoading =
              displayedPlatforms.any(state.testingPlatforms.contains);
          final card = CommonCard(
            onPressed: () {
              showExtend(
                context,
                builder: (_, type) => MediaUnlockPage(type: type),
              );
            },
            child: Column(
              children: [
                InfoHeader(
                  padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                  actionsHeight: globalState.measure.titleSmallHeight,
                  info: Info(
                    label: appLocalizations.mediaUnlockShort,
                    iconData: FluentIcons.link_24_regular,
                  ),
                  actions: [
                    SizedBox(
                      width: 24.ap,
                      height: 24.ap,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: isWidgetLoading
                            ? null
                            : () => mediaUnlockState.checkPlatforms(
                                  displayedPlatforms,
                                  force: true,
                                ),
                        icon: isWidgetLoading
                            ? RepaintBoundary(
                                child: SizedBox(
                                  width: 16.ap,
                                  height: 16.ap,
                                  child: SpinKitFadingCircle(
                                    color: context.colorScheme.primary,
                                    size: 16.ap,
                                  ),
                                ),
                              )
                            : Icon(
                                FluentIcons.arrow_sync_24_regular,
                                size: 18.ap,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.ap, 8.ap, 16.ap, 4.ap),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.ap, 2.ap, 16.ap, 8.ap),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final p in displayedPlatforms)
                          _buildPlatformRow(
                            p,
                            state.results[p],
                            state.isLoading,
                            context,
                            isItemTesting:
                                state.testingPlatforms.contains(p),
                            colorfulIcons: colorfulIcons,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
          _cachedCard = card;
          return card;
        },
      ),
    );
  }
}
