// Miarina design tokens, transcribed from apps/client/src/styles/theme.css
// (the shipped app) and design/design_handoff_lecture_ecouter (README,
// Design System §03–§05). Values are the source of truth there; change them
// there first.
import 'package:material_ui/material_ui.dart';

@immutable
class MmColors extends ThemeExtension<MmColors> {
  const MmColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.sidebar,
    required this.playerChrome,
    required this.line,
    required this.lineStrong,
    required this.divider,
    required this.cardHover,
    required this.selected,
    required this.overlayBorder,
    required this.fg,
    required this.fgSoft,
    required this.muted,
    required this.faint,
    required this.faintIcon,
    required this.accent,
    required this.accentStrong,
    required this.accentSubtle,
    required this.chipText,
    required this.chipBorder,
    required this.coral,
    required this.coralHover,
    required this.coralPress,
    required this.coralInk,
    required this.coralStrong,
    required this.coralSubtle,
    required this.coralChipBorder,
    required this.warning,
    required this.warningSubtle,
    required this.warningBorder,
    required this.warningInk,
    required this.danger,
    required this.video,
    required this.scrim,
    required this.hatchA,
    required this.hatchB,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color sidebar;
  final Color playerChrome;
  final Color line;
  final Color lineStrong;
  final Color divider;
  final Color cardHover;
  final Color selected;
  final Color overlayBorder;
  final Color fg;

  /// Secondary text on dark grounds in the mockups (#C7D0DB).
  final Color fgSoft;
  final Color muted;
  final Color faint;
  final Color faintIcon;

  /// Teal: get, selection, focus ring.
  final Color accent;
  final Color accentStrong;
  final Color accentSubtle;
  final Color chipText;
  final Color chipBorder;

  /// Coral: play.
  final Color coral;
  final Color coralHover;
  final Color coralPress;
  final Color coralInk;
  final Color coralStrong;
  final Color coralSubtle;
  final Color coralChipBorder;
  final Color warning;
  final Color warningSubtle;
  final Color warningBorder;
  final Color warningInk;
  final Color danger;
  final Color video;
  final Color scrim;

  /// Placeholder tones for covers that have no picture (hatchA is used).
  final Color hatchA;
  final Color hatchB;

  static const dark = MmColors(
    brightness: Brightness.dark,
    bg: Color(0xFF101820),
    surface: Color(0xFF182530),
    surface2: Color(0xFF1F2F3B),
    sidebar: Color(0xFF0D141B),
    playerChrome: Color(0xFF0B1117),
    line: Color(0xFF243545),
    lineStrong: Color(0xFF2A3D4E),
    divider: Color(0xFF1B2935),
    cardHover: Color(0xFF1B2A36),
    selected: Color(0xFF16302F),
    overlayBorder: Color(0xFF2F4558),
    fg: Color(0xFFF5F7FA),
    fgSoft: Color(0xFFC7D0DB),
    muted: Color(0xFF94A3B8),
    faint: Color(0xFF64748B),
    faintIcon: Color(0xFF3A4D5E),
    accent: Color(0xFF35C9BD),
    accentStrong: Color(0xFF35C9BD),
    accentSubtle: Color(0xFF1F3A3C),
    chipText: Color(0xFF5FE0D5),
    chipBorder: Color(0xFF2E6A68),
    coral: Color(0xFFFF7A45),
    coralHover: Color(0xFFFF9166),
    coralPress: Color(0xFFE8642E),
    coralInk: Color(0xFF1F0C03),
    coralStrong: Color(0xFFFF9166),
    coralSubtle: Color(0xFF3A2620),
    coralChipBorder: Color(0xFF7A4330),
    warning: Color(0xFFE8B04B),
    warningSubtle: Color(0xFF2B2616),
    warningBorder: Color(0xFF4A3F1F),
    warningInk: Color(0xFF1A1204),
    danger: Color(0xFFF07070),
    video: Color(0xFF070B0F),
    scrim: Color(0x9E05090D),
    hatchA: Color(0xFF22333F),
    hatchB: Color(0xFF1C2C37),
  );

  // Light values are the shipped [data-theme='light'] ones; those marked
  // "derived" in theme.css are still pending design review.
  static const light = MmColors(
    brightness: Brightness.light,
    bg: Color(0xFFF6F8FA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF2F5),
    sidebar: Color(0xFFEDF1F4),
    playerChrome: Color(0xFFEDF1F4),
    line: Color(0xFFDDE3E9),
    lineStrong: Color(0xFFC9D2DB),
    divider: Color(0xFFE3E8ED),
    cardHover: Color(0xFFF3F6F8),
    selected: Color(0xFFE8F8F6),
    overlayBorder: Color(0xFFC9D2DB),
    fg: Color(0xFF101820),
    fgSoft: Color(0xFF3A4757),
    muted: Color(0xFF526072),
    faint: Color(0xFF707D8C),
    faintIcon: Color(0xFFB5C0CB),
    accent: Color(0xFF35C9BD),
    accentStrong: Color(0xFF0F8579),
    accentSubtle: Color(0xFFDDF5F2),
    chipText: Color(0xFF0F8579),
    chipBorder: Color(0xFF9ADCD5),
    coral: Color(0xFFFF7A45),
    coralHover: Color(0xFFFF9166),
    coralPress: Color(0xFFE8642E),
    coralInk: Color(0xFF1F0C03),
    coralStrong: Color(0xFFC2410C),
    coralSubtle: Color(0xFFFFE8DE),
    coralChipBorder: Color(0xFFF2B8A0),
    warning: Color(0xFFA86F0A),
    warningSubtle: Color(0xFFFBF1DC),
    warningBorder: Color(0xFFF0DDB0),
    warningInk: Color(0xFFFBF1DC),
    danger: Color(0xFFC93C3C),
    video: Color(0xFF070B0F),
    scrim: Color(0x9E05090D),
    hatchA: Color(0xFFE4E9EE),
    hatchB: Color(0xFFEEF2F5),
  );

  static MmColors of(BuildContext context) =>
      Theme.of(context).extension<MmColors>()!;

  @override
  MmColors copyWith() => this;

  @override
  MmColors lerp(MmColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Manrope for text, JetBrains Mono (tabular) for times, formats and paths.
/// Both are variable fonts: the weight axis is set explicitly so every
/// platform renders the designed weight.
abstract final class MmType {
  static const sans = 'Manrope';
  static const mono = 'JetBrainsMono';

  static TextStyle _s(
    double size,
    double height,
    int weight, {
    double tracking = 0,
  }) => TextStyle(
    fontFamily: sans,
    fontSize: size,
    height: height / size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    letterSpacing: tracking * size,
  );

  static final displayXl = _s(40, 46, 800, tracking: -0.03);
  static final display = _s(28, 34, 800, tracking: -0.02);
  static final titleLg = _s(24, 30, 800, tracking: -0.02);
  static final title = _s(18, 24, 700);
  static final heading = _s(14, 20, 700);
  static final body = _s(14, 21, 500);
  static final bodySm = _s(13, 19, 500);
  static final label = _s(13.5, 18, 600);
  static final labelStrong = _s(13.5, 18, 700);
  static final caption = _s(12, 16, 500);
  static final captionStrong = _s(12, 16, 700);
  static final overline = _s(11, 16, 700, tracking: 0.06);

  static TextStyle monoStyle({
    double size = 11.5,
    int weight = 500,
    Color? color,
  }) => TextStyle(
    fontFamily: mono,
    color: color,
    fontSize: size,
    height: 1.4,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

abstract final class MmRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const card = 16.0;
  static const xl = 18.0;
  static const sheet = 20.0;
  static const xxl = 24.0;
  static const pill = 999.0;
}

abstract final class MmShadows {
  static const card = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const menu = [
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 12)),
  ];
  static const dialog = [
    BoxShadow(color: Color(0x80000000), blurRadius: 64, offset: Offset(0, 24)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x73000000), blurRadius: 30, offset: Offset(0, 12)),
  ];
  static const cover = [
    BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Halo of the coral play button.
  static const playHalo = [
    BoxShadow(color: Color(0x4DFF7A45), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// Durations and curves of the handoff (§03). [MmMotion.of] swaps every
/// movement for a 120 ms fade when the system asks for reduced motion.
@immutable
class MmMotion {
  const MmMotion._(this.reduced);

  final bool reduced;

  static const standard = Cubic(0.2, 0, 0, 1);
  static const exit = Cubic(0.3, 0, 1, 1);
  static const _fade = Duration(milliseconds: 120);

  static MmMotion of(BuildContext context) =>
      MmMotion._(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  Duration _d(int ms) => reduced ? _fade : Duration(milliseconds: ms);

  Duration get hover => const Duration(milliseconds: 80);
  Duration get state => _d(120);
  Duration get screen => _d(160);
  Duration get favorite => _d(180);
  Duration get dialog => _d(220);
  Duration get album => _d(240);
  Duration get sheetSettle => _d(240);
  Duration get video => _d(280);
  Duration get player => _d(320);

  /// Distance a screen rises while fading in (0 when motion is reduced).
  double get screenRise => reduced ? 0 : 8;
}
