import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/malagasy_fallback.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../common/state_views.dart';
import '../library/groups.dart';
import '../library/library_data.dart';
import '../playback/listen_months.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';

/// Monthly recap (decision 0013, proposal 10): the months heard, newest
/// first. Read again when another title starts.
final listenMonthsProvider = FutureProvider.autoDispose<ListenMonths>((ref) {
  ref.watch(queueProvider.select((q) => q.current?.libraryId));
  return ref.read(playbackMemoryProvider).listenMonths();
});

/// The month's most heard library tracks still in the library, with their
/// seconds (at most ten).
final monthTopTracksProvider = FutureProvider.autoDispose
    .family<List<(LibraryItem, int)>, String>((ref, key) async {
      final months = await ref.watch(listenMonthsProvider.future);
      final api = ref.read(libraryApiProvider);
      final out = <(LibraryItem, int)>[];
      for (final e in months[key].topTracks) {
        if (out.length >= 10) break;
        final item = await api.item(e.key);
        if (item != null && !item.missing) out.add((item, e.value));
      }
      return out;
    });

/// « Votre mois »: time heard, days of listening, the busiest day, a bar
/// per day, the artists and the titles of the month; one tap plays the
/// month's top.
class MonthRecapScreen extends ConsumerStatefulWidget {
  const MonthRecapScreen({super.key});

  @override
  ConsumerState<MonthRecapScreen> createState() => _MonthRecapScreenState();
}

class _MonthRecapScreenState extends ConsumerState<MonthRecapScreen> {
  String? _month;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final pad = mobile ? 16.0 : 32.0;
    final months = ref.watch(listenMonthsProvider);
    final locale = intlLocaleOf(context);
    final now = DateTime.now();
    final keys = months.value?.keys ?? const <String>[];
    final current = ListenMonths.monthKey(now);
    final key = _month ?? (keys.isEmpty ? current : keys.first);
    final month = months.value?[key] ?? ListenMonth.empty;
    final first = ListenMonths.monthOf(key) ?? DateTime(now.year, now.month);

    String monthName(String k) {
      final d = ListenMonths.monthOf(k);
      if (d == null) return k;
      final s = DateFormat.yMMMM(locale).format(d);
      return s[0].toUpperCase() + s.substring(1);
    }

    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, mobile ? 12 : 24, pad, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.recapTitle, style: MmType.display.copyWith(color: c.fg)),
          const SizedBox(height: 2),
          Text(t.recapSubtitle, style: MmType.bodySm.copyWith(color: c.muted)),
          if (keys.length > 1) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final k in keys) ...[
                    _Chip(
                      label: monthName(k),
                      selected: k == key,
                      onTap: () => setState(() => _month = k),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (months.hasError) {
      return Column(
        children: [
          header,
          Expanded(
            child: LibraryErrorView(
              error: months.error!,
              onRetry: () => ref.invalidate(listenMonthsProvider),
            ),
          ),
        ],
      );
    }
    if (!months.hasValue) {
      return Column(
        children: [
          header,
          const Expanded(child: SizedBox()),
        ],
      );
    }
    if (month.seconds == 0) {
      return Column(
        children: [
          header,
          Expanded(
            child: LibraryMessage(
              icon: PhosphorRegular.calendarBlank,
              title: t.recapEmpty,
              body: t.recapEmptyBody,
            ),
          ),
        ],
      );
    }

    final top = ref.watch(monthTopTracksProvider(key)).value ?? const [];
    final best = month.bestDay;
    final dayName = DateFormat.MMMMEEEEd(locale);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final maxDay = month.days.values.fold<int>(1, math.max);
    final artists = month.topArtists.take(5).toList();
    final maxArtist = artists.isEmpty ? 1 : artists.first.value;

    Widget card({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: c.brightness == Brightness.dark
            ? c.surface
            : Color.lerp(c.bg, c.fg, 0.07),
        borderRadius: BorderRadius.circular(32),
      ),
      child: child,
    );

    final sub = MmType.body.copyWith(fontSize: 14.5, color: c.fgSoft);
    final title = MmType.title.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation.weight(600)],
      color: c.fg,
    );

    final children = <Widget>[
      card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(monthName(key), style: sub),
            Text(
              durationWords(month.seconds.toDouble()),
              style: MmType.displayXl.copyWith(
                fontSize: 40,
                height: 1.15,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(600)],
                color: c.fg,
              ),
            ),
            const SizedBox(height: 4),
            Text(t.recapDays(month.activeDays), style: sub),
            if (best != null)
              Text(
                t.recapBestDay(
                  dayName.format(DateTime(first.year, first.month, best.key)),
                ),
                style: sub,
              ),
            const SizedBox(height: 18),
            // One bar per day of the month.
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var d = 1; d <= daysInMonth; d++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          height: (month.days[d] ?? 0) == 0
                              ? 4
                              : math.max(8, 86 * month.days[d]! / maxDay),
                          decoration: BoxDecoration(
                            color: (month.days[d] ?? 0) == 0
                                ? c.fg.withValues(alpha: 0.14)
                                : (best?.key == d
                                      ? c.fg
                                      : c.fg.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (artists.isNotEmpty) ...[
        const SizedBox(height: 12),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.yourArtists, style: title),
              const SizedBox(height: 14),
              for (final (i, a) in artists.indexed) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${i + 1}',
                        style: MmType.labelStrong.copyWith(color: c.muted),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MmType.body.copyWith(color: c.fg),
                                ),
                              ),
                              Text(
                                durationWords(a.value.toDouble()),
                                style: MmType.label.copyWith(color: c.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: a.value / maxArtist,
                              minHeight: 6,
                              color: c.coralStrong,
                              backgroundColor: c.fg.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
      if (top.isNotEmpty) ...[
        const SizedBox(height: 12),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t.recapTopTracks, style: title)),
                  Pressable(
                    onTap: () => _play(top, 0),
                    semanticLabel: t.recapPlayTop,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: c.coral,
                        borderRadius: BorderRadius.circular(MmRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorFill.play, size: 16, color: c.coralInk),
                          const SizedBox(width: 6),
                          Text(
                            t.recapPlayTop,
                            style: MmType.labelStrong.copyWith(
                              color: c.coralInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final (i, (item, secs)) in top.indexed)
                Pressable(
                  onTap: () => _play(top, i),
                  semanticLabel: item.title,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${i + 1}',
                            style: MmType.labelStrong.copyWith(color: c.muted),
                          ),
                        ),
                        CoverArt(
                          size: 48,
                          radius: 12,
                          seed: item.id,
                          imagePath: item.thumbnail,
                          shadow: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.body.copyWith(color: c.fg),
                              ),
                              Text(
                                item.artist ?? t.unknownArtist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.label.copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          durationWords(secs.toDouble()),
                          style: MmType.label.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ];

    return ListView(
      padding: EdgeInsets.only(bottom: 120),
      children: [
        header,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _play(List<(LibraryItem, int)> top, int start) {
    HapticFeedback.selectionClick();
    final t = L10n.of(context);
    ref
        .read(queueProvider.notifier)
        .playAll(
          [
            for (final (item, _) in top)
              queueEntryOf(item, unknownArtist: t.unknownArtist),
          ],
          start: start,
          inOrder: true,
        );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: MmMotion.of(context).state,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? c.fg : null,
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: selected ? c.fg : c.lineStrong),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: MmType.labelStrong.copyWith(
              fontSize: 13,
              color: selected ? c.bg : c.fgSoft,
            ),
          ),
        ),
      ),
    );
  }
}
