import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import '../settings/settings_data.dart';

/// Where the small cover was when the player was opened, so the big one can
/// grow out of it (Handoff §03, "Ouverture du lecteur").
final coverOriginProvider = NotifierProvider<CoverOrigin, Rect?>(
  CoverOrigin.new,
);

class CoverOrigin extends Notifier<Rect?> {
  @override
  Rect? build() => null;

  void set(Rect? rect) => state = rect;

  /// Global rectangle of the widget holding [key], recorded before opening.
  void capture(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    state = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Toggles the favorite of the current entry in the library and in the queue.
Future<void> toggleCurrentFavorite(WidgetRef ref) async {
  final entry = ref.read(queueProvider).current;
  final id = entry?.libraryId;
  if (entry == null || id == null) return;
  final next = !entry.favorite;
  await ref.read(libraryApiProvider).setFavorite(id, favorite: next);
  ref.read(queueProvider.notifier).markFavorite(id, favorite: next);
}

/// Blurred cover behind the player (σ 60) under a dark veil so text keeps a
/// 4.5:1 contrast. Static: the blur is never animated.
class CoverBackdrop extends ConsumerWidget {
  const CoverBackdrop({
    super.key,
    required this.seed,
    this.veil = const Color(0x8C0D141B),
    this.imagePath,
    this.nowPlaying = false,
  });

  final int seed;
  final Color veil;
  final String? imagePath;

  /// Behind the Now playing screens, where Settings can turn it off.
  final bool nowPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(appearanceProvider).value;
    // Settings › Appearance: opaque surfaces, or no cover behind the player.
    if ((look?.reduceTransparency ?? false) ||
        (nowPlaying && !(look?.coverBackdrop ?? true))) {
      return ColoredBox(color: MmColors.of(context).surface);
    }
    // Clipped: a blur spreads ~3σ beyond its box and would tint (and make the
    // compositor repaint) everything around it.
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 60,
                sigmaY: 60,
                tileMode: TileMode.mirror,
              ),
              child: FittedBox(
                fit: BoxFit.cover,
                // Decoded small: it is blurred anyway.
                child: CoverArt(
                  size: 160,
                  radius: 0,
                  seed: seed,
                  shadow: false,
                  imagePath: imagePath,
                ),
              ),
            ),
            ColoredBox(color: veil),
          ],
        ),
      ),
    );
  }
}

/// The big cover, growing from where the small one was (320 ms; a 120 ms
/// fade when motion is reduced).
class FlyingCover extends ConsumerStatefulWidget {
  const FlyingCover({
    super.key,
    required this.size,
    required this.seed,
    this.radius = 16,
    this.imagePath,
  });

  final double size;
  final int seed;
  final double radius;
  final String? imagePath;

  @override
  ConsumerState<FlyingCover> createState() => _FlyingCoverState();
}

class _FlyingCoverState extends ConsumerState<FlyingCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  final _key = GlobalKey();
  Rect? _origin;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    _origin = ref.read(coverOriginProvider);
    Future.microtask(() => ref.read(coverOriginProvider.notifier).set(null));
    if (_origin == null) {
      _ctl.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MmMotion.of(context).reduced) {
        _ctl.value = 1;
        return;
      }
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        _ctl.value = 1;
        return;
      }
      setState(() => _target = box.localToGlobal(Offset.zero) & box.size);
      _ctl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cover = CoverArt(
      key: _key,
      size: widget.size,
      radius: widget.radius,
      seed: widget.seed,
      imagePath: widget.imagePath,
    );
    return AnimatedBuilder(
      animation: _ctl,
      child: cover,
      builder: (context, child) {
        final origin = _origin;
        final target = _target;
        if (origin == null || target == null || _ctl.isCompleted) {
          return Opacity(
            opacity: origin != null && target == null ? 0 : 1,
            child: child,
          );
        }
        final t = MmMotion.standard.transform(_ctl.value);
        final r = Rect.lerp(origin, target, t)!;
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(r.left - target.left, r.top - target.top, 0, 1)
            ..scaleByDouble(
              r.width / target.width,
              r.width / target.width,
              1,
              1,
            ),
          child: child,
        );
      },
    );
  }
}

/// Favorite heart: 1 → 1.15 → 1 and fill in 180 ms (Handoff §03).
class FavoriteHeart extends StatelessWidget {
  const FavoriteHeart({super.key, required this.on, this.size = 24});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final motion = MmMotion.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(on),
      tween: Tween(begin: on && !motion.reduced ? 0 : 1, end: 1),
      duration: motion.favorite,
      builder: (context, t, child) => Transform.scale(
        scale: 1 + 0.15 * (t < 0.5 ? t * 2 : (1 - t) * 2),
        child: child,
      ),
      child: MmIcon(
        PhosphorRegular.heart,
        filled: PhosphorFill.heart,
        active: on,
        size: size,
        color: on ? c.coralStrong : c.fgSoft,
      ),
    );
  }
}

/// Small rounded info/action chip under the title (speed, preset, timer,
/// format).
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final fg = active ? c.coralStrong : c.fg;
    final chip = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(MmRadius.pill),
        border: Border.all(
          color: active ? c.coralChipBorder : c.fg.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: MmType.captionStrong.copyWith(fontSize: 12.5, color: fg),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return Pressable(
      onTap: onTap,
      semanticLabel: tooltip ?? label,
      tooltip: tooltip,
      child: chip,
    );
  }
}

/// Sleep timer chip with its menu; shows the time left when running.
class SleepTimerChip extends ConsumerStatefulWidget {
  const SleepTimerChip({super.key});

  @override
  ConsumerState<SleepTimerChip> createState() => _SleepTimerChipState();
}

class _SleepTimerChipState extends ConsumerState<SleepTimerChip> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final timer = ref.watch(sleepTimerProvider);
    final ctl = ref.read(sleepTimerProvider.notifier);
    final until = timer.until;
    _tick?.cancel();
    // Refresh the minutes left while the timer runs.
    if (until != null) {
      _tick = Timer(const Duration(seconds: 15), () {
        if (mounted) setState(() {});
      });
    }
    String label;
    if (until != null) {
      final left = until.difference(DateTime.now());
      label = '${left.inMinutes + 1} min';
    } else if (timer.endOfTrack) {
      label = t.sleepEndOfTrack;
    } else {
      label = t.sleepTimer;
    }
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface2),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MmRadius.lg),
            side: BorderSide(color: c.overlayBorder),
          ),
        ),
      ),
      menuChildren: [
        for (final m in const [15, 30, 45, 60])
          MenuItemButton(
            onPressed: () => ctl.after(Duration(minutes: m)),
            child: Text(
              t.sleepMinutes(m),
              style: MmType.label.copyWith(color: c.fg),
            ),
          ),
        MenuItemButton(
          onPressed: ctl.atEndOfTrack,
          child: Text(
            t.sleepEndOfTrack,
            style: MmType.label.copyWith(color: c.fg),
          ),
        ),
        if (timer.active)
          MenuItemButton(
            onPressed: ctl.cancel,
            child: Text(
              t.sleepOff,
              style: MmType.label.copyWith(color: c.coralStrong),
            ),
          ),
      ],
      builder: (context, menu, _) => InfoChip(
        icon: PhosphorRegular.moon,
        label: label,
        active: timer.active,
        tooltip: until != null ? t.sleepRemaining(label) : t.sleepTimer,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
