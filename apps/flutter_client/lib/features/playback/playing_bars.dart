import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import 'playback.dart';

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

/// [PlayingBars] that follow the engine: bouncing while it plays, still
/// on pause. For the « now playing » marks of lists and panels.
class LivePlayingBars extends ConsumerWidget {
  const LivePlayingBars({super.key, required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlayingBars(
    color: color,
    size: size,
    playing: ref.watch(
      playbackProvider.select(
        (s) => (s.value?.isPlaying ?? false) && !(s.value?.buffering ?? false),
      ),
    ),
  );
}
