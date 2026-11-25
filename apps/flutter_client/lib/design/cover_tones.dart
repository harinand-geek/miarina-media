import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Colours taken from a cover (expressive phone design, 2026-11-25): the
/// player's ground, its buttons and the tinted cards of the lists follow the
/// album. Derived from the cover's dominant colour with Material's tonal
/// palettes, so contrast stays right in both themes.
@immutable
class CoverTones {
  const CoverTones({
    required this.ground,
    required this.onGround,
    required this.onGroundSoft,
    required this.button,
    required this.onButton,
    required this.primary,
    required this.onPrimary,
    required this.track,
    required this.card,
    required this.onCard,
  });

  /// Page behind the player; tinted card of a list.
  final Color ground;
  final Color onGround;
  final Color onGroundSoft;

  /// Secondary buttons (previous, next, round icons): white in light.
  final Color button;
  final Color onButton;

  /// Play button, active slider.
  final Color primary;
  final Color onPrimary;

  /// Inactive part of the sliders.
  final Color track;

  /// Softer tint for cards that sit on the app's own ground.
  final Color card;
  final Color onCard;

  factory CoverTones.fromSeed(Color seed, Brightness brightness) {
    final s = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    final dark = brightness == Brightness.dark;
    return CoverTones(
      ground: dark
          ? Color.lerp(s.surfaceContainerLow, s.primaryContainer, 0.42)!
          : s.primaryContainer,
      onGround: dark ? s.onSurface : s.onPrimaryContainer,
      onGroundSoft: dark
          ? s.onSurfaceVariant
          : s.onPrimaryContainer.withValues(alpha: 0.72),
      button: dark
          ? Color.lerp(s.surfaceContainerHighest, s.primaryContainer, 0.25)!
          : s.surfaceContainerLowest,
      onButton: s.onSurface,
      primary: s.primary,
      onPrimary: s.onPrimary,
      track: (dark ? s.onSurface : s.onPrimaryContainer).withValues(
        alpha: 0.18,
      ),
      card: dark
          ? Color.lerp(s.surfaceContainer, s.primaryContainer, 0.3)!
          : s.primaryContainer,
      onCard: dark ? s.onSurface : s.onPrimaryContainer,
    );
  }

  /// No cover, or not read yet: neutral surfaces of the app, play in coral.
  factory CoverTones.neutral(MmColors c) {
    final dark = c.brightness == Brightness.dark;
    return CoverTones(
      ground: dark ? c.surface : c.surface2,
      onGround: c.fg,
      onGroundSoft: c.fgSoft,
      button: dark ? c.surface2 : c.surface,
      onButton: c.fg,
      primary: c.coral,
      onPrimary: c.coralInk,
      track: c.fg.withValues(alpha: 0.16),
      card: c.surface,
      onCard: c.fg,
    );
  }

  static CoverTones lerp(CoverTones a, CoverTones b, double t) {
    Color l(Color x, Color y) => Color.lerp(x, y, t)!;
    return CoverTones(
      ground: l(a.ground, b.ground),
      onGround: l(a.onGround, b.onGround),
      onGroundSoft: l(a.onGroundSoft, b.onGroundSoft),
      button: l(a.button, b.button),
      onButton: l(a.onButton, b.onButton),
      primary: l(a.primary, b.primary),
      onPrimary: l(a.onPrimary, b.onPrimary),
      track: l(a.track, b.track),
      card: l(a.card, b.card),
      onCard: l(a.onCard, b.onCard),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoverTones &&
      other.ground == ground &&
      other.primary == primary &&
      other.button == button &&
      other.onGround == onGround;

  @override
  int get hashCode => Object.hash(ground, primary, button, onGround);
}

/// Dominant colour of the picture at [path], or null when it cannot be read.
/// Decoded at 64 px by the engine; the quantizer runs in another isolate so
/// scrolling a grid of covers never stalls the UI. Remembered (LRU) for the
/// session: a few hundred integers.
final coverSeedProvider = FutureProvider.autoDispose.family<Color?, String>((
  ref,
  path,
) async {
  final known = CoverSeeds.instance.cached(path);
  if (known != null) return known.$1;
  final seed = await CoverSeeds.instance.compute(path);
  return seed;
});

class CoverSeeds {
  CoverSeeds._();

  static final instance = CoverSeeds._();

  static const _capacity = 400;
  static const _maxParallel = 2;

  final _cache = <String, Color?>{};
  final _pending = <String, Future<Color?>>{};
  int _running = 0;
  final _waiting = Queue<void Function()>();

  /// Tests: put a known colour for a path.
  @visibleForTesting
  void put(String path, Color? seed) => _remember(path, seed);

  @visibleForTesting
  void clear() => _cache.clear();

  (Color?,)? cached(String path) {
    if (!_cache.containsKey(path)) return null;
    final v = _cache.remove(path);
    _cache[path] = v;
    return (v,);
  }

  void _remember(String path, Color? seed) {
    _cache.remove(path);
    _cache[path] = seed;
    while (_cache.length > _capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<Color?> compute(String path) =>
      _pending[path] ??= _slot(() => _read(path)).then((seed) {
        _remember(path, seed);
        _pending.remove(path);
        return seed;
      });

  /// At most [_maxParallel] covers are read at once.
  Future<T> _slot<T>(Future<T> Function() job) async {
    if (_running >= _maxParallel) {
      final turn = Completer<void>();
      _waiting.add(turn.complete);
      await turn.future;
    }
    _running++;
    try {
      return await job();
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeFirst()();
    }
  }

  static Future<Color?> _read(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 64,
        targetHeight: 64,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final data = await frame.image.toByteData();
      frame.image.dispose();
      if (data == null) return null;
      final rgba = data.buffer.asUint8List();
      final argb = await Isolate.run(() => dominantArgb(rgba));
      return argb == null ? null : Color(argb);
    } catch (_) {
      return null;
    }
  }
}

/// The Material score of the cover's colours (RGBA bytes); null when the
/// picture is fully transparent. Public for tests.
Future<int?> dominantArgb(List<int> rgba) async {
  final pixels = <int>[];
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final a = rgba[i + 3];
    if (a < 255) continue;
    pixels.add((a << 24) | (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2]);
  }
  if (pixels.isEmpty) return null;
  final result = await QuantizerCelebi().quantize(pixels, 128);
  final scored = Score.score(result.colorToCount, desired: 1);
  return scored.isEmpty ? null : scored.first;
}

/// The tones of [imagePath] in the current theme, neutral until the cover is
/// read (or without one).
CoverTones watchCoverTones(WidgetRef ref, BuildContext context, String? path) {
  final c = MmColors.of(context);
  if (path == null || path.isEmpty) return CoverTones.neutral(c);
  final seed = ref.watch(coverSeedProvider(path)).value;
  return seed == null
      ? CoverTones.neutral(c)
      : CoverTones.fromSeed(seed, c.brightness);
}

/// Animates from one set of tones to the next (500 ms) when the track, and so
/// the cover, changes; instant when motion is reduced.
class AnimatedCoverTones extends StatefulWidget {
  const AnimatedCoverTones({
    super.key,
    required this.tones,
    required this.builder,
    this.child,
  });

  final CoverTones tones;
  final Widget Function(BuildContext context, CoverTones tones, Widget? child)
  builder;
  final Widget? child;

  @override
  State<AnimatedCoverTones> createState() => _AnimatedCoverTonesState();
}

class _AnimatedCoverTonesState extends State<AnimatedCoverTones>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );
  late CoverTones _from = widget.tones;
  late CoverTones _to = widget.tones;

  @override
  void didUpdateWidget(AnimatedCoverTones old) {
    super.didUpdateWidget(old);
    if (widget.tones == _to) return;
    _from = CoverTones.lerp(_from, _to, _curve(_ctl.value));
    _to = widget.tones;
    if (MmMotion.of(context).reduced) {
      _ctl.value = 1;
    } else {
      _ctl.forward(from: 0);
    }
  }

  double _curve(double t) => MmMotion.standard.transform(t);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctl,
    child: widget.child,
    builder: (context, child) => widget.builder(
      context,
      CoverTones.lerp(_from, _to, _curve(_ctl.value)),
      child,
    ),
  );
}
