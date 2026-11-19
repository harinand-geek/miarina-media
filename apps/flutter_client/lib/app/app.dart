import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../features/focus/focus_data.dart';
import '../features/settings/settings_data.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class MiarinaApp extends ConsumerWidget {
  const MiarinaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Remembered Focus speeds follow what plays, whichever screen started it.
    ref.watch(focusSpeedProvider);
    // Playback settings (W-S2) reach the engine.
    ref.watch(enginePreferencesProvider);
    final look = ref.watch(appearanceProvider).value ?? const AppearancePrefs();
    return MaterialApp.router(
      title: 'Miarina Media',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: buildMmTheme(MmColors.light),
      darkTheme: buildMmTheme(MmColors.dark),
      // Dark-first (design direction 3a); Settings › Appearance changes it.
      themeMode: switch (look.theme) {
        ThemePref.dark => ThemeMode.dark,
        ThemePref.light => ThemeMode.light,
        ThemePref.system => ThemeMode.system,
      },
      locale: look.language == null ? null : Locale(look.language!),
      // Text size and reduced motion (W-S1) apply to every screen live.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1) * look.textScale,
            ),
            disableAnimations: media.disableAnimations || look.reduceMotion,
          ),
          child: child!,
        );
      },
      localizationsDelegates: const [
        L10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: L10n.supportedLocales,
    );
  }
}
