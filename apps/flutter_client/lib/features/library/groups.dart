import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../playback/playback.dart';
import 'library_data.dart';

final groupsProvider = FutureProvider.family<List<LibraryGroup>, GroupKind>(
  (ref, kind) => ref.watch(libraryApiProvider).groups(kind),
);

typedef GroupKey = ({GroupKind kind, String name});

/// Tracks of one album (disc and track order) or one artist.
final groupTracksProvider = FutureProvider.family<List<LibraryItem>, GroupKey>((
  ref,
  key,
) async {
  final page = await ref
      .watch(libraryApiProvider)
      .tracks(
        search: '',
        favoritesOnly: false,
        offset: 0,
        limit: 500,
        album: key.kind == GroupKind.album ? key.name : null,
        artist: key.kind == GroupKind.artist ? key.name : null,
      );
  return page.items;
});

/// Plays every track of a group, optionally shuffled.
Future<void> playGroup(
  WidgetRef ref,
  L10n t,
  GroupKey key, {
  bool shuffle = false,
  int start = 0,
}) async {
  final items = await ref.read(groupTracksProvider(key).future);
  if (items.isEmpty) return;
  final queue = ref.read(queueProvider.notifier);
  if (shuffle != ref.read(queueProvider).shuffle) await queue.toggleShuffle();
  await queue.playAll([
    for (final i in items) queueEntryOf(i, unknownArtist: t.unknownArtist),
  ], start: start);
}

/// Opens an album or artist page. Android keeps a back stack (system back
/// returns to the list); Windows navigates in place.
void openGroup(BuildContext context, WidgetRef ref, GroupKey key) {
  final path = key.kind == GroupKind.album ? Routes.album : Routes.artist;
  final uri = Uri(path: path, queryParameters: {'name': key.name}).toString();
  ref.read(desktopShellProvider) ? context.go(uri) : context.push(uri);
}

String durationWords(double secs) {
  final d = Duration(seconds: secs.round());
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes.remainder(60)} min';
  return '${d.inMinutes} min';
}

/// Album card of the grids (W-M1a, A-00): hover or focus lifts it and shows
/// the coral play button; Enter opens, the button plays.
class AlbumCard extends ConsumerStatefulWidget {
  const AlbumCard({
    super.key,
    required this.group,
    required this.size,
    this.subtitle,
  });

  final LibraryGroup group;
  final double size;
  final String? subtitle;

  @override
  ConsumerState<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends ConsumerState<AlbumCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final motion = MmMotion.of(context);
    final g = widget.group;
    final key = (kind: GroupKind.album, name: g.name);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: () => openGroup(context, ref, key),
        semanticLabel: g.name,
        pressScale: 0.98,
        borderRadius: BorderRadius.circular(MmRadius.card),
        child: AnimatedContainer(
          duration: motion.hover,
          curve: MmMotion.standard,
          padding: const EdgeInsets.all(8),
          transform: Matrix4.translationValues(
            0,
            _hover && !motion.reduced ? -3 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: _hover ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(MmRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CoverArt(
                    size: widget.size,
                    radius: MmRadius.md,
                    seed: g.name.hashCode,
                    imagePath: g.thumbnail,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: AnimatedOpacity(
                      duration: motion.hover,
                      opacity: _hover ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_hover,
                        child: Pressable(
                          onTap: () => playGroup(ref, t, key),
                          semanticLabel: '${t.play} ${g.name}',
                          pressScale: 0.9,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c.coral,
                              shape: BoxShape.circle,
                              boxShadow: MmShadows.menu,
                            ),
                            child: Icon(
                              PhosphorFill.play,
                              size: 20,
                              color: c.coralInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.labelStrong.copyWith(color: c.fg),
              ),
              Text(
                widget.subtitle ??
                    [
                      g.detail,
                      g.year?.toString(),
                    ].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.caption.copyWith(color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Artist of the grid (W-M1b): a circle, the only round shape of the app.
class ArtistCircle extends ConsumerWidget {
  const ArtistCircle({super.key, required this.group, required this.size});

  final LibraryGroup group;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final albums = int.tryParse(group.detail ?? '') ?? 0;
    return Pressable(
      onTap: () =>
          openGroup(context, ref, (kind: GroupKind.artist, name: group.name)),
      semanticLabel: group.name,
      pressScale: 0.97,
      borderRadius: BorderRadius.circular(MmRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            CoverArt(
              size: size,
              radius: size / 2,
              seed: group.name.hashCode,
              imagePath: group.thumbnail,
            ),
            const SizedBox(height: 10),
            Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: MmType.labelStrong.copyWith(color: c.fg),
            ),
            Text(
              t.albumsCount(albums),
              style: MmType.caption.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Android navigation chips of the music tab (A-00): Albums · Tracks ·
/// Artists · Playlists.
class MusicChips extends StatelessWidget {
  const MusicChips({super.key, required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final items = [
      (t.navAlbums, Routes.albums),
      (t.navTracks, Routes.tracks),
      (t.navArtists, Routes.artists),
      (t.navPlaylists, Routes.playlists),
      // Decision 0011: reachable even while the library is empty.
      (t.navOnline, Routes.online),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (label, route) in items) ...[
            Pressable(
              onTap: route == current ? null : () => context.go(route),
              selected: route == current,
              semanticLabel: label,
              child: AnimatedContainer(
                duration: MmMotion.of(context).state,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: route == current ? c.coralSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                  border: Border.all(
                    color: route == current ? c.coralChipBorder : c.lineStrong,
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: MmType.labelStrong.copyWith(
                      fontSize: 13,
                      color: route == current ? c.coralStrong : c.fgSoft,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Empty / error state of the library screens.
class LibraryMessage extends StatelessWidget {
  const LibraryMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: MmType.bodySm.copyWith(color: c.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
