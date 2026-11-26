import 'package:material_ui/material_ui.dart';

import '../brand_marks.dart';
import '../svg_path.dart';

/// A site's brand mark as an app-icon-like disc: the brand's colour, its
/// mark in white (readable on dark and light grounds, whatever the brand
/// colour).
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.mark, this.size = 48});

  final BrandMark mark;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _BrandPainter(mark)),
  );
}

class _BrandPainter extends CustomPainter {
  _BrandPainter(this.mark);

  final BrandMark mark;

  /// Parsed once per mark.
  static final _paths = <String, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, r, Paint()..color = mark.color);
    // A near-black brand would melt into a dark ground: a faint ring.
    if (mark.color.computeLuminance() < 0.05) {
      canvas.drawCircle(
        center,
        r - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x33FFFFFF),
      );
    }
    final glyph = _paths.putIfAbsent(mark.path, () => parseSvgPath(mark.path));
    // The 24-unit mark fills about half of the disc.
    final side = r * 1.05;
    final scale = side / 24;
    canvas
      ..save()
      ..translate(center.dx - side / 2, center.dy - side / 2)
      ..scale(scale)
      ..drawPath(glyph, Paint()..color = const Color(0xFFFFFFFF))
      ..restore();
  }

  @override
  bool shouldRepaint(_BrandPainter old) => old.mark != mark;
}
