import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../playback/audio_route.dart';
import '../playback/equalizer.dart';
import '../playback/playback.dart';
import '../settings/settings_data.dart';

const playbackSpeeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

String speedLabel(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  return '${s.replaceAll('.', ',')}×';
}

String presetLabel(L10n t, EqPreset p) => switch (p) {
  EqPreset.flat => t.eqFlat,
  EqPreset.bass => t.eqBass,
  EqPreset.voice => t.eqVoice,
  EqPreset.rock => t.eqRock,
  EqPreset.classic => t.eqClassic,
  EqPreset.custom => t.eqCustom,
};

/// What the user calls the output the sound goes to.
String _outputName(L10n t, WidgetRef ref, AudioRoute route) =>
    switch (route.kind) {
      AudioRouteKind.speaker => t.outputSpeaker,
      AudioRouteKind.wired => t.outputWired,
      AudioRouteKind.bluetooth =>
        route.name.isEmpty ? t.outputBluetooth : route.name,
      AudioRouteKind.output =>
        route.name == 'auto' || route.name.isEmpty
            ? t.systemDefault
            : (ref
                      .watch(audioOutputsProvider)
                      .value
                      ?.where((o) => o.id == route.name)
                      .firstOrNull
                      ?.label ??
                  route.name),
    };

/// Sound (W-M3 « Son », A-03c): equalizer, speed, normalisation (P1).
class SoundView extends ConsumerWidget {
  const SoundView({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(12, 14, 12, 14),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final eq = ref.watch(equalizerProvider);
    final prefs = ref.watch(playbackPrefsProvider).value;
    final normalizable =
        ref.watch(mediaEngineProvider)?.capabilities.normalization ?? false;
    final eqCtl = ref.read(equalizerProvider.notifier);
    final speed = ref.watch(
      playbackProvider.select((s) => s.value?.speed ?? 1.0),
    );
    final unsupported = eq.supported == false;
    return ListView(
      padding: padding,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.equalizer,
                    style: MmType.heading.copyWith(fontSize: 15, color: c.fg),
                  ),
                  Text(
                    unsupported ? t.equalizerUnsupported : t.equalizerBody,
                    style: MmType.caption.copyWith(color: c.fgSoft),
                  ),
                ],
              ),
            ),
            MmSwitch(
              value: eq.enabled && !unsupported,
              label: t.equalizer,
              onChanged: unsupported ? null : eqCtl.setEnabled,
            ),
          ],
        ),
        if (eq.route case final route?) ...[
          const SizedBox(height: 10),
          // Decision 0013, proposal 9: each output keeps its own setting.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.eqPerOutput,
                      style: MmType.body.copyWith(fontSize: 14, color: c.fg),
                    ),
                    if (eq.perOutput)
                      Text(
                        t.eqSetFor(_outputName(t, ref, route)),
                        style: MmType.caption.copyWith(color: c.fgSoft),
                      ),
                  ],
                ),
              ),
              MmSwitch(
                value: eq.perOutput,
                label: t.eqPerOutput,
                onChanged: eqCtl.setPerOutput,
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Opacity(
          opacity: unsupported ? 0.45 : 1,
          child: IgnorePointer(
            ignoring: unsupported,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in EqPreset.values.where(
                      (p) => p != EqPreset.custom,
                    ))
                      ChoicePill(
                        label: presetLabel(t, p),
                        on: eq.enabled && eq.preset == p,
                        onTap: () => eqCtl.setPreset(p),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 170,
                  child: Row(
                    children: [
                      for (var i = 0; i < eqBands.length; i++)
                        Expanded(
                          child: _EqBand(
                            label: eqBands[i],
                            value: eq.gains[i],
                            active: eq.enabled,
                            onChanged: (db) => eqCtl.setGain(i, db),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          t.speed,
          style: MmType.heading.copyWith(fontSize: 15, color: c.fg),
        ),
        const SizedBox(height: 10),
        Segmented<double>(
          values: playbackSpeeds,
          selected: speed,
          label: speedLabel,
          mono: true,
          onSelected: (v) => ref.read(mediaEngineProvider)?.setSpeed(v),
        ),
        if (normalizable && prefs != null) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.normalization,
                      style: MmType.labelStrong.copyWith(color: c.fg),
                    ),
                    Text(
                      t.normalizationBody,
                      style: MmType.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              MmSwitch(
                value: prefs.engine.normalize,
                label: t.normalization,
                onChanged: (v) => ref
                    .read(playbackPrefsProvider.notifier)
                    .save(
                      prefs.copyWith(
                        engine: withEngine(prefs.engine, normalize: v),
                      ),
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One equalizer band: vertical 4 px track, coral thumb, dB above, Hz below.
class _EqBand extends StatefulWidget {
  const _EqBand({
    required this.label,
    required this.value,
    required this.active,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool active;
  final ValueChanged<double> onChanged;

  @override
  State<_EqBand> createState() => _EqBandState();
}

class _EqBandState extends State<_EqBand> {
  double? _drag;
  bool _focused = false;

  static String _dbText(double db) => db == 0
      ? '0'
      : '${db > 0 ? '+' : ''}${db.toStringAsFixed(db == db.roundToDouble() ? 0 : 1)}';

  double _at(double y, double height) =>
      ((0.5 - y / height) * 2 * eqMaxDb).clamp(-eqMaxDb, eqMaxDb);

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final v = _drag ?? widget.value;
    final db = (v * 2).round() / 2;
    final text = _dbText(db);
    final up = (db + 0.5).clamp(-eqMaxDb, eqMaxDb);
    final down = (db - 0.5).clamp(-eqMaxDb, eqMaxDb);
    return Semantics(
      slider: true,
      label: '${widget.label} Hz',
      value: '$text dB',
      increasedValue: '${_dbText(up)} dB',
      decreasedValue: '${_dbText(down)} dB',
      onIncrease: () => widget.onChanged((db + 0.5).clamp(-eqMaxDb, eqMaxDb)),
      onDecrease: () => widget.onChanged((db - 0.5).clamp(-eqMaxDb, eqMaxDb)),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (f) => setState(() => _focused = f),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): _Nudge(0.5),
          SingleActivator(LogicalKeyboardKey.arrowDown): _Nudge(-0.5),
        },
        actions: {
          _Nudge: CallbackAction<_Nudge>(
            onInvoke: (n) =>
                widget.onChanged((db + n.db).clamp(-eqMaxDb, eqMaxDb)),
          ),
        },
        child: Column(
          children: [
            Text(text, style: MmType.monoStyle(size: 11, color: c.fgSoft)),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (d) => setState(
                    () => _drag = _at(d.localPosition.dy, box.maxHeight),
                  ),
                  onVerticalDragUpdate: (d) => setState(
                    () => _drag = _at(d.localPosition.dy, box.maxHeight),
                  ),
                  onVerticalDragEnd: (_) {
                    final end = _drag;
                    setState(() => _drag = null);
                    if (end != null) widget.onChanged(end);
                  },
                  onTapUp: (d) =>
                      widget.onChanged(_at(d.localPosition.dy, box.maxHeight)),
                  child: CustomPaint(
                    size: Size(box.maxWidth, box.maxHeight),
                    painter: _BandPainter(
                      ratio: 0.5 - v / (2 * eqMaxDb),
                      track: c.line,
                      tick: c.lineStrong,
                      thumb: widget.active ? c.coral : c.muted,
                      focus: _focused ? c.accent : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: MmType.monoStyle(size: 11, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Nudge extends Intent {
  const _Nudge(this.db);
  final double db;
}

class _BandPainter extends CustomPainter {
  _BandPainter({
    required this.ratio,
    required this.track,
    required this.tick,
    required this.thumb,
    this.focus,
  });

  /// 0 = top (+12 dB), 1 = bottom (−12 dB).
  final double ratio;
  final Color track;
  final Color tick;
  final Color thumb;
  final Color? focus;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    const r = 8.0;
    final top = r;
    final bottom = size.height - r;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 2, top, x + 2, bottom),
        const Radius.circular(2),
      ),
      Paint()..color = track,
    );
    final mid = (top + bottom) / 2;
    canvas.drawLine(
      Offset(x - 6, mid),
      Offset(x + 6, mid),
      Paint()
        ..color = tick
        ..strokeWidth = 1,
    );
    final y = top + (bottom - top) * ratio.clamp(0.0, 1.0);
    if (focus != null) {
      canvas.drawCircle(
        Offset(x, y),
        r + 3,
        Paint()
          ..color = focus!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(Offset(x, y), r, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_BandPainter o) =>
      o.ratio != ratio ||
      o.thumb != thumb ||
      o.focus != focus ||
      o.track != track;
}

/// Coral on/off switch of the design (52 × 32).
class MmSwitch extends StatelessWidget {
  const MmSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final motion = MmMotion.of(context);
    return Semantics(
      toggled: value,
      label: label,
      child: Pressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        pressScale: 0.95,
        child: AnimatedContainer(
          duration: motion.state,
          curve: MmMotion.standard,
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? c.coral : c.lineStrong,
            borderRadius: BorderRadius.circular(MmRadius.pill),
          ),
          child: AnimatedAlign(
            duration: motion.state,
            curve: MmMotion.standard,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              // White in both themes, like the mockups' switches.
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded choice chip (presets, filters): coral when selected.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.height = 32,
  });

  final String label;
  final bool on;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      selected: on,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: MmMotion.of(context).state,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? c.coralSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: on ? c.coralChipBorder : c.lineStrong),
        ),
        // widthFactor 1: the pill hugs its label inside a Wrap.
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: MmType.captionStrong.copyWith(
              fontSize: 12.5,
              color: on ? c.coralStrong : c.fgSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control (speed): the selected value sits on a sliding surface.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.mono = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final index = values.indexOf(selected);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(MmRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / values.length;
          return Stack(
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: MmMotion.of(context).dialog,
                  curve: MmMotion.standard,
                  left: index * w,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(MmRadius.pill),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final v in values)
                    Expanded(
                      child: Pressable(
                        onTap: v == selected ? null : () => onSelected(v),
                        selected: v == selected,
                        semanticLabel: label(v),
                        child: Center(
                          child: Text(
                            label(v),
                            style:
                                (mono
                                        ? MmType.monoStyle(
                                            size: 12,
                                            weight: 600,
                                          )
                                        : MmType.captionStrong)
                                    .copyWith(
                                      color: v == selected ? c.fg : c.muted,
                                    ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
