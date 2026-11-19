import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/mm_icon.dart';
import '../../design/widgets/play_button.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart';
import '../../engine/media_engine.dart';
import '../../l10n/app_localizations.dart';
import '../playback/playback.dart';
import 'lyrics_view.dart';
import 'now_playing_shared.dart';
import 'queue_view.dart';
import 'sound_view.dart';

/// A-03 Lecteur audio (Android): drag down or system back to collapse into
/// the mini player; swipe the cover for the next / previous track; the
/// lyrics button swaps the cover for the synchronised lyrics.
class MobilePlayer extends ConsumerStatefulWidget {
  const MobilePlayer({super.key});

  @override
  ConsumerState<MobilePlayer> createState() => _MobilePlayerState();
}

class _MobilePlayerState extends ConsumerState<MobilePlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );
  bool _lyrics = false;
  double _swipe = 0;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) context.pop();
  }

  void _onDragEnd(DragEndDetails d, double height) {
    final v = d.primaryVelocity ?? 0;
    // Handoff §03: past 30 % of the height or faster than 800 dp/s.
    if (_drag.value > height * 0.3 || v > 800) {
      _close();
      return;
    }
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 500,
      ratio: 0.9,
    );
    _drag.animateWith(SpringSimulation(spring, _drag.value, 0, v));
  }

  Future<void> _sheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MmColors.of(context).bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(MmRadius.xxl)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: MmColors.of(context).faintIcon,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final q = ref.watch(queueProvider);
    final queue = ref.read(queueProvider.notifier);
    final entry = q.current;
    final snap = currentSnapshot(ref);
    final size = MediaQuery.sizeOf(context);
    final motion = MmMotion.of(context);

    final body = SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                _RoundIcon(
                  icon: PhosphorRegular.caretDown,
                  label: t.closePlayer,
                  onTap: _close,
                ),
                Expanded(
                  child: Text(
                    entry?.album ?? t.nowPlaying,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.heading.copyWith(color: c.fg),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder: (context, box) {
                  final cover = box.maxWidth
                      .clamp(0.0, box.maxHeight - 250)
                      .toDouble();
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      SizedBox(
                        height: cover,
                        child: AnimatedSwitcher(
                          duration: motion.screen,
                          child: _lyrics
                              ? LyricsView(
                                  key: const ValueKey('lyrics'),
                                  fontSize: 22,
                                  padding: EdgeInsets.zero,
                                )
                              : GestureDetector(
                                  key: const ValueKey('cover'),
                                  onHorizontalDragUpdate: (d) =>
                                      setState(() => _swipe += d.delta.dx),
                                  onHorizontalDragEnd: (d) {
                                    final v = d.primaryVelocity ?? 0;
                                    if (_swipe < -cover * 0.25 || v < -600) {
                                      HapticFeedback.selectionClick();
                                      queue.next();
                                    } else if (_swipe > cover * 0.25 ||
                                        v > 600) {
                                      HapticFeedback.selectionClick();
                                      queue.previous();
                                    }
                                    setState(() => _swipe = 0);
                                  },
                                  child: AnimatedSlide(
                                    offset: Offset(
                                      _swipe / (cover == 0 ? 1 : cover),
                                      0,
                                    ),
                                    duration: _swipe == 0
                                        ? motion.album
                                        : Duration.zero,
                                    curve: MmMotion.standard,
                                    child: FlyingCover(
                                      size: cover,
                                      seed: entry?.seed ?? 0,
                                      radius: MmRadius.xl,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry?.title ?? t.nothingPlaying,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MmType.titleLg.copyWith(
                                    fontSize: 22,
                                    color: c.fg,
                                  ),
                                ),
                                if (entry?.subtitle != null)
                                  Text(
                                    entry!.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MmType.body.copyWith(
                                      fontSize: 15,
                                      color: c.fgSoft,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (entry?.libraryId != null)
                            Pressable(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                toggleCurrentFavorite(ref);
                              },
                              semanticLabel: entry!.favorite
                                  ? t.favoriteRemove
                                  : t.favoriteAdd,
                              pressScale: 0.85,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: c.fg.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: FavoriteHeart(on: entry.favorite),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      InterpolatedPosition(
                        position: snap.position,
                        duration: snap.duration,
                        playing: snap.isPlaying && !snap.buffering,
                        speed: snap.speed,
                        builder: (context, position) {
                          final total = snap.duration;
                          final ratio = total > Duration.zero
                              ? position.inMilliseconds / total.inMilliseconds
                              : 0.0;
                          return Column(
                            children: [
                              TrackBar(
                                value: ratio,
                                fillColor: c.fg,
                                height: 28,
                                semanticLabel: t.seek,
                                semanticValue:
                                    '${formatClock(position)} / ${formatClock(total)}',
                                onChanged: total > Duration.zero
                                    ? (_) {}
                                    : null,
                                onChangeEnd: total > Duration.zero
                                    ? (v) => ref
                                          .read(mediaEngineProvider)
                                          ?.seek(
                                            Duration(
                                              milliseconds:
                                                  (v * total.inMilliseconds)
                                                      .round(),
                                            ),
                                          )
                                    : null,
                              ),
                              Row(
                                children: [
                                  Text(
                                    formatClock(position),
                                    style: MmType.monoStyle(
                                      size: 12,
                                      color: c.fgSoft,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    total > Duration.zero
                                        ? '-${formatClock(total - position)}'
                                        : '',
                                    style: MmType.monoStyle(
                                      size: 12,
                                      color: c.fgSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _RoundIcon(
                            icon: PhosphorRegular.shuffle,
                            label: t.shuffle,
                            color: q.shuffle ? c.coralStrong : c.fg,
                            onTap: queue.toggleShuffle,
                          ),
                          _RoundIcon(
                            icon: PhosphorFill.skipBack,
                            size: 30,
                            label: t.previous,
                            onTap: entry == null ? null : queue.previous,
                          ),
                          PlayPauseButton(
                            playing: snap.isPlaying,
                            onPressed: entry == null ? null : queue.togglePlay,
                            playLabel: t.play,
                            pauseLabel: t.pause,
                            size: 76,
                            glyphSize: 34,
                          ),
                          _RoundIcon(
                            icon: PhosphorFill.skipForward,
                            size: 30,
                            label: t.next,
                            onTap: q.hasNext ? queue.next : null,
                          ),
                          _RoundIcon(
                            icon: q.repeat == RepeatSetting.one
                                ? PhosphorRegular.repeatOnce
                                : PhosphorRegular.repeat,
                            label: switch (q.repeat) {
                              RepeatSetting.off => t.repeatOff,
                              RepeatSetting.all => t.repeatAll,
                              RepeatSetting.one => t.repeatOne,
                            },
                            color: q.repeat == RepeatSetting.off
                                ? c.fg
                                : c.coralStrong,
                            onTap: queue.cycleRepeat,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _RoundIcon(
                            icon: PhosphorRegular.quotes,
                            label: _lyrics ? t.showCover : t.showLyrics,
                            color: _lyrics ? c.coralStrong : c.fg,
                            onTap: () => setState(() => _lyrics = !_lyrics),
                          ),
                          const Spacer(),
                          const SleepTimerChip(),
                          const SizedBox(width: 8),
                          InfoChip(
                            icon: PhosphorRegular.slidersHorizontal,
                            label: t.tabSound,
                            onTap: () => _sheet(
                              const SoundView(
                                padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                              ),
                            ),
                          ),
                          const Spacer(),
                          _RoundIcon(
                            icon: PhosphorRegular.queue,
                            label: t.queue,
                            onTap: () => _sheet(
                              const QueueView(
                                rowHeight: 60,
                                padding: EdgeInsets.fromLTRB(12, 12, 12, 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _drag,
      builder: (context, child) {
        final dy = _drag.value.clamp(0.0, size.height);
        final progress = (dy / size.height).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: 1 - progress * 0.06,
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(progress * 120),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: (d) =>
            _drag.value = (_drag.value + d.delta.dy).clamp(0.0, size.height),
        onVerticalDragEnd: (d) => _onDragEnd(d, size.height),
        child: Material(
          color: c.bg,
          child: Stack(
            children: [
              Positioned.fill(child: CoverBackdrop(seed: entry?.seed ?? 0)),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 24,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      tooltip: label,
      pressScale: 0.88,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: MmIcon(
            icon,
            size: size,
            color: onTap == null ? c.faintIcon : (color ?? c.fg),
          ),
        ),
      ),
    );
  }
}

/// Opening from the mini player: the sheet rises in 320 ms (fade 120 ms
/// when motion is reduced).
class PlayerPage extends CustomTransitionPage<void> {
  PlayerPage({super.key})
    : super(
        child: const MobilePlayer(),
        opaque: false,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: MmMotion.standard,
            reverseCurve: MmMotion.exit,
          );
          if (MmMotion.of(context).reduced) {
            return FadeTransition(opacity: curved, child: child);
          }
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
}
