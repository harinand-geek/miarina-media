import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
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

/// W-M1c Titres: every audio track of the library, sorted by title, in a
/// virtualised table loaded page by page.
class TracksScreen extends ConsumerStatefulWidget {
  const TracksScreen({super.key});

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
  bool _favoritesOnly = false;
  int? _selected;
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
    final entries = [
      for (final i in _items) queueEntryOf(i, unknownArtist: t.unknownArtist),
    ];
    ref.read(queueProvider.notifier).playAll(entries, start: index);
  }

  Future<void> _toggleFavorite(int index) async {
    final item = _items[index];
    await ref
        .read(libraryApiProvider)
        .setFavorite(item.id, favorite: !item.favorite);
    if (!mounted) return;
    setState(() {
      _items[index] = item.withFavorite(!item.favorite);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_items.isEmpty) return KeyEventResult.ignored;
    final s = _selected ?? -1;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (s + 1).clamp(0, _items.length - 1));
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (s - 1).clamp(0, _items.length - 1));
    } else if (e.logicalKey == LogicalKeyboardKey.enter && _selected != null) {
      _play(_selected!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

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
                    t.navTracks,
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
          Row(
            children: [
              _Chip(
                label: t.filterAll,
                on: !_favoritesOnly,
                onTap: () {
                  _favoritesOnly = false;
                  _reload();
                },
              ),
              const SizedBox(width: 8),
              _Chip(
                label: t.navFavorites,
                on: _favoritesOnly,
                onTap: () {
                  _favoritesOnly = true;
                  _reload();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HeaderRow(compact: compact),
          Expanded(child: _body(c, t, playingId, compact)),
        ],
      ),
    );
  }

  /// A-01 (Android, 360 dp reference): 60 dp rows, a tap plays.
  Widget _mobile(MmColors c, L10n t, int? playingId) {
    final queue = ref.read(queueProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
          child: Text(
            t.navTracks,
            style: MmType.titleLg.copyWith(fontSize: 20, color: c.fg),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            t.tracksSummary(_total),
            style: MmType.bodySm.copyWith(color: c.muted),
          ),
        ),
        const MusicChips(current: Routes.tracks),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _Chip(
                label: t.filterAll,
                on: !_favoritesOnly,
                height: 34,
                onTap: () {
                  _favoritesOnly = false;
                  _reload();
                },
              ),
              const SizedBox(width: 8),
              _Chip(
                label: t.navFavorites,
                on: _favoritesOnly,
                height: 34,
                onTap: () {
                  _favoritesOnly = true;
                  _reload();
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: _WideButton(
                  label: t.playAll,
                  icon: PhosphorFill.play,
                  primary: true,
                  onTap: _items.isEmpty ? null : () => _play(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WideButton(
                  label: t.shuffle,
                  icon: PhosphorRegular.shuffle,
                  onTap: _items.isEmpty
                      ? null
                      : () async {
                          if (!ref.read(queueProvider).shuffle) {
                            await queue.toggleShuffle();
                          }
                          _play(math.Random().nextInt(_items.length));
                        },
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _mobileList(c, t, playingId)),
      ],
    );
  }

  Widget _mobileList(MmColors c, L10n t, int? playingId) {
    if (_error != null || (_items.isEmpty && !_loading)) {
      return _body(c, t, playingId, true);
    }
    return ListView.builder(
      itemExtent: 60,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        if (i >= _items.length - 40 && _items.length < _total) _loadMore();
        final item = _items[i];
        final playing = playingId == item.id;
        return Opacity(
          opacity: item.missing ? 0.72 : 1,
          child: Pressable(
            onTap: () => _play(i),
            semanticLabel: '${item.title}, ${item.artist ?? t.unknownArtist}',
            borderRadius: BorderRadius.circular(MmRadius.lg),
            pressScale: 0.98,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  CoverArt(
                    size: 48,
                    radius: 10,
                    seed: item.id,
                    shadow: false,
                    child: playing
                        ? Icon(
                            PhosphorFill.equalizer,
                            size: 20,
                            color: c.coralStrong,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.heading.copyWith(
                            fontSize: 15,
                            color: playing ? c.coralStrong : c.fg,
                          ),
                        ),
                        Text(
                          item.missing
                              ? t.fileMissing
                              : (item.artist ?? t.unknownArtist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.caption.copyWith(
                            fontSize: 12.5,
                            color: item.missing ? c.warning : c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () => _toggleFavorite(i),
                    semanticLabel: item.favorite
                        ? t.favoriteRemove
                        : t.favoriteAdd,
                    pressScale: 0.85,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(child: _Heart(on: item.favorite)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(MmColors c, L10n t, int? playingId, bool compact) {
    if (_error != null) {
      return _Message(
        icon: PhosphorRegular.warningCircle,
        title: t.libraryError,
        body: '$_error',
        action: t.retry,
        onAction: _reload,
      );
    }
    if (_items.isEmpty && !_loading) {
      return _Message(
        icon: PhosphorRegular.musicNotesMinus,
        title: t.tracksEmptyTitle,
        body: t.tracksEmptyBody,
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
            selected: _selected == i,
            playing: playingId == item.id,
            onSelect: () {
              _listFocus.requestFocus();
              setState(() => _selected = i);
            },
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
  const _HeaderRow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final style = MmType.overline.copyWith(color: c.faint);
    Text h(String s) => Text(s.toUpperCase(), style: style);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: _grid([
          h('#'),
          Row(
            children: [
              Text(
                t.colTitle.toUpperCase(),
                style: style.copyWith(color: c.fg),
              ),
              const SizedBox(width: 4),
              Icon(PhosphorRegular.arrowUp, size: 13, color: c.fg),
            ],
          ),
          h(t.colArtist),
          h(t.colAlbum),
          h(t.colFormat),
          Align(alignment: Alignment.centerRight, child: h(t.colDuration)),
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
    required this.onSelect,
    required this.onPlay,
    required this.onFavorite,
  });

  final int index;
  final LibraryItem item;
  final bool compact;
  final bool selected;
  final bool playing;
  final VoidCallback onSelect;
  final VoidCallback onPlay;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final muted = MmType.bodySm.copyWith(color: c.muted);
    final duration = item.durationSecs;
    final bg = playing ? c.surface : (selected ? c.selected : null);
    return Opacity(
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
                  ? Icon(PhosphorFill.equalizer, size: 16, color: c.coralStrong)
                  : Text(
                      '${index + 1}',
                      style: MmType.monoStyle(size: 12, color: c.faint),
                    ),
              Row(
                children: [
                  CoverArt(size: 32, radius: 6, seed: item.id, shadow: false),
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
                            t.fileMissing,
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
    );
  }
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
  final VoidCallback onTap;
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

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.faintIcon),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MmType.title.copyWith(color: c.fg),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: MmType.bodySm.copyWith(color: c.muted),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              Pressable(
                onTap: onAction,
                semanticLabel: action,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    border: Border.all(color: c.lineStrong),
                  ),
                  child: Text(
                    action!,
                    style: MmType.labelStrong.copyWith(color: c.fg),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-width action of the Android lists (A-01): 44 dp, radius 14.
class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final fg = primary ? c.coralInk : c.fg;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(MmRadius.lg),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: primary ? c.coral : c.surface2,
            borderRadius: BorderRadius.circular(MmRadius.lg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.heading.copyWith(
                    color: fg,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
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
