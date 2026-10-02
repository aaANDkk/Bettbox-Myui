import 'package:bett_box/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the theme palette color schemes from being regenerated on every visit
/// to the theme page: the providers are auto-disposed, so each entry used to
/// re-run `ColorScheme.fromSeed` for every swatch during the page transition.
/// Warms one entry per frame to keep any single frame cheap.
class ThemePaletteWarmer extends ConsumerStatefulWidget {
  const ThemePaletteWarmer({super.key});

  @override
  ConsumerState<ThemePaletteWarmer> createState() => _ThemePaletteWarmerState();
}

class _ThemePaletteWarmerState extends ConsumerState<ThemePaletteWarmer> {
  final Map<String, ProviderSubscription<ColorScheme>> _subscriptions = {};
  final List<_PaletteEntry> _pending = [];
  var _scheduled = false;

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.close();
    }
    _subscriptions.clear();
    _pending.clear();
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || _pending.isEmpty) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _warmNext();
    });
  }

  void _warmNext() {
    if (_pending.isEmpty) return;
    final entry = _pending.removeAt(0);
    _subscriptions.putIfAbsent(
      entry.key,
      () => ref.listenManual(
        genColorSchemeProvider(
          entry.brightness,
          color: entry.color,
          ignoreConfig: true,
        ),
        (_, _) {},
      ),
    );
    _schedule();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = ref.watch(
      themeSettingProvider.select((state) => state.primaryColors),
    );
    for (final color in <Color?>[null, ...colors.map(Color.new)]) {
      final entry = _PaletteEntry(brightness, color);
      if (_subscriptions.containsKey(entry.key)) continue;
      if (_pending.contains(entry)) continue;
      _pending.add(entry);
    }
    _schedule();
    return const SizedBox.shrink();
  }
}

class _PaletteEntry {
  _PaletteEntry(this.brightness, this.color);

  final Brightness brightness;
  final Color? color;

  String get key => '${brightness.name}:${color?.toARGB32()}';

  @override
  bool operator ==(Object other) =>
      other is _PaletteEntry &&
      other.brightness == brightness &&
      other.color == color;

  @override
  int get hashCode => Object.hash(brightness, color);
}
