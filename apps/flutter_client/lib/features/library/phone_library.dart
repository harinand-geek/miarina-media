import 'dart:math' as math;

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
import '../../design/widgets/track_bar.dart' show formatClock;
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../playback/playback.dart';
import '../playback/settings_store.dart';
import 'groups.dart';
import 'library_data.dart';

/// Phone library of the expressive redesign (2026-11-25, decision 0010):
/// big title, search, tabs with their counts, rows joined into rounded
/// blocks, covers tinting their cards, artists in a soft flower shape.

/// Neutral filled surface (grey in light, raised in dark).
Color phoneTile(MmColors c) =>
    c.brightness == Brightness.dark ? c.surface : Color.lerp(c.bg, c.fg, 0.07)!;

/// Titres shown as a grid instead of a list on the phone; remembered.
final phoneTracksGridProvider = AsyncNotifierProvider<PhoneTracksGrid, bool>(
  PhoneTracksGrid.new,
);

class PhoneTracksGrid extends AsyncNotifier<bool> {
  static const _key = 'phoneTracksGrid';

  @override
  Future<bool> build() async {
    try {
      return await ref.read(settingsStoreProvider).read(_key) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> set(bool grid) async {
    state = AsyncData(grid);
    try {
      await ref.read(settingsStoreProvider).write(_key, grid);
    } catch (_) {
      // Only the choice is lost.
    }
  }
}

/// Number of titles, albums and artists, for the tabs.
final libraryCountsProvider = FutureProvider<(int, int, int)>((ref) async {
  final api = ref.watch(libraryApiProvider);
  final tracks = await api.tracks(
    search: '',
    favoritesOnly: false,
    offset: 0,
    limit: 1,
  );
  final albums = await ref.watch(groupsProvider(GroupKind.album).future);
  final artists = await ref.watch(groupsProvider(GroupKind.artist).future);
  return (tracks.total.toInt(), albums.length, artists.length);
});

/// Title, search field and tabs of the phone library screens.
class PhoneLibraryHeader extends StatelessWidget {
  const PhoneLibraryHeader({super.key, required this.current, this.title});

  /// Route of the tab shown.
  final String current;

  /// Big title; « Bibliothèque » by default.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Text(
            title ?? t.phoneLibrary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MmType.displayXl.copyWith(
              fontSize: 40,
              height: 1.15,
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation.weight(600)],
              color: c.fg,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Pressable(
            onTap: () => context.push(Routes.search),
            semanticLabel: t.searchPlaceholder,
            pressScale: 0.98,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: phoneTile(c),
                borderRadius: BorderRadius.circular(MmRadius.pill),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorRegular.magnifyingGlass,
                    size: 22,
                    color: c.fgSoft,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      t.searchPlaceholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.body.copyWith(fontSize: 16, color: c.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LibraryTabs(current: current),
      ],
    );
  }
}

/// Titres · Albums · Artistes · Playlists with their counts; the line under
/// the current one slides in.
class LibraryTabs extends ConsumerWidget {
  const LibraryTabs({super.key, required this.current});

  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final counts = ref.watch(libraryCountsProvider).value;
    final tabs = [
      // Back to the Music home (owner's request, 2026-11-25).
      (t.navHome, Routes.listenHome, null),
      (t.navTracks, Routes.tracks, counts?.$1),
      (t.navAlbums, Routes.albums, counts?.$2),
      (t.navArtists, Routes.artists, counts?.$3),
      (t.navPlaylists, Routes.playlists, null),
    ];
    final motion = MmMotion.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (label, route, n) in tabs)
            Builder(
              builder: (context) {
                final on =
                    route == current ||
                    (route == Routes.tracks && current == Routes.favorites);
                return Pressable(
                  onTap: on ? null : () => context.go(route),
                  semanticLabel: n == null ? label : '$label $n',
                  selected: on,
                  pressScale: 0.96,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    // The line is as wide as the label and its count.
                    child: IntrinsicWidth(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: MmType.body.copyWith(
                                  fontSize: 17,
                                  fontWeight: on
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontVariations: [
                                    FontVariation.weight(on ? 650 : 500),
                                  ],
                                  color: on ? c.fg : c.fgSoft,
                                ),
                              ),
                              if (n != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '$n',
                                  style: MmType.body.copyWith(
                                    fontSize: 17,
                                    color: on ? c.fg : c.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          AnimatedContainer(
                            duration: motion.album,
                            curve: MmMotion.standard,
                            height: 3,
                            margin: EdgeInsets.symmetric(
                              horizontal: on ? 0 : 30,
                            ),
                            decoration: BoxDecoration(
                              color: on ? c.fg : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A small outlined chip of the library toolbars.
class ToolChip extends StatelessWidget {
  const ToolChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.on = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      selected: on,
      pressScale: 0.94,
      child: AnimatedContainer(
        duration: MmMotion.of(context).state,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? phoneTile(c) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? phoneTile(c) : c.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (on)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(PhosphorRegular.check, size: 16, color: c.fg),
              )
            else if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(icon, size: 16, color: c.fg),
              ),
            Text(
              label,
              style: MmType.label.copyWith(fontSize: 15, color: c.fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cover on top, its title on a band tinted by the cover.
class TintedCoverCard extends ConsumerStatefulWidget {
  const TintedCoverCard({
    super.key,
    required this.imagePath,
    required this.seed,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.width = 150,
    this.onLongPress,
    this.onPlay,
    this.playLabel,
  });

  final String? imagePath;
  final int seed;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double width;

  /// Windows: a play button on the cover while the pointer is over the card
  /// (the album cards' hover play of W-M1a).
  final VoidCallback? onPlay;
  final String? playLabel;

  @override
  ConsumerState<TintedCoverCard> createState() => _TintedCoverCardState();
}

class _TintedCoverCardState extends ConsumerState<TintedCoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.imagePath;
    final seed = widget.seed;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final width = widget.width;
    final tones = watchCoverTones(ref, context, imagePath);
    final small = width < 140;
    final card = Pressable(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      semanticLabel: '$title, $subtitle',
      pressScale: 0.96,
      borderRadius: BorderRadius.circular(small ? 20 : 24),
      child: AnimatedCoverTones(
        tones: tones,
        builder: (context, tones, _) => Container(
          width: width,
          decoration: BoxDecoration(
            color: tones.card,
            borderRadius: BorderRadius.circular(small ? 20 : 24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF000000), Color(0x00000000)],
                  stops: [0.72, 1],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Stack(
                  children: [
                    CoverArt(
                      size: width,
                      radius: 0,
                      seed: seed,
                      imagePath: imagePath,
                      shadow: false,
                    ),
                    if (widget.onPlay != null)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: AnimatedScale(
                          scale: _hover ? 1 : 0.6,
                          duration: MmMotion.of(context).state,
                          curve: MmMotion.spring,
                          child: AnimatedOpacity(
                            opacity: _hover ? 1 : 0,
                            duration: MmMotion.of(context).state,
                            child: Pressable(
                              onTap: widget.onPlay,
                              semanticLabel: widget.playLabel ?? title,
                              tooltip: widget.playLabel,
                              pressScale: 0.9,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: tones.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorFill.play,
                                  size: 20,
                                  color: tones.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(small ? 12 : 14, 0, 10, 0),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.title.copyWith(
                    fontSize: small ? 15 : 17,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation.weight(600)],
                    color: tones.onCard,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(small ? 12 : 14, 0, 10, 12),
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.body.copyWith(
                    fontSize: small ? 13.5 : 14.5,
                    color: tones.onCard.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: card,
    );
  }
}

/// An artist: one of their covers in the flower shape, which turns slowly
/// while one of their titles plays; the name under it.
class ArtistBlob extends ConsumerWidget {
  const ArtistBlob({
    super.key,
    required this.group,
    required this.size,
    this.subtitle,
  });

  final LibraryGroup group;
  final double size;

  /// Under the name (Windows: the number of albums).
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final playing = ref.watch(
      queueProvider.select(
        (q) => q.current?.subtitle?.toLowerCase() == group.name.toLowerCase(),
      ),
    );
    return Pressable(
      onTap: () =>
          openGroup(context, ref, (kind: GroupKind.artist, name: group.name)),
      semanticLabel: group.name,
      pressScale: 0.95,
      borderRadius: BorderRadius.circular(size / 2),
      child: Column(
        children: [
          ScallopClip(
            spinning: playing,
            child: CoverArt(
              size: size,
              radius: 0,
              seed: group.name.hashCode,
              imagePath: group.thumbnail,
              shadow: false,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: MmType.labelStrong.copyWith(
              fontSize: 16,
              letterSpacing: 0.2,
              color: playing ? c.coralStrong : c.fg,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: MmType.body.copyWith(fontSize: 14, color: c.muted),
            ),
        ],
      ),
    );
  }
}

/// Three bars that bounce while the title plays (still when paused or when
/// motion is reduced).
class PlayingBars extends StatefulWidget {
  const PlayingBars({
    super.key,
    required this.color,
    required this.playing,
    this.size = 18,
  });

  final Color color;
  final bool playing;
  final double size;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PlayingBars old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.playing && !MmMotion.of(context).reduced;
    if (on && !_ctl.isAnimating) _ctl.repeat();
    if (!on && _ctl.isAnimating) _ctl.stop();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => SizedBox(
        width: s,
        height: s,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: s * 0.24,
                height:
                    s *
                    (0.35 +
                        0.65 *
                            (0.5 +
                                    0.5 *
                                        math.sin(
                                          _ctl.value * 2 * math.pi + i * 2.1,
                                        ))
                                .abs()),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(s * 0.12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One title of a phone list: part of a rounded block (big outer corners,
/// small inner ones), cover, title, artist, the file format and the dots.
class PhoneTrackRow extends ConsumerWidget {
  const PhoneTrackRow({
    super.key,
    required this.item,
    required this.first,
    required this.last,
    required this.onTap,
    required this.onMore,
    this.leading,
    this.trailing,
    this.moreKey,
  });

  final LibraryItem item;
  final bool first;
  final bool last;
  final VoidCallback onTap;
  final VoidCallback onMore;

  /// Instead of the cover (a track number on an album page).
  final Widget? leading;

  /// Instead of the format (the length on an album page).
  final String? trailing;
  final Key? moreKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final playingId = ref.watch(
      queueProvider.select((q) => q.current?.libraryId),
    );
    final on = playingId == item.id;
    final isPlaying =
        on &&
        ref.watch(playbackProvider.select((s) => s.value?.isPlaying ?? false));
    final radius = BorderRadius.vertical(
      top: Radius.circular(first ? 24 : 6),
      bottom: Radius.circular(last ? 24 : 6),
    );
    final row = c.brightness == Brightness.dark
        ? c.surface
        : Color.lerp(c.bg, c.fg, 0.055)!;
    final accent = c.coralStrong;
    return Opacity(
      opacity: item.missing ? 0.72 : 1,
      child: Pressable(
        onTap: onTap,
        onLongPress: onMore,
        semanticLabel: '${item.title}, ${item.artist ?? t.unknownArtist}',
        borderRadius: radius,
        pressScale: 0.985,
        child: AnimatedContainer(
          duration: MmMotion.of(context).screen,
          height: 76,
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
          decoration: BoxDecoration(
            color: on ? Color.lerp(row, c.coral, 0.14) : row,
            borderRadius: radius,
          ),
          child: Row(
            children: [
              leading ??
                  CoverArt(
                    size: 54,
                    radius: 14,
                    seed: item.id,
                    shadow: false,
                    imagePath: item.thumbnail,
                    child: on
                        ? PlayingBars(color: Colors.white, playing: isPlaying)
                        : null,
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.body.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontVariations: const [FontVariation.weight(600)],
                        color: on ? accent : c.fg,
                      ),
                    ),
                    Text(
                      item.missing
                          ? '${t.fileMissing} · ${t.locate}'
                          : (item.artist ?? t.unknownArtist),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.body.copyWith(
                        fontSize: 14.5,
                        color: item.missing ? c.warning : c.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if ((trailing ?? item.format) != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    trailing ?? item.format!,
                    style: MmType.monoStyle(size: 13, color: c.fgSoft),
                  ),
                ),
              Pressable(
                key: moreKey,
                onTap: onMore,
                semanticLabel: t.moreOptions,
                pressScale: 0.85,
                child: SizedBox(
                  width: 44,
                  height: 56,
                  child: Icon(
                    PhosphorRegular.dotsThree,
                    size: 24,
                    color: c.fgSoft,
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

/// One title of the phone grid: cover with its format and a play button,
/// title and artist under it.
class PhoneTrackTile extends ConsumerWidget {
  const PhoneTrackTile({
    super.key,
    required this.item,
    required this.size,
    required this.onTap,
    required this.onMore,
  });

  final LibraryItem item;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final on = ref.watch(
      queueProvider.select((q) => q.current?.libraryId == item.id),
    );
    final isPlaying =
        on &&
        ref.watch(playbackProvider.select((s) => s.value?.isPlaying ?? false));
    return Opacity(
      opacity: item.missing ? 0.72 : 1,
      child: Pressable(
        onTap: onTap,
        onLongPress: onMore,
        semanticLabel: '${item.title}, ${item.artist ?? t.unknownArtist}',
        pressScale: 0.96,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverArt(
                  size: size,
                  radius: 20,
                  seed: item.id,
                  imagePath: item.thumbnail,
                  shadow: false,
                ),
                if (item.format != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.bg.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(MmRadius.pill),
                      ),
                      child: Text(
                        item.format!,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 11.5,
                          color: c.fg,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xCC1C1D21),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: on
                        ? PlayingBars(
                            color: Colors.white,
                            playing: isPlaying,
                            size: 16,
                          )
                        : const Icon(
                            PhosphorFill.play,
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.body.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(600)],
                color: on ? c.coralStrong : c.fg,
              ),
            ),
            Text(
              item.artist ?? t.unknownArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.body.copyWith(fontSize: 14, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A-02 album / artist page on the phone: the cover fills the top and fades
/// into the page, big title, artist, details, Lecture and Aléatoire in the
/// cover's colours, then the titles in rounded blocks and, for an artist,
/// their albums.
class PhoneGroupPage extends ConsumerWidget {
  const PhoneGroupPage({
    super.key,
    required this.kind,
    required this.name,
    required this.group,
    required this.artwork,
    required this.items,
    required this.meta,
    required this.albums,
    required this.onPlay,
    required this.onShuffle,
    required this.onMore,
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
  final ValueChanged<LibraryItem> onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final album = kind == GroupKind.album;
    final artist = album ? group?.detail : null;
    final width = MediaQuery.sizeOf(context).width;
    final tones = watchCoverTones(ref, context, artwork);
    final heroHeight = math.min(width * 0.95, 420.0);
    return AnimatedCoverTones(
      tones: tones,
      builder: (context, tones, _) => ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SizedBox(
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ShaderMask(
                  // Eased fade into the page (a linear one shows an edge).
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0x8CFFFFFF),
                      Color(0x26FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [0, 0.5, 0.75, 0.9, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: album
                      ? CoverArt(
                          size: width,
                          aspectRatio: width / heroHeight,
                          radius: 0,
                          seed: name.hashCode,
                          imagePath: artwork,
                          shadow: false,
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: ScallopClip(
                              child: CoverArt(
                                size: heroHeight * 0.72,
                                radius: 0,
                                seed: name.hashCode,
                                imagePath: artwork,
                                shadow: false,
                              ),
                            ),
                          ),
                        ),
                ),
                Positioned(
                  left: 12,
                  top: 8,
                  child: DiscButton(
                    icon: PhosphorRegular.caretLeft,
                    label: t.back,
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(album ? Routes.albums : Routes.artists),
                    color: c.bg.withValues(alpha: 0.85),
                    iconColor: c.fg,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.displayXl.copyWith(
                    fontSize: 36,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation.weight(600)],
                    color: c.fg,
                  ),
                ),
                if (artist != null)
                  Pressable(
                    onTap: () => openGroup(context, ref, (
                      kind: GroupKind.artist,
                      name: artist,
                    )),
                    semanticLabel: artist,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        artist,
                        style: MmType.body.copyWith(
                          fontSize: 20,
                          color: c.fgSoft,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (album) group?.year?.toString(),
                    meta,
                  ].whereType<String>().join(' · '),
                  style: MmType.body.copyWith(fontSize: 15, color: c.muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: MorphButton(
                        onTap: items.isEmpty ? null : () => onPlay(0),
                        color: tones.primary,
                        semanticLabel: t.play,
                        height: 60,
                        radius: 30,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorFill.play,
                              size: 20,
                              color: tones.onPrimary,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                t.play,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.labelStrong.copyWith(
                                  fontSize: 17,
                                  color: tones.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MorphButton(
                        onTap: items.isEmpty ? null : onShuffle,
                        color: tones.card,
                        semanticLabel: t.shuffle,
                        height: 60,
                        radius: 30,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorRegular.shuffle,
                              size: 20,
                              color: tones.onCard,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                t.shuffle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.labelStrong.copyWith(
                                  fontSize: 17,
                                  color: tones.onCard,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  t.artistTracks,
                  style: MmType.display.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation.weight(600)],
                    color: c.fg,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 3),
                  PhoneTrackRow(
                    item: items[i],
                    first: i == 0,
                    last: i == items.length - 1,
                    onTap: () => onPlay(i),
                    onMore: () => onMore(items[i]),
                    leading: album
                        ? SizedBox(
                            width: 34,
                            child: Center(
                              child:
                                  ref.watch(
                                    queueProvider.select(
                                      (q) =>
                                          q.current?.libraryId == items[i].id,
                                    ),
                                  )
                                  ? PlayingBars(
                                      color: c.coralStrong,
                                      playing: ref.watch(
                                        playbackProvider.select(
                                          (s) => s.value?.isPlaying ?? false,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      '${items[i].trackNo ?? i + 1}',
                                      style: MmType.monoStyle(
                                        size: 14,
                                        color: c.muted,
                                      ),
                                    ),
                            ),
                          )
                        : null,
                    trailing: items[i].durationSecs == null
                        ? null
                        : formatClock(
                            Duration(
                              milliseconds: (items[i].durationSecs! * 1000)
                                  .round(),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
          if (albums.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 12),
              child: Text(
                t.navAlbums,
                style: MmType.display.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation.weight(600)],
                  color: c.fg,
                ),
              ),
            ),
            SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: albums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => TintedCoverCard(
                  imagePath: albums[i].thumbnail,
                  seed: albums[i].name.hashCode,
                  title: albums[i].name,
                  subtitle: albums[i].year?.toString() ?? '',
                  onTap: () => openGroup(context, ref, (
                    kind: GroupKind.album,
                    name: albums[i].name,
                  )),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
