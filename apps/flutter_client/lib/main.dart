import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/launch_args.dart';
import 'engine/engine_factory.dart';
import 'engine/media_engine.dart';
import 'features/playback/playback.dart';
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
  if (media != null) {
    final name = fileTitle(media);
    await container.read(queueProvider.notifier).playAll([
      QueueEntry(
        source: MediaSource.file(media, title: name),
        title: name,
      ),
    ]);
  }
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
