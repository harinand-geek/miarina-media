import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../playback/playing_bars.dart';
import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../common/state_views.dart';
import '../../design/widgets/states.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/cinema_screen.dart';
import '../focus/focus_data.dart';
import '../import/import_data.dart';
import '../library/groups.dart';
import '../library/library_data.dart';
import '../now_playing/lyrics_view.dart';
import '../now_playing/now_playing_shared.dart';
import '../playback/playback.dart';
import 'home_data.dart';
import 'phone_home.dart';

/// W-00 Accueil Écouter (Windows) and A-00 Accueil Musique (Android):
/// resume card, automatic lists, recent albums; on wide Windows windows a
/// 320 px "Now playing" panel without transport (it lives in the bar).
class ListenHomeScreen extends ConsumerWidget {
  const ListenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 720;
    // A-00 on the phone: the expressive home (2026-11-25).
    if (mobile) return const PhoneMusicHome();
    final t = L10n.of(context);
    final data = ref.watch(homeProvider);
    final home = data.value;
    if (data.hasError) {
      return LibraryErrorView(
        error: data.error!,
        onRetry: () => ref.invalidate(homeProvider),
      );
    }
    if (home == null) return const SkeletonGrid(minTile: 240);
    // W-O1: an empty library on a first launch opens the welcome screens,
    // unless the app was opened to play a file.
    if (home.isEmpty &&
        !mobile &&
        ref.watch(onboardingProvider).value == false &&
        !ref.watch(launchedWithMediaProvider) &&
        ref.watch(queueProvider.select((q) => q.current == null))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.welcome);
      });
    }

    // Expressive redesign (decision 0010): the phone's home, laid out wide,
    // led by the resume card and the automatic lists of W-00.
    final body = home.isEmpty
        ? const EmptyListenHome()
        : PhoneMusicHome(
            wide: true,
            lead: [
              if (home.resume.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _ResumeCard(items: home.resume),
                ),
              if (home.lists.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionTitle(t.autoLists),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, box) {
                          const gap = 16.0;
                          final w = (box.maxWidth - gap * 3) / 4;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final l in home.lists) ...[
                                SizedBox(
                                  width: w,
                                  child: _AutoListCard(list: l),
                                ),
                                const SizedBox(width: gap),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        if (width >= 1280) const SizedBox(width: 340, child: _NowPanel()),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: MmType.title.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: c.fg,
            ),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: MmType.label.copyWith(fontSize: 13, color: c.fgSoft),
        ),
      ),
    );
  }
}

String _kindLabel(L10n t, ResumeItem r) => r.item.isVideo
    ? t.tabCinema
    : r.focus != null
    ? t.tabFocus
    : t.tabMusic;

/// Resumes [r]; a video opens its player (W-C3 / A-04), an episode with
/// the rest of its series after it.
Future<void> resumeItem(
  BuildContext context,
  WidgetRef ref,
  L10n t,
  ResumeItem r,
) async {
  final video = r.video;
  final focus = r.focus;
  if (video != null) {
    await playVideo(ref, t, video);
  } else if (focus != null) {
    final items = await ref.read(focusProgramProvider(focus.program).future);
    final i = items.indexWhere((f) => f.item.id == focus.item.id);
    await playFocus(
      ref.read(queueProvider.notifier),
      i < 0 ? [focus] : items,
      start: i < 0 ? 0 : i,
    );
    if (context.mounted) context.push(Routes.focusPlayer);
    return;
  } else {
    await ref.read(queueProvider.notifier).playAll([
      queueEntryOf(r.item, unknownArtist: t.unknownArtist),
    ]);
  }
  if (r.item.isVideo && context.mounted) context.push(Routes.watch);
}

String _resumeTitle(L10n t, ResumeItem r) =>
    r.video == null ? r.item.title : resumeTitle(t, r.video!);

/// "Reprendre" (W-00): 216 px card on the blurred cover, progress, resume
/// button with the exact time; several unfinished items page sideways.
class _ResumeCard extends ConsumerStatefulWidget {
  const _ResumeCard({required this.items});

  final List<ResumeItem> items;

  @override
  ConsumerState<_ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends ConsumerState<_ResumeCard> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  // The card always sits on a dark veil over the cover, so it keeps the dark
  // palette in the light theme too (its texts stay readable).
  @override
  Widget build(BuildContext context) => Theme(
    data: buildMmTheme(MmColors.dark),
    child: Builder(builder: _card),
  );

  Widget _card(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      height: 216,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        border: Border.all(color: c.line),
        boxShadow: MmShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.items.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, i) => _ResumePage(r: widget.items[i]),
          ),
          if (widget.items.length > 1)
            Positioned(
              right: 196,
              bottom: 18,
              child: Row(
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    Pressable(
                      onTap: () => _pages.animateToPage(
                        i,
                        duration: MmMotion.of(context).album,
                        curve: MmMotion.standard,
                      ),
                      semanticLabel: '${i + 1} / ${widget.items.length}',
                      child: AnimatedContainer(
                        duration: MmMotion.of(context).state,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? c.fg
                              : c.fg.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
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

class _ResumePage extends ConsumerWidget {
  const _ResumePage({required this.r});

  final ResumeItem r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final i = r.item;
    final left = r.remaining;
    final sub = [
      if (r.video == null) ...[i.artist, i.album] else r.video!.episodeTitle,
      if (left != null) t.minutesLeft(left.inMinutes),
    ].whereType<String>().join(' · ');
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverBackdrop(
          seed: i.id,
          imagePath: i.thumbnail,
          veil: const Color(0x260E0E0E),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xF00E0E0E), Color(0x330E0E0E)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorRegular.clockCounterClockwise,
                          size: 15,
                          color: c.coralStrong,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.homeResumeKind(_kindLabel(t, r)),
                          style: MmType.captionStrong.copyWith(
                            fontSize: 12.5,
                            color: c.coralStrong,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _resumeTitle(t, r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.display.copyWith(color: c.fg),
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.body.copyWith(
                        fontSize: 13.5,
                        color: c.fgSoft,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 300,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.fg.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: r.progress,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.coral,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Fixed card height: the buttons shrink (ellipsis) on
                    // narrow windows or large text instead of wrapping.
                    Row(
                      children: [
                        Flexible(
                          child: _Pill(
                            label: t.homeResumeAt(formatClock(r.position)),
                            icon: PhosphorFill.play,
                            primary: true,
                            onTap: () => resumeItem(context, ref, t, r),
                          ),
                        ),
                        if (i.album != null) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: _Pill(
                              label: t.openAlbum,
                              onTap: () => openGroup(context, ref, (
                                kind: GroupKind.album,
                                name: i.album!,
                              )),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              CoverArt(
                size: i.isVideo ? 112 : 140,
                aspectRatio: i.isVideo ? 2 / 3 : 1,
                radius: MmRadius.lg,
                seed: i.id,
                imagePath: i.thumbnail,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final IconData? icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final fg = primary ? c.coralInk : c.fg;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 40,
        padding: EdgeInsets.fromLTRB(icon == null ? 16 : 12, 0, 16, 0),
        decoration: BoxDecoration(
          color: primary ? c.coral : c.fg.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: primary
              ? null
              : Border.all(color: c.fg.withValues(alpha: 0.12)),
          boxShadow: primary ? MmShadows.playHalo : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.labelStrong.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card of an automatic list: cover, count badge, play on hover.
class _AutoListCard extends ConsumerStatefulWidget {
  const _AutoListCard({required this.list});

  final AutoList list;

  @override
  ConsumerState<_AutoListCard> createState() => _AutoListCardState();
}

class _AutoListCardState extends ConsumerState<_AutoListCard> {
  bool _hover = false;

  void _play(L10n t) => ref.read(queueProvider.notifier).playAll([
    for (final i in widget.list.items)
      queueEntryOf(i, unknownArtist: t.unknownArtist),
  ]);

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final motion = MmMotion.of(context);
    final l = widget.list;
    final (title, icon) = switch (l.kind) {
      AutoListKind.mostPlayed => (t.listMostPlayed, PhosphorRegular.trendUp),
      AutoListKind.recentlyAdded => (
        t.listRecentlyAdded,
        PhosphorRegular.clock,
      ),
      AutoListKind.favorites => (t.navFavorites, PhosphorRegular.heart),
    };
    final artists = l.items
        .map((i) => i.artist)
        .whereType<String>()
        .toSet()
        .toList();
    final body = switch (l.kind) {
      AutoListKind.mostPlayed when artists.length > 2 => t.andOthers(
        artists.take(2).join(', '),
        artists.length - 2,
      ),
      AutoListKind.mostPlayed => artists.join(', '),
      AutoListKind.recentlyAdded => t.listRecentlyAddedBody,
      AutoListKind.favorites => t.listFavoritesBody,
    };
    final cover = l.items
        .map((i) => i.thumbnail)
        .whereType<String>()
        .firstOrNull;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: () => _play(t),
        semanticLabel: '${t.play} $title',
        pressScale: 0.98,
        borderRadius: BorderRadius.circular(MmRadius.xl),
        child: AnimatedContainer(
          duration: motion.hover,
          padding: const EdgeInsets.all(12),
          transform: Matrix4.translationValues(
            0,
            _hover && !motion.reduced ? -3 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: _hover ? c.surface2 : c.surface,
            borderRadius: BorderRadius.circular(MmRadius.xl),
            border: Border.all(color: c.line),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      CoverArt(
                        size: size,
                        radius: MmRadius.md,
                        seed: l.kind.index * 7 + 3,
                        imagePath: cover,
                        shadow: false,
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xB30E0E0E),
                            borderRadius: BorderRadius.circular(MmRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // On a dark chip in both themes.
                              Icon(icon, size: 13, color: MmColors.dark.fg),
                              const SizedBox(width: 4),
                              Text(
                                '${l.count}',
                                style: MmType.captionStrong.copyWith(
                                  color: MmColors.dark.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: AnimatedOpacity(
                          duration: motion.hover,
                          opacity: _hover ? 1 : 0,
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.heading.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.fg,
                    ),
                  ),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.caption.copyWith(
                      fontSize: 12.5,
                      color: c.muted,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Right panel of W-00: what plays (cover, title, current lyric line) and
/// what comes next. No transport here: it is in the bar.
class _NowPanel extends ConsumerWidget {
  const _NowPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final q = ref.watch(queueProvider);
    final entry = q.current;
    final upcoming = q.upcoming.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 22, 20, 18),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MmRadius.xl),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LivePlayingBars(color: c.coralStrong, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.nowPlaying,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 12.5,
                          color: c.fgSoft,
                        ),
                      ),
                    ),
                    if (entry != null)
                      Pressable(
                        onTap: () => context.go(Routes.now),
                        semanticLabel: t.openNowPlaying,
                        tooltip: t.openNowPlaying,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            PhosphorRegular.arrowsOutSimple,
                            size: 17,
                            color: c.muted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (entry == null)
                  Text(
                    t.nowPlayingHint,
                    style: MmType.bodySm.copyWith(color: c.muted),
                  )
                else ...[
                  LayoutBuilder(
                    builder: (context, box) => CoverArt(
                      size: box.maxWidth,
                      radius: MmRadius.lg,
                      seed: entry.seed,
                      imagePath: entry.artwork,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.title.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: c.fg,
                              ),
                            ),
                            Text(
                              [
                                entry.subtitle,
                                entry.album,
                              ].whereType<String>().join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.caption.copyWith(
                                fontSize: 12.5,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (entry.libraryId != null)
                        Pressable(
                          onTap: () => toggleCurrentFavorite(ref),
                          semanticLabel: entry.favorite
                              ? t.favoriteRemove
                              : t.favoriteAdd,
                          pressScale: 0.85,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: FavoriteHeart(on: entry.favorite, size: 20),
                          ),
                        ),
                    ],
                  ),
                  const _LyricPeek(),
                ],
              ],
            ),
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionTitle(
              t.upNext,
              action: _Link(
                t.fullQueue,
                () => context.go('${Routes.now}?tab=queue'),
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, e) in upcoming.indexed)
              Pressable(
                onTap: () => ref.read(queueProvider.notifier).playUpcoming(i),
                semanticLabel: e.title,
                hoverColor: c.cardHover,
                borderRadius: BorderRadius.circular(MmRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      CoverArt(
                        size: 40,
                        radius: 8,
                        seed: e.seed,
                        imagePath: e.artwork,
                        shadow: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.labelStrong.copyWith(color: c.fg),
                            ),
                            if (e.subtitle != null)
                              Text(
                                e.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.caption.copyWith(color: c.muted),
                              ),
                          ],
                        ),
                      ),
                      if (e.duration != null)
                        Text(
                          formatClock(e.duration!),
                          style: MmType.monoStyle(size: 11.5, color: c.muted),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The lyric line being sung and the next one, under the cover.
class _LyricPeek extends ConsumerWidget {
  const _LyricPeek();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final lyrics = ref.watch(currentLyricsProvider).value;
    if (lyrics == null) return const SizedBox.shrink();
    // 4 updates per second are enough for a line that lasts seconds.
    final position = ref.watch(
      playbackProvider.select((s) => s.value?.position ?? Duration.zero),
    );
    final i = lyrics.indexAt(position);
    final current = i < 0 ? null : lyrics.lines[i].text;
    final next = i + 1 < lyrics.lines.length ? lyrics.lines[i + 1].text : null;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MmRadius.md),
      ),
      child: AnimatedSwitcher(
        duration: MmMotion.of(context).screen,
        // Left-aligned like the design (the default layout centres).
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        child: Column(
          key: ValueKey(i),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current ?? '…', style: MmType.heading.copyWith(color: c.fg)),
            if (next != null)
              Text(
                next,
                style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyListenHome extends StatelessWidget {
  const EmptyListenHome({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorRegular.headphones, size: 44, color: c.faintIcon),
              const SizedBox(height: 14),
              Text(
                t.homeEmptyTitle,
                textAlign: TextAlign.center,
                style: MmType.title.copyWith(color: c.fg),
              ),
              const SizedBox(height: 6),
              Text(
                t.homeEmptyBody,
                textAlign: TextAlign.center,
                style: MmType.bodySm.copyWith(color: c.muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _Pill(
                    label: t.goGet,
                    icon: PhosphorRegular.downloadSimple,
                    primary: true,
                    onTap: () => context.go(Routes.get),
                  ),
                  _Pill(
                    label: t.goTracks,
                    onTap: () => context.go(Routes.tracks),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
