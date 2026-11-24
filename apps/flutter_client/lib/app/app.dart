import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../features/capture/capture_data.dart';
import '../features/capture/capture_overlay.dart';
import '../features/cinema/series_audio.dart';
import '../features/recorder/recorder_bar.dart';
import '../features/tour/tour.dart';
import '../features/recorder/recorder_data.dart';
import '../features/focus/focus_data.dart';
import '../features/get/download_notifications.dart';
import '../features/get/get_data.dart';
import '../features/import/import_data.dart';
import '../features/mini/mini_player.dart' show TaskbarSync;
import '../features/settings/settings_data.dart';
import '../l10n/app_localizations.dart';
import '../features/updates/updates_view.dart';
import 'exit_guard.dart';
import 'router.dart';

class MiarinaApp extends ConsumerWidget {
  const MiarinaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Remembered Focus speeds follow what plays, whichever screen started it.
    ref.watch(focusSpeedProvider);
    // Skip silences and voice boost, for Focus programs only.
    ref.watch(focusSpeechProvider);
    // Playback settings (W-S2) reach the engine.
    ref.watch(enginePreferencesProvider);
    // Episodes of a series start in the audio language chosen before.
    ref.watch(seriesAudioProvider);
    // Followed folders are scanned at launch; screens refresh as the
    // background worker reads them (W-O1).
    ref.watch(indexingProvider);
    // Obtenir: the download manager starts with the app, so queued and
    // interrupted downloads resume (rebuilt only when it becomes ready).
    ref.watch(downloadsProvider.select((s) => s.ready));
    // Android: download notifications and their buttons.
    ref.watch(downloadNotifierProvider);
    // Outils PC (Windows): the capture shortcuts work from any app.
    ref.watch(captureHotkeysProvider);
    // The recorder answers Alt R and the overlay's « Filmer » (Windows).
    ref.watch(recorderProvider.select((s) => s.busy));
    final look = ref.watch(appearanceProvider).value ?? const AppearancePrefs();
    return MaterialApp.router(
      title: 'Miarina Media',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: rootMessengerKey,
      theme: buildMmTheme(MmColors.light.withPlayColor(look.playColor)),
      darkTheme: buildMmTheme(MmColors.dark.withPlayColor(look.playColor)),
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
          // Taskbar thumbnail buttons follow the queue (W-M4, Windows);
          // closing stops torrents and flushes downloads first.
          // Updates are looked for after launch and every six hours.
          child: ExitGuard(
            child: UpdateMonitor(
              // The capture overlay covers every screen while it is open.
              child: TaskbarSync(
                child: RecorderHost(
                  child: CaptureHost(child: TourHost(child: child!)),
                ),
              ),
            ),
          ),
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
