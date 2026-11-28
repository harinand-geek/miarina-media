// Social media screenshots of 0.2.10: the real app screens, drawn by the
// test engine with a fictional demo library (names, generated covers) so no
// personal file and no protected artwork appears.
//
//   $env:MM_SOCIAL = "<folder>"; flutter test test/tool/social_shots_test.dart
//
// Skipped when MM_SOCIAL is not set.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/design/cover_tones.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/listen_journal.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import '../support/fakes.dart';

final _out = Platform.environment['MM_SOCIAL'];

/// A phone at 1080 px wide, a desktop at 2160 × 1350.
const _phone = Size(412, 892);
const _phoneDpr = 2.625;
const _desk = Size(1440, 900);
const _deskDpr = 1.5;
var _dpr = _phoneDpr;

/// Fictional albums: title, artist, two colours, art style.
const _albums = [
  ('Lavitra', 'Hanta Rova', Color(0xFFFF7A45), Color(0xFF3D1A5B), 0),
  ('Rivotra', 'Nosy Be Collective', Color(0xFF2EC4B6), Color(0xFF0B3C5D), 1),
  ('Ambalavao', 'Toky Rakoto', Color(0xFFF4D35E), Color(0xFF8C2F39), 2),
  ('Fitiavana', 'Mialy', Color(0xFFEF476F), Color(0xFF1B1B3A), 3),
  ('Ranomasina', 'Fara & Lova', Color(0xFF4CC9F0), Color(0xFF3A0CA3), 4),
  ('Andro vaovao', 'Kanto', Color(0xFF90BE6D), Color(0xFF264653), 0),
  ('Tanàna', 'Hanta Rova', Color(0xFFB5179E), Color(0xFFFFB703), 1),
  ('Lalana', 'Rado Jazz', Color(0xFFE76F51), Color(0xFF2A9D8F), 2),
];

/// Titles, with their album index.
const _tracks = [
  ('Rivotra mahery', 1),
  ('Lavitra ianao', 0),
  ('Masoandro mena', 0),
  ('Ambalavao hariva', 2),
  ('Fitiavana mandrakizay', 3),
  ('Onja', 4),
  ('Andro vaovao', 5),
  ('Tanàna mazava', 6),
  ('Lalana lavitra', 7),
  ('Nosy kely', 1),
  ('Feo malefaka', 3),
  ('Ranomasina manga', 4),
];

Future<String> _cover(Directory dir, int i) async {
  final (_, _, a, b, style) = _albums[i];
  const s = 600.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  const full = Rect.fromLTWH(0, 0, s, s);
  canvas.drawRect(
    full,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, s), [a, b]),
  );
  final light = Paint()..color = const Color(0x33FFFFFF);
  final dark = Paint()..color = b.withValues(alpha: 0.75);
  switch (style) {
    case 0: // Sun over the sea.
      canvas.drawCircle(
        const Offset(s / 2, s * 0.46),
        s * 0.2,
        Paint()..color = Color.lerp(a, const Color(0xFFFFFFFF), 0.45)!,
      );
      for (var k = 0; k < 7; k++) {
        canvas.drawRect(
          Rect.fromLTWH(0, s * 0.62 + k * 26, s, 10 + k * 1.5),
          dark,
        );
      }
    case 1: // Waves.
      for (var k = 0; k < 9; k++) {
        final path = Path()..moveTo(0, s * 0.2 + k * 50);
        for (var x = 0.0; x <= s; x += 6) {
          path.lineTo(x, s * 0.2 + k * 50 + 18 * math.sin(x / 60 + k));
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..color = k.isEven ? const Color(0x55FFFFFF) : dark.color,
        );
      }
    case 2: // Mountains.
      for (var k = 0; k < 3; k++) {
        final path = Path()
          ..moveTo(0, s)
          ..lineTo(0, s * (0.55 + k * 0.12))
          ..lineTo(s * (0.3 + k * 0.1), s * (0.3 + k * 0.12))
          ..lineTo(s * (0.6 + k * 0.05), s * (0.5 + k * 0.1))
          ..lineTo(s * 0.85, s * (0.35 + k * 0.12))
          ..lineTo(s, s * (0.5 + k * 0.1))
          ..lineTo(s, s)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.lerp(
              b,
              const Color(0xFF000000),
              k * 0.2,
            )!.withValues(alpha: 0.6 + k * 0.15),
        );
      }
      canvas.drawCircle(const Offset(s * 0.72, s * 0.2), 46, light);
    case 3: // Rings.
      for (var k = 7; k > 0; k--) {
        canvas.drawCircle(
          const Offset(s * 0.5, s * 0.5),
          k * 38.0,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..color = (k.isEven ? a : b).withValues(alpha: 0.8),
        );
      }
    default: // Diagonal bands.
      canvas.save();
      canvas.rotate(-0.5);
      for (var k = -4; k < 14; k++) {
        canvas.drawRect(
          Rect.fromLTWH(-s, k * 70.0, s * 3, 30),
          k.isEven ? light : dark,
        );
      }
      canvas.restore();
  }
  // Fine grain so the covers look printed, not flat.
  final grain = Paint()..color = const Color(0x14FFFFFF);
  final rnd = math.Random(i);
  for (var k = 0; k < 2500; k++) {
    canvas.drawCircle(
      Offset(rnd.nextDouble() * s, rnd.nextDouble() * s),
      0.8,
      grain,
    );
  }
  final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('${dir.path}/album$i.png');
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
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _images(WidgetTester tester) async {
  final found = find.byType(Image).evaluate().toList();
  if (found.isEmpty) return;
  final providers = {for (final e in found) (e.widget as Image).image};
  final context = found.first;
  imageCache
    ..clear()
    ..clearLiveImages();
  await tester.runAsync(() async {
    for (final p in providers) {
      try {
        await precacheImage(p, context).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  });
  unawaited(tester.binding.reassembleApplication());
  await _settle(tester);
}

final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
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
    final dir = Directory.systemTemp.createTempSync('mm_social');
    covers = [for (var i = 0; i < _albums.length; i++) await _cover(dir, i)];
    for (final c in covers) {
      await CoverSeeds.instance.compute(c);
    }
    library = FakeLibraryApi([
      for (final (i, (title, album)) in _tracks.indexed)
        track(
          i + 1,
          title,
          artist: _albums[album].$2,
          album: _albums[album].$1,
          thumbnail: covers[album],
          favorite: i % 4 == 1,
          plays: 14 - i,
          trackNo: i + 1,
        ),
    ]);
  });

  Future<FakeEngine> pump(
    WidgetTester tester, {
    required bool light,
    required bool desktop,
    String start = Routes.listenHome,
  }) async {
    _dpr = desktop ? _deskDpr : _phoneDpr;
    tester.view.physicalSize = (desktop ? _desk : _phone) * _dpr;
    tester.view.devicePixelRatio = _dpr;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final settings = FakeSettingsStore()..values['onboardingDone'] = true;
    final store = FakePlaybackStore();
    if (light) store.values['mm:theme'] = 'light';
    final now = DateTime.now();
    store.values[historyKey] = jsonEncode([
      for (final (i, id) in const [1, 2, 4, 5, 3, 7, 1, 9, 2, 6].indexed)
        {
          'id': id,
          'title': 'x',
          'kind': 'audio',
          'at': now
              .subtract(Duration(minutes: 4 + i * 37))
              .millisecondsSinceEpoch,
          'position': 60,
          'duration': 245,
        },
    ]);
    var journal = ListenJournal.empty;
    for (final (d, mins, artist) in const [
      (6, 42, 'Mialy'),
      (5, 18, 'Kanto'),
      (4, 75, 'Nosy Be Collective'),
      (3, 33, 'Hanta Rova'),
      (2, 96, 'Nosy Be Collective'),
      (1, 64, 'Toky Rakoto'),
      (0, 51, 'Nosy Be Collective'),
    ]) {
      journal = journal.add(
        now.subtract(Duration(days: d)),
        mins * 60,
        artist: artist,
      );
    }
    store.values[listenJournalKey] = journal.encode();
    final engine = FakeEngine();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(engine),
            libraryApiProvider.overrideWithValue(library),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            desktopShellProvider.overrideWithValue(desktop),
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
    return engine;
  }

  /// Plays "Rivotra mahery" and moves it to 1:24 of 4:05.
  Future<void> playing(WidgetTester tester, FakeEngine engine) async {
    await tester.tap(find.text('Titres').first);
    await _settle(tester);
    await tester.tap(find.text('Rivotra mahery').first);
    await tester.pump(const Duration(milliseconds: 60));
    if (find.text('Rivotra mahery').evaluate().length < 2) {
      await tester.tap(find.text('Rivotra mahery').first);
    }
    await _settle(tester);
    final src = engine.current.source;
    engine.emit(
      PlaybackSnapshot(
        status: PlaybackStatus.playing,
        source: src,
        duration: const Duration(seconds: 245),
        position: const Duration(seconds: 84),
      ),
    );
    await _settle(tester);
  }

  testWidgets('android', (tester) async {
    final engine = await pump(tester, light: false, desktop: false);
    await _shot(tester, 'android-1-accueil');
    await tester.scrollUntilVisible(
      find.text('7 derniers jours'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await _settle(tester);
    await _shot(tester, 'android-4-statistiques');
    await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
    await _settle(tester);
    await playing(tester, engine);
    await tester.tap(find.text('Albums').first);
    await _settle(tester);
    await _shot(tester, 'android-5-albums');
    await tester.tap(find.bySemanticsLabel(RegExp('^Ouvrir En lecture')));
    await _settle(tester);
    await _shot(tester, 'android-2-lecteur');
    await tester.tap(find.bySemanticsLabel("Plus d'options").last);
    await _settle(tester);
    await tester.tap(find.text('Afficher le vinyle'));
    await _settle(tester);
    await _shot(tester, 'android-3-vinyle');
  }, skip: _out == null);

  testWidgets('desktop', (tester) async {
    final engine = await pump(tester, light: false, desktop: true);
    await playing(tester, engine);
    await tester.tap(find.text('Accueil').first);
    await _settle(tester);
    await _shot(tester, 'pc-1-accueil');
    await tester.tap(find.text('Albums').first);
    await _settle(tester);
    await _shot(tester, 'pc-3-albums');
    await tester.tap(find.text('Rivotra').first);
    await _settle(tester);
    await _shot(tester, 'pc-4-album');
    await tester.tap(find.bySemanticsLabel(RegExp('^Ouvrir En lecture')));
    await _settle(tester);
    await _shot(tester, 'pc-2-en-lecture');
    await tester.tap(find.text('Vinyle'));
    await _settle(tester);
    await _shot(tester, 'pc-5-vinyle');
  }, skip: _out == null);
}
