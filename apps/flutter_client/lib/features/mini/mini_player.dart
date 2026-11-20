import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/play_button.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../playback/playback.dart';

/// Client size of the compact window (W-M4): 340 × 120, up to 340 × 340.
const miniSize = Size(340, 120);
const miniMaxSize = Size(340, 340);

/// Height from which the cover goes above the controls.
const miniTallFrom = 220.0;

/// The window the app lives in; tests use a fake.
abstract interface class AppWindow {
  /// Shrinks to the compact window, remembering where the window was.
  Future<void> enterCompact({required bool onTop});

  /// Back to the size, place and state the window had.
  Future<void> leaveCompact();

  Future<void> setOnTop(bool value);
}

/// W-M4 is the main window made compact rather than a second window: a
/// second Flutter window means a second engine (memory) and keeping the
/// player in sync across them, for the same result on screen.
class NativeAppWindow implements AppWindow {
  Rect? _bounds;
  Size? _minimum;
  bool _maximized = false;

  Window? get _window => WindowManager.instance.getCurrent();

  /// Windows' invisible resize borders: sizes given to the window include
  /// them.
  Size _frame(Window w) {
    final outer = w.size.toSize();
    final inner = w.contentSize.toSize();
    return Size(
      (outer.width - inner.width).clamp(0, 64).toDouble(),
      (outer.height - inner.height).clamp(0, 64).toDouble(),
    );
  }

  @override
  Future<void> enterCompact({required bool onTop}) async {
    final w = _window;
    if (w == null) return;
    if (w.isFullScreen) w.isFullScreen = false;
    _maximized = w.isMaximized;
    if (_maximized) w.unmaximize();
    _bounds = w.bounds.toRect();
    _minimum = w.minimumSize.toSize();
    final frame = _frame(w);
    Size outer(Size s) => Size(s.width + frame.width, s.height + frame.height);
    w.minimumSize = outer(miniSize).toNative();
    w.maximumSize = outer(miniMaxSize).toNative();
    w.isMaximizable = false;
    w.setSize(outer(miniSize).toNative(), false);
    w.isAlwaysOnTop = onTop;
  }

  @override
  Future<void> leaveCompact() async {
    final w = _window;
    if (w == null) return;
    w.isAlwaysOnTop = false;
    // 0 = no limit.
    w.maximumSize = Size.zero.toNative();
    w.isMaximizable = true;
    if (_minimum != null) w.minimumSize = _minimum!.toNative();
    if (_bounds != null) w.bounds = _bounds!.toNative();
    if (_maximized) w.maximize();
  }

  @override
  Future<void> setOnTop(bool value) async => _window?.isAlwaysOnTop = value;
}

class _NoWindow implements AppWindow {
  const _NoWindow();

  @override
  Future<void> enterCompact({required bool onTop}) async {}

  @override
  Future<void> leaveCompact() async {}

  @override
  Future<void> setOnTop(bool value) async {}
}

final appWindowProvider = Provider<AppWindow>(
  (_) => Platform.isWindows ? NativeAppWindow() : const _NoWindow(),
);

@immutable
class MiniState {
  const MiniState({this.on = false, this.onTop = true});

  final bool on;

  /// Pinned above the other windows (on by default, as in the mockup).
  final bool onTop;
}

final miniPlayerProvider = NotifierProvider<MiniController, MiniState>(
  MiniController.new,
);

class MiniController extends Notifier<MiniState> {
  @override
  MiniState build() => const MiniState();

  Future<void> toggle() => state.on ? leave() : enter();

  Future<void> enter() async {
    if (state.on) return;
    // The compact layout first, then the window shrinks: the full layout is
    // never squeezed into 340 × 120.
    state = MiniState(on: true, onTop: state.onTop);
    await _guard(
      () => ref.read(appWindowProvider).enterCompact(onTop: state.onTop),
    );
  }

  Future<void> leave() async {
    if (!state.on) return;
    await _guard(() => ref.read(appWindowProvider).leaveCompact());
    state = MiniState(onTop: state.onTop);
  }

  Future<void> setOnTop(bool value) async {
    state = MiniState(on: state.on, onTop: value);
    if (state.on) {
      await _guard(() => ref.read(appWindowProvider).setOnTop(value));
    }
  }

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('window: $e');
    }
  }
}

/// W-M4: the compact window, always on top unless unpinned. Cover 120 on
/// the left; from 220 px high the cover goes above. The whole window
/// drags.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final entry = ref.watch(queueProvider.select((q) => q.current));
    // Drag only: DragToMoveArea also waits for a double click (maximize,
    // off here), which would delay every button by 300 ms.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => WindowManager.instance.getCurrent()?.startDragging(),
      child: Container(
        decoration: BoxDecoration(
          color: c.sidebar,
          border: Border.all(color: c.lineStrong),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final tall = box.maxHeight >= miniTallFrom;
            Widget cover(double width, double height) => CoverArt(
              size: width,
              aspectRatio: width / height,
              radius: 0,
              shadow: false,
              seed: entry?.seed ?? 0,
              imagePath: entry?.artwork,
            );
            if (tall) {
              const controls = 120.0;
              final coverHeight = box.maxHeight - controls;
              return Column(
                children: [
                  cover(box.maxWidth, coverHeight),
                  const SizedBox(height: controls, child: _MiniControls()),
                ],
              );
            }
            final side = box.maxHeight;
            return Row(
              children: [
                cover(side, side),
                const Expanded(child: _MiniControls()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniControls extends ConsumerWidget {
  const _MiniControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final q = ref.watch(queueProvider);
    final queue = ref.read(queueProvider.notifier);
    final mini = ref.watch(miniPlayerProvider);
    final snap = currentSnapshot(ref);
    final entry = q.current;
    final hasMedia = entry != null;

    Widget icon(
      IconData glyph,
      String label,
      VoidCallback? onTap, {
      double size = 22,
      Color? color,
    }) => Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: SizedBox(
          width: size + 10,
          height: size + 10,
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: Icon(glyph, size: size, color: color ?? c.fg),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry?.title ?? t.nothingPlaying,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.labelStrong.copyWith(
                        fontSize: 13.5,
                        color: hasMedia ? c.fg : c.muted,
                      ),
                    ),
                    if (entry?.subtitle != null)
                      Text(
                        entry!.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.caption.copyWith(
                          fontSize: 12,
                          color: c.muted,
                        ),
                      ),
                  ],
                ),
              ),
              icon(
                mini.onTop ? PhosphorFill.pushPin : PhosphorRegular.pushPin,
                mini.onTop ? t.miniUnpin : t.miniPin,
                () =>
                    ref.read(miniPlayerProvider.notifier).setOnTop(!mini.onTop),
                size: 16,
                color: mini.onTop ? c.accent : c.faint,
              ),
              icon(
                PhosphorRegular.arrowsOutSimple,
                t.miniExpand,
                () => ref.read(miniPlayerProvider.notifier).leave(),
                size: 16,
                color: c.faint,
              ),
            ],
          ),
          const Spacer(),
          InterpolatedPosition(
            position: snap.position,
            duration: snap.duration,
            playing: snap.isPlaying && !snap.buffering,
            speed: snap.speed,
            builder: (context, position) {
              final total = snap.duration;
              final ratio = total > Duration.zero
                  ? (position.inMilliseconds / total.inMilliseconds).clamp(
                      0.0,
                      1.0,
                    )
                  : 0.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Semantics(
                      label: t.seek,
                      value: '${formatClock(position)} / ${formatClock(total)}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(MmRadius.pill),
                        child: SizedBox(
                          height: 3,
                          child: Stack(
                            children: [
                              Positioned.fill(child: ColoredBox(color: c.line)),
                              FractionallySizedBox(
                                widthFactor: ratio,
                                heightFactor: 1,
                                alignment: Alignment.centerLeft,
                                child: ColoredBox(color: c.coral),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      icon(
                        PhosphorFill.skipBack,
                        t.previous,
                        hasMedia ? queue.previous : null,
                      ),
                      PlayPauseButton(
                        playing: snap.isPlaying,
                        onPressed: hasMedia ? queue.togglePlay : null,
                        playLabel: t.play,
                        pauseLabel: t.pause,
                        size: 34,
                        glyphSize: 20,
                        halo: false,
                      ),
                      icon(
                        PhosphorFill.skipForward,
                        t.next,
                        q.hasNext ? queue.next : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          formatClock(position),
                          style: MmType.monoStyle(size: 11, color: c.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Previous / Play / Next in the taskbar thumbnail (W-M4), kept in step
/// with the queue; the buttons are drawn by the Windows runner
/// (`windows/runner/taskbar_buttons.cpp`). Watched by the app root on
/// Windows.
final taskbarButtonsProvider = Provider<void>((ref) {
  if (!Platform.isWindows) return;
  const channel = MethodChannel('miarina/taskbar');
  channel.setMethodCallHandler((call) async {
    if (call.method != 'pressed') return;
    final queue = ref.read(queueProvider.notifier);
    switch (call.arguments) {
      case 'previous':
        await queue.previous();
      case 'toggle':
        await queue.togglePlay();
      case 'next':
        await queue.next();
    }
  });
  ref.onDispose(() => channel.setMethodCallHandler(null));
});

/// The state sent to the taskbar buttons, with their tooltips.
Map<String, Object> taskbarState({
  required QueueState queue,
  required bool playing,
  required L10n t,
}) => {
  'enabled': queue.current != null,
  'playing': playing,
  'hasPrevious': queue.current != null,
  'hasNext': queue.hasNext,
  'tips': [t.previous, t.play, t.pause, t.next],
};

/// Sends the taskbar state whenever it changes (not on every position
/// tick). Placed under the localizations by the app.
class TaskbarSync extends ConsumerStatefulWidget {
  const TaskbarSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TaskbarSync> createState() => _TaskbarSyncState();
}

class _TaskbarSyncState extends ConsumerState<TaskbarSync> {
  static const _channel = MethodChannel('miarina/taskbar');
  String? _sent;

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      ref.watch(taskbarButtonsProvider);
      final queue = ref.watch(queueProvider);
      final playing = ref.watch(
        playbackProvider.select((s) => s.value?.isPlaying ?? false),
      );
      final next = taskbarState(
        queue: queue,
        playing: playing,
        t: L10n.of(context),
      );
      final key = next.toString();
      if (key != _sent) {
        _sent = key;
        unawaited(
          _channel.invokeMethod<void>('update', next).catchError((_) {}),
        );
      }
    }
    return widget.child;
  }
}
