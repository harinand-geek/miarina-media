import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/cover_tones.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/expressive.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../now_playing/now_playing_shared.dart';
import '../playback/playback.dart';
import 'groups.dart';
import 'phone_library.dart';
import 'track_actions.dart';
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
    final plays = items.fold<int>(0, (n, i) => n + i.plays);
    final meta = [
      if (kind == GroupKind.artist && albumsOfArtist.isNotEmpty)
        t.albumsCount(albumsOfArtist.length),
      t.tracksSummary(items.length),
      if (totalSecs > 0) durationWords(totalSecs),
      if (kind == GroupKind.artist && plays > 0) t.playedTimes(plays),
    ].join(' · ');
    // W-M2b "Les plus écoutés": the five most played, from local plays.
    final top = kind == GroupKind.artist
        ? ([
            for (final i in items)
              if (i.plays > 0) i,
          ]..sort((a, b) => b.plays.compareTo(a.plays))).take(5).toList()
        : const <LibraryItem>[];

    return mobile
        ? PhoneGroupPage(
            kind: kind,
            name: name,
            group: group,
            artwork: artwork,
            items: items,
            meta: meta,
            albums: albumsOfArtist,
            onPlay: (i) => playGroup(ref, t, _key, start: i),
            onShuffle: () => playGroup(ref, t, _key, shuffle: true),
            onMore: (item) => showTrackActions(
              context,
              ref,
              item,
              onChanged: () => ref.invalidate(groupTracksProvider(_key)),
            ),
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
                                if (top.isNotEmpty) ...[
                                  Text(
                                    t.groupSortPlays,
                                    style: MmType.title.copyWith(color: c.fg),
                                  ),
                                  const SizedBox(height: 10),
                                  _TrackList(
                                    items: top,
                                    showPlays: true,
                                    onPlay: (i) => playGroup(
                                      ref,
                                      t,
                                      _key,
                                      start: items.indexOf(top[i]),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                ],
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
    // Expressive redesign (decision 0010): a rounded panel in the cover's
    // colours instead of the blurred backdrop.
    return AnimatedCoverTones(
      tones: watchCoverTones(ref, context, artwork),
      builder: (context, tones, _) => Container(
        height: album ? 300 : 260,
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: BoxDecoration(
          color: tones.card,
          borderRadius: BorderRadius.circular(32),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
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
                          Icon(
                            PhosphorRegular.caretLeft,
                            size: 16,
                            color: c.fg,
                          ),
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
                          size: 210,
                          radius: 28,
                          seed: name.hashCode,
                          imagePath: artwork,
                          shadow: false,
                        ),
                        const SizedBox(width: 28),
                      ] else ...[
                        ScallopClip(
                          child: CoverArt(
                            size: 170,
                            radius: 0,
                            seed: name.hashCode,
                            imagePath: artwork,
                            shadow: false,
                          ),
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
                              style: MmType.displayXl.copyWith(
                                fontWeight: FontWeight.w600,
                                fontVariations: const [
                                  FontVariation.weight(600),
                                ],
                                color: tones.onCard,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // A compilation's "Various Artists" is not
                                // an artist page (its tracks go to their own).
                                if (artist != null &&
                                    group?.compilation == true)
                                  Text(
                                    artist,
                                    style: MmType.labelStrong.copyWith(
                                      color: c.fg,
                                    ),
                                  )
                                else if (artist != null)
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
                                  style: MmType.bodySm.copyWith(
                                    color: c.fgSoft,
                                  ),
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
                              _Actions(
                                onPlay: onPlay,
                                onShuffle: onShuffle,
                                tones: tones,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!album)
                        _Actions(
                          onPlay: onPlay,
                          onShuffle: onShuffle,
                          tones: tones,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onPlay,
    required this.onShuffle,
    required this.tones,
  });

  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final CoverTones tones;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    Widget pill(
      String label,
      IconData icon,
      VoidCallback onTap, {
      required bool primary,
    }) {
      final fg = primary ? tones.onPrimary : tones.onButton;
      return MorphButton(
        onTap: onTap,
        color: primary ? tones.primary : tones.button,
        semanticLabel: label,
        height: 48,
        radius: 24,
        pressedRadius: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(label, style: MmType.labelStrong.copyWith(color: fg)),
            ],
          ),
        ),
      );
    }

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
    this.showPlays = false,
  });

  final List<LibraryItem> items;
  final ValueChanged<int> onPlay;
  final bool numbered;

  /// "58 écoutes" before the length ("Les plus écoutés").
  final bool showPlays;

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
                  onTap: () {},
                  onDoubleTap: () => onPlay(i),
                  semanticLabel: item.title,
                  pressScale: 1,
                  hoverColor: on ? null : c.cardHover,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 42,
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
                                style: MmType.labelStrong.copyWith(
                                  color: on ? c.coralStrong : c.fg,
                                ),
                              ),
                              if (item.missing)
                                Text(
                                  t.fileMissing,
                                  style: MmType.caption.copyWith(
                                    color: c.warning,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (showPlays)
                          Padding(
                            padding: const EdgeInsets.only(right: 18),
                            child: Text(
                              t.playsCount(item.plays),
                              style: MmType.caption.copyWith(color: c.muted),
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
