import 'package:flutter/material.dart';

const monochromeColorFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0,
]);

const mediaUnlockGreen = Color(0xFF10B981);
const mediaUnlockOrange = Color(0xFFF59E0B);

/// 深色模式下把双色素材映射到主题色系：暗部 → `onSurface`、亮部 → `surface`，
/// 与其余单色图标同色系，不会出现纯白/纯黑那种突兀感。
ColorFilter themedInvertFilter(ColorScheme colorScheme) {
  final fg = colorScheme.onSurface;
  final bg = colorScheme.surface;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  List<double> row(double f, double b) => <double>[
        lr * (b - f) / 255,
        lg * (b - f) / 255,
        lb * (b - f) / 255,
        0,
        f,
      ];
  return ColorFilter.matrix(<double>[
    ...row(fg.r * 255, bg.r * 255),
    ...row(fg.g * 255, bg.g * 255),
    ...row(fg.b * 255, bg.b * 255),
    0, 0, 0, 1, 0,
  ]);
}

/// 双色素材（如 OKX 黑底白标记徽标）没法靠单色着色适配：
/// 浅色模式保持原样，深色模式按主题色系做一次亮度反色（黑底变主题前景色、
/// 白标记变卡片底色），与其它图标观感一致。
Widget themedPlatformIcon(
  BuildContext context,
  MediaPlatform platform,
  Widget icon,
) {
  final theme = Theme.of(context);
  if (!platform.invertOnDark || theme.brightness != Brightness.dark) {
    return icon;
  }
  return ColorFiltered(
    colorFilter: themedInvertFilter(theme.colorScheme),
    child: icon,
  );
}

enum MediaCategory {
  ai,
  streaming,
  china,
  social,
  developer,
  gaming,
  crypto,
}

enum MediaPlatform {
  openai,
  claude,
  gemini,
  grok,
  openrouter,
  poe,
  suno,
  perplexity,
  netflix,
  disney,
  youtube,
  spotify,
  tiktok,
  iqiyi,
  crunchyroll,
  missav,
  ehentai,
  qqnews,
  alidnsprobe,
  netease,
  bytedance,
  bilibili,
  cloudflarecn,
  reddit,
  x,
  discord,
  v2ex,
  medium,
  stackoverflow,
  quora,
  telegram,
  github,
  wikipedia,
  apple,
  onetrust,
  cloudflare,
  gitlab,
  npm,
  cdnjs,
  unpkg,
  nodejs,
  steam,
  epic,
  ubisoft,
  humblebundle,
  coinbase,
  okx,
  kraken,
  cryptocom,
  phantom,
}

extension MediaPlatformExt on MediaPlatform {
  MediaCategory get category => switch (this) {
        MediaPlatform.openai ||
        MediaPlatform.claude ||
        MediaPlatform.gemini ||
        MediaPlatform.grok ||
        MediaPlatform.openrouter ||
        MediaPlatform.poe ||
        MediaPlatform.suno ||
        MediaPlatform.perplexity =>
          MediaCategory.ai,
        MediaPlatform.netflix ||
        MediaPlatform.disney ||
        MediaPlatform.youtube ||
        MediaPlatform.spotify ||
        MediaPlatform.tiktok ||
        MediaPlatform.iqiyi ||
        MediaPlatform.crunchyroll ||
        MediaPlatform.missav ||
        MediaPlatform.ehentai =>
          MediaCategory.streaming,
        MediaPlatform.qqnews ||
        MediaPlatform.alidnsprobe ||
        MediaPlatform.netease ||
        MediaPlatform.bytedance ||
        MediaPlatform.bilibili ||
        MediaPlatform.cloudflarecn =>
          MediaCategory.china,
        MediaPlatform.reddit ||
        MediaPlatform.x ||
        MediaPlatform.discord ||
        MediaPlatform.v2ex ||
        MediaPlatform.medium ||
        MediaPlatform.stackoverflow ||
        MediaPlatform.quora ||
        MediaPlatform.telegram =>
          MediaCategory.social,
        MediaPlatform.github ||
        MediaPlatform.wikipedia ||
        MediaPlatform.apple ||
        MediaPlatform.onetrust ||
        MediaPlatform.cloudflare ||
        MediaPlatform.gitlab ||
        MediaPlatform.npm ||
        MediaPlatform.cdnjs ||
        MediaPlatform.unpkg ||
        MediaPlatform.nodejs =>
          MediaCategory.developer,
        MediaPlatform.steam ||
        MediaPlatform.epic ||
        MediaPlatform.ubisoft ||
        MediaPlatform.humblebundle =>
          MediaCategory.gaming,
        MediaPlatform.coinbase ||
        MediaPlatform.okx ||
        MediaPlatform.kraken ||
        MediaPlatform.cryptocom ||
        MediaPlatform.phantom =>
          MediaCategory.crypto,
      };

  String get defaultName => switch (this) {
        MediaPlatform.openai => 'OpenAI',
        MediaPlatform.claude => 'Claude',
        MediaPlatform.gemini => 'Gemini',
        MediaPlatform.grok => 'Grok',
        MediaPlatform.openrouter => 'OpenRouter',
        MediaPlatform.poe => 'Poe',
        MediaPlatform.suno => 'Suno',
        MediaPlatform.cloudflare => 'Cloudflare',
        MediaPlatform.perplexity => 'Perplexity',
        MediaPlatform.netflix => 'Netflix',
        MediaPlatform.disney => 'Disney+',
        MediaPlatform.youtube => 'YouTube',
        MediaPlatform.spotify => 'Spotify',
        MediaPlatform.tiktok => 'TikTok',
        MediaPlatform.bilibili => 'Bilibili(CN)',
        MediaPlatform.iqiyi => 'iQIYI',
        MediaPlatform.crunchyroll => 'Crunchyroll',
        MediaPlatform.missav => 'MissAV',
        MediaPlatform.ehentai => 'E-Hentai',
        MediaPlatform.qqnews => 'Tencent(CN)',
        MediaPlatform.alidnsprobe => 'Alibaba(CN)',
        MediaPlatform.netease => 'Netease(CN)',
        MediaPlatform.bytedance => 'Douyin(CN)',
        MediaPlatform.cloudflarecn => 'Cloudflare(CN)',
        MediaPlatform.reddit => 'Reddit',
        MediaPlatform.x => 'Twitter',
        MediaPlatform.discord => 'Discord',
        MediaPlatform.v2ex => 'V2EX',
        MediaPlatform.medium => 'Medium',
        MediaPlatform.stackoverflow => 'Stack Overflow',
        MediaPlatform.quora => 'Quora',
        MediaPlatform.telegram => 'Telegram',
        MediaPlatform.github => 'GitHub',
        MediaPlatform.wikipedia => 'Wikipedia',
        MediaPlatform.apple => 'Apple',
        MediaPlatform.onetrust => 'OneTrust',
        MediaPlatform.gitlab => 'GitLab',
        MediaPlatform.npm => 'npm',
        MediaPlatform.cdnjs => 'cdnjs',
        MediaPlatform.unpkg => 'unpkg',
        MediaPlatform.nodejs => 'Node.js',
        MediaPlatform.steam => 'Steam',
        MediaPlatform.epic => 'Epic Games',
        MediaPlatform.ubisoft => 'Ubisoft',
        MediaPlatform.humblebundle => 'Humble Bundle',
        MediaPlatform.coinbase => 'Coinbase',
        MediaPlatform.okx => 'OKX',
        MediaPlatform.kraken => 'Kraken',
        MediaPlatform.cryptocom => 'Crypto.com',
        MediaPlatform.phantom => 'Phantom',
      };

  bool get isMonochrome => switch (this) {
        MediaPlatform.openai ||
        MediaPlatform.suno ||
        MediaPlatform.github ||
        MediaPlatform.wikipedia ||
        MediaPlatform.apple ||
        MediaPlatform.tiktok ||
        MediaPlatform.medium ||
        MediaPlatform.grok ||
        MediaPlatform.unpkg ||
        // 品牌本身是黑/白单色素材：跟随主题着色，浅色模式黑、深色模式白
        MediaPlatform.ubisoft ||
        MediaPlatform.epic =>
          true,
        _ => false,
      };

  /// 深色模式下整体反色的素材，见 [themedPlatformIcon]；单色黑素材请用 [isMonochrome]。
  ///
  /// crypto 分类默认整体反色（这类标记多为黑/深色，深色背景下要反色才看得清），
  /// 但彩色品牌徽标例外：反色会破坏品牌色，因此显式排除。
  bool get invertOnDark => switch (this) {
        MediaPlatform.coinbase ||
        MediaPlatform.phantom ||
        MediaPlatform.kraken => false,
        // E-Hentai 是深红色单色标记，深色背景下偏暗，单独加入反色
        MediaPlatform.ehentai => true,
        _ => category == MediaCategory.crypto,
      };

  bool get pinColoBadge => this == MediaPlatform.telegram;

  Size get iconSize => switch (this) {
        MediaPlatform.youtube => const Size(19, 13.5),
        MediaPlatform.disney ||
        MediaPlatform.onetrust =>
          const Size(19, 10.5),
        MediaPlatform.netflix => const Size(10, 18),
        MediaPlatform.reddit ||
        MediaPlatform.spotify ||
        MediaPlatform.telegram ||
        MediaPlatform.coinbase ||
        MediaPlatform.cryptocom ||
        MediaPlatform.steam =>
          const Size(15, 15),
        MediaPlatform.openai ||
        MediaPlatform.claude ||
        MediaPlatform.openrouter ||
        MediaPlatform.perplexity ||
        MediaPlatform.apple =>
          const Size(17, 17),
        _ => const Size(16, 16),
      };
}

enum MediaUnlockStatus {
  unlocked,
  limited,
  flagged,
  blocked,
  failed,
  testing,
  unknown,
}

extension MediaUnlockStatusExt on MediaUnlockStatus {
  Color statusColor(ColorScheme colorScheme) => switch (this) {
        MediaUnlockStatus.unlocked => mediaUnlockGreen,
        MediaUnlockStatus.limited || MediaUnlockStatus.flagged =>
          mediaUnlockOrange,
        MediaUnlockStatus.blocked || MediaUnlockStatus.failed =>
          colorScheme.error,
        MediaUnlockStatus.testing => colorScheme.primary,
        MediaUnlockStatus.unknown => colorScheme.outlineVariant,
      };
}

class MediaUnlockResult {
  final MediaPlatform platform;
  final MediaUnlockStatus status;
  final String? region;
  final int? latency;
  final String? colo;
  final String? ip;
  final bool isWarp;

  const MediaUnlockResult({
    required this.platform,
    required this.status,
    this.region,
    this.latency,
    this.colo,
    this.ip,
    this.isWarp = false,
  });

  MediaUnlockResult copyWith({
    MediaPlatform? platform,
    MediaUnlockStatus? status,
    String? region,
    int? latency,
    String? colo,
    String? ip,
    bool? isWarp,
  }) {
    return MediaUnlockResult(
      platform: platform ?? this.platform,
      status: status ?? this.status,
      region: region ?? this.region,
      latency: latency ?? this.latency,
      colo: colo ?? this.colo,
      ip: ip ?? this.ip,
      isWarp: isWarp ?? this.isWarp,
    );
  }
}

class MediaUnlockState {
  final bool isLoading;
  final Map<MediaPlatform, MediaUnlockResult> results;
  final Set<MediaPlatform> testingPlatforms;
  final DateTime? lastChecked;

  const MediaUnlockState({
    this.isLoading = false,
    this.results = const {},
    this.testingPlatforms = const {},
    this.lastChecked,
  });

  MediaUnlockState copyWith({
    bool? isLoading,
    Map<MediaPlatform, MediaUnlockResult>? results,
    Set<MediaPlatform>? testingPlatforms,
    DateTime? lastChecked,
  }) {
    return MediaUnlockState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      testingPlatforms: testingPlatforms ?? this.testingPlatforms,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}
