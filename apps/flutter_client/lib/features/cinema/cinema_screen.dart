import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/states.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/cinema.dart';
import '../common/state_views.dart';
import '../import/import_data.dart';
import '../search/search_screen.dart' show SearchButton;
import '../playback/playback.dart';
import 'cinema_data.dart';
import 'cinema_widgets.dart';
import 'video_menu.dart';

enum CinemaFilter { all, films, series }

enum CinemaSort { title, added }

/// Opens the player screen once a video was started (W-C3 / A-04).
void openPlayer(BuildContext context) => context.push(Routes.watch);

void openSeries(BuildContext context, WidgetRef ref, String name) {
  final uri = Uri(path: Routes.series, queryParameters: {'name': name});
  ref.read(desktopShellProvider)
      ? context.go(uri.toString())
      : context.push(uri.toString());
}

String episodeTitle(L10n t, CinemaItem e) => e.episode == null
    ? (e.episodeTitle ?? e.item.title)
    : t.episodeLabel(e.episode!, e.episodeTitle ?? t.episodeNumber(e.episode!));

/// Subtitle line of a "Reprendre" tile.
String resumeLine(L10n t, CinemaItem v, Duration at) {
  final when = t.resumeAtShort(formatClock(at));
  return switch (v.kind) {
    CinemaKind.episode => [
      if (v.episodeTitle != null) v.episodeTitle!,
      when,
    ].join(' · '),
    CinemaKind.film => '${t.kindFilm} · $when',
    CinemaKind.personal => '${t.kindPersonal} · $when',
  };
}

/// Plays [v]; an episode plays with the rest of its series queued after it.
/// [fromStart] ignores its resume point.
Future<void> playVideo(
  WidgetRef ref,
  L10n t,
  CinemaItem v, {
  bool fromStart = false,
}) async {
  String label(CinemaItem e) => episodeTitle(t, e);
  final name = v.series;
  if (v.kind == CinemaKind.episode && name != null) {
    final s = await ref.read(seriesProvider(name).future);
    final i = s?.episodes.indexWhere((e) => e.item.id == v.item.id) ?? -1;
    if (s != null && i >= 0) {
      return playVideos(
        ref.read(queueProvider.notifier),
        s.episodes,
        start: i,
        fromStart: fromStart,
        label: label,
      );
    }
  }
  await playVideos(
    ref.read(queueProvider.notifier),
    [v],
    fromStart: fromStart,
    label: label,
  );
}

String resumeTitle(L10n t, CinemaItem v) =>
    v.kind == CinemaKind.episode && v.season != null && v.episode != null
    ? '${v.series} · ${t.episodeShort(v.season!, v.episode!)}'
    : v.item.title;

/// W-C1 Films & séries (Windows) and the Android Cinema tab (A-C).
class CinemaScreen extends ConsumerStatefulWidget {
  const CinemaScreen({super.key});

  @override
  ConsumerState<CinemaScreen> createState() => _CinemaScreenState();
}

class _CinemaScreenState extends ConsumerState<CinemaScreen> {
  CinemaFilter _filter = CinemaFilter.all;
  CinemaSort _sort = CinemaSort.title;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final lib = ref.watch(cinemaLibraryProvider);
    final resume = ref.watch(cinemaResumeProvider).value ?? const [];
    final watch = ref.watch(watchStateProvider).value ?? const WatchState();
    final data = lib.value;

    final filters = [
      (CinemaFilter.all, t.segAll),
      (CinemaFilter.films, t.segFilms),
      (CinemaFilter.series, t.segSeries),
    ];

    Widget header;
    if (mobile) {
      header = Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.tabCinema,
                style: MmType.display.copyWith(color: c.fg),
              ),
            ),
            const SearchButton(),
          ],
        ),
      );
    } else {
      header = Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.navMovies,
                    style: MmType.display.copyWith(color: c.fg),
                  ),
                  const SizedBox(height: 2),
                  if (data != null)
                    Text(
                      '${t.filmsCount(data.films.length)} · '
                      '${t.seriesCount(data.series.length)}',
                      style: MmType.bodySm.copyWith(color: c.muted),
                    ),
                ],
              ),
            ),
            PillSegment(
              values: filters,
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            const SizedBox(width: 12),
            PillMenu(
              icon: PhosphorRegular.sortAscending,
              tooltip: t.sortBy,
              values: [
                (CinemaSort.title, t.sortTitle),
                (CinemaSort.added, t.sortAdded),
              ],
              selected: _sort,
              onChanged: (s) => setState(() => _sort = s),
            ),
          ],
        ),
      );
    }

    Widget body;
    if (lib.hasError) {
      body = LibraryErrorView(
        error: lib.error!,
        onRetry: () => ref.invalidate(cinemaLibraryProvider),
      );
    } else if (data == null) {
      body = SkeletonGrid(
        aspectRatio: 2 / 3,
        minTile: 128,
        padding: mobile ? 20 : 32,
      );
    } else if (data.films.isEmpty && data.series.isEmpty) {
      body = LibraryEmpty(
        icon: PhosphorRegular.filmSlate,
        title: t.cinemaEmptyTitle,
        body: t.cinemaEmptyBody,
        folderKind: FolderKind.video,
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) =>
            _content(context, data, resume, watch, box.maxWidth, mobile),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (mobile) ...[
          ChoiceChips(
            values: filters,
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 14),
        ],
        Expanded(child: body),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    CinemaLibrary data,
    List<CinemaItem> resume,
    WatchState watch,
    double width,
    bool mobile,
  ) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final pad = mobile ? 20.0 : 32.0;
    final inner = width - pad * 2;

    final shownResume = resume
        .where(
          (v) => switch (_filter) {
            CinemaFilter.all => v.kind != CinemaKind.personal,
            CinemaFilter.films => v.kind == CinemaKind.film,
            CinemaFilter.series => v.kind == CinemaKind.episode,
          },
        )
        .toList();

    final series = [...data.series];
    final films = [...data.films];
    if (_sort == CinemaSort.added) {
      series.sort((a, b) => b.latestAdded.compareTo(a.latestAdded));
      films.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    final showSeries = _filter != CinemaFilter.films && series.isNotEmpty;
    final showFilms = _filter != CinemaFilter.series && films.isNotEmpty;

    // Posters 2:3: six columns at 1280 (at least 120 px), three on phones.
    const gap = 16.0;
    final cols = mobile
        ? 3
        : math.max(3, ((inner + gap) / (128 + gap)).floor()).clamp(3, 8);
    final mGap = mobile ? 12.0 : gap;
    final poster = (inner - mGap * (cols - 1)) / cols;
    // Picture, 8 px gap, title (20) and one caption line (18).
    final posterExtent = poster * 1.5 + 8 + 20 + 18;

    Widget resumeRow() {
      if (mobile) {
        return SizedBox(
          height: 135 + 8 + 20 + 18,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: shownResume.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _resumeTile(context, shownResume[i], watch, 240),
          ),
        );
      }
      final tile = (inner - gap * 2) / 3;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: tile,
                child: i < shownResume.length
                    ? _resumeTile(context, shownResume[i], watch, tile)
                    : null,
              ),
            ],
          ],
        ),
      );
    }

    SliverGrid grid(int count, Widget Function(int i) build) => SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: mGap,
        mainAxisSpacing: 18,
        mainAxisExtent: posterExtent,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) => build(i),
        childCount: count,
      ),
    );

    Widget section(String title) => Padding(
      padding: EdgeInsets.fromLTRB(pad, 22, pad, 12),
      child: SectionHeader(title),
    );

    return CustomScrollView(
      slivers: [
        if (shownResume.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
              child: SectionHeader(t.homeResume),
            ),
          ),
          SliverToBoxAdapter(child: resumeRow()),
        ],
        if (showSeries) ...[
          SliverToBoxAdapter(child: section(t.segSeries)),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: grid(series.length, (i) {
              final s = series[i];
              return VideoTile(
                width: poster,
                aspectRatio: 2 / 3,
                title: s.name,
                subtitle: t.seasonsCount(math.max(1, s.seasons)),
                imagePath: s.poster ?? s.thumbnail,
                seed: s.name.hashCode,
                onTap: () => openSeries(context, ref, s.name),
              );
            }),
          ),
        ],
        if (showFilms) ...[
          SliverToBoxAdapter(child: section(t.segFilms)),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            sliver: grid(films.length, (i) {
              final f = films[i];
              Future<void> playFilm(int i) async {
                await playVideos(
                  ref.read(queueProvider.notifier),
                  films,
                  start: i,
                );
                if (context.mounted) openPlayer(context);
              }

              return VideoTile(
                width: poster,
                aspectRatio: 2 / 3,
                title: f.item.title,
                subtitle: [
                  f.year?.toString(),
                  if (durationOf(f) != null)
                    t.minutesShort(durationOf(f)!.inMinutes),
                ].whereType<String>().join(' · '),
                imagePath: f.poster ?? f.item.thumbnail,
                seed: f.item.title.hashCode,
                progress: progressOf(f, watch),
                dimmed: f.item.missing,
                onTap: () => playFilm(i),
                onMenu: (at) => showVideoMenu(
                  context,
                  ref,
                  f,
                  at,
                  seen: watch.isSeen(f.item.id),
                  onPlay: () => playFilm(i),
                ),
              );
            }),
          ),
        ],
        if (!showSeries && !showFilms)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 40, pad, 0),
              child: Text(
                t.cinemaNoMatch,
                textAlign: TextAlign.center,
                style: MmType.bodySm.copyWith(color: c.muted),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _resumeTile(
    BuildContext context,
    CinemaItem v,
    WatchState watch,
    double width,
  ) {
    final t = L10n.of(context);
    final at = watch.resumeOf(v.item.id) ?? Duration.zero;
    final total = durationOf(v);
    final left = total == null ? null : total - at;
    Future<void> play() async {
      await playVideo(ref, t, v);
      if (context.mounted) openPlayer(context);
    }

    return VideoTile(
      width: width,
      aspectRatio: 16 / 9,
      radius: MmRadius.lg,
      title: resumeTitle(t, v),
      subtitle: resumeLine(t, v, at),
      imagePath: v.item.thumbnail,
      seed: v.item.id,
      progress: progressOf(v, watch),
      playButton: true,
      topRight: left == null || left.isNegative
          ? null
          : PicturePill(t.minutesShort(math.max(1, left.inMinutes))),
      onTap: () => play(),
      onMenu: (at) => showVideoMenu(
        context,
        ref,
        v,
        at,
        seen: watch.isSeen(v.item.id),
        onPlay: play,
      ),
    );
  }
}
