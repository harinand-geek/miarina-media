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
import '../../src/rust/api/focus.dart';
import '../common/state_views.dart';
import '../cinema/cinema_data.dart';
import '../cinema/cinema_widgets.dart';
import '../cinema/watch_screen.dart' show speedLabel;
import '../playback/playback.dart';
import '../search/search_screen.dart' show SearchButton;
import 'focus_data.dart';

enum FocusFilter { all, podcasts, courses, books }

bool _matches(FocusFilter f, FocusKind k) => switch (f) {
  FocusFilter.all => true,
  FocusFilter.podcasts => k == FocusKind.podcast,
  FocusFilter.courses => k == FocusKind.course,
  FocusFilter.books => k == FocusKind.audiobook,
};

String kindLabel(L10n t, FocusKind k) => switch (k) {
  FocusKind.podcast => t.kindPodcast,
  FocusKind.course => t.kindCourse,
  FocusKind.audiobook => t.kindAudiobook,
};

String itemsCount(L10n t, FocusKind k, int n) => switch (k) {
  FocusKind.podcast => t.episodesCount(n),
  FocusKind.course => t.lessonsCount(n),
  FocusKind.audiobook => t.partsCount(n),
};

String shortDuration(Duration d) => d.inHours > 0
    ? '${d.inHours} h ${d.inMinutes.remainder(60).toString().padLeft(2, '0')}'
    : '${d.inMinutes} min';

/// Opens the long-format player (W-F2) once a Focus item was started.
void openFocusPlayer(BuildContext context) => context.push(Routes.focusPlayer);

void openProgram(BuildContext context, String name) => context.push(
  Uri(path: Routes.focusProgram, queryParameters: {'name': name}).toString(),
);

/// W-F1 Podcasts & cours (Windows) and the Android Focus tab (A-F).
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, this.initial = FocusFilter.all});

  final FocusFilter initial;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  late FocusFilter _filter = widget.initial;
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final lib = ref.watch(focusLibraryProvider);
    final inProgress = ref.watch(focusInProgressProvider).value ?? const [];
    final rates = ref.watch(focusMemoryProvider).value ?? const FocusMemory();
    final data = lib.value;

    final filters = [
      (FocusFilter.all, t.segAll),
      (FocusFilter.podcasts, t.segPodcasts),
      (FocusFilter.courses, t.segCourses),
      (FocusFilter.books, t.segBooks),
    ];

    final summary = data == null
        ? null
        : [
            t.podcastsCount(data.podcastCount),
            t.coursesCount(data.courseCount),
            t.audiobooksCount(data.audiobookCount),
            if (data.durationSecs >= 3600)
              t.hoursTotal((data.durationSecs / 3600).round()),
          ].join(' · ');

    final header = mobile
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.tabFocus,
                    style: MmType.display.copyWith(color: c.fg),
                  ),
                ),
                const SearchButton(),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initial == FocusFilter.books
                            ? t.navAudiobooks
                            : t.navPodcasts,
                        style: MmType.display.copyWith(color: c.fg),
                      ),
                      const SizedBox(height: 2),
                      if (summary != null)
                        Text(
                          summary,
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
              ],
            ),
          );

    Widget body;
    if (lib.hasError) {
      body = LibraryErrorView(
        error: lib.error!,
        onRetry: () => ref.invalidate(focusLibraryProvider),
      );
    } else if (data == null) {
      body = SkeletonList(rowHeight: 64, padding: mobile ? 16 : 32);
    } else if (data.programs.isEmpty) {
      body = LibraryEmpty(
        icon: PhosphorRegular.graduationCap,
        title: t.focusEmptyTitle,
        body: t.focusEmptyBody,
      );
    } else {
      final programs = data.programs
          .where((p) => _matches(_filter, p.kind))
          .toList();
      final started = inProgress
          .where((f) => _matches(_filter, f.kind))
          .toList();
      final selected =
          programs.where((p) => p.name == _selected).firstOrNull ??
          programs
              .where((p) => p.name == started.firstOrNull?.program)
              .firstOrNull ??
          programs.firstOrNull;

      final left = <Widget>[
        if (started.isNotEmpty) ...[
          SectionHeader(t.focusInProgress),
          const SizedBox(height: 10),
          for (final f in started) ...[
            _InProgressCard(item: f, rate: rates.rateFor(_key(f))),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
        SectionHeader(t.focusLibrary),
        const SizedBox(height: 10),
        if (programs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              t.focusNoMatch,
              style: MmType.bodySm.copyWith(color: c.muted),
            ),
          ),
        for (final p in programs)
          _ProgramRow(
            program: p,
            selected: !mobile && p == selected,
            onTap: () => mobile
                ? openProgram(context, p.name)
                : setState(() => _selected = p.name),
          ),
      ];

      if (mobile) {
        body = ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: left,
        );
      } else {
        body = SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: left,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 10,
                child: selected == null
                    ? const SizedBox.shrink()
                    : ProgramItems(program: selected.name, kind: selected.kind),
              ),
            ],
          ),
        );
      }
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

  static String _key(FocusItem f) => focusKeyOf(f.kind, f.program);
}

/// "En cours" card: cover, kind, title, progress and time left at the
/// chosen speed, coral play button.
class _InProgressCard extends ConsumerWidget {
  const _InProgressCard({required this.item, required this.rate});

  final FocusItem item;
  final double rate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final state = ref.watch(listenStateProvider).value ?? const WatchState();
    final at = state.resumeOf(item.item.id) ?? Duration.zero;
    final total = focusDuration(item);
    final progress = total == null || total == Duration.zero
        ? 0.0
        : (at.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final left = total == null
        ? null
        : t.leftAtRate(
            shortDuration(leftAt(total, at, rate)),
            speedLabel(rate),
          );

    Future<void> play() async {
      final items = await ref.read(focusProgramProvider(item.program).future);
      final i = items.indexWhere((f) => f.item.id == item.item.id);
      await playFocus(
        ref.read(queueProvider.notifier),
        i < 0 ? [item] : items,
        start: i < 0 ? 0 : i,
      );
      if (context.mounted) openFocusPlayer(context);
    }

    return Pressable(
      onTap: play,
      semanticLabel: item.item.title,
      borderRadius: BorderRadius.circular(MmRadius.card),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MmRadius.card),
          border: Border.all(color: c.surface2),
        ),
        child: Row(
          children: [
            CoverArt(
              size: 72,
              radius: MmRadius.md,
              shadow: false,
              seed: item.program.hashCode,
              imagePath: item.item.thumbnail,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${kindLabel(t, item.kind)} · ${item.program}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.captionStrong.copyWith(
                      fontSize: 11.5,
                      color: c.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.heading.copyWith(fontSize: 14.5, color: c.fg),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(MmRadius.pill),
                          child: SizedBox(
                            height: 4,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: c.line,
                              color: c.coral,
                            ),
                          ),
                        ),
                      ),
                      if (left != null) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          flex: 3,
                          child: Text(
                            left,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MmType.caption.copyWith(color: c.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const PictureplayButton(),
          ],
        ),
      ),
    );
  }
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({
    required this.program,
    required this.selected,
    required this.onTap,
  });

  final FocusProgram program;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final p = program;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: p.name,
      borderRadius: BorderRadius.circular(MmRadius.md),
      hoverColor: c.cardHover,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(MmRadius.md),
        ),
        child: Row(
          children: [
            CoverArt(
              size: 48,
              radius: MmRadius.sm,
              shadow: false,
              seed: p.name.hashCode,
              imagePath: p.thumbnail,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.labelStrong.copyWith(color: c.fg),
                  ),
                  Text(
                    [
                      kindLabel(t, p.kind),
                      if (p.artist != null && p.artist != p.name) p.artist!,
                      itemsCount(t, p.kind, p.count),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            Text(
              shortDuration(Duration(seconds: p.durationSecs.round())),
              style: MmType.monoStyle(size: 11.5, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Items of one program in play order, with their state: finished (teal
/// check), started (coral), not yet heard (ring). Right column of W-F1 and
/// the Android program page.
class ProgramItems extends ConsumerWidget {
  const ProgramItems({super.key, required this.program, required this.kind});

  final String program;
  final FocusKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final items = ref.watch(focusProgramProvider(program)).value ?? const [];
    final state = ref.watch(listenStateProvider).value ?? const WatchState();
    final current = ref.watch(
      queueProvider.select((q) => q.current?.libraryId),
    );
    final latest = state.recent
        .where((id) => items.any((f) => f.item.id == id))
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('${kindLabel(t, kind)} · $program'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.sidebar,
            borderRadius: BorderRadius.circular(MmRadius.card),
            border: Border.all(color: c.divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _ItemRow(
                  item: items[i],
                  done: state.isSeen(items[i].item.id),
                  active:
                      items[i].item.id == current ||
                      (current == null && items[i].item.id == latest),
                  started: state.resumeOf(items[i].item.id) != null,
                  onTap: () async {
                    await playFocus(
                      ref.read(queueProvider.notifier),
                      items,
                      start: i,
                    );
                    if (context.mounted) openFocusPlayer(context);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(t.focusOrderHint, style: MmType.caption.copyWith(color: c.faint)),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.done,
    required this.active,
    required this.started,
    required this.onTap,
  });

  final FocusItem item;
  final bool done;
  final bool active;
  final bool started;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final d = focusDuration(item);
    final (icon, color) = done
        ? (PhosphorFill.checkCircle, c.accent)
        : active || started
        ? (PhosphorFill.playCircle, c.coral)
        : (PhosphorRegular.circle, c.faintIcon);
    return Pressable(
      onTap: item.item.missing ? null : onTap,
      semanticLabel: item.item.title,
      borderRadius: BorderRadius.circular(10),
      hoverColor: c.cardHover,
      child: Opacity(
        opacity: item.item.missing ? 0.72 : 1,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.label.copyWith(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: item.item.missing
                        ? c.warning
                        : active
                        ? c.coralStrong
                        : c.fg,
                  ),
                ),
              ),
              if (d != null)
                Text(
                  formatClock(d),
                  style: MmType.monoStyle(size: 11.5, color: c.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Android page of one program (from the Focus tab).
class FocusProgramScreen extends ConsumerWidget {
  const FocusProgramScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final lib = ref.watch(focusLibraryProvider).value;
    final kind =
        lib?.programs.where((p) => p.name == name).firstOrNull?.kind ??
        FocusKind.podcast;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Pressable(
            onTap: () =>
                context.canPop() ? context.pop() : context.go(Routes.focus),
            semanticLabel: t.back,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorRegular.caretLeft, size: 20, color: c.fgSoft),
                  Text(
                    t.tabFocus,
                    style: MmType.label.copyWith(color: c.fgSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ProgramItems(program: name, kind: kind),
      ],
    );
  }
}
