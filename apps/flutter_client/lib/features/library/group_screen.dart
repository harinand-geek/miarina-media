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
import '../now_playing/now_playing_shared.dart';
import '../playback/playback.dart';
import 'groups.dart';
import 'library_data.dart';

/// W-M2a Album / W-M2b Artist (Windows) and A-02 (Android): blurred cover
/// header, play and shuffle, the tracks in disc order; an artist also lists
/// their albums.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key, required this.kind, required this.name});

  final GroupKind kind;
  final String name;

  GroupKey get _key => (kind: kind, name: name);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final groups =
        ref.watch(groupsProvider(kind)).value ?? const <LibraryGroup>[];
    final group = groups
        .where((g) => g.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    final tracks = ref.watch(groupTracksProvider(_key));
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final items = tracks.value ?? const <LibraryItem>[];
    final artwork =
        group?.thumbnail ??
        items.map((i) => i.thumbnail).whereType<String>().firstOrNull;

    if (tracks.hasValue && items.isEmpty) {
      return LibraryMessage(
        icon: PhosphorRegular.warningCircle,
        title: name,
        body: t.groupMissing,
      );
    }

    final albumsOfArtist = kind == GroupKind.artist
        ? ((ref.watch(groupsProvider(GroupKind.album)).value ??
                  const <LibraryGroup>[])
              .where((a) => a.detail?.toLowerCase() == name.toLowerCase())
              .toList()
            ..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0)))
        : const <LibraryGroup>[];

    final totalSecs = items.fold<double>(
      0,
      (s, i) => s + (i.durationSecs ?? 0),
    );
    final formats = items.map((i) => i.format).whereType<String>().toSet();
    final meta = [
      t.tracksSummary(items.length),
      if (totalSecs > 0) durationWords(totalSecs),
    ].join(' · ');

    return mobile
        ? _MobileGroup(
            kind: kind,
            name: name,
            group: group,
            artwork: artwork,
            items: items,
            meta: meta,
            albums: albumsOfArtist,
            onPlay: (i) => playGroup(ref, t, _key, start: i),
            onShuffle: () => playGroup(ref, t, _key, shuffle: true),
          )
        : ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Header(
                kind: kind,
                name: name,
                group: group,
                artwork: artwork,
                meta: meta,
                format: formats.length == 1 ? formats.single : null,
                onPlay: () => playGroup(ref, t, _key),
                onShuffle: () => playGroup(ref, t, _key, shuffle: true),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: kind == GroupKind.album
                    ? _TrackList(
                        items: items,
                        numbered: true,
                        onPlay: (i) => playGroup(ref, t, _key, start: i),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  t.artistTracks,
                                  style: MmType.title.copyWith(color: c.fg),
                                ),
                                const SizedBox(height: 10),
                                _TrackList(
                                  items: items,
                                  onPlay: (i) =>
                                      playGroup(ref, t, _key, start: i),
                                ),
                              ],
                            ),
                          ),
                          if (albumsOfArtist.isNotEmpty) ...[
                            const SizedBox(width: 32),
                            SizedBox(
                              width: 3 * 132 + 2 * 14 + 48,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.navAlbums,
                                    style: MmType.title.copyWith(color: c.fg),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 0,
                                    runSpacing: 8,
                                    children: [
                                      for (final a in albumsOfArtist)
                                        SizedBox(
                                          width: 148,
                                          child: AlbumCard(
                                            group: a,
                                            size: 132,
                                            subtitle: a.year?.toString() ?? '',
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.kind,
    required this.name,
    required this.group,
    required this.artwork,
    required this.meta,
    required this.format,
    required this.onPlay,
    required this.onShuffle,
  });

  final GroupKind kind;
  final String name;
  final LibraryGroup? group;
  final String? artwork;
  final String meta;
  final String? format;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final album = kind == GroupKind.album;
    final artist = album ? group?.detail : null;
    return SizedBox(
      height: album ? 290 : 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.55,
            child: CoverBackdrop(seed: name.hashCode, imagePath: artwork),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.bg.withValues(alpha: 0), c.bg],
                stops: const [0.45, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 32, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pressable(
                  onTap: () =>
                      context.go(album ? Routes.albums : Routes.artists),
                  semanticLabel: album ? t.navAlbums : t.navArtists,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorRegular.caretLeft, size: 16, color: c.fg),
                        const SizedBox(width: 4),
                        Text(
                          album ? t.navAlbums : t.navArtists,
                          style: MmType.label.copyWith(
                            fontSize: 13,
                            color: c.fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (album) ...[
                      CoverArt(
                        size: 200,
                        radius: MmRadius.card,
                        seed: name.hashCode,
                        imagePath: artwork,
                      ),
                      const SizedBox(width: 28),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (album)
                            Text(
                              [
                                t.albumOverline,
                                group?.year?.toString(),
                              ].whereType<String>().join(' · ').toUpperCase(),
                              style: MmType.overline.copyWith(color: c.fg),
                            ),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MmType.displayXl.copyWith(color: c.fg),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (artist != null)
                                Pressable(
                                  onTap: () => openGroup(context, ref, (
                                    kind: GroupKind.artist,
                                    name: artist,
                                  )),
                                  semanticLabel: artist,
                                  child: Text(
                                    artist,
                                    style: MmType.labelStrong.copyWith(
                                      color: c.fg,
                                    ),
                                  ),
                                ),
                              Text(
                                '${artist != null ? ' · ' : ''}$meta',
                                style: MmType.bodySm.copyWith(color: c.fgSoft),
                              ),
                              if (format != null)
                                Text(
                                  ' · $format',
                                  style: MmType.monoStyle(
                                    size: 12.5,
                                    color: c.fgSoft,
                                  ),
                                ),
                            ],
                          ),
                          if (album) ...[
                            const SizedBox(height: 16),
                            _Actions(onPlay: onPlay, onShuffle: onShuffle),
                          ],
                        ],
                      ),
                    ),
                    if (!album) _Actions(onPlay: onPlay, onShuffle: onShuffle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onPlay, required this.onShuffle});

  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget pill(
      String label,
      IconData icon,
      VoidCallback onTap, {
      required bool primary,
    }) => Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 42,
        padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
        decoration: BoxDecoration(
          color: primary ? c.coral : c.fg.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(MmRadius.pill),
          boxShadow: primary ? MmShadows.playHalo : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: primary ? c.coralInk : c.fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: MmType.labelStrong.copyWith(
                color: primary ? c.coralInk : c.fg,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill(t.playVerb, PhosphorFill.play, onPlay, primary: true),
        const SizedBox(width: 10),
        pill(t.shuffle, PhosphorRegular.shuffle, onShuffle, primary: false),
      ],
    );
  }
}

/// Tracks of a group: 42 px rows (60 dp on Android), the playing one in
/// coral with the equalizer glyph; double-click plays on Windows.
class _TrackList extends ConsumerWidget {
  const _TrackList({
    required this.items,
    required this.onPlay,
    this.numbered = false,
    this.mobile = false,
  });

  final List<LibraryItem> items;
  final ValueChanged<int> onPlay;
  final bool numbered;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final playing = ref.watch(
      queueProvider.select((q) => q.current?.libraryId),
    );
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Builder(
            builder: (context) {
              final item = items[i];
              final on = item.id == playing;
              final number = numbered ? (item.trackNo ?? i + 1) : i + 1;
              return Opacity(
                opacity: item.missing ? 0.72 : 1,
                child: Pressable(
                  onTap: mobile ? () => onPlay(i) : () {},
                  onDoubleTap: mobile ? null : () => onPlay(i),
                  semanticLabel: item.title,
                  pressScale: mobile ? 0.98 : 1,
                  hoverColor: on ? null : c.cardHover,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: mobile ? 60 : 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: on ? c.coralSubtle : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: on
                              ? Icon(
                                  PhosphorFill.equalizer,
                                  size: 15,
                                  color: c.coralStrong,
                                )
                              : Text(
                                  '$number',
                                  style: MmType.monoStyle(
                                    size: 12,
                                    color: c.faint,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    (mobile
                                            ? MmType.heading.copyWith(
                                                fontSize: 15,
                                              )
                                            : MmType.labelStrong)
                                        .copyWith(
                                          color: on ? c.coralStrong : c.fg,
                                        ),
                              ),
                              if (item.missing)
                                Text(
                                  t.fileMissing,
                                  style: MmType.caption.copyWith(
                                    color: c.warning,
                                  ),
                                )
                              else if (mobile && item.artist != null)
                                Text(
                                  item.artist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MmType.caption.copyWith(
                                    fontSize: 12.5,
                                    color: on ? c.coralStrong : c.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item.durationSecs != null)
                          Text(
                            formatClock(
                              Duration(
                                milliseconds: (item.durationSecs! * 1000)
                                    .round(),
                              ),
                            ),
                            style: MmType.monoStyle(size: 12, color: c.muted),
                          ),
                        const SizedBox(width: 14),
                        FavoriteHeart(on: item.favorite, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _MobileGroup extends StatelessWidget {
  const _MobileGroup({
    required this.kind,
    required this.name,
    required this.group,
    required this.artwork,
    required this.items,
    required this.meta,
    required this.albums,
    required this.onPlay,
    required this.onShuffle,
  });

  final GroupKind kind;
  final String name;
  final LibraryGroup? group;
  final String? artwork;
  final List<LibraryItem> items;
  final String meta;
  final List<LibraryGroup> albums;
  final ValueChanged<int> onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final album = kind == GroupKind.album;
    final artist = album ? group?.detail : null;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 520,
          // Eased fade: a linear one ends on a visible edge (Mach band).
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xD9FFFFFF),
                Color(0x8CFFFFFF),
                Color(0x40FFFFFF),
                Color(0x14FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0, 0.35, 0.6, 0.78, 0.91, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: CoverBackdrop(seed: name.hashCode, imagePath: artwork),
          ),
        ),
        ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Row(
              children: [
                Pressable(
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(album ? Routes.albums : Routes.artists),
                  semanticLabel: t.back,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      PhosphorRegular.arrowLeft,
                      size: 24,
                      color: c.fg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: CoverArt(
                size: 210,
                radius: album ? MmRadius.xl : 105,
                seed: name.hashCode,
                imagePath: artwork,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MmType.titleLg.copyWith(fontSize: 22, color: c.fg),
            ),
            if (artist != null)
              Text(
                artist,
                textAlign: TextAlign.center,
                style: MmType.heading.copyWith(color: c.coralStrong),
              ),
            const SizedBox(height: 2),
            Text(
              [
                if (album) group?.year?.toString(),
                meta,
              ].whereType<String>().join(' · '),
              textAlign: TextAlign.center,
              style: MmType.caption.copyWith(fontSize: 12.5, color: c.fgSoft),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  const Spacer(),
                  Pressable(
                    onTap: onShuffle,
                    semanticLabel: t.shuffle,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        PhosphorRegular.shuffle,
                        size: 24,
                        color: c.fg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    onTap: () => onPlay(0),
                    semanticLabel: t.play,
                    pressScale: 0.92,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: c.coral,
                        shape: BoxShape.circle,
                        boxShadow: MmShadows.playHalo,
                      ),
                      child: Icon(
                        PhosphorFill.play,
                        size: 26,
                        color: c.coralInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _TrackList(
                items: items,
                numbered: album,
                mobile: true,
                onPlay: onPlay,
              ),
            ),
            if (albums.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text(
                  t.navAlbums,
                  style: MmType.title.copyWith(color: c.fg),
                ),
              ),
              SizedBox(
                height: 196,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final a in albums)
                      SizedBox(
                        width: 148,
                        child: AlbumCard(
                          group: a,
                          size: 132,
                          subtitle: a.year?.toString() ?? '',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
