import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../convert/convert_data.dart' show convertProvider;
import '../get/get_data.dart';
import '../health/health_data.dart';
import '../library/library_data.dart';
import '../playlists/playlists_data.dart';

class _Entry {
  const _Entry(
    this.route,
    this.label,
    this.icon,
    this.filled, {
    this.count,
    this.warn = false,
    this.accent = false,
  });
  final String route;
  final String label;
  final IconData icon;
  final IconData filled;
  final String? count;

  /// Amber badge: something needs the user (missing files).
  final bool warn;

  /// Teal badge (open downloads, as in the Tauri app).
  final bool accent;
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
    final playlists = ref.watch(playlistsProvider).value?.length;
    final favorites = ref.watch(favoritesCountProvider).value;
    final inGet = location.startsWith(Routes.get);
    // W-O2: shown when there is something to look at (or while on it).
    final health = ref.watch(healthCountsProvider).value;
    final missing = health?.missing.toInt() ?? 0;
    final duplicates = health?.duplicates ?? 0;
    final onHealth =
        location == Routes.missing || location == Routes.duplicates;

    final open = ref.watch(downloadsSummaryProvider).openCount;
    final converting = ref.watch(convertProvider.select((s) => s.running));
    // Obtenir: the Tauri app's sections, in its order.
    final getGroups = <(String?, List<_Entry>)>[
      (
        null,
        [
          _Entry(
            Routes.get,
            t.getNavHome,
            PhosphorRegular.house,
            PhosphorFill.house,
          ),
          _Entry(
            Routes.getDownloads,
            t.getNavDownloads,
            PhosphorRegular.downloadSimple,
            PhosphorFill.downloadSimple,
            count: open > 0 ? '$open' : null,
            accent: true,
          ),
          _Entry(
            Routes.getBrowser,
            t.getNavBrowser,
            PhosphorRegular.globe,
            PhosphorFill.globe,
          ),
          _Entry(
            Routes.getTorrents,
            t.getNavTorrents,
            PhosphorRegular.shareNetwork,
            PhosphorFill.shareNetwork,
          ),
          _Entry(
            Routes.getHistory,
            t.getNavHistory,
            PhosphorRegular.clockCounterClockwise,
            PhosphorFill.clockCounterClockwise,
          ),
        ],
      ),
      // Outils PC (design_handoff_outils_pc): Windows only.
      if (Platform.isWindows)
        (
          t.toolsGroup,
          [
            _Entry(
              Routes.convert,
              t.navConvert,
              PhosphorRegular.arrowsClockwise,
              PhosphorFill.arrowsClockwise,
              count: converting ? '●' : null,
              accent: true,
            ),
          ],
        ),
    ];
    final groups = inGet
        ? getGroups
        : <(String?, List<_Entry>)>[
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
                  count: playlists == null ? null : _group(playlists),
                ),
                _Entry(
                  Routes.favorites,
                  t.navFavorites,
                  PhosphorRegular.heart,
                  PhosphorFill.heart,
                  count: favorites == null ? null : _group(favorites),
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
            if (missing > 0 || duplicates > 0 || onHealth)
              (
                t.navSectionLibrary,
                [
                  if (missing > 0 || location == Routes.missing)
                    _Entry(
                      Routes.missing,
                      t.navMissing,
                      PhosphorRegular.linkBreak,
                      PhosphorFill.linkBreak,
                      count: missing > 0 ? _group(missing) : null,
                      warn: true,
                    ),
                  if (duplicates > 0 || location == Routes.duplicates)
                    _Entry(
                      Routes.duplicates,
                      t.navDuplicates,
                      PhosphorRegular.copy,
                      PhosphorFill.copy,
                      count: duplicates > 0 ? _group(duplicates) : null,
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
                                  e.route == Routes.artists ||
                                  e.route == Routes.playlists) &&
                              location.startsWith('${e.route}/')) ||
                          // Series pages and the player sit under Films &
                          // séries.
                          (e.route == Routes.cinema &&
                              (location == Routes.series ||
                                  location == Routes.watch)) ||
                          // The Focus player and program pages too.
                          (e.route == Routes.focus &&
                              (location == Routes.focusPlayer ||
                                  location == Routes.focusProgram)) ||
                          // The analysis of a link belongs to Obtenir's home.
                          (e.route == Routes.get &&
                              (location == Routes.getAnalysis ||
                                  location == Routes.getBatch)),
                      collapsed: collapsed,
                      teal: inGet,
                    ),
                ],
              ],
            ),
          ),
          if (inGet && !collapsed) const _DownloadsCard(),
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
    this.teal = false,
  });

  /// Obtenir lights its active entry in teal, as the Tauri app.
  final bool teal;

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
              color: active ? (teal ? c.accentStrong : c.coral) : c.muted,
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
              if (entry.count != null && entry.accent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.accentSubtle,
                    borderRadius: BorderRadius.circular(MmRadius.xs),
                  ),
                  child: Text(
                    entry.count!,
                    style: MmType.monoStyle(
                      size: 11,
                      color: c.chipText,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                )
              else if (entry.count != null && entry.warn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: c.warningSubtle,
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                  ),
                  child: Text(
                    entry.count!,
                    style: MmType.caption.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: c.warning,
                    ),
                  ),
                )
              else if (entry.count != null)
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

/// Downloads at a glance (Tauri sidebar card): what runs, the speed, the
/// overall progress and what waits; opens Téléchargements.
class _DownloadsCard extends ConsumerWidget {
  const _DownloadsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final s = ref.watch(downloadsSummaryProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final head = s.running.isNotEmpty
        ? t.getSumRunning(s.running.length)
        : s.offline
        ? t.getSumOffline
        : s.active.isNotEmpty
        ? t.getSumPaused
        : t.getSumIdle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Pressable(
        onTap: () => context.go(Routes.getDownloads),
        semanticLabel: head,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      head,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.captionStrong.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.fg,
                      ),
                    ),
                  ),
                  if (s.running.isNotEmpty)
                    Text(
                      formatSpeed(s.speed, lang: lang),
                      style: MmType.monoStyle(size: 12, color: c.accentStrong),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(MmRadius.pill),
                child: LinearProgressIndicator(
                  value: s.overallPercent / 100,
                  minHeight: 3,
                  color: c.accent,
                  backgroundColor: c.line,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.getSumQueue(s.queued.length),
                style: MmType.caption.copyWith(fontSize: 11.5, color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
