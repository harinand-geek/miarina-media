import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

ThemeData buildMmTheme(MmColors c) {
  final base = ThemeData(
    brightness: c.brightness,
    fontFamily: MmType.sans,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: c.surface2,
    focusColor: c.accent.withValues(alpha: 0.2),
    colorScheme: ColorScheme(
      brightness: c.brightness,
      primary: c.coral,
      onPrimary: c.coralInk,
      secondary: c.accent,
      onSecondary: const Color(0xFF062320),
      error: c.danger,
      onError: c.fg,
      surface: c.surface,
      onSurface: c.fg,
      outline: c.line,
      outlineVariant: c.divider,
    ),
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.fg, displayColor: c.fg),
    iconTheme: IconThemeData(color: c.muted, size: 20),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(MmRadius.sm),
        border: Border.all(color: c.overlayBorder),
      ),
      textStyle: MmType.caption.copyWith(color: c.fg),
      waitDuration: const Duration(milliseconds: 500),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.3),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.lineStrong),
      radius: const Radius.circular(MmRadius.pill),
      thickness: const WidgetStatePropertyAll(6),
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: c.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
    ),
  );
}
