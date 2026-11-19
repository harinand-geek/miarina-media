import 'dart:io';

import 'media3_engine.dart';
import 'media_engine.dart';
import 'mpv_engine.dart';

/// Returns null when this platform has no adapter yet, so the interface can
/// say so instead of offering controls that do nothing.
MediaEngine? createPlatformEngine() {
  if (Platform.isWindows) return MpvEngine();
  if (Platform.isAndroid) return Media3Engine();
  return null;
}

void initializeEngines() {
  if (Platform.isWindows) MpvEngine.ensureInitialized();
}
