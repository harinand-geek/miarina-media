import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/media_engine.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';

/// "Piste audio mémorisée par série" (handoff Cinéma): the language chosen
/// for an episode is used for the next ones of the series. Kept with the
/// other playback memories (`mm:` keys).
String seriesAudioKey(String series) => 'mm:series-audio:$series';

/// The series of a queued episode (its album), or null.
String? seriesOf(QueueEntry? e) =>
    e != null && e.isVideo && (e.album ?? '').isNotEmpty ? e.album : null;

/// Remembers the language of an audio track picked during an episode.
Future<void> rememberSeriesAudio(
  PlaybackStore store,
  QueueEntry? entry,
  TrackInfo track,
) async {
  final series = seriesOf(entry);
  final lang = track.language;
  if (series == null || lang == null || lang.isEmpty) return;
  try {
    await store.write({seriesAudioKey(series): lang});
  } catch (_) {}
}

/// Applies the remembered language when an episode's tracks are known.
final seriesAudioProvider = Provider<void>((ref) {
  final engine = ref.watch(mediaEngineProvider);
  if (engine == null) return;
  Uri? applied;
  final sub = engine.snapshots.listen((s) async {
    final uri = s.source?.uri;
    if (uri == null || uri == applied || s.audioTracks.length < 2) return;
    final series = seriesOf(ref.read(queueProvider).current);
    applied = uri;
    if (series == null) return;
    String? lang;
    try {
      lang = await ref.read(playbackStoreProvider).read(seriesAudioKey(series));
    } catch (_) {}
    if (lang == null) return;
    final track = s.audioTracks.where((t) => t.language == lang).firstOrNull;
    if (track != null && track.id != s.selectedAudio) {
      await engine.selectAudioTrack(track.id);
    }
  });
  ref.onDispose(sub.cancel);
});
