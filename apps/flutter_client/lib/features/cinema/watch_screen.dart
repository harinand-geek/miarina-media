import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../common/state_views.dart';
import '../../design/widgets/play_button.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../engine/media_engine.dart';
import '../../l10n/app_localizations.dart';
import '../playback/playback.dart';
import '../shortcuts/keymap.dart';
import 'cinema_data.dart';
import 'video_adjust.dart';

/// Full screen of the video player (W-C4). On Windows it also switches the
/// window to full screen; the desktop shell then shows the player alone.
final videoFullscreenProvider = NotifierProvider<VideoFullscreen, bool>(
  VideoFullscreen.new,
);

class VideoFullscreen extends Notifier<bool> {
  @override
  bool build() => false;

  Window? _window() {
    try {
      return WindowManager.instance.getCurrent();
    } catch (_) {
      return null; // Widget tests and Android: no native window.
    }
  }

  void set(bool value) {
    if (value == state) return;
    state = value;
    if (!ref.read(desktopShellProvider)) return;
    final w = _window();
    if (w != null) w.isFullScreen = value;
  }

  void toggle() => set(!state);
}

enum _Menu { subtitles, audio, speed, video }

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

String speedLabel(double s) =>
    '${s.toStringAsFixed(s == s.roundToDouble() ? 0 : 2).replaceAll(RegExp(r'0$'), '')}×'
        .replaceAll('.', ',');

/// W-C3 windowed video player (Windows, inside the shell, chapters panel on
/// the right) and the Android video page. Space plays / pauses, ←/→ move
/// 10 s, F or a double click switch to full screen, Esc leaves it, C and A
/// open the subtitle and audio menus.
class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({super.key});

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  final _focus = FocusNode(debugLabel: 'video');
  _Menu? _menu;
  bool _controls = true;
  Timer? _hide;

  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _hide?.cancel();
    _focus.dispose();
    // However the player is left (back, sidebar, tab), the resume points and
    // "watched" marks shown by the Cinema screens changed while playing.
    final container = _container;
    Future.microtask(() {
      try {
        container.read(videoFullscreenProvider.notifier).set(false);
        container.invalidate(watchStateProvider);
      } on StateError {
        // The whole app is closing: nothing left to refresh.
      }
    });
    super.dispose();
  }

  bool get _mobile => !ref.read(desktopShellProvider);

  /// Controls hide after 3 s without input in full screen (and on Android
  /// while playing); any movement brings them back.
  void _wake() {
    _hide?.cancel();
    if (!_controls) setState(() => _controls = true);
    final full = ref.read(videoFullscreenProvider) || _mobile;
    if (!full || _menu != null) return;
    _hide = Timer(const Duration(seconds: 3), () {
      final playing = ref.read(mediaEngineProvider)?.current.isPlaying ?? false;
      if (mounted && playing && _menu == null) {
        setState(() => _controls = false);
      }
    });
  }

  void _toggleMenu(_Menu m) {
    setState(() => _menu = _menu == m ? null : m);
    _wake();
  }

  Future<void> _skip(Duration by) async {
    final engine = ref.read(mediaEngineProvider);
    if (engine == null) return;
    final s = engine.current;
    var to = s.position + by;
    if (to < Duration.zero) to = Duration.zero;
    if (s.duration > Duration.zero && to > s.duration) to = s.duration;
    await engine.seek(to);
  }

  void _leave() {
    ref.read(videoFullscreenProvider.notifier).set(false);
    context.canPop() ? context.pop() : context.go(Routes.cinema);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final full = ref.read(videoFullscreenProvider.notifier);
    _wake();
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      if (e is! KeyDownEvent) return KeyEventResult.handled;
      if (_menu != null) {
        setState(() => _menu = null);
      } else if (ref.read(videoFullscreenProvider)) {
        full.set(false);
      } else {
        _leave();
      }
      return KeyEventResult.handled;
    }
    // Keys from Settings › Shortcuts: the player's own first (F, C, A, .),
    // then the global ones it answers itself; the rest goes to the window.
    final map = ref.read(keymapProvider).value ?? const Keymap();
    final action = map.actionFor(e, const {ShortcutScope.video});
    final repeat = e is KeyRepeatEvent;
    switch (action) {
      case ShortcutAction.fullscreen when !repeat:
        full.toggle();
      case ShortcutAction.subtitles when !repeat:
        _toggleMenu(_Menu.subtitles);
      case ShortcutAction.audioTrack when !repeat:
        _toggleMenu(_Menu.audio);
      case ShortcutAction.frameStep:
        ref.read(mediaEngineProvider)?.frameStep();
      case null:
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final engine = ref.watch(mediaEngineProvider);
    final snap = currentSnapshot(ref);
    final queue = ref.watch(queueProvider);
    final full = ref.watch(videoFullscreenProvider);
    final mobile = _mobile;
    final current = queue.current;
    final overlayControls = full || mobile;

    if (snap.status == PlaybackStatus.ended && _controls == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _wake());
    }

    final title = current == null
        ? t.videoUnavailable
        : [
            if (full && current.album != null) current.album!,
            current.title,
          ].join(' · ');

    final adjust = ref.watch(videoAdjustProvider);
    final surface = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_menu != null) {
          setState(() => _menu = null);
        } else if (mobile) {
          _controls ? setState(() => _controls = false) : _wake();
        } else {
          ref.read(queueProvider.notifier).togglePlay();
        }
        _focus.requestFocus();
      },
      onDoubleTap: mobile
          ? null
          : () => ref.read(videoFullscreenProvider.notifier).toggle(),
      child: ColoredBox(
        color: c.video,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (engine != null)
              engine.buildVideoView(
                fit: adjust.fill ? BoxFit.cover : BoxFit.contain,
                aspectRatio: adjust.aspectRatio,
              ),
            if (snap.status == PlaybackStatus.loading || snap.buffering)
              Center(
                child: Text(
                  t.videoLoading,
                  style: MmType.bodySm.copyWith(color: c.muted),
                ),
              ),
            // W-E3: what happened, the file is kept, skip or copy details.
            if (snap.status == PlaybackStatus.error && snap.error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: PlaybackErrorView(error: snap.error!),
                ),
              ),
          ],
        ),
      ),
    );

    final top = Row(
      children: [
        Pressable(
          onTap: _leave,
          semanticLabel: t.back,
          tooltip: t.back,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0x99070B0F),
              shape: BoxShape.circle,
            ),
            child: Icon(PhosphorRegular.arrowLeft, size: 20, color: c.fg),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MmType.heading.copyWith(
              fontWeight: FontWeight.w800,
              color: c.fg,
              shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3)],
            ),
          ),
        ),
      ],
    );

    final controls = _Controls(
      snap: snap,
      menu: _menu,
      full: full,
      overlay: overlayControls,
      onMenu: _toggleMenu,
      onSkip: _skip,
    );

    final menuPanel = _menu == null
        ? null
        : _MenuPanel(
            menu: _menu!,
            snap: snap,
            onClose: () => setState(() => _menu = null),
          );

    Widget player;
    if (overlayControls) {
      player = MouseRegion(
        onHover: (_) => _wake(),
        cursor: _controls ? MouseCursor.defer : SystemMouseCursors.none,
        child: Stack(
          fit: StackFit.expand,
          children: [
            surface,
            IgnorePointer(
              ignoring: !_controls,
              child: AnimatedOpacity(
                opacity: _controls ? 1 : 0,
                duration: MmMotion.of(context).dialog,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xA6070B0F),
                              Color(0x00070B0F),
                              Color(0x00070B0F),
                              Color(0xD9070B0F),
                            ],
                            stops: [0, 0.22, 0.6, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: mobile ? 12 : 24,
                      right: mobile ? 12 : 24,
                      top: mobile ? MediaQuery.paddingOf(context).top + 8 : 18,
                      child: top,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.paddingOf(context).bottom,
                      child: controls,
                    ),
                    if (menuPanel != null)
                      Positioned(
                        right: mobile ? 12 : 24,
                        bottom:
                            (mobile ? 96 : 84) +
                            MediaQuery.paddingOf(context).bottom,
                        child: menuPanel,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      player = Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                surface,
                Positioned(left: 16, right: 16, top: 14, child: top),
                if (menuPanel != null)
                  Positioned(right: 16, bottom: 12, child: menuPanel),
              ],
            ),
          ),
          controls,
        ],
      );
    }

    final wide = !mobile && !full && MediaQuery.sizeOf(context).width >= 1100;
    final body = Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: player),
                const _SidePanel(),
              ],
            )
          : player,
    );
    return ColoredBox(color: c.video, child: body);
  }
}

/// Seek bar and buttons. Windowed: on the player chrome under the video;
/// full screen and Android: over the picture.
class _Controls extends ConsumerWidget {
  const _Controls({
    required this.snap,
    required this.menu,
    required this.full,
    required this.overlay,
    required this.onMenu,
    required this.onSkip,
  });

  final PlaybackSnapshot snap;
  final _Menu? menu;
  final bool full;
  final bool overlay;
  final ValueChanged<_Menu> onMenu;
  final Future<void> Function(Duration) onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final engine = ref.read(mediaEngineProvider);
    final queue = ref.watch(queueProvider);
    final total = snap.duration;
    final mobile = !ref.watch(desktopShellProvider);
    final caps = engine?.capabilities;

    final subtitle = snap.subtitlesEnabled
        ? snap.subtitleTracks
              .where((s) => s.id == snap.selectedSubtitle)
              .firstOrNull
        : null;
    final ccLabel = subtitle == null
        ? null
        : (subtitle.language ?? '').toUpperCase().split(RegExp('[-_]')).first;

    Widget timed(Widget Function(Duration position) build) =>
        InterpolatedPosition(
          position: snap.position,
          duration: total,
          playing: snap.isPlaying && !snap.buffering,
          speed: snap.speed,
          builder: (context, position) => build(position),
        );

    final seekBar = timed(
      (position) => SizedBox(
        height: 18,
        child: TrackBar(
          value: total > Duration.zero
              ? position.inMilliseconds / total.inMilliseconds
              : 0.0,
          fillColor: c.coral,
          semanticLabel: t.seek,
          semanticValue: '${formatClock(position)} / ${formatClock(total)}',
          step: total > Duration.zero ? 10000 / total.inMilliseconds : 0.05,
          onChanged: total > Duration.zero ? (_) {} : null,
          onChangeEnd: total > Duration.zero
              ? (v) => engine?.seek(
                  Duration(milliseconds: (v * total.inMilliseconds).round()),
                )
              : null,
        ),
      ),
    );
    final clock = timed(
      (position) => Text(
        '${formatClock(position)} / ${formatClock(total)}',
        style: MmType.monoStyle(size: 12, color: c.fgSoft),
      ),
    );

    Widget icon(
      IconData glyph,
      String label,
      VoidCallback? onTap, {
      bool active = false,
      Widget? child,
    }) => Pressable(
      onTap: onTap,
      tooltip: label,
      semanticLabel: label,
      selected: active,
      child: Container(
        height: 36,
        constraints: const BoxConstraints(minWidth: 36),
        padding: EdgeInsets.symmetric(horizontal: child == null ? 0 : 10),
        decoration: BoxDecoration(
          color: active ? const Color(0x1FF5F7FA) : Colors.transparent,
          borderRadius: BorderRadius.circular(MmRadius.pill),
        ),
        child: Center(
          widthFactor: child == null ? null : 1,
          child: child ?? Icon(glyph, size: 22, color: c.fgSoft),
        ),
      ),
    );

    final hasNext = queue.hasNext;
    final row = Row(
      children: [
        PlayPauseButton(
          playing: snap.isPlaying,
          size: overlay ? 48 : 40,
          onPressed: () => ref.read(queueProvider.notifier).togglePlay(),
          playLabel: t.play,
          pauseLabel: t.pause,
        ),
        const SizedBox(width: 8),
        icon(
          PhosphorRegular.arrowCounterClockwise,
          t.replay10,
          () => onSkip(const Duration(seconds: -10)),
          child: const _SkipGlyph(back: true),
        ),
        icon(
          PhosphorRegular.arrowClockwise,
          t.forward10,
          () => onSkip(const Duration(seconds: 10)),
          child: const _SkipGlyph(back: false),
        ),
        if (hasNext)
          icon(
            PhosphorFill.skipForward,
            t.nextEpisode,
            () => ref.read(queueProvider.notifier).next(),
          ),
        const SizedBox(width: 8),
        if (!mobile) clock,
        const Spacer(),
        if (caps == null || caps.embeddedSubtitles || caps.externalSubtitles)
          Pressable(
            onTap: () => onMenu(_Menu.subtitles),
            tooltip: '${t.subtitles} (C)',
            semanticLabel: t.subtitles,
            selected: menu == _Menu.subtitles,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: menu == _Menu.subtitles
                    ? const Color(0x1FF5F7FA)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(MmRadius.pill),
                border: Border.all(color: c.lineStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorRegular.subtitles, size: 17, color: c.fgSoft),
                  if (ccLabel != null && ccLabel.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text(
                      ccLabel,
                      style: MmType.captionStrong.copyWith(color: c.fgSoft),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(width: 4),
        if (caps == null || caps.audioTrackSelection)
          icon(
            PhosphorRegular.musicNote,
            '${t.audioTrack} (A)',
            () => onMenu(_Menu.audio),
            active: menu == _Menu.audio,
          ),
        if (caps == null || caps.speed)
          icon(
            PhosphorRegular.gauge,
            t.speed,
            () => onMenu(_Menu.speed),
            active: menu == _Menu.speed,
          ),
        if (caps != null &&
            (caps.abLoop ||
                caps.videoFrame ||
                caps.audioDelay ||
                caps.hardwareDecoding))
          icon(
            PhosphorRegular.slidersHorizontal,
            t.videoSettings,
            () => onMenu(_Menu.video),
            active: menu == _Menu.video,
          ),
        if (!mobile)
          icon(
            full ? PhosphorRegular.cornersIn : PhosphorRegular.cornersOut,
            full ? t.fullscreenExit : t.fullscreen,
            () => ref.read(videoFullscreenProvider.notifier).toggle(),
          ),
      ],
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        seekBar,
        if (mobile)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: clock,
          ),
        const SizedBox(height: 6),
        row,
      ],
    );

    if (overlay) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          mobile ? 16 : 32,
          0,
          mobile ? 12 : 24,
          mobile ? 12 : 20,
        ),
        child: content,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: BoxDecoration(
        color: c.playerChrome,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: content,
    );
  }
}

/// "Reculer / avancer de 10 s" glyph: circular arrow with the number, drawn
/// on the Phosphor grid as docs/icon-system.md describes.
class _SkipGlyph extends StatelessWidget {
  const _SkipGlyph({required this.back});

  final bool back;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            back
                ? PhosphorRegular.arrowCounterClockwise
                : PhosphorRegular.arrowClockwise,
            size: 24,
            color: c.fgSoft,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '10',
              style: MmType.captionStrong.copyWith(
                fontSize: 8.5,
                height: 1,
                color: c.fgSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Menus of W-C4: subtitles, audio track, speed. Only what the engine
/// reports is listed.
class _MenuPanel extends ConsumerWidget {
  const _MenuPanel({
    required this.menu,
    required this.snap,
    required this.onClose,
  });

  final _Menu menu;
  final PlaybackSnapshot snap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final engine = ref.read(mediaEngineProvider);

    Widget row(
      String label, {
      required bool selected,
      required VoidCallback onTap,
      String? detail,
      IconData? icon,
    }) => Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(MmRadius.sm),
      hoverColor: c.cardHover,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(MmRadius.sm),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: selected
                  ? Icon(PhosphorRegular.check, size: 17, color: c.accent)
                  : icon == null
                  ? null
                  : Icon(icon, size: 17, color: c.fgSoft),
            ),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.labelStrong.copyWith(color: c.fg),
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 10),
              Text(detail, style: MmType.monoStyle(size: 11, color: c.muted)),
            ],
          ],
        ),
      ),
    );

    final adjust = ref.watch(videoAdjustProvider);
    final adjustCtl = ref.read(videoAdjustProvider.notifier);
    final caps = engine?.capabilities;

    Widget step(IconData glyph, String label, VoidCallback? onTap) => Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      borderRadius: BorderRadius.circular(MmRadius.pill),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.lineStrong),
        ),
        child: Icon(glyph, size: 16, color: onTap == null ? c.faint : c.fgSoft),
      ),
    );

    // One setting: its value, and either - / + or a tap to change it.
    Widget line(
      String label,
      String value, {
      VoidCallback? onTap,
      VoidCallback? less,
      VoidCallback? more,
      String? lessLabel,
      String? moreLabel,
    }) {
      final body = Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.labelStrong.copyWith(color: c.fg),
              ),
            ),
            if (less != null) ...[
              step(PhosphorRegular.minus, lessLabel ?? label, less),
              const SizedBox(width: 8),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: MmType.monoStyle(size: 12, color: c.fgSoft),
              ),
            ),
            if (more != null) ...[
              const SizedBox(width: 8),
              step(PhosphorRegular.plus, moreLabel ?? label, more),
            ],
          ],
        ),
      );
      if (onTap == null) return Semantics(label: '$label, $value', child: body);
      return Pressable(
        onTap: onTap,
        semanticLabel: '$label, $value',
        borderRadius: BorderRadius.circular(MmRadius.sm),
        hoverColor: c.cardHover,
        child: body,
      );
    }

    String signedMs(int ms) {
      final v = ms / 1000;
      final text = v
          .toStringAsFixed(ms % 100 == 0 ? 1 : 2)
          .replaceAll(
            '.',
            Localizations.localeOf(context).languageCode == 'fr' ? ',' : '.',
          );
      return '${ms > 0 ? '+' : ''}$text s';
    }

    late final String heading;
    final rows = <Widget>[];
    switch (menu) {
      case _Menu.subtitles:
        heading = t.subtitles;
        rows.add(
          row(
            t.subtitlesOff,
            selected: !snap.subtitlesEnabled || snap.selectedSubtitle == null,
            onTap: () => engine?.selectSubtitleTrack(null),
          ),
        );
        for (final s in snap.subtitleTracks) {
          rows.add(
            row(
              [s.title, s.language].whereType<String>().join(' · ').isEmpty
                  ? s.label
                  : [s.title, s.language].whereType<String>().join(' · '),
              detail: s.codec?.toUpperCase(),
              selected: snap.subtitlesEnabled && snap.selectedSubtitle == s.id,
              onTap: () => engine?.selectSubtitleTrack(s.id),
            ),
          );
        }
        if (caps?.subtitleTiming ?? false) {
          rows.add(Divider(height: 14, color: c.line));
          rows.add(
            line(
              t.subtitleDelay,
              signedMs(adjust.subDelayMs),
              less: () => adjustCtl.nudgeSubtitles(-1),
              more: () => adjustCtl.nudgeSubtitles(1),
              lessLabel: t.earlier,
              moreLabel: t.later,
            ),
          );
          rows.add(
            line(
              t.subtitleSize,
              '${(adjust.subScale * 100).round()} %',
              less: () => adjustCtl.stepSubtitleSize(-1),
              more: () => adjustCtl.stepSubtitleSize(1),
              lessLabel: t.smaller,
              moreLabel: t.larger,
            ),
          );
        }
        if (engine?.capabilities.externalSubtitles ?? false) {
          rows.add(Divider(height: 14, color: c.line));
          rows.add(
            row(
              t.subtitlesLoad,
              selected: false,
              icon: PhosphorRegular.filePlus,
              onTap: () async {
                final file = await openFile(
                  acceptedTypeGroups: const [
                    XTypeGroup(
                      label: 'Subtitles',
                      extensions: ['srt', 'vtt', 'ass', 'ssa'],
                    ),
                  ],
                );
                if (file != null) {
                  await engine?.loadExternalSubtitle(Uri.file(file.path));
                }
              },
            ),
          );
        }
      case _Menu.audio:
        heading = t.audioTrack;
        if (snap.audioTracks.length < 2) {
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Text(
                t.noTracks,
                style: MmType.caption.copyWith(color: c.muted),
              ),
            ),
          );
        }
        for (final a in snap.audioTracks) {
          rows.add(
            row(
              [a.title, a.language].whereType<String>().join(' · ').isEmpty
                  ? a.label
                  : [a.title, a.language].whereType<String>().join(' · '),
              detail: a.codec?.toUpperCase(),
              selected: snap.selectedAudio == a.id,
              onTap: () => engine?.selectAudioTrack(a.id),
            ),
          );
        }
      case _Menu.video:
        heading = t.videoSettings;
        final speedIndex = _speeds.indexWhere(
          (s) => (s - snap.speed).abs() < 0.01,
        );
        rows.add(
          line(
            t.speed,
            speedLabel(snap.speed),
            less: speedIndex > 0
                ? () => engine?.setSpeed(_speeds[speedIndex - 1])
                : null,
            more: speedIndex >= 0 && speedIndex < _speeds.length - 1
                ? () => engine?.setSpeed(_speeds[speedIndex + 1])
                : null,
            lessLabel: t.slower,
            moreLabel: t.faster,
          ),
        );
        if (caps?.videoFrame ?? false) {
          final order = [null, ...VideoAdjust.aspects.keys];
          rows.add(
            line(
              t.aspectRatio,
              adjust.aspect ?? t.aspectAuto,
              onTap: () => adjustCtl.setAspect(
                order[(order.indexOf(adjust.aspect) + 1) % order.length],
              ),
            ),
          );
          rows.add(
            line(
              t.cropSetting,
              adjust.fill ? t.cropFill : t.cropNone,
              onTap: () => adjustCtl.setFill(!adjust.fill),
            ),
          );
        }
        if (caps?.audioDelay ?? false) {
          rows.add(
            line(
              t.audioSync,
              '${adjust.audioDelayMs > 0 ? '+' : ''}${adjust.audioDelayMs} ms',
              less: () => adjustCtl.nudgeAudio(-1),
              more: () => adjustCtl.nudgeAudio(1),
              lessLabel: t.earlier,
              moreLabel: t.later,
            ),
          );
        }
        if (caps?.hardwareDecoding ?? false) {
          rows.add(const _DecoderLine());
        }
        if (caps?.abLoop ?? false) {
          final a = adjust.abA;
          final b = adjust.abB;
          rows.add(
            line(
              t.abLoop,
              a == null
                  ? t.abOff
                  : b == null
                  ? t.abFrom(formatClock(a))
                  : '${formatClock(a)} → ${formatClock(b)}',
              onTap: () => adjustCtl.abStep(snap.position),
            ),
          );
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Text(
                a == null
                    ? t.abHintA
                    : b == null
                    ? t.abHintB
                    : t.abHintOff,
                style: MmType.caption.copyWith(color: c.muted),
              ),
            ),
          );
        }
      case _Menu.speed:
        heading = t.speed;
        for (final s in _speeds) {
          rows.add(
            row(
              speedLabel(s),
              selected: (snap.speed - s).abs() < 0.01,
              onTap: () => engine?.setSpeed(s),
            ),
          );
        }
    }

    return TapRegion(
      onTapOutside: (_) => onClose(),
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 420),
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(MmRadius.xl),
          border: Border.all(color: c.overlayBorder),
          boxShadow: MmShadows.floating,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  heading.toUpperCase(),
                  style: MmType.overline.copyWith(color: c.muted),
                ),
              ),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }
}

/// "Décodage matériel": what the engine says decodes the picture now.
class _DecoderLine extends ConsumerWidget {
  const _DecoderLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final engine = ref.read(mediaEngineProvider);
    return FutureBuilder<String?>(
      future: engine?.hardwareDecoder(),
      builder: (context, snap) {
        final decoder = snap.data;
        final value = decoder == null
            ? t.hwSoftware
            : t.hwAuto(decoder.toUpperCase());
        return Semantics(
          label: '${t.hwDecoding}, $value',
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.hwDecoding,
                    style: MmType.labelStrong.copyWith(color: c.fg),
                  ),
                ),
                Text(value, style: MmType.monoStyle(size: 12, color: c.fgSoft)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Right panel of W-C3: chapters (P1, not read yet) and the next episode.
class _SidePanel extends ConsumerWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final queue = ref.watch(queueProvider);
    final next = queue.hasNext && queue.position + 1 < queue.order.length
        ? queue.entries[queue.order[queue.position + 1]]
        : null;
    final engine = ref.read(mediaEngineProvider);
    final readsChapters = engine?.capabilities.chapters ?? false;
    final snap = currentSnapshot(ref);
    final chapters = snap.chapters;
    final current = snap.chapterAt();
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(left: BorderSide(color: c.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.chapters,
                    style: MmType.heading.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.fg,
                    ),
                  ),
                ),
                // P1 where the engine cannot read chapters (handoff rule).
                if (!readsChapters) const _P1Badge(),
              ],
            ),
          ),
          if (chapters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                readsChapters ? t.chaptersNone : t.chaptersSoon,
                style: MmType.caption.copyWith(color: c.muted),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < chapters.length; i++)
                    Pressable(
                      onTap: () => engine?.seek(chapters[i].start),
                      selected: i == current,
                      semanticLabel:
                          chapters[i].title ?? '${t.chapters} ${i + 1}',
                      borderRadius: BorderRadius.circular(10),
                      hoverColor: c.cardHover,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: i == current ? c.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapters[i].title ?? '${t.chapters} ${i + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.labelStrong.copyWith(
                                fontSize: 13,
                                color: i == current ? c.coralStrong : c.fg,
                              ),
                            ),
                            Text(
                              formatClock(chapters[i].start),
                              style: MmType.monoStyle(size: 11, color: c.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (chapters.isEmpty) const Spacer() else const SizedBox(height: 8),
          if (next != null)
            Pressable(
              onTap: () => ref.read(queueProvider.notifier).next(),
              semanticLabel: '${t.nextEpisode} : ${next.title}',
              borderRadius: BorderRadius.circular(MmRadius.md),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(MmRadius.md),
                  border: Border.all(color: c.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.nextEpisode,
                      style: MmType.caption.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.labelStrong.copyWith(color: c.fg),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.autoNext,
                      style: MmType.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "P1" marker of the handoff: visible, disabled, delivered later.
class _P1Badge extends StatelessWidget {
  const _P1Badge();

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: c.warningSubtle,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.warningBorder),
      ),
      child: Text(
        'P1',
        style: MmType.monoStyle(size: 9.5, weight: 700, color: c.warning),
      ),
    );
  }
}
