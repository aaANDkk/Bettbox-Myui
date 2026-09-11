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
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return false;
      }

      final familyName =
          'CustomUserFont_${DateTime.now().millisecondsSinceEpoch}';
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(
        Future.value(
          ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
        ),
      );

      await fontLoader.load();
      if (displayName != null && displayName.isNotEmpty) {
        _customFontName = displayName;
      }
      fontFamilyNotifier.value = familyName;
      commonPrint.log(
        'FontManager: custom font loaded ($familyName) from $filePath',
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
    fontFamilyNotifier.value = null;
  }
}
