import 'dart:io';
import 'dart:math' as math;

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
import '../../src/rust/api/cinema.dart';
import '../get/get_screens.dart' show revealProvider;
import '../library/groups.dart';
import '../playback/playback.dart';
import 'cinema_data.dart';
import 'cinema_screen.dart';
import 'cinema_widgets.dart';
import 'video_menu.dart';

/// W-C2 series page: 300 px header on the local fanart, what can be chosen
/// before playing (subtitle files, picture format), explicit resume button,
/// seasons and episodes (watched, in progress, missing).
class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key, required this.name});

  final String name;

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  int? _season;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final detail = ref.watch(seriesProvider(widget.name));
    final watch = ref.watch(watchStateProvider).value ?? const WatchState();
    final mobile = MediaQuery.sizeOf(context).width < 720;

    final s = detail.value;
    if (detail.hasError || (detail.hasValue && s == null)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackLink(mobile: mobile),
          Expanded(
            child: LibraryMessage(
              icon: PhosphorRegular.filmSlate,
              title: detail.hasError ? t.libraryError : widget.name,
              body: detail.hasError ? '${detail.error}' : t.seriesMissing,
            ),
          ),
        ],
      );
    }
    if (s == null) return const SizedBox.shrink();

    final target = nextEpisode(s, watch);
    final seasons = {for (final e in s.episodes) e.season ?? 1}.toList()
      ..sort();
    final season = _season ?? target?.episode.season ?? seasons.first;
    final inSeason = [
      for (final e in s.episodes)
        if ((e.season ?? 1) == season) e,
    ];
    final seenCount = inSeason.where((e) => watch.isSeen(e.item.id)).length;
    final allSeen = s.episodes.every((e) => watch.isSeen(e.item.id));
    void mark(Iterable<CinemaItem> eps, {required bool seen}) => ref
        .read(seenMarksProvider.notifier)
        .mark([for (final e in eps) e.item.id], seen: seen);

    Future<void> play(CinemaItem e, {bool fromStart = false}) async {
      await playVideos(
        ref.read(queueProvider.notifier),
        s.episodes,
        start: s.episodes.indexOf(e),
        fromStart: fromStart,
        label: (v) => episodeTitle(t, v),
      );
      if (context.mounted) openPlayer(context);
    }

    final header = _Header(
      detail: s,
      seasons: seasons.length,
      mobile: mobile,
      target: target,
      onPlay: play,
      menu: _SeriesMenu(
        allSeen: allSeen,
        onMark: () => mark(s.episodes, seen: !allSeen),
        onReveal: Platform.isWindows
            ? () => ref.read(revealProvider)(
                s.episodes.first.item.path,
                select: true,
              )
            : null,
      ),
    );

    final tabs = Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final n in seasons) ...[
                    _SeasonTab(
                      label: t.seasonNumber(n),
                      active: n == season,
                      onTap: () => setState(() => _season = n),
                    ),
                    const SizedBox(width: 20),
                  ],
                ],
              ),
            ),
          ),
          Text(
            '${t.seenOf(seenCount, inSeason.length)} · ',
            style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
          ),
          Pressable(
            onTap: () => mark(inSeason, seen: seenCount < inSeason.length),
            semanticLabel: seenCount < inSeason.length
                ? t.markSeasonSeen
                : t.markSeasonUnseen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                seenCount < inSeason.length
                    ? t.markSeasonSeen
                    : t.markSeasonUnseen,
                style: MmType.captionStrong.copyWith(
                  fontSize: 12.5,
                  color: c.fg,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final pad = mobile ? 16.0 : 32.0;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = mobile || box.maxWidth < 900 ? 1 : 2;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 6, pad, 12),
              sliver: SliverToBoxAdapter(child: tabs),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 28),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 90,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _EpisodeRow(
                    episode: inSeason[i],
                    watch: watch,
                    current: inSeason[i] == target?.episode,
                    onTap: () => play(inSeason[i]),
                    onMenu: (at) => showVideoMenu(
                      context,
                      ref,
                      inSeason[i],
                      at,
                      seen: watch.isSeen(inSeason[i].item.id),
                      onPlay: () => play(inSeason[i]),
                    ),
                  ),
                  childCount: inSeason.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "⋯" of the series header: the whole series seen or not, its folder.
class _SeriesMenu extends StatelessWidget {
  const _SeriesMenu({
    required this.allSeen,
    required this.onMark,
    required this.onReveal,
  });

  final bool allSeen;
  final VoidCallback onMark;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget label(String text) =>
        Text(text, style: MmType.label.copyWith(color: c.fg));
    return MenuAnchor(
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
            allSeen ? PhosphorRegular.circle : PhosphorRegular.checkCircle,
            size: 18,
            color: c.muted,
          ),
          onPressed: onMark,
          child: label(allSeen ? t.markSeriesUnseen : t.markSeriesSeen),
        ),
        if (onReveal != null)
          MenuItemButton(
            leadingIcon: Icon(
              PhosphorRegular.folderOpen,
              size: 18,
              color: c.muted,
            ),
            onPressed: onReveal,
            child: label(t.showInExplorer),
          ),
      ],
      builder: (context, menu, _) => Pressable(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        semanticLabel: t.moreOptions,
        tooltip: t.moreOptions,
        pressScale: 0.94,
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0x1AF5F7FA),
            shape: BoxShape.circle,
          ),
          child: Icon(PhosphorRegular.dotsThree, size: 22, color: c.fg),
        ),
      ),
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Pressable(
      onTap: () => context.canPop() ? context.pop() : context.go(Routes.cinema),
      semanticLabel: t.back,
      child: Padding(
        padding: EdgeInsets.fromLTRB(mobile ? 12 : 24, 14, 12, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorRegular.caretLeft, size: 20, color: c.fgSoft),
            const SizedBox(width: 2),
            Text(
              mobile ? t.tabCinema : t.navMovies,
              style: MmType.label.copyWith(fontSize: 13, color: c.fgSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.detail,
    required this.seasons,
    required this.mobile,
    required this.target,
    required this.onPlay,
    required this.menu,
  });

  final SeriesDetail detail;
  final int seasons;
  final bool mobile;
  final ({CinemaItem episode, Duration? resumeAt})? target;
  final Future<void> Function(CinemaItem, {bool fromStart}) onPlay;

  /// "⋯" after the buttons (mockup W-C2).
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final s = detail;
    final overline = [
      t.seriesWord,
      s.year?.toString(),
      s.genre,
      t.seasonsCount(math.max(1, seasons)),
    ].whereType<String>().join(' · ').toUpperCase();

    final chips = <(IconData?, String, bool)>[
      if (s.subtitleLanguages.isNotEmpty)
        (
          PhosphorRegular.subtitles,
          '${s.subtitleLanguages.join(' · ')} (${s.subtitleFormats.join(', ')})',
          false,
        ),
      if (s.videoLabel != null && s.videoLabel!.isNotEmpty)
        (null, s.videoLabel!, true),
    ];

    final target = this.target;
    final ep = target?.episode;
    final resumeAt = target?.resumeAt;
    String? mainLabel;
    if (ep != null && ep.season != null && ep.episode != null) {
      mainLabel = resumeAt != null
          ? t.resumeEpisode(ep.season!, ep.episode!, formatClock(resumeAt))
          : t.playEpisode(ep.season!, ep.episode!);
    } else if (ep != null) {
      mainLabel = resumeAt != null
          ? t.homeResumeAt(formatClock(resumeAt))
          : t.playVerb;
    }

    final posterW = mobile ? 96.0 : 140.0;
    final height = mobile ? 260.0 : 300.0;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(overline, style: MmType.overline.copyWith(color: c.fgSoft)),
        const SizedBox(height: 6),
        Text(
          s.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MmType.displayXl.copyWith(
            fontSize: mobile ? 26 : 38,
            height: mobile ? 30 / 26 : 42 / 38,
            color: c.fg,
          ),
        ),
        if (s.plot != null) ...[
          const SizedBox(height: 8),
          Text(
            s.plot!,
            maxLines: mobile ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: MmType.bodySm.copyWith(
              fontSize: 13.5,
              height: 20 / 13.5,
              color: c.fgSoft,
            ),
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (icon, label, mono) in chips)
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x14F5F7FA),
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 15, color: c.fg),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label,
                        style: mono
                            ? MmType.monoStyle(size: 11, color: c.fg)
                            : MmType.captionStrong.copyWith(color: c.fg),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (mainLabel != null && ep != null) ...[
              _HeaderButton(
                label: mainLabel,
                primary: true,
                onTap: () => onPlay(ep),
              ),
              if (resumeAt != null)
                _HeaderButton(
                  label: t.fromStart,
                  onTap: () => onPlay(ep, fromStart: true),
                ),
            ],
            menu,
          ],
        ),
      ],
    );

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(path: s.backdrop, seed: s.name.hashCode),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.bg,
                  c.bg.withValues(alpha: 0.85),
                  c.bg.withValues(alpha: 0.2),
                ],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [c.bg, c.bg.withValues(alpha: 0)],
                stops: const [0, 0.5],
              ),
            ),
          ),
          Positioned(left: 0, top: 4, child: _BackLink(mobile: mobile)),
          Positioned(
            left: mobile ? 16 : 32,
            right: mobile ? 16 : 32,
            bottom: mobile ? 14 : 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CoverArt(
                  size: posterW,
                  aspectRatio: 2 / 3,
                  radius: MmRadius.md,
                  seed: s.name.hashCode,
                  imagePath: s.poster ?? s.episodes.first.item.thumbnail,
                ),
                SizedBox(width: mobile ? 14 : 24),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The header picture, at reduced opacity behind the gradients.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.path, required this.seed});

  final String? path;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null) {
      return LayoutBuilder(
        builder: (context, box) => CoverArt(
          size: box.maxWidth,
          aspectRatio: box.maxWidth / box.maxHeight,
          radius: 0,
          shadow: false,
          seed: seed,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) => Opacity(
        opacity: 0.55,
        child: Image.file(
          File(p),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
              .round(),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      pressScale: 0.97,
      child: Container(
        height: 42,
        padding: EdgeInsets.fromLTRB(
          primary ? 14 : 16,
          0,
          primary ? 20 : 16,
          0,
        ),
        decoration: BoxDecoration(
          color: primary ? c.coral : const Color(0x1AF5F7FA),
          borderRadius: BorderRadius.circular(MmRadius.pill),
          boxShadow: primary ? MmShadows.playHalo : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (primary) ...[
              Icon(PhosphorFill.play, size: 20, color: c.coralInk),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.heading.copyWith(
                  color: primary ? c.coralInk : c.fg,
                  fontSize: primary ? 14 : 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonTab extends StatelessWidget {
  const _SeasonTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: active ? null : onTap,
      selected: active,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: MmMotion.of(context).state,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? c.coral : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: MmType.heading.copyWith(
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? c.fg : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.watch,
    required this.current,
    required this.onTap,
    required this.onMenu,
  });

  final CinemaItem episode;
  final WatchState watch;
  final bool current;
  final VoidCallback onTap;

  /// Right click / long press: the episode's menu at that point.
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final e = episode;
    final seen = watch.isSeen(e.item.id);
    final at = watch.resumeOf(e.item.id);
    final total = durationOf(e);

    String? line;
    Color lineColor = c.muted;
    if (e.item.missing) {
      line = t.fileMissing;
      lineColor = c.warning;
    } else if (at != null) {
      final left = total == null ? null : total - at;
      line = left == null || left.isNegative
          ? t.homeResumeAt(formatClock(at))
          : t.resumeAtLeft(formatClock(at), t.minutesLeft(left.inMinutes));
    } else if (seen) {
      line = t.watched;
    } else if (e.subtitleLanguages.isNotEmpty) {
      line = t.subtitlesLangs(e.subtitleLanguages.join(', '));
    }

    return GestureDetector(
      onSecondaryTapUp: (d) => onMenu(d.globalPosition),
      onLongPressStart: (d) => onMenu(d.globalPosition),
      child: Pressable(
        onTap: e.item.missing ? null : onTap,
        semanticLabel: episodeTitle(t, e),
        borderRadius: BorderRadius.circular(MmRadius.lg),
        hoverColor: c.surface,
        child: Opacity(
          opacity: e.item.missing ? 0.72 : 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: current ? c.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(MmRadius.lg),
              border: Border.all(color: current ? c.line : Colors.transparent),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CoverArt(
                      size: 128,
                      aspectRatio: 16 / 9,
                      radius: 10,
                      shadow: false,
                      seed: e.item.id,
                      imagePath: e.item.thumbnail,
                    ),
                    if (seen)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Icon(
                          PhosphorFill.checkCircle,
                          size: 18,
                          color: c.accent,
                        ),
                      ),
                    if (seen || at != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10),
                          ),
                          child: PictureProgress(
                            value: progressOf(e, watch),
                            height: 3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episodeTitle(t, e),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.heading.copyWith(color: c.fg),
                      ),
                      if (line != null)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.caption.copyWith(
                            fontSize: 12.5,
                            color: lineColor,
                          ),
                        ),
                    ],
                  ),
                ),
                if (total != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatClock(total),
                    style: MmType.monoStyle(size: 12, color: c.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
