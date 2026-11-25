import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/cover_tones.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/expressive.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../design/widgets/wavy_slider.dart';
import '../../engine/media_engine.dart';
import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../now_playing/now_playing_shared.dart';
import '../mini/mini_player.dart';
import '../online/online_playback.dart'
    show onlineFailureProvider, onlineResolvingProvider;
import '../online/online_widgets.dart' show onlineProblemText;
import '../playback/playback.dart';
import '../playback/audio_only.dart';
import '../shortcuts/global_shortcuts.dart';

/// Windows playback bar (Handoff, shell): 80 px, full width, always visible;
/// grid 320 / 1fr / 320. Below 1024 px the side columns shrink.
class PlaybackBar extends ConsumerWidget {
  const PlaybackBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 1024;
    final side = narrow ? 240.0 : 320.0;
    final artwork = ref.watch(queueProvider.select((q) => q.current?.artwork));
    // Expressive redesign (decision 0010): the bar takes a light tint of the
    // cover; the controls use its colours.
    return AnimatedCoverTones(
      tones: watchCoverTones(ref, context, artwork),
      builder: (context, tones, _) => _BarTones(
        tones: tones,
        child: Container(
          height: 88,
          padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
          decoration: BoxDecoration(
            color: Color.lerp(
              c.playerChrome,
              tones.card,
              c.brightness == Brightness.dark ? 0.35 : 0.45,
            ),
            border: Border(top: BorderSide(color: c.divider)),
          ),
          child: Row(
            children: [
              SizedBox(width: side, child: const _NowPlayingInfo()),
              const Expanded(child: _Transport()),
              SizedBox(
                width: side,
                child: _SideControls(narrow: narrow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current cover's tones for the bar's controls.
class _BarTones extends InheritedWidget {
  const _BarTones({required this.tones, required super.child});

  final CoverTones tones;

  static CoverTones of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BarTones>()!.tones;

  @override
  bool updateShouldNotify(_BarTones old) => old.tones != tones;
}

class _NowPlayingInfo extends ConsumerStatefulWidget {
  const _NowPlayingInfo();

  @override
  ConsumerState<_NowPlayingInfo> createState() => _NowPlayingInfoState();
}

class _NowPlayingInfoState extends ConsumerState<_NowPlayingInfo> {
  // One key per track: while the bar cross-fades from one track to the
  // next, both covers are on screen and a key may only be used once.
  GlobalKey _cover = GlobalKey();
  Uri? _coverOf;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final entry = ref.watch(queueProvider.select((q) => q.current));
    final failure = ref.watch(onlineFailureProvider);
    if (entry?.source.uri != _coverOf) {
      _coverOf = entry?.source.uri;
      _cover = GlobalKey();
    }
    final row = AnimatedSwitcher(
      duration: MmMotion.of(context).screen,
      switchInCurve: MmMotion.standard,
      child: Row(
        key: ValueKey(entry?.source.uri),
        children: [
          KeyedSubtree(
            key: _cover,
            child: CoverArt(
              size: 56,
              radius: 14,
              seed: entry?.seed ?? 0,
              imagePath: entry?.artwork,
              shadow: entry != null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry?.title ?? t.nothingPlaying,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.heading.copyWith(
                    color: entry == null ? c.muted : c.fg,
                  ),
                ),
                if (failure != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    onlineProblemText(t, failure.kind).title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.bodySm.copyWith(
                      fontSize: 12.5,
                      color: c.coralStrong,
                    ),
                  ),
                ] else if (entry?.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry!.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.bodySm.copyWith(
                      fontSize: 12.5,
                      color: c.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (entry == null) return row;
    return Pressable(
      onTap: () {
        if (opensVideoPage(ref, entry)) {
          context.go(Routes.watch);
          return;
        }
        if (entry.focusKey != null) {
          context.go(Routes.focusPlayer);
          return;
        }
        ref.read(coverOriginProvider.notifier).capture(_cover);
        context.go(Routes.now);
      },
      semanticLabel: t.openNowPlaying,
      tooltip: t.openNowPlaying,
      pressScale: 0.98,
      borderRadius: BorderRadius.circular(MmRadius.lg),
      child: row,
    );
  }
}

class _Transport extends ConsumerWidget {
  const _Transport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final tones = _BarTones.of(context);
    final q = ref.watch(queueProvider);
    final queue = ref.read(queueProvider.notifier);
    final snap = currentSnapshot(ref);
    final hasMedia = q.current != null;
    final motion = MmMotion.of(context);
    final repeatLabel = switch (q.repeat) {
      RepeatSetting.off => t.repeatOff,
      RepeatSetting.all => t.repeatAll,
      RepeatSetting.one => t.repeatOne,
    };
    Widget toggle(IconData icon, String label, bool on, VoidCallback onTap) =>
        MorphButton(
          onTap: onTap,
          color: on ? tones.primary : Colors.transparent,
          semanticLabel: label,
          tooltip: label,
          selected: on,
          width: 40,
          height: 36,
          radius: 18,
          pressedRadius: 10,
          child: Icon(
            icon,
            size: 19,
            color: on ? tones.onPrimary : tones.onGround,
          ),
        );
    Widget pill(IconData icon, String label, VoidCallback? onTap) =>
        MorphButton(
          onTap: onTap,
          color: tones.button,
          semanticLabel: label,
          tooltip: label,
          width: 52,
          height: 40,
          radius: 20,
          pressedRadius: 10,
          child: Icon(icon, size: 20, color: tones.onButton),
        );
    final glyph = snap.isPlaying ? PhosphorFill.pause : PhosphorFill.play;
    // An online entry's stream is being found (decision 0011).
    final resolving = ref.watch(onlineResolvingProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            toggle(
              PhosphorRegular.shuffle,
              t.shuffle,
              q.shuffle,
              queue.toggleShuffle,
            ),
            const SizedBox(width: 10),
            pill(
              PhosphorFill.skipBack,
              t.previous,
              hasMedia ? queue.previous : null,
            ),
            const SizedBox(width: 6),
            MorphButton(
              onTap: hasMedia ? queue.togglePlay : null,
              color: tones.primary,
              semanticLabel: snap.isPlaying ? t.pause : t.play,
              tooltip: snap.isPlaying ? t.pause : t.play,
              width: 72,
              height: 44,
              radius: 22,
              pressedRadius: 12,
              child: AnimatedSwitcher(
                duration: motion.reduced
                    ? motion.state
                    : const Duration(milliseconds: 180),
                switchInCurve: MmMotion.spring,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.5, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: resolving
                    ? SizedBox(
                        key: const ValueKey('resolving'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: tones.onPrimary,
                        ),
                      )
                    : Icon(
                        glyph,
                        key: ValueKey(glyph),
                        size: 22,
                        color: tones.onPrimary,
                      ),
              ),
            ),
            const SizedBox(width: 6),
            pill(
              PhosphorFill.skipForward,
              t.next,
              q.hasNext ? queue.next : null,
            ),
            const SizedBox(width: 10),
            toggle(
              q.repeat == RepeatSetting.one
                  ? PhosphorRegular.repeatOnce
                  : PhosphorRegular.repeat,
              repeatLabel,
              q.repeat != RepeatSetting.off,
              queue.cycleRepeat,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _Seek(snap: snap, label: t.seek),
        ),
      ],
    );
  }
}

class _Seek extends ConsumerWidget {
  const _Seek({required this.snap, required this.label});

  final PlaybackSnapshot snap;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final engine = ref.read(mediaEngineProvider);
    final total = snap.duration;
    final uri = ref.watch(queueProvider.select((q) => q.current?.source.uri));
    final time = MmType.monoStyle(color: c.muted);
    return InterpolatedPosition(
      position: snap.position,
      duration: total,
      playing: snap.isPlaying && !snap.buffering,
      speed: snap.speed,
      builder: (context, position) {
        final ratio = total > Duration.zero
            ? position.inMilliseconds / total.inMilliseconds
            : 0.0;
        return Row(
          children: [
            Text(
              formatClock(position),
              maxLines: 1,
              softWrap: false,
              style: time,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ExpressiveSlider(
                value: ratio,
                wavy: true,
                playing: snap.isPlaying && !snap.buffering,
                bpm: uri == null
                    ? null
                    : ref.watch(trackBpmProvider(uri)).value,
                position: position,
                activeColor: _BarTones.of(context).primary,
                trackColor: _BarTones.of(context).track,
                height: 22,
                stroke: 4,
                semanticLabel: label,
                semanticValue:
                    '${formatClock(position)} / ${formatClock(total)}',
                step: total > Duration.zero
                    ? 5000 / total.inMilliseconds
                    : 0.05,
                onChanged: total > Duration.zero ? (_) {} : null,
                onChangeEnd: total > Duration.zero
                    ? (v) => engine?.seek(
                        Duration(
                          milliseconds: (v * total.inMilliseconds).round(),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Text(formatClock(total), maxLines: 1, softWrap: false, style: time),
          ],
        );
      },
    );
  }
}

class _SideControls extends ConsumerStatefulWidget {
  const _SideControls({required this.narrow});

  final bool narrow;

  @override
  ConsumerState<_SideControls> createState() => _SideControlsState();
}

class _SideControlsState extends ConsumerState<_SideControls> {
  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final engine = ref.read(mediaEngineProvider);
    final volume = ref.watch(
      playbackProvider.select((s) => s.value?.volume ?? 1.0),
    );
    final muted = volume <= 0.001;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IconButton(
          icon: PhosphorRegular.quotes,
          size: 20,
          label: t.lyrics,
          color: c.muted,
          onTap: () => context.go('${Routes.now}?tab=lyrics'),
        ),
        const SizedBox(width: 10),
        _IconButton(
          icon: PhosphorRegular.queue,
          size: 20,
          label: t.queue,
          color: c.muted,
          onTap: () => context.go('${Routes.now}?tab=queue'),
        ),
        const SizedBox(width: 10),
        // W-M4: the compact always-on-top window.
        _IconButton(
          icon: PhosphorRegular.pictureInPicture,
          size: 20,
          label: t.miniPlayer,
          color: c.muted,
          onTap: () => ref.read(miniPlayerProvider.notifier).enter(),
        ),
        const SizedBox(width: 14),
        _IconButton(
          icon: muted
              ? PhosphorRegular.speakerSlash
              : PhosphorRegular.speakerHigh,
          size: 20,
          label: muted ? t.unmute : t.mute,
          color: c.muted,
          onTap: () => ref.read(muteProvider.notifier).toggle(),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: widget.narrow ? 70 : 96,
          child: ExpressiveSlider(
            value: volume,
            activeColor: _BarTones.of(context).onGround,
            trackColor: _BarTones.of(context).track,
            height: 28,
            stroke: 6,
            semanticLabel: t.volume,
            onChanged: (v) => engine?.setVolume(v),
          ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.size,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      pressScale: 0.9,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: MmIcon(
          icon,
          size: size,
          color: onTap == null ? c.faintIcon : color,
        ),
      ),
    );
  }
}
