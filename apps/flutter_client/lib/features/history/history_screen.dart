import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/states.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/cinema.dart';
import '../cinema/cinema_screen.dart' show resumeTitle;
import '../common/state_views.dart';
import '../cinema/cinema_widgets.dart';
import '../common/open_media.dart';
import '../focus/focus_screen.dart' show kindLabel;
import '../library/groups.dart';
import 'history_data.dart';
import '../../app/malagasy_fallback.dart';

/// W-03 History: every play, grouped by day, all sections together; each
/// line shows where it stopped and resumes in one click. Clearing forgets
/// the plays only.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistorySection? _filter;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final history = ref.watch(historyProvider);
    final rows = (history.value ?? const <HistoryRow>[])
        .where((r) => _filter == null || r.section == _filter)
        .toList();
    final locale = intlLocaleOf(context);
    final time = DateFormat.Hm(locale);
    final day = DateFormat.yMMMMEEEEd(locale);
    final today = dayOf(DateTime.now());

    String dayLabel(DateTime d) {
      final diff = today.difference(d).inDays;
      if (diff == 0) return t.today;
      if (diff == 1) return t.yesterday;
      final text = day.format(d);
      return text[0].toUpperCase() + text.substring(1);
    }

    final filters = [
      (null, t.segAll),
      (HistorySection.music, t.tabMusic),
      (HistorySection.cinema, t.tabCinema),
      (HistorySection.focus, t.tabFocus),
    ];

    final header = Padding(
      padding: mobile
          ? const EdgeInsets.fromLTRB(16, 12, 16, 10)
          : const EdgeInsets.fromLTRB(32, 24, 32, 18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.navHistory, style: MmType.display.copyWith(color: c.fg)),
              const SizedBox(height: 2),
              Text(
                t.historySubtitle,
                style: MmType.bodySm.copyWith(color: c.muted),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillSegment<HistorySection?>(
                values: filters,
                selected: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(width: 12),
              Pressable(
                onTap: (history.value?.isEmpty ?? true)
                    ? null
                    : () => confirmClearHistory(context, ref),
                semanticLabel: t.historyClear,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      t.historyClear,
                      style: MmType.labelStrong.copyWith(
                        fontSize: 13,
                        color: c.fgSoft,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    Widget body;
    if (history.hasError) {
      body = LibraryErrorView(
        error: history.error!,
        onRetry: () => ref.invalidate(historyProvider),
      );
    } else if (!history.hasValue) {
      body = SkeletonList(rowHeight: 60, padding: mobile ? 16 : 32);
    } else if (rows.isEmpty) {
      body = LibraryMessage(
        icon: PhosphorRegular.clockCounterClockwise,
        title: t.historyEmptyTitle,
        body: t.historyEmptyBody,
      );
    } else {
      final children = <Widget>[];
      DateTime? current;
      for (final r in rows) {
        final d = dayOf(r.play.at);
        if (d != current) {
          current = d;
          children.add(
            Padding(
              padding: EdgeInsets.only(
                top: children.isEmpty ? 0 : 18,
                bottom: 8,
              ),
              child: Text(
                dayLabel(d),
                style: MmType.heading.copyWith(color: c.fgSoft),
              ),
            ),
          );
        }
        children.add(
          _HistoryLine(row: r, time: time.format(r.play.at), mobile: mobile),
        );
      }
      body = ListView(
        padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 0, mobile ? 16 : 32, 24),
        children: children,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }
}

class _HistoryLine extends ConsumerWidget {
  const _HistoryLine({
    required this.row,
    required this.time,
    required this.mobile,
  });

  final HistoryRow row;
  final String time;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final r = row;
    final video = r.video;
    final total = r.duration;
    final finished = r.finished;
    final progress = finished
        ? 1.0
        : total == null || total == Duration.zero
        ? 0.0
        : (r.position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    final title = video != null ? resumeTitle(t, video) : r.item.title;
    final subtitle = switch (r.section) {
      HistorySection.cinema => [
        t.tabCinema,
        switch (video?.kind) {
          CinemaKind.episode => t.seriesWord,
          CinemaKind.film => t.kindFilm,
          _ => t.kindPersonal,
        },
      ],
      HistorySection.focus => [
        t.tabFocus,
        if (r.focus != null) kindLabel(t, r.focus!.kind),
        ?r.focus?.program,
      ],
      HistorySection.music => [t.tabMusic, ?r.item.artist],
    }.join(' · ');

    final status = finished
        ? t.finished
        : total == null
        ? formatClock(r.position)
        : t.positionOf(formatClock(r.position), formatClock(total));

    void open({bool fromStart = false}) => openMedia(
      context,
      ref,
      r.item,
      video: video,
      focus: r.focus,
      fromStart: fromStart,
    );

    final action = finished
        ? Pressable(
            onTap: () => open(fromStart: true),
            semanticLabel: '${t.replay} $title',
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  t.replay,
                  style: MmType.labelStrong.copyWith(color: c.fgSoft),
                ),
              ),
            ),
          )
        : Pressable(
            onTap: open,
            semanticLabel: '${t.homeResume} $title',
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.coralSubtle,
                borderRadius: BorderRadius.circular(MmRadius.pill),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  t.homeResume,
                  style: MmType.labelStrong.copyWith(color: c.coralStrong),
                ),
              ),
            ),
          );

    final thumb = CoverArt(
      size: r.item.isVideo ? 80 : 48,
      aspectRatio: r.item.isVideo ? 16 / 9 : 1,
      radius: MmRadius.sm,
      shadow: false,
      seed: r.item.id,
      imagePath: r.item.thumbnail,
    );

    return Pressable(
      onTap: finished ? () => open(fromStart: true) : open,
      semanticLabel: title,
      borderRadius: BorderRadius.circular(MmRadius.md),
      hoverColor: c.cardHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            if (!mobile)
              SizedBox(
                width: 64,
                child: Text(
                  time,
                  style: MmType.monoStyle(size: 11.5, color: c.muted),
                ),
              ),
            SizedBox(
              width: 80,
              child: Align(alignment: Alignment.centerLeft, child: thumb),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.labelStrong.copyWith(color: c.fg),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.caption.copyWith(color: c.muted),
                  ),
                  if (mobile) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$time · $status',
                      style: MmType.caption.copyWith(color: c.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (!mobile) ...[
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: MmType.caption.copyWith(color: c.fgSoft),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MmRadius.pill),
                      child: SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: c.line,
                          color: finished ? c.accent : c.coral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
            SizedBox(
              width: mobile ? null : 120,
              child: Align(alignment: Alignment.centerRight, child: action),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before forgetting the plays (files, favorites and resume points
/// are kept).
Future<void> confirmClearHistory(BuildContext context, WidgetRef ref) async {
  final t = L10n.of(context);
  final c = MmColors.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        side: BorderSide(color: c.overlayBorder),
      ),
      title: Text(
        t.historyClearTitle,
        style: MmType.title.copyWith(color: c.fg),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(
          t.historyClearBody,
          style: MmType.body.copyWith(color: c.fgSoft),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            t.cancel,
            style: MmType.labelStrong.copyWith(color: c.fg),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            t.clear,
            style: MmType.labelStrong.copyWith(color: c.danger),
          ),
        ),
      ],
    ),
  );
  if (ok == true) await clearHistory(ref);
}
