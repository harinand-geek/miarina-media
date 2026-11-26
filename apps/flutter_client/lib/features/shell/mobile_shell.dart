import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/cover_tones.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/expressive.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../design/widgets/wavy_slider.dart';
import '../../l10n/app_localizations.dart';
import '../device_media/device_media_view.dart';
import '../health/health_screens.dart' show MissingSkipListener;
import '../now_playing/now_playing_shared.dart';
import '../online/online_playback.dart' show onlineResolvingProvider;
import '../playback/playback.dart';
import '../playback/audio_only.dart';

/// Android shell (decision 0006 extended, D2): tabs Musique · Cinéma · Focus
/// (coral) and Obtenir (teal), the 64 dp mini player above them whenever
/// something is loaded. The browser has the screen to itself (its own bars,
/// design_handoff_android_v2 screen 02).
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
    if (location.startsWith(Routes.getBrowser)) {
      return MissingSkipListener(
        child: Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(bottom: false, child: child),
        ),
      );
    }
    return MissingSkipListener(
      child: _scaffold(context, c, hasMedia, navHeight, bottomInset),
    );
  }

  Widget _scaffold(
    BuildContext context,
    MmColors c,
    bool hasMedia,
    double navHeight,
    double bottomInset,
  ) {
    final motion = MmMotion.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            bottom: navHeight + (hasMedia ? _miniHeight : 0),
            child: SafeArea(
              bottom: false,
              // Musique without the phone's media: A-06 / A-07.
              child: DeviceMediaGate(
                active:
                    location.startsWith('/listen/music') ||
                    location == Routes.listenHome,
                child: child,
              ),
            ),
          ),
          // The mini player and the tabs make one dock; the player slides
          // out of it when something is loaded.
          AnimatedPositioned(
            duration: motion.sheetSettle,
            curve: MmMotion.spring,
            left: 0,
            right: 0,
            bottom: hasMedia ? navHeight - 1 : navHeight - _miniHeight,
            height: _miniHeight + 1,
            child: AnimatedOpacity(
              duration: motion.screen,
              opacity: hasMedia ? 1 : 0,
              child: const _MiniPlayer(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: navHeight,
            child: _TabBar(
              location: location,
              bottomInset: bottomInset,
              attached: hasMedia,
            ),
          ),
        ],
      ),
    );
  }
}

/// Height of the mini player in the dock.
const _miniHeight = 80.0;

/// Background of the dock (mini player + tabs).
Color dockColor(MmColors c) => c.brightness == Brightness.dark
    ? c.sidebar
    : Color.lerp(c.bg, c.fg, 0.045)!;

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.location,
    required this.bottomInset,
    required this.attached,
  });

  final String location;
  final double bottomInset;

  /// Under the mini player: square top, no line between them.
  final bool attached;

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
    return AnimatedContainer(
      duration: MmMotion.of(context).sheetSettle,
      curve: MmMotion.standard,
      padding: EdgeInsets.only(bottom: bottomInset + 6),
      decoration: BoxDecoration(
        color: dockColor(c),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(attached ? 0 : 28),
        ),
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
                  // The tab already shown goes back to its first page
                  // (Music: from a library page to the home).
                  return Pressable(
                    onTap: on && location == route
                        ? null
                        : () => context.go(route),
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

//// Mini player of the dock (expressive redesign, 2026-11-25): a waving
/// progress line along the top, the cover, title and artist, play in a
/// rounded pill tinted by the cover, next. Tap or swipe up opens the player;
/// swipe sideways for the next or previous title.
class _MiniPlayer extends ConsumerStatefulWidget {
  const _MiniPlayer();

  @override
  ConsumerState<_MiniPlayer> createState() => _MiniPlayerState();
}

/// The phone mini player's cover: the player's cover flies to it when the
/// player is dragged down (one mini player on a phone).
final miniCoverKey = GlobalKey(debugLabel: 'mini cover');

/// Its title and artist, where the player's fly to.
final miniTitleKey = GlobalKey(debugLabel: 'mini title');

/// The mini player's card: the player's ground shrinks into it.
final miniBarKey = GlobalKey(debugLabel: 'mini bar');

/// True while the player's cover and title fly to the mini player: its own
/// hide until the copies land on them.
final miniHidden = ValueNotifier(false);

TextStyle miniTitleStyle(MmColors c) => MmType.title.copyWith(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  fontVariations: const [FontVariation.weight(600)],
  color: c.fg,
);

TextStyle miniArtistStyle(MmColors c) =>
    MmType.body.copyWith(fontSize: 14, color: c.muted);

class _MiniPlayerState extends ConsumerState<_MiniPlayer> {
  final _cover = miniCoverKey;
  double _swipe = 0;

  void _open() {
    final current = ref.read(queueProvider).current;
    if (current != null && opensVideoPage(ref, current)) {
      context.push(Routes.watch);
      return;
    }
    if (current?.focusKey != null) {
      context.push(Routes.focusPlayer);
      return;
    }
    ref.read(coverOriginProvider.notifier).capture(_cover);
    context.push(Routes.player);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final q = ref.watch(queueProvider);
    final entry = q.current;
    final queue = ref.read(queueProvider.notifier);
    final snap = currentSnapshot(ref);
    final tones = watchCoverTones(ref, context, entry?.artwork);
    final playing = snap.isPlaying && !snap.buffering;
    final motion = MmMotion.of(context);
    final glyph = snap.isPlaying ? PhosphorFill.pause : PhosphorFill.play;
    // An online entry's stream is being found (decision 0011).
    final resolving = ref.watch(onlineResolvingProvider);

    final card = AnimatedCoverTones(
      tones: tones,
      builder: (context, tones, _) => Container(
        key: miniBarKey,
        decoration: BoxDecoration(
          color: dockColor(c),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: InterpolatedPosition(
                position: snap.position,
                duration: snap.duration,
                playing: playing,
                speed: snap.speed,
                builder: (context, position) {
                  final total = snap.duration.inMilliseconds;
                  return WavyProgress(
                    value: total > 0
                        ? (position.inMilliseconds / total).clamp(0.0, 1.0)
                        : 0.0,
                    playing: playing,
                    color: c.brightness == Brightness.dark
                        ? tones.primary
                        : tones.onCard,
                    trackColor: c.fg.withValues(alpha: 0.12),
                    stroke: 3.5,
                    height: 14,
                  );
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 6),
                child: Row(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: miniHidden,
                      builder: (context, hidden, child) =>
                          Opacity(opacity: hidden ? 0 : 1, child: child),
                      child: AnimatedSwitcher(
                        duration: motion.album,
                        child: CoverArt(
                          key: _cover,
                          size: 52,
                          radius: 14,
                          seed: entry?.seed ?? 0,
                          imagePath: entry?.artwork,
                          shadow: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: miniHidden,
                        builder: (context, hidden, child) =>
                            Opacity(opacity: hidden ? 0 : 1, child: child),
                        child: AnimatedSwitcher(
                          key: miniTitleKey,
                          duration: motion.screen,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, ?current],
                          ),
                          child: Column(
                            key: ValueKey(entry?.title),
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry?.title ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: miniTitleStyle(c),
                              ),
                              if (entry?.subtitle != null)
                                Text(
                                  entry!.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: miniArtistStyle(c),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MorphButton(
                      onTap: entry == null ? null : queue.togglePlay,
                      color: tones.card,
                      semanticLabel: snap.isPlaying ? t.pause : t.play,
                      tooltip: snap.isPlaying ? t.pause : t.play,
                      width: 58,
                      height: 50,
                      radius: 18,
                      pressedRadius: 25,
                      child: AnimatedSwitcher(
                        duration: motion.state,
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: Tween(begin: 0.6, end: 1.0).animate(anim),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: resolving
                            ? SizedBox(
                                key: const ValueKey('resolving'),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: tones.onCard,
                                ),
                              )
                            : Icon(
                                glyph,
                                key: ValueKey(glyph),
                                size: 24,
                                color: tones.onCard,
                              ),
                      ),
                    ),
                    Pressable(
                      onTap: q.hasNext ? queue.next : null,
                      semanticLabel: t.next,
                      tooltip: t.next,
                      pressScale: 0.85,
                      child: SizedBox(
                        width: 46,
                        height: 50,
                        child: Icon(
                          PhosphorFill.skipForward,
                          size: 24,
                          color: q.hasNext ? c.fg : c.faintIcon,
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
    );
    if (entry == null) return card;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -300) _open();
      },
      onHorizontalDragUpdate: (d) => setState(() => _swipe += d.delta.dx),
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_swipe < -80 || v < -700) {
          HapticFeedback.selectionClick();
          if (q.hasNext) queue.next();
        } else if (_swipe > 80 || v > 700) {
          HapticFeedback.selectionClick();
          queue.previous();
        }
        setState(() => _swipe = 0);
      },
      child: Pressable(
        onTap: _open,
        semanticLabel: t.openNowPlaying,
        pressScale: 0.99,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: AnimatedSlide(
          offset: Offset(_swipe / 1200, 0),
          duration: _swipe == 0 ? motion.album : Duration.zero,
          curve: MmMotion.spring,
          child: card,
        ),
      ),
    );
  }
}
