import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';

/// Thin progress line at the bottom of a picture (coral on a light veil).
class PictureProgress extends StatelessWidget {
  const PictureProgress({super.key, required this.value, this.height = 4});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0x33F5F7FA)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: ColoredBox(color: c.coral),
          ),
        ],
      ),
    );
  }
}

/// Small dark pill over a picture (time left, duration, "new episode").
class PicturePill extends StatelessWidget {
  const PicturePill(this.text, {super.key, this.mono = true});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCC0D141B),
        borderRadius: BorderRadius.circular(MmRadius.pill),
      ),
      child: Text(
        text,
        style: mono
            ? MmType.monoStyle(size: 11, color: c.fg)
            : MmType.captionStrong.copyWith(fontSize: 11, color: c.fg),
      ),
    );
  }
}

/// Coral round play button drawn on pictures.
class PictureplayButton extends StatelessWidget {
  const PictureplayButton({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.coral,
        shape: BoxShape.circle,
        boxShadow: MmShadows.menu,
      ),
      child: Icon(PhosphorFill.play, size: size * 0.5, color: c.coralInk),
    );
  }
}

/// A 16:9 or 2:3 video tile: picture, title and one line under it. Hover
/// (or focus) lifts it a little, like the album cards.
class VideoTile extends StatefulWidget {
  const VideoTile({
    super.key,
    required this.width,
    required this.aspectRatio,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.imagePath,
    this.seed = 0,
    this.progress,
    this.topRight,
    this.topLeft,
    this.playButton = false,
    this.radius = MmRadius.md,
    this.semanticLabel,
    this.dimmed = false,
  });

  final double width;
  final double aspectRatio;
  final String title;
  final String? subtitle;
  final String? imagePath;
  final int seed;
  final double? progress;
  final Widget? topRight;
  final Widget? topLeft;
  final bool playButton;
  final double radius;
  final VoidCallback onTap;
  final String? semanticLabel;

  /// Missing file: shown at .72 opacity, like the track rows.
  final bool dimmed;

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final motion = MmMotion.of(context);
    final w = widget;
    final picture = Stack(
      children: [
        CoverArt(
          size: w.width,
          aspectRatio: w.aspectRatio,
          radius: w.radius,
          seed: w.seed,
          imagePath: w.imagePath,
        ),
        if (w.progress != null && w.progress! > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(w.radius),
              ),
              child: PictureProgress(value: w.progress!),
            ),
          ),
        if (w.playButton)
          const Positioned(left: 12, bottom: 14, child: PictureplayButton()),
        if (w.topRight != null)
          Positioned(right: 10, top: 10, child: w.topRight!),
        if (w.topLeft != null) Positioned(left: 8, top: 8, child: w.topLeft!),
      ],
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: w.onTap,
        semanticLabel: w.semanticLabel ?? w.title,
        pressScale: 0.98,
        borderRadius: BorderRadius.circular(w.radius),
        child: Opacity(
          opacity: w.dimmed ? 0.72 : 1,
          child: AnimatedContainer(
            duration: motion.hover,
            curve: MmMotion.standard,
            transform: Matrix4.translationValues(
              0,
              _hover && !motion.reduced ? -3 : 0,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                picture,
                const SizedBox(height: 8),
                Text(
                  w.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.heading.copyWith(
                    fontSize: w.aspectRatio < 1 ? 13 : 14,
                    color: c.fg,
                  ),
                ),
                if (w.subtitle != null)
                  Text(
                    w.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.caption.copyWith(
                      fontSize: w.aspectRatio < 1 ? 12 : 12.5,
                      color: c.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill segment of W-C1 (Tout / Films / Séries).
class PillSegment<T> extends StatelessWidget {
  const PillSegment({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> values;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final motion = MmMotion.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MmRadius.pill),
        border: Border.all(color: c.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in values)
            Pressable(
              onTap: value == selected ? null : () => onChanged(value),
              selected: value == selected,
              semanticLabel: label,
              child: AnimatedContainer(
                duration: motion.state,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: value == selected ? c.surface2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: MmType.labelStrong.copyWith(
                      fontSize: 13,
                      color: value == selected ? c.fg : c.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chips of the Android tabs (A-C): one choice among a few.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> values;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final (value, label) in values) ...[
            Pressable(
              onTap: value == selected ? null : () => onChanged(value),
              selected: value == selected,
              semanticLabel: label,
              child: AnimatedContainer(
                duration: MmMotion.of(context).state,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: value == selected ? c.coralSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                  border: Border.all(
                    color: value == selected ? c.coralChipBorder : c.lineStrong,
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: MmType.labelStrong.copyWith(
                      fontSize: 13,
                      color: value == selected ? c.coralStrong : c.fgSoft,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Outlined pill that opens a short menu ("Titre ⌄").
class PillMenu<T> extends StatelessWidget {
  const PillMenu({
    super.key,
    required this.icon,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.tooltip,
  });

  final IconData icon;
  final List<(T, String)> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final label = values.firstWhere((v) => v.$1 == selected).$2;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface2),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MmRadius.lg),
            side: BorderSide(color: c.overlayBorder),
          ),
        ),
      ),
      menuChildren: [
        for (final (value, text) in values)
          MenuItemButton(
            onPressed: () => onChanged(value),
            leadingIcon: SizedBox(
              width: 18,
              child: value == selected
                  ? Icon(PhosphorRegular.check, size: 16, color: c.accent)
                  : null,
            ),
            child: Text(text, style: MmType.label.copyWith(color: c.fg)),
          ),
      ],
      builder: (context, menu, _) => Pressable(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        tooltip: tooltip,
        semanticLabel: '$tooltip : $label',
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c.fgSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: MmType.labelStrong.copyWith(
                  fontSize: 13,
                  color: c.fgSoft,
                ),
              ),
              const SizedBox(width: 4),
              Icon(PhosphorRegular.caretDown, size: 16, color: c.fgSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section title of the Cinema screens (17/800) with an optional action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: MmType.title.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: c.fg,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
