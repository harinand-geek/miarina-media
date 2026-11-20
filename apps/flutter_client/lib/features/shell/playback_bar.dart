import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/play_button.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../engine/media_engine.dart';
import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../now_playing/now_playing_shared.dart';
import '../playback/playback.dart';
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
    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
      decoration: BoxDecoration(
        color: c.playerChrome,
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
    );
  }
}

class _NowPlayingInfo extends ConsumerStatefulWidget {
  const _NowPlayingInfo();

  @override
  ConsumerState<_NowPlayingInfo> createState() => _NowPlayingInfoState();
}

class _NowPlayingInfoState extends ConsumerState<_NowPlayingInfo> {
  final _cover = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final entry = ref.watch(queueProvider.select((q) => q.current));
    final row = AnimatedSwitcher(
      duration: MmMotion.of(context).screen,
      switchInCurve: MmMotion.standard,
      child: Row(
        key: ValueKey(entry?.source.uri),
        children: [
          KeyedSubtree(
            key: _cover,
            child: CoverArt(
              size: 52,
              radius: MmRadius.md,
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
                if (entry?.subtitle != null) ...[
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
        if (entry.isVideo) {
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
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final q = ref.watch(queueProvider);
    final queue = ref.read(queueProvider.notifier);
    final snap = currentSnapshot(ref);
    final hasMedia = q.current != null;
    final repeatLabel = switch (q.repeat) {
      RepeatSetting.off => t.repeatOff,
      RepeatSetting.all => t.repeatAll,
      RepeatSetting.one => t.repeatOne,
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconButton(
              icon: PhosphorRegular.shuffle,
              size: 20,
              label: t.shuffle,
              color: q.shuffle ? c.coralStrong : c.muted,
              selected: q.shuffle,
              onTap: queue.toggleShuffle,
            ),
            const SizedBox(width: 18),
            _IconButton(
              icon: PhosphorFill.skipBack,
              size: 26,
              label: t.previous,
              color: c.fg,
              onTap: hasMedia ? queue.previous : null,
            ),
            const SizedBox(width: 18),
            PlayPauseButton(
              playing: snap.isPlaying,
              onPressed: hasMedia ? queue.togglePlay : null,
              playLabel: t.play,
              pauseLabel: t.pause,
            ),
            const SizedBox(width: 18),
            _IconButton(
              icon: PhosphorFill.skipForward,
              size: 26,
              label: t.next,
              color: c.fg,
              onTap: q.hasNext ? queue.next : null,
            ),
            const SizedBox(width: 18),
            _IconButton(
              icon: q.repeat == RepeatSetting.one
                  ? PhosphorRegular.repeatOnce
                  : PhosphorRegular.repeat,
              size: 20,
              label: repeatLabel,
              color: q.repeat == RepeatSetting.off ? c.muted : c.coralStrong,
              selected: q.repeat != RepeatSetting.off,
              onTap: queue.cycleRepeat,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
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
              child: TrackBar(
                value: ratio,
                fillColor: c.coral,
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
        // The compact always-on-top window (W-M4) comes later; it keeps its
        // place in the bar but is inert and says so.
        Tooltip(
          message: '${t.miniPlayer} · ${t.comingSoonShort}',
          child: Icon(
            PhosphorRegular.pictureInPicture,
            size: 20,
            color: c.faintIcon,
          ),
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
          width: widget.narrow ? 64 : 84,
          child: TrackBar(
            value: volume,
            fillColor: c.fg,
            thumbAlways: false,
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
    this.selected = false,
  });

  final IconData icon;
  final double size;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      selected: selected,
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
