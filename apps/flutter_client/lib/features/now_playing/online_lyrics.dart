import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/lyrics.dart' as rust;
import '../../src/rust/frb_generated.dart';
import '../get/get_data.dart';
import '../library/library_data.dart' show dataDirProvider;
import '../playback/playback.dart';
import 'lyrics.dart';

/// Lyrics found online (decision 0011, lot 7) for a track without a `.lrc`
/// next to it: the subtitles uploaded with its YouTube clip, then LRCLIB.
/// What is found is kept in the app's data (`lyrics/`), so it shows again
/// offline, and once the track is obtained (same title).

typedef LyricsLookup = ({
  String title,
  String? artist,
  Duration? duration,
  String? videoId,
});

/// The core's lookup; tests use a fake.
abstract interface class OnlineLyricsApi {
  /// Synchronised LRC text and where it comes from (`youtube`, `lrclib`).
  Future<({String lrc, String source})?> find(LyricsLookup query);
}

class RustOnlineLyricsApi implements OnlineLyricsApi {
  RustOnlineLyricsApi(this._ref);

  final Ref _ref;

  @override
  Future<({String lrc, String source})?> find(LyricsLookup q) async {
    if (!RustLib.instance.initialized) return null;
    await _ref.read(downloadsProvider.notifier).started;
    final found = await rust.lyricsFind(
      query: rust.LyricsQuery(
        title: q.title,
        artist: q.artist,
        durationSecs: q.duration == null
            ? null
            : q.duration!.inMilliseconds / 1000,
        videoId: q.videoId,
      ),
    );
    return found == null ? null : (lrc: found.lrc, source: found.source);
  }
}

final onlineLyricsApiProvider = Provider<OnlineLyricsApi>(
  RustOnlineLyricsApi.new,
);

/// The kept lyrics, one LRC file per key in `<data>/lyrics/`; tests use an
/// in-memory one.
abstract interface class LyricsCache {
  Future<String?> read(String key);
  Future<void> write(String key, String lrc);
}

class FileLyricsCache implements LyricsCache {
  FileLyricsCache(this._ref);

  final Ref _ref;

  Future<File> _file(String key) async {
    final dir = await _ref.read(dataDirProvider.future);
    return File(
      '$dir${Platform.pathSeparator}lyrics${Platform.pathSeparator}$key.lrc',
    );
  }

  @override
  Future<String?> read(String key) async {
    // Widget tests run without the native core: no disk either.
    if (!RustLib.instance.initialized) return null;
    try {
      final f = await _file(key);
      if (!await f.exists() || await f.length() > maxLrcBytes) return null;
      return utf8.decode(await f.readAsBytes(), allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String lrc) async {
    if (!RustLib.instance.initialized) return;
    try {
      final f = await _file(key);
      await f.parent.create(recursive: true);
      await f.writeAsString(lrc, flush: true);
    } catch (_) {
      // Shown this time; looked up again next time.
    }
  }
}

final lyricsCacheProvider = Provider<LyricsCache>(FileLyricsCache.new);

/// A key for a title that survives a download's file naming: letters and
/// digits only, lower case (FNV-1a, 64 bits).
String lyricsTitleKey(String title) {
  final norm = title.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
  var h = 0xcbf29ce484222325;
  for (final b in utf8.encode(norm)) {
    h ^= b;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return 't-${h.toUnsigned(64).toRadixString(16)}';
}

/// The LRC tag that remembers where kept lyrics came from (ignored by the
/// parser: no timestamp).
const _sourceTag = '[re:';

String sourceLabel(String source) => switch (source) {
  'youtube' => 'YouTube',
  'lrclib' => 'LRCLIB',
  _ => source,
};

Lyrics? _parseKept(String text) {
  final first = text.split('\n').first.trim();
  final source = first.startsWith(_sourceTag) && first.endsWith(']')
      ? first.substring(_sourceTag.length, first.length - 1)
      : null;
  return parseLrc(text, source: source);
}

/// Lookups that found nothing this session: not asked again.
final _missed = <String>{};

/// Kept lyrics for [entry], else (when [online]) an online lookup, kept.
Future<Lyrics?> loadOnlineLyrics(
  Ref ref,
  QueueEntry entry, {
  required bool online,
}) async {
  final keys = [
    if (entry.onlineId case final id?) 'v-$id',
    lyricsTitleKey(entry.title),
  ];
  final cache = ref.read(lyricsCacheProvider);
  for (final key in keys) {
    final text = await cache.read(key);
    if (text != null) {
      final kept = _parseKept(text);
      if (kept != null) return kept;
    }
  }
  if (!online || keys.any(_missed.contains)) return null;
  final found = await ref
      .read(onlineLyricsApiProvider)
      .find((
        title: entry.title,
        artist: entry.subtitle,
        duration: entry.duration,
        videoId: entry.onlineId,
      ))
      .catchError((Object _) => null);
  if (found == null) {
    _missed.addAll(keys);
    return null;
  }
  final label = sourceLabel(found.source);
  final text = '$_sourceTag$label]\n${found.lrc}';
  for (final key in keys) {
    await cache.write(key, text);
  }
  return parseLrc(found.lrc, source: label);
}
