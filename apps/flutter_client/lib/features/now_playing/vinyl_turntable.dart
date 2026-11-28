// Vue vinyle « Platine » (option 1a), from the owner's handoff
// design_handoff_vinyle_platine (2026-11-25): a record on a turntable with a
// tonearm. Geometry on a 372 dp design box, scaled by `size / 372`.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../design/cover_tones.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';

/// The cover as a record on a turntable: the record turns (one turn per
/// 4 s, slowed at the owner's request) while the music plays and stops
/// dead on pause; the label (cover) and the spindle stay still; the
/// tonearm sets down when playing, tracks inward with [progress] and swings
/// back to its rest on pause.
class VinylTurntable extends StatefulWidget {
  const VinylTurntable({
    super.key,
    required this.size,
    required this.seed,
    required this.imagePath,
    required this.playing,
    required this.progress,
    required this.tones,
    this.recordHidden = false,
  });

  /// Where the record sits in a turntable laid out in [box] (a square).
  static Rect recordIn(Rect box) {
    final k = box.width / 372;
    return Rect.fromLTWH(box.left + 4 * k, box.top + 18 * k, 336 * k, 336 * k);
  }

  final double size;
  final int seed;
  final String? imagePath;
  final bool playing;

  /// 0..1 position in the track (drives the tonearm).
  final double progress;
  final CoverTones tones;

  /// The record, its label and the spindle are hidden (their copy is lifted
  /// off toward the mini player); the platter and the tonearm stay.
  final bool recordHidden;

  @override
  State<VinylTurntable> createState() => _VinylTurntableState();
}

class _VinylTurntableState extends State<VinylTurntable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(VinylTurntable old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.playing && !MmMotion.of(context).reduced;
    if (on && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!on && _turn.isAnimating) {
      _turn.stop(); // keeps the angle: the record pauses where it is
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.size / 372;
    const disc = 336.0, discLeft = 4.0, discTop = 18.0;
    final label = disc * 0.4;
    final spindle = disc * 0.035;
    final armTarget = widget.playing
        ? _Arm.angleFor(168 * (0.93 - 0.49 * widget.progress.clamp(0.0, 1.0)))
        : _Arm.rest;

    Widget at(double l, double t, double w, double h, Widget child) =>
        Positioned(
          left: l * k,
          top: t * k,
          width: w * k,
          height: h * k,
          child: child,
        );

    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Platter under the record.
          at(
            0,
            14,
            344,
            344,
            const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x38000000),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0x0DFFFFFF)),
                ),
              ),
            ),
          ),
          // The turning record (grooves, track gaps, light streaks, specks).
          if (!widget.recordHidden) ...[
            at(
              discLeft,
              discTop,
              disc,
              disc,
              RotationTransition(
                turns: _turn,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: MmShadows.card,
                  ),
                  child: CustomPaint(painter: _RecordPainter()),
                ),
              ),
            ),
            // Fixed reflection: it does not turn with the record.
            at(
              discLeft,
              discTop,
              disc,
              disc,
              const IgnorePointer(child: CustomPaint(painter: _SheenPainter())),
            ),
            // Fixed label: the cover (or the Miarina placeholder) never turns.
            at(
              discLeft + (disc - label) / 2,
              discTop + (disc - label) / 2,
              label,
              label,
              DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x59000000), spreadRadius: 2),
                  ],
                ),
                child: ClipOval(
                  child: CoverArt(
                    size: label * k,
                    radius: 0,
                    seed: widget.seed,
                    imagePath: widget.imagePath,
                    shadow: false,
                  ),
                ),
              ),
            ),
            at(
              discLeft + (disc - spindle) / 2,
              discTop + (disc - spindle) / 2,
              spindle,
              spindle,
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF101418),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x2EFFFFFF), spreadRadius: 2),
                  ],
                ),
              ),
            ),
          ],
          // Tonearm base, arm, cap. The arm eases to its target (set down,
          // tracking, back to rest) in 600 ms.
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: armTarget),
              duration: MmMotion.of(context).reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              curve: MmMotion.standard,
              builder: (context, deg, _) => CustomPaint(
                painter: _TonearmPainter(
                  scale: k,
                  degrees: deg,
                  base: widget.tones.button,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The record lifted off the turntable when the player is dragged down: at
/// [t] 0 the record as it sits on the platter (label = cover, 40 %), at 1
/// the bare cover with the mini player's corners: the label grows to fill
/// it while the grooves fade.
class RecordFlight extends StatelessWidget {
  const RecordFlight({
    super.key,
    required this.size,
    required this.t,
    required this.seed,
    required this.imagePath,
    this.endRadius = 14,
  });

  final double size;
  final double t;
  final int seed;
  final String? imagePath;
  final double endRadius;

  @override
  Widget build(BuildContext context) {
    final label = size * (0.4 + 0.6 * t);
    final radius = label / 2 + (endRadius - label / 2) * t;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: (1 - t * 1.6).clamp(0.0, 1.0),
            child: const SizedBox.expand(
              child: CustomPaint(painter: _RecordPainter()),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: CoverArt(
              size: label,
              radius: 0,
              seed: seed,
              imagePath: imagePath,
              shadow: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// Needle geometry, design box 372: pivot (340, 36), arm 250 long, record
/// centre (172, 186), radius 168. 0° points straight down; positive turns
/// clockwise (needle moves left, onto the record).
abstract final class _Arm {
  static const rest = -6.0;
  static const _pivot = Offset(340, 36);
  static const _length = 250.0;
  static const _centre = Offset(172, 186);

  static final List<(double, double)> _table = [
    for (var i = 0; i <= 900; i++)
      () {
        final deg = -10 + i * 0.1;
        final r = deg * math.pi / 180;
        final n =
            _pivot + Offset(-_length * math.sin(r), _length * math.cos(r));
        return (deg, (n - _centre).distance);
      }(),
  ];

  /// Smallest angle that puts the needle [radius] from the record centre.
  static double angleFor(double radius) {
    for (final (deg, d) in _table) {
      if (d <= radius) return deg;
    }
    return _table.last.$1;
  }
}

class _RecordPainter extends CustomPainter {
  const _RecordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Base (same as the shipped _Grooves).
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF23272C), Color(0xFF0E1013), Color(0xFF1A1D21)],
          stops: [0.2, 0.75, 1],
        ).createShader(rect),
    );

    // Fine grooves: a hairline every 1.4 % of the radius.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.004
      ..color = const Color(0x12FFFFFF);
    for (var k = r * 0.41; k < r * 0.97; k += r * 0.014) {
      canvas.drawCircle(c, k, groove);
    }

    // Dead wax (smooth band around the label).
    canvas.drawCircle(
      c,
      r * 0.43,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = const Color(0x8C0E1013),
    );

    // Gaps between tracks.
    final gap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.008
      ..color = const Color(0x73000000);
    for (final f in const [0.584, 0.724, 0.844]) {
      canvas.drawCircle(c, r * f, gap);
    }

    // Light streaks that turn with the record (they make the rotation visible).
    canvas.drawCircle(
      c,
      r * 0.69,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.56
        ..shader = SweepGradient(
          transform: const GradientRotation(-math.pi / 2),
          colors: const [
            Color(0x00FFFFFF),
            Color(0x29FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x12FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x21FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x0FFFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [
            0,
            0.039,
            0.094,
            0.333,
            0.383,
            0.433,
            0.556,
            0.6,
            0.661,
            0.833,
            0.883,
            0.933,
            1,
          ],
        ).createShader(rect),
    );

    // Outer lip.
    canvas.drawCircle(
      c,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = const Color(0x12FFFFFF),
    );

    // Dust specks (box-relative positions).
    final d = size.shortestSide;
    for (final (x, y, s, a) in const [
      (0.22, 0.16, 3.0, 0x73),
      (0.78, 0.64, 2.0, 0x66),
      (0.34, 0.84, 2.0, 0x59),
    ]) {
      canvas.drawCircle(
        Offset(x * d + s / 2, y * d + s / 2),
        s / 2,
        Paint()..color = Color.fromARGB(a, 255, 255, 255),
      );
    }
  }

  @override
  bool shouldRepaint(_RecordPainter old) => false;
}

/// Fixed reflection: CSS conic-gradient(from 300deg …) → sweep from 210°.
class _SheenPainter extends CustomPainter {
  const _SheenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          transform: const GradientRotation(210 * math.pi / 180),
          colors: const [
            Color(0x00FFFFFF),
            Color(0x1AFFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x12FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0, 25 / 360, 55 / 360, 0.5, 205 / 360, 235 / 360, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => false;
}

class _TonearmPainter extends CustomPainter {
  _TonearmPainter({
    required this.scale,
    required this.degrees,
    required this.base,
  });

  final double scale;
  final double degrees;
  final Color base;

  static const _metal = LinearGradient(
    colors: [Color(0xFFA9A29D), Color(0xFFF4EFEB), Color(0xFFB8B1AC)],
  );
  static const _weight = LinearGradient(
    colors: [Color(0xFF8E8782), Color(0xFFE6E0DB), Color(0xFF9E9792)],
    stops: [0, 0.45, 1],
  );
  static const _head = LinearGradient(
    colors: [Color(0xFF2E2A27), Color(0xFF4C4642), Color(0xFF2E2A27)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale);
    const pivot = Offset(340, 36);

    // Base.
    canvas.drawCircle(pivot, 30, Paint()..color = base);
    canvas.drawCircle(
      pivot,
      29,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x14FFFFFF),
    );

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(degrees * math.pi / 180);

    final shadow = Paint()
      ..color = const Color(0x47000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    const arm = Rect.fromLTWH(-3, -40, 6, 290);
    const weight = Rect.fromLTWH(-12, -46, 24, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        arm.shift(const Offset(4, 6)),
        const Radius.circular(3),
      ),
      shadow,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(weight, const Radius.circular(7)),
      Paint()..shader = _weight.createShader(weight),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(arm, const Radius.circular(3)),
      Paint()..shader = _metal.createShader(arm),
    );

    // Headshell, turned 16° at the end of the arm.
    canvas.save();
    canvas.translate(0, 241);
    canvas.rotate(16 * math.pi / 180);
    const head = Rect.fromLTWH(-11, -17, 22, 34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        head.shift(const Offset(4, 6)),
        const Radius.circular(5),
      ),
      shadow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(head, const Radius.circular(5)),
      Paint()..shader = _head.createShader(head),
    );
    canvas.restore();
    canvas.restore();

    // Cap over the pivot.
    canvas.drawCircle(
      pivot,
      9,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFF4EFEB), Color(0xFF8E8782)],
        ).createShader(Rect.fromCircle(center: pivot, radius: 9)),
    );
  }

  @override
  bool shouldRepaint(_TonearmPainter old) =>
      old.degrees != degrees || old.scale != scale || old.base != base;
}
