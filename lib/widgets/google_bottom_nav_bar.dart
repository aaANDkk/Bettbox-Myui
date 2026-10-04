import 'dart:math' as math;
import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoogleBottomNavBar extends ConsumerStatefulWidget {
  final List<NavigationItem> navigationItems;
  final int selectedIndex;
  final ValueChanged<int> onTabChange;

  const GoogleBottomNavBar({
    super.key,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onTabChange,
  });

  @override
  ConsumerState<GoogleBottomNavBar> createState() => _GoogleBottomNavBarState();
}

class _GoogleBottomNavBarState extends ConsumerState<GoogleBottomNavBar>
    with TickerProviderStateMixin {
  late final AnimationController _posController = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );
  late final AnimationController _liftController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    value: 0.0,
  );
  late final Listenable _animListenable =
      Listenable.merge([_posController, _liftController]);

  int? _activePointerId;
  bool _dragCancel = false;
  Offset? _downPosition;
  double _barWidth = 0;
  int _lastSnappedIndex = 0;
  int _lastHapticTime = 0;
  int? _animatingTargetIndex;
  late final ValueNotifier<int> _highlightedIndex = ValueNotifier(widget.selectedIndex);

  @override
  void initState() {
    super.initState();
    _lastSnappedIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant GoogleBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        _activePointerId == null) {
      _highlightedIndex.value = widget.selectedIndex;
      if (_animatingTargetIndex != widget.selectedIndex) {
        _lastSnappedIndex = widget.selectedIndex;
        _posController.animateTo(
          widget.selectedIndex.toDouble(),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
      _animatingTargetIndex = null;
    }
  }

  @override
  void dispose() {
    _highlightedIndex.dispose();
    _posController.dispose();
    _liftController.dispose();
    super.dispose();
  }

  void _triggerHapticFeedback(bool enableFeedback) {
    if (system.isAndroid && enableFeedback) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastHapticTime > 35) {
        _lastHapticTime = now;
        HapticFeedback.selectionClick();
      }
    }
  }

  double _calculateSlot(double dx) {
    const borderWidth = 1.0;
    final innerWidth = math.max(0.0, _barWidth - (2 * borderWidth));
    if (innerWidth <= 0 || widget.navigationItems.isEmpty) {
      return widget.selectedIndex.toDouble();
    }
    final count = widget.navigationItems.length;
    final slotWidth = innerWidth / count;
    final localDx = (dx - borderWidth).clamp(0.0, innerWidth);
    final rawSlot = (localDx / slotWidth) - 0.5;
    return rawSlot.clamp(0.0, (count - 1).toDouble());
  }

  int _slotToIndex(double slot) {
    final count = widget.navigationItems.length;
    if (count == 0) return 0;
    return slot.round().clamp(0, count - 1);
  }

  @override
  Widget build(BuildContext context) {
    final enableFeedback = ref.watch(
      appSettingProvider.select((state) => state.enableNavBarHapticFeedback),
    );
    final pureBlack = ref.watch(
      themeSettingProvider.select((s) => s.pureBlack),
    );
    final colorScheme = context.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final primaryColor = colorScheme.primary;
    final onSurfaceVariantColor = colorScheme.onSurfaceVariant;

    final navGradient = isLight
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                    colorScheme.surfaceContainerLowest,
                    Colors.white,
                    0.20,
                  )?.withValues(alpha: 0.98) ??
                  colorScheme.surface.withValues(alpha: 0.98),
              colorScheme.surfaceContainer.withValues(alpha: 0.96),
            ],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (!pureBlack
                          ? colorScheme.surfaceContainerHigh
                          : Color.lerp(
                              Colors.black,
                              colorScheme.surfaceContainerHighest,
                              0.10,
                            ))
                      ?.withValues(alpha: pureBlack ? 0.98 : 0.97) ??
                  Colors.black.withValues(alpha: 0.97),
              (!pureBlack ? colorScheme.surfaceContainer : Colors.black)
                  .withValues(alpha: pureBlack ? 0.97 : 0.95),
            ],
          );
    final borderColor = isLight
        ? colorScheme.outlineVariant.withValues(alpha: 0.24)
        : Colors.white.withValues(alpha: 0.08);

    const itemTextStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
    );

    final count = widget.navigationItems.length;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.only(left: 17, right: 17, top: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _barWidth = constraints.maxWidth;
            const borderWidth = 1.0;
            final innerWidth = math.max(0.0, _barWidth - (2 * borderWidth));
            final slotWidth = count > 0 ? innerWidth / count : innerWidth;
            const barHeight = 60.0;
            final innerHeight = barHeight - (2 * borderWidth);
            const baseGap = 5.0;

            return RepaintBoundary(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  if (_activePointerId != null) return;
                  _activePointerId = event.pointer;
                  _downPosition = event.localPosition;
                  _dragCancel = false;
                  final slot = _calculateSlot(event.localPosition.dx);
                  final targetIndex = _slotToIndex(slot);
                  _lastSnappedIndex = targetIndex;
                  _animatingTargetIndex = targetIndex;
                  _highlightedIndex.value = targetIndex;
                  _triggerHapticFeedback(enableFeedback);
                  _liftController.animateTo(1.0, curve: Curves.easeOut);
                  _posController.animateTo(
                    targetIndex.toDouble(),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                  );
                },
                onPointerMove: (event) {
                  if (_activePointerId != event.pointer || _dragCancel) return;
                  final downPos = _downPosition;
                  if (downPos != null) {
                    final delta = event.localPosition - downPos;
                    if (delta.dy < -50 || delta.dy > 80) {
                      _dragCancel = true;
                      _liftController.animateTo(0.0);
                      _highlightedIndex.value = widget.selectedIndex;
                      _posController.animateTo(
                        widget.selectedIndex.toDouble(),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                      );
                      return;
                    }
                    if (delta.dx.abs() > 8) {
                      final slot = _calculateSlot(event.localPosition.dx);
                      _posController.value = slot;
                      final index = _slotToIndex(slot);
                      _highlightedIndex.value = index;
                      if (index != _lastSnappedIndex) {
                        _lastSnappedIndex = index;
                        _triggerHapticFeedback(enableFeedback);
                      }
                    }
                  }
                },
                onPointerUp: (event) {
                  if (_activePointerId != event.pointer) return;
                  _activePointerId = null;
                  if (_dragCancel) {
                    _dragCancel = false;
                    return;
                  }
                  final targetIndex =
                      _slotToIndex(_calculateSlot(event.localPosition.dx));
                  _animatingTargetIndex = targetIndex;
                  _highlightedIndex.value = targetIndex;
                  _posController.animateTo(
                    targetIndex.toDouble(),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                  );
                  _liftController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                  );
                  if (targetIndex != widget.selectedIndex) {
                    widget.onTabChange(targetIndex);
                  }
                },
                onPointerCancel: (event) {
                  if (_activePointerId != event.pointer) return;
                  _activePointerId = null;
                  _dragCancel = false;
                  _animatingTargetIndex = null;
                  _highlightedIndex.value = widget.selectedIndex;
                  _posController.animateTo(
                    widget.selectedIndex.toDouble(),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                  );
                  _liftController.animateTo(0.0);
                },
                child: Container(
                  height: barHeight,
                  padding: const EdgeInsets.all(borderWidth),
                  decoration: BoxDecoration(
                    gradient: navGradient,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: borderColor,
                      width: 1,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                        color: Colors.black.withValues(
                          alpha: isLight ? 0.06 : 0.25,
                        ),
                      ),
                      BoxShadow(
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        color: Colors.black.withValues(
                          alpha: isLight ? 0.04 : 0.12,
                        ),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(29),
                    child: RepaintBoundary(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          AnimatedBuilder(
                            animation: _animListenable,
                            builder: (context, _) {
                              final lensPos = _posController.value;
                              final lift = _liftController.value;
                              final currentGap = baseGap * (1.0 - lift);
                              final pillWidth =
                                  math.max(0.0, slotWidth - (2 * currentGap));
                              final centerDx = (lensPos + 0.5) * slotWidth;
                              final pillLeft = centerDx - (pillWidth / 2);
                              final pillTop = currentGap;
                              final pillBottom = currentGap;
                              final pillRadius =
                                  (innerHeight - (2 * currentGap)) / 2;

                              final lensColor = isLight
                                  ? primaryColor.withValues(
                                      alpha: 0.08 + (0.05 * lift),
                                    )
                                  : primaryColor.withValues(
                                      alpha: 0.16 + (0.06 * lift),
                                    );
                              final lensBorderColor = isLight
                                  ? primaryColor.withValues(
                                      alpha: 0.12 + (0.10 * lift),
                                    )
                                  : primaryColor.withValues(
                                      alpha: 0.18 + (0.12 * lift),
                                    );

                              if (count == 0) return const SizedBox.shrink();

                              return Positioned(
                                left: pillLeft,
                                top: pillTop,
                                bottom: pillBottom,
                                width: pillWidth,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: lensColor,
                                    borderRadius:
                                        BorderRadius.circular(pillRadius),
                                    border: Border.all(
                                      color: lensBorderColor,
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      if (lift > 0.05)
                                        BoxShadow(
                                          color: (isLight
                                                  ? primaryColor
                                                  : Colors.white)
                                              .withValues(
                                            alpha: (isLight ? 0.12 : 0.08) *
                                                lift,
                                          ),
                                          blurRadius: 12,
                                          offset: Offset(0, 1 * lift),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _highlightedIndex,
                            builder: (context, highlightedIndex, _) {
                              return Row(
                                children: List.generate(count, (index) {
                                  final item = widget.navigationItems[index];
                                  final isHighlighted = index == highlightedIndex;
                                  final itemScale = isHighlighted ? 1.04 : 1.0;
                                  final itemColor = isHighlighted
                                      ? primaryColor
                                      : onSurfaceVariantColor;

                                  return Expanded(
                                    child: Center(
                                      child: AnimatedScale(
                                        scale: itemScale,
                                        duration: const Duration(milliseconds: 150),
                                        curve: Curves.easeOut,
                                        alignment: Alignment.center,
                                        child: TweenAnimationBuilder<Color?>(
                                          tween: ColorTween(
                                            begin: onSurfaceVariantColor,
                                            end: itemColor,
                                          ),
                                          duration: const Duration(milliseconds: 150),
                                          curve: Curves.easeOut,
                                          builder: (context, color, child) {
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconTheme(
                                                  data: IconThemeData(
                                                    color: color ?? onSurfaceVariantColor,
                                                    size: 22,
                                                  ),
                                                  child: item.icon,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.label.localizedName,
                                                  style: itemTextStyle.copyWith(
                                                    color: color,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
