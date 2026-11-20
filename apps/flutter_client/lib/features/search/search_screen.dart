import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/states.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/cinema.dart';
import '../../src/rust/api/library.dart';
import '../../src/rust/api/search.dart';
import '../cinema/cinema_screen.dart' show resumeTitle;
import '../common/state_views.dart';
import '../cinema/cinema_widgets.dart';
import '../common/open_media.dart';
import '../focus/focus_data.dart';
import '../focus/focus_screen.dart' show kindLabel;
import '../library/groups.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import 'search_data.dart';

enum SearchFilter { all, music, cinema, focus }

String searchUri(String query) =>
    Uri(path: Routes.search, queryParameters: {'q': query}).toString();

/// W-02 search results (Windows: typed in the title bar, Ctrl K) and A-01b
/// (Android: its own field). Grouped by type and section, counters on the
/// filters, best result first; accent-insensitive, words matched from
/// their start.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.query});

  final String query;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  SearchFilter _filter = SearchFilter.all;
  late final _field = TextEditingController(text: widget.query);
  Timer? _debounce;

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _filter = SearchFilter.all;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = !ref.watch(desktopShellProvider);
    final q = widget.query.trim();
    final data = q.isEmpty ? null : ref.watch(searchProvider(q));
    final d = data?.value;

    final mobileField = Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 8,
        16,
        8,
      ),
      child: Row(
        children: [
          Pressable(
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(Routes.listenHome),
            semanticLabel: t.back,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(PhosphorRegular.arrowLeft, color: c.fg, size: 22),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _field,
              autofocus: q.isEmpty,
              textInputAction: TextInputAction.search,
              style: MmType.body.copyWith(color: c.fg),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: t.searchPlaceholder,
                hintStyle: MmType.body.copyWith(color: c.faint),
                filled: true,
                fillColor: c.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                  borderSide: BorderSide(color: c.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                  borderSide: BorderSide(color: c.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                  borderSide: BorderSide(color: c.accent),
                ),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 200),
                  () => mounted ? context.replace(searchUri(v)) : null,
                );
              },
            ),
          ),
        ],
      ),
    );

    Widget body;
    if (q.isEmpty) {
      body = LibraryMessage(
        icon: PhosphorRegular.magnifyingGlass,
        title: t.searchPlaceholder,
        body: t.searchHint,
      );
    } else if (data!.hasError) {
      body = LibraryErrorView(
        error: data.error!,
        onRetry: () => ref.invalidate(searchProvider(q)),
      );
    } else if (d == null) {
      body = SkeletonList(padding: mobile ? 16 : 32);
    } else if (d.isEmpty) {
      body = LibraryMessage(
        icon: PhosphorRegular.magnifyingGlass,
        title: t.searchEmptyTitle(q),
        body: t.searchEmptyBody,
      );
    } else {
      body = _Results(
        data: d,
        filter: _filter,
        mobile: mobile,
        onFilter: (f) => setState(() => _filter = f),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile) mobileField,
        if (!mobile && q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 14,
              children: [
                Text(
                  t.searchTitle(q),
                  style: MmType.display.copyWith(color: c.fg),
                ),
                if (d != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      t.searchCount(d.total),
                      style: MmType.bodySm.copyWith(color: c.muted),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(child: body),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.data,
    required this.filter,
    required this.mobile,
    required this.onFilter,
  });

  final SearchData data;
  final SearchFilter filter;
  final bool mobile;
  final ValueChanged<SearchFilter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final d = data;
    final chips = [
      (SearchFilter.all, t.segAll, d.total),
      (SearchFilter.music, t.tabMusic, d.musicCount),
      (SearchFilter.cinema, t.tabCinema, d.cinema.length),
      (SearchFilter.focus, t.tabFocus, d.focus.length),
    ];

    Widget chipRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label, count) in chips)
          if (value == SearchFilter.all || count > 0)
            Pressable(
              onTap: () => onFilter(value),
              selected: value == filter,
              semanticLabel: '$label $count',
              child: AnimatedContainer(
                duration: MmMotion.of(context).state,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: value == filter ? c.coralSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                  border: Border.all(
                    color: value == filter ? c.coralChipBorder : c.lineStrong,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: MmType.labelStrong.copyWith(
                        fontSize: 13,
                        color: value == filter ? c.coralStrong : c.fgSoft,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: MmType.monoStyle(
                        size: 11,
                        color: value == filter ? c.coralStrong : c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );

    final limit = filter == SearchFilter.all ? 4 : 1 << 20;
    Widget section<T>(
      String title,
      List<T> items,
      Widget Function(T) row,
      SearchFilter target,
    ) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: SectionHeader(title)),
                if (filter == SearchFilter.all && items.length > limit)
                  Pressable(
                    onTap: () => onFilter(target),
                    semanticLabel: t.seeAllCount(items.length),
                    child: Text(
                      t.seeAllCount(items.length),
                      style: MmType.label.copyWith(
                        fontSize: 13,
                        color: c.muted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final i in items.take(limit)) row(i),
          ],
        ),
      );
    }

    final showMusic =
        filter == SearchFilter.all || filter == SearchFilter.music;
    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMusic) ...[
          section(
            t.navTracks,
            d.tracks,
            (h) => _HitRow(hit: h, music: d.tracks),
            SearchFilter.music,
          ),
          section(
            t.navAlbums,
            d.albums,
            (g) => _GroupRow(group: g, kind: GroupKind.album),
            SearchFilter.music,
          ),
          section(
            t.navArtists,
            d.artists,
            (g) => _GroupRow(group: g, kind: GroupKind.artist),
            SearchFilter.music,
          ),
        ],
        if (filter == SearchFilter.all || filter == SearchFilter.focus)
          section(
            t.tabFocus,
            d.focus,
            (h) => _HitRow(hit: h),
            SearchFilter.focus,
          ),
        if (filter == SearchFilter.all || filter == SearchFilter.cinema)
          section(
            t.tabCinema,
            d.cinema,
            (h) => _HitRow(hit: h),
            SearchFilter.cinema,
          ),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                t.searchTranscripts,
                style: MmType.caption.copyWith(color: c.faint),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: c.faint),
                ),
                child: Text(
                  t.futureBadge,
                  style: MmType.monoStyle(
                    size: 8.5,
                    weight: 700,
                    color: c.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final best = filter == SearchFilter.all ? d.best : null;
    final pad = mobile ? 16.0 : 32.0;
    if (mobile) {
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
        children: [
          chipRow,
          const SizedBox(height: 16),
          if (best != null) ...[
            _BestCard(hit: best, music: d.tracks),
            const SizedBox(height: 18),
          ],
          sections,
        ],
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chipRow,
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (best != null) ...[
                SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(t.bestResult),
                      const SizedBox(height: 10),
                      _BestCard(hit: best, music: d.tracks),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
              ],
              Expanded(child: sections),
            ],
          ),
        ],
      ),
    );
  }
}

String hitTitle(L10n t, SearchHit h) =>
    h.video != null ? resumeTitle(t, h.video!) : h.item.title;

String hitSubtitle(L10n t, SearchHit h) => switch (h.section) {
  SearchSection.music => [
    t.kindTrack,
    ?h.item.artist,
    ?h.item.album,
  ].join(' · '),
  SearchSection.focus => [
    if (h.focusKind != null) kindLabel(t, h.focusKind!),
    ?h.program,
  ].join(' · '),
  SearchSection.cinema => switch (h.video?.kind) {
    CinemaKind.episode => '${t.seriesWord} · ${h.video!.series ?? ''}',
    CinemaKind.film => t.kindFilm,
    _ => t.kindPersonal,
  },
};

Future<void> openHit(
  BuildContext context,
  WidgetRef ref,
  SearchHit h, {
  List<SearchHit> music = const [],
}) async {
  if (h.section == SearchSection.music && music.isNotEmpty) {
    // A track plays with the other matching tracks after it.
    final t = L10n.of(context);
    final start = music.indexWhere((m) => m.item.id == h.item.id);
    await ref.read(queueProvider.notifier).playAll([
      for (final m in music)
        queueEntryOf(m.item, unknownArtist: t.unknownArtist),
    ], start: start < 0 ? 0 : start);
    return;
  }
  final focus = h.focusKind == null
      ? null
      : await ref.read(focusApiProvider).entry(h.item.id);
  if (!context.mounted) return;
  await openMedia(context, ref, h.item, video: h.video, focus: focus);
}

class _HitRow extends ConsumerWidget {
  const _HitRow({required this.hit, this.music = const []});

  final SearchHit hit;
  final List<SearchHit> music;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final h = hit;
    final d = h.item.durationSecs;
    final playing = ref.watch(
      queueProvider.select((q) => q.current?.libraryId == h.item.id),
    );
    return Pressable(
      onTap: h.item.missing
          ? null
          : () => openHit(context, ref, h, music: music),
      semanticLabel: hitTitle(t, h),
      borderRadius: BorderRadius.circular(MmRadius.md),
      hoverColor: c.cardHover,
      child: Opacity(
        opacity: h.item.missing ? 0.72 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            children: [
              CoverArt(
                size: h.item.isVideo ? 56 : 40,
                aspectRatio: h.item.isVideo ? 16 / 9 : 1,
                radius: MmRadius.sm,
                shadow: false,
                seed: h.item.id,
                imagePath: h.item.thumbnail,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hitTitle(t, h),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.labelStrong.copyWith(
                        color: playing ? c.coralHover : c.fg,
                      ),
                    ),
                    Text(
                      hitSubtitle(t, h),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.caption.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              if (d != null)
                Text(
                  formatClock(Duration(milliseconds: (d * 1000).round())),
                  style: MmType.monoStyle(size: 11.5, color: c.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends ConsumerWidget {
  const _GroupRow({required this.group, required this.kind});

  final LibraryGroup group;
  final GroupKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final g = group;
    final album = kind == GroupKind.album;
    return Pressable(
      onTap: () => openGroup(context, ref, (kind: kind, name: g.name)),
      semanticLabel: g.name,
      borderRadius: BorderRadius.circular(MmRadius.md),
      hoverColor: c.cardHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            CoverArt(
              size: 40,
              radius: album ? MmRadius.sm : 20,
              shadow: false,
              seed: g.name.hashCode,
              imagePath: g.thumbnail,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.labelStrong.copyWith(color: c.fg),
                  ),
                  Text(
                    album
                        ? [t.kindAlbum, ?g.detail].join(' · ')
                        : '${t.kindArtist} · ${t.albumsCount(int.tryParse(g.detail ?? '') ?? 0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestCard extends ConsumerWidget {
  const _BestCard({required this.hit, required this.music});

  final SearchHit hit;
  final List<SearchHit> music;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final h = hit;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        border: Border.all(color: c.surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverArt(
            size: h.item.isVideo ? 170 : 96,
            aspectRatio: h.item.isVideo ? 16 / 9 : 1,
            radius: MmRadius.md,
            seed: h.item.id,
            imagePath: h.item.thumbnail,
          ),
          const SizedBox(height: 18),
          Text(
            hitTitle(t, h),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MmType.titleLg.copyWith(color: c.fg),
          ),
          const SizedBox(height: 2),
          Text(
            hitSubtitle(t, h),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MmType.bodySm.copyWith(color: c.muted),
          ),
          const SizedBox(height: 16),
          Pressable(
            onTap: h.item.missing
                ? null
                : () => openHit(context, ref, h, music: music),
            semanticLabel: '${t.playVerb} ${hitTitle(t, h)}',
            pressScale: 0.97,
            child: Container(
              height: 42,
              padding: const EdgeInsets.fromLTRB(14, 0, 20, 0),
              decoration: BoxDecoration(
                color: c.coral,
                borderRadius: BorderRadius.circular(MmRadius.pill),
                boxShadow: MmShadows.playHalo,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorFill.play, size: 20, color: c.coralInk),
                  const SizedBox(width: 6),
                  Text(
                    t.playVerb,
                    style: MmType.heading.copyWith(color: c.coralInk),
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

/// Android search entry (A-01b) of the tab headers.
class SearchButton extends StatelessWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Pressable(
      onTap: () => context.push(Routes.search),
      semanticLabel: t.searchPlaceholder,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(PhosphorRegular.magnifyingGlass, size: 24, color: c.fgSoft),
      ),
    );
  }
}
