import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/cinema_widgets.dart' show PillSegment;
import 'get_data.dart';
import 'get_screens.dart' show bytes, failureReason, revealProvider;

final _audioFormats = RegExp(
  r'^(MP3|FLAC|M4A|OPUS|OGG|WAV|AAC|ALAC|VORBIS)\b',
  caseSensitive: false,
);

/// Obtenir › Historique (Windows v2 screen 10, ported from the Tauri app):
/// finished, failed and cancelled downloads grouped by day. The "Lectures"
/// side is the Listen space's history (W-03), already in the app.
class GetHistoryScreen extends ConsumerStatefulWidget {
  const GetHistoryScreen({super.key});

  @override
  ConsumerState<GetHistoryScreen> createState() => _GetHistoryScreenState();
}

class _GetHistoryScreenState extends ConsumerState<GetHistoryScreen> {
  // Day labels move on at midnight.
  late final Timer _minute = Timer.periodic(
    const Duration(minutes: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _minute;
  }

  @override
  void dispose() {
    _minute.cancel();
    super.dispose();
  }

  Future<void> _confirmClear() async {
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
          t.getClearDlTitle,
          style: MmType.title.copyWith(color: c.fg),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            t.getClearDlBody,
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
              t.getClearHistory,
              style: MmType.labelStrong.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(downloadsProvider.notifier).clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final history = ref.watch(downloadsProvider.select((s) => s.history));
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayFormat = DateFormat.MMMMEEEEd(locale);

    String dayLabel(DateTime d) {
      final diff = today.difference(d).inDays;
      if (diff == 0) return t.getToday;
      if (diff == 1) return t.getYesterday;
      return dayFormat.format(d);
    }

    final groups = <DateTime, List<HistoryInfo>>{};
    for (final h in history) {
      final at = DateTime.fromMillisecondsSinceEpoch(h.finishedAt);
      (groups[DateTime(at.year, at.month, at.day)] ??= []).add(h);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.getNavHistory,
                style: MmType.display.copyWith(fontSize: 24, color: c.fg),
              ),
            ),
            PillSegment<String>(
              values: [
                ('downloads', t.getHistDownloads),
                ('plays', t.getHistPlays),
              ],
              selected: 'downloads',
              // The plays are the Listen space's history (W-03).
              onChanged: (v) {
                if (v == 'plays') context.go(Routes.history);
              },
            ),
            const SizedBox(width: 12),
            Pressable(
              onTap: history.isEmpty ? null : _confirmClear,
              semanticLabel: t.getClearHistory,
              child: Opacity(
                opacity: history.isEmpty ? 0.5 : 1,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(MmRadius.sm),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorRegular.trash, size: 18, color: c.fg),
                      const SizedBox(width: 6),
                      Text(
                        t.getClearHistory,
                        style: MmType.labelStrong.copyWith(
                          fontSize: 13,
                          color: c.fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final MapEntry(key: day, value: entries) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              dayLabel(day).toUpperCase(),
              style: MmType.overline.copyWith(color: c.faint),
            ),
          ),
          for (final h in entries) ...[
            _HistoryRow(entry: h),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 14),
        ],
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MmRadius.md),
              border: Border.all(color: c.lineStrong),
            ),
            child: Text(
              t.getHistEmptyDl,
              textAlign: TextAlign.center,
              style: MmType.bodySm.copyWith(color: c.muted),
            ),
          )
        else
          Text(t.getHistNoteDl, style: MmType.caption.copyWith(color: c.muted)),
      ],
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry});

  final HistoryInfo entry;

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final at = DateTime.fromMillisecondsSinceEpoch(entry.finishedAt);
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final failed = !entry.completed && !entry.canceled;
    final icon = entry.completed
        ? (_audioFormats.hasMatch(entry.formatLabel)
              ? PhosphorRegular.musicNote
              : PhosphorRegular.filmStrip)
        : failed
        ? PhosphorRegular.warningCircle
        : PhosphorRegular.x;
    final size = entry.totalBytes ?? entry.doneBytes;
    final meta = entry.completed
        ? [
            entry.formatLabel,
            if (size > BigInt.zero) bytes(context, size.toInt()),
            entry.sourceHost,
          ].where((s) => s.isNotEmpty).join(' · ')
        : failed
        ? (entry.reason == null
              ? t.getStFailed
              : t.getFailedBecause(failureReason(entry.reason, t)!))
        : '${t.getStCanceled} · ${entry.sourceHost}';
    final path = entry.finalPath;

    // A failed task still exists and keeps its format; anything else is
    // analyzed again from its source link.
    void retry() {
      final task = ref.read(downloadsProvider).tasks[entry.taskId];
      if (task?.state == 'failed') {
        ref.read(downloadsProvider.notifier).action(task!.id, 'retry');
      } else {
        context.go(
          Uri(
            path: Routes.getAnalysis,
            queryParameters: {'url': entry.url},
          ).toString(),
        );
      }
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              time,
              style: MmType.monoStyle(size: 12, color: c.muted),
            ),
          ),
          const SizedBox(width: 14),
          Icon(icon, size: 20, color: failed ? c.danger : c.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.labelStrong.copyWith(fontSize: 13.5, color: c.fg),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: MmType.monoStyle(size: 11.5, color: c.muted),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: t.getActionsFor(entry.title),
            icon: Icon(PhosphorRegular.dotsThree, size: 18, color: c.muted),
            color: c.surface2,
            onSelected: (v) async {
              switch (v) {
                case 'reveal':
                  if (path != null) {
                    await ref.read(revealProvider)(path, select: true);
                  }
                case 'retry':
                  retry();
                case 'copy':
                  await Clipboard.setData(ClipboardData(text: entry.url));
                  if (context.mounted) _toast(context, t.getLinkCopied);
              }
            },
            itemBuilder: (context) => [
              if (entry.completed)
                PopupMenuItem(
                  value: 'reveal',
                  enabled: path != null,
                  child: Text(t.getShowInFolder),
                )
              else
                PopupMenuItem(value: 'retry', child: Text(t.getTryAgain)),
              PopupMenuItem(value: 'copy', child: Text(t.getCopySourceLink)),
            ],
          ),
        ],
      ),
    );
  }
}
