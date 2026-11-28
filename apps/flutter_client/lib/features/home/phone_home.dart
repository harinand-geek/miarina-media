import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/malagasy_fallback.dart';
import '../../app/router.dart';
import '../../design/cover_tones.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/expressive.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/states.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../cinema/cinema_screen.dart' show resumeTitle;
import '../common/state_views.dart';
import '../library/groups.dart';
import '../library/library_data.dart';
import '../library/phone_library.dart';
import '../playback/playback.dart';
import 'home_data.dart';
import 'listen_home_screen.dart' show EmptyListenHome, resumeItem;
import 'mix_screen.dart';
import 'phone_home_data.dart';

/// A-00 Accueil Musique, expressive redesign (2026-11-25, decision 0010):
/// search, the last things played in a carousel, quick tiles, rows tinted
/// by their covers, the daily mix, titles to discover, the week's listening
/// and the latest plays. Every section comes from the device's own data and
/// hides itself when there is nothing true to show. Sections rise in one
/// after the other; the shuffle button folds into a square while scrolling.
class PhoneMusicHome extends ConsumerStatefulWidget {
  const PhoneMusicHome({super.key, this.wide = false, this.lead = const []});

  /// Windows (W-00, same design): no search field, chips or settings button
  /// (the title bar and the sidebar have them), cards side by side, and
  /// [lead] (the resume card and the automatic lists) instead of the
  /// carousel.
  final bool wide;
  final List<Widget> lead;

  @override
  ConsumerState<PhoneMusicHome> createState() => _PhoneMusicHomeState();
}

class _PhoneMusicHomeState extends ConsumerState<PhoneMusicHome> {
  final _scroll = ScrollController();
  bool _folded = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final fold = _scroll.offset > 120;
      if (fold != _folded) setState(() => _folded = fold);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(phoneHomeProvider);
    final home = data.value;
    if (data.hasError && home == null) {
      return LibraryErrorView(
        error: data.error!,
        onRetry: () => ref.invalidate(phoneHomeProvider),
      );
    }
    if (home == null) {
      return const SkeletonGrid(minTile: 160, padding: 20);
    }
    final sections = _sections(context, home);
    final wide = widget.wide;
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            wide ? 12 : 0,
            wide ? 8 : 0,
            wide ? 12 : 0,
            110,
          ),
          itemCount: sections.length,
          itemBuilder: (context, i) => _Reveal(index: i, child: sections[i]),
        ),
        if (!home.isEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: _ShuffleFab(folded: _folded),
          ),
      ],
    );
  }

  List<Widget> _sections(BuildContext context, PhoneHome home) {
    final t = L10n.of(context);
    final wide = widget.wide;
    return [
      if (!wide) const _Header(),
      Padding(
        padding: EdgeInsets.fromLTRB(20, wide ? 12 : 18, 20, 14),
        child: Text(wide ? t.navHome : t.tabMusic, style: _Type.page(context)),
      ),
      if (!wide) const MusicChips(current: Routes.listenHome),
      ...widget.lead,
      if (home.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: EmptyListenHome(),
        )
      else ...[
        if (home.recent.isNotEmpty && widget.lead.isEmpty) ...[
          const SizedBox(height: 20),
          _Hero(items: home.recent.take(5).toList()),
        ],
        const SizedBox(height: 16),
        _QuickTiles(home: home, wide: wide),
        if (home.recent.isNotEmpty)
          _Section(
            title: t.recentlyPlayed,
            onQueue: () => _enqueue(ref, t, [
              for (final r in home.recent)
                if (!r.item.isVideo) r.item,
            ]),
            onMore: () => context.push(Routes.history),
            child: _Row(
              children: [
                for (final r in home.recent)
                  TintedCoverCard(
                    imagePath: r.item.thumbnail,
                    seed: r.item.id,
                    title: _titleOf(t, r),
                    subtitle: r.item.artist ?? t.unknownArtist,
                    onTap: () => resumeItem(context, ref, t, r),
                  ),
              ],
            ),
          ),
        if (home.recentAlbums.isNotEmpty)
          _Section(
            title: t.recentlyAddedAlbums,
            onMore: () => context.go(Routes.albums),
            child: _Row(
              children: [
                for (final a in home.recentAlbums)
                  TintedCoverCard(
                    imagePath: a.thumbnail,
                    seed: a.name.hashCode,
                    title: a.name,
                    subtitle: a.detail ?? t.unknownArtist,
                    onTap: () => openGroup(context, ref, (
                      kind: GroupKind.album,
                      name: a.name,
                    )),
                  ),
              ],
            ),
          ),
        if (home.mostPlayed.isNotEmpty)
          _Section(
            title: t.mostPlayedTitle,
            onMore: () => openMix(context, MixKind.mostPlayed),
            onQueue: () => _enqueue(ref, t, home.mostPlayed),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final (i, item) in home.mostPlayed.take(5).indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PillRow(
                        item: item,
                        onTap: () => _play(ref, t, home.mostPlayed, start: i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (home.artists.isNotEmpty)
          _Section(
            title: t.yourArtists,
            onMore: () => context.go(Routes.artists),
            child: _Row(
              height: 300,
              children: [for (final a in home.artists) _ArtistCard(group: a)],
            ),
          ),
        if (wide) ...[
          // Windows: mix | discover, counters and tiles; artist | week.
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (home.mix.isNotEmpty) Expanded(child: _MixCard(home: home)),
              Expanded(
                child: Column(
                  children: [
                    if (home.discover.isNotEmpty) ...[
                      _DiscoverCard(home: home),
                      const SizedBox(height: 12),
                    ],
                    _Counters(home: home),
                    const SizedBox(height: 12),
                    _Tiles(home: home),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (home.topArtist != null)
                Expanded(child: _TopArtist(home: home)),
              Expanded(child: _WeekChart(home: home)),
            ],
          ),
        ] else ...[
          if (home.mix.isNotEmpty) ...[
            const SizedBox(height: 28),
            _MixCard(home: home),
          ],
          const SizedBox(height: 12),
          _Counters(home: home),
          if (home.discover.isNotEmpty) ...[
            const SizedBox(height: 28),
            _DiscoverCard(home: home),
          ],
          const SizedBox(height: 12),
          _Tiles(home: home),
          if (home.topArtist != null) ...[
            const SizedBox(height: 12),
            _TopArtist(home: home),
          ],
          const SizedBox(height: 12),
          _WeekChart(home: home),
        ],
        if (home.history.isNotEmpty)
          _Section(
            title: t.navHistory,
            onMore: () => context.push(Routes.history),
            child: _HistoryPeek(home: home),
          ),
      ],
    ];
  }
}

String _titleOf(L10n t, ResumeItem r) =>
    r.video == null ? r.item.title : resumeTitle(t, r.video!);

/// Plays [items] from [start], shuffled or in order.
Future<void> _play(
  WidgetRef ref,
  L10n t,
  List<LibraryItem> items, {
  int start = 0,
  bool shuffle = false,
}) async {
  final list = items.where((i) => !i.missing).toList();
  if (list.isEmpty) return;
  final queue = ref.read(queueProvider.notifier);
  if (shuffle != ref.read(queueProvider).shuffle) await queue.toggleShuffle();
  await queue.playAll([
    for (final i in list) queueEntryOf(i, unknownArtist: t.unknownArtist),
  ], start: start.clamp(0, list.length - 1));
}

Future<void> _enqueue(WidgetRef ref, L10n t, List<LibraryItem> items) async {
  HapticFeedback.lightImpact();
  await ref.read(queueProvider.notifier).enqueue([
    for (final i in items)
      if (!i.missing) queueEntryOf(i, unknownArtist: t.unknownArtist),
  ], next: false);
}

/// Text styles of the home: big, light titles like the expressive design.
abstract final class _Type {
  static TextStyle page(BuildContext context) => MmType.displayXl.copyWith(
    fontSize: 44,
    height: 1.1,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation.weight(600)],
    color: MmColors.of(context).fg,
  );

  static TextStyle section(BuildContext context) => MmType.display.copyWith(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation.weight(600)],
    color: MmColors.of(context).fg,
  );

  static TextStyle cardTitle(Color color) => MmType.title.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation.weight(600)],
    color: color,
  );

  static TextStyle cardSub(Color color) =>
      MmType.body.copyWith(fontSize: 14.5, color: color);
}

/// Neutral filled surface of the tiles (grey in light, raised in dark).
Color _tile(MmColors c) =>
    c.brightness == Brightness.dark ? c.surface : Color.lerp(c.bg, c.fg, 0.07)!;

/// Each section rises 16 dp and fades in, a beat after the previous one,
/// the first time it is built.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MmMotion.of(context).reduced || index > 12) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + 45 * index),
      curve: Interval(math.min(0.5, index * 0.07), 1, curve: MmMotion.standard),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: () => context.push(Routes.search),
              semanticLabel: t.searchPlaceholder,
              pressScale: 0.98,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: _tile(c),
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
                        style: MmType.body.copyWith(
                          fontSize: 16,
                          color: c.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DiscButton(
            icon: PhosphorRegular.gearSix,
            label: t.navSettings,
            onTap: () => context.go(Routes.settings),
            color: _tile(c),
            iconColor: c.fgSoft,
            size: 56,
          ),
        ],
      ),
    );
  }
}

/// A titled section: title, then an "add all to the queue" and a "see all"
/// button when they apply.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.onQueue,
    this.onMore,
  });

  final String title;
  final Widget child;
  final VoidCallback? onQueue;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget icon(IconData i, String label, VoidCallback onTap) => Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      pressScale: 0.85,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(i, size: 24, color: c.fgSoft),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 10, 12),
            child: Row(
              children: [
                Expanded(child: Text(title, style: _Type.section(context))),
                if (onQueue != null)
                  icon(PhosphorRegular.listPlus, t.addAllToQueue, onQueue!),
                if (onMore != null)
                  icon(PhosphorRegular.caretRight, t.seeAll, onMore!),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A horizontal row of cards.
class _Row extends StatelessWidget {
  const _Row({required this.children, this.height = 216});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) => children[i],
    ),
  );
}

/// The last things played, one big card each; the cover drifts a little as
/// the page turns.
class _Hero extends ConsumerStatefulWidget {
  const _Hero({required this.items});

  final List<ResumeItem> items;

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> {
  final _pages = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final items = widget.items;
    return SizedBox(
      height: 320,
      child: PageView.builder(
        controller: _pages,
        itemCount: items.length,
        itemBuilder: (context, i) {
          final r = items[i];
          final shift = (_page - i).clamp(-1.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Pressable(
              onTap: () => resumeItem(context, ref, t, r),
              semanticLabel: _titleOf(t, r),
              pressScale: 0.98,
              borderRadius: BorderRadius.circular(32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.translate(
                        offset: Offset(shift * box.maxWidth * 0.25, 0),
                        child: Transform.scale(
                          scale: 1.15,
                          child: CoverArt(
                            size: box.maxWidth,
                            aspectRatio: box.maxWidth / box.maxHeight,
                            radius: 0,
                            seed: r.item.id,
                            imagePath: r.item.thumbnail,
                            shadow: false,
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xD9000000)],
                            stops: [0.45, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: _Dots(count: items.length, page: _page),
                      ),
                      Positioned(
                        left: 22,
                        right: 18,
                        bottom: 18,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _titleOf(t, r),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _Type.cardTitle(Colors.white)
                                        .copyWith(fontSize: 22),
                                  ),
                                  Text(
                                    r.item.artist ?? t.unknownArtist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _Type.cardSub(
                                      const Color(0xD9FFFFFF),
                                    ).copyWith(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: Color(0xF2F3EFEF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorFill.play,
                                size: 24,
                                color: Color(0xFF1C1B1F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Page dots of the carousel: the current one is a longer bar.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x59000000),
        borderRadius: BorderRadius.circular(MmRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Builder(
              builder: (context) {
                final near = (1 - (page - i).abs()).clamp(0.0, 1.0);
                return Container(
                  width: 7 + 12 * near,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0x80FFFFFF),
                      Colors.white,
                      near,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Favoris · Récents · Plus joués · Mix du jour.
class _QuickTiles extends ConsumerWidget {
  const _QuickTiles({required this.home, this.wide = false});

  final PhoneHome home;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final tiles = [
      (PhosphorRegular.globe, t.navOnline, () => context.push(Routes.online)),
      (
        PhosphorRegular.heart,
        t.navFavorites,
        () => context.go(Routes.favorites),
      ),
      (
        PhosphorRegular.clockCounterClockwise,
        t.quickRecent,
        () => context.push(Routes.history),
      ),
      if (home.mostPlayed.isNotEmpty)
        (
          PhosphorRegular.trendUp,
          t.quickMostPlayed,
          () => openMix(context, MixKind.mostPlayed),
        ),
      if (home.mix.isNotEmpty)
        (
          PhosphorRegular.shuffle,
          mixTitle(t, home.mixPart),
          () => openMix(context, MixKind.moment),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, box) {
          final across = wide ? 4 : 2;
          final w = (box.maxWidth - 10 * (across - 1)) / across;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (icon, label, onTap) in tiles)
                SizedBox(
                  width: w,
                  child: MorphButton(
                    onTap: onTap,
                    color: _tile(c),
                    semanticLabel: label,
                    height: 60,
                    radius: 22,
                    pressedRadius: 30,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Icon(icon, size: 24, color: c.fg),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.body.copyWith(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                fontVariations: const [
                                  FontVariation.weight(600),
                                ],
                                color: c.fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// « Les plus joués »: a pill tinted by the cover, with the play count.
class _PillRow extends ConsumerWidget {
  const _PillRow({required this.item, required this.onTap});

  final LibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final tones = watchCoverTones(ref, context, item.thumbnail);
    final line = [
      item.artist ?? t.unknownArtist,
      if (item.plays > 0) t.playsCount(item.plays),
    ].join(' · ');
    return Pressable(
      onTap: onTap,
      semanticLabel: '${item.title}, $line',
      pressScale: 0.98,
      borderRadius: BorderRadius.circular(MmRadius.pill),
      child: AnimatedCoverTones(
        tones: tones,
        builder: (context, tones, _) => Container(
          height: 78,
          padding: const EdgeInsets.fromLTRB(12, 10, 22, 10),
          decoration: BoxDecoration(
            color: tones.card,
            borderRadius: BorderRadius.circular(MmRadius.pill),
          ),
          child: Row(
            children: [
              CoverArt(
                size: 56,
                radius: 16,
                seed: item.id,
                imagePath: item.thumbnail,
                shadow: false,
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
                      style: _Type.cardTitle(tones.onCard),
                    ),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _Type.cardSub(
                        tones.onCard.withValues(alpha: 0.78),
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
  }
}

/// « Vos artistes »: a tall card, the cover of one of their albums fading
/// into a band tinted by it, with their name.
class _ArtistCard extends ConsumerWidget {
  const _ArtistCard({required this.group});

  final LibraryGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tones = watchCoverTones(ref, context, group.thumbnail);
    final width = math.min(MediaQuery.sizeOf(context).width * 0.56, 260.0);
    return Pressable(
      onTap: () =>
          openGroup(context, ref, (kind: GroupKind.artist, name: group.name)),
      semanticLabel: group.name,
      pressScale: 0.97,
      borderRadius: BorderRadius.circular(32),
      child: AnimatedCoverTones(
        tones: tones,
        builder: (context, tones, _) => Container(
          width: width,
          decoration: BoxDecoration(
            color: tones.card,
            borderRadius: BorderRadius.circular(32),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF000000), Color(0x00000000)],
                  stops: [0.55, 0.92],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: CoverArt(
                  size: width,
                  aspectRatio: width / 300,
                  radius: 0,
                  seed: group.name.hashCode,
                  imagePath: group.thumbnail,
                  shadow: false,
                ),
              ),
              Positioned(
                left: 20,
                right: 16,
                bottom: 22,
                child: Text(
                  group.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _Type.cardTitle(tones.onCard).copyWith(fontSize: 21),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Mix du jour »: three covers, count and length, shuffle and play.
/// The mix of the moment: a tap opens its titles (owner's request,
/// 2026-11-28); the two buttons still play it at once.
class _MixCard extends ConsumerWidget {
  const _MixCard({required this.home});

  final PhoneHome home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final items = home.mix;
    final covers = <LibraryItem>[];
    for (final i in items) {
      if (covers.length == 3) break;
      if (i.thumbnail != null &&
          !covers.any((x) => x.thumbnail == i.thumbnail)) {
        covers.add(i);
      }
    }
    while (covers.length < 3 && covers.length < items.length) {
      covers.add(items[covers.length]);
    }
    final secs = items.fold<double>(0, (a, i) => a + (i.durationSecs ?? 0));
    Widget cover(LibraryItem? i, double size, double radius) => CoverArt(
      size: size,
      radius: radius,
      seed: i?.id ?? 0,
      imagePath: i?.thumbnail,
      shadow: false,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Pressable(
        onTap: () => openMix(context, MixKind.moment),
        semanticLabel: mixTitle(t, home.mixPart),
        pressScale: 0.98,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _tile(c),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  // Big + gap + small = width; two smalls + gap = big.
                  final big = (box.maxWidth - 6) / 1.5;
                  final small = (big - 12) / 2;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover(covers.firstOrNull, big, 22),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          cover(covers.elementAtOrNull(1), small, 18),
                          const SizedBox(height: 12),
                          cover(covers.elementAtOrNull(2), small, 18),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mixTitle(t, home.mixPart),
                          style: _Type.section(context),
                        ),
                        Text(
                          '${t.titlesCount(items.length)} · '
                          '${durationWords(secs)}',
                          style: _Type.cardSub(c.fgSoft).copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  DiscButton(
                    icon: PhosphorRegular.shuffle,
                    label: t.shufflePlay,
                    onTap: () => _play(ref, t, items, shuffle: true),
                    color: Color.lerp(_tile(c), c.fg, 0.08)!,
                    iconColor: c.fg,
                    size: 56,
                  ),
                  const SizedBox(width: 10),
                  DiscButton(
                    icon: PhosphorFill.play,
                    label: t.playAll,
                    onTap: () => _play(ref, t, items),
                    color: c.fg,
                    iconColor: c.bg,
                    size: 64,
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

/// Never played · favorites · added this month.
class _Counters extends StatelessWidget {
  const _Counters({required this.home});

  final PhoneHome home;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final items = [
      (home.neverPlayed, t.counterNever, Routes.tracks),
      (home.favorites, t.navFavorites, Routes.favorites),
      (home.addedMonth, t.counterAdded, Routes.tracks),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final (i, (n, label, route)) in items.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: MorphButton(
                onTap: () => context.go(route),
                color: _tile(c),
                semanticLabel: '$n $label',
                height: 108,
                radius: 24,
                pressedRadius: 32,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CountUp(
                        value: n,
                        style: MmType.display.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          fontVariations: const [FontVariation.weight(500)],
                          color: c.fg,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _Type.cardSub(c.fgSoft)
                            .copyWith(fontSize: 13.5, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A number that counts up to its value when it appears.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (MmMotion.of(context).reduced) return Text('$value', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        NumberFormat.decimalPattern(intlLocaleOf(context)).format(v.round()),
        maxLines: 1,
        style: style,
      ),
    );
  }
}

/// « À découvrir »: titles never played, three covers fanned out.
class _DiscoverCard extends ConsumerWidget {
  const _DiscoverCard({required this.home});

  final PhoneHome home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final covers = home.discover.take(3).toList();
    final reduced = MmMotion.of(context).reduced;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Pressable(
        onTap: () => openMix(context, MixKind.discover),
        semanticLabel: t.discoverTitle,
        pressScale: 0.98,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(22, 22, 12, 22),
          decoration: BoxDecoration(
            color: _tile(c),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.discoverTitle,
                      style: _Type.section(context).copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.discoverCount(home.neverPlayed),
                      style: _Type.cardSub(c.fgSoft).copyWith(fontSize: 16),
                    ),
                    const Spacer(),
                    // The card opens the titles; this plays them shuffled.
                    Pressable(
                      onTap: () => _play(ref, t, home.discover, shuffle: true),
                      semanticLabel: '${t.discoverTitle}, ${t.shufflePlay}',
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Color.lerp(_tile(c), c.fg, 0.08),
                          borderRadius: BorderRadius.circular(MmRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorRegular.shuffle,
                              size: 20,
                              color: c.fg,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                t.shufflePlay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.label.copyWith(
                                  fontSize: 15,
                                  color: c.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 150,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: MmMotion.spring,
                  builder: (context, v, _) => Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      for (final (i, item) in covers.indexed)
                        Transform.translate(
                          offset: Offset((i - 1) * 26.0 * v, (i - 1) * 6.0 * v),
                          child: Transform.rotate(
                            angle: (i - 1) * 0.16 * v,
                            child: CoverArt(
                              size: 104,
                              radius: 18,
                              seed: item.id,
                              imagePath: item.thumbnail,
                            ),
                          ),
                        ),
                    ],
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

/// Album au hasard · today's listening.
class _Tiles extends ConsumerWidget {
  const _Tiles({required this.home});

  final PhoneHome home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final album = home.randomAlbum;
    Widget tile({
      required Widget leading,
      required String label,
      required String value,
      VoidCallback? onTap,
    }) => Expanded(
      child: MorphButton(
        onTap: onTap,
        color: _tile(c),
        semanticLabel: '$label, $value',
        height: 108,
        radius: 26,
        pressedRadius: 34,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _Type.cardSub(c.fgSoft).copyWith(fontSize: 13.5),
                    ),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _Type.cardTitle(c.fg).copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final today = home.todaySeconds ~/ 60;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (album != null)
            tile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CoverArt(
                    size: 60,
                    radius: 16,
                    seed: album.name.hashCode,
                    imagePath: album.thumbnail,
                    shadow: false,
                  ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _tile(c),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorRegular.shuffle,
                        size: 14,
                        color: c.fg,
                      ),
                    ),
                  ),
                ],
              ),
              label: t.randomAlbum,
              value: album.name,
              onTap: () =>
                  playGroup(ref, t, (kind: GroupKind.album, name: album.name)),
            ),
          if (album != null) const SizedBox(width: 10),
          tile(
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: c.fg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(PhosphorRegular.headphones, size: 26, color: c.bg),
            ),
            label: t.today,
            value: t.minutesCount(today),
          ),
        ],
      ),
    );
  }
}

/// The artist heard the most this week: a big picture (one of their
/// covers) fading into the page, and the time spent with them.
class _TopArtist extends ConsumerWidget {
  const _TopArtist({required this.home});

  final PhoneHome home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final (name, secs) = home.topArtist!;
    final group = home.topArtistGroup;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Pressable(
        onTap: group == null
            ? null
            : () => openGroup(context, ref, (
                kind: GroupKind.artist,
                name: group.name,
              )),
        semanticLabel: '${t.artistOfWeek}: $name',
        pressScale: 0.98,
        borderRadius: BorderRadius.circular(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: SizedBox(
            height: 300,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                fit: StackFit.expand,
                children: [
                  CoverArt(
                    size: box.maxWidth,
                    aspectRatio: box.maxWidth / 300,
                    radius: 0,
                    seed: name.hashCode,
                    imagePath: group?.thumbnail,
                    shadow: false,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.bg.withValues(alpha: 0), c.bg],
                        stops: const [0.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.artistOfWeek, style: _Type.cardSub(c.fgSoft)),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _Type.page(context).copyWith(fontSize: 38),
                        ),
                        Text(
                          t.minutesCount(secs ~/ 60),
                          style: _Type.cardSub(c.fgSoft).copyWith(fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « 7 derniers jours »: total, and one bar per day that grows in.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.home});

  final PhoneHome home;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final total = home.weekSeconds;
    final max = home.week.fold<int>(1, (a, d) => math.max(a, d.$2));
    final day = DateFormat.E(intlLocaleOf(context));
    final reduced = MmMotion.of(context).reduced;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // Opens the monthly recap (decision 0013, proposal 10).
      child: Pressable(
        onTap: () => context.push(Routes.recap),
        semanticLabel: t.recapOpen,
        pressScale: 0.98,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: _tile(c),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.last7Days, style: _Type.cardSub(c.fgSoft)),
                  ),
                  Text(t.recapOpen, style: _Type.cardSub(c.fg)),
                  Icon(PhosphorRegular.caretRight, size: 16, color: c.fg),
                ],
              ),
              Text(
                total == 0 ? '0 min' : durationWords(total.toDouble()),
                style: _Type.page(context).copyWith(fontSize: 34),
              ),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(t.noListenYet, style: _Type.cardSub(c.muted)),
                ),
              const SizedBox(height: 18),
              SizedBox(
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, (d, secs)) in home.week.indexed)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: reduced ? 1 : 0, end: 1),
                              duration: Duration(milliseconds: 700 + 60 * i),
                              curve: MmMotion.spring,
                              builder: (context, v, _) {
                                final h = secs == 0
                                    ? 6.0
                                    : math.max(12.0, 130 * secs / max * v);
                                final today = i == home.week.length - 1;
                                return Container(
                                  width: 34,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: secs == 0
                                        ? c.fg.withValues(alpha: 0.18)
                                        : (today
                                              ? c.fg
                                              : c.fg.withValues(alpha: 0.38)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              day.format(d).replaceAll('.', ''),
                              style: MmType.label.copyWith(
                                fontSize: 14,
                                color: i == home.week.length - 1
                                    ? c.fg
                                    : c.fgSoft,
                              ),
                            ),
                          ],
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
  }
}

/// The three latest plays, with how long ago.
class _HistoryPeek extends ConsumerWidget {
  const _HistoryPeek({required this.home});

  final PhoneHome home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    String ago(DateTime at) {
      final d = DateTime.now().difference(at);
      if (d.inMinutes < 1) return t.agoNow;
      if (d.inHours < 1) return t.agoMinutes(d.inMinutes);
      if (d.inDays < 1) return t.agoHours(d.inHours);
      return t.agoDays(d.inDays);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (final (item, at) in home.history)
            Pressable(
              onTap: () => _play(ref, t, [item]),
              semanticLabel: item.title,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    CoverArt(
                      size: 56,
                      radius: 14,
                      seed: item.id,
                      imagePath: item.thumbnail,
                      shadow: false,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _Type.cardTitle(c.fg),
                          ),
                          Text(
                            item.artist ?? t.unknownArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _Type.cardSub(c.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      ago(at),
                      style: MmType.caption.copyWith(
                        fontSize: 13,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shuffles the whole library; a wide pill at the top of the page that
/// folds into a square once the page scrolls.
class _ShuffleFab extends ConsumerWidget {
  const _ShuffleFab({required this.folded});

  final bool folded;

  Future<void> _shuffleAll(WidgetRef ref, L10n t) async {
    final page = await ref
        .read(libraryApiProvider)
        .tracks(search: '', favoritesOnly: false, offset: 0, limit: 1500);
    final items = page.items.where((i) => !i.missing && !i.isVideo).toList();
    if (items.isEmpty) return;
    await _play(
      ref,
      t,
      seededShuffle(items, DateTime.now().microsecondsSinceEpoch),
      shuffle: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final dark = c.brightness == Brightness.dark;
    final bg = dark ? c.fg : const Color(0xFF2B2D31);
    final fg = dark ? c.bg : Colors.white;
    final motion = MmMotion.of(context);
    return Pressable(
      onTap: () {
        HapticFeedback.mediumImpact();
        unawaited(_shuffleAll(ref, t));
      },
      semanticLabel: t.shuffleAll,
      tooltip: t.shuffleAll,
      pressScale: 0.92,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: motion.reduced
            ? Duration.zero
            : const Duration(milliseconds: 320),
        // No overshoot here: the padding and width cannot go below zero.
        curve: MmMotion.standard,
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: folded ? 0 : 22),
        constraints: BoxConstraints(minWidth: 64, maxWidth: folded ? 64 : 260),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorRegular.shuffle, size: 24, color: fg),
            Flexible(
              child: AnimatedSize(
                duration: motion.reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: MmMotion.standard,
                child: folded
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          t.shuffleAll,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: MmType.labelStrong.copyWith(
                            fontSize: 16,
                            color: fg,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
