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
    required int count,
  }) {
    final isTesting = isItemTesting ||
        (isLoading &&
            (result == null || result.status == MediaUnlockStatus.testing));
    final status = isTesting
        ? MediaUnlockStatus.testing
        : (result?.status ??
            (isLoading ? MediaUnlockStatus.testing : MediaUnlockStatus.unknown));
    final color = status.statusColor(context.colorScheme);

    final double iconSize;
    final double textFontSize;
    final double dotSize;
    final double iconSpacing;
    final double borderRadius;

    if (count == 1) {
      iconSize = 20.ap;
      textFontSize = 13.5.ap;
      dotSize = 8.ap;
      iconSpacing = 9.ap;
      borderRadius = 11.ap;
    } else if (count == 2) {
      iconSize = 18.5.ap;
      textFontSize = 13.ap;
      dotSize = 7.5.ap;
      iconSpacing = 8.ap;
      borderRadius = 11.ap;
    } else if (count == 3) {
      iconSize = 17.5.ap;
      textFontSize = 12.5.ap;
      dotSize = 7.ap;
      iconSpacing = 7.ap;
      borderRadius = 10.ap;
    } else {
      iconSize = 16.ap;
      textFontSize = 11.5.ap;
      dotSize = 6.5.ap;
      iconSpacing = 7.ap;
      borderRadius = 10.ap;
    }

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isDark
        ? Color.alphaBlend(
            context.colorScheme.onSurface.withValues(alpha: 0.10),
            context.colorScheme.surfaceContainerHighest,
          )
        : context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.65,
          );
    final rowBorder = isDark
        ? BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.8,
          )
        : BorderSide.none;

    return DecoratedBox(
      key: ValueKey(platform),
      decoration: ShapeDecoration(
        color: rowBg,
        shape: SuperellipseBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: rowBorder,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.ap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 20.ap,
              height: 20.ap,
              child: Center(
                child: themedPlatformIcon(context, platform, icon),
              ),
            ),
            SizedBox(width: iconSpacing),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform.defaultName,
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: textFontSize,
                      color: context.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (count <= 2) ...[
                    SizedBox(height: 2.ap),
                    Text(
                      result?.latency != null
                          ? '${result!.latency}ms'
                          : (isTesting ? '...' : '-'),
                      style: context.textTheme.bodySmall?.copyWith(
                        fontSize: (textFontSize - 2.ap).clamp(9.5.ap, 11.5.ap),
                        fontWeight: FontWeight.w500,
                        color: context.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 6.ap),
            SizedBox(
              width: 16.ap,
              height: 16.ap,
              child: Center(
                child: isTesting
                    ? RepaintBoundary(
                        child: SizedBox(
                          width: dotSize + 3.ap,
                          height: dotSize + 3.ap,
                          child: SpinKitFadingCircle(
                            color: context.colorScheme.primary,
                            size: dotSize + 3.ap,
                          ),
                        ),
                      )
                    : Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: ShapeDecoration(
                          color: color,
                          shape: const CircleBorder(),
                        ),
                      ),
              ),
            ),
          ],
        ),
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

          final int count = displayedPlatforms.length;
          final double gap = count == 4
              ? 6.ap
              : (count == 3 ? 8.ap : (count == 2 ? 10.ap : 0.0));

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
                  info: Info(
                    label: appLocalizations.mediaUnlockShort,
                    iconData: IconsExt.cowork,
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
                          onPressed: isWidgetLoading
                              ? null
                              : () => mediaUnlockState.checkPlatforms(
                                    displayedPlatforms,
                                    force: true,
                                  ),
                          icon: isWidgetLoading
                              ? RepaintBoundary(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: SpinKitFadingCircle(
                                      color: context.colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : Icon(
                                  FluentIcons.arrow_sync_24_regular,
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.ap, 10.ap, 16.ap, 16.ap),
                    child: Column(
                      children: [
                        for (int i = 0; i < count; i++) ...[
                          if (i > 0) SizedBox(height: gap),
                          Expanded(
                            child: _buildPlatformRow(
                              displayedPlatforms[i],
                              state.results[displayedPlatforms[i]],
                              state.isLoading,
                              context,
                              isItemTesting: state.testingPlatforms
                                  .contains(displayedPlatforms[i]),
                              colorfulIcons: colorfulIcons,
                              count: count,
                            ),
                          ),
                        ],
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
