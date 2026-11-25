import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../playback/playing_bars.dart';
import '../device_media/device_media.dart';
import '../get/get_screens.dart' show revealProvider;
import '../health/health_data.dart';
import '../health/health_screens.dart' show locateMissing;
import '../playlists/playlists_screen.dart' show showAddToPlaylistDialog;
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../common/state_views.dart';
import '../../design/widgets/states.dart';
import '../../design/widgets/action_sheet.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../playback/playback.dart';
import '../settings/settings_data.dart';
import '../../app/router.dart';
import 'groups.dart';
import 'library_data.dart';
import 'phone_library.dart';
import 'tag_editor.dart';
import 'track_info.dart';

/// W-M1c Titres: every audio track of the library, sorted by title, in a
/// virtualised table loaded page by page. [favorites]: the Favoris entry of
/// the sidebar, the same table limited to favorite tracks (the "Favoris"
/// chip of Titres leads there).
class TracksScreen extends ConsumerStatefulWidget {
  const TracksScreen({super.key, this.favorites = false});

  final bool favorites;

  @override
  ConsumerState<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends ConsumerState<TracksScreen> {
  static const _pageSize = 200;
  final _items = <LibraryItem>[];
  int _total = 0;
  bool _loading = false;
  Object? _error;
  String _search = '';
  late final bool _favoritesOnly = widget.favorites;
  TrackSort _sort = TrackSort.title;
  bool _reverse = false;
  _Quick? _quick;

  /// Keyboard cursor (index into [_items]).
  int? _selected;

  /// Selected rows (library ids); [_anchor] starts Shift ranges.
  final _picked = <int>{};
  int? _anchor;
  int _generation = 0;
  Timer? _debounce;
  final _listFocus = FocusNode(debugLabel: 'tracks');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _listFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _total = 0;
      _selected = null;
      _picked.clear();
      _anchor = null;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(libraryApiProvider)
          .tracks(
            search: _search,
            favoritesOnly: _favoritesOnly,
            sort: _sort,
            reverse: _reverse,
            addedSince: _quick == _Quick.addedThisMonth
                ? _monthStart(DateTime.now())
                : null,
            neverPlayed: _quick == _Quick.neverPlayed,
            hiRes: _quick == _Quick.hiRes,
            offset: _items.length,
            limit: _pageSize,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total.toInt();
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _search = value.trim();
      _reload();
    });
  }

  void _play(int index) {
    final t = L10n.of(context);
    // W-O2: a missing file is located rather than played.
    if (_items[index].missing) {
      unawaited(locateMissing(context, ref, _items[index].id));
      return;
    }
    final entries = [
      for (final i in _items) queueEntryOf(i, unknownArtist: t.unknownArtist),
    ];
    ref.read(queueProvider.notifier).playAll(entries, start: index);
  }

  /// The selected rows in table order; the cursor row when none is.
  List<LibraryItem> get _chosen {
    if (_picked.isNotEmpty) {
      return [
        for (final i in _items)
          if (_picked.contains(i.id)) i,
      ];
    }
    final s = _selected;
    return s == null ? const [] : [_items[s]];
  }

  List<QueueEntry> _entries(List<LibraryItem> items) {
    final t = L10n.of(context);
    return [
      for (final i in items)
        if (!i.missing) queueEntryOf(i, unknownArtist: t.unknownArtist),
    ];
  }

  /// "Lire" on the selection: several rows play on their own, in order.
  void _playChosen() {
    final chosen = _chosen;
    if (chosen.length == 1) {
      _play(_items.indexOf(chosen.single));
    } else if (chosen.isNotEmpty) {
      ref.read(queueProvider.notifier).playAll(_entries(chosen), inOrder: true);
    }
  }

  Future<void> _enqueue({required bool next}) async {
    final entries = _entries(_chosen);
    if (entries.isEmpty) return;
    final t = L10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref.read(queueProvider.notifier).enqueue(entries, next: next);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          next
              ? t.playNextDone(entries.length)
              : t.queueAddDone(entries.length),
        ),
      ),
    );
  }

  Future<void> _addToPlaylist() =>
      showAddToPlaylistDialog(context, ref, [for (final i in _chosen) i.id]);

  /// « Modifier les tags » (Ctrl I): one row; the table shows the result.
  Future<void> _editTags() async {
    final chosen = _chosen;
    if (chosen.length != 1) return;
    final updated = await showTagEditor(context, chosen.single);
    if (updated == null || !mounted) return;
    ref
      ..invalidate(groupsProvider(GroupKind.album))
      ..invalidate(groupsProvider(GroupKind.artist));
    final i = _items.indexWhere((e) => e.id == updated.id);
    if (i >= 0) setState(() => _items[i] = updated);
  }

  Future<void> _reveal() async {
    final chosen = _chosen;
    if (chosen.length != 1) return;
    await ref.read(revealProvider)(chosen.single.path, select: true);
  }

  /// "Retirer…": out of the library after a confirmation; files stay.
  Future<void> _remove() async {
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MmRadius.sheet),
          side: BorderSide(color: c.overlayBorder),
        ),
        title: Text(
          t.missingRemoveTitle(chosen.length),
          style: MmType.title.copyWith(color: c.fg),
        ),
        content: SizedBox(
          width: 440,
          child: Text(
            t.missingRemoveBody,
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.remove, style: MmType.labelStrong),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(healthApiProvider).remove([for (final i in chosen) i.id]);
    ref
      ..invalidate(favoritesCountProvider)
      ..invalidate(healthCountsProvider);
    await _reload();
  }

  /// Ctrl / Shift as they were when the button went down: the click itself
  /// comes after the double-click delay, when they may be released.
  /// Per row: another row's pending click may land in between.
  final _downKeys = <int, (bool, bool)>{};

  void _pointerDown(int i) {
    final keys = HardwareKeyboard.instance;
    _downKeys[i] = (keys.isControlPressed, keys.isShiftPressed);
  }

  /// Click: one row; Ctrl: add or take out; Shift: a range from the anchor.
  void _click(int i) {
    _listFocus.requestFocus();
    final (ctrl, shift) = _downKeys.remove(i) ?? (false, false);
    final id = _items[i].id;
    setState(() {
      if (shift && _anchor != null) {
        final a = math.min(_anchor!, i), b = math.max(_anchor!, i);
        if (!ctrl) _picked.clear();
        _picked.addAll([for (var k = a; k <= b; k++) _items[k].id]);
      } else if (ctrl) {
        if (!_picked.remove(id)) _picked.add(id);
        _anchor = i;
      } else {
        _picked
          ..clear()
          ..add(id);
        _anchor = i;
      }
      _selected = i;
    });
  }

  void _setSort(TrackSort sort) {
    setState(() {
      _reverse = sort == _sort && !_reverse;
      _sort = sort;
    });
    _reload();
  }

  Future<void> _openMenu(int i, Offset at) async {
    if (!_picked.contains(_items[i].id)) _click(i);
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final chosen = _chosen;
    final single = chosen.length == 1 ? chosen.single : null;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<_Act>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: c.surface2,
      constraints: const BoxConstraints.tightFor(width: 250),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.overlayBorder),
      ),
      menuPadding: const EdgeInsets.all(6),
      items: [
        if (single?.missing ?? false)
          _item(_Act.play, PhosphorRegular.magnifyingGlass, t.missingLocate)
        else
          _item(
            _Act.play,
            PhosphorFill.play,
            t.playSelection,
            keys: t.keyEnter,
            accent: true,
          ),
        _item(
          _Act.playNext,
          PhosphorRegular.playlist,
          t.playNext,
          keys: t.keyCtrlEnter,
        ),
        _item(_Act.queue, PhosphorRegular.queue, t.addToQueue),
        _item(_Act.playlist, PhosphorRegular.listPlus, t.addToPlaylist),
        if (single != null) ...[
          const PopupMenuDivider(height: 9),
          _item(
            _Act.tags,
            PhosphorRegular.notePencil,
            t.editTags,
            keys: t.keyCtrlI,
          ),
          if (Platform.isWindows)
            _item(_Act.reveal, PhosphorRegular.folderOpen, t.showInExplorer),
        ],
        const PopupMenuDivider(height: 9),
        _item(
          _Act.remove,
          PhosphorRegular.minusCircle,
          t.removeEllipsis,
          keys: t.keyDelete,
          danger: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    _run(action);
  }

  void _run(_Act action) {
    switch (action) {
      case _Act.play:
        _playChosen();
      case _Act.playNext:
        unawaited(_enqueue(next: true));
      case _Act.queue:
        unawaited(_enqueue(next: false));
      case _Act.playlist:
        unawaited(_addToPlaylist());
      case _Act.tags:
        unawaited(_editTags());
      case _Act.reveal:
        unawaited(_reveal());
      case _Act.remove:
        unawaited(_remove());
      case _Act.share:
        unawaited(_share());
      case _Act.delete:
        unawaited(_deleteFromPhone());
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  /// Phone: long press or the dots on a title, the actions in a sheet.
  Future<void> _openSheet(int i) async {
    final item = _items[i];
    setState(() {
      _picked
        ..clear()
        ..add(item.id);
      _anchor = i;
      _selected = i;
    });
    final phone = ref.read(deviceMediaSupportedProvider);
    final t = L10n.of(context);
    void run(_Act a) {
      if (mounted) _run(a);
    }

    // Expressive grouped sheet (2026-11-25).
    await showActionSheet(
      context,
      header: SheetHeader(
        leading: CoverArt(
          size: 64,
          radius: 16,
          seed: item.id,
          imagePath: item.thumbnail,
          shadow: false,
        ),
        title: item.title,
        subtitle: item.artist ?? t.unknownArtist,
      ),
      groups: [
        [
          SheetAction(
            icon: PhosphorRegular.arrowBendDownRight,
            label: t.playNext,
            onTap: () => run(_Act.playNext),
          ),
          SheetAction(
            icon: PhosphorRegular.queue,
            label: t.addToQueue,
            onTap: () => run(_Act.queue),
          ),
          SheetAction(
            icon: PhosphorRegular.listPlus,
            label: t.addToPlaylist,
            onTap: () => run(_Act.playlist),
          ),
          SheetAction(
            icon: item.favorite ? PhosphorFill.heart : PhosphorRegular.heart,
            label: item.favorite ? t.favoriteRemove : t.favoriteAdd,
            onTap: () {
              final at = _items.indexWhere((x) => x.id == item.id);
              if (mounted && at >= 0) unawaited(_toggleFavorite(at));
            },
          ),
        ],
        [
          if (item.album != null)
            SheetAction(
              icon: PhosphorRegular.disc,
              label: t.viewAlbum,
              onTap: () => openGroup(context, ref, (
                kind: GroupKind.album,
                name: item.album!,
              )),
            ),
          if (item.artist != null)
            SheetAction(
              icon: PhosphorRegular.user,
              label: t.viewArtist,
              onTap: () => openGroup(context, ref, (
                kind: GroupKind.artist,
                name: item.artist!,
              )),
            ),
          SheetAction(
            icon: PhosphorRegular.info,
            label: t.trackInfo,
            onTap: () => unawaited(showTrackInfo(context, item)),
          ),
        ],
        [
          if (phone) ...[
            SheetAction(
              icon: PhosphorRegular.shareNetwork,
              label: t.share,
              onTap: () => run(_Act.share),
            ),
            SheetAction(
              icon: PhosphorRegular.trash,
              label: t.deleteFromPhone,
              danger: true,
              onTap: () => run(_Act.delete),
            ),
          ] else
            SheetAction(
              icon: PhosphorRegular.minusCircle,
              label: t.removeEllipsis,
              danger: true,
              onTap: () => run(_Act.remove),
            ),
        ],
      ],
    );
  }

  Future<void> _share() async {
    final chosen = _chosen;
    if (chosen.length != 1) return;
    final item = chosen.single;
    final ok = await ref
        .read(deviceMediaApiProvider)
        .share(item.path, item.title);
    if (!ok && mounted) _toast(L10n.of(context).shareFailed);
  }

  /// Supprimer du téléphone: Android asks for confirmation, then the
  /// titles leave the library (MediaStore would list them again otherwise).
  Future<void> _deleteFromPhone() async {
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    final answer = await ref.read(deviceMediaApiProvider).delete([
      for (final i in chosen) i.path,
    ]);
    if (!mounted) return;
    final t = L10n.of(context);
    if (answer == 'canceled') return;
    if (answer != 'deleted') {
      _toast(t.deleteFailed);
      return;
    }
    await ref.read(healthApiProvider).remove([for (final i in chosen) i.id]);
    ref
      ..invalidate(favoritesCountProvider)
      ..invalidate(healthCountsProvider);
    _picked.clear();
    await _reload();
    if (mounted) _toast(t.deletedFromPhone(chosen.length));
  }

  PopupMenuItem<_Act> _item(
    _Act value,
    IconData icon,
    String label, {
    String? keys,
    bool accent = false,
    bool danger = false,
  }) {
    final c = MmColors.of(context);
    return PopupMenuItem<_Act>(
      value: value,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: danger ? c.danger : (accent ? c.coralStrong : c.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: MmType.label.copyWith(
                color: danger ? c.danger : c.fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (keys != null)
            Text(keys, style: MmType.monoStyle(size: 10.5, color: c.faint)),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(int index) async {
    final item = _items[index];
    await ref
        .read(libraryApiProvider)
        .setFavorite(item.id, favorite: !item.favorite);
    // In Favoris the row stays until the next visit: a heart tapped by
    // mistake can be put back.
    ref.invalidate(favoritesCountProvider);
    if (!mounted) return;
    setState(() {
      _items[index] = item.withFavorite(!item.favorite);
    });
  }

  void _moveCursor(int to, {required bool extend}) {
    final i = to.clamp(0, _items.length - 1);
    setState(() {
      if (extend && _anchor != null) {
        final a = math.min(_anchor!, i), b = math.max(_anchor!, i);
        _picked
          ..clear()
          ..addAll([for (var k = a; k <= b; k++) _items[k].id]);
      } else {
        _picked
          ..clear()
          ..add(_items[i].id);
        _anchor = i;
      }
      _selected = i;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_items.isEmpty) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = e.logicalKey;
    final s = _selected ?? -1;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveCursor(s + 1, extend: keys.isShiftPressed);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveCursor(s - 1, extend: keys.isShiftPressed);
    } else if (key == LogicalKeyboardKey.keyA && keys.isControlPressed) {
      setState(() => _picked.addAll([for (final i in _items) i.id]));
    } else if (key == LogicalKeyboardKey.escape && _picked.isNotEmpty) {
      setState(_picked.clear);
    } else if (key == LogicalKeyboardKey.enter && _chosen.isNotEmpty) {
      if (keys.isControlPressed) {
        unawaited(_enqueue(next: true));
      } else if (_picked.length > 1) {
        _playChosen();
      } else {
        _play(s < 0 ? 0 : s);
      }
    } else if (key == LogicalKeyboardKey.keyI &&
        keys.isControlPressed &&
        _chosen.length == 1) {
      unawaited(_editTags());
    } else if (key == LogicalKeyboardKey.delete && _chosen.isNotEmpty) {
      unawaited(_remove());
    } else if ((key == LogicalKeyboardKey.contextMenu ||
            (key == LogicalKeyboardKey.f10 && keys.isShiftPressed)) &&
        s >= 0) {
      final box = context.findRenderObject() as RenderBox?;
      final at = box?.localToGlobal(const Offset(240, 160)) ?? Offset.zero;
      unawaited(_openMenu(s, at));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static DateTime _monthStart(DateTime now) => DateTime(now.year, now.month);

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final playingId = ref.watch(
      queueProvider.select((q) => q.current?.libraryId),
    );
    final width = MediaQuery.sizeOf(context).width;
    if (width < 720) return _mobile(c, t, playingId);
    final compact = width < 1280;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.favorites ? t.navFavorites : t.navTracks,
                    style: MmType.display.copyWith(color: c.fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.tracksSummary(_total),
                    style: MmType.bodySm.copyWith(color: c.muted),
                  ),
                ],
              ),
              const Spacer(),
              _FilterField(hint: t.filterTracks, onChanged: _onSearch),
              const SizedBox(width: 12),
              _PlayAllButton(
                label: t.playAll,
                onTap: _items.isEmpty ? null : () => _play(0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 30,
            // Narrow windows: the chips scroll, the selection bar stays.
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _chips(t, height: 30)),
                  ),
                ),
                if (_picked.length > 1) ...[
                  const SizedBox(width: 12),
                  _selectionBar(c, t),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _HeaderRow(
            compact: compact,
            sort: _sort,
            reverse: _reverse,
            onSort: _setSort,
          ),
          Expanded(child: _body(c, t, playingId, compact)),
        ],
      ),
    );
  }

  /// Tous / Favoris (the sidebar entries), then the quick filters of the
  /// core, one at a time (a second tap clears it): Jamais écoutés, Hi-res
  /// (more than 16 bits or 48 kHz), Ajoutés ce mois. Introuvables · N opens
  /// the W-O2 screen, shown when files are missing.
  List<Widget> _chips(L10n t, {required double height}) {
    // The phone toolbar (40 dp) uses the expressive chips.
    final phone = height >= 40;
    Widget chip0({
      required String label,
      required bool on,
      VoidCallback? onTap,
    }) => phone
        ? ToolChip(label: label, on: on, onTap: onTap)
        : _Chip(label: label, on: on, height: height, onTap: onTap);
    final missing = ref.watch(healthCountsProvider).value?.missing.toInt() ?? 0;
    Widget quick(_Quick q, String label) => chip0(
      label: label,
      on: _quick == q,
      onTap: () => _setQuick(_quick == q ? null : q),
    );
    const gap = SizedBox(width: 8);
    return [
      chip0(
        label: t.filterAll,
        on: !_favoritesOnly && _quick == null,
        onTap: _favoritesOnly
            ? () => context.go(Routes.tracks)
            : (_quick == null ? null : () => _setQuick(null)),
      ),
      gap,
      chip0(
        label: t.navFavorites,
        on: _favoritesOnly,
        onTap: _favoritesOnly ? null : () => context.go(Routes.favorites),
      ),
      gap,
      quick(_Quick.neverPlayed, t.filterNeverPlayed),
      gap,
      quick(_Quick.hiRes, t.filterHiRes),
      if (missing > 0) ...[
        gap,
        chip0(
          label: t.filterMissingCount(missing),
          on: false,
          onTap: () => context.go(Routes.missing),
        ),
      ],
      gap,
      quick(_Quick.addedThisMonth, t.filterAddedThisMonth),
    ];
  }

  void _setQuick(_Quick? q) {
    setState(() => _quick = q);
    _reload();
  }

  /// "2 sélectionnés · Lire ensuite · Ajouter à…" (mockup W-M1c).
  Widget _selectionBar(MmColors c, L10n t) {
    final strong = MmType.captionStrong.copyWith(fontSize: 12.5, color: c.fg);
    Widget link(String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressScale: 0.96,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(label, style: strong),
      ),
    );
    final dot = Text(
      ' · ',
      style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
    );
    return Row(
      children: [
        Text(
          t.selectedCount(_picked.length),
          style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
        ),
        dot,
        link(t.playNext, () => _enqueue(next: true)),
        dot,
        MenuAnchor(
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
            MenuItemButton(
              leadingIcon: Icon(
                PhosphorRegular.queue,
                size: 18,
                color: c.muted,
              ),
              onPressed: () => _enqueue(next: false),
              child: Text(
                t.addToQueue,
                style: MmType.label.copyWith(color: c.fg),
              ),
            ),
            MenuItemButton(
              leadingIcon: Icon(
                PhosphorRegular.listPlus,
                size: 18,
                color: c.muted,
              ),
              onPressed: _addToPlaylist,
              child: Text(
                t.addToPlaylist,
                style: MmType.label.copyWith(color: c.fg),
              ),
            ),
          ],
          builder: (context, menu, _) =>
              link(t.addTo, () => menu.isOpen ? menu.close() : menu.open()),
        ),
        const SizedBox(width: 6),
        Pressable(
          onTap: () => setState(_picked.clear),
          semanticLabel: t.clearSelection,
          tooltip: t.clearSelection,
          pressScale: 0.9,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(PhosphorRegular.x, size: 16, color: c.muted),
          ),
        ),
      ],
    );
  }

  /// A-01 on the phone, expressive redesign (decision 0010): library header
  /// with tabs and counts, a toolbar (count, sort, favorites and quick
  /// filters, shuffle, grid or list), then the titles as rows joined into
  /// rounded blocks or as a three-column grid. A tap plays.
  Widget _mobile(MmColors c, L10n t, int? playingId) {
    final queue = ref.read(queueProvider.notifier);
    final grid = ref.watch(phoneTracksGridProvider).value ?? false;
    Widget iconButton(IconData icon, String label, VoidCallback? onTap) =>
        Pressable(
          onTap: onTap,
          semanticLabel: label,
          tooltip: label,
          pressScale: 0.88,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              icon,
              size: 24,
              color: onTap == null ? c.faintIcon : c.fg,
            ),
          ),
        );
    final sortLabel = switch (_sort) {
      TrackSort.title => t.colTitle,
      TrackSort.artist => t.colArtist,
      TrackSort.album => t.colAlbum,
      TrackSort.format => t.colFormat,
      TrackSort.duration => t.colDuration,
      TrackSort.added => t.groupSortAdded,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhoneLibraryHeader(
          current: widget.favorites ? Routes.favorites : Routes.tracks,
          title: widget.favorites ? t.navFavorites : null,
        ),
        SizedBox(
          height: 66,
          child: Row(
            children: [
              Expanded(
                // The chips fade out under the two buttons on the right.
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Color(0xFF000000), Color(0x00000000)],
                    stops: [0.9, 1],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 13, 24, 13),
                    children: [
                      Center(
                        child: Text(
                          t.tracksSummary(_total),
                          style: MmType.body.copyWith(
                            fontSize: 15,
                            color: c.fgSoft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ToolChip(
                        label: sortLabel,
                        icon: _reverse
                            ? PhosphorRegular.arrowDown
                            : PhosphorRegular.arrowUp,
                        onTap: () => _sortSheet(t),
                      ),
                      const SizedBox(width: 8),
                      ..._chips(t, height: 40),
                    ],
                  ),
                ),
              ),
              iconButton(
                PhosphorRegular.shuffle,
                t.shuffle,
                _items.isEmpty
                    ? null
                    : () async {
                        if (!ref.read(queueProvider).shuffle) {
                          await queue.toggleShuffle();
                        }
                        _play(math.Random().nextInt(_items.length));
                      },
              ),
              iconButton(
                grid ? PhosphorRegular.listBullets : PhosphorRegular.gridFour,
                grid ? t.viewList : t.viewGrid,
                () => ref.read(phoneTracksGridProvider.notifier).set(!grid),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: MmMotion.of(context).screen,
            child: KeyedSubtree(
              key: ValueKey(grid),
              child: grid
                  ? _mobileGrid(c, t, playingId)
                  : _mobileList(c, t, playingId),
            ),
          ),
        ),
      ],
    );
  }

  /// Sort of the phone list: one sheet; the current order again reverses it.
  void _sortSheet(L10n t) {
    showActionSheet(
      context,
      header: SheetHeader(
        leading: Icon(
          PhosphorRegular.sortAscending,
          size: 30,
          color: MmColors.of(context).fg,
        ),
        title: t.sortBy,
      ),
      groups: [
        [
          for (final (s, label) in [
            (TrackSort.title, t.colTitle),
            (TrackSort.artist, t.colArtist),
            (TrackSort.album, t.colAlbum),
            (TrackSort.added, t.groupSortAdded),
            (TrackSort.duration, t.colDuration),
          ])
            SheetAction(
              icon: s == _sort
                  ? (_reverse
                        ? PhosphorRegular.arrowDown
                        : PhosphorRegular.arrowUp)
                  : PhosphorRegular.sortAscending,
              label: label,
              value: s == _sort ? '✓' : null,
              onTap: () => _setSort(s),
            ),
        ],
      ],
    );
  }

  Widget _mobileList(MmColors c, L10n t, int? playingId) {
    if (_error != null || (_items.isEmpty && !_loading)) {
      return _body(c, t, playingId, true);
    }
    return ListView.builder(
      itemExtent: 79,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        if (i >= _items.length - 40 && _items.length < _total) _loadMore();
        final item = _items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: PhoneTrackRow(
            item: item,
            first: i == 0,
            last: i == _items.length - 1,
            onTap: () => _play(i),
            onMore: () => _openSheet(i),
            moreKey: ValueKey('track-more-${item.id}'),
          ),
        );
      },
    );
  }

  Widget _mobileGrid(MmColors c, L10n t, int? playingId) {
    if (_error != null || (_items.isEmpty && !_loading)) {
      return _body(c, t, playingId, true);
    }
    return LayoutBuilder(
      builder: (context, box) {
        const pad = 20.0;
        const gap = 10.0;
        final tile = (box.maxWidth - pad * 2 - gap * 2) / 3;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(pad, 4, pad, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: gap,
            mainAxisSpacing: 14,
            mainAxisExtent: tile + 54,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            if (i >= _items.length - 40 && _items.length < _total) {
              _loadMore();
            }
            return PhoneTrackTile(
              item: _items[i],
              size: tile,
              onTap: () => _play(i),
              onMore: () => _openSheet(i),
            );
          },
        );
      },
    );
  }

  Widget _body(MmColors c, L10n t, int? playingId, bool compact) {
    if (_error != null) {
      return LibraryErrorView(error: _error!, onRetry: _reload);
    }
    if (_items.isEmpty && _loading) return const SkeletonList();
    if (_items.isEmpty && _favoritesOnly && _search.isEmpty) {
      return LibraryMessage(
        icon: PhosphorRegular.heart,
        title: t.favoritesEmptyTitle,
        body: t.favoritesEmptyBody,
      );
    }
    if (_items.isEmpty) {
      return LibraryEmpty(
        icon: PhosphorRegular.musicNotesMinus,
        title: t.tracksEmptyTitle,
        body: t.tracksEmptyBody,
        onAdded: _reload,
      );
    }
    return Focus(
      focusNode: _listFocus,
      onKeyEvent: _onKey,
      child: ListView.builder(
        // Settings › Appearance › Density: compact rows are 40 px.
        itemExtent:
            ref.watch(appearanceProvider).value?.density == Density.compact
            ? 40
            : 44,
        padding: const EdgeInsets.only(bottom: 24, top: 4),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          if (i >= _items.length - 40 && _items.length < _total) _loadMore();
          final item = _items[i];
          return _TrackRow(
            index: i,
            item: item,
            compact: compact,
            selected: _picked.contains(item.id),
            playing: playingId == item.id,
            onDown: () => _pointerDown(i),
            onSelect: () => _click(i),
            onMenu: (at) => _openMenu(i, at),
            onPlay: () => _play(i),
            onFavorite: () => _toggleFavorite(i),
          );
        },
      ),
    );
  }
}

const _columnsWide = [40.0, 2.0, 1.3, 1.3, 110.0, 60.0, 36.0];

/// The mockup grid: fixed columns in px, flexible ones as fractions.
List<Widget> _grid(List<Widget> cells, {required bool compact}) {
  final out = <Widget>[];
  for (var i = 0; i < cells.length; i++) {
    // Below 1280 px the Album and Format columns are hidden (Handoff §04).
    if (compact && (i == 3 || i == 4)) continue;
    final w = _columnsWide[i];
    out.add(
      w > 3
          ? SizedBox(width: w, child: cells[i])
          : Expanded(flex: (w * 10).round(), child: cells[i]),
    );
  }
  return out;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.compact,
    required this.sort,
    required this.reverse,
    required this.onSort,
  });

  final bool compact;
  final TrackSort sort;
  final bool reverse;
  final ValueChanged<TrackSort> onSort;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final style = MmType.overline.copyWith(color: c.faint);
    // Duration starts with the longest; the others from A.
    final ascending = (sort == TrackSort.duration) == reverse;
    Widget h(String label, TrackSort by, {bool end = false}) {
      final on = sort == by;
      final button = Pressable(
        onTap: () => onSort(by),
        semanticLabel: [
          t.sortByColumn(label),
          if (on) ascending ? t.sortedAscending : t.sortedDescending,
        ].join(', '),
        selected: on,
        pressScale: 1,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: on ? style.copyWith(color: c.fg) : style,
                ),
              ),
              if (on) ...[
                const SizedBox(width: 4),
                RotatedBox(
                  quarterTurns: ascending ? 0 : 2,
                  child: Icon(PhosphorRegular.arrowUp, size: 13, color: c.fg),
                ),
              ],
            ],
          ),
        ),
      );
      // The 60 px Durée column: a longer label ("DURATION", or with the
      // arrow) runs into the free end of Format rather than being cut.
      return end
          ? OverflowBox(
              alignment: Alignment.centerRight,
              minWidth: 0,
              maxWidth: 140,
              child: button,
            )
          : Align(alignment: Alignment.centerLeft, child: button);
    }

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: _grid([
          Text('#', style: style),
          h(t.colTitle, TrackSort.title),
          h(t.colArtist, TrackSort.artist),
          h(t.colAlbum, TrackSort.album),
          h(t.colFormat, TrackSort.format),
          h(t.colDuration, TrackSort.duration, end: true),
          const SizedBox(),
        ], compact: compact),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.index,
    required this.item,
    required this.compact,
    required this.selected,
    required this.playing,
    required this.onDown,
    required this.onSelect,
    required this.onMenu,
    required this.onPlay,
    required this.onFavorite,
  });

  final int index;
  final LibraryItem item;
  final bool compact;
  final bool selected;
  final bool playing;
  final VoidCallback onDown;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onMenu;
  final VoidCallback onPlay;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final muted = MmType.bodySm.copyWith(color: c.muted);
    final duration = item.durationSecs;
    final bg = playing ? c.surface : (selected ? c.selected : null);
    return Listener(
      onPointerDown: (e) {
        if (e.buttons == kPrimaryButton) onDown();
      },
      child: GestureDetector(
        onSecondaryTapUp: (d) => onMenu(d.globalPosition),
        child: Opacity(
          opacity: item.missing ? 0.72 : 1,
          child: Pressable(
            onTap: onSelect,
            onDoubleTap: onPlay,
            semanticLabel: '${item.title}, ${item.artist ?? t.unknownArtist}',
            selected: selected,
            pressScale: 1,
            hoverColor: bg == null ? c.cardHover : null,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: MmMotion.of(context).hover,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: _grid([
                  playing
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: LivePlayingBars(
                            color: c.coralStrong,
                            size: 15,
                          ),
                        )
                      : Text(
                          '${index + 1}',
                          style: MmType.monoStyle(size: 12, color: c.faint),
                        ),
                  Row(
                    children: [
                      CoverArt(
                        size: 32,
                        radius: 6,
                        seed: item.id,
                        shadow: false,
                        imagePath: item.thumbnail,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.labelStrong.copyWith(
                                color: playing ? c.coralStrong : c.fg,
                              ),
                            ),
                            if (item.missing)
                              Text(
                                '${t.fileMissing} · ${t.locate}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.caption.copyWith(
                                  color: c.warning,
                                  fontSize: 11.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.artist ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                  Text(
                    item.album ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                  Text(
                    item.format ?? '—',
                    style: MmType.monoStyle(size: 11.5, color: c.faint),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      duration == null
                          ? '—'
                          : formatClock(
                              Duration(milliseconds: (duration * 1000).round()),
                            ),
                      style: MmType.monoStyle(size: 12, color: c.muted),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Pressable(
                      onTap: onFavorite,
                      semanticLabel: item.favorite
                          ? t.favoriteRemove
                          : t.favoriteAdd,
                      tooltip: item.favorite ? t.favoriteRemove : t.favoriteAdd,
                      pressScale: 0.85,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: _Heart(on: item.favorite),
                      ),
                    ),
                  ),
                ], compact: compact),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick filters of Titres, one at a time.
enum _Quick { neverPlayed, hiRes, addedThisMonth }

enum _Act {
  play,
  playNext,
  queue,
  playlist,
  tags,
  reveal,
  remove,
  share,
  delete,
}

/// Favorite heart: 1 → 1.15 → 1 and fill in 180 ms (handoff §03).
class _Heart extends StatelessWidget {
  const _Heart({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final motion = MmMotion.of(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(on),
      tween: Tween(begin: on && !motion.reduced ? 0 : 1, end: 1),
      duration: motion.favorite,
      builder: (context, t, child) {
        final scale = 1 + 0.15 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Transform.scale(scale: scale, child: child);
      },
      child: MmIcon(
        PhosphorRegular.heart,
        filled: PhosphorFill.heart,
        active: on,
        size: 18,
        color: on ? c.coralStrong : c.lineStrong,
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      width: 240,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.pill),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(PhosphorRegular.funnelSimple, size: 17, color: c.faint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: MmType.bodySm.copyWith(color: c.fg),
              cursorColor: c.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: MmType.bodySm.copyWith(color: c.faint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayAllButton extends StatelessWidget {
  const _PlayAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
        decoration: BoxDecoration(
          color: onTap == null ? c.coral.withValues(alpha: 0.4) : c.coral,
          borderRadius: BorderRadius.circular(MmRadius.pill),
        ),
        child: Row(
          children: [
            Icon(PhosphorFill.play, size: 18, color: c.coralInk),
            const SizedBox(width: 6),
            Text(
              label,
              style: MmType.labelStrong.copyWith(
                color: c.coralInk,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.height = 30,
  });

  final String label;
  final bool on;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      selected: on,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: MmMotion.of(context).state,
        height: height,
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
