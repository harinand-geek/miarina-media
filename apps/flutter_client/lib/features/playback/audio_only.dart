import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import 'playback.dart';

/// « Écouter seulement »: a video goes on as sound alone, in the audio
/// player (and in the background on Android), its picture not decoded.
/// Stays for the next videos of the queue until the video is shown again.
final audioOnlyProvider = NotifierProvider<AudioOnly, bool>(AudioOnly.new);

class AudioOnly extends Notifier<bool> {
  @override
  bool build() {
    // Nothing plays any more: back to normal.
    ref.listen(queueProvider.select((q) => q.current == null), (_, empty) {
      if (empty) set(false);
    });
    return false;
  }

  Future<void> set(bool on) async {
    if (on == state) return;
    state = on;
    await ref.read(mediaEngineProvider)?.setVideoEnabled(!on);
  }
}

/// From the video page: the sound goes on in the audio player.
Future<void> listenOnly(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final desktop = ref.read(desktopShellProvider);
  await ref.read(audioOnlyProvider.notifier).set(true);
  if (desktop) {
    router.go(Routes.now);
  } else {
    router.pushReplacement(Routes.player);
  }
}

/// From the audio player: the picture again, where the video is.
Future<void> showVideoAgain(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final desktop = ref.read(desktopShellProvider);
  await ref.read(audioOnlyProvider.notifier).set(false);
  if (desktop) {
    router.go(Routes.watch);
  } else {
    router.pushReplacement(Routes.watch);
  }
}

/// Where the mini player and the playback bar open what plays: a video
/// listened to only opens the audio player.
bool opensVideoPage(WidgetRef ref, QueueEntry entry) =>
    entry.isVideo && !ref.read(audioOnlyProvider);
