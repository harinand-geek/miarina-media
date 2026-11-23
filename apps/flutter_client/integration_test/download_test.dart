import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miarina_media/features/get/get_data.dart'
    show defaultFormat, downloadTitle;
import 'package:miarina_media/src/rust/api/get.dart';
import 'package:miarina_media/src/rust/api/indexer.dart';
import 'package:miarina_media/src/rust/api/library.dart';
import 'package:miarina_media/src/rust/frb_generated.dart';

// Obtenir on Windows with the real core, as the screens call it: analysis of
// a link, the audio format, download, conversion by FFmpeg, the file in the
// library, then a canceled download. Everything happens in DL_WORK (a
// scratch folder, never the user's library or Downloads folder); the tools
// are those of the installer (DL_TOOLS: the staged `tools` folder).
//
//   flutter test integration_test/download_test.dart -d windows
//     --dart-define=DL_WORK=<scratch folder> --dart-define=DL_TOOLS=<tools>
//     [--dart-define=DL_URL=<link>]
// The scenario's lines are printed as it goes. On Windows the test window
// stays open (blank) at the end: the tool waits for the core's threads,
// which run until the app quits; close it once "canceled entry" is printed.
const _work = String.fromEnvironment('DL_WORK');
const _tools = String.fromEnvironment('DL_TOOLS');
// Big Buck Bunny (Blender Foundation, CC BY 3.0), as in the 0.1.x checks.
const _url = String.fromEnvironment(
  'DL_URL',
  defaultValue: 'https://youtu.be/aqz-KE-bpKQ',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => RustLib.init());

  testWidgets('link → analysis → MP3 → library; a cancel is no failure', (
    tester,
  ) async {
    // Real time: the core works on its own threads.
    await tester.runAsync(_scenario);
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _scenario() async {
  {
    expect(_work, isNotEmpty, reason: 'DL_WORK is required');
    final work = Directory(_work)..createSync(recursive: true);
    final db = '${work.path}${Platform.pathSeparator}miarina.db';
    final downloads = Directory(
      '${work.path}${Platform.pathSeparator}downloads',
    )..createSync();

    await indexerStart(
      dbPath: db,
      dataDir: work.path,
      toolsDir: _tools.isEmpty ? null : _tools,
    );
    await getStart(defaultDir: downloads.path);
    final events = <GetEvent>[];
    final sub = getEvents().listen(events.add);

    // Analysis, as GetAnalysisScreen.
    final analysis = await getAnalyze(url: _url);
    expect(analysis.status, AnalysisStatus.ready, reason: analysis.detail);
    final info = analysis.info!;
    // ignore: avoid_print
    print(
      'analysis: "${info.title}" · ${info.video.length} video, '
      '${info.audio.length} audio formats',
    );
    expect(info.audio, isNotEmpty);
    final mp3 = info.audio.firstWhere(
      (f) => f.quality.startsWith('MP3 · 128'),
      orElse: () => defaultFormat(info.audio)!,
    );

    // Download, as "Télécharger" does.
    final task = await getStartDownload(
      request: StartRequest(
        url: info.url,
        title: downloadTitle(info, mp3),
        isAudio: true,
        engine: info.engine,
        formatId: mp3.id == 'original' ? null : mp3.id,
        formatLabel: mp3.quality,
        extension_: mp3.extension_,
        startNow: true,
        thumbnail: info.thumbnail,
      ),
    );
    HistoryInfo? done;
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (done == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final history = await getHistory(limit: 20);
      done = history.where((h) => h.taskId == task.id).firstOrNull;
    }
    expect(done, isNotNull, reason: 'the download did not finish in time');
    expect(done!.completed, isTrue, reason: done.reason);
    final file = File(done.finalPath!);
    expect(file.existsSync(), isTrue);
    expect(file.path.toLowerCase(), endsWith('.mp3'));
    expect(file.parent.path, downloads.path);
    // ignore: avoid_print
    print('downloaded: ${file.path} (${file.lengthSync()} bytes)');
    expect(
      events.any((e) => e.kind == GetEventKind.progress),
      isTrue,
      reason: 'progress events reach the screens',
    );

    // In the library (Récemment téléchargés, Titres).
    final item = await libraryItemByPath(dbPath: db, path: file.path);
    expect(item, isNotNull);
    // ignore: avoid_print
    print('in the library: ${item!.title}');

    // A second download canceled by the user: in the history as canceled,
    // never as a failure.
    final second = await getStartDownload(
      request: StartRequest(
        url: info.url,
        title: '${downloadTitle(info, mp3)} (2)',
        isAudio: true,
        engine: info.engine,
        formatId: mp3.id == 'original' ? null : mp3.id,
        formatLabel: mp3.quality,
        extension_: mp3.extension_,
        startNow: true,
        thumbnail: null,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    // ignore: avoid_print
    print('second download started: ${second.id}');
    await getTaskAction(id: second.id, action: 'cancel');
    // ignore: avoid_print
    print('cancel sent');
    HistoryInfo? canceled;
    for (var i = 0; i < 15 && canceled == null; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final history = await getHistory(limit: 20);
      // ignore: avoid_print
      print('history polled ($i): ${history.length} entries');
      canceled = history.where((h) => h.taskId == second.id).firstOrNull;
    }
    expect(canceled?.canceled, isTrue);
    expect(canceled?.completed, isFalse);
    // ignore: avoid_print
    print('canceled entry: ${canceled?.canceled}');
    await sub.cancel();
  }
}
