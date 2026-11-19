import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// Thin 4 px bar with a fill and a 12 px thumb (handoff: seek bar and
/// volume). The thumb grows on hover or drag; clicking or dragging anywhere
/// sets the value; arrow keys step it.
class TrackBar extends StatefulWidget {
  const TrackBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    required this.fillColor,
    required this.semanticLabel,
    this.semanticValue,
    this.step = 0.05,
    this.thumbAlways = true,
    this.height = 20,
  });

  /// 0..1.
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color fillColor;
  final String semanticLabel;
  final String? semanticValue;
  final double step;
  final bool thumbAlways;
  final double height;

  @override
  State<TrackBar> createState() => _TrackBarState();
}

class _TrackBarState extends State<TrackBar> {
  bool _hover = false;
  bool _focused = false;
  double? _drag;

  double _at(Offset local, double width) => (local.dx / width).clamp(0.0, 1.0);

  void _set(double v, {bool end = false}) {
    widget.onChanged?.call(v);
    if (end) widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final enabled = widget.onChanged != null;
    final value = (_drag ?? widget.value).clamp(0.0, 1.0);
    final active = (_hover || _drag != null || _focused) && enabled;
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
        onShowHoverHighlight: (v) => setState(() => _hover = v),
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
          builder: (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled
                ? (d) => _set(_at(d.localPosition, box.maxWidth), end: true)
                : null,
            onHorizontalDragStart: enabled
                ? (d) =>
                      setState(() => _drag = _at(d.localPosition, box.maxWidth))
                : null,
            onHorizontalDragUpdate: enabled
                ? (d) {
                    setState(() => _drag = _at(d.localPosition, box.maxWidth));
                    widget.onChanged?.call(_drag!);
                  }
                : null,
            onHorizontalDragEnd: enabled
                ? (_) {
                    final v = _drag;
                    setState(() => _drag = null);
                    if (v != null) widget.onChangeEnd?.call(v);
                  }
                : null,
            child: SizedBox(
              height: widget.height,
              width: box.maxWidth,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: active ? 1 : 0),
                duration: MmMotion.of(context).hover,
                builder: (context, t, _) => CustomPaint(
                  painter: _TrackPainter(
                    value: value,
                    track: c.line,
                    fill: widget.fillColor,
                    thumb: c.fg,
                    focus: _focused ? c.accent : null,
                    thumbRadius: (widget.thumbAlways || active) ? 6 + t : 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends Intent {
  const _Step(this.direction);
  final int direction;
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.value,
    required this.track,
    required this.fill,
    required this.thumb,
    required this.thumbRadius,
    this.focus,
  });

  final double value;
  final Color track;
  final Color fill;
  final Color thumb;
  final Color? focus;
  final double thumbRadius;

  @override
  void paint(Canvas canvas, Size size) {
    const h = 4.0;
    final y = size.height / 2;
    final r = Radius.circular(h / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, y - h / 2, size.width, h), r),
      Paint()..color = track,
    );
    final x = size.width * value;
    if (x > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, y - h / 2, x, h), r),
        Paint()..color = fill,
      );
    }
    if (thumbRadius > 0) {
      final cx = x.clamp(thumbRadius, size.width - thumbRadius);
      if (focus != null) {
        canvas.drawCircle(
          Offset(cx, y),
          thumbRadius + 3,
          Paint()
            ..color = focus!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(
        Offset(cx, y + 1),
        thumbRadius,
        Paint()
          ..color = const Color(0x55000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(Offset(cx, y), thumbRadius, Paint()..color = thumb);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value ||
      old.thumbRadius != thumbRadius ||
      old.fill != fill ||
      old.track != track ||
      old.focus != focus;
}

/// Playback position between two engine events (every 250 ms), advanced
/// every frame from the last known position and the speed, so the bar never
/// jumps (handoff §03, "Progression de lecture").
class InterpolatedPosition extends StatefulWidget {
  const InterpolatedPosition({
    super.key,
    required this.position,
    required this.duration,
    required this.playing,
    required this.speed,
    required this.builder,
  });

  final Duration position;
  final Duration duration;
  final bool playing;
  final double speed;
  final Widget Function(BuildContext context, Duration position) builder;

  @override
  State<InterpolatedPosition> createState() => _InterpolatedPositionState();
}

class _InterpolatedPositionState extends State<InterpolatedPosition>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final Stopwatch _sinceEvent = Stopwatch();
  Duration _base = Duration.zero;
  Duration _shown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _rebase();
    _sync();
  }

  @override
  void didUpdateWidget(InterpolatedPosition old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position ||
        old.playing != widget.playing ||
        old.speed != widget.speed) {
      _rebase();
    }
    _sync();
  }

  void _rebase() {
    _base = widget.position;
    _shown = _base;
    _sinceEvent
      ..reset()
      ..start();
  }

  void _sync() {
    if (widget.playing && !_ticker.isActive) _ticker.start();
    if (!widget.playing && _ticker.isActive) _ticker.stop();
  }

  void _tick(Duration _) {
    final advance = _sinceEvent.elapsed * widget.speed;
    // Never run more than half a second ahead of the engine.
    const cap = Duration(milliseconds: 500);
    var next = _base + (advance > cap ? cap : advance);
    if (widget.duration > Duration.zero && next > widget.duration) {
      next = widget.duration;
    }
    if (next != _shown) setState(() => _shown = next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _shown);
}

String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
