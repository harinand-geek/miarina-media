import 'package:material_ui/material_ui.dart';

/// The Miarina 4d mark (design/brand): dark tile, coral play triangle, three
/// teal flow bars. Drawn from the mockup SVG (32-unit grid).
class MiarinaLogo extends StatelessWidget {
  const MiarinaLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.5, 0.5, 31, 31),
        const Radius.circular(7.5),
      ),
      Paint()..color = const Color(0xFF101820),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.5, 0.5, 31, 31),
        const Radius.circular(7.5),
      ),
      Paint()
        ..color = const Color(0xFF3A4D5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      Path()
        ..moveTo(13, 9.5)
        ..lineTo(13, 22.5)
        ..lineTo(23, 16)
        ..close(),
      Paint()..color = const Color(0xFFFF7A45),
    );
    final teal = Paint()..color = const Color(0xFF35C9BD);
    for (final r in const [
      Rect.fromLTWH(6, 10.5, 4, 2.5),
      Rect.fromLTWH(4, 14.75, 6, 2.5),
      Rect.fromLTWH(6, 19, 4, 2.5),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1.25)),
        teal,
      );
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => false;
}
