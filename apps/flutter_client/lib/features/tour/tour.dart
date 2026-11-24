import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../playback/settings_store.dart';

/// The places the guided tour points at (Windows shell).
enum TourSpot { space, getLink, tools, library, search, playbar, settings }

/// One step: where the app goes (null: stays), what is lit (null: the
/// card alone, in the middle).
typedef TourStep = ({String? route, TourSpot? spot});

const tourSteps = <TourStep>[
  // Welcome: where the user is.
  (route: null, spot: null),
  (route: Routes.get, spot: TourSpot.space),
  (route: Routes.get, spot: TourSpot.getLink),
  (route: Routes.get, spot: TourSpot.tools),
  (route: Routes.listenHome, spot: TourSpot.library),
  (route: Routes.listenHome, spot: TourSpot.search),
  (route: Routes.listenHome, spot: TourSpot.playbar),
  (route: Routes.listenHome, spot: TourSpot.settings),
];

(String, String) tourText(L10n t, int step) => switch (step) {
  0 => (t.tourWelcomeTitle, t.tourWelcomeBody),
  1 => (t.tourSpaceTitle, t.tourSpaceBody),
  2 => (t.tourLinkTitle, t.tourLinkBody),
  3 => (t.tourToolsTitle, t.tourToolsBody),
  4 => (t.tourLibraryTitle, t.tourLibraryBody),
  5 => (t.tourSearchTitle, t.tourSearchBody),
  6 => (t.tourPlaybarTitle, t.tourPlaybarBody),
  _ => (t.tourSettingsTitle, t.tourSettingsBody),
};

/// Marks a widget the tour can light: its place is read from here.
class TourTarget extends StatefulWidget {
  const TourTarget({
    super.key,
    required this.spot,
    required this.child,
    this.enabled = true,
  });

  final TourSpot spot;
  final Widget child;

  /// False: shown as is, not a place of the tour.
  final bool enabled;

  static final _keys = <TourSpot, GlobalKey>{};

  /// Where [spot] is on the window, if it shows.
  static Rect? rectOf(TourSpot spot) {
    final box = _keys[spot]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.enabled) TourTarget._keys[widget.spot] = _key;
  }

  @override
  void dispose() {
    if (identical(TourTarget._keys[widget.spot], _key)) {
      TourTarget._keys.remove(widget.spot);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

/// The current step, or null when no tour shows.
final tourProvider = NotifierProvider<TourController, int?>(TourController.new);

class TourController extends Notifier<int?> {
  static const doneKey = 'tourDone';

  @override
  int? build() => null;

  /// From Settings: from the start, whatever was seen.
  void start() {
    state = 0;
    _go();
  }

  /// After the first-launch screens: once, on Windows.
  Future<void> startIfNew() async {
    if (!ref.read(desktopShellProvider)) return;
    if (await ref.read(settingsStoreProvider).read(doneKey) == true) return;
    start();
  }

  void next() {
    final s = state;
    if (s == null) return;
    if (s + 1 >= tourSteps.length) {
      unawaited(finish());
      return;
    }
    state = s + 1;
    _go();
  }

  void back() {
    final s = state;
    if (s == null || s == 0) return;
    state = s - 1;
    _go();
  }

  /// Done or skipped: not shown again by itself.
  Future<void> finish() async {
    state = null;
    await ref.read(settingsStoreProvider).write(doneKey, true);
  }

  void _go() {
    final s = state;
    if (s == null) return;
    final route = tourSteps[s].route;
    if (route != null) ref.read(routerProvider).go(route);
  }
}

/// Above every screen (app root): the lit place and the step's card.
class TourHost extends ConsumerWidget {
  const TourHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(tourProvider);
    return Stack(
      children: [
        child,
        if (step != null)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: _TourOverlay(key: ValueKey(step), step: step),
            ),
          ),
      ],
    );
  }
}

class _TourOverlay extends ConsumerStatefulWidget {
  const _TourOverlay({super.key, required this.step});

  final int step;

  @override
  ConsumerState<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<_TourOverlay> {
  Rect? _target;
  int _tries = 0;
  final _focus = FocusNode(debugLabel: 'tour');

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The screen changes first: the place is read once it is drawn.
  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final spot = tourSteps[widget.step].spot;
      final rect = spot == null ? null : TourTarget.rectOf(spot);
      if (rect != _target) setState(() => _target = rect);
      _focus.requestFocus();
      if (spot != null && _tries++ < 20) _measure();
    });
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final tour = ref.read(tourProvider.notifier);
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(tour.finish());
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight ||
        e.logicalKey == LogicalKeyboardKey.enter) {
      tour.next();
    } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      tour.back();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final size = MediaQuery.sizeOf(context);
    final hole = _target?.inflate(6);
    const cardWidth = 340.0;
    const cardHeight = 210.0;
    // Right of the lit place when there is room, else under it, else above.
    Offset at;
    if (hole == null) {
      at = Offset((size.width - cardWidth) / 2, (size.height - cardHeight) / 2);
    } else if (hole.right + 16 + cardWidth < size.width - 12) {
      at = Offset(hole.right + 16, hole.top);
    } else if (hole.bottom + 12 + cardHeight < size.height - 12) {
      at = Offset(hole.right - cardWidth, hole.bottom + 12);
    } else {
      at = Offset(hole.right - cardWidth, hole.top - 12 - cardHeight);
    }
    at = Offset(
      at.dx.clamp(12, size.width - cardWidth - 12),
      at.dy.clamp(12, size.height - cardHeight - 12),
    );
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: Stack(
        children: [
          // The window is dimmed but for the lit place; clicks stay here.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _SpotPainter(
                  hole: hole,
                  scrim: c.scrim,
                  ring: c.accent,
                ),
              ),
            ),
          ),
          Positioned(
            left: at.dx,
            top: at.dy,
            width: cardWidth,
            child: _TourCard(step: widget.step),
          ),
        ],
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter({required this.hole, required this.scrim, required this.ring});

  final Rect? hole;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    final h = hole;
    if (h == null) {
      canvas.drawRect(all, Paint()..color = scrim);
      return;
    }
    final r = RRect.fromRectAndRadius(h, const Radius.circular(MmRadius.lg));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(all),
        Path()..addRRect(r),
      ),
      Paint()..color = scrim,
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotPainter old) =>
      old.hole != hole || old.scrim != scrim || old.ring != ring;
}

class _TourCard extends ConsumerWidget {
  const _TourCard({required this.step});

  final int step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final tour = ref.read(tourProvider.notifier);
    final (title, body) = tourText(t, step);
    final last = step == tourSteps.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MmRadius.xl),
        border: Border.all(color: c.overlayBorder),
        boxShadow: MmShadows.dialog,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < tourSteps.length; i++)
                Container(
                  width: i == step ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i == step ? c.accent : c.lineStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 12),
              const Spacer(),
              if (!last)
                Flexible(
                  child: Pressable(
                    onTap: () => unawaited(tour.finish()),
                    semanticLabel: t.tourSkip,
                    child: Text(
                      t.tourSkip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.caption.copyWith(color: c.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: MmType.heading.copyWith(fontSize: 16, color: c.fg),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: MmType.bodySm.copyWith(color: c.fgSoft, height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              if (step > 0) ...[
                _CardButton(label: t.tourBack, onTap: tour.back),
                const SizedBox(width: 8),
              ],
              _CardButton(
                label: last ? t.tourDone : t.tourNext,
                primary: true,
                onTap: tour.next,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: primary ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(MmRadius.sm),
          border: primary ? null : Border.all(color: c.lineStrong),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: MmType.labelStrong.copyWith(
              fontSize: 13,
              color: primary ? const Color(0xFF062320) : c.fg,
            ),
          ),
        ),
      ),
    );
  }
}
