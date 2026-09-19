import 'dart:io';
import 'dart:typed_data';

import 'package:bett_box/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class FontManager {
  static final ValueNotifier<String?> fontFamilyNotifier =
      ValueNotifier<String?>(null);

  static String? get customFontFamily => fontFamilyNotifier.value;
  static bool get isLoaded => fontFamilyNotifier.value != null;

  static bool _isVariableFont = false;
  static bool get isVariableFont => _isVariableFont;

  static int _fontBaseWeight = 400;
  static int get fontBaseWeight => _fontBaseWeight;

  static String? _customFontName;
  static String? get customFontName => _customFontName;

  static const String _prefKeyFontName = 'custom_font_name';
  static const String _prefKeyFontPath = 'custom_font_path';

  static Future<String?> get _existingFontPath async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    final savedPath = prefs?.getString(_prefKeyFontPath);
    if (savedPath != null && savedPath.isNotEmpty && File(savedPath).existsSync()) {
      return savedPath;
    }
    final homeDir = await appPath.homeDirPath;
    final ttf = File(p.join(homeDir, 'fonts', 'user_custom.ttf'));
    if (ttf.existsSync()) return ttf.path;
    final otf = File(p.join(homeDir, 'fonts', 'user_custom.otf'));
    if (otf.existsSync()) return otf.path;
    return null;
  }

  /// Initialize custom font from local storage on app start
  static Future<bool> init({required bool enabled}) async {
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      _customFontName = prefs?.getString(_prefKeyFontName);
      final fontPath = await _existingFontPath;

      if (fontPath == null) {
        commonPrint.log('FontManager: no custom font file found');
        _customFontName = null;
        fontFamilyNotifier.value = null;
        return false;
      }

      if (_customFontName == null || _customFontName!.isEmpty) {
        _customFontName = p.basename(fontPath);
      }

      if (enabled) {
        final success = await loadFont(fontPath, _customFontName);
        if (success) {
          return true;
        }
      }
      return true;
    } catch (e, stack) {
      commonPrint.log('FontManager.init failed: $e\n$stack');
      return false;
    }
  }

  /// Checks whether a custom font file is present in local storage
  static Future<bool> hasFontFile() async {
    try {
      final path = await _existingFontPath;
      return path != null;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the font is loaded into runtime memory
  static Future<bool> ensureLoaded() async {
    if (isLoaded) return true;
    try {
      final fontPath = await _existingFontPath;
      if (fontPath == null) return false;
      return await loadFont(fontPath, _customFontName);
    } catch (_) {
      return false;
    }
  }

  /// Loads a font file dynamically into Flutter runtime with a fresh family name
  static Future<bool> loadFont(String filePath, [String? displayName]) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }
      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) {
        return false;
      }

      final processed = _analyzeAndProcessFont(rawBytes);
      _isVariableFont = processed.isVariable;
      _fontBaseWeight = processed.baseWeight;

      final familyName =
          'CustomUserFont_${DateTime.now().millisecondsSinceEpoch}';
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(
        Future.value(
          ByteData.view(
            processed.bytes.buffer,
            processed.bytes.offsetInBytes,
            processed.bytes.lengthInBytes,
          ),
        ),
      );

      await fontLoader.load();
      if (displayName != null && displayName.isNotEmpty) {
        _customFontName = displayName;
      }
      fontFamilyNotifier.value = familyName;
      commonPrint.log(
        'FontManager: custom font loaded ($familyName) from $filePath (variable: $_isVariableFont, baseWeight: $_fontBaseWeight)',
      );
      return true;
    } catch (e, stack) {
      commonPrint.log('FontManager.loadFont failed: $e\n$stack');
      return false;
    }
  }

  /// Opens file picker, copies chosen font to safe storage, and applies it
  static Future<bool> pickAndApplyFont(BuildContext context) async {
    try {
      final file = await picker.pickerFile(
        allowedExtensions: ['ttf', 'otf'],
      );
      if (file == null) {
        return false;
      }

      final fileName = file.name;
      final ext = p.extension(fileName).toLowerCase();
      if (ext != '.ttf' && ext != '.otf') {
        if (context.mounted) {
          context.showNotifier(appLocalizations.invalidFontFormat);
        }
        return false;
      }

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && file.path!.isNotEmpty) {
        final f = File(file.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        return false;
      }

      final homeDir = await appPath.homeDirPath;
      final fontsDir = Directory(p.join(homeDir, 'fonts'));
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }

      final destFile = File(p.join(fontsDir.path, 'user_custom$ext'));
      final altExt = ext == '.ttf' ? '.otf' : '.ttf';
      final altFile = File(p.join(fontsDir.path, 'user_custom$altExt'));
      if (await altFile.exists()) {
        try {
          await altFile.delete();
        } catch (_) {}
      }
      await destFile.writeAsBytes(bytes);

      final success = await loadFont(destFile.path, fileName);
      if (success) {
        _customFontName = fileName;
        final prefs = await preferences.sharedPreferencesCompleter.future;
        await prefs?.setString(_prefKeyFontName, fileName);
        await prefs?.setString(_prefKeyFontPath, destFile.path);
        return true;
      }
      return false;
    } catch (e, stack) {
      commonPrint.log('FontManager.pickAndApplyFont failed: $e\n$stack');
      return false;
    }
  }

  /// Disables custom font, reverting to system font
  static void disableFont() {
    _isVariableFont = false;
    _fontBaseWeight = 400;
    fontFamilyNotifier.value = null;
  }

  static int _calcTableChecksum(
    Uint8List bytes,
    ByteData byteData,
    int offset,
    int length,
  ) {
    int sum = 0;
    final nLongs = (length + 3) ~/ 4;
    for (int i = 0; i < nLongs; i++) {
      final pos = offset + i * 4;
      int word = 0;
      if (pos + 4 <= bytes.length) {
        word = byteData.getUint32(pos, Endian.big);
      } else {
        for (int b = 0; b < 4; b++) {
          final p = pos + b;
          final bVal = (p < offset + length && p < bytes.length) ? bytes[p] : 0;
          word = (word << 8) | bVal;
        }
      }
      sum = (sum + word) & 0xFFFFFFFF;
    }
    return sum;
  }

  static _ProcessedFontData _analyzeAndProcessFont(Uint8List rawBytes) {
    if (rawBytes.length < 12) {
      return _ProcessedFontData(
        bytes: rawBytes,
        isVariable: false,
        baseWeight: 400,
      );
    }

    final bytes = Uint8List.fromList(rawBytes);
    final byteData = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    final magic = byteData.getUint32(0, Endian.big);
    final isTtc = (magic == 0x74746366); // 'ttcf'

    final List<int> fontOffsets = [];
    if (isTtc) {
      if (bytes.length >= 12) {
        final numFonts = byteData.getUint32(8, Endian.big);
        for (int i = 0; i < numFonts; i++) {
          final off = 12 + i * 4;
          if (off + 4 <= bytes.length) {
            fontOffsets.add(byteData.getUint32(off, Endian.big));
          }
        }
      }
    } else {
      fontOffsets.add(0);
    }

    bool isVariable = false;
    int originalWeight = 400;
    bool modified = false;

    for (final base in fontOffsets) {
      if (base + 12 > bytes.length) continue;
      final numTables = byteData.getUint16(base + 4, Endian.big);

      int? os2RecOffset;
      int? os2Offset;
      int? os2Length;
      int? headOffset;

      for (int i = 0; i < numTables; i++) {
        final rec = base + 12 + i * 16;
        if (rec + 16 > bytes.length) break;

        final tag = byteData.getUint32(rec, Endian.big);
        final offset = byteData.getUint32(rec + 8, Endian.big);
        final length = byteData.getUint32(rec + 12, Endian.big);

        if (tag == 0x66766172) {
          // 'fvar'
          isVariable = true;
        } else if (tag == 0x4F532F32) {
          // 'OS/2'
          os2RecOffset = rec;
          os2Offset = offset;
          os2Length = length;
        } else if (tag == 0x68656164) {
          // 'head'
          headOffset = offset;
        }
      }

      if (os2Offset != null && os2Offset + 6 <= bytes.length) {
        final weight = byteData.getUint16(os2Offset + 4, Endian.big);
        originalWeight = weight;

        // If static font has usWeightClass > 400 (e.g. 700 bold), normalize to 400 so Skia
        // can apply fake-bold to titles and does not force body text to be bold.
        if (!isVariable &&
            weight > 400 &&
            os2RecOffset != null &&
            os2Length != null) {
          byteData.setUint16(os2Offset + 4, 400, Endian.big);

          if (os2Offset + 64 <= bytes.length) {
            int fsSel = byteData.getUint16(os2Offset + 62, Endian.big);
            if ((fsSel & 0x0020) != 0) {
              fsSel = (fsSel & ~0x0020) | 0x0040;
              byteData.setUint16(os2Offset + 62, fsSel, Endian.big);
            }
          }

          final newCksum = _calcTableChecksum(
            bytes,
            byteData,
            os2Offset,
            os2Length,
          );
          byteData.setUint32(os2RecOffset + 4, newCksum, Endian.big);

          if (headOffset != null && headOffset + 12 <= bytes.length && !isTtc) {
            byteData.setUint32(headOffset + 8, 0, Endian.big);
            final totalCksum = _calcTableChecksum(
              bytes,
              byteData,
              0,
              bytes.length,
            );
            final adj = (0xB1B0AFBA - totalCksum) & 0xFFFFFFFF;
            byteData.setUint32(headOffset + 8, adj, Endian.big);
          }

          modified = true;
        }
      }
    }

    return _ProcessedFontData(
      bytes: modified ? bytes : rawBytes,
      isVariable: isVariable,
      baseWeight: originalWeight,
    );
  }
}

class _ProcessedFontData {
  final Uint8List bytes;
  final bool isVariable;
  final int baseWeight;

  const _ProcessedFontData({
    required this.bytes,
    required this.isVariable,
    required this.baseWeight,
  });
}
