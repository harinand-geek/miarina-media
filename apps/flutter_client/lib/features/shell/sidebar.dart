import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../library/library_data.dart';

class _Entry {
  const _Entry(this.route, this.label, this.icon, this.filled, {this.count});
  final String route;
  final String label;
  final IconData icon;
  final IconData filled;
  final String? count;
}

/// Windows sidebar of the Listen space (Handoff, "Navigation cible"):
/// 232 px, collapsed to 64 px (icons and tooltips) below 1280 px.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.location, required this.collapsed});

  final String location;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final tracks = ref.watch(libraryStatsProvider).value?.audioCount.toInt();
    final inGet = location.startsWith(Routes.get);

    final groups = <(String?, List<_Entry>)>[
      (
        null,
        [
          _Entry(
            Routes.listenHome,
            t.navHome,
            PhosphorRegular.house,
            PhosphorFill.house,
          ),
          // W-03, under Home in the Cinema & Focus mockups.
          _Entry(
            Routes.history,
            t.navHistory,
            PhosphorRegular.clockCounterClockwise,
            PhosphorFill.clockCounterClockwise,
          ),
        ],
      ),
      (
        t.navSectionMusic,
        [
          _Entry(
            Routes.albums,
            t.navAlbums,
            PhosphorRegular.vinylRecord,
            PhosphorFill.vinylRecord,
          ),
          _Entry(
            Routes.artists,
            t.navArtists,
            PhosphorRegular.user,
            PhosphorFill.user,
          ),
          _Entry(
            Routes.tracks,
            t.navTracks,
            PhosphorRegular.musicNote,
            PhosphorFill.musicNote,
            count: tracks == null ? null : _group(tracks),
          ),
          _Entry(
            Routes.playlists,
            t.navPlaylists,
            PhosphorRegular.queue,
            PhosphorFill.queue,
          ),
          _Entry(
            Routes.favorites,
            t.navFavorites,
            PhosphorRegular.heart,
            PhosphorFill.heart,
          ),
        ],
      ),
      (
        t.navSectionCinema,
        [
          _Entry(
            Routes.cinema,
            t.navMovies,
            PhosphorRegular.filmSlate,
            PhosphorFill.filmSlate,
          ),
          _Entry(
            Routes.personalVideos,
            t.navPersonalVideos,
            PhosphorRegular.monitorPlay,
            PhosphorFill.monitorPlay,
          ),
        ],
      ),
      (
        t.navSectionFocus,
        [
          _Entry(
            Routes.focus,
            t.navPodcasts,
            PhosphorRegular.graduationCap,
            PhosphorFill.graduationCap,
          ),
          _Entry(
            Routes.audiobooks,
            t.navAudiobooks,
            PhosphorRegular.bookOpenText,
            PhosphorFill.bookOpenText,
          ),
        ],
      ),
    ];

    return Container(
      width: collapsed ? 64 : 232,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(right: BorderSide(color: c.divider)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 8 : 10,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SpaceSwitch(inGet: inGet, collapsed: collapsed),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final (head, entries) in groups) ...[
                  if (head != null)
                    collapsed
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              color: c.divider,
                              height: 1,
                              indent: 8,
                              endIndent: 8,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(13, 10, 13, 6),
                            child: Text(
                              head.toUpperCase(),
                              style: MmType.overline.copyWith(color: c.faint),
                            ),
                          ),
                  for (final e in entries)
                    _NavItem(
                      entry: e,
                      active:
                          location == e.route ||
                          // Album and artist pages keep their list lit.
                          ((e.route == Routes.albums ||
                                  e.route == Routes.artists) &&
                              location.startsWith('${e.route}/')) ||
                          // Series pages and the player sit under Films &
                          // séries.
                          (e.route == Routes.cinema &&
                              (location == Routes.series ||
                                  location == Routes.watch)) ||
                          // The Focus player and program pages too.
                          (e.route == Routes.focus &&
                              (location == Routes.focusPlayer ||
                                  location == Routes.focusProgram)),
                      collapsed: collapsed,
                    ),
                ],
              ],
            ),
          ),
          _NavItem(
            entry: _Entry(
              Routes.settings,
              t.navSettings,
              PhosphorRegular.gearSix,
              PhosphorFill.gearSix,
            ),
            active: location.startsWith(Routes.settings),
            collapsed: collapsed,
          ),
        ],
      ),
    );
  }

  static String _group(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.entry,
    required this.active,
    required this.collapsed,
  });

  final _Entry entry;
  final bool active;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final motion = MmMotion.of(context);
    final item = Pressable(
      onTap: active ? null : () => context.go(entry.route),
      semanticLabel: entry.label,
      selected: active,
      hoverColor: c.surface.withValues(alpha: 0.6),
      pressScale: 0.98,
      child: AnimatedContainer(
        duration: motion.state,
        curve: MmMotion.standard,
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 14),
        decoration: BoxDecoration(
          color: active ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: active ? c.line : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            MmIcon(
              entry.icon,
              filled: entry.filled,
              active: active,
              size: 20,
              color: active ? c.coral : c.muted,
            ),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.label.copyWith(color: active ? c.fg : c.muted),
                ),
              ),
              if (entry.count != null)
                Text(
                  entry.count!,
                  style: MmType.caption.copyWith(
                    fontSize: 11.5,
                    color: c.faint,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: collapsed ? Tooltip(message: entry.label, child: item) : item,
    );
  }
}

/// Get / Listen selector, unchanged from the shipped app.
class _SpaceSwitch extends StatelessWidget {
  const _SpaceSwitch({required this.inGet, required this.collapsed});

  final bool inGet;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget side(
      String label,
      IconData icon,
      IconData filled,
      bool on,
      Color tint,
      String route,
    ) {
      final pill = Pressable(
        onTap: on ? null : () => context.go(route),
        semanticLabel: label,
        selected: on,
        pressScale: 0.98,
        child: AnimatedContainer(
          duration: MmMotion.of(context).state,
          height: 34,
          decoration: BoxDecoration(
            color: on ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: on ? c.lineStrong : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MmIcon(
                icon,
                filled: filled,
                active: on,
                size: 18,
                color: on ? tint : c.muted,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.captionStrong.copyWith(
                      color: on ? c.fg : c.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      return collapsed
          ? Tooltip(message: label, child: pill)
          : Expanded(child: pill);
    }

    final children = [
      side(
        t.spaceGet,
        PhosphorRegular.downloadSimple,
        PhosphorFill.downloadSimple,
        inGet,
        c.accent,
        Routes.get,
      ),
      if (collapsed) const SizedBox(height: 2) else const SizedBox(width: 2),
      side(
        t.spaceListen,
        PhosphorRegular.musicNotes,
        PhosphorFill.musicNotes,
        !inGet,
        c.coral,
        Routes.tracks,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(
          collapsed ? MmRadius.xl : MmRadius.pill,
        ),
        border: Border.all(color: c.line),
      ),
      child: collapsed ? Column(children: children) : Row(children: children),
    );
  }
}
