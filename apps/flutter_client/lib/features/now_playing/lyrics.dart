import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

@immutable
class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

@immutable
class Lyrics {
  const Lyrics(this.lines, {this.source});

  /// Sorted by time; never empty for parsed lyrics.
  final List<LyricLine> lines;

  /// File the lyrics come from, for the footer ("marée-haute.lrc").
  final String? source;

  /// Index of the line being sung at [position], -1 before the first one.
  int indexAt(Duration position) {
    var lo = 0;
    var hi = lines.length - 1;
    var found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].time <= position) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }
}

final _stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _offset = RegExp(r'^\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

/// Parses synchronised LRC text. Lines without a timestamp (and the ID tags
/// such as [ar:]) are ignored; a line may carry several timestamps. Returns
/// null when nothing is synchronised.
Lyrics? parseLrc(String text, {String? source}) {
  var offset = Duration.zero;
  final lines = <LyricLine>[];
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    final o = _offset.firstMatch(line);
    if (o != null) {
      // Positive offset = lyrics appear sooner (LRC convention).
      offset = Duration(milliseconds: -int.parse(o.group(1)!));
      continue;
    }
    final stamps = <Duration>[];
    var rest = line;
    while (true) {
      final m = _stamp.matchAsPrefix(rest);
      if (m == null) break;
      final fraction = m.group(3);
      final ms = fraction == null
          ? 0
          : int.parse(fraction.padRight(3, '0').substring(0, 3));
      stamps.add(
        Duration(
          minutes: int.parse(m.group(1)!),
          seconds: int.parse(m.group(2)!),
          milliseconds: ms,
        ),
      );
      rest = rest.substring(m.end);
    }
    final words = rest.trim();
    if (stamps.isEmpty || words.isEmpty) continue;
    for (final t in stamps) {
      final at = t + offset;
      lines.add(LyricLine(at < Duration.zero ? Duration.zero : at, words));
    }
  }
  if (lines.isEmpty) return null;
  lines.sort((a, b) => a.time.compareTo(b.time));
  return Lyrics(List.unmodifiable(lines), source: source);
}

/// Larger files are not lyrics; they are not read.
const maxLrcBytes = 512 * 1024;

/// The .lrc file with the same name next to [mediaPath], if any.
Future<Lyrics?> loadSidecarLyrics(String mediaPath) async {
  final dot = mediaPath.lastIndexOf('.');
  final sep = mediaPath.lastIndexOf(RegExp(r'[\\/]'));
  final base = dot > sep ? mediaPath.substring(0, dot) : mediaPath;
  for (final ext in const ['.lrc', '.LRC', '.Lrc']) {
    final file = File('$base$ext');
    try {
      if (!await file.exists()) continue;
      if (await file.length() > maxLrcBytes) return null;
      final bytes = await file.readAsBytes();
      var text = utf8.decode(bytes, allowMalformed: true);
      // Byte order mark (U+FEFF) left by some editors.
      if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
        text = text.substring(1);
      }
      final name = file.path.substring(
        file.path.lastIndexOf(RegExp(r'[\\/]')) + 1,
      );
      return parseLrc(text, source: name);
    } on FileSystemException {
      return null;
    }
  }
  return null;
}
