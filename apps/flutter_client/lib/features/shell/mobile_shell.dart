import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/play_button.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../now_playing/now_playing_shared.dart';
import '../playback/playback.dart';

/// Android shell (decision 0006 extended, D2): tabs Musique · Cinéma · Focus
/// (coral) and Obtenir (teal), the 64 dp mini player above them whenever
/// something is loaded.
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final hasMedia = ref.watch(queueProvider.select((q) => q.current != null));
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navHeight = 72 + bottomInset;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            bottom: navHeight + (hasMedia ? 72 : 0),
            child: SafeArea(bottom: false, child: child),
          ),
          AnimatedPositioned(
            duration: MmMotion.of(context).sheetSettle,
            curve: MmMotion.standard,
            left: 8,
            right: 8,
            bottom: hasMedia ? navHeight + 8 : navHeight - 72,
            height: 64,
            child: AnimatedOpacity(
              duration: MmMotion.of(context).screen,
              opacity: hasMedia ? 1 : 0,
              child: const _MiniPlayer(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: navHeight,
            child: _TabBar(location: location, bottomInset: bottomInset),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.location, required this.bottomInset});

  final String location;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final tabs = [
      (
        t.tabMusic,
        PhosphorRegular.musicNotes,
        PhosphorFill.musicNotes,
        '/listen/music',
        Routes.listenHome,
        c.coralStrong,
        c.coralSubtle,
      ),
      (
        t.tabCinema,
        PhosphorRegular.filmSlate,
        PhosphorFill.filmSlate,
        Routes.cinema,
        Routes.cinema,
        c.coralStrong,
        c.coralSubtle,
      ),
      (
        t.tabFocus,
        PhosphorRegular.headphones,
        PhosphorFill.headphones,
        Routes.focus,
        Routes.focus,
        c.coralStrong,
        c.coralSubtle,
      ),
      (
        t.tabGet,
        PhosphorRegular.downloadSimple,
        PhosphorFill.downloadSimple,
        Routes.get,
        Routes.get,
        c.chipText,
        c.accentSubtle,
      ),
    ];
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset + 6),
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          for (final (label, icon, filled, prefix, route, fg, pill) in tabs)
            Expanded(
              child: Builder(
                builder: (context) {
                  // The Music tab also owns the Listen home (A-00).
                  final on =
                      location.startsWith(prefix) ||
                      (prefix == '/listen/music' &&
                          location == Routes.listenHome);
                  return Pressable(
                    onTap: on ? null : () => context.go(route),
                    semanticLabel: label,
                    selected: on,
                    borderRadius: BorderRadius.circular(MmRadius.lg),
                    child: SizedBox(
                      height: 66,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: MmMotion.of(context).state,
                            curve: MmMotion.standard,
                            width: 56,
                            height: 30,
                            decoration: BoxDecoration(
                              color: on ? pill : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                MmRadius.pill,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: MmIcon(
                              icon,
                              filled: filled,
                              active: on,
                              size: 22,
                              color: on ? fg : c.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            style: MmType.captionStrong.copyWith(
                              fontSize: 11.5,
                              color: on ? fg : c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 64 dp mini player: cover, title, play; 3 dp progress along the bottom.
class _MiniPlayer extends ConsumerStatefulWidget {
  const _MiniPlayer();

  @override
  ConsumerState<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<_MiniPlayer> {
  final _cover = GlobalKey();

  void _open() {
    ref.read(coverOriginProvider.notifier).capture(_cover);
    context.push(Routes.player);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final entry = ref.watch(queueProvider.select((q) => q.current));
    final snap = currentSnapshot(ref);
    final card = Container(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        border: Border.all(color: c.lineStrong),
        boxShadow: MmShadows.floating,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
            child: Row(
              children: [
                CoverArt(
                  key: _cover,
                  size: 48,
                  radius: MmRadius.md,
                  seed: entry?.seed ?? 0,
                  imagePath: entry?.artwork,
                  shadow: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.heading.copyWith(color: c.fg),
                      ),
                      if (entry?.subtitle != null)
                        Text(
                          entry!.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MmType.caption.copyWith(color: c.muted),
                        ),
                    ],
                  ),
                ),
                PlayPauseButton(
                  playing: snap.isPlaying,
                  onPressed: entry == null
                      ? null
                      : ref.read(queueProvider.notifier).togglePlay,
                  playLabel: t.play,
                  pauseLabel: t.pause,
                  halo: false,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            height: 3,
            child: InterpolatedPosition(
              position: snap.position,
              duration: snap.duration,
              playing: snap.isPlaying && !snap.buffering,
              speed: snap.speed,
              builder: (context, position) {
                final total = snap.duration.inMilliseconds;
                final ratio = total > 0
                    ? (position.inMilliseconds / total).clamp(0.0, 1.0)
                    : 0.0;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.line,
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.coral,
                        borderRadius: BorderRadius.circular(MmRadius.pill),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (entry == null) return card;
    // Tap or swipe up opens the full player (A-03).
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -300) _open();
      },
      child: Pressable(
        onTap: _open,
        semanticLabel: t.openNowPlaying,
        pressScale: 0.98,
        borderRadius: BorderRadius.circular(MmRadius.sheet),
        child: card,
      ),
    );
  }
}
