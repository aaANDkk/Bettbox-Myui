import 'dart:math';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

extension ColorExtension on Color {
  Color get opacity80 {
    return withAlpha(204);
  }

  Color get opacity60 {
    return withAlpha(153);
  }

  Color get opacity50 {
    return withAlpha(128);
  }

  Color get opacity38 {
    return withAlpha(97);
  }

  Color get opacity30 {
    return withAlpha(77);
  }

  Color get opacity12 {
    return withAlpha(31);
  }

  Color get opacity15 {
    return withAlpha(38);
  }

  Color get opacity10 {
    return withAlpha(15);
  }

  Color get opacity3 {
    return withAlpha(76);
  }

  Color get opacity0 {
    return withAlpha(0);
  }

  int get value32bit {
    return _floatToInt8(a) << 24 |
        _floatToInt8(r) << 16 |
        _floatToInt8(g) << 8 |
        _floatToInt8(b) << 0;
  }

  int get alpha8bit => (0xff000000 & value32bit) >> 24;

  int get red8bit => (0x00ff0000 & value32bit) >> 16;

  int get green8bit => (0x0000ff00 & value32bit) >> 8;

  int get blue8bit => (0x000000ff & value32bit) >> 0;

  int _floatToInt8(double x) {
    return (x * 255.0).round() & 0xff;
  }

  Color lighten([double amount = 10]) {
    if (amount <= 0) return this;
    if (amount > 100) return Colors.white;
    final HSLColor hsl = this == const Color(0xFF000000)
        ? HSLColor.fromColor(this).withSaturation(0)
        : HSLColor.fromColor(this);
    return hsl
        .withLightness(min(1, max(0, hsl.lightness + amount / 100)))
        .toColor();
  }

  String get hex {
    final value = toARGB32();
    final red = (value >> 16) & 0xFF;
    final green = (value >> 8) & 0xFF;
    final blue = value & 0xFF;
    return '#${red.toRadixString(16).padLeft(2, '0')}'
            '${green.toRadixString(16).padLeft(2, '0')}'
            '${blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Color darken([int amount = 10]) {
    if (amount <= 0) return this;
    if (amount > 100) return Colors.black;
    final HSLColor hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness(min(1, max(0, hsl.lightness - amount / 100)))
        .toColor();
  }

  Color blendDarken(BuildContext context, {double factor = 0.1}) {
    final brightness = Theme.of(context).brightness;
    return Color.lerp(
      this,
      brightness == Brightness.dark ? Colors.white : Colors.black,
      factor,
    )!;
  }

  Color blendLighten(BuildContext context, {double factor = 0.1}) {
    final brightness = Theme.of(context).brightness;
    return Color.lerp(
      this,
      brightness == Brightness.dark ? Colors.black : Colors.white,
      factor,
    )!;
  }
}

extension ColorSchemeExtension on ColorScheme {
  ColorScheme toPureBlack(bool isPrueBlack) => isPrueBlack
      ? copyWith(
          surface: Colors.black,
          surfaceContainer: surfaceContainer.darken(5),
          surfaceContainerLow: Colors.black,
        )
      : this;

  Color get success => Colors.green.harmonizeWith(primary);

  Color get warning => Colors.orange.harmonizeWith(primary);

  Color? delayColor(int? delay) {
    if (delay == null) return null;
    if (delay < 0) return error;
    if (delay < 600) return success;
    return warning;
  }
}

/// Hairline used for structural separations (window header, side bar) and for
/// the dividers inside cards, so every line in the app shares one token that
/// follows the theme's neutral variant and the current brightness.
Color panelDividerColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return colorScheme.outlineVariant.withValues(
    alpha: colorScheme.brightness == Brightness.light ? 0.6 : 0.45,
  );
}

/// Idle surface of selectable option cards (theme mode, pickers, …): must
/// differ from both the page and [commonCardColor], otherwise the unselected
/// options read as ordinary cards.
Color optionCardColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  if (colorScheme.brightness == Brightness.light) {
    return colorScheme.surfaceContainerHigh;
  }
  return colorScheme.surfaceContainerHighest;
}

/// Selected-item tint matching the floating nav bar's tab background.
Color navSelectedColor(ColorScheme colorScheme, {bool hovered = false}) {
  if (hovered) {
    return Color.alphaBlend(
      colorScheme.onSecondaryContainer.withValues(alpha: 0.08),
      colorScheme.secondaryContainer,
    );
  }
  return colorScheme.secondaryContainer;
}

// Lifts every channel by a few units, saturating at white.
Color _liftColor(Color color, [double amount = 3]) {
  int channel(double value) {
    return (value * 255 + amount).round().clamp(0, 255).toInt();
  }

  return Color.fromARGB(
    255,
    channel(color.r),
    channel(color.g),
    channel(color.b),
  );
}

Color commonCardColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  if (colorScheme.brightness == Brightness.light) {
    return _liftColor(
      Color.lerp(
            colorScheme.surfaceContainerLow,
            colorScheme.surfaceContainerLowest,
            0.72,
          ) ??
          colorScheme.surfaceContainerLow,
    );
  }
  return colorScheme.surfaceContainerHigh;
}

// The side bar and the window header stay on the plain 60% blend on purpose:
// only the cards (and the widgets built from them) carry the extra lift.
Color sidebarSurfaceColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  if (colorScheme.brightness == Brightness.light) {
    return Color.lerp(
          colorScheme.surfaceContainerLow,
          colorScheme.surfaceContainerLowest,
          0.60,
        ) ??
        colorScheme.surfaceContainerLow;
  }
  return colorScheme.surfaceContainerHigh;
}

Color headerSurfaceColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  if (colorScheme.brightness == Brightness.light) {
    return Color.lerp(
          colorScheme.surface,
          colorScheme.surfaceContainerLowest,
          0.60,
        ) ??
        colorScheme.surface;
  }
  return colorScheme.surfaceContainerHighest;
}





