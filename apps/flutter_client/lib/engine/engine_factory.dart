import 'dart:io';

import 'media3_engine.dart';
import 'media_engine.dart';
import 'crossfade_engine.dart';
import 'mpv_engine.dart';

/// Returns null when this platform has no adapter yet, so the interface can
/// say so instead of offering controls that do nothing.
MediaEngine? createPlatformEngine() {
  // Two players: the second only carries the next track during a
  // crossfade.
  if (Platform.isWindows) return CrossfadeEngine(MpvEngine(), MpvEngine());
  if (Platform.isAndroid) return Media3Engine();
  return null;
}

void initializeEngines() {
  if (Platform.isWindows) MpvEngine.ensureInitialized();
}
