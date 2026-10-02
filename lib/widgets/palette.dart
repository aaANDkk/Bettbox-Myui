import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/color_scheme_box.dart';
import 'package:bett_box/widgets/input.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/hct/hct.dart';

const _trackHeight = 20.0;
const _thumbRadius = 14.0;
const _trackTone = 60.0;
const _previewInset = 8.0;

// The tone strip's hairline sits on a surface ring instead of on the darkest
// cells, which would swallow an outlineVariant line in dark mode.
const double _toneStripBorder = 1.0;

// One dp tighter than the hairline, so the inner clip never reads as rounder
// than the outer border.
const double _toneStripInnerRadius = 16 - _toneStripBorder - 1;

// Every panel in the palette shares one hairline: the same colour and width as
// the role-preview card.
BorderSide _panelBorderSide(ColorScheme colorScheme) =>
    BorderSide(color: colorScheme.outlineVariant);

class _SuperellipseClipper extends CustomClipper<Path> {
  final BorderRadius borderRadius;

  const _SuperellipseClipper({required this.borderRadius});

  @override
  Path getClip(Size size) {
    return RoundedSuperellipseBorder(
      borderRadius: borderRadius,
    ).getOuterPath(Offset.zero & size);
  }

  @override
  bool shouldReclip(_SuperellipseClipper oldClipper) =>
      borderRadius != oldClipper.borderRadius;
}

Color? parseColor(String input) {
  final cleanInput = input.trim().replaceAll(' ', '').toLowerCase();

  // 3-digit Hex: #RGB or RGB
  if (RegExp(r'^#?[0-9a-f]{3}$').hasMatch(cleanInput)) {
    final hexString = cleanInput.startsWith('#')
        ? cleanInput.substring(1)
        : cleanInput;
    final r = hexString[0];
    final g = hexString[1];
    final b = hexString[2];
    return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
  }

  // 6-digit Hex: #RRGGBB or RRGGBB
  if (RegExp(r'^#?[0-9a-f]{6}$').hasMatch(cleanInput)) {
    final hexString = cleanInput.startsWith('#')
        ? cleanInput.substring(1)
        : cleanInput;
    return Color(int.parse('FF$hexString', radix: 16));
  }

  // 8-digit Hex with alpha: #AARRGGBB or AARRGGBB
  if (RegExp(r'^#?[0-9a-f]{8}$').hasMatch(cleanInput)) {
    final hexString = cleanInput.startsWith('#')
        ? cleanInput.substring(1)
        : cleanInput;
    return Color(int.parse(hexString, radix: 16));
  }

  // RGB/RGBA: rgb(255,255,255) or rgba(255,255,255,1.0)
  final rgbMatch = RegExp(
    r'^rgba?\((\d+),(\d+),(\d+)(?:,([\d.]+))?\)$',
  ).firstMatch(cleanInput);
  if (rgbMatch != null) {
    final r = int.parse(rgbMatch.group(1)!);
    final g = int.parse(rgbMatch.group(2)!);
    final b = int.parse(rgbMatch.group(3)!);
    final aStr = rgbMatch.group(4);
    final a = aStr != null ? double.parse(aStr) : 1.0;

    final alphaVal = (a * 255).round().clamp(0, 255);
    final rVal = r.clamp(0, 255);
    final gVal = g.clamp(0, 255);
    final bVal = b.clamp(0, 255);
    return Color.fromARGB(alphaVal, rVal, gVal, bVal);
  }

  return null;
}

class Palette extends StatefulWidget {
  const Palette({super.key, required this.controller});

  final ValueNotifier<Color> controller;

  @override
  State<Palette> createState() => _PaletteState();
}

class _PaletteState extends State<Palette> {
  double _hue = 0;
  double _chroma = 0;
  double _tone = 0;

  @override
  void initState() {
    super.initState();
    _initFromColor(widget.controller.value);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(Palette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.value.toARGB32() != _toColor().toARGB32()) {
      setState(() {
        _initFromColor(widget.controller.value);
      });
    }
  }

  void _initFromColor(Color color) {
    final hct = Hct.fromInt(color.toARGB32());
    _hue = hct.hue;
    _chroma = hct.chroma;
    _tone = hct.tone;
  }

  Color _toColor() => Color(Hct.from(_hue, _chroma, _tone).toInt());

  void _onHueChanged(double value) {
    setState(() => _hue = value);
    widget.controller.value = _toColor();
  }

  void _onChromaChanged(double value) {
    setState(() => _chroma = value);
    widget.controller.value = _toColor();
  }

  void _onToneSelected(double tone) {
    setState(() => _tone = tone);
    widget.controller.value = _toColor();
  }

  Future<void> _handleCustomInput(BuildContext context) async {
    final currentColorHex = widget.controller.value.hex;
    final customColorStr = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.color,
        value: currentColorHex,
        hintText: '#000000 / rgb(0,0,0)',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.color);
          }
          if (parseColor(value) == null) {
            return appLocalizations.formatError;
          }
          return null;
        },
      ),
    );
    if (customColorStr != null) {
      final newColor = parseColor(customColorStr);
      if (newColor != null) {
        widget.controller.value = newColor;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxChroma = Hct.from(_hue, 200, _trackTone).chroma;
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (_, currentColor, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GradientSlider(
                value: _hue,
                max: 360,
                thumbColor: Color(Hct.from(_hue, 100, _trackTone).toInt()),
                colors: [
                  for (var hue = 0; hue <= 360; hue += 10)
                    Color(Hct.from(hue.toDouble(), 100, _trackTone).toInt()),
                ],
                onChanged: _onHueChanged,
              ),
              const SizedBox(height: 8),
              _GradientSlider(
                value: _chroma.clamp(0, maxChroma),
                max: maxChroma,
                thumbColor: Color(Hct.from(_hue, _chroma, _trackTone).toInt()),
                colors: [
                  for (var i = 0; i <= 24; i++)
                    Color(
                      Hct.from(_hue, maxChroma * i / 24, _trackTone).toInt(),
                    ),
                ],
                onChanged: _onChromaChanged,
              ),
              const SizedBox(height: 14),
              _ToneStrip(
                hue: _hue,
                chroma: _chroma,
                selectedTone: _tone,
                onToneSelected: _onToneSelected,
              ),
              const SizedBox(height: 14),
              Material(
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: _panelBorderSide(theme.colorScheme),
                ),
                color: theme.colorScheme.surfaceContainer,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _handleCustomInput(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: ShapeDecoration(
                            color: currentColor,
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            shadows: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            currentColor.hex,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Icon(
                          FluentIcons.edit_24_regular,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  appLocalizations.preview,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              PrimaryColorBox(
                primaryColor: currentColor,
                child: const _ColorSchemePreview(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.value,
    required this.max,
    required this.thumbColor,
    required this.colors,
    required this.onChanged,
  });

  final double value;
  final double max;
  final Color thumbColor;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackShape: _GradientTrackShape(
          colors: colors,
          outlineColor: Theme.of(context).colorScheme.outlineVariant,
        ),
        trackHeight: _trackHeight,
        thumbShape: _ColorThumbShape(color: thumbColor),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(
        padding: EdgeInsets.zero,
        value: value,
        min: 0,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}

class _GradientTrackShape extends SliderTrackShape {
  const _GradientTrackShape({required this.colors, required this.outlineColor});

  final List<Color> colors;
  final Color outlineColor;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? _trackHeight;
    return Rect.fromLTWH(
      offset.dx + _thumbRadius,
      offset.dy + (parentBox.size.height - trackHeight) / 2,
      parentBox.size.width - _thumbRadius * 2,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final valueRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final rect = Rect.fromLTRB(
      valueRect.left - _thumbRadius,
      valueRect.top,
      valueRect.right + _thumbRadius,
      valueRect.bottom,
    );
    final path = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(rect.height / 2),
    ).getOuterPath(rect);
    final canvas = context.canvas;
    canvas.drawPath(
      path,
      Paint()..shader = LinearGradient(colors: colors).createShader(valueRect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = outlineColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

class _ColorThumbShape extends SliderComponentShape {
  const _ColorThumbShape({required this.color});

  final Color color;

  static const _ringWidth = 3.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_thumbRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final radius = _thumbRadius + activationAnimation.value * 2;
    canvas.drawCircle(
      center.translate(0, 1),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius - _ringWidth, Paint()..color = color);
  }
}

class _ToneStrip extends StatelessWidget {
  const _ToneStrip({
    required this.hue,
    required this.chroma,
    required this.selectedTone,
    required this.onToneSelected,
  });

  final double hue;
  final double chroma;
  final double selectedTone;
  final ValueChanged<double> onToneSelected;

  static const _tones = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(_toneStripBorder),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainer,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
          side: _panelBorderSide(colorScheme),
        ),
      ),
      child: ClipPath(
        clipper: const _SuperellipseClipper(
          borderRadius: BorderRadius.all(
            Radius.circular(_toneStripInnerRadius),
          ),
        ),
        child: Row(
          children: [
            for (final tone in _tones)
              Expanded(
                child: _ToneCell(
                  tone: tone,
                  color: Color(Hct.from(hue, chroma, tone.toDouble()).toInt()),
                  isSelected: tone == selectedTone.round(),
                  onSelected: () => onToneSelected(tone.toDouble()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToneCell extends StatefulWidget {
  const _ToneCell({
    required this.tone,
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  final int tone;
  final Color color;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  State<_ToneCell> createState() => _ToneCellState();
}

class _ToneCellState extends State<_ToneCell> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = widget.tone <= 50 ? Colors.white : Colors.black;
    final showRing = widget.isSelected || _isFocused;
    return Material(
      color: widget.color,
      child: InkWell(
        onTap: widget.onSelected,
        onFocusChange: (value) => setState(() => _isFocused = value),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showRing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(1000),
                      side: BorderSide(
                        color: foregroundColor.withValues(
                          alpha: widget.isSelected ? 0.9 : 0.5,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${widget.tone}',
                  style: TextStyle(
                    color: foregroundColor.withValues(
                      alpha: widget.isSelected ? 1 : 0.72,
                    ),
                    fontSize: 11,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSchemePreview extends StatelessWidget {
  const _ColorSchemePreview();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roles = [
      (
        colorScheme.primary,
        colorScheme.onPrimary,
        colorScheme.primaryContainer,
        'Primary',
      ),
      (
        colorScheme.secondary,
        colorScheme.onSecondary,
        colorScheme.secondaryContainer,
        'Secondary',
      ),
      (
        colorScheme.tertiary,
        colorScheme.onTertiary,
        colorScheme.tertiaryContainer,
        'Tertiary',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(_previewInset),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainer,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
          side: _panelBorderSide(colorScheme),
        ),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) => Row(
          children: [
            for (int i = 0; i < roles.length; i++) ...[
              if (i > 0)
                SizedBox(width: min(_previewInset, constraints.maxWidth / 8)),
              Expanded(
                child: ClipPath(
                  clipper: const _SuperellipseClipper(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 44,
                        color: roles[i].$1,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          roles[i].$4,
                          style: TextStyle(
                            color: roles[i].$2,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(height: 24, color: roles[i].$3),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
