// Phone screenshots of the expressive redesign, drawn by the test engine
// with the real fonts and generated covers (no device needed).
//
//   $env:MM_SHOTS = "<folder>"; flutter test test/tool/phone_shots_test.dart
//
// Skipped when MM_SHOTS is not set, so the normal suite ignores it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/design/cover_tones.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import '../support/fakes.dart';

final _out = Platform.environment['MM_SHOTS'];

const _size = Size(412, 892);
const _dpr = 2.0;

/// Covers: two-tone gradients with a disc, saturated like real artwork.
const _palette = [
  (Color(0xFFD7263D), Color(0xFF1B1B1E)),
  (Color(0xFF2E86DE), Color(0xFF9AD0F5)),
  (Color(0xFF2D6A4F), Color(0xFFB7E4C7)),
  (Color(0xFFF4A261), Color(0xFF264653)),
  (Color(0xFF7B2CBF), Color(0xFFE0AAFF)),
  (Color(0xFF3D405B), Color(0xFFE07A5F)),
  (Color(0xFFFFD166), Color(0xFF073B4C)),
  (Color(0xFF0B132B), Color(0xFF5BC0BE)),
];

Future<String> _cover(Directory dir, int i) async {
  final (a, b) = _palette[i % _palette.length];
  const s = 400.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(s, s), [a, b]),
  );
  canvas.drawCircle(
    Offset(s * (0.3 + 0.05 * i % 0.4), s * 0.55),
    s * 0.28,
    Paint()..color = b.withValues(alpha: 0.85),
  );
  canvas.drawCircle(
    Offset(s * 0.7, s * 0.3),
    s * 0.12,
    Paint()..color = a.withValues(alpha: 0.9),
  );
  final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('${dir.path}/cover$i.png');
  await f.writeAsBytes(png!.buffer.asUint8List());
  return f.path;
}

Future<void> _font(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Lets real file images decode, then draws a frame.
Future<void> _images(WidgetTester tester) async {
  // ignore: avoid_print
  print('images ${find.byType(Image).evaluate().length}');
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      final w = e.widget as Image;
      try {
        await precacheImage(w.image, e).timeout(const Duration(seconds: 2));
      } catch (_) {
        // ignore: avoid_print
        print('image not loaded: ${w.image}');
      }
    }
  });
  // ignore: avoid_print
  print('images done');
  await _settle(tester);
}

final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  // ignore: avoid_print
  print('shot $name');
  await _images(tester);
  await tester.runAsync(() async {
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_out/$name.png').writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  late List<String> covers;
  late FakeLibraryApi library;

  setUpAll(() async {
    if (_out == null) return;
    Directory(_out!).createSync(recursive: true);
    await _font('Manrope', 'assets/fonts/Manrope-Variable.ttf');
    await _font('JetBrainsMono', 'assets/fonts/JetBrainsMono-Variable.ttf');
    await _font('PhosphorRegular', 'assets/icons/Phosphor.ttf');
    await _font('PhosphorFill', 'assets/icons/Phosphor-Fill.ttf');
    final dir = Directory.systemTemp.createTempSync('mm_shots');
    covers = [for (var i = 0; i < 8; i++) await _cover(dir, i)];
    // Cover colours are read for real (decode + quantizer), before the
    // widget tests' fake clock.
    for (final c in covers) {
      await CoverSeeds.instance.compute(c);
    }
    library = FakeLibraryApi([
      for (final (i, (title, artist, album)) in const [
        ('Basse marée', 'Nafy Rakoto', 'Saisons de sel'),
        ('Échos du soir sur la colline rouge', 'Collectif Rova', 'Ny lanitra'),
        ('Kabary', 'Toky', 'Ny lanitra'),
        ('Lumière basse', 'Nafy Rakoto', 'Saisons de sel'),
        ('Marée haute', 'Hanta', 'Rivages'),
        ('Seuil', 'Mamy Ravel', 'Seuil'),
        ('Tsiky', 'Hanta', 'Rivages'),
        ('Vent de sable', 'Toky', 'Dunes'),
      ].indexed)
        track(
          i + 1,
          title,
          artist: artist,
          album: album,
          thumbnail: covers[i],
          favorite: i == 1,
          plays: 9 - i,
        ),
    ]);
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool light,
    String start = Routes.tracks,
  }) async {
    tester.view.physicalSize = _size * _dpr;
    tester.view.devicePixelRatio = _dpr;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final settings = FakeSettingsStore()..values['onboardingDone'] = true;
    final store = FakePlaybackStore();
    if (light) store.values['mm:theme'] = 'light';
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(FakeEngine()),
            libraryApiProvider.overrideWithValue(library),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            desktopShellProvider.overrideWithValue(false),
            settingsStoreProvider.overrideWithValue(settings),
            indexerApiProvider.overrideWithValue(FakeIndexerApi()),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(store),
            initialRouteProvider.overrideWithValue(start),
            launchedWithMediaProvider.overrideWithValue(false),
          ],
          child: const MiarinaApp(),
        ),
      ),
    );
    await _settle(tester);
  }

  Future<void> play(WidgetTester tester, String title) async {
    await tester.tap(find.text(title).first);
    await _settle(tester);
  }

  Future<void> openPlayer(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^Ouvrir En lecture')));
    await _settle(tester);
  }

  for (final light in [true, false]) {
    final theme = light ? 'light' : 'dark';
    testWidgets('$theme: library, mini player, player, sheets', (
      tester,
    ) async {
      await pump(tester, light: light);
      await play(tester, 'Basse marée');
      await _shot(tester, '$theme-01-tracks-mini');
      await openPlayer(tester);
      await _shot(tester, '$theme-02-player');
      await tester.tap(find.bySemanticsLabel("Plus d'options").last);
      await _settle(tester);
      await _shot(tester, '$theme-03-player-more');
      await tester.tap(find.text('Afficher le vinyle'));
      await _settle(tester);
      await _shot(tester, '$theme-04-vinyl');
      await tester.tap(find.bySemanticsLabel('Réduire le lecteur'));
      await _settle(tester);
      await tester.longPress(find.text('Kabary').first);
      await _settle(tester);
      await _shot(tester, '$theme-05-track-sheet');
    }, skip: _out == null);
  }

  testWidgets('players in other colours', (tester) async {
    await pump(tester, light: true);
    for (final (i, title) in const [
      (1, 'Échos du soir sur la colline rouge'),
      (4, 'Marée haute'),
      (6, 'Tsiky'),
    ]) {
      await play(tester, title);
      await openPlayer(tester);
      await _shot(tester, 'light-06-player-$i');
      await tester.tap(find.bySemanticsLabel('Réduire le lecteur'));
      await _settle(tester);
    }
  }, skip: _out == null);
}
