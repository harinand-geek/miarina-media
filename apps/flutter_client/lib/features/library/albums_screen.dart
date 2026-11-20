import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/states.dart';
import '../../l10n/app_localizations.dart';
import '../common/state_views.dart';
import '../health/health_screens.dart' show formatSize;
import '../playback/settings_store.dart';
import '../../src/rust/api/library.dart';
import 'groups.dart';
import 'library_data.dart';

/// Orders of the Albums and Artists views (W-M1a / W-M1b).
enum GroupSort { added, name, artist, year, plays, tracks }

/// Sorts offered by each view, the first one by default (mockup: albums
/// "Ajoutés récemment", artists "A → Z").
List<GroupSort> sortsFor(GroupKind kind) => kind == GroupKind.album
    ? const [
        GroupSort.added,
        GroupSort.name,
        GroupSort.artist,
        GroupSort.year,
        GroupSort.plays,
      ]
    : const [GroupSort.name, GroupSort.plays, GroupSort.tracks];

/// Quick filters of the Albums view, one at a time (null = Tous).
enum AlbumFilter { lossless, downloaded, compilation, noCover }

bool albumMatches(LibraryGroup g, AlbumFilter? f) => switch (f) {
  null => true,
  AlbumFilter.lossless => g.lossless,
  AlbumFilter.downloaded => g.downloaded,
  AlbumFilter.compilation => g.compilation,
  AlbumFilter.noCover => g.thumbnail == null,
};

/// [groups] in [sort] order; ties and missing values by name.
List<LibraryGroup> sortGroups(List<LibraryGroup> groups, GroupSort sort) {
  int byName(LibraryGroup a, LibraryGroup b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  int then(int c, LibraryGroup a, LibraryGroup b) => c != 0 ? c : byName(a, b);
  final list = [...groups];
  list.sort(
    (a, b) => switch (sort) {
      GroupSort.name => byName(a, b),
      GroupSort.added => then(b.addedAt.compareTo(a.addedAt), a, b),
      GroupSort.plays => then(b.plays.compareTo(a.plays), a, b),
      GroupSort.tracks => then(b.count.compareTo(a.count), a, b),
      // Newest first, undated last.
      GroupSort.year => then((b.year ?? -1).compareTo(a.year ?? -1), a, b),
      // Untagged last.
      GroupSort.artist => then(
        (a.detail == null ? 1 : 0).compareTo(b.detail == null ? 1 : 0) != 0
            ? (a.detail == null ? 1 : -1)
            : (a.detail ?? '').toLowerCase().compareTo(
                (b.detail ?? '').toLowerCase(),
              ),
        a,
        b,
      ),
    },
  );
  return list;
}

/// How a view is shown, remembered per view ("le tri est mémorisé par vue").
@immutable
class GroupView {
  const GroupView({required this.sort, this.list = false});

  final GroupSort sort;

  /// Albums as a list instead of the grid.
  final bool list;
}

final groupViewsProvider =
    AsyncNotifierProvider<GroupViewsController, Map<GroupKind, GroupView>>(
      GroupViewsController.new,
    );

class GroupViewsController extends AsyncNotifier<Map<GroupKind, GroupView>> {
  static const key = 'groupViews';

  @override
  Future<Map<GroupKind, GroupView>> build() async {
    Object? raw;
    try {
      raw = await ref.read(settingsStoreProvider).read(key);
    } catch (_) {}
    final saved = raw is Map ? raw : const {};
    return {
      for (final kind in GroupKind.values)
        kind: () {
          final v = saved[kind.name];
          final sorts = sortsFor(kind);
          final sort = v is Map
              ? sorts.where((s) => s.name == v['sort']).firstOrNull
              : null;
          return GroupView(
            sort: sort ?? sorts.first,
            list: v is Map && v['list'] == true,
          );
        }(),
    };
  }

  Future<void> set(GroupKind kind, GroupView view) async {
    final next = {...?state.value, kind: view};
    state = AsyncData(next);
    try {
      await ref.read(settingsStoreProvider).write(key, {
        for (final e in next.entries)
          e.key.name: {'sort': e.value.sort.name, 'list': e.value.list},
      });
    } catch (_) {}
  }
}

/// W-M1a Albums / W-M1b Artists (Windows) and their Android lists: a grid
/// in auto-fill columns (cards at least 168 px, circles 140 px), virtualised.
/// Windows: sort menu (remembered per view), albums as grid or list, and
/// the quick filters of the mockup.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key, required this.kind});

  final GroupKind kind;

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  AlbumFilter? _filter;

  GroupKind get kind => widget.kind;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final groups = ref.watch(groupsProvider(kind));
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final albums = kind == GroupKind.album;
    final view =
        ref.watch(groupViewsProvider).value?[kind] ??
        GroupView(sort: sortsFor(kind).first);

    final all = groups.value ?? const <LibraryGroup>[];
    final tracks = all.fold<int>(0, (n, g) => n + g.count.toInt());
    final bytes = all.fold<int>(0, (n, g) => n + g.sizeBytes.toInt());
    final summary = albums
        ? [
            t.albumsCount(all.length),
            t.tracksSummary(tracks),
            if (bytes > 0) formatSize(context, bytes),
          ].join(' · ')
        : '${t.artistsCount(all.length)} · ${t.artistsGrouping}';
    final filter = albums && !mobile ? _filter : null;
    final list = sortGroups([
      for (final g in all)
        if (albumMatches(g, filter)) g,
    ], mobile ? GroupSort.name : view.sort);
    final noCover = all.where((g) => g.thumbnail == null).length;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          albums ? t.navAlbums : t.navArtists,
          style: mobile
              ? MmType.titleLg.copyWith(fontSize: 20, color: c.fg)
              : MmType.display.copyWith(color: c.fg),
        ),
        const SizedBox(height: 2),
        Text(summary, style: MmType.bodySm.copyWith(color: c.muted)),
      ],
    );
    final header = mobile
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: title,
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    _SortMenu(
                      kind: kind,
                      view: view,
                      onChanged: (s) => ref
                          .read(groupViewsProvider.notifier)
                          .set(kind, GroupView(sort: s, list: view.list)),
                    ),
                    if (albums) ...[
                      const SizedBox(width: 8),
                      _ViewToggle(
                        list: view.list,
                        onChanged: (l) => ref
                            .read(groupViewsProvider.notifier)
                            .set(kind, GroupView(sort: view.sort, list: l)),
                      ),
                    ],
                  ],
                ),
                if (albums) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: t.filterAll,
                          on: filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        for (final (f, label) in [
                          (AlbumFilter.lossless, t.filterLossless),
                          (AlbumFilter.downloaded, t.filterDownloaded),
                          (AlbumFilter.compilation, t.filterCompilations),
                          if (noCover > 0)
                            (AlbumFilter.noCover, t.filterNoCover(noCover)),
                        ]) ...[
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: label,
                            on: filter == f,
                            onTap: () => setState(
                              () => _filter = filter == f ? null : f,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
              ],
            ),
          );

    Widget body;
    if (groups.hasError) {
      body = LibraryErrorView(
        error: groups.error!,
        onRetry: () => ref.invalidate(groupsProvider(kind)),
      );
    } else if (groups.isLoading && all.isEmpty) {
      body = SkeletonGrid(
        minTile: albums ? 168 : 140,
        padding: mobile ? 16 : 32,
      );
    } else if (all.isEmpty) {
      body = LibraryEmpty(
        icon: albums ? PhosphorRegular.vinylRecord : PhosphorRegular.user,
        title: albums ? t.albumsEmptyTitle : t.artistsEmptyTitle,
        body: albums ? t.albumsEmptyBody : t.artistsEmptyBody,
      );
    } else if (list.isEmpty) {
      body = LibraryMessage(
        icon: PhosphorRegular.funnelSimple,
        title: t.filterEmptyTitle,
        body: t.filterEmptyBody,
      );
    } else if (albums && view.list && !mobile) {
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
        itemExtent: 60,
        itemCount: list.length,
        itemBuilder: (context, i) => _AlbumRow(group: list[i]),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) {
          final pad = mobile ? 16.0 : 32.0;
          final gap = albums ? 18.0 : 16.0;
          final minTile = albums ? 168.0 : 140.0;
          final width = box.maxWidth - pad * 2;
          final cols = mobile
              ? (albums ? 2 : 3)
              : math.max(2, ((width + gap) / (minTile + gap)).floor());
          final tile = (width - gap * (cols - 1)) / cols;
          // Album cards have an 8 px hover padding around the cover.
          final cover = albums ? tile - 16 : tile - 12;
          final height = albums
              ? cover + 16 + 9 + 18 + 16
              : cover + 8 + 10 + 18 + 16;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: gap,
              mainAxisSpacing: albums ? 14 : 18,
              mainAxisExtent: height,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) => albums
                ? AlbumCard(group: list[i], size: cover)
                : ArtistCircle(group: list[i], size: cover),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (mobile) ...[
          MusicChips(current: albums ? Routes.albums : Routes.artists),
          const SizedBox(height: 12),
        ],
        Expanded(child: body),
      ],
    );
  }
}

String sortLabel(L10n t, GroupSort s) => switch (s) {
  GroupSort.added => t.groupSortAdded,
  GroupSort.name => t.groupSortName,
  GroupSort.artist => t.colArtist,
  GroupSort.year => t.groupSortYear,
  GroupSort.plays => t.groupSortPlays,
  GroupSort.tracks => t.groupSortTracks,
};

/// "↕ Ajoutés récemment ▾" (mockup): the view's order.
class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.kind,
    required this.view,
    required this.onChanged,
  });

  final GroupKind kind;
  final GroupView view;
  final ValueChanged<GroupSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface2),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: c.overlayBorder),
          ),
        ),
      ),
      menuChildren: [
        for (final s in sortsFor(kind))
          MenuItemButton(
            onPressed: () => onChanged(s),
            leadingIcon: SizedBox(
              width: 18,
              child: s == view.sort
                  ? Icon(PhosphorRegular.check, size: 16, color: c.accent)
                  : null,
            ),
            child: Text(
              sortLabel(t, s),
              style: MmType.label.copyWith(color: c.fg),
            ),
          ),
      ],
      builder: (context, menu, _) => Pressable(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        semanticLabel: '${t.sortBy} : ${sortLabel(t, view.sort)}',
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorRegular.sortAscending, size: 18, color: c.fgSoft),
              const SizedBox(width: 6),
              Text(
                sortLabel(t, view.sort),
                style: MmType.label.copyWith(
                  color: c.fgSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(PhosphorRegular.caretDown, size: 16, color: c.fgSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid / list switch of the Albums view.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.list, required this.onChanged});

  final bool list;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget option(bool asList, IconData icon, String label) {
      final on = list == asList;
      return Pressable(
        onTap: on ? null : () => onChanged(asList),
        selected: on,
        semanticLabel: label,
        tooltip: label,
        child: Container(
          width: 34,
          height: 28,
          decoration: BoxDecoration(
            color: on ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(MmRadius.pill),
          ),
          child: Icon(icon, size: 18, color: on ? c.fg : c.muted),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.sidebar,
        borderRadius: BorderRadius.circular(MmRadius.pill),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(false, PhosphorRegular.squaresFour, t.viewGrid),
          option(true, PhosphorRegular.list, t.viewList),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      selected: on,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: MmMotion.of(context).state,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? c.coralSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: on ? c.coralChipBorder : c.lineStrong),
        ),
        child: Text(
          label,
          style: MmType.captionStrong.copyWith(
            fontSize: 12.5,
            color: on ? c.coralStrong : c.muted,
          ),
        ),
      ),
    );
  }
}

/// An album of the list view: cover, name, artist, year, tracks, length.
class _AlbumRow extends ConsumerWidget {
  const _AlbumRow({required this.group});

  final LibraryGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final g = group;
    final key = (kind: GroupKind.album, name: g.name);
    final muted = MmType.bodySm.copyWith(color: c.muted);
    return Pressable(
      onTap: () => openGroup(context, ref, key),
      onDoubleTap: () => playGroup(ref, t, key),
      semanticLabel: [g.name, g.detail].whereType<String>().join(', '),
      pressScale: 1,
      hoverColor: c.cardHover,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            CoverArt(
              size: 40,
              radius: 8,
              seed: g.name.hashCode,
              imagePath: g.thumbnail,
              shadow: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 20,
              child: Text(
                g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.labelStrong.copyWith(color: c.fg),
              ),
            ),
            Expanded(
              flex: 14,
              child: Text(
                g.detail ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                g.year?.toString() ?? '—',
                style: MmType.monoStyle(size: 12, color: c.faint),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(t.tracksSummary(g.count.toInt()), style: muted),
            ),
            SizedBox(
              width: 80,
              child: Text(
                durationWords(g.durationSecs),
                textAlign: TextAlign.right,
                style: MmType.monoStyle(size: 12, color: c.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
