import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/cover_tones.dart';
import '../settings/settings_data.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart' show InterpolatedPosition;
import '../../l10n/app_localizations.dart';
import '../common/state_views.dart';
import '../online/online_obtain.dart' show OnlineObtainChip;
import '../online/online_playback.dart' show playOnlineClip;
import '../playback/equalizer.dart';
import '../playback/playback.dart';
import '../playback/audio_only.dart';
import 'lyrics_view.dart';
import 'mobile_player.dart' show vinylModeProvider;
import 'now_playing_shared.dart';
import 'queue_view.dart';
import 'sound_view.dart';
import 'vinyl_turntable.dart';

enum NowTab { lyrics, queue, sound }

/// Last Listen location before Now playing, for the back pill.
final lastLocationProvider = NotifierProvider<LastLocation, String>(
  LastLocation.new,
);

class LastLocation extends Notifier<String> {
  @override
  String build() => Routes.tracks;

  void set(String location) => state = location;
}

/// W-M3 En lecture (Windows): blurred cover backdrop, 360 px cover, title,
/// chips, and the 420 px panel with Lyrics / Queue / Sound.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.tab = NowTab.lyrics});

  final NowTab tab;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  late NowTab _tab = widget.tab;

  @override
  void didUpdateWidget(NowPlayingScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) _tab = widget.tab;
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final entry = ref.watch(queueProvider.select((q) => q.current));
    final speed = ref.watch(
      playbackProvider.select((s) => s.value?.speed ?? 1.0),
    );
    final eq = ref.watch(equalizerProvider);
    final back = ref.watch(lastLocationProvider);
    final vinyl = ref.watch(vinylModeProvider);
    final snap = currentSnapshot(ref);
    // Expressive redesign (decision 0010): the page takes the cover's
    // colours; Settings › Appearance can still turn the cover ground off.
    final look = ref.watch(appearanceProvider).value;
    final plain =
        (look?.reduceTransparency ?? false) || !(look?.coverBackdrop ?? true);
    final tones = plain
        ? CoverTones.neutral(c)
        : watchCoverTones(ref, context, entry?.artwork);

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedCoverTones(
            tones: tones,
            builder: (context, tones, _) => ColoredBox(color: tones.ground),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 20, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Pressable(
                        onTap: () => context.go(back),
                        semanticLabel: t.back,
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
                          decoration: BoxDecoration(
                            color: c.fg.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(MmRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorRegular.caretLeft,
                                size: 18,
                                color: c.fgSoft,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                entry?.album ?? t.back,
                                style: MmType.label.copyWith(
                                  fontSize: 13,
                                  color: c.fgSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (entry?.isVideo ?? false)
                      Align(
                        alignment: Alignment.topRight,
                        child: Pressable(
                          onTap: () => unawaited(showVideoAgain(context, ref)),
                          semanticLabel: t.showVideo,
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                            decoration: BoxDecoration(
                              color: c.fg.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                MmRadius.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorRegular.monitorPlay,
                                  size: 17,
                                  color: c.fgSoft,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.showVideo,
                                  style: MmType.label.copyWith(
                                    fontSize: 13,
                                    color: c.fgSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (entry == null)
                      Center(
                        child: Text(
                          t.nothingPlaying,
                          style: MmType.title.copyWith(color: c.muted),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, box) {
                          final size = [
                            360.0,
                            box.maxHeight - 250,
                            box.maxWidth - 40,
                          ].reduce((a, b) => a < b ? a : b);
                          // The text column may be wider than the cover so
                          // the chips stay on one line.
                          return Center(
                            child: SizedBox(
                              width: [
                                box.maxWidth - 40,
                                size > 430 ? size : 430.0,
                              ].reduce((a, b) => a < b ? a : b),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // The turntable view of the phone (vinyl
                                  // handoff), switched by the Vinyle chip.
                                  AnimatedSwitcher(
                                    duration: MmMotion.of(context).album,
                                    switchInCurve: MmMotion.spring,
                                    transitionBuilder: (child, anim) =>
                                        FadeTransition(
                                          opacity: anim,
                                          child: ScaleTransition(
                                            scale: Tween(
                                              begin: 0.9,
                                              end: 1.0,
                                            ).animate(anim),
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
                                                  size: size,
                                                  seed: entry.seed,
                                                  imagePath: entry.artwork,
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
                                        : FlyingCover(
                                            key: const ValueKey('cover'),
                                            size: size,
                                            seed: entry.seed,
                                            imagePath: entry.artwork,
                                            radius: 32,
                                            shadow: false,
                                          ),
                                  ),
                                  const SizedBox(height: 26),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: MmType.titleLg.copyWith(
                                                fontSize: 26,
                                                height: 32 / 26,
                                                color: c.fg,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                entry.subtitle,
                                                entry.album,
                                              ].whereType<String>().join(' · '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: MmType.body.copyWith(
                                                fontSize: 14.5,
                                                color: c.fgSoft,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (entry.libraryId != null)
                                        Pressable(
                                          onTap: () =>
                                              toggleCurrentFavorite(ref),
                                          semanticLabel: entry.favorite
                                              ? t.favoriteRemove
                                              : t.favoriteAdd,
                                          tooltip: entry.favorite
                                              ? t.favoriteRemove
                                              : t.favoriteAdd,
                                          pressScale: 0.85,
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: FavoriteHeart(
                                              on: entry.favorite,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      InfoChip(
                                        icon: PhosphorRegular.gauge,
                                        label: speedLabel(speed),
                                        active: speed != 1,
                                        tooltip: t.speed,
                                        onTap: () =>
                                            setState(() => _tab = NowTab.sound),
                                      ),
                                      if (eq.enabled && eq.supported != false)
                                        InfoChip(
                                          icon:
                                              PhosphorRegular.slidersHorizontal,
                                          label: presetLabel(t, eq.preset),
                                          tooltip: t.equalizer,
                                          onTap: () => setState(
                                            () => _tab = NowTab.sound,
                                          ),
                                        ),
                                      const SleepTimerChip(),
                                      InfoChip(
                                        icon: PhosphorRegular.vinylRecord,
                                        label: t.vinylChip,
                                        active: vinyl,
                                        tooltip: vinyl
                                            ? t.showCover
                                            : t.showVinyl,
                                        onTap: ref
                                            .read(vinylModeProvider.notifier)
                                            .toggle,
                                      ),
                                      if (entry.format != null)
                                        InfoChip(
                                          icon: PhosphorRegular.fileAudio,
                                          label: entry.format!,
                                        ),
                                      // Decision 0011: keep it offline,
                                      // or watch its clip from here.
                                      if (entry.onlineId != null)
                                        OnlineObtainChip(entry: entry),
                                      if (entry.onlineId != null &&
                                          !entry.isVideo)
                                        InfoChip(
                                          icon: PhosphorRegular.monitorPlay,
                                          label: t.onlineWatchClip,
                                          onTap: () => playOnlineClip(
                                            context,
                                            ref,
                                            videoId: entry.onlineId!,
                                            title: entry.title,
                                            subtitle: entry.subtitle,
                                            duration: entry.duration,
                                            artwork: entry.artwork,
                                            replace: true,
                                            at: currentSnapshot(ref).position,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 420,
                child: _Panel(
                  tab: _tab,
                  onTab: (v) => setState(() => _tab = v),
                ),
              ),
            ],
          ),
        ),
        // W-E3 when the file stopped with an error.
        const Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: Center(child: PlaybackErrorOverlay()),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.tab, required this.onTab});

  final NowTab tab;
  final ValueChanged<NowTab> onTab;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final labels = {
      NowTab.lyrics: t.lyrics,
      NowTab.queue: t.tabQueue,
      NowTab.sound: t.tabSound,
    };
    return Container(
      decoration: BoxDecoration(
        color: c.brightness == Brightness.dark
            ? const Color(0x8C0D141B)
            : c.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: c.fg.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Segmented<NowTab>(
            values: NowTab.values,
            selected: tab,
            label: (v) => labels[v]!,
            onSelected: onTab,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MmMotion.of(context).screen,
              switchInCurve: MmMotion.standard,
              child: KeyedSubtree(
                key: ValueKey(tab),
                child: switch (tab) {
                  NowTab.lyrics => const LyricsView(),
                  NowTab.queue => const QueueView(),
                  NowTab.sound => const SoundView(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
