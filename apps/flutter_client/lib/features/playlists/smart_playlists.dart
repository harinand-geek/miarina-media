part of 'playlists_screen.dart';

// Playlists intelligentes (handoff Musique W-M5, P1 → done): a name and
// rules on what the library already knows (text, artist, album, favourites,
// never played, hi-res, added recently), with a sort and a limit. They are
// computed each time they open, so they follow the library. Kept in the
// settings table (`smartPlaylists`); files are never touched.

@immutable
class SmartRules {
  const SmartRules({
    this.text = '',
    this.artist = '',
    this.album = '',
    this.favorites = false,
    this.neverPlayed = false,
    this.hiRes = false,
    this.addedDays,
    this.sort = TrackSort.added,
    this.reverse = false,
    this.limit,
  });

  final String text;
  final String artist;
  final String album;
  final bool favorites;
  final bool neverPlayed;
  final bool hiRes;

  /// Added in the last N days; null = whenever.
  final int? addedDays;
  final TrackSort sort;
  final bool reverse;

  /// At most this many tracks; null = all.
  final int? limit;

  static const addedChoices = [null, 7, 30, 90, 365];
  static const limitChoices = [null, 25, 50, 100, 250];

  /// Tracks read at most when there is no limit.
  static const all = 2000;

  Map<String, Object?> toJson() => {
    'text': text,
    'artist': artist,
    'album': album,
    'favorites': favorites,
    'neverPlayed': neverPlayed,
    'hiRes': hiRes,
    'addedDays': addedDays,
    'sort': sort.name,
    'reverse': reverse,
    'limit': limit,
  };

  factory SmartRules.fromJson(Object? raw) {
    if (raw is! Map) return const SmartRules();
    T pick<T>(String k, T fallback) => raw[k] is T ? raw[k] as T : fallback;
    int? choice(String k, List<int?> allowed) {
      final v = raw[k];
      return v is int && allowed.contains(v) ? v : null;
    }

    return SmartRules(
      text: pick('text', ''),
      artist: pick('artist', ''),
      album: pick('album', ''),
      favorites: pick('favorites', false),
      neverPlayed: pick('neverPlayed', false),
      hiRes: pick('hiRes', false),
      addedDays: choice('addedDays', addedChoices),
      sort: TrackSort.values.asNameMap()[raw['sort']] ?? TrackSort.added,
      reverse: pick('reverse', false),
      limit: choice('limit', limitChoices),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SmartRules && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

@immutable
class SmartPlaylist {
  const SmartPlaylist({
    required this.id,
    required this.name,
    required this.rules,
  });

  final String id;
  final String name;
  final SmartRules rules;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'rules': rules.toJson(),
  };

  static SmartPlaylist? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['name'] is! String) {
      return null;
    }
    return SmartPlaylist(
      id: raw['id'] as String,
      name: raw['name'] as String,
      rules: SmartRules.fromJson(raw['rules']),
    );
  }
}

final smartPlaylistsProvider =
    AsyncNotifierProvider<SmartPlaylistsController, List<SmartPlaylist>>(
      SmartPlaylistsController.new,
    );

class SmartPlaylistsController extends AsyncNotifier<List<SmartPlaylist>> {
  static const key = 'smartPlaylists';

  @override
  Future<List<SmartPlaylist>> build() async {
    final raw = await ref.read(settingsStoreProvider).read(key);
    return [
      if (raw is List)
        for (final e in raw) ?SmartPlaylist.fromJson(e),
    ];
  }

  Future<void> _write(List<SmartPlaylist> next) async {
    state = AsyncData(next);
    await ref.read(settingsStoreProvider).write(key, [
      for (final p in next) p.toJson(),
    ]);
  }

  /// Adds [p], or replaces the one with its id.
  Future<void> save(SmartPlaylist p) async {
    final now = await future;
    final i = now.indexWhere((e) => e.id == p.id);
    final next = [...now];
    if (i < 0) {
      next.add(p);
    } else {
      next[i] = p;
    }
    await _write(next);
  }

  Future<void> remove(String id) async {
    final now = await future;
    await _write([
      for (final p in now)
        if (p.id != id) p,
    ]);
  }
}

/// The tracks of [rules], read from the library.
final smartTracksProvider = FutureProvider.autoDispose
    .family<List<LibraryItem>, SmartRules>((ref, rules) async {
      final page = await ref
          .read(libraryApiProvider)
          .tracks(
            search: rules.text.trim(),
            favoritesOnly: rules.favorites,
            offset: 0,
            limit: rules.limit ?? SmartRules.all,
            artist: rules.artist.trim().isEmpty ? null : rules.artist.trim(),
            album: rules.album.trim().isEmpty ? null : rules.album.trim(),
            sort: rules.sort,
            reverse: rules.reverse,
            addedSince: rules.addedDays == null
                ? null
                : DateTime.now().subtract(Duration(days: rules.addedDays!)),
            neverPlayed: rules.neverPlayed,
            hiRes: rules.hiRes,
          );
      return page.items;
    });

/// The smart playlist shown beside the list (desktop), or none.
final selectedSmartProvider = NotifierProvider<SelectedSmart, String?>(
  SelectedSmart.new,
);

class SelectedSmart extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

String sortLabel(L10n t, TrackSort s) => switch (s) {
  TrackSort.title => t.colTitle,
  TrackSort.artist => t.colArtist,
  TrackSort.album => t.colAlbum,
  TrackSort.format => t.colFormat,
  TrackSort.duration => t.colDuration,
  TrackSort.added => t.sortAdded,
};

/// A short line of the rules: "Favoris · Jamais écoutés · 30 derniers
/// jours · 50 titres".
String rulesLine(L10n t, SmartRules r) => [
  if (r.text.trim().isNotEmpty) '« ${r.text.trim()} »',
  if (r.artist.trim().isNotEmpty) r.artist.trim(),
  if (r.album.trim().isNotEmpty) r.album.trim(),
  if (r.favorites) t.smartFavorites,
  if (r.neverPlayed) t.filterNeverPlayed,
  if (r.hiRes) t.filterHiRes,
  if (r.addedDays != null) t.smartAddedDays(r.addedDays!),
  sortLabel(t, r.sort),
  if (r.limit != null) t.smartLimitN(r.limit!),
].join(' · ');

/// The smart playlists, under the others in the list.
class _SmartSection extends ConsumerWidget {
  const _SmartSection({required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final smart = ref.watch(smartPlaylistsProvider).value ?? const [];
    if (smart.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(selectedSmartProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
          child: Text(
            t.smartSection.toUpperCase(),
            style: MmType.overline.copyWith(color: c.faint),
          ),
        ),
        for (final p in smart)
          Pressable(
            onTap: () {
              if (mobile) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      backgroundColor: c.bg,
                      body: SafeArea(
                        child: SmartPlaylistView(id: p.id, mobile: true),
                      ),
                    ),
                  ),
                );
              } else {
                ref.read(selectedSmartProvider.notifier).select(p.id);
              }
            },
            selected: p.id == selected,
            semanticLabel: p.name,
            borderRadius: BorderRadius.circular(MmRadius.lg),
            hoverColor: c.cardHover,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: p.id == selected && !mobile
                    ? c.surface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(MmRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    width: mobile ? 52 : 44,
                    height: mobile ? 52 : 44,
                    decoration: BoxDecoration(
                      color: c.coralSubtle,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                    ),
                    child: Icon(
                      PhosphorRegular.magicWand,
                      size: 20,
                      color: c.coralStrong,
                    ),
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
                          rulesLine(t, p.rules),
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
          ),
      ],
    );
  }
}

/// A smart playlist: its rules, its tracks as the library has them now.
class SmartPlaylistView extends ConsumerWidget {
  const SmartPlaylistView({super.key, required this.id, required this.mobile});

  final String id;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final p = (ref.watch(smartPlaylistsProvider).value ?? const [])
        .where((e) => e.id == id)
        .firstOrNull;
    if (p == null) return const SizedBox.shrink();
    final tracks = ref.watch(smartTracksProvider(p.rules));
    final items = tracks.value ?? const <LibraryItem>[];

    Future<void> play({bool shuffle = false, int start = 0}) async {
      final list = [
        for (final item in items)
          if (!item.missing) queueEntryOf(item, unknownArtist: t.unknownArtist),
      ];
      if (list.isEmpty) return;
      if (shuffle) list.shuffle();
      await ref
          .read(queueProvider.notifier)
          .playAll(list, start: shuffle ? 0 : start, inOrder: true);
    }

    Future<void> delete() async {
      final ok = await _dialog<bool>(
        context,
        title: t.deletePlaylistTitle(p.name),
        body: Text(
          t.smartDeleteBody,
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
      await ref.read(smartPlaylistsProvider.notifier).remove(p.id);
      ref.read(selectedSmartProvider.notifier).select(null);
      if (mobile && context.mounted) Navigator.of(context).maybePop();
    }

    final head = Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : 32,
        mobile ? 8 : 28,
        mobile ? 16 : 32,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mobile)
            Pressable(
              onTap: () => Navigator.of(context).maybePop(),
              semanticLabel: t.back,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Icon(PhosphorRegular.arrowLeft, color: c.muted),
              ),
            ),
          Row(
            children: [
              Icon(PhosphorRegular.magicWand, size: 22, color: c.coral),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.titleLg.copyWith(color: c.fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tracks.hasValue ? t.smartCount(items.length) : t.smartReading,
            style: MmType.monoStyle(size: 12, color: c.muted),
          ),
          const SizedBox(height: 4),
          Text(
            rulesLine(t, p.rules),
            style: MmType.caption.copyWith(color: c.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Button(
                label: t.playAll,
                icon: PhosphorFill.play,
                onTap: items.isEmpty ? null : () => play(),
              ),
              _Button(
                label: t.shuffle,
                icon: PhosphorRegular.shuffle,
                onTap: items.isEmpty ? null : () => play(shuffle: true),
              ),
              _Button(
                label: t.smartEdit,
                icon: PhosphorRegular.slidersHorizontal,
                onTap: () => showSmartRulesDialog(context, ref, existing: p),
              ),
              _Button(
                label: t.delete,
                icon: PhosphorRegular.trash,
                onTap: delete,
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Divider(height: 1, color: c.divider),
        Expanded(
          child: tracks.hasValue && items.isEmpty
              ? LibraryMessage(
                  icon: PhosphorRegular.magicWand,
                  title: t.smartEmptyTitle,
                  body: t.smartEmptyBody,
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 8 : 20,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  itemExtent: mobile ? 60 : 52,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Pressable(
                      onTap: () => play(start: i),
                      semanticLabel: item.title,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                      hoverColor: c.cardHover,
                      child: Opacity(
                        opacity: item.missing ? 0.55 : 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${i + 1}',
                                  style: MmType.monoStyle(
                                    size: 12,
                                    color: c.muted,
                                  ),
                                ),
                              ),
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
                                        color: c.fg,
                                      ),
                                    ),
                                    Text(
                                      [
                                        item.artist ?? t.unknownArtist,
                                        ?item.album,
                                      ].join(' · '),
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
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// New smart playlist ([name] given) or its rules changed ([existing]).
Future<void> showSmartRulesDialog(
  BuildContext context,
  WidgetRef ref, {
  String? name,
  SmartPlaylist? existing,
}) => showDialog<void>(
  context: context,
  builder: (_) => _SmartRulesDialog(name: name, existing: existing),
);

class _SmartRulesDialog extends ConsumerStatefulWidget {
  const _SmartRulesDialog({this.name, this.existing});

  final String? name;
  final SmartPlaylist? existing;

  @override
  ConsumerState<_SmartRulesDialog> createState() => _SmartRulesDialogState();
}

class _SmartRulesDialogState extends ConsumerState<_SmartRulesDialog> {
  late final SmartRules _start = widget.existing?.rules ?? const SmartRules();
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.name ?? '',
  );
  late final _text = TextEditingController(text: _start.text);
  late final _artist = TextEditingController(text: _start.artist);
  late final _album = TextEditingController(text: _start.album);
  late bool _favorites = _start.favorites;
  late bool _neverPlayed = _start.neverPlayed;
  late bool _hiRes = _start.hiRes;
  late int? _addedDays = _start.addedDays;
  late TrackSort _sort = _start.sort;
  late int? _limit = _start.limit;

  @override
  void dispose() {
    for (final c in [_name, _text, _artist, _album]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final nav = Navigator.of(context);
    final p = SmartPlaylist(
      id:
          widget.existing?.id ??
          's${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: name,
      rules: SmartRules(
        text: _text.text.trim(),
        artist: _artist.text.trim(),
        album: _album.text.trim(),
        favorites: _favorites,
        neverPlayed: _neverPlayed,
        hiRes: _hiRes,
        addedDays: _addedDays,
        sort: _sort,
        reverse: _sort == TrackSort.added,
        limit: _limit,
      ),
    );
    await ref.read(smartPlaylistsProvider.notifier).save(p);
    if (ref.read(desktopShellProvider)) {
      ref.read(selectedSmartProvider.notifier).select(p.id);
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text, style: MmType.labelStrong.copyWith(color: c.fg)),
    );
    Widget field(TextEditingController ctl, String hint) => TextField(
      controller: ctl,
      style: MmType.body.copyWith(color: c.fg),
      cursorColor: c.accent,
      decoration: _fieldDecoration(c, hint: hint),
    );
    Widget toggle(String text, bool value, ValueChanged<bool> onChanged) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(text, style: MmType.bodySm.copyWith(color: c.fg)),
              ),
              MmSwitch(value: value, label: text, onChanged: onChanged),
            ],
          ),
        );
    Widget menu<T>(
      String text,
      List<(T, String)> values,
      T selected,
      ValueChanged<T> onChanged,
    ) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: MmType.bodySm.copyWith(color: c.fg)),
          ),
          SettingsMenu<T>(
            label: text,
            values: values,
            selected: selected,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ],
      ),
    );

    return AlertDialog(
      backgroundColor: c.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        side: BorderSide(color: c.overlayBorder),
      ),
      title: Text(
        widget.existing == null ? t.smartNewTitle : t.smartEdit,
        style: MmType.title.copyWith(color: c.fg),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label(t.playlistName),
              TextField(
                key: const ValueKey('smart-name'),
                controller: _name,
                autofocus: widget.name == null,
                style: MmType.body.copyWith(color: c.fg),
                cursorColor: c.accent,
                decoration: _fieldDecoration(c),
              ),
              label(t.smartText),
              field(_text, t.smartTextHint),
              label(t.colArtist),
              field(_artist, t.smartAny),
              label(t.colAlbum),
              field(_album, t.smartAny),
              const SizedBox(height: 6),
              toggle(t.smartFavorites, _favorites, (v) {
                setState(() => _favorites = v);
              }),
              toggle(t.filterNeverPlayed, _neverPlayed, (v) {
                setState(() => _neverPlayed = v);
              }),
              toggle(t.filterHiRes, _hiRes, (v) => setState(() => _hiRes = v)),
              menu<int?>(
                t.smartAdded,
                [
                  for (final d in SmartRules.addedChoices)
                    (d, d == null ? t.smartAddedAny : t.smartAddedDays(d)),
                ],
                _addedDays,
                (v) => _addedDays = v,
              ),
              menu<TrackSort>(
                t.smartSort,
                [for (final s in TrackSort.values) (s, sortLabel(t, s))],
                _sort,
                (v) => _sort = v,
              ),
              menu<int?>(
                t.smartLimit,
                [
                  for (final l in SmartRules.limitChoices)
                    (l, l == null ? t.smartLimitAll : t.smartLimitN(l)),
                ],
                _limit,
                (v) => _limit = v,
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
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: const Color(0xFF062320),
          ),
          onPressed: _save,
          child: Text(
            widget.existing == null ? t.create : t.save,
            style: MmType.labelStrong,
          ),
        ),
      ],
    );
  }
}
