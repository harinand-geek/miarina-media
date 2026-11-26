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
  /// The lyrics and where they come from (`youtube`, `lrclib`: LRC;
  /// `tononkira`: plain text).
  Future<FoundOnline?> find(LyricsLookup query);

  /// « Chercher les paroles »: choices for what the user typed.
  Future<List<LyricsOption>> search(
    String title,
    String? artist,
    Duration? duration,
  );

  /// The plain text of a Tononkira choice.
  Future<String?> fetch(String url);
}

typedef FoundOnline = ({String lrc, String source, bool synced});

/// One result of « Chercher les paroles ».
typedef LyricsOption = ({
  String track,
  String? artist,
  String? album,
  Duration? duration,
  String source,
  String? lrc,
  String? url,
});

class RustOnlineLyricsApi implements OnlineLyricsApi {
  RustOnlineLyricsApi(this._ref);

  final Ref _ref;

  @override
  Future<FoundOnline?> find(LyricsLookup q) async {
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
    return found == null
        ? null
        : (lrc: found.lrc, source: found.source, synced: found.synced);
  }

  @override
  Future<List<LyricsOption>> search(
    String title,
    String? artist,
    Duration? duration,
  ) async {
    if (!RustLib.instance.initialized) return const [];
    await _ref.read(downloadsProvider.notifier).started;
    final found = await rust.lyricsSearch(
      title: title,
      artist: artist,
      durationSecs: duration == null ? null : duration.inMilliseconds / 1000,
    );
    return [
      for (final c in found)
        (
          track: c.track,
          artist: c.artist,
          album: c.album,
          duration: c.durationSecs == null
              ? null
              : Duration(milliseconds: (c.durationSecs! * 1000).round()),
          source: c.source,
          lrc: c.lrc,
          url: c.url,
        ),
    ];
  }

  @override
  Future<String?> fetch(String url) async {
    if (!RustLib.instance.initialized) return null;
    await _ref.read(downloadsProvider.notifier).started;
    return rust.lyricsFetch(url: url);
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

/// The line that marks kept lyrics as plain text.
const _plainTag = '[plain]';

String sourceLabel(String source) => switch (source) {
  'youtube' => 'YouTube',
  'lrclib' => 'LRCLIB',
  'tononkira' => 'Tononkira',
  _ => source,
};

Lyrics? _parseKept(String text) {
  final lines = text.split('\n');
  final first = lines.first.trim();
  final source = first.startsWith(_sourceTag) && first.endsWith(']')
      ? first.substring(_sourceTag.length, first.length - 1)
      : null;
  if (lines.length > 1 && lines[1].trim() == _plainTag) {
    return parsePlainLyrics(lines.skip(2).join('\n'), source: source);
  }
  return parseLrc(text, source: source);
}

/// The kept form of lyrics: where they come from, plain or timed.
String _keptText(String body, String label, {required bool synced}) => synced
    ? '$_sourceTag$label]\n$body'
    : '$_sourceTag$label]\n$_plainTag\n$body';

/// Keeps [body] for [entry] (a choice, an imported file) and shows it.
Future<void> keepLyrics(
  WidgetRef ref,
  QueueEntry entry,
  String body, {
  required String label,
  required bool synced,
}) async {
  final cache = ref.read(lyricsCacheProvider);
  final keys = _keysOf(entry);
  final text = _keptText(body, label, synced: synced);
  for (final key in keys) {
    await cache.write(key, text);
  }
  ref.read(_missedProvider).removeAll(keys);
  ref.read(chosenLyricsProvider.notifier).set(entry, _parseKept(text));
}

/// Lyrics the user just chose or imported, shown at once (and kept).
final chosenLyricsProvider =
    NotifierProvider<ChosenLyrics, ({QueueEntry? entry, Lyrics? lyrics})>(
      ChosenLyrics.new,
    );

class ChosenLyrics extends Notifier<({QueueEntry? entry, Lyrics? lyrics})> {
  @override
  ({QueueEntry? entry, Lyrics? lyrics}) build() => (entry: null, lyrics: null);

  void set(QueueEntry entry, Lyrics? lyrics) =>
      state = (entry: entry, lyrics: lyrics);
}

List<String> _keysOf(QueueEntry entry) => [
  if (entry.onlineId case final id?) 'v-$id',
  lyricsTitleKey(entry.title),
];

/// Lookups that found nothing this session: not asked again.
final _missedProvider = Provider<Set<String>>((_) => <String>{});

/// Kept lyrics for [entry], else (when [online]) an online lookup, kept.
Future<Lyrics?> loadOnlineLyrics(
  Ref ref,
  QueueEntry entry, {
  required bool online,
}) async {
  final keys = _keysOf(entry);
  final cache = ref.read(lyricsCacheProvider);
  for (final key in keys) {
    final text = await cache.read(key);
    if (text != null) {
      final kept = _parseKept(text);
      if (kept != null) return kept;
    }
  }
  final missed = ref.read(_missedProvider);
  if (!online || keys.any(missed.contains)) return null;
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
    missed.addAll(keys);
    return null;
  }
  final label = sourceLabel(found.source);
  final text = _keptText(found.lrc, label, synced: found.synced);
  for (final key in keys) {
    await cache.write(key, text);
  }
  return _parseKept(text);
}
