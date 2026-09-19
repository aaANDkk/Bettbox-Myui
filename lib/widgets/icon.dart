import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bett_box/common/common.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

class CommonTargetIcon extends StatefulWidget {
  final String src;
  final double size;

  const CommonTargetIcon({super.key, required this.src, required this.size});

  /// 主动预取图标（不依赖组件是否挂载或可见）。
  ///
  /// 策略组数据更新后（例如用户在 YAML 里更换了策略组图标）立即把所有
  /// 图标拉取到本地缓存，避免「只有当前可见的图标才会被懒加载」，
  /// 从而无需重启应用即可显示新图标。
  static Future<void> prefetchAll(Iterable<String> srcs) {
    return _CommonTargetIconState.prefetchAll(srcs);
  }

  @override
  State<CommonTargetIcon> createState() => _CommonTargetIconState();
}

class _CommonTargetIconState extends State<CommonTargetIcon> {
  File? _file;
  String? _cachedSrc; // Cached src
  int? _cachedSize; // Cached size
  bool _didSyncCheck = false; // Guard for didChangeDependencies

  String? _currentSubscribedUrl;
  void Function(File?)? _urlListener;
  Timer? _retryTimer;

  static final Map<String, File?> _moduleFileCache = {};
  static final Map<String, bool> _moduleSvgValidCache = {};
  static final Map<String, DateTime> _urlFailureCache = {};
  static final Map<String, Set<void Function(File?)>> _urlListeners = {};
  static final Map<String, Future<File?>> _inFlightDownloads = {};
  static const _maxCacheEntries = 256;
  static const _failureCooldownSeconds = 8;
  static const _prefetchConcurrency = 4;
  static const _maxPrefetchPerRound = 64;

  String _moduleCacheKey(int cacheSize) {
    if (widget.src.isSvg) return 'svg|${widget.src}';
    return 'bmp|${widget.src}|$cacheSize';
  }

  static bool _cacheKeyMatchesSrc(String key, String src) {
    if (src.isEmpty) return false;
    if (key == 'svg|$src') return true;
    return key.startsWith('bmp|$src|');
  }

  /// 清除某个 URL 残留的「永久无效」标记。
  ///
  /// 仅清理内存中的判定标记，**绝不删除磁盘缓存文件**，因此在断网、
  /// 弱网或上游临时异常时依旧可以回退渲染旧图（遵循 SWR 高可用原则）。
  static bool _clearInvalidMark(String src) {
    if (src.isEmpty) return false;
    final poisonKeys = _moduleFileCache.entries
        .where(
          (entry) => entry.value == null && _cacheKeyMatchesSrc(entry.key, src),
        )
        .map((entry) => entry.key)
        .toList();
    if (poisonKeys.isEmpty) return false;
    for (final key in poisonKeys) {
      _moduleFileCache.remove(key);
    }
    _moduleSvgValidCache.remove(src);
    return true;
  }

  static void _ensureCacheLimit() {
    while (_moduleFileCache.length > _maxCacheEntries) {
      _moduleFileCache.remove(_moduleFileCache.keys.first);
    }
    while (_moduleSvgValidCache.length > _maxCacheEntries) {
      _moduleSvgValidCache.remove(_moduleSvgValidCache.keys.first);
    }
  }

  static bool _shouldRetry(String url) {
    final failedAt = _urlFailureCache[url];
    if (failedAt == null) return true;
    if (DateTime.now().difference(failedAt).inSeconds <
        _failureCooldownSeconds) {
      return false;
    }
    _urlFailureCache.remove(url);
    return true;
  }

  static void _addListener(String url, void Function(File?) listener) {
    _urlListeners.putIfAbsent(url, () => {}).add(listener);
  }

  static void _removeListener(String url, void Function(File?) listener) {
    final set = _urlListeners[url];
    if (set != null) {
      set.remove(listener);
      if (set.isEmpty) {
        _urlListeners.remove(url);
      }
    }
  }

  static void _notifyUrlUpdated(String url, File? file) {
    final listeners = _urlListeners[url]?.toList();
    if (listeners != null) {
      for (final listener in listeners) {
        listener(file);
      }
    }
  }

  void _subscribeToUrl(String url) {
    if (url.isEmpty || url.getBase64 != null) return;
    if (_currentSubscribedUrl == url) return;
    _unsubscribeFromUrl();
    _currentSubscribedUrl = url;
    _urlListener = (File? file) {
      if (!mounted) return;
      _onUrlUpdated(file);
    };
    _addListener(url, _urlListener!);
  }

  void _unsubscribeFromUrl() {
    if (_currentSubscribedUrl != null && _urlListener != null) {
      _removeListener(_currentSubscribedUrl!, _urlListener!);
      _urlListener = null;
      _currentSubscribedUrl = null;
    }
  }

  void _onUrlUpdated(File? file) {
    if (!mounted || widget.src.isEmpty) return;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (widget.size * devicePixelRatio).ceil();
    final key = _moduleCacheKey(cacheSize);

    final exact = _moduleFileCache[key];
    if (exact != null) {
      if (_file?.path != exact.path) {
        setState(() {
          _file = exact;
          _cachedSrc = widget.src;
          _cachedSize = cacheSize;
        });
      }
      return;
    }

    final anyFile = file ?? _findCachedFileForSrc(widget.src);
    if (anyFile != null && _file == null) {
      setState(() {
        _file = anyFile;
        _cachedSrc = widget.src;
        _cachedSize = null;
      });
    }

    _init(cacheSize);
  }

  @override
  void initState() {
    super.initState();
    _subscribeToUrl(widget.src);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _unsubscribeFromUrl();
    super.dispose();
  }

  void _syncCheckAndInit({bool force = false}) {
    if (widget.src.isEmpty || widget.src.getBase64 != null) return;

    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (widget.size * devicePixelRatio).ceil();
    final key = _moduleCacheKey(cacheSize);

    final exactFile = _moduleFileCache[key];
    if (exactFile != null) {
      _cachedSrc = widget.src;
      _cachedSize = cacheSize;
      _file = exactFile;
      if (!force) return;
    }

    final fallbackFile = _findCachedFileForSrc(widget.src);
    if (fallbackFile != null && _file == null) {
      _cachedSrc = widget.src;
      _cachedSize = null;
      _file = fallbackFile;
    }
    _init(cacheSize, force: force);
  }

  @override
  void didUpdateWidget(covariant CommonTargetIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _retryTimer?.cancel();
      _unsubscribeFromUrl();
      _subscribeToUrl(widget.src);

      // 配置（YAML）中更换了图标地址：必须让新地址真正走一次网络拉取，
      // 并清掉该地址可能残留的「永久无效 / 失败冷却」标记，
      // 否则会一直显示默认准星图标，只能靠完全重启应用才能恢复。
      _clearInvalidMark(widget.src);
      if (widget.src.isNotEmpty) {
        _urlFailureCache.remove(widget.src);
      }

      final newCacheSize =
          (widget.size * MediaQuery.of(context).devicePixelRatio).ceil();
      final exact = _moduleFileCache[_moduleCacheKey(newCacheSize)];
      final fallback = exact ?? _findCachedFileForSrc(widget.src);
      _file = fallback;
      _cachedSrc = fallback != null ? widget.src : null;
      _cachedSize = exact != null ? newCacheSize : null;
      _didSyncCheck = true;
      _syncCheckAndInit(force: true);
    } else if (oldWidget.size != widget.size) {
      _didSyncCheck = true;
      _syncCheckAndInit();
    }
  }

  static File? _findCachedFileForSrc(String src) {
    if (src.isSvg) {
      return _moduleFileCache['svg|$src'];
    }
    for (final entry in _moduleFileCache.entries) {
      if (entry.key.startsWith('bmp|$src|') && entry.value != null) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSyncCheck) return;
    _didSyncCheck = true;
    _syncCheckAndInit();
  }

  /// Generate resized cache path (persisted in data directory, fallback to temp)
  Future<String> _getResizedCachePath(String originalPath, int size) async {
    final hash = md5.convert(utf8.encode('${originalPath}_$size')).toString();
    try {
      final dataDirectory = await appPath.dataDir.future;
      return path.join(
        dataDirectory.path,
        'cache',
        'resized_icons',
        '$hash.png',
      );
    } catch (_) {
      final tempDir = await appPath.tempPath;
      return path.join(tempDir, 'resized_icons', '$hash.png');
    }
  }

  /// Decode, resize and cache image to disk, preserving aspect ratio
  Future<File?> _resizeAndCacheImage(File originalFile, int targetSize) async {
    try {
      final cachePath = await _getResizedCachePath(
        originalFile.path,
        targetSize,
      );
      final cacheFile = File(cachePath);

      // Return cached file if exists
      if (await cacheFile.exists()) {
        return cacheFile;
      }

      // Read original image
      final bytes = await originalFile.readAsBytes();

      // Probe original image dimensions
      final probeCodec = await ui.instantiateImageCodec(bytes);
      final probeFrame = await probeCodec.getNextFrame();
      final origImage = probeFrame.image;
      final origWidth = origImage.width;
      final origHeight = origImage.height;

      // If already small enough, no need to resize and re-encode
      if (origWidth <= targetSize && origHeight <= targetSize) {
        return originalFile;
      }

      // Calculate aspect-ratio-preserving dimensions bounded by targetSize
      final int targetWidth;
      final int targetHeight;
      if (origWidth >= origHeight) {
        targetWidth = targetSize;
        targetHeight =
            (origHeight * targetSize / origWidth).round().clamp(1, targetSize);
      } else {
        targetHeight = targetSize;
        targetWidth =
            (origWidth * targetSize / origHeight).round().clamp(1, targetSize);
      }

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Convert to PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return originalFile;
      }

      // Save to disk
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(byteData.buffer.asUint8List());

      return cacheFile;
    } catch (e) {
      // Resize failed, verify original file is decodable before falling back
      try {
        final bytes = await originalFile.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        await codec.getNextFrame();
        return originalFile;
      } catch (_) {
        return null;
      }
    }
  }

  /// Validate and sanitize SVG file
  Future<bool> _validateSvg(File file) async {
    try {
      final content = await file.readAsString();
      final trimmed = content.trim();

      // Check if content starts with valid SVG/XML tags
      if (!trimmed.startsWith('<svg') &&
          !trimmed.startsWith('<?xml') &&
          !trimmed.startsWith('<!DOCTYPE svg')) {
        commonPrint.log('Invalid SVG: not starting with svg tag');
        return false;
      }

      // Check for HTML error pages
      if (trimmed.contains('<!DOCTYPE html>') ||
          trimmed.contains('<html>') ||
          trimmed.contains('<head>') ||
          trimmed.contains('<body>')) {
        commonPrint.log('Invalid SVG: HTML content detected');
        return false;
      }

      // Validate XML structure
      try {
        XmlDocument.parse(content);
      } catch (e) {
        commonPrint.log('Invalid SVG: XML parse error - $e');
        return false;
      }

      // Fix invalid font-weight values
      if (content.contains('font-weight:none') ||
          content.contains('font-weight: none')) {
        final fixed = content
            .replaceAll('font-weight:none', 'font-weight:normal')
            .replaceAll('font-weight: none', 'font-weight: normal');
        await file.writeAsString(fixed);
      }
      return true;
    } catch (e) {
      commonPrint.log('SVG validation failed: $e');
      return false;
    }
  }

  Future<void> _init(int cacheSize, {bool force = false}) async {
    if (widget.src.isEmpty || widget.src.getBase64 != null) {
      return;
    }

    // If cached with same src and size, return directly
    // （force 为真时跳过该快捷返回：配置更换图标地址后必须重新走一次拉取流程）
    if (!force &&
        _cachedSrc == widget.src &&
        _cachedSize == cacheSize &&
        _file != null) {
      return;
    }

    final mKey = _moduleCacheKey(cacheSize);

    // Check module-level cache: another instance (or a previous
    // expand/collapse) may have already loaded this URL at the same size.
    // The cached File is already display-ready — no async resize needed.
    if (_moduleFileCache.containsKey(mKey)) {
      final cachedFile = _moduleFileCache[mKey];
      if (cachedFile == null) {
        // 历史版本会写入 null 作为「永久无效」标记，导致该地址此后
        // 永远不再尝试拉取（只能靠完全重启应用恢复）。这里直接剔除，
        // 让其走正常的失败冷却 + 自动补试流程。
        _moduleFileCache.remove(mKey);
      } else {
        if (mounted) {
          setState(() {
            _file = cachedFile;
            _cachedSrc = widget.src;
            _cachedSize = cacheSize;
          });
        }
        return;
      }
    }

    // 1. Try local cache from DefaultCacheManager (Stale-While-Revalidate: disk cache priority)
    FileInfo? fileInfo;
    try {
      fileInfo = await DefaultCacheManager().getFileFromCache(widget.src);
    } catch (_) {}

    if (fileInfo != null && mounted && widget.src.isNotEmpty) {
      final cachedFile = fileInfo.file;
      // Immediately render local disk file so UI never flashes or falls back to target icon
      if (_file == null && mounted) {
        setState(() {
          _file = cachedFile;
          _cachedSrc = widget.src;
          _cachedSize = null;
        });
      }
      await _processFile(cachedFile, cacheSize, mKey);

      // Check validity: if not expired, we are done!
      final isExpired = DateTime.now().isAfter(fileInfo.validTill);
      if (!isExpired) {
        return;
      }

      // If expired, trigger background revalidation (Stale-While-Revalidate)
      if (!_shouldRetry(widget.src)) return;
      _revalidateInBackground(cacheSize, mKey);
      return;
    }

    // 2. If no local file on disk, check URL failure cooldown before attempting network
    if (!_shouldRetry(widget.src)) {
      _scheduleAutoRetry(cacheSize);
      return;
    }

    // 3. Download via Single-Flight deduplication
    try {
      final file = await _downloadFileSingleFlight(widget.src);
      if (file != null && mounted && widget.src.isNotEmpty) {
        await _processFile(file, cacheSize, mKey);
      }
    } catch (e) {
      _urlFailureCache[widget.src] = DateTime.now();
      _scheduleAutoRetry(cacheSize);
    }
  }

  Future<void> _revalidateInBackground(int cacheSize, String mKey) async {
    try {
      final newFile = await _downloadFileSingleFlight(widget.src);
      if (newFile != null && mounted && widget.src.isNotEmpty) {
        await _processFile(newFile, cacheSize, mKey);
      }
    } catch (_) {
      // Background revalidation failure (e.g. offline, hotspot disconnect):
      // Keep displaying the stale disk image, do NOT clear _file!
      _urlFailureCache[widget.src] = DateTime.now();
    }
  }

  void _scheduleAutoRetry(int cacheSize) {
    _retryTimer?.cancel();
    _retryTimer =
        Timer(const Duration(seconds: _failureCooldownSeconds + 1), () {
      if (mounted && _file == null && widget.src.isNotEmpty) {
        _init(cacheSize);
      }
    });
  }

  static Future<File?> _downloadFileSingleFlight(String url) {
    final inFlight = _inFlightDownloads[url];
    if (inFlight != null) {
      return inFlight;
    }
    final future = _doDownload(url);
    _inFlightDownloads[url] = future;
    return future;
  }

  static Future<File?> _doDownload(String url) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      _urlFailureCache.remove(url);
      _notifyUrlUpdated(url, file);
      return file;
    } finally {
      _inFlightDownloads.remove(url);
    }
  }

  /// 主动预取图标（不依赖组件是否挂载或可见）。
  ///
  /// 策略组数据更新后（例如用户在 YAML 里更换了策略组图标）立即把所有
  /// 图标拉取到本地缓存，避免「只有当前可见的图标才会被懒加载」，
  /// 从而无需重启应用即可显示新图标。
  static Future<void> prefetchAll(Iterable<String> srcs) async {
    final targets = <String>[];
    final seen = <String>{};
    for (final raw in srcs) {
      final src = raw.trim();
      if (src.isEmpty || src.getBase64 != null) continue;
      if (!seen.add(src)) continue;
      // 清理历史版本遗留的「永久无效」标记，否则该地址永远不会再被拉取
      _clearInvalidMark(src);
      if (_findCachedFileForSrc(src) != null) continue;
      targets.add(src);
      if (targets.length >= _maxPrefetchPerRound) break;
    }
    if (targets.isEmpty) return;
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < targets.length) {
        final src = targets[cursor++];
        if (!_shouldRetry(src)) continue;
        try {
          await _prefetchOne(src);
        } catch (_) {
          _urlFailureCache[src] = DateTime.now();
        }
      }
    }

    final workerCount = targets.length < _prefetchConcurrency
        ? targets.length
        : _prefetchConcurrency;
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  static Future<void> _prefetchOne(String url) async {
    FileInfo? info;
    try {
      info = await DefaultCacheManager().getFileFromCache(url);
    } catch (_) {}
    if (info != null && !DateTime.now().isAfter(info.validTill)) {
      // 本地副本仍然新鲜：直接广播给已挂载的同源组件，无需网络
      _notifyUrlUpdated(url, info.file);
      return;
    }
    // 无缓存或已过期：走 single-flight 拉取（内含 URL 级并发去重与广播）
    await _downloadFileSingleFlight(url);
  }

  Future<void> _processFile(File file, int cacheSize, String mKey) async {
    if (widget.src.isSvg) {
      final isValid = await _validateSvg(file);
      if (!isValid) {
        await DefaultCacheManager().removeFile(widget.src);
        // 不再写入 null 永久标记：仅记录失败冷却，冷却结束后自动补试，
        // 网络恢复或上游恢复时无需重启应用即可显示图标。
        _moduleFileCache.remove(mKey);
        _moduleSvgValidCache.remove(widget.src);
        _urlFailureCache[widget.src] = DateTime.now();
        if (mounted) {
          setState(() {
            _file = null;
            _cachedSrc = null;
            _cachedSize = null;
          });
        }
        _scheduleAutoRetry(cacheSize);
        return;
      }
      _moduleFileCache[mKey] = file;
      _moduleSvgValidCache[widget.src] = true;
      _urlFailureCache.remove(widget.src);
      _ensureCacheLimit();
      _notifyUrlUpdated(widget.src, file);
      if (mounted) {
        setState(() {
          _file = file;
          _cachedSrc = widget.src;
          _cachedSize = cacheSize;
        });
      }
      return;
    }

    final displayFile = (await _resizeAndCacheImage(file, cacheSize)) ?? file;
    _moduleFileCache[mKey] = displayFile;
    _urlFailureCache.remove(widget.src);
    _ensureCacheLimit();
    _notifyUrlUpdated(widget.src, displayFile);
    if (mounted) {
      setState(() {
        _file = displayFile;
        _cachedSrc = widget.src;
        _cachedSize = cacheSize;
      });
    }
  }

  Widget _defaultIcon() {
    return Icon(IconsExt.target, size: widget.size);
  }

  Widget _buildIcon() {
    if (widget.src.isEmpty) {
      return _defaultIcon();
    }
    final base64 = widget.src.getBase64;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (widget.size * devicePixelRatio).ceil();

    if (base64 != null) {
      return Image.memory(
        base64,
        gaplessPlayback: true,
        fit: BoxFit.contain,
        errorBuilder: (_, error, _) {
          return _defaultIcon();
        },
      );
    }
    if (_file != null) {
      if (widget.src.isSvg) {
        final mKey = _moduleCacheKey(cacheSize);
        if (_moduleSvgValidCache[widget.src] == true) {
          try {
            return SvgPicture.file(
              _file!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => _defaultIcon(),
            );
          } catch (e) {
            commonPrint.log('Failed to load SVG: $e');
            _moduleFileCache.remove(mKey);
            _moduleSvgValidCache.remove(widget.src);
            _urlFailureCache[widget.src] = DateTime.now();
            _scheduleAutoRetry(cacheSize);
            return _defaultIcon();
          }
        }
        return FutureBuilder<bool>(
          future: _validateSvg(_file!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _defaultIcon();
            }
            if (snapshot.hasError || snapshot.data == false) {
              commonPrint.log(
                'SVG validation failed in build: ${snapshot.error}',
              );
              DefaultCacheManager().removeFile(widget.src);
              _moduleFileCache.remove(_moduleCacheKey(cacheSize));
              _moduleSvgValidCache.remove(widget.src);
              _urlFailureCache[widget.src] = DateTime.now();
              _file = null;
              _cachedSrc = null;
              _cachedSize = null;
              _scheduleAutoRetry(cacheSize);
              return _defaultIcon();
            }
            _moduleSvgValidCache[widget.src] = true;
            try {
              return SvgPicture.file(
                _file!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _defaultIcon(),
              );
            } catch (e) {
              commonPrint.log('Failed to load SVG: $e');
              DefaultCacheManager().removeFile(widget.src);
              _moduleFileCache.remove(_moduleCacheKey(cacheSize));
              _moduleSvgValidCache.remove(widget.src);
              _urlFailureCache[widget.src] = DateTime.now();
              _file = null;
              _cachedSrc = null;
              _cachedSize = null;
              _scheduleAutoRetry(cacheSize);
              return _defaultIcon();
            }
          },
        );
      }
      final mKey = _moduleCacheKey(cacheSize);
      return Image.file(
        _file!,
        gaplessPlayback: true,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) {
          _moduleFileCache.remove(mKey);
          _urlFailureCache[widget.src] = DateTime.now();
          _file = null;
          _cachedSrc = null;
          _cachedSize = null;
          _scheduleAutoRetry(cacheSize);
          return _defaultIcon();
        },
      );
    }
    return _defaultIcon();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey<String>('${widget.src}_${_file?.path}'),
          child: _buildIcon(),
        ),
      ),
    );
  }
}
