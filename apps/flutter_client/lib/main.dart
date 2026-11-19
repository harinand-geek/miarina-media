import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/launch_args.dart';
import 'app/router.dart';
import 'engine/engine_factory.dart';
import 'engine/media_engine.dart';
import 'features/cinema/cinema_data.dart';
import 'features/cinema/cinema_screen.dart';
import 'features/focus/focus_data.dart';
import 'l10n/app_localizations.dart';
import 'features/library/library_data.dart';
import 'features/playback/playback.dart';
import 'src/rust/api/library.dart';
import 'src/rust/frb_generated.dart';

// Test hook: Android has no command line, so a test build can name a file to
// open with --dart-define=POC_OPEN=...
const _openDefine = String.fromEnvironment('POC_OPEN');

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  initializeEngines();
  if (Platform.isWindows) _setUpWindow();

  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(container: container, child: const MiarinaApp()),
  );

  // "Open with Miarina Media" / file association: play the handed-over file.
  final launch = LaunchArgs.parse([
    ...args,
    if (_openDefine.isNotEmpty) _openDefine,
  ]);
  final media = launch.media;
  if (media != null) await _openLaunchFile(container, media);
}

/// 1280 × 800 reference client area, 960 × 640 minimum, own title bar
/// (Handoff, Windows shell). Window sizes include Windows' invisible resize
/// borders, so they are measured once and added.
void _setUpWindow() {
  final window = WindowManager.instance.getCurrent();
  if (window == null) return;
  window.titleBarStyle = TitleBarStyle.hidden;
  final outer = window.size.toSize();
  final client = window.contentSize.toSize();
  final frame = Size(
    (outer.width - client.width).clamp(0, 64).toDouble(),
    (outer.height - client.height).clamp(0, 64).toDouble(),
  );
  window.minimumSize = Size(960 + frame.width, 640 + frame.height).toNative();
  window.setSize(
    Size(1280 + frame.width, 800 + frame.height).toNative(),
    false,
  );
  window.center();
}

/// A known file plays as its library entry (title, cover, favorite, resume
/// point); an unknown one under its file name.
Future<void> _openLaunchFile(ProviderContainer container, String path) async {
  LibraryItem? known;
  try {
    known = await container.read(libraryApiProvider).itemByPath(path);
  } catch (_) {
    known = null;
  }
  final name = fileTitle(path);
  final video = known != null && known.isVideo
      ? await container.read(cinemaApiProvider).item(known.id)
      : null;
  final focus = known != null && !known.isVideo
      ? await container.read(focusApiProvider).entry(known.id)
      : null;
  if (focus != null) {
    // A podcast, course or book plays in its program, at its speed (W-F2).
    final items = await container.read(
      focusProgramProvider(focus.program).future,
    );
    final i = items.indexWhere((f) => f.item.id == focus.item.id);
    await playFocus(
      container.read(queueProvider.notifier),
      i < 0 ? [focus] : items,
      start: i < 0 ? 0 : i,
    );
    container.read(routerProvider).push(Routes.focusPlayer);
    return;
  }
  if (video != null) {
    // A known episode keeps its label ("É4 · Le col"), like from Cinema.
    final t = lookupL10n(_appLocale());
    await playVideos(container.read(queueProvider.notifier), [
      video,
    ], label: (v) => episodeTitle(t, v));
  } else {
    await container.read(queueProvider.notifier).playAll([
      known != null
          ? queueEntryOf(known)
          : QueueEntry(
              source: MediaSource.file(path, title: name),
              title: name,
              isVideo: looksLikeVideo(path),
            ),
    ]);
  }
  // A video opens on its player (W-C3 / A-04).
  if (container.read(queueProvider).current?.isVideo ?? false) {
    container.read(routerProvider).push(Routes.watch);
  }
}

/// The interface language the app will pick (French unless the system asks
/// for a supported other one).
Locale _appLocale() {
  final system = PlatformDispatcher.instance.locale.languageCode;
  return L10n.supportedLocales.firstWhere(
    (l) => l.languageCode == system,
    orElse: () => const Locale('fr'),
  );
}
