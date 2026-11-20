import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../playback/playback.dart';
import '../playlists/playlists_screen.dart' show showAddToPlaylistDialog;

/// Queue (W-M3 « File », A-03b): the current entry, then what comes next,
/// reordered with the handle (or Alt+↑/↓), removed with ×.
class QueueView extends ConsumerWidget {
  const QueueView({
    super.key,
    this.rowHeight = 50,
    this.padding = const EdgeInsets.fromLTRB(4, 12, 4, 12),
  });

  final double rowHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final q = ref.watch(queueProvider);
    final queue = ref.read(queueProvider.notifier);
    final current = q.current;
    final upcoming = q.upcoming;
    Widget label(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: MmType.overline.copyWith(color: c.muted),
            ),
          ),
          ?trailing,
        ],
      ),
    );

    // "Enregistrer en playlist": the whole queue in play order, files of the
    // library only (a stream or a file outside it has no place there).
    final saved = [
      for (final i in q.order)
        if (q.entries[i].libraryId != null) q.entries[i].libraryId!,
    ];

    return Padding(
      padding: padding,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (current != null) ...[
                  SliverToBoxAdapter(child: label(t.nowCurrent)),
                  SliverToBoxAdapter(
                    child: Container(
                      height: rowHeight + 4,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(MmRadius.lg),
                      ),
                      child: Row(
                        children: [
                          CoverArt(
                            size: 36,
                            radius: 8,
                            seed: current.seed,
                            shadow: false,
                            child: Icon(
                              PhosphorFill.equalizer,
                              size: 16,
                              color: c.coralStrong,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Titles(entry: current, highlight: true),
                          ),
                          if (current.duration != null)
                            Text(
                              formatClock(current.duration!),
                              style: MmType.monoStyle(size: 12, color: c.muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                SliverToBoxAdapter(
                  child: label(
                    t.upNext,
                    trailing: upcoming.isEmpty
                        ? null
                        : Pressable(
                            onTap: queue.clearUpcoming,
                            semanticLabel: t.clearQueue,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                t.clearQueue,
                                style: MmType.captionStrong.copyWith(
                                  color: c.muted,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                if (upcoming.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        t.upNextEmpty,
                        style: MmType.bodySm.copyWith(color: c.muted),
                      ),
                    ),
                  )
                else
                  SliverReorderableList(
                    itemCount: upcoming.length,
                    onReorderItem: queue.moveUpcoming,
                    proxyDecorator: (child, index, anim) => Material(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(MmRadius.md),
                          border: Border.all(color: c.accent),
                          boxShadow: MmShadows.menu,
                        ),
                        child: child,
                      ),
                    ),
                    itemBuilder: (context, i) => _UpcomingRow(
                      key: ValueKey('${upcoming[i].source.uri}#$i'),
                      index: i,
                      entry: upcoming[i],
                      height: rowHeight,
                      onPlay: () => queue.playUpcoming(i),
                      onRemove: () => queue.removeUpcoming(i),
                      onMove: (delta) => queue.moveUpcoming(
                        i,
                        (i + delta).clamp(0, upcoming.length - 1),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverToBoxAdapter(
                  child: _SmartQueueCard(
                    title: t.smartQueueTitle,
                    body: t.smartQueueBody,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: _SaveButton(
              label: t.saveAsPlaylist,
              onTap: saved.isEmpty
                  ? null
                  : () => showAddToPlaylistDialog(context, ref, saved),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width pill under the queue (mockup W-M3 « File »).
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: c.fg.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(MmRadius.pill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorRegular.listPlus, size: 17, color: c.fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: MmType.captionStrong.copyWith(
                  fontSize: 12.5,
                  color: c.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles({required this.entry, this.highlight = false});

  final QueueEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MmType.labelStrong.copyWith(
            color: highlight ? c.coralStrong : c.fg,
          ),
        ),
        if (entry.subtitle != null)
          Text(
            entry.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MmType.caption.copyWith(color: c.fgSoft),
          ),
      ],
    );
  }
}

class _UpcomingRow extends StatefulWidget {
  const _UpcomingRow({
    super.key,
    required this.index,
    required this.entry,
    required this.height,
    required this.onPlay,
    required this.onRemove,
    required this.onMove,
  });

  final int index;
  final QueueEntry entry;
  final double height;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  final ValueChanged<int> onMove;

  @override
  State<_UpcomingRow> createState() => _UpcomingRowState();
}

class _UpcomingRowState extends State<_UpcomingRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent || !HardwareKeyboard.instance.isAltPressed) {
            return KeyEventResult.ignored;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onMove(-1);
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onMove(1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Pressable(
          onTap: () {},
          onDoubleTap: widget.onPlay,
          semanticLabel: widget.entry.title,
          pressScale: 1,
          hoverColor: c.cardHover,
          borderRadius: BorderRadius.circular(MmRadius.md),
          child: SizedBox(
            height: widget.height,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: SizedBox(
                      width: 28,
                      child: Icon(
                        PhosphorRegular.dotsSixVertical,
                        size: 18,
                        color: c.faint,
                      ),
                    ),
                  ),
                ),
                CoverArt(
                  size: 36,
                  radius: 8,
                  seed: widget.entry.seed,
                  shadow: false,
                ),
                const SizedBox(width: 12),
                Expanded(child: _Titles(entry: widget.entry)),
                if (_hover)
                  Pressable(
                    onTap: widget.onRemove,
                    semanticLabel: t.removeFromQueue,
                    tooltip: t.removeFromQueue,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(PhosphorRegular.x, size: 16, color: c.muted),
                    ),
                  )
                else if (widget.entry.duration != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      formatClock(widget.entry.duration!),
                      style: MmType.monoStyle(size: 12, color: c.muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Smart Queue is P1: shown where users look for it, marked and inert.
class _SmartQueueCard extends StatelessWidget {
  const _SmartQueueCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(color: c.lineStrong),
      ),
      child: Row(
        children: [
          Icon(PhosphorRegular.magicWand, size: 20, color: c.faint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MmType.labelStrong.copyWith(color: c.muted)),
                Text(body, style: MmType.caption.copyWith(color: c.faint)),
              ],
            ),
          ),
          const PlannedBadge(),
        ],
      ),
    );
  }
}

/// "P1": visible in the design, not delivered yet (Handoff §06).
class PlannedBadge extends StatelessWidget {
  const PlannedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.warning,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'P1',
        style: MmType.monoStyle(size: 10, weight: 700, color: c.warningInk),
      ),
    );
  }
}
