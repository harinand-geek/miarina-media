import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/now_playing/lyrics.dart';

void main() {
  test('parses timestamps, fractions, repeats and ignores tags', () {
    final l = parseLrc('''
[ar:Nafy Rakoto]
[ti:Marée haute]
[00:12.30]On compte les vagues
[00:18]et la nuit ne finit pas
[01:02.5][00:24.125]On attend la marée haute

[00:30.00]
sans horodatage
''')!;
    expect(l.lines.map((x) => x.text), [
      'On compte les vagues',
      'et la nuit ne finit pas',
      'On attend la marée haute',
      'On attend la marée haute',
    ]);
    expect(l.lines.map((x) => x.time.inMilliseconds), [
      12300,
      18000,
      24125,
      62500,
    ]);
  });

  test('offset moves every line, never before zero', () {
    final l = parseLrc('[offset:+500]\n[00:00.20]a\n[00:02.00]b')!;
    expect(l.lines.map((x) => x.time.inMilliseconds), [0, 1500]);
  });

  test('indexAt finds the line being sung', () {
    final l = parseLrc('[00:01]a\n[00:05]b\n[00:09]c')!;
    expect(l.indexAt(Duration.zero), -1);
    expect(l.indexAt(const Duration(seconds: 1)), 0);
    expect(l.indexAt(const Duration(seconds: 7)), 1);
    expect(l.indexAt(const Duration(minutes: 9)), 2);
  });

  test('unsynchronised text is not lyrics', () {
    expect(parseLrc('just words\nno time'), isNull);
    expect(parseLrc(''), isNull);
  });

  test(
    'loads the sidecar .lrc next to the file, BOM and bad bytes tolerated',
    () async {
      final dir = await Directory.systemTemp.createTemp('mm-lrc');
      addTearDown(() => dir.delete(recursive: true));
      final lrc = File('${dir.path}/Marée haute.lrc');
      await lrc.writeAsBytes([
        0xEF,
        0xBB,
        0xBF,
        ...'[00:01]Le sel\n'.codeUnits,
        0xFF,
        0x0A,
      ]);
      final l = await loadSidecarLyrics(
        '${dir.path}${Platform.pathSeparator}Marée haute.flac',
      );
      expect(l, isNotNull);
      expect(l!.lines.single.text, 'Le sel');
      expect(l.source, 'Marée haute.lrc');
      expect(await loadSidecarLyrics('${dir.path}/absent.mp3'), isNull);
    },
  );

  test('oversized sidecar files are not read', () async {
    final dir = await Directory.systemTemp.createTemp('mm-lrc');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/big.lrc')
        .writeAsBytes(List.filled(maxLrcBytes + 1, 0x41));
    expect(await loadSidecarLyrics('${dir.path}/big.mp3'), isNull);
  });

  test('an empty sidecar file gives no lyrics', () async {
    final dir = await Directory.systemTemp.createTemp('mm-lrc');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/empty.lrc').writeAsBytes(const []);
    expect(await loadSidecarLyrics('${dir.path}/empty.mp3'), isNull);
  });
}
