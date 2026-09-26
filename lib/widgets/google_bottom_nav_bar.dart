import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/common.dart';
import 'package:bett_box/providers/config.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:bett_box/widgets/animated_nav_icon.dart';

class GoogleBottomNavBar extends ConsumerWidget {
  final List<NavigationItem> navigationItems;
  final int selectedIndex;
  final ValueChanged<int> onTabChange;

  const GoogleBottomNavBar({
    super.key,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onTabChange,
  });

  IconData _extractIconData(Widget iconWidget) {
    if (iconWidget is Icon) {
      return iconWidget.icon ?? FluentIcons.home_24_filled;
    }
    return FluentIcons.home_24_filled;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableHapticFeedback = ref.watch(
      appSettingProvider.select((state) => state.enableNavBarHapticFeedback),
    );
    final tabsList = navigationItems.asMap().entries.map((entry) {
      final index = entry.key;
      final e = entry.value;
      final isSelected = selectedIndex == index;
      return GButton(
        icon: e.label.regularNavIcon,
        leading: AnimatedNavIcon(
          label: e.label,
          selected: isSelected,
          color: isSelected
              ? context.colorScheme.primary
              : context.colorScheme.onSurfaceVariant,
        ),
        text: Intl.message(e.label.name),
      );
    }).toList();

    void handleTabChange(int index) {
      // Trigger vibration only if haptic feedback enabled
      if (system.isAndroid && enableHapticFeedback) {
        HapticFeedback.selectionClick(); // Lighter haptic feedback
      }
      onTabChange(index);
    }

    final isLight = context.colorScheme.brightness == Brightness.light;
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: max(viewBottom, 12.0)),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                  color: Colors.black.withValues(
                    alpha: isLight ? 0.08 : 0.22,
                  ),
                ),
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                  color: Colors.black.withValues(
                    alpha: isLight ? 0.04 : 0.10,
                  ),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9.0,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: (isLight
                            ? context.colorScheme.surface
                            : context.colorScheme.surfaceContainer)
                        .withValues(alpha: isLight ? 0.80 : 0.72),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: isLight
                          ? context.colorScheme.outlineVariant.withValues(
                              alpha: 0.45,
                            )
                          : Colors.white.withValues(alpha: 0.14),
                      width: 1,
                    ),
                  ),
                  child: GNav(
                    rippleColor: enableHapticFeedback
                        ? context.colorScheme.onSurface.withValues(alpha: 0.15)
                        : Colors.transparent, // Disabling ripple may disable haptic feedback
                    hoverColor: context.colorScheme.onSurface.withValues(
                      alpha: 0.1,
                    ),
                    haptic: enableHapticFeedback, // Control GNav haptic feedback
                    // 只把文字往右推一点点：图标位置与胶囊总长都不能变。
                    // 原来 = 左16 + 图标 + gap8 + 文字 + 右16；
                    // 现在 = 左16 + 图标 + gap10 + 文字 + 右14（总和不变的 40）。
                    gap: 10,
                    activeColor: context.colorScheme.primary,
                    iconSize: 24,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 14,
                      top: 10,
                      bottom: 10,
                    ),
                    duration: const Duration(milliseconds: 250),
                    tabBackgroundColor: context.colorScheme.primary.withValues(
                      alpha: isLight ? 0.20 : 0.26,
                    ),
                    color: context.colorScheme.onSurfaceVariant,
                    tabs: tabsList,
                    selectedIndex: selectedIndex,
                    onTabChange: handleTabChange,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
