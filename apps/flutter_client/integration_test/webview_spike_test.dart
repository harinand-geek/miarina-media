import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miarina_media/src/rust/api/browser_spike.dart';
import 'package:miarina_media/src/rust/frb_generated.dart';

// Windows only. Serves a page with a <video> from this process and checks
// that a WebView2 hosted in the Flutter window reports the file through the
// shared media_core detection rules (same as the Tauri browser).
const _mediaDir = String.fromEnvironment('POC_MEDIA');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => RustLib.init());

  testWidgets('WebView2 in the Flutter window detects a page video', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(color: Color(0xFF101820)),
      ),
    );
    final video = File('$_mediaDir/test.mp4');
    expect(video.existsSync(), isTrue);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      if (req.uri.path == '/test.mp4') {
        res.headers.contentType = ContentType('video', 'mp4');
        res.contentLength = video.lengthSync();
        await res.addStream(video.openRead());
      } else {
        res.headers.contentType = ContentType.html;
        res.write(
          '<!doctype html><title>poc</title>'
          '<video src="/test.mp4" autoplay muted controls width="480"></video>',
        );
      }
      await res.close();
    });
    addTearDown(() => server.close(force: true));

    final info = webviewSpikeOpen(
      url: 'http://127.0.0.1:${server.port}/',
      x: 0,
      y: 0,
      width: 640,
      height: 360,
    );
    addTearDown(webviewSpikeClose);
    // ignore: avoid_print
    print('WebView2 created on the window thread: ${info.onWindowThread}');

    final deadline = DateTime.now().add(const Duration(seconds: 20));
    var found = <DetectedMediaItem>[];
    while (DateTime.now().isBefore(deadline) && found.isEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
      found = webviewSpikeDetections();
    }
    // ignore: avoid_print
    print('detected: ${found.map((m) => '${m.kind} ${m.url} ${m.sizeBytes}')}');
    expect(found, isNotEmpty);
    expect(found.first.kind, 'video');
    expect(found.first.url, endsWith('/test.mp4'));
  });
}
