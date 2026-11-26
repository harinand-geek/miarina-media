import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../app/router.dart' show Routes;
import '../../engine/media_engine.dart';
import '../../src/rust/api/library.dart' show LibraryItem;
import '../../src/rust/api/online.dart';
import '../../src/rust/frb_generated.dart';
import '../get/get_data.dart';
import '../library/library_data.dart' show queueEntryOf;
import '../playback/playback.dart';
import 'online_data.dart';

/// Online entries in the player (decision 0011). An entry keeps
/// `miarina-online:<id>` as its source; the queue asks for the stream just
/// before the engine opens it (and ahead for the next entry), since stream
/// URLs expire and are never stored.

const onlineScheme = 'miarina-online';

Uri onlineSourceUri(String videoId) => Uri(scheme: onlineScheme, path: videoId);

/// Finds the audio stream of an online entry; tests use a fake.
abstract interface class OnlineStreams {
  /// [source] with the stream to open. Throws an [OnlineFailure]. [fresh]:
  /// not the cached one (the engine was refused with it). [ahead]: found
  /// before it is needed, never in the way of the one waited for.
  /// [clip]: the video with its sound (HLS) rather than the sound alone.
  Future<MediaSource> resolve(
    MediaSource source,
    String videoId, {
    bool fresh = false,
    bool ahead = false,
    bool clip = false,
  });
}

class RustOnlineStreams implements OnlineStreams {
  RustOnlineStreams(this._ref);

  final Ref _ref;

  @override
  Future<MediaSource> resolve(
    MediaSource source,
    String videoId, {
    bool fresh = false,
    bool ahead = false,
    bool clip = false,
  }) async {
    if (!RustLib.instance.initialized) {
      throw const OnlineFailure(OnlineFailureKind.tools);
    }
    await _ref.read(downloadsProvider.notifier).started;
    try {
      final s = await onlineResolve(
        videoId: videoId,
        fresh: fresh,
        ahead: ahead,
      );
      if (clip) {
        final hls = s.hlsUrl;
        if (hls == null) {
          throw const OnlineFailure(OnlineFailureKind.unavailable, 'no clip');
        }
        return source.withStream(
          Uri.parse(hls),
          mimeType: 'application/x-mpegURL',
        );
      }
      return source.withStream(
        Uri.parse(s.url),
        headers: {for (final h in s.httpHeaders) h.name: h.value},
      );
    } catch (e) {
      throw OnlineFailure.of(e);
    }
  }
}

final onlineStreamsProvider = Provider<OnlineStreams>(RustOnlineStreams.new);

/// What the queue is doing with an online entry: finding its stream, or
/// why it could not.
@immutable
class OnlinePlayback {
  const OnlinePlayback({this.entry, this.resolving = false, this.failure});

  final QueueEntry? entry;
  final bool resolving;
  final OnlineFailure? failure;
}

class OnlinePlaybackNotifier extends Notifier<OnlinePlayback> {
  @override
  OnlinePlayback build() => const OnlinePlayback();

  void resolving(QueueEntry entry) =>
      state = OnlinePlayback(entry: entry, resolving: true);

  void failed(QueueEntry entry, OnlineFailure failure) =>
      state = OnlinePlayback(entry: entry, failure: failure);

  /// [entry] plays: nothing to show for it any more.
  void done(QueueEntry entry) {
    if (identical(state.entry, entry)) state = const OnlinePlayback();
  }

  void clear() {
    if (state.entry != null) state = const OnlinePlayback();
  }
}

final onlinePlaybackProvider =
    NotifierProvider<OnlinePlaybackNotifier, OnlinePlayback>(
      OnlinePlaybackNotifier.new,
    );

/// The current entry's stream is being found (several seconds): the
/// players show it on their play button.
final onlineResolvingProvider = Provider<bool>((ref) {
  final s = ref.watch(onlinePlaybackProvider);
  final current = ref.watch(queueProvider.select((q) => q.current));
  return s.resolving && current != null && identical(s.entry, current);
});

/// Why the current online entry does not play, if it does not.
final onlineFailureProvider = Provider<OnlineFailure?>((ref) {
  final s = ref.watch(onlinePlaybackProvider);
  final current = ref.watch(queueProvider.select((q) => q.current));
  return current != null && identical(s.entry, current) ? s.failure : null;
});

/// A result's picture as a local file, fetched by the core (the UI never
/// loads remote images); null while it comes or when there is none.
final onlineThumbnailProvider = FutureProvider.family<String?, String>(
  (ref, url) => ref.watch(onlineApiProvider).thumbnail(url),
  retry: (_, _) => null,
);

/// Finds [videoId]'s stream ahead (the first result of a search): a
/// click on it then plays at once. Failures are left to the click.
void prepareOnline(WidgetRef ref, String videoId) => unawaited(
  ref
      .read(onlineStreamsProvider)
      .resolve(MediaSource(onlineSourceUri(videoId)), videoId, ahead: true)
      .then<void>((_) {}, onError: (Object _) {}),
);

/// The clip of an online track (decision 0011, lot 8): same video, its
/// picture and sound together, played in the video player.
Uri onlineClipUri(String videoId) =>
    Uri(scheme: onlineScheme, path: videoId, query: 'clip');

QueueEntry onlineClipEntry({
  required String videoId,
  required String title,
  String? subtitle,
  Duration? duration,
  String? artwork,
}) => QueueEntry(
  source: MediaSource(onlineClipUri(videoId), title: title),
  title: title,
  subtitle: subtitle,
  duration: duration,
  artwork: artwork,
  isVideo: true,
  onlineId: videoId,
);

QueueEntry onlineEntry(
  OnlineTrack track, {
  required String unknownArtist,
  String? artwork,
}) => QueueEntry(
  source: MediaSource(onlineSourceUri(track.videoId), title: track.title),
  title: track.title,
  subtitle: track.channel ?? unknownArtist,
  duration: Duration(milliseconds: (track.durationSecs * 1000).round()),
  artwork: artwork,
  onlineId: track.videoId,
);

/// Pictures not fetched by then are left out: playing must not wait.
const _artworkWait = Duration(milliseconds: 1500);

/// Plays [tracks] from [index], the others following like an album's.
/// Those in [local] (already obtained) play from their file, offline too.
Future<void> playOnline(
  WidgetRef ref,
  List<OnlineTrack> tracks,
  int index, {
  required String unknownArtist,
  Map<String, LibraryItem> local = const {},
}) async {
  final art = <String, String?>{};
  await Future.wait([
    for (final t in tracks)
      if (t.thumbnail case final url? when !local.containsKey(t.videoId))
        ref
            .read(onlineThumbnailProvider(url).future)
            .then((path) => art[t.videoId] = path)
            .catchError((_) => null),
  ]).timeout(_artworkWait, onTimeout: () => const []);
  await ref.read(queueProvider.notifier).playAll([
    for (final t in tracks)
      if (local[t.videoId] case final item?)
        queueEntryOf(item, unknownArtist: unknownArtist)
      else
        onlineEntry(t, unknownArtist: unknownArtist, artwork: art[t.videoId]),
  ], start: index);
}

/// Plays an online track's clip in the video player (decision 0011, lot 8).
/// [replace]: in place of the current entry (its sound), from [at].
Future<void> playOnlineClip(
  BuildContext context,
  WidgetRef ref, {
  required String videoId,
  required String title,
  String? subtitle,
  Duration? duration,
  String? artwork,
  bool replace = false,
  Duration? at,
}) async {
  final clip = onlineClipEntry(
    videoId: videoId,
    title: title,
    subtitle: subtitle,
    duration: duration,
    artwork: artwork,
  );
  final queue = ref.read(queueProvider.notifier);
  // The video page shows while the clip is found.
  unawaited(
    replace ? queue.replaceCurrent(clip, at: at) : queue.playAll([clip]),
  );
  if (context.mounted) await context.push(Routes.watch);
}
