import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:path/path.dart' as p;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';

class ClockCardData {
  final String? imagePath;
  final String? customText;
  final String? author;

  const ClockCardData({
    this.imagePath,
    this.customText,
    this.author,
  });

  ClockCardData copyWith({
    String? imagePath,
    String? customText,
    String? author,
    bool clearImage = false,
    bool clearText = false,
    bool clearAuthor = false,
  }) {
    return ClockCardData(
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      customText: clearText ? null : (customText ?? this.customText),
      author: clearAuthor ? null : (author ?? this.author),
    );
  }
}

final clockCardProvider =
    StateNotifierProvider<ClockCardNotifier, ClockCardData>((ref) {
  return ClockCardNotifier();
});

class ClockCardNotifier extends StateNotifier<ClockCardData> {
  static const _imageKey = 'clock_card_large_image';
  static const _textKey = 'clock_card_large_text';
  static const _authorKey = 'clock_card_large_author';

  ClockCardNotifier() : super(const ClockCardData()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final imagePath = prefs?.getString(_imageKey);
    final customText = prefs?.getString(_textKey);
    final author = prefs?.getString(_authorKey);
    state = ClockCardData(
      imagePath: imagePath,
      customText: customText,
      author: author,
    );
  }

  Future<void> updateSettings({
    required String? text,
    required String? author,
    required String? imagePath,
  }) async {
    final prefs = await preferences.sharedPreferencesCompleter.future;

    final trimmedText = text?.trim();
    if (trimmedText == null || trimmedText.isEmpty) {
      await prefs?.remove(_textKey);
    } else {
      await prefs?.setString(_textKey, trimmedText);
    }

    final trimmedAuthor = author?.trim();
    if (trimmedAuthor == null || trimmedAuthor.isEmpty) {
      await prefs?.remove(_authorKey);
    } else {
      await prefs?.setString(_authorKey, trimmedAuthor);
    }

    if (imagePath == null) {
      if (state.imagePath != null) {
        try {
          final file = File(state.imagePath!);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
      await prefs?.remove(_imageKey);
    } else if (imagePath != state.imagePath) {
      await prefs?.setString(_imageKey, imagePath);
    }

    state = ClockCardData(
      imagePath: (imagePath != null && imagePath.isNotEmpty) ? imagePath : null,
      customText:
          (trimmedText != null && trimmedText.isNotEmpty) ? trimmedText : null,
      author: (trimmedAuthor != null && trimmedAuthor.isNotEmpty)
          ? trimmedAuthor
          : null,
    );
  }
}

Future<String?> _saveSelectedImage(String sourcePath) async {
  try {
    final baseDir = await appPath.dataDir.future;
    final dir = Directory(p.join(baseDir.path, 'clock_card_images'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final ext =
        p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final fileName = 'large_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(dir.path, fileName);
    await File(sourcePath).copy(targetPath);
    return targetPath;
  } catch (e) {
    commonPrint.log('Failed to save clock card image: $e');
    return sourcePath;
  }
}

class ClockCard extends ConsumerWidget {
  const ClockCard({super.key});

  Future<void> _showClockDialog(
    BuildContext context,
    WidgetRef ref,
    ClockCardData data,
  ) async {
    final notifier = ref.read(clockCardProvider.notifier);

    final result = await globalState.showCommonDialog<_ClockDialogResult>(
      child: _ClockDialog(initialData: data),
    );

    if (result != null) {
      await notifier.updateSettings(
        text: result.text,
        author: result.author,
        imagePath: result.imageCleared ? null : result.imagePath,
      );
    }
  }

  Widget _buildDefaultBackground(bool isDark) {
    return Image.asset(
      'assets/images/xiaozhu.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF1E293B)]
                : const [Color(0xFFE0E7FF), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            FluentIcons.image_24_regular,
            size: 28,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(clockCardProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = context.colorScheme;
    final customFont = theme.textTheme.bodyMedium?.fontFamily;

    final hasCustomImage =
        data.imagePath != null && File(data.imagePath!).existsSync();

    final displayText = (data.customText != null &&
            data.customText!.trim().isNotEmpty)
        ? data.customText!.trim()
        : appLocalizations.clockCardDefaultText;

    final displayAuthor = (data.author != null &&
            data.author!.trim().isNotEmpty)
        ? data.author!.trim()
        : appLocalizations.clockCardDefaultAuthor;

    final authorText =
        (displayAuthor.startsWith('—') || displayAuthor.startsWith('-'))
            ? displayAuthor
            : '—— $displayAuthor';

    return RepaintBoundary(
      child: CommonCard(
        onPressed: () => _showClockDialog(context, ref, data),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final innerHeight =
                max(0.0, constraints.maxHeight - baseInfoEdgeInsets.vertical);
            final innerAvailableWidth = max(
              0.0,
              constraints.maxWidth - baseInfoEdgeInsets.horizontal - 14.ap,
            );
            final idealImageWidth = innerHeight * (4 / 3);
            final maxImageWidth = innerAvailableWidth * 0.60;
            final imageWidth = min(idealImageWidth, maxImageWidth);

            return Padding(
              padding: baseInfoEdgeInsets,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: dashboardRefreshManager.tick1s,
                          builder: (_, _, _) {
                            final now = DateTime.now();
                            final hour = now.hour.toString().padLeft(2, '0');
                            final minute =
                                now.minute.toString().padLeft(2, '0');
                            final timeText = '$hour:$minute';

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  FluentIcons.clock_24_filled,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeText,
                                  style: context.textTheme.titleSmall?.copyWith(
                                    fontFamily: customFont,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: EmojiText(
                              displayText,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: customFont,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        if (authorText.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 16.ap),
                              child: EmojiText(
                                authorText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: customFont,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: imageWidth,
                    height: innerHeight,
                    child: _BlurredSuperellipseFrame(
                      borderRadius: BorderRadius.circular(16),
                      borderWidth: 3.5,
                      child: hasCustomImage
                          ? Image.file(
                              File(data.imagePath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, _, _) =>
                                  _buildDefaultBackground(isDark),
                            )
                          : _buildDefaultBackground(isDark),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ClockCardLarge extends StatelessWidget {
  const ClockCardLarge({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(2),
      child: const ClockCard(),
    );
  }
}

class _ClockDialogResult {
  final String? text;
  final String? author;
  final String? imagePath;
  final bool imageCleared;

  const _ClockDialogResult({
    required this.text,
    required this.author,
    required this.imagePath,
    required this.imageCleared,
  });
}

class _ClockDialog extends StatefulWidget {
  final ClockCardData initialData;

  const _ClockDialog({required this.initialData});

  @override
  State<_ClockDialog> createState() => _ClockDialogState();
}

class _ClockDialogState extends State<_ClockDialog> {
  late final TextEditingController _textController;
  late final TextEditingController _authorController;
  String? _selectedImagePath;
  bool _imageCleared = false;

  @override
  void initState() {
    super.initState();
    _textController = EmojiTextEditingController(
      text: widget.initialData.customText ?? '',
    );
    _authorController = EmojiTextEditingController(
      text: widget.initialData.author ?? '',
    );
    _selectedImagePath = widget.initialData.imagePath;
  }

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final rawPath = await picker.pickImage();
      if (rawPath != null && rawPath.isNotEmpty) {
        final savedPath = await _saveSelectedImage(rawPath);
        if (mounted) {
          setState(() {
            _selectedImagePath = savedPath;
            _imageCleared = false;
          });
        }
      }
    } catch (e) {
      commonPrint.log('Pick image error: $e');
    }
  }

  void _resetImage() {
    setState(() {
      _selectedImagePath = null;
      _imageCleared = true;
    });
  }

  Widget _buildDefaultBackground(bool isDark) {
    return Image.asset(
      'assets/images/xiaozhu.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF1E293B)]
                : const [Color(0xFFE0E7FF), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            FluentIcons.image_24_regular,
            size: 20,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fabTheme = Theme.of(context).floatingActionButtonTheme;
    final fabBgColor =
        fabTheme.backgroundColor ?? colorScheme.primaryContainer;
    final fabFgColor =
        fabTheme.foregroundColor ?? colorScheme.onPrimaryContainer;
    final hasImage = !_imageCleared &&
        _selectedImagePath != null &&
        File(_selectedImagePath!).existsSync();

    return CommonDialog(
      title: appLocalizations.clock,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(
              _ClockDialogResult(
                text: _textController.text,
                author: _authorController.text,
                imagePath: _selectedImagePath,
                imageCleared: _imageCleared,
              ),
            );
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              maxLength: 80,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: appLocalizations.customCardText,
                hintText: appLocalizations.clockCardDefaultText,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authorController,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: appLocalizations.clockCardAuthor,
                hintText: appLocalizations.clockCardDefaultAuthor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              appLocalizations.clockCardImage,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: ShapeDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: SuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 39,
                      child: _BlurredSuperellipseFrame(
                        borderRadius: BorderRadius.circular(10),
                        borderWidth: 2,
                        child: hasImage
                            ? Image.file(
                                File(_selectedImagePath!),
                                fit: BoxFit.cover,
                              )
                            : _buildDefaultBackground(isDark),
                      ),
                    ),
                    const Spacer(),
                    if (hasImage) ...[
                      IconButton.filledTonal(
                        iconSize: 20,
                        padding: const EdgeInsets.all(4),
                        visualDensity: VisualDensity.compact,
                        tooltip: appLocalizations.restoreDefaultImage,
                        onPressed: _resetImage,
                        icon: const Icon(FluentIcons.arrow_repeat_all_24_regular),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: fabBgColor,
                        foregroundColor: fabFgColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _pickImage,
                      icon: const Icon(FluentIcons.image_24_regular, size: 18),
                      label: Text(appLocalizations.changeImage),
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

class _BlurredSuperellipseFrame extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double borderWidth;

  const _BlurredSuperellipseFrame({
    required this.child,
    required this.borderRadius,
    this.borderWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final blurSigma = isDark ? 10.0 : 8.0;
    final tintColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.35);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : colorScheme.outlineVariant.withValues(alpha: 0.5);

    final photoRadius = BorderRadius.only(
      topLeft: Radius.elliptical(
        max(0.0, borderRadius.topLeft.x - 0.8),
        max(0.0, borderRadius.topLeft.y - 0.8),
      ),
      topRight: Radius.elliptical(
        max(0.0, borderRadius.topRight.x - 0.8),
        max(0.0, borderRadius.topRight.y - 0.8),
      ),
      bottomLeft: Radius.elliptical(
        max(0.0, borderRadius.bottomLeft.x - 0.8),
        max(0.0, borderRadius.bottomLeft.y - 0.8),
      ),
      bottomRight: Radius.elliptical(
        max(0.0, borderRadius.bottomRight.x - 0.8),
        max(0.0, borderRadius.bottomRight.y - 0.8),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(0.8),
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: SuperellipseBorder(
                borderRadius: photoRadius,
              ),
            ),
            child: child,
          ),
        ),
        IgnorePointer(
          child: ClipPath(
            clipBehavior: Clip.antiAlias,
            clipper: _SuperellipseRingClipper(
              borderRadius: borderRadius,
              borderWidth: borderWidth,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Container(
                color: tintColor,
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: SuperellipseBorder(
                borderRadius: borderRadius,
                side: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuperellipseRingClipper extends CustomClipper<Path> {
  final BorderRadius borderRadius;
  final double borderWidth;

  const _SuperellipseRingClipper({
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    final outerShape = SuperellipseBorder(borderRadius: borderRadius);
    final outerPath = outerShape.getOuterPath(rect);

    final innerRect = rect.deflate(borderWidth);
    final innerRadius = BorderRadius.only(
      topLeft: Radius.elliptical(
        max(0.0, borderRadius.topLeft.x - borderWidth),
        max(0.0, borderRadius.topLeft.y - borderWidth),
      ),
      topRight: Radius.elliptical(
        max(0.0, borderRadius.topRight.x - borderWidth),
        max(0.0, borderRadius.topRight.y - borderWidth),
      ),
      bottomLeft: Radius.elliptical(
        max(0.0, borderRadius.bottomLeft.x - borderWidth),
        max(0.0, borderRadius.bottomLeft.y - borderWidth),
      ),
      bottomRight: Radius.elliptical(
        max(0.0, borderRadius.bottomRight.x - borderWidth),
        max(0.0, borderRadius.bottomRight.y - borderWidth),
      ),
    );
    final innerShape = SuperellipseBorder(borderRadius: innerRadius);
    final innerPath = innerShape.getOuterPath(innerRect);

    return Path.combine(PathOperation.difference, outerPath, innerPath);
  }

  @override
  bool shouldReclip(covariant _SuperellipseRingClipper oldClipper) {
    return oldClipper.borderRadius != borderRadius ||
        oldClipper.borderWidth != borderWidth;
  }
}




