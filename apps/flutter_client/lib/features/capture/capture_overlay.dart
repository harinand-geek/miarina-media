import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../updates/updates_view.dart' show rootMessengerKey;
import 'capture_data.dart';

/// Above every screen (app root): the zone overlay while a capture is
/// chosen, and the toast after each picture.
class CaptureHost extends ConsumerStatefulWidget {
  const CaptureHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CaptureHost> createState() => _CaptureHostState();
}

class _CaptureHostState extends ConsumerState<CaptureHost> {
  StreamSubscription<CaptureEvent>? _events;

  @override
  void initState() {
    super.initState();
    _events = ref.read(captureProvider.notifier).events.listen(_toast);
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _toast(CaptureEvent e) {
    final messenger = rootMessengerKey.currentState;
    final context = rootMessengerKey.currentContext;
    if (messenger == null || context == null) return;
    final t = L10n.of(context);
    final c = MmColors.of(context);
    final settings =
        ref.read(captureSettingsProvider).value ?? const CaptureSettings();
    late final String text;
    SnackBarAction? action;
    Widget? thumb;
    switch (e) {
      case CaptureFailed():
        text = t.capFailed;
      case CaptureDone(:final result):
        final path = result.path;
        if (path == null) {
          text = t.capCopied;
          action = SnackBarAction(
            label: t.capSave,
            onPressed: () => unawaited(_saveLater(result)),
          );
        } else {
          final name = path.split(Platform.pathSeparator).last;
          text = result.fellBackToPng ? t.capPngFallback(name) : name;
          action = SnackBarAction(
            label: t.capOpen,
            onPressed: () => Process.run('explorer.exe', [path]),
          );
        }
        if (settings.preview) {
          thumb = ClipRRect(
            borderRadius: BorderRadius.circular(MmRadius.sm),
            child: Image.memory(
              result.png,
              width: 64,
              height: 36,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        }
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: action,
          content: Row(
            children: [
              if (thumb != null) ...[thumb, const SizedBox(width: 12)],
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.bodySm.copyWith(color: c.fg),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _saveLater(CaptureResult r) async {
    final settings =
        ref.read(captureSettingsProvider).value ?? const CaptureSettings();
    try {
      final saved = await ref
          .read(captureProvider.notifier)
          .saveCapture(settings, r.png);
      _toast(CaptureDone(saved));
    } catch (_) {
      _toast(const CaptureFailed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureProvider);
    return Stack(
      children: [
        // The screens stay mounted (playback and state go on) under it.
        widget.child,
        if (session != null)
          Positioned.fill(
            // Above the navigator: its own text style and ink.
            child: Material(
              type: MaterialType.transparency,
              child: CaptureOverlay(key: ObjectKey(session), session: session),
            ),
          ),
      ],
    );
  }
}

/// § 2 Superposition de capture: the frozen screen, dimmed outside the
/// zone; drag a new zone or a corner; the action bar under it.
class CaptureOverlay extends ConsumerStatefulWidget {
  const CaptureOverlay({super.key, required this.session});

  final CaptureSession session;

  @override
  ConsumerState<CaptureOverlay> createState() => _CaptureOverlayState();
}

class _CaptureOverlayState extends ConsumerState<CaptureOverlay> {
  Rect? _zone;
  Offset? _anchor;
  bool _dragging = false;
  // Enter and Esc reach the overlay even after a button had the focus.
  final _focus = FocusNode(debugLabel: 'capture-overlay');

  @override
  void initState() {
    super.initState();
    // autofocus gives way to whatever had the focus (« Essayer »…): the
    // overlay takes it, so Enter and Esc reach it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  CaptureController get _capture => ref.read(captureProvider.notifier);

  /// Window points → picture pixels.
  double _scale(Size size) =>
      size.width <= 0 ? 1 : widget.session.image.width / size.width;

  Rect _pixels(Rect zone, Size size) {
    final s = _scale(size);
    return Rect.fromLTRB(
      zone.left * s,
      zone.top * s,
      zone.right * s,
      zone.bottom * s,
    );
  }

  bool get _valid => _zone != null && _zone!.width >= 4 && _zone!.height >= 4;

  void _start(Offset p) {
    _focus.requestFocus();
    final zone = _zone;
    if (zone != null) {
      // A corner: the opposite one stays.
      final corners = [
        (zone.topLeft, zone.bottomRight),
        (zone.topRight, zone.bottomLeft),
        (zone.bottomLeft, zone.topRight),
        (zone.bottomRight, zone.topLeft),
      ];
      for (final (corner, opposite) in corners) {
        if ((corner - p).distance <= 12) {
          setState(() {
            _anchor = opposite;
            _dragging = true;
          });
          return;
        }
      }
    }
    setState(() {
      _anchor = p;
      _zone = Rect.fromPoints(p, p);
      _dragging = true;
    });
  }

  void _move(Offset p, Size size) {
    final a = _anchor;
    if (a == null) return;
    final q = Offset(p.dx.clamp(0, size.width), p.dy.clamp(0, size.height));
    setState(() => _zone = Rect.fromPoints(a, q));
  }

  Rect _whole() => Rect.fromLTWH(
    0,
    0,
    widget.session.image.width.toDouble(),
    widget.session.image.height.toDouble(),
  );

  void _save(Size size) => unawaited(
    _capture.finish(_valid ? _pixels(_zone!, size) : _whole(), save: true),
  );

  KeyEventResult _key(FocusNode _, KeyEvent e, Size size) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(_capture.cancel());
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _save(size);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final zone = _zone;
        final px = zone == null ? null : _pixels(zone, size);
        return Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (node, e) => _key(node, e, size),
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RawImage(
                    image: widget.session.image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _start(d.localPosition),
                    onPanUpdate: (d) => _move(d.localPosition, size),
                    onPanEnd: (_) => setState(() => _dragging = false),
                    child: CustomPaint(
                      painter: _ZonePainter(
                        zone: zone,
                        scrim: c.scrim,
                        accent: c.accent,
                      ),
                    ),
                  ),
                ),
                // Help pill, top centre.
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IgnorePointer(child: _HelpPill(t: t)),
                  ),
                ),
                if (zone != null && px != null && _valid)
                  Positioned(
                    left: zone.left,
                    top: (zone.top - 30).clamp(0, size.height - 24),
                    child: IgnorePointer(
                      child: _Label(
                        '${px.width.round()} × ${px.height.round()}',
                      ),
                    ),
                  ),
                if (zone != null && _valid && !_dragging)
                  _ActionBar(
                    zone: zone,
                    size: size,
                    onWhole: () =>
                        unawaited(_capture.finish(_whole(), save: true)),
                    onFilm: _capture.onFilm == null
                        ? null
                        : () => unawaited(_capture.film(_pixels(zone, size))),
                    onCopy: () => unawaited(
                      _capture.finish(_pixels(zone, size), save: false),
                    ),
                    onSave: () => _save(size),
                    onClose: () => unawaited(_capture.cancel()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZonePainter extends CustomPainter {
  _ZonePainter({required this.zone, required this.scrim, required this.accent});

  final Rect? zone;
  final Color scrim;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    final z = zone;
    final dim = Paint()..color = scrim;
    if (z == null || z.isEmpty) {
      canvas.drawRect(all, dim);
      return;
    }
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(all),
        Path()..addRect(z),
      ),
      dim,
    );
    canvas.drawRect(
      z,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final handle = Paint()..color = accent;
    for (final p in [z.topLeft, z.topRight, z.bottomLeft, z.bottomRight]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 9, height: 9),
          const Radius.circular(2),
        ),
        handle,
      );
    }
  }

  @override
  bool shouldRepaint(_ZonePainter old) =>
      old.zone != zone || old.scrim != scrim || old.accent != accent;
}

class _HelpPill extends StatelessWidget {
  const _HelpPill({required this.t});

  final L10n t;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final style = MmType.caption.copyWith(fontSize: 12.5, color: c.muted);
    Widget key(String k) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MmRadius.xs + 1),
        border: Border.all(color: c.lineStrong),
      ),
      child: Text(
        k,
        style: MmType.monoStyle(size: 11, weight: 600, color: c.fg),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c.sidebar,
        borderRadius: BorderRadius.circular(MmRadius.pill),
        border: Border.all(color: c.overlayBorder),
        boxShadow: MmShadows.menu,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.capHelp, style: style),
          const SizedBox(width: 8),
          key(t.capKeyEnter),
          Text(t.capHelpEnter, style: style),
          const SizedBox(width: 4),
          key(t.capKeyEsc),
          Text(t.capHelpEsc, style: style),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.sidebar,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.overlayBorder),
      ),
      child: Text(
        text,
        style: MmType.monoStyle(size: 11.5, weight: 600, color: c.fg),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.zone,
    required this.size,
    required this.onWhole,
    required this.onFilm,
    required this.onCopy,
    required this.onSave,
    required this.onClose,
  });

  final Rect zone;
  final Size size;
  final VoidCallback onWhole;
  final VoidCallback? onFilm;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback onClose;

  static const _height = 44.0;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    // Under the zone, right-aligned with it; above it when the screen ends.
    var top = zone.bottom + 12;
    if (top + _height > size.height - 8) {
      top = (zone.top - _height - 40).clamp(8, size.height - _height - 8);
    }
    return Positioned(
      top: top,
      right: (size.width - zone.right).clamp(8, size.width),
      child: Container(
        height: _height,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.sidebar,
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: c.overlayBorder),
          boxShadow: MmShadows.menu,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BarButton(
              icon: PhosphorRegular.cornersOut,
              label: t.capWholeScreen,
              onTap: onWhole,
            ),
            if (onFilm != null)
              _BarButton(
                icon: PhosphorRegular.videoCamera,
                iconColor: const Color(0xFFF07070),
                label: t.capFilm,
                onTap: onFilm!,
              ),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: c.line,
            ),
            _BarButton(
              icon: PhosphorRegular.copy,
              label: t.capCopy,
              onTap: onCopy,
            ),
            _BarButton(
              icon: PhosphorRegular.downloadSimple,
              label: t.capSave,
              onTap: onSave,
              primary: true,
            ),
            _BarButton(
              icon: PhosphorRegular.x,
              label: t.capClose,
              onTap: onClose,
              iconOnly: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.primary = false,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool primary;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final fg = primary ? const Color(0xFF062320) : c.fg;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      hoverColor: primary ? null : c.surface,
      borderRadius: BorderRadius.circular(MmRadius.pill),
      child: Container(
        height: 34,
        width: iconOnly ? 34 : null,
        padding: iconOnly ? null : const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: primary ? c.accent : null,
          borderRadius: BorderRadius.circular(MmRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconOnly ? c.muted : iconColor ?? fg),
            if (!iconOnly) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: MmType.caption.copyWith(
                  fontSize: 12.5,
                  fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
