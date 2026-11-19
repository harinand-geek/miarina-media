import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// A Phosphor glyph pair: outline at rest, filled when [active]. The swap is
/// a 120 ms cross-fade, never a jump.
class MmIcon extends StatelessWidget {
  const MmIcon(
    this.regular, {
    super.key,
    this.filled,
    this.active = false,
    this.size = 20,
    this.color,
    this.semanticLabel,
  });

  final IconData regular;
  final IconData? filled;
  final bool active;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glyph = active && filled != null ? filled! : regular;
    final icon = Icon(
      glyph,
      key: ValueKey(glyph),
      size: size,
      color: color ?? IconTheme.of(context).color,
      semanticLabel: semanticLabel,
    );
    if (filled == null) return icon;
    return AnimatedSwitcher(
      duration: MmMotion.of(context).state,
      switchInCurve: MmMotion.standard,
      switchOutCurve: MmMotion.exit,
      child: icon,
    );
  }
}
