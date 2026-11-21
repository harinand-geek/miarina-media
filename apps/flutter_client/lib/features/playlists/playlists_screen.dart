import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../../src/rust/api/playlists.dart';
import '../focus/focus_screen.dart' show shortDuration;
import '../library/groups.dart';
import '../library/library_data.dart';
import '../now_playing/sound_view.dart' show MmSwitch;
import '../playback/playback.dart';
import '../settings/settings_screen.dart' show P1Badge;
import 'playlists_data.dart';

String ago(L10n t, int millis) {
  final d = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(millis),
  );
  if (d.inMinutes < 1) return t.agoNow;
  if (d.inHours < 1) return t.agoMinutes(d.inMinutes);
  if (d.inDays < 1) return t.agoHours(d.inHours);
  return t.agoDays(d.inDays);
}

String playlistLine(L10n t, PlaylistInfo p, {int missing = 0}) => [
  t.titlesCount(p.count),
  if (p.durationSecs >= 60)
    shortDuration(Duration(seconds: p.durationSecs.round())),
  if (missing > 0) t.missingCount(missing),
].join(' · ');

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

void openPlaylist(BuildContext context, WidgetRef ref, int id) {
  if (ref.read(desktopShellProvider)) {
    context.go(
      Uri(path: Routes.playlists, queryParameters: {'id': '$id'}).toString(),
    );
  } else {
    context.push(
      Uri(path: Routes.playlist, queryParameters: {'id': '$id'}).toString(),
    );
  }
}

/// 2 × 2 mosaic of the first covers (or the logo placeholder).
class PlaylistMosaic extends StatelessWidget {
  const PlaylistMosaic({
    super.key,
    required this.covers,
    required this.size,
    required this.seed,
  });

  final List<String> covers;
  final double size;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final half = size / 2;
    if (covers.length < 4) {
      return CoverArt(
        size: size,
        radius: size > 80 ? MmRadius.card : MmRadius.sm,
        seed: seed,
        imagePath: covers.firstOrNull,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        size > 80 ? MmRadius.card : MmRadius.sm,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Wrap(
          children: [
            for (final (i, c) in covers.take(4).indexed)
              CoverArt(
                size: half,
                radius: 0,
                shadow: false,
                seed: seed + i,
                imagePath: c,
              ),
          ],
        ),
      ),
    );
  }
}

/// W-M5 Playlists (Windows: list and open playlist side by side) and the
/// Android list (A-02c).
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key, this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = !ref.watch(desktopShellProvider);
    final lists = ref.watch(playlistsProvider);
    final all = lists.value ?? const <PlaylistInfo>[];
    final current =
        all.where((p) => p.id == selected).firstOrNull ?? all.firstOrNull;

    final list = _PlaylistList(
      playlists: all,
      selected: mobile ? null : current?.id,
      mobile: mobile,
      loading: !lists.hasValue,
    );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Text(
              t.navPlaylists,
              style: MmType.titleLg.copyWith(fontSize: 20, color: c.fg),
            ),
          ),
          const MusicChips(current: Routes.playlists),
          const SizedBox(height: 12),
          Expanded(child: list),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: c.divider)),
          ),
          child: list,
        ),
        Expanded(
          child: current == null
              ? (lists.hasValue
                    ? LibraryMessage(
                        icon: PhosphorRegular.playlist,
                        title: t.playlistsEmptyTitle,
                        body: t.playlistsEmptyBody,
                      )
                    : const SizedBox.shrink())
              : PlaylistView(
                  key: ValueKey(current.id),
                  id: current.id,
                  mobile: false,
                ),
        ),
      ],
    );
  }
}

class _PlaylistList extends ConsumerWidget {
  const _PlaylistList({
    required this.playlists,
    required this.selected,
    required this.mobile,
    required this.loading,
  });

  final List<PlaylistInfo> playlists;
  final int? selected;
  final bool mobile;
  final bool loading;

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final t = L10n.of(context);
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: t.playlistFileType,
          extensions: const ['m3u', 'm3u8'],
        ),
      ],
    );
    if (file == null || !context.mounted) return;
    try {
      final r = await editPlaylists(ref, (api) => api.importM3u(file.path));
      if (!context.mounted) return;
      _toast(context, t.importDone(r.playlist.name, r.added, r.skipped));
      openPlaylist(context, ref, r.playlist.id);
    } catch (e) {
      if (context.mounted) _toast(context, t.playlistActionFailed('$e'));
    }
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    PlaylistInfo p,
  ) async {
    final t = L10n.of(context);
    final target = await getSaveLocation(
      suggestedName: '${p.name}.m3u8',
      acceptedTypeGroups: [
        XTypeGroup(label: t.playlistFileType, extensions: const ['m3u8']),
      ],
    );
    if (target == null) return;
    try {
      await ref.read(playlistApiProvider).exportM3u(p.id, target.path);
      if (context.mounted) _toast(context, t.exportDone(target.path));
    } catch (e) {
      if (context.mounted) _toast(context, t.playlistActionFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final current = playlists.where((p) => p.id == selected).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 16 : 20,
            mobile ? 0 : 22,
            mobile ? 16 : 14,
            12,
          ),
          child: Row(
            children: [
              if (!mobile)
                Expanded(
                  child: Text(
                    t.navPlaylists,
                    style: MmType.titleLg.copyWith(color: c.fg),
                  ),
                )
              else
                const Spacer(),
              _Button(
                label: t.playlistNew,
                icon: PhosphorRegular.plus,
                onTap: () => showNewPlaylistDialog(context, ref),
              ),
            ],
          ),
        ),
        Expanded(
          child: playlists.isEmpty && !loading
              ? (mobile
                    ? LibraryMessage(
                        icon: PhosphorRegular.playlist,
                        title: t.playlistsEmptyTitle,
                        body: t.playlistsEmptyBody,
                      )
                    : const SizedBox.shrink())
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 10),
                  children: [
                    for (final p in playlists)
                      Pressable(
                        onTap: () => openPlaylist(context, ref, p.id),
                        selected: p.id == selected,
                        semanticLabel: p.name,
                        borderRadius: BorderRadius.circular(MmRadius.lg),
                        hoverColor: c.cardHover,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: p.id == selected
                                ? c.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(MmRadius.lg),
                          ),
                          child: Row(
                            children: [
                              PlaylistMosaic(
                                covers: p.covers,
                                size: mobile ? 52 : 44,
                                seed: p.id,
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
                                      style: MmType.labelStrong.copyWith(
                                        color: c.fg,
                                      ),
                                    ),
                                    Text(
                                      playlistLine(t, p),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: MmType.caption.copyWith(
                                        color: c.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 16 : 20,
            8,
            mobile ? 16 : 20,
            16,
          ),
          child: Row(
            children: [
              Expanded(
                child: _Button(
                  label: t.playlistImport,
                  icon: PhosphorRegular.fileArrowUp,
                  onTap: () => _import(context, ref),
                  expand: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Button(
                  label: t.playlistExport,
                  icon: PhosphorRegular.export,
                  expand: true,
                  onTap: current == null
                      ? null
                      : () => _export(context, ref, current),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final fg = primary ? c.coralInk : c.fg;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressScale: 0.97,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: primary ? 42 : 36,
          padding: EdgeInsets.symmetric(horizontal: primary ? 18 : 14),
          decoration: BoxDecoration(
            color: primary ? c.coral : Colors.transparent,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: primary ? null : Border.all(color: c.lineStrong),
            boxShadow: primary ? MmShadows.playHalo : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: primary ? 20 : 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.labelStrong.copyWith(
                    fontSize: primary ? 14 : 13,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One playlist: header, Play / Add tracks, rows in order. Drag or
/// Alt+↑/↓ to reorder, Del to remove (the file stays), Enter to play.
class PlaylistView extends ConsumerStatefulWidget {
  const PlaylistView({super.key, required this.id, required this.mobile});

  final int id;
  final bool mobile;

  @override
  ConsumerState<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends ConsumerState<PlaylistView> {
  int? _selected;
  final _focus = FocusNode(debugLabel: 'playlist');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _play(List<LibraryItem> items, [int start = 0]) async {
    final t = L10n.of(context);
    final playable = [
      for (final (i, item) in items.indexed)
        if (!item.missing || i == start) (i, item),
    ];
    final first = playable.indexWhere((e) => e.$1 == start);
    await ref
        .read(queueProvider.notifier)
        .playAll(
          [
            for (final (_, item) in playable)
              queueEntryOf(item, unknownArtist: t.unknownArtist),
          ],
          start: first < 0 ? 0 : first,
          inOrder: true,
        );
  }

  Future<void> _move(int from, int to) async {
    setState(() => _selected = to);
    await editPlaylists(
      ref,
      (api) => api.move(widget.id, from, to),
      id: widget.id,
    );
  }

  Future<void> _remove(int index, int count) async {
    setState(() => _selected = count <= 1 ? null : index.clamp(0, count - 2));
    await editPlaylists(
      ref,
      (api) => api.remove(widget.id, index),
      id: widget.id,
    );
  }

  KeyEventResult _onKey(List<LibraryItem> items, KeyEvent e) {
    final i = _selected;
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final alt = HardwareKeyboard.instance.isAltPressed;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowUp) {
      final d = k == LogicalKeyboardKey.arrowDown ? 1 : -1;
      if (i == null) {
        setState(() => _selected = 0);
      } else if (alt) {
        final to = (i + d).clamp(0, items.length - 1);
        if (to != i) _move(i, to);
      } else {
        setState(() => _selected = (i + d).clamp(0, items.length - 1));
      }
      return KeyEventResult.handled;
    }
    if (i == null) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.delete && e is KeyDownEvent) {
      _remove(i, items.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter && e is KeyDownEvent) {
      _play(items, i);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final detail = ref.watch(playlistProvider(widget.id));
    final d = detail.value;
    if (d == null) {
      return detail.hasValue
          ? LibraryMessage(
              icon: PhosphorRegular.playlist,
              title: t.playlistsEmptyTitle,
              body: t.playlistsEmptyBody,
            )
          : const SizedBox.shrink();
    }
    final items = d.items;
    final missing = items.where((i) => i.missing).length;
    final playing = ref.watch(
      queueProvider.select((q) => q.current?.libraryId),
    );
    final mobile = widget.mobile;
    final pad = mobile ? 16.0 : 28.0;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, mobile ? 8 : 22, pad, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PlaylistMosaic(
            covers: d.info.covers,
            size: mobile ? 96 : 132,
            seed: d.info.id,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t
                      .playlistModified(ago(t, d.info.updatedAt.toInt()))
                      .toUpperCase(),
                  style: MmType.overline.copyWith(color: c.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  d.info.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.displayXl.copyWith(
                    fontSize: mobile ? 24 : 34,
                    color: c.fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  playlistLine(t, d.info, missing: missing),
                  style: MmType.bodySm.copyWith(color: c.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Button(
                      label: t.playVerb,
                      icon: PhosphorFill.play,
                      primary: true,
                      onTap: items.isEmpty ? null : () => _play(items),
                    ),
                    _Button(
                      label: t.addTracks,
                      icon: PhosphorRegular.plus,
                      onTap: () => showAddTracksDialog(context, ref, widget.id),
                    ),
                    _PlaylistMenu(info: d.info),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final rows = items.isEmpty
        ? SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
              child: Text(
                t.playlistEmpty,
                style: MmType.bodySm.copyWith(color: c.muted),
              ),
            ),
          )
        : SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pad - 6),
            sliver: SliverReorderableList(
              itemCount: items.length,
              onReorderItem: _move,
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
              itemBuilder: (context, i) => _Row(
                key: ValueKey('${items[i].id}#$i'),
                index: i,
                item: items[i],
                selected: _selected == i,
                playing: playing == items[i].id,
                mobile: mobile,
                onTap: () {
                  setState(() => _selected = i);
                  _focus.requestFocus();
                },
                onPlay: () => _play(items, i),
                onRemove: () => _remove(i, items.length),
                onMove: (delta) {
                  final to = (i + delta).clamp(0, items.length - 1);
                  if (to != i) _move(i, to);
                },
              ),
            ),
          );

    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, e) => _onKey(items, e),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          rows,
          if (items.isNotEmpty && !mobile)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 14, pad, 24),
                child: Text(
                  t.playlistHint,
                  style: MmType.caption.copyWith(color: c.faint),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.index,
    required this.item,
    required this.selected,
    required this.playing,
    required this.mobile,
    required this.onTap,
    required this.onPlay,
    required this.onRemove,
    required this.onMove,
  });

  final int index;
  final LibraryItem item;
  final bool selected;
  final bool playing;
  final bool mobile;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final d = item.durationSecs;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: t.moveUp): () => onMove(-1),
          CustomSemanticsAction(label: t.moveDown): () => onMove(1),
          CustomSemanticsAction(label: t.removeFromPlaylist): onRemove,
        },
        child: Pressable(
          onTap: mobile ? onPlay : onTap,
          onDoubleTap: mobile ? null : onPlay,
          selected: selected,
          semanticLabel: item.title,
          borderRadius: BorderRadius.circular(MmRadius.md),
          hoverColor: c.cardHover,
          child: Opacity(
            opacity: item.missing ? 0.72 : 1,
            child: Container(
              height: mobile ? 60 : 48,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? c.selected : Colors.transparent,
                borderRadius: BorderRadius.circular(MmRadius.md),
                border: Border.all(
                  color: selected ? c.accent : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: SizedBox(
                        width: 24,
                        child: Icon(
                          PhosphorRegular.dotsSixVertical,
                          size: 16,
                          color: c.faint,
                        ),
                      ),
                    ),
                  ),
                  CoverArt(
                    size: 36,
                    radius: MmRadius.sm,
                    shadow: false,
                    seed: item.id,
                    imagePath: item.thumbnail,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.labelStrong.copyWith(
                            color: playing ? c.coralHover : c.fg,
                          ),
                        ),
                        Text(
                          item.missing
                              ? t.fileMissing
                              : (item.artist ?? t.unknownArtist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.caption.copyWith(
                            color: item.missing ? c.warning : c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!mobile)
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.album ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.bodySm.copyWith(color: c.muted),
                      ),
                    ),
                  if (d != null)
                    SizedBox(
                      width: 56,
                      child: Text(
                        formatClock(Duration(milliseconds: (d * 1000).round())),
                        textAlign: TextAlign.right,
                        style: MmType.monoStyle(size: 11.5, color: c.muted),
                      ),
                    ),
                  Pressable(
                    onTap: onRemove,
                    tooltip: t.removeFromPlaylist,
                    semanticLabel: '${t.removeFromPlaylist} ${item.title}',
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        PhosphorRegular.minusCircle,
                        size: 16,
                        color: c.faint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistMenu extends ConsumerWidget {
  const _PlaylistMenu({required this.info});

  final PlaylistInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface2),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MmRadius.lg),
            side: BorderSide(color: c.overlayBorder),
          ),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => showRenameDialog(context, ref, info),
          child: Text(t.rename, style: MmType.label.copyWith(color: c.fg)),
        ),
        MenuItemButton(
          onPressed: () => confirmDeletePlaylist(context, ref, info),
          child: Text(
            t.deletePlaylist,
            style: MmType.label.copyWith(color: c.danger),
          ),
        ),
      ],
      builder: (context, menu, _) => Pressable(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        tooltip: t.moreOptions,
        semanticLabel: t.moreOptions,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.lineStrong),
          ),
          child: Icon(PhosphorRegular.dotsThree, size: 20, color: c.fg),
        ),
      ),
    );
  }
}

Future<T?> _dialog<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  required List<Widget> actions,
}) {
  final c = MmColors.of(context);
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        side: BorderSide(color: c.overlayBorder),
      ),
      title: Text(title, style: MmType.title.copyWith(color: c.fg)),
      content: SizedBox(width: 440, child: body),
      actions: actions,
    ),
  );
}

InputDecoration _fieldDecoration(MmColors c, {String? hint, IconData? icon}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: MmType.body.copyWith(color: c.faint),
      prefixIcon: icon == null ? null : Icon(icon, size: 16, color: c.faint),
      filled: true,
      fillColor: c.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MmRadius.md),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MmRadius.md),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MmRadius.md),
        borderSide: BorderSide(color: c.accent),
      ),
    );

/// "Nouvelle playlist": a name, optionally the tracks of the queue.
Future<void> showNewPlaylistDialog(BuildContext context, WidgetRef ref) async {
  final queued = [
    for (final e in ref.read(queueProvider).entries)
      if (e.libraryId != null) e.libraryId!,
  ];
  final created = await showDialog<PlaylistInfo>(
    context: context,
    builder: (context) => _NameDialog(
      create: true,
      queued: queued,
      onSave: (name, withQueue) => editPlaylists(
        ref,
        (api) => api.create(name, withQueue ? queued : const []),
      ),
    ),
  );
  if (created != null && context.mounted) {
    openPlaylist(context, ref, created.id);
  }
}

/// "Ajouter à une playlist…": [mediaIds] go at the end of a chosen playlist,
/// or into a new one. Says what was done.
Future<void> showAddToPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  List<int> mediaIds,
) async {
  if (mediaIds.isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = L10n.of(context);
  final chosen = await showDialog<_PlaylistChoice>(
    context: context,
    builder: (context) => const _AddToPlaylistDialog(),
  );
  if (chosen == null || !context.mounted) return;
  PlaylistInfo? target = chosen.playlist;
  if (target == null) {
    target = await showDialog<PlaylistInfo>(
      context: context,
      builder: (context) => _NameDialog(
        create: true,
        onSave: (name, _) =>
            editPlaylists(ref, (api) => api.create(name, mediaIds)),
      ),
    );
    if (target == null) return;
  } else {
    final id = target.id;
    await editPlaylists(ref, (api) => api.add(id, mediaIds), id: id);
  }
  messenger?.showSnackBar(
    SnackBar(content: Text(t.playlistAddDone(mediaIds.length, target.name))),
  );
}

/// A playlist, or null for "Nouvelle playlist…".
class _PlaylistChoice {
  const _PlaylistChoice(this.playlist);

  final PlaylistInfo? playlist;
}

class _AddToPlaylistDialog extends ConsumerWidget {
  const _AddToPlaylistDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final lists = ref.watch(playlistsProvider).value ?? const <PlaylistInfo>[];
    Widget row(IconData icon, String label, String? sub, _PlaylistChoice v) =>
        Pressable(
          onTap: () => Navigator.of(context).pop(v),
          semanticLabel: label,
          borderRadius: BorderRadius.circular(MmRadius.md),
          hoverColor: c.cardHover,
          pressScale: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 18, color: c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.label.copyWith(color: c.fg),
                  ),
                ),
                if (sub != null)
                  Text(sub, style: MmType.caption.copyWith(color: c.faint)),
              ],
            ),
          ),
        );
    return AlertDialog(
      backgroundColor: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        side: BorderSide(color: c.overlayBorder),
      ),
      title: Text(
        t.addToPlaylistTitle,
        style: MmType.title.copyWith(color: c.fg),
      ),
      content: SizedBox(
        width: 400,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView(
            shrinkWrap: true,
            children: [
              row(
                PhosphorRegular.plus,
                t.newPlaylistEllipsis,
                null,
                const _PlaylistChoice(null),
              ),
              for (final p in lists)
                row(
                  PhosphorRegular.playlist,
                  p.name,
                  t.tracksSummary(p.count),
                  _PlaylistChoice(p),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.cancel,
            style: MmType.labelStrong.copyWith(color: c.fg),
          ),
        ),
      ],
    );
  }
}

Future<void> showRenameDialog(
  BuildContext context,
  WidgetRef ref,
  PlaylistInfo p,
) => showDialog<void>(
  context: context,
  builder: (context) => _NameDialog(
    create: false,
    initial: p.name,
    onSave: (name, _) async {
      await editPlaylists(ref, (api) => api.rename(p.id, name), id: p.id);
      return null;
    },
  ),
);

/// Name dialog of a new or renamed playlist. It owns its text field, so the
/// field lives as long as the dialog, closing animation included.
class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.create,
    required this.onSave,
    this.initial = '',
    this.queued = const [],
  });

  final bool create;
  final String initial;
  final List<int> queued;
  final Future<PlaylistInfo?> Function(String name, bool withQueue) onSave;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  late bool _withQueue = widget.queued.isNotEmpty;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final result = await widget.onSave(name, _withQueue);
    if (mounted) nav.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return AlertDialog(
      backgroundColor: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        side: BorderSide(color: c.overlayBorder),
      ),
      title: Text(
        widget.create ? t.newPlaylistTitle : t.rename,
        style: MmType.title.copyWith(color: c.fg),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.playlistName,
              style: MmType.labelStrong.copyWith(color: c.fg),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              autofocus: true,
              style: MmType.body.copyWith(color: c.fg),
              cursorColor: c.accent,
              decoration: _fieldDecoration(c),
              onSubmitted: (_) => _save(),
            ),
            if (widget.create && widget.queued.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.addQueue(widget.queued.length),
                      style: MmType.bodySm.copyWith(color: c.fg),
                    ),
                  ),
                  MmSwitch(
                    value: _withQueue,
                    label: t.addQueue(widget.queued.length),
                    onChanged: (v) => setState(() => _withQueue = v),
                  ),
                ],
              ),
            ],
            if (widget.create) ...[
              const SizedBox(height: 12),
              // P1: shown, not available yet (handoff rule).
              Opacity(
                opacity: 0.55,
                child: Row(
                  children: [
                    Text(
                      t.smartPlaylist,
                      style: MmType.bodySm.copyWith(color: c.fgSoft),
                    ),
                    const SizedBox(width: 8),
                    const P1Badge(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.cancel,
            style: MmType.labelStrong.copyWith(color: c.fg),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: const Color(0xFF062320),
          ),
          onPressed: _saving ? null : _save,
          child: Text(
            widget.create ? t.create : t.save,
            style: MmType.labelStrong,
          ),
        ),
      ],
    );
  }
}

Future<void> confirmDeletePlaylist(
  BuildContext context,
  WidgetRef ref,
  PlaylistInfo p,
) async {
  final t = L10n.of(context);
  final c = MmColors.of(context);
  final ok = await _dialog<bool>(
    context,
    title: t.deletePlaylistTitle(p.name),
    body: Text(
      t.deletePlaylistBody,
      style: MmType.body.copyWith(color: c.fgSoft),
    ),
    actions: [
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            t.cancel,
            style: MmType.labelStrong.copyWith(color: c.fg),
          ),
        ),
      ),
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            t.delete,
            style: MmType.labelStrong.copyWith(color: c.danger),
          ),
        ),
      ),
    ],
  );
  if (ok != true) return;
  await editPlaylists(ref, (api) => api.delete(p.id), id: p.id);
  if (!context.mounted) return;
  ref.read(desktopShellProvider)
      ? context.go(Routes.playlists)
      : (context.canPop() ? context.pop() : null);
}

/// "Ajouter des titres": search the tracks and add them one by one.
Future<void> showAddTracksDialog(
  BuildContext context,
  WidgetRef ref,
  int id,
) async {
  final t = L10n.of(context);
  await _dialog<void>(
    context,
    title: t.addTracks,
    body: SizedBox(height: 420, child: _AddTracks(id: id)),
    actions: [
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.close,
            style: MmType.labelStrong.copyWith(color: MmColors.of(context).fg),
          ),
        ),
      ),
    ],
  );
}

class _AddTracks extends ConsumerStatefulWidget {
  const _AddTracks({required this.id});

  final int id;

  @override
  ConsumerState<_AddTracks> createState() => _AddTracksState();
}

class _AddTracksState extends ConsumerState<_AddTracks> {
  String _query = '';
  List<LibraryItem> _items = const [];
  final _added = <int>{};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final page = await ref
        .read(libraryApiProvider)
        .tracks(search: _query, favoritesOnly: false, offset: 0, limit: 100);
    if (mounted) setState(() => _items = page.items);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          style: MmType.body.copyWith(color: c.fg),
          cursorColor: c.accent,
          decoration: _fieldDecoration(
            c,
            hint: t.searchPlaceholder,
            icon: PhosphorRegular.magnifyingGlass,
          ),
          onChanged: (v) {
            _query = v;
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 200), _load);
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      CoverArt(
                        size: 36,
                        radius: MmRadius.sm,
                        shadow: false,
                        seed: item.id,
                        imagePath: item.thumbnail,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.labelStrong.copyWith(color: c.fg),
                            ),
                            Text(
                              item.artist ?? t.unknownArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.caption.copyWith(color: c.muted),
                            ),
                          ],
                        ),
                      ),
                      _added.contains(item.id)
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                t.addedShort,
                                style: MmType.captionStrong.copyWith(
                                  color: c.accent,
                                ),
                              ),
                            )
                          : Pressable(
                              onTap: () async {
                                setState(() => _added.add(item.id));
                                await editPlaylists(
                                  ref,
                                  (api) => api.add(widget.id, [item.id]),
                                  id: widget.id,
                                );
                              },
                              semanticLabel: '${t.addTracks} ${item.title}',
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  PhosphorRegular.plus,
                                  size: 18,
                                  color: c.fg,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Android page of one playlist (A-02c).
class PlaylistPage extends ConsumerWidget {
  const PlaylistPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Pressable(
            onTap: () =>
                context.canPop() ? context.pop() : context.go(Routes.playlists),
            semanticLabel: t.back,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(PhosphorRegular.arrowLeft, size: 22, color: c.fg),
            ),
          ),
        ),
        Expanded(child: PlaylistView(id: id, mobile: true)),
      ],
    );
  }
}
