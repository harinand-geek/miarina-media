import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../features/focus/focus_data.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class MiarinaApp extends ConsumerWidget {
  const MiarinaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Remembered Focus speeds follow what plays, whichever screen started it.
    ref.watch(focusSpeedProvider);
    return MaterialApp.router(
      title: 'Miarina Media',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: buildMmTheme(MmColors.light),
      darkTheme: buildMmTheme(MmColors.dark),
      // Dark-first (design direction 3a); the theme setting comes with W-S1.
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        L10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: L10n.supportedLocales,
    );
  }
}
