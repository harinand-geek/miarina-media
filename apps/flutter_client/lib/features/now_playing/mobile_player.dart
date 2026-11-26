import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/cover_tones.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/action_sheet.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/expressive.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../design/widgets/wavy_slider.dart';
import '../../engine/media_engine.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/screen_control.dart';
import '../common/state_views.dart';
import '../device_media/device_media.dart';
import '../library/library_data.dart';
import '../library/track_info.dart';
import '../online/online_obtain.dart' show obtainOnline;
import '../shell/mobile_shell.dart'
    show
        miniArtistStyle,
        miniCoverKey,
        miniHidden,
        miniTitleKey,
        miniTitleStyle;
import '../playback/audio_only.dart';
import '../playback/equalizer.dart';
import '../playback/playback.dart';
import '../../src/rust/api/library.dart';
import 'lyrics_view.dart';
import 'now_playing_shared.dart';
import 'queue_view.dart';
import 'sound_view.dart';
import 'vinyl_turntable.dart';

/// Cover shown as a turning record instead of the square picture (phone
/// player, « Afficher le vinyle »). Kept for the session.
final vinylModeProvider = NotifierProvider<VinylMode, bool>(VinylMode.new);

class VinylMode extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// A-03 Lecteur audio (Android), expressive redesign (2026-11-25): the page
/// takes the colours of the cover and changes with it; big rounded cover
/// (swipe for next / previous, or the lyrics, or a turning record); waving
/// seek bar; pill transport whose buttons change shape under the finger;
/// media volume; shuffle · repeat and queue · sound in connected pairs. The
/// dots open the other actions. Drag down or system back to collapse.
class MobilePlayer extends ConsumerStatefulWidget {
  const MobilePlayer({super.key});

  @override
  ConsumerState<MobilePlayer> createState() => _MobilePlayerState();
}

class _MobilePlayerState extends ConsumerState<MobilePlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );

  /// Dragged down, the cover leaves the page and flies to the mini
  /// player's cover (bottom left), following the finger both ways; these
  /// are its two ends, in the player's coordinates, taken as the drag
  /// starts. Null: the page moves as one (lyrics, record, no mini player).
  Rect? _coverAtRest;
  Rect? _coverInMini;

  /// The title and artist fly the same way, to the mini player's.
  Rect? _titleAtRest;
  Rect? _titleInMini;
  final _flying = ValueNotifier(false);
  final _stackKey = GlobalKey();
  final _bigCoverKey = GlobalKey();
  final _bigTitleKey = GlobalKey();
  bool _lyrics = false;
  double _swipe = 0;

  /// Where the finger is while seeking (the clock follows it).
  double? _seeking;

  @override
  void dispose() {
    _drag.dispose();
    _flying.dispose();
    // The mini player shows its own cover and title again.
    if (miniHidden.value) miniHidden.value = false;
    super.dispose();
  }

  /// Where the cover is now and where the mini player's is, when the cover
  /// shows (not the lyrics or the record) and the page is at rest.
  void _onDragStart() {
    if (_drag.value > 1) return;
    _coverAtRest = null;
    _coverInMini = null;
    _titleAtRest = null;
    _titleInMini = null;
    if (_lyrics || ref.read(vinylModeProvider)) return;
    if (MmMotion.of(context).reduced) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return;
    Rect? inStack(GlobalKey key, {required bool page}) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return page
          ? box.localToGlobal(Offset.zero, ancestor: stack) & box.size
          : stack.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
    }

    _coverAtRest = inStack(_bigCoverKey, page: true);
    _coverInMini = inStack(miniCoverKey, page: false);
    if (_coverAtRest == null || _coverInMini == null) {
      _coverAtRest = _coverInMini = null;
      return;
    }
    _titleAtRest = inStack(_bigTitleKey, page: true);
    _titleInMini = inStack(miniTitleKey, page: false);
  }

  void _close() {
    if (context.canPop()) context.pop();
  }

  void _onDragEnd(DragEndDetails d, double height) {
    final v = d.primaryVelocity ?? 0;
    // Handoff §03: past 30 % of the height or faster than 800 dp/s.
    if (_drag.value > height * 0.3 || v > 800) {
      if (_coverAtRest == null) {
        _close();
        return;
      }
      // The cover ends its flight in the mini player, then the page goes.
      _drag
          .animateTo(
            height,
            duration: const Duration(milliseconds: 240),
            curve: MmMotion.exit,
          )
          .whenCompleteOrCancel(() {
            if (mounted) _close();
          });
      return;
    }
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 500,
      ratio: 0.9,
    );
    _drag.animateWith(SpringSimulation(spring, _drag.value, 0, v));
  }

  Future<void> _sheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MmColors.of(context).brightness == Brightness.dark
        ? MmColors.of(context).surface
        : MmColors.of(context).bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: MmColors.of(context).faintIcon,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );

  void _sound() =>
      _sheet(const SoundView(padding: EdgeInsets.fromLTRB(20, 16, 20, 24)));

  void _queue() => _sheet(
    const QueueView(
      rowHeight: 60,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 24),
    ),
  );

  Future<void> _seekBy(int seconds) async {
    final engine = ref.read(mediaEngineProvider);
    final snap = ref.read(playbackProvider).value;
    if (engine == null || snap == null) return;
    var to = snap.position + Duration(seconds: seconds);
    if (to < Duration.zero) to = Duration.zero;
    if (snap.duration > Duration.zero && to > snap.duration) to = snap.duration;
    await engine.seek(to);
  }

  /// Album or artist page: the player folds away first.
  void _openGroup(String path, String name) {
    final router = GoRouter.of(context);
    _close();
    router.push(Uri(path: path, queryParameters: {'name': name}).toString());
  }

  Future<LibraryItem?> _item() async {
    final id = ref.read(queueProvider).current?.libraryId;
    return id == null ? null : ref.read(libraryApiProvider).item(id);
  }

  Future<void> _share() async {
    final item = await _item();
    if (item == null) return;
    final ok = await ref
        .read(deviceMediaApiProvider)
        .share(item.path, item.title);
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(L10n.of(context).shareFailed)));
    }
  }

  Future<void> _info() async {
    final item = await _item();
    if (item != null && mounted) await showTrackInfo(context, item);
  }

  void _sleepSheet() {
    final t = L10n.of(context);
    final timer = ref.read(sleepTimerProvider);
    final ctl = ref.read(sleepTimerProvider.notifier);
    showActionSheet(
      context,
      header: SheetHeader(
        leading: const _SheetGlyph(PhosphorRegular.moon),
        title: t.sleepTimer,
      ),
      groups: [
        [
          for (final m in const [15, 30, 45, 60])
            SheetAction(
              icon: PhosphorRegular.timer,
              label: t.sleepMinutes(m),
              onTap: () => ctl.after(Duration(minutes: m)),
            ),
          SheetAction(
            icon: PhosphorRegular.musicNotes,
            label: t.sleepEndOfTrack,
            value: timer.endOfTrack ? '✓' : null,
            onTap: ctl.atEndOfTrack,
          ),
        ],
        if (timer.active)
          [
            SheetAction(
              icon: PhosphorRegular.x,
              label: t.sleepOff,
              onTap: ctl.cancel,
            ),
          ],
      ],
    );
  }

  void _speedSheet() {
    final t = L10n.of(context);
    final current = ref.read(playbackProvider).value?.speed ?? 1.0;
    showActionSheet(
      context,
      header: SheetHeader(
        leading: const _SheetGlyph(PhosphorRegular.gauge),
        title: t.playbackSpeed,
      ),
      groups: [
        [
          for (final v in playbackSpeeds)
            SheetAction(
              icon: v == current
                  ? PhosphorRegular.check
                  : PhosphorRegular.gauge,
              label: speedLabel(v),
              onTap: () => ref.read(mediaEngineProvider)?.setSpeed(v),
            ),
        ],
      ],
    );
  }

  void _more() {
    final t = L10n.of(context);
    final entry = ref.read(queueProvider).current;
    if (entry == null) return;
    final timer = ref.read(sleepTimerProvider);
    final eq = ref.read(equalizerProvider);
    final speed = ref.read(playbackProvider).value?.speed ?? 1.0;
    final vinyl = ref.read(vinylModeProvider);
    final inLibrary = entry.libraryId != null;
    String? sleepValue;
    final until = timer.until;
    if (until != null) {
      sleepValue = t.sleepMinutes(
        until.difference(DateTime.now()).inMinutes + 1,
      );
    } else if (timer.endOfTrack) {
      sleepValue = t.sleepEndOfTrack;
    } else {
      sleepValue = t.off;
    }
    showActionSheet(
      context,
      header: SheetHeader(
        leading: CoverArt(
          size: 64,
          radius: 16,
          seed: entry.seed,
          imagePath: entry.artwork,
          shadow: false,
        ),
        title: entry.title,
        subtitle: entry.subtitle,
      ),
      groups: [
        // Decision 0011: keep an online track for offline listening.
        if (entry.onlineId case final id?)
          [
            SheetAction(
              icon: PhosphorRegular.downloadSimple,
              label: t.tabGet,
              onTap: () => obtainOnline(context, ref, (
                videoId: id,
                title: entry.title,
                thumbnail: entry.artwork,
              )),
            ),
          ],
        if (inLibrary)
          [
            SheetAction(
              icon: entry.favorite ? PhosphorFill.heart : PhosphorRegular.heart,
              label: entry.favorite ? t.favoriteRemove : t.favoriteAdd,
              onTap: () {
                HapticFeedback.lightImpact();
                toggleCurrentFavorite(ref);
              },
            ),
          ],
        [
          SheetAction(
            icon: PhosphorRegular.timer,
            label: t.sleepTimer,
            value: sleepValue,
            onTap: _sleepSheet,
          ),
          SheetAction(
            icon: PhosphorRegular.slidersHorizontal,
            label: t.equalizer,
            value: eq.enabled ? t.on : t.off,
            onTap: _sound,
          ),
          SheetAction(
            icon: PhosphorRegular.gauge,
            label: t.playbackSpeed,
            value: speedLabel(speed),
            onTap: _speedSheet,
          ),
        ],
        [
          SheetAction(
            icon: PhosphorRegular.clockCounterClockwise,
            label: t.skipBack10,
            keepOpen: true,
            onTap: () => unawaited(_seekBy(-10)),
          ),
          SheetAction(
            icon: PhosphorRegular.clockClockwise,
            label: t.skipForward10,
            keepOpen: true,
            onTap: () => unawaited(_seekBy(10)),
          ),
        ],
        [
          SheetAction(
            icon: vinyl ? PhosphorRegular.image : PhosphorRegular.vinylRecord,
            label: vinyl ? t.showCover : t.showVinyl,
            onTap: ref.read(vinylModeProvider.notifier).toggle,
          ),
          if (inLibrary && entry.album != null)
            SheetAction(
              icon: PhosphorRegular.disc,
              label: t.viewAlbum,
              onTap: () => _openGroup(Routes.album, entry.album!),
            ),
          if (inLibrary && entry.subtitle != null)
            SheetAction(
              icon: PhosphorRegular.user,
              label: t.viewArtist,
              onTap: () => _openGroup(Routes.artist, entry.subtitle!),
            ),
        ],
        if (inLibrary)
          [
            SheetAction(
              icon: PhosphorRegular.info,
              label: t.trackInfo,
              onTap: () => unawaited(_info()),
            ),
            SheetAction(
              icon: PhosphorRegular.shareNetwork,
              label: t.share,
              onTap: () => unawaited(_share()),
            ),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(queueProvider.select((q) => q.current));
    final tones = watchCoverTones(ref, context, entry?.artwork);
    final size = MediaQuery.sizeOf(context);
    final dark = MmColors.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _drag,
      builder: (context, child) {
        final dy = _drag.value.clamp(0.0, size.height);
        final progress = (dy / size.height).clamp(0.0, 1.0);
        final from = _coverAtRest, to = _coverInMini;
        final flying = from != null && to != null && progress > 0;
        // Set after this frame: the page's cover and title hide while their
        // copies fly, and so do the mini player's until they land on them.
        final landed = progress >= 1;
        if (_flying.value != flying ||
            miniHidden.value != (flying && !landed)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _flying.value = flying;
            miniHidden.value = flying && !landed;
          });
        }
        // The same widgets in both cases (only their values change), so the
        // page and the drag survive the switch. Flying, the page fades as
        // it sinks and shrinks a little: gone by the time the cover and
        // title reach the mini player.
        final page = Opacity(
          opacity: flying ? (1 - progress / 0.6).clamp(0.0, 1.0) : 1,
          child: Transform.translate(
            offset: Offset(0, flying ? dy * 0.35 : dy),
            child: Transform.scale(
              scale: 1 - progress * (flying ? 0.12 : 0.06),
              alignment: flying ? Alignment.center : Alignment.topCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(progress * 120),
                child: child,
              ),
            ),
          ),
        );
        if (!flying) return Stack(key: _stackKey, children: [page]);
        // Toward the bottom left, a little ahead of the page.
        final t = Curves.easeOutCubic.transform(progress);
        final r = Rect.lerp(from, to, t)!;
        final c = MmColors.of(context);
        final titleFrom = _titleAtRest, titleTo = _titleInMini;
        return Stack(
          key: _stackKey,
          children: [
            page,
            if (!landed)
              Positioned.fromRect(
                rect: r,
                child: IgnorePointer(
                  child: CoverArt(
                    size: r.width,
                    radius: 32 + (14 - 32) * t,
                    seed: entry?.seed ?? 0,
                    imagePath: entry?.artwork,
                    shadow: false,
                  ),
                ),
              ),
            if (!landed && titleFrom != null && titleTo != null)
              Positioned(
                left: titleFrom.left + (titleTo.left - titleFrom.left) * t,
                top: titleFrom.top + (titleTo.top - titleFrom.top) * t,
                width: titleFrom.width + (titleTo.width - titleFrom.width) * t,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle.lerp(
                          _bigTitleStyle(tones.onGround),
                          miniTitleStyle(c),
                          t,
                        ),
                      ),
                      if (entry?.subtitle != null)
                        Text(
                          entry!.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle.lerp(
                            _bigArtistStyle(tones.onGroundSoft),
                            miniArtistStyle(c),
                            t,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      child: GestureDetector(
        onVerticalDragStart: (_) => _onDragStart(),
        onVerticalDragUpdate: (d) =>
            _drag.value = (_drag.value + d.delta.dy).clamp(0.0, size.height),
        onVerticalDragEnd: (d) => _onDragEnd(d, size.height),
        child: AnimatedCoverTones(
          tones: tones,
          builder: (context, tones, _) => AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                (ThemeData.estimateBrightnessForColor(tones.ground) ==
                        Brightness.dark ||
                    dark)
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: Material(
              color: tones.ground,
              child: Stack(
                children: [
                  _body(context, tones),
                  // W-E3 when the file stopped with an error.
                  const Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Center(child: PlaybackErrorOverlay()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CoverTones tones) {
    final t = L10n.of(context);
    final q = ref.watch(queueProvider);
    final queue = ref.read(queueProvider.notifier);
    final entry = q.current;
    final snap = currentSnapshot(ref);
    final motion = MmMotion.of(context);
    final vinyl = ref.watch(vinylModeProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 4),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  DiscButton(
                    icon: PhosphorRegular.caretDown,
                    label: t.closePlayer,
                    onTap: _close,
                    color: tones.button,
                    iconColor: tones.onButton,
                  ),
                  Expanded(
                    child: Center(
                      child: _SleepPill(tones: tones, onTap: _sleepSheet),
                    ),
                  ),
                  if (entry?.isVideo ?? false) ...[
                    DiscButton(
                      icon: PhosphorRegular.monitorPlay,
                      label: t.showVideo,
                      onTap: () => unawaited(showVideoAgain(context, ref)),
                      color: tones.button,
                      iconColor: tones.onButton,
                    ),
                    const SizedBox(width: 8),
                  ],
                  DiscButton(
                    icon: PhosphorRegular.dotsThreeVertical,
                    label: t.moreOptions,
                    onTap: entry == null ? null : _more,
                    color: tones.button,
                    iconColor: tones.onButton,
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // Everything below the cover needs about 400 dp.
                  final cover = math.max(
                    120.0,
                    math.min(box.maxWidth, box.maxHeight - 404),
                  );
                  return Column(
                    children: [
                      const SizedBox(height: 14),
                      SizedBox(
                        height: cover,
                        width: box.maxWidth,
                        child: AnimatedSwitcher(
                          duration: motion.screen,
                          child: _lyrics
                              ? DefaultTextStyle.merge(
                                  key: const ValueKey('lyrics'),
                                  style: TextStyle(color: tones.onGround),
                                  child: const LyricsView(
                                    fontSize: 22,
                                    padding: EdgeInsets.zero,
                                  ),
                                )
                              : _swipeable(
                                  cover,
                                  queue,
                                  Center(
                                    child: AnimatedSwitcher(
                                      duration: motion.album,
                                      switchInCurve: MmMotion.spring,
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(
                                            scale: Tween(
                                              begin: 0.86,
                                              end: 1.0,
                                            ).animate(anim),
                                            child: FadeTransition(
                                              opacity: anim,
                                              child: child,
                                            ),
                                          ),
                                      child: vinyl
                                          ? InterpolatedPosition(
                                              key: const ValueKey('vinyl'),
                                              position: snap.position,
                                              duration: snap.duration,
                                              playing:
                                                  snap.isPlaying &&
                                                  !snap.buffering,
                                              speed: snap.speed,
                                              builder: (context, position) =>
                                                  VinylTurntable(
                                                    size: cover,
                                                    seed: entry?.seed ?? 0,
                                                    imagePath: entry?.artwork,
                                                    playing:
                                                        snap.isPlaying &&
                                                        !snap.buffering,
                                                    progress:
                                                        snap.duration >
                                                            Duration.zero
                                                        ? position.inMilliseconds /
                                                              snap
                                                                  .duration
                                                                  .inMilliseconds
                                                        : 0,
                                                    tones: tones,
                                                  ),
                                            )
                                          : ValueListenableBuilder(
                                              key: const ValueKey('cover'),
                                              valueListenable: _flying,
                                              // Hidden while its copy flies
                                              // to the mini player.
                                              builder: (context, flying, c) =>
                                                  Opacity(
                                                    opacity: flying ? 0 : 1,
                                                    child: c,
                                                  ),
                                              child: KeyedSubtree(
                                                key: _bigCoverKey,
                                                child: FlyingCover(
                                                  size: cover,
                                                  seed: entry?.seed ?? 0,
                                                  imagePath: entry?.artwork,
                                                  radius: 32,
                                                  shadow: false,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const Spacer(),
                      _titleRow(context, tones, entry),
                      const SizedBox(height: 10),
                      _seek(context, tones, snap, entry),
                      const Spacer(),
                      _transport(context, tones, snap, entry, q),
                      const SizedBox(height: 14),
                      _VolumeRow(tones: tones),
                      const SizedBox(height: 12),
                      _tools(context, tones, q),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swipeable(double cover, QueueController queue, Widget child) =>
      GestureDetector(
        key: const ValueKey('cover-swipe'),
        onHorizontalDragUpdate: (d) => setState(() => _swipe += d.delta.dx),
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (_swipe < -cover * 0.25 || v < -600) {
            HapticFeedback.selectionClick();
            queue.next();
          } else if (_swipe > cover * 0.25 || v > 600) {
            HapticFeedback.selectionClick();
            queue.previous();
          }
          setState(() => _swipe = 0);
        },
        child: AnimatedSlide(
          offset: Offset(_swipe / (cover == 0 ? 1 : cover), 0),
          duration: _swipe == 0 ? MmMotion.of(context).album : Duration.zero,
          curve: MmMotion.spring,
          child: AnimatedRotation(
            turns: _swipe / (cover == 0 ? 1 : cover) * 0.03,
            duration: _swipe == 0 ? MmMotion.of(context).album : Duration.zero,
            curve: MmMotion.spring,
            child: child,
          ),
        ),
      );

  static TextStyle _bigTitleStyle(Color color) => MmType.titleLg.copyWith(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation.weight(600)],
    color: color,
  );

  static TextStyle _bigArtistStyle(Color color) =>
      MmType.body.copyWith(fontSize: 18, height: 1.35, color: color);

  Widget _titleRow(BuildContext context, CoverTones tones, QueueEntry? entry) {
    final t = L10n.of(context);
    return Row(
      children: [
        Expanded(
          // Hidden while its copy flies to the mini player.
          child: ValueListenableBuilder(
            valueListenable: _flying,
            builder: (context, flying, c) =>
                Opacity(opacity: flying ? 0 : 1, child: c),
            child: Column(
              key: _bigTitleKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarqueeText(
                  entry?.title ?? t.nothingPlaying,
                  style: _bigTitleStyle(tones.onGround),
                ),
                if (entry?.subtitle != null)
                  Text(
                    entry!.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bigArtistStyle(tones.onGroundSoft),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (entry?.libraryId != null) ...[
          Pressable(
            onTap: () {
              HapticFeedback.lightImpact();
              toggleCurrentFavorite(ref);
            },
            semanticLabel: entry!.favorite ? t.favoriteRemove : t.favoriteAdd,
            pressScale: 0.85,
            child: SizedBox(
              width: 48,
              height: 52,
              child: Center(
                child: FavoriteHeart(
                  on: entry.favorite,
                  size: 26,
                  color: tones.onGround,
                  activeColor: tones.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        DiscButton(
          icon: _lyrics
              ? PhosphorRegular.image
              : PhosphorRegular.microphoneStage,
          label: _lyrics ? t.showCover : t.showLyrics,
          onTap: () => setState(() => _lyrics = !_lyrics),
          color: _lyrics ? tones.primary : tones.button,
          iconColor: _lyrics ? tones.onPrimary : tones.onButton,
          size: 56,
        ),
      ],
    );
  }

  Widget _seek(
    BuildContext context,
    CoverTones tones,
    PlaybackSnapshot snap,
    QueueEntry? entry,
  ) {
    final t = L10n.of(context);
    return InterpolatedPosition(
      position: snap.position,
      duration: snap.duration,
      playing: snap.isPlaying && !snap.buffering,
      speed: snap.speed,
      builder: (context, position) {
        final total = snap.duration;
        final ratio = total > Duration.zero
            ? position.inMilliseconds / total.inMilliseconds
            : 0.0;
        final shown = _seeking == null
            ? position
            : Duration(
                milliseconds: (_seeking! * total.inMilliseconds).round(),
              );
        final clock = MmType.monoStyle(size: 13, color: tones.onGroundSoft);
        return Column(
          children: [
            ExpressiveSlider(
              value: ratio,
              wavy: true,
              playing: snap.isPlaying && !snap.buffering,
              bpm: entry == null
                  ? null
                  : ref.watch(trackBpmProvider(entry.source.uri)).value,
              position: position,
              activeColor: tones.primary,
              trackColor: tones.track,
              semanticLabel: t.seek,
              semanticValue: '${formatClock(position)} / ${formatClock(total)}',
              onChanged: total > Duration.zero
                  ? (v) => setState(() => _seeking = v)
                  : null,
              onChangeEnd: total > Duration.zero
                  ? (v) {
                      setState(() => _seeking = null);
                      ref
                          .read(mediaEngineProvider)
                          ?.seek(
                            Duration(
                              milliseconds: (v * total.inMilliseconds).round(),
                            ),
                          );
                    }
                  : null,
            ),
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  Text(formatClock(shown), style: clock),
                  const Spacer(),
                  if (entry?.format != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tones.track,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry!.format!,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 13,
                          letterSpacing: 0.6,
                          color: tones.onGround,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    total > Duration.zero
                        ? '-${formatClock(total - shown)}'
                        : '',
                    style: clock,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _transport(
    BuildContext context,
    CoverTones tones,
    PlaybackSnapshot snap,
    QueueEntry? entry,
    QueueState q,
  ) {
    final t = L10n.of(context);
    final queue = ref.read(queueProvider.notifier);
    final motion = MmMotion.of(context);
    final glyph = snap.isPlaying ? PhosphorFill.pause : PhosphorFill.play;
    return SizedBox(
      height: 80,
      child: MorphGroup(
        weights: const [1, 1.65, 1],
        spacing: 10,
        builder: (context, i, held) => switch (i) {
          0 => MorphButton(
            onTap: entry == null ? null : queue.previous,
            onHeld: held,
            color: tones.button,
            semanticLabel: t.previous,
            tooltip: t.previous,
            height: 80,
            radius: 32,
            child: Icon(PhosphorFill.skipBack, size: 30, color: tones.onButton),
          ),
          1 => MorphButton(
            onTap: entry == null ? null : queue.togglePlay,
            onHeld: held,
            color: tones.primary,
            semanticLabel: snap.isPlaying ? t.pause : t.play,
            tooltip: snap.isPlaying ? t.pause : t.play,
            height: 80,
            radius: 40,
            pressedRadius: 20,
            child: AnimatedSwitcher(
              duration: motion.reduced
                  ? motion.state
                  : const Duration(milliseconds: 200),
              switchInCurve: MmMotion.spring,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.5, end: 1.0).animate(anim),
                  child: RotationTransition(
                    turns: Tween(begin: -0.08, end: 0.0).animate(anim),
                    child: child,
                  ),
                ),
              ),
              child: Icon(
                glyph,
                key: ValueKey(glyph),
                size: 36,
                color: tones.onPrimary,
              ),
            ),
          ),
          _ => MorphButton(
            onTap: q.hasNext ? queue.next : null,
            onHeld: held,
            color: tones.button,
            semanticLabel: t.next,
            tooltip: t.next,
            height: 80,
            radius: 32,
            child: Icon(
              PhosphorFill.skipForward,
              size: 30,
              color: tones.onButton,
            ),
          ),
        },
      ),
    );
  }

  Widget _tools(BuildContext context, CoverTones tones, QueueState q) {
    final t = L10n.of(context);
    final queue = ref.read(queueProvider.notifier);
    final repeatOn = q.repeat != RepeatSetting.off;
    Widget pair(List<(IconData, String, VoidCallback, bool)> items) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          MorphButton(
            onTap: () {
              HapticFeedback.selectionClick();
              items[i].$3();
            },
            color: items[i].$4 ? tones.primary : tones.button,
            semanticLabel: items[i].$2,
            tooltip: items[i].$2,
            selected: items[i].$4,
            width: 64,
            height: 56,
            pressedRadius: 12,
            shape: BorderRadius.horizontal(
              left: Radius.circular(i == 0 ? 28 : 8),
              right: Radius.circular(i == items.length - 1 ? 28 : 8),
            ),
            child: Icon(
              items[i].$1,
              size: 24,
              color: items[i].$4 ? tones.onPrimary : tones.onButton,
            ),
          ),
        ],
      ],
    );
    return Row(
      children: [
        pair([
          (PhosphorRegular.shuffle, t.shuffle, queue.toggleShuffle, q.shuffle),
          (
            q.repeat == RepeatSetting.one
                ? PhosphorRegular.repeatOnce
                : PhosphorRegular.repeat,
            switch (q.repeat) {
              RepeatSetting.off => t.repeatOff,
              RepeatSetting.all => t.repeatAll,
              RepeatSetting.one => t.repeatOne,
            },
            queue.cycleRepeat,
            repeatOn,
          ),
        ]),
        const Spacer(),
        pair([
          (PhosphorRegular.queue, t.queue, _queue, false),
          (
            PhosphorRegular.slidersHorizontal,
            t.tabSound,
            _sound,
            ref.watch(equalizerProvider.select((e) => e.enabled)),
          ),
        ]),
      ],
    );
  }
}

/// Media volume of the phone (the system's music stream, so the buttons and
/// the slider agree); the engine's own volume where there is no phone.
class _VolumeRow extends ConsumerStatefulWidget {
  const _VolumeRow({required this.tones});

  final CoverTones tones;

  @override
  ConsumerState<_VolumeRow> createState() => _VolumeRowState();
}

class _VolumeRowState extends ConsumerState<_VolumeRow> {
  double? _system;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    final control = ref.read(screenControlProvider);
    if (control != null) {
      unawaited(
        control.volume().then((v) {
          if (mounted) setState(() => _system = v);
        }),
      );
      _sub = control.volumeChanges.listen((v) {
        if (mounted) setState(() => _system = v);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final tones = widget.tones;
    final control = ref.read(screenControlProvider);
    final engine = ref.read(mediaEngineProvider);
    final value = control != null
        ? (_system ?? 0.5)
        : ref.watch(playbackProvider.select((s) => s.value?.volume ?? 1.0));
    void set(double v) {
      if (control != null) {
        setState(() => _system = v);
        unawaited(control.setVolume(v));
      } else {
        unawaited(engine?.setVolume(v));
      }
    }

    return Row(
      children: [
        Icon(PhosphorFill.speakerSimpleLow, size: 22, color: tones.onGround),
        const SizedBox(width: 8),
        Expanded(
          child: ExpressiveSlider(
            value: value,
            activeColor: tones.onGround,
            trackColor: tones.track,
            semanticLabel: t.volume,
            height: 40,
            stroke: 12,
            step: 1 / 15,
            onChanged: set,
          ),
        ),
        const SizedBox(width: 8),
        Icon(PhosphorFill.speakerSimpleHigh, size: 22, color: tones.onGround),
      ],
    );
  }
}

/// "Arrêt dans 12 min" under the top bar while the sleep timer runs.
class _SleepPill extends ConsumerStatefulWidget {
  const _SleepPill({required this.tones, required this.onTap});

  final CoverTones tones;
  final VoidCallback onTap;

  @override
  ConsumerState<_SleepPill> createState() => _SleepPillState();
}

class _SleepPillState extends ConsumerState<_SleepPill> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final timer = ref.watch(sleepTimerProvider);
    final until = timer.until;
    _tick?.cancel();
    if (until != null) {
      _tick = Timer(const Duration(seconds: 15), () {
        if (mounted) setState(() {});
      });
    }
    final label = until != null
        ? t.sleepRemaining(
            t.sleepMinutes(until.difference(DateTime.now()).inMinutes + 1),
          )
        : (timer.endOfTrack ? t.sleepEndOfTrack : null);
    return AnimatedSwitcher(
      duration: MmMotion.of(context).screen,
      child: label == null
          ? const SizedBox.shrink()
          : Pressable(
              key: const ValueKey('sleep'),
              onTap: widget.onTap,
              semanticLabel: label,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: widget.tones.button,
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorFill.moon,
                      size: 16,
                      color: widget.tones.onButton,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 13,
                          color: widget.tones.onButton,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SheetGlyph extends StatelessWidget {
  const _SheetGlyph(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: c.coralSubtle,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 28, color: c.coralStrong),
    );
  }
}

/// Opening from the mini player: the sheet rises in 320 ms (fade 120 ms
/// when motion is reduced).
class PlayerPage extends CustomTransitionPage<void> {
  PlayerPage({super.key})
    : super(
        child: const MobilePlayer(),
        opaque: false,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: MmMotion.standard,
            reverseCurve: MmMotion.exit,
          );
          if (MmMotion.of(context).reduced) {
            return FadeTransition(opacity: curved, child: child);
          }
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
}
