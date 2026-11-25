import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'pressable.dart';

/// Building blocks of the expressive phone design (2026-11-25): soft
/// "flower" shape for artists, buttons whose corners tighten when pressed,
/// a title that scrolls when it does not fit.

/// Scalloped circle ("cookie"): [lobes] soft bumps around a circle, [depth]
/// of the radius deep. [rotation] turns it (radians).
class ScallopBorder extends OutlinedBorder {
  const ScallopBorder({
    this.lobes = 9,
    this.depth = 0.07,
    this.rotation = 0,
    super.side,
  });

  final int lobes;
  final double depth;
  final double rotation;

  Path _path(Rect rect) {
    final r = rect.shortestSide / 2;
    final center = rect.center;
    final path = Path();
    const steps = 180;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * math.pi;
      // Cosine bumps, smooth at the valleys.
      final k = r * (1 - depth * (1 - math.cos(lobes * a)) / 2);
      final p =
          center + Offset(math.cos(a + rotation), math.sin(a + rotation)) * k;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.strokeInset));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_path(rect), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => ScallopBorder(
    lobes: lobes,
    depth: depth,
    rotation: rotation,
    side: side.scale(t),
  );

  @override
  ScallopBorder copyWith({BorderSide? side}) => ScallopBorder(
    lobes: lobes,
    depth: depth,
    rotation: rotation,
    side: side ?? this.side,
  );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  bool operator ==(Object other) =>
      other is ScallopBorder &&
      other.lobes == lobes &&
      other.depth == depth &&
      other.rotation == rotation &&
      other.side == side;

  @override
  int get hashCode => Object.hash(lobes, depth, rotation, side);
}

/// Clips [child] to the scallop; it turns slowly while [spinning] (an artist
/// whose title plays), still when motion is reduced.
class ScallopClip extends StatefulWidget {
  const ScallopClip({
    super.key,
    required this.child,
    this.spinning = false,
    this.lobes = 9,
    this.depth = 0.07,
  });

  final Widget child;
  final bool spinning;
  final int lobes;
  final double depth;

  @override
  State<ScallopClip> createState() => _ScallopClipState();
}

class _ScallopClipState extends State<ScallopClip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ScallopClip old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.spinning && !MmMotion.of(context).reduced;
    if (on && !_turn.isAnimating) _turn.repeat();
    if (!on && _turn.isAnimating) _turn.stop();
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _turn,
    child: widget.child,
    builder: (context, child) => ClipPath(
      clipper: ShapeBorderClipper(
        shape: ScallopBorder(
          lobes: widget.lobes,
          depth: widget.depth,
          rotation: _turn.value * 2 * math.pi / widget.lobes,
        ),
      ),
      child: child,
    ),
  );
}

/// A filled button whose corners tighten and whose content dips when held
/// (shape morph of the expressive design). [radius] at rest, [pressedRadius]
/// held. A light haptic on press.
class MorphButton extends StatefulWidget {
  const MorphButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    required this.semanticLabel,
    this.onLongPress,
    this.radius = 40,
    this.pressedRadius = 14,
    this.height = 64,
    this.width,
    this.tooltip,
    this.selected = false,
    this.shape,
    this.onHeld,
  });

  /// Told when the finger goes down and up (a [MorphGroup] widens it).
  final ValueChanged<bool>? onHeld;

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Corners at rest when they differ (connected pairs); [radius] otherwise.
  final BorderRadius? shape;
  final Color color;
  final String semanticLabel;
  final String? tooltip;
  final double radius;
  final double pressedRadius;
  final double height;
  final double? width;
  final bool selected;

  @override
  State<MorphButton> createState() => _MorphButtonState();
}

class _MorphButtonState extends State<MorphButton> {
  bool _down = false;

  void _press(bool v) {
    if (widget.onTap == null || _down == v) return;
    if (v) HapticFeedback.lightImpact();
    setState(() => _down = v);
    widget.onHeld?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final motion = MmMotion.of(context);
    final radius = _down
        ? BorderRadius.circular(widget.pressedRadius)
        : (widget.shape ?? BorderRadius.circular(widget.radius));
    return Listener(
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: Pressable(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        semanticLabel: widget.semanticLabel,
        tooltip: widget.tooltip,
        selected: widget.selected,
        pressScale: 1,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: motion.reduced
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: MmMotion.spring,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.onTap == null
                ? widget.color.withValues(alpha: 0.5)
                : widget.color,
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: _down && !motion.reduced ? 0.9 : 1,
            duration: const Duration(milliseconds: 160),
            curve: MmMotion.spring,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Buttons side by side whose widths follow their weights; the one being
/// pressed borrows width from its neighbours (connected button group).
class MorphGroup extends StatefulWidget {
  const MorphGroup({
    super.key,
    required this.weights,
    required this.builder,
    this.spacing = 8,
  });

  final List<double> weights;
  final double spacing;

  /// Builds button [i]; [onDown] tells the group it is held.
  final Widget Function(BuildContext context, int i, ValueChanged<bool> onDown)
  builder;

  @override
  State<MorphGroup> createState() => _MorphGroupState();
}

class _MorphGroupState extends State<MorphGroup> {
  int? _held;

  @override
  Widget build(BuildContext context) {
    final motion = MmMotion.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final n = widget.weights.length;
        final free = box.maxWidth - widget.spacing * (n - 1);
        final weights = [
          for (var i = 0; i < n; i++)
            widget.weights[i] * (_held == i && !motion.reduced ? 1.15 : 1),
        ];
        final sum = weights.fold<double>(0, (a, b) => a + b);
        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(width: widget.spacing),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: MmMotion.spring,
                width: free * weights[i] / sum,
                child: widget.builder(
                  context,
                  i,
                  (down) => setState(
                    () => _held = down ? i : (_held == i ? null : _held),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Text on one line that, when too long, scrolls slowly after a pause and
/// comes back (fades at the edges). Static and ellipsised with reduced
/// motion.
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this);
  double _overflow = 0;

  static const _gap = 48.0;
  static const _speed = 32.0; // logical px per second
  static const _pause = Duration(milliseconds: 1800);

  @override
  void didUpdateWidget(MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _wait?.cancel();
      _wait = null;
      _ctl.stop();
      _ctl.value = 0;
      _overflow = 0;
    }
  }

  /// The pause before each pass; one at a time.
  Timer? _wait;

  void _run(double textWidth) {
    if (!mounted || _ctl.isAnimating || (_wait?.isActive ?? false)) return;
    final distance = textWidth + _gap;
    final run = Duration(milliseconds: (distance / _speed * 1000).round());
    _wait = Timer(_pause, () async {
      if (!mounted || _overflow <= 0) return;
      _ctl.duration = run;
      await _ctl.forward(from: 0).orCancel.catchError((_) {});
      if (mounted && _overflow > 0) {
        _ctl.value = 0;
        _run(textWidth);
      }
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MmMotion.of(context).reduced;
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final textWidth = painter.width;
        final height = painter.height;
        painter.dispose();
        _overflow = textWidth - box.maxWidth;
        if (_overflow <= 0 || reduced) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _run(textWidth));
        final line = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: widget.style,
        );
        return Semantics(
          label: widget.text,
          excludeSemantics: true,
          child: SizedBox(
            height: height,
            width: box.maxWidth,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (context, _) {
                  final dx = -_ctl.value * (textWidth + _gap);
                  // The left edge fades only while the text moves.
                  final left = _ctl.value > 0 && _ctl.value < 1 ? 0.05 : 0.0;
                  return ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      colors: const [
                        Color(0x00000000),
                        Color(0xFF000000),
                        Color(0xFF000000),
                        Color(0x00000000),
                      ],
                      stops: [0, left, 0.9, 1],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: double.infinity,
                      child: Transform.translate(
                        offset: Offset(dx, 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            line,
                            const SizedBox(width: _gap),
                            line,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A round icon button on a filled disc (player top bar, lyrics).
class DiscButton extends StatelessWidget {
  const DiscButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.iconColor,
    this.size = 52,
    this.iconSize = 24,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color iconColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    tooltip: label,
    pressScale: 0.88,
    child: AnimatedContainer(
      duration: MmMotion.of(context).screen,
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: iconSize,
        color: onTap == null ? iconColor.withValues(alpha: 0.4) : iconColor,
      ),
    ),
  );
}
