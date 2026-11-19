import 'package:material_ui/material_ui.dart';

import '../mm_icons.g.dart';
import '../tokens.dart';
import 'pressable.dart';

/// Coral play/pause disc with its halo. The glyph morphs (scale + fade,
/// 160 ms) instead of swapping, so the state change reads as one motion.
class PlayPauseButton extends StatefulWidget {
  const PlayPauseButton({
    super.key,
    required this.playing,
    required this.onPressed,
    required this.playLabel,
    required this.pauseLabel,
    this.size = 44,
    this.glyphSize = 24,
    this.halo = true,
  });

  final bool playing;
  final VoidCallback? onPressed;
  final String playLabel;
  final String pauseLabel;
  final double size;
  final double glyphSize;
  final bool halo;

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final motion = MmMotion.of(context);
    final enabled = widget.onPressed != null;
    final glyph = widget.playing ? PhosphorFill.pause : PhosphorFill.play;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: widget.onPressed,
        semanticLabel: widget.playing ? widget.pauseLabel : widget.playLabel,
        tooltip: widget.playing ? widget.pauseLabel : widget.playLabel,
        pressScale: 0.94,
        child: AnimatedContainer(
          duration: motion.hover,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: !enabled
                ? c.coral.withValues(alpha: 0.4)
                : (_hover ? c.coralHover : c.coral),
            boxShadow: widget.halo && enabled ? MmShadows.playHalo : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: motion.reduced
                ? motion.state
                : const Duration(milliseconds: 160),
            switchInCurve: MmMotion.standard,
            switchOutCurve: MmMotion.exit,
            transitionBuilder: (child, anim) => motion.reduced
                ? FadeTransition(opacity: anim, child: child)
                : FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.6, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
            child: Icon(
              glyph,
              key: ValueKey(glyph),
              size: widget.glyphSize,
              color: c.coralInk,
            ),
          ),
        ),
      ),
    );
  }
}
