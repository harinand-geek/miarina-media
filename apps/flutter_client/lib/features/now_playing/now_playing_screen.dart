import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../playback/equalizer.dart';
import '../playback/playback.dart';
import 'lyrics_view.dart';
import 'now_playing_shared.dart';
import 'queue_view.dart';
import 'sound_view.dart';

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

    return Stack(
      children: [
        Positioned.fill(
          child: CoverBackdrop(
            seed: entry?.seed ?? 0,
            imagePath: entry?.artwork,
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
                          return Center(
                            child: SizedBox(
                              width: size,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FlyingCover(
                                    size: size,
                                    seed: entry.seed,
                                    imagePath: entry.artwork,
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
                                      if (entry.format != null)
                                        InfoChip(
                                          icon: PhosphorRegular.fileAudio,
                                          label: entry.format!,
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
        color: const Color(0x8C0D141B),
        borderRadius: BorderRadius.circular(MmRadius.sheet),
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
