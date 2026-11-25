import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// Expressive progress (phone redesign, 2026-11-25): the played part is a
/// line that waves while the music plays and flattens when it pauses; a gap,
/// then the rest of the track and a stop dot at its end. [ExpressiveSlider]
/// adds a vertical thumb and dragging; [WavyProgress] is the bare line of the
/// mini player.
class WavyProgress extends StatelessWidget {
  const WavyProgress({
    super.key,
    required this.value,
    required this.playing,
    required this.color,
    required this.trackColor,
    this.stroke = 4,
    this.height = 12,
  });

  final double value;
  final bool playing;
  final Color color;
  final Color trackColor;
  final double stroke;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: _Wave(
      playing: playing,
      builder: (phase, amp) => CustomPaint(
        size: Size.infinite,
        painter: _SliderPainter(
          value: value,
          phase: phase,
          amplitude: amp * height * 0.28,
          active: color,
          inactive: trackColor,
          stroke: stroke,
          thumb: null,
          thumbHeight: 0,
        ),
      ),
    ),
  );
}

class ExpressiveSlider extends StatefulWidget {
  const ExpressiveSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    required this.activeColor,
    required this.trackColor,
    required this.semanticLabel,
    this.semanticValue,
    this.wavy = false,
    this.playing = false,
    this.step = 0.05,
    this.height = 44,
    this.stroke = 5,
  });

  /// 0..1.
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color activeColor;
  final Color trackColor;
  final String semanticLabel;
  final String? semanticValue;

  /// The played part waves while [playing] (seek bar); flat otherwise.
  final bool wavy;
  final bool playing;
  final double step;
  final double height;
  final double stroke;

  @override
  State<ExpressiveSlider> createState() => _ExpressiveSliderState();
}

class _ExpressiveSliderState extends State<ExpressiveSlider> {
  double? _drag;
  bool _focused = false;

  double _at(Offset local, double width) =>
      ((local.dx - 2) / (width - 4)).clamp(0.0, 1.0);

  void _set(double v, {bool end = false}) {
    widget.onChanged?.call(v);
    if (end) widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final enabled = widget.onChanged != null;
    final value = (_drag ?? widget.value).clamp(0.0, 1.0);
    final dragging = _drag != null;
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: widget.semanticValue ?? '${(value * 100).round()} %',
      increasedValue:
          '${((value + widget.step).clamp(0.0, 1.0) * 100).round()} %',
      decreasedValue:
          '${((value - widget.step).clamp(0.0, 1.0) * 100).round()} %',
      onIncrease: enabled
          ? () => _set((value + widget.step).clamp(0.0, 1.0), end: true)
          : null,
      onDecrease: enabled
          ? () => _set((value - widget.step).clamp(0.0, 1.0), end: true)
          : null,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowRight): _Step(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _Step(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _Step(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _Step(-1),
        },
        actions: {
          _Step: CallbackAction<_Step>(
            onInvoke: (s) => _set(
              (value + s.direction * widget.step).clamp(0.0, 1.0),
              end: true,
            ),
          ),
        },
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: enabled
                  ? (d) {
                      HapticFeedback.selectionClick();
                      _set(_at(d.localPosition, width), end: true);
                    }
                  : null,
              onHorizontalDragStart: enabled
                  ? (d) {
                      HapticFeedback.selectionClick();
                      setState(() => _drag = _at(d.localPosition, width));
                      _set(_drag!);
                    }
                  : null,
              onHorizontalDragUpdate: enabled
                  ? (d) {
                      setState(() => _drag = _at(d.localPosition, width));
                      _set(_drag!);
                    }
                  : null,
              onHorizontalDragEnd: enabled
                  ? (_) {
                      final v = _drag ?? value;
                      setState(() => _drag = null);
                      _set(v, end: true);
                    }
                  : null,
              onHorizontalDragCancel: () => setState(() => _drag = null),
              child: SizedBox(
                height: widget.height,
                width: width,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: dragging ? 1 : 0),
                  duration: MmMotion.of(context).state,
                  curve: MmMotion.standard,
                  builder: (context, press, _) => _Wave(
                    playing: widget.wavy && widget.playing && !dragging,
                    builder: (phase, amp) => CustomPaint(
                      size: Size.infinite,
                      painter: _SliderPainter(
                        value: value,
                        phase: phase,
                        amplitude: amp * 3.2,
                        active: enabled
                            ? widget.activeColor
                            : widget.activeColor.withValues(alpha: 0.4),
                        inactive: widget.trackColor,
                        stroke: widget.stroke,
                        thumb: _focused ? c.accent : widget.activeColor,
                        // The thumb grows while it is held.
                        thumbHeight: widget.height * (0.62 + 0.18 * press),
                        thumbWidth: 4 + 2 * press,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Step extends Intent {
  const _Step(this.direction);
  final int direction;
}

/// Runs the wave: phase turns while [playing]; the amplitude eases in and out
/// (400 ms) so pausing flattens the line instead of freezing it. Nothing
/// ticks while flat. Reduced motion: always flat.
class _Wave extends StatefulWidget {
  const _Wave({required this.playing, required this.builder});

  final bool playing;
  final Widget Function(double phase, double amplitude) builder;

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with TickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _amp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MmMotion.of(context).reduced;
    _sync(initial: true);
  }

  @override
  void didUpdateWidget(_Wave old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _sync();
  }

  void _sync({bool initial = false}) {
    final on = widget.playing && !_reduced;
    if (on) {
      if (!_phase.isAnimating) _phase.repeat();
      initial ? _amp.value = 1 : _amp.forward();
    } else {
      if (initial || _reduced) {
        _amp.value = 0;
        _phase.stop();
      } else {
        _amp.reverse().whenComplete(() {
          if (mounted && !widget.playing) _phase.stop();
        });
      }
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    _amp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_phase, _amp]),
    builder: (context, _) => widget.builder(
      _phase.value * 2 * math.pi,
      Curves.easeInOut.transform(_amp.value),
    ),
  );
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.value,
    required this.phase,
    required this.amplitude,
    required this.active,
    required this.inactive,
    required this.stroke,
    required this.thumb,
    required this.thumbHeight,
    this.thumbWidth = 4,
  });

  final double value;
  final double phase;
  final double amplitude;
  final Color active;
  final Color inactive;
  final double stroke;
  final Color? thumb;
  final double thumbHeight;
  final double thumbWidth;

  static const _wavelength = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final half = stroke / 2;
    final left = half + 1;
    final right = size.width - half - 1;
    final x = left + (right - left) * value;
    final hasThumb = thumb != null;
    final gap = hasThumb ? thumbWidth / 2 + 5 : 4.0;

    final line = Paint()
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Played part: a wave (or a line when flat), up to the gap.
    final end = x - gap;
    if (end > left) {
      line.color = active;
      if (amplitude < 0.05) {
        canvas.drawLine(Offset(left, mid), Offset(end, mid), line);
      } else {
        final path = Path()..moveTo(left, mid + _y(left));
        for (var px = left + 1; px <= end; px += 1) {
          path.lineTo(px, mid + _y(px));
        }
        canvas.drawPath(path, line);
      }
    }

    // The rest, then the stop dot at the end.
    final start = x + gap;
    if (start < right) {
      line.color = inactive;
      canvas.drawLine(Offset(start, mid), Offset(right, mid), line);
      if (right - start > stroke * 2) {
        canvas.drawCircle(
          Offset(right - half, mid),
          math.max(1.5, half * 0.5),
          Paint()..color = active,
        );
      }
    }

    if (hasThumb) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, mid),
            width: thumbWidth,
            height: thumbHeight,
          ),
          Radius.circular(thumbWidth),
        ),
        Paint()..color = thumb!,
      );
    }
  }

  double _y(double px) =>
      amplitude * math.sin(px / _wavelength * 2 * math.pi - phase);

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.value != value ||
      old.phase != phase ||
      old.amplitude != amplitude ||
      old.active != active ||
      old.inactive != inactive ||
      old.thumb != thumb ||
      old.thumbHeight != thumbHeight ||
      old.thumbWidth != thumbWidth;
}
