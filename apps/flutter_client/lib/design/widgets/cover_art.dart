import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'logo.dart';

/// Cover, poster or thumbnail from the user's own files ([imagePath]),
/// decoded at the displayed size. Without a picture, or when it cannot be
/// read, it shows the Miarina Media mark at low opacity on a tone picked
/// from [seed] (owner's choice, 2026-11-21, instead of the mockups'
/// hatching); never a stock image.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    this.size = 52,
    this.radius = MmRadius.md,
    this.seed = 0,
    this.shadow = true,
    this.child,
    this.aspectRatio = 1,
    this.imagePath,
  });

  final double size;
  final double radius;
  final int seed;
  final bool shadow;
  final Widget? child;
  final double aspectRatio;
  final String? imagePath;

  // Placeholder tones, from the prototypes' hatching pairs (warm, green,
  // plum, olive, teal, slate…); the first of each pair is used.
  static const _pairs = [
    (Color(0xFF4A3424), Color(0xFF422E20)),
    (Color(0xFF2E3B2A), Color(0xFF283423)),
    (Color(0xFF3B2A3B), Color(0xFF332433)),
    (Color(0xFF3B3A24), Color(0xFF33321F)),
    (Color(0xFF1F3A3C), Color(0xFF1A3335)),
    (Color(0xFF22333F), Color(0xFF1C2C37)),
    (Color(0xFF2A3B52), Color(0xFF243348)),
    (Color(0xFF4A3F1F), Color(0xFF41371B)),
  ];

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final pair = c.brightness == Brightness.dark
        ? _pairs[seed.abs() % _pairs.length]
        : (c.hatchA, c.hatchB);
    final height = size / aspectRatio;
    final placeholder = ColoredBox(
      color: pair.$1,
      child: SizedBox(
        width: size,
        height: height,
        child: Center(
          child: Opacity(
            opacity: c.brightness == Brightness.dark ? 0.32 : 0.4,
            child: MiarinaLogo(size: math.min(size, height) * 0.42),
          ),
        ),
      ),
    );
    final path = imagePath;
    Widget picture = placeholder;
    if (path != null && path.isNotEmpty) {
      final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
      picture = Image.file(
        File(path),
        width: size,
        height: size / aspectRatio,
        fit: BoxFit.cover,
        cacheWidth: px,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, img, frame, sync) => sync || frame != null
            ? img
            : Stack(fit: StackFit.expand, children: [placeholder, img]),
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return Container(
      width: size,
      height: size / aspectRatio,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? MmShadows.cover : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child == null
            ? picture
            : Stack(
                fit: StackFit.expand,
                children: [
                  picture,
                  // Keeps the overlay icon readable over a real picture.
                  if (picture != placeholder)
                    const ColoredBox(color: Color(0x990D141B)),
                  Center(child: child),
                ],
              ),
      ),
    );
  }
}
