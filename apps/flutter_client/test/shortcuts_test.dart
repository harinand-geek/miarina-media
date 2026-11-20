import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/cinema/watch_screen.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/shortcuts/keymap.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool ctrl = false,
  bool alt = false,
  bool shift = false,
}) async {
  final mods = [
    if (ctrl) LogicalKeyboardKey.controlLeft,
    if (alt) LogicalKeyboardKey.altLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
  ];
  for (final m in mods) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final m in mods.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await settle(tester);
}

void main() {
  group('keymap', () {
    test('keys are saved and read back', () {
      const k = KeySpec(LogicalKeyboardKey.keyP, ctrl: true, shift: true);
      expect(KeySpec.decode(k.encode()), k);
      expect(k.label(), 'Ctrl Maj P');
      expect(
        const KeySpec(LogicalKeyboardKey.space).label(spaceName: 'Space'),
        'Space',
      );
      expect(KeySpec.decode('nope'), isNull);
    });

    test('conflicts follow the scopes', () {
      const map = Keymap();
      // F is the video's full screen: a global shortcut cannot take it…
      expect(
        map.conflictFor(
          ShortcutAction.mute,
          const KeySpec(LogicalKeyboardKey.keyF),
        ),
        ShortcutAction.fullscreen,
      );
      // …but the Focus player can use the video player's C.
      expect(
        map.conflictFor(
          ShortcutAction.bookmark,
          const KeySpec(LogicalKeyboardKey.keyC),
        ),
        isNull,
      );
    });

    test('changes keep only what differs from the defaults', () {
      var map = const Keymap().withKey(
        ShortcutAction.fullscreen,
        const KeySpec(LogicalKeyboardKey.keyG),
      );
      expect(map.toJson().keys, ['fullscreen']);
      map = Keymap.fromJson(map.toJson());
      expect(
        map.keyOf(ShortcutAction.fullscreen)?.key,
        LogicalKeyboardKey.keyG,
      );
      map = map.withKey(
        ShortcutAction.fullscreen,
        map.defaultOf(ShortcutAction.fullscreen),
      );
      expect(map.changes, isEmpty);
      // An action with no key at all is kept as such.
      map = map.withKey(ShortcutAction.mute, null);
      expect(Keymap.fromJson(map.toJson()).keyOf(ShortcutAction.mute), isNull);
    });
  });

  group('in the app', () {
    late FakeEngine engine;
    late FakeSettingsStore settings;

    Future<void> pumpApp(WidgetTester tester, {required String start}) async {
      tester.view.physicalSize = const Size(1280, 860);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(engine),
            libraryApiProvider.overrideWithValue(
              FakeLibraryApi([track(1, 'Basse marée'), track(2, 'Échos')]),
            ),
            cinemaApiProvider.overrideWithValue(
              FakeCinemaApi([video(20, 'Le Dernier Ferry', minutes: 102)]),
            ),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(settings),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
            initialRouteProvider.overrideWithValue(start),
          ],
          child: const MiarinaApp(),
        ),
      );
      await settle(tester);
    }

    setUp(() {
      engine = FakeEngine();
      settings = FakeSettingsStore();
    });

    testWidgets('global keys: play, volume, mute, sidebar, back, now', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.tracks);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Basse marée')),
      );
      await container.read(queueProvider.notifier).playAll([
        queueEntryOf(track(1, 'Basse marée')),
      ]);
      await settle(tester);

      await press(tester, LogicalKeyboardKey.space);
      expect(engine.current.status, PlaybackStatus.paused);
      await press(tester, LogicalKeyboardKey.space);
      expect(engine.current.status, PlaybackStatus.playing);

      await engine.setVolume(0.5);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(engine.current.volume, closeTo(0.55, 0.001));
      await press(tester, LogicalKeyboardKey.keyM);
      expect(engine.current.volume, 0);
      await press(tester, LogicalKeyboardKey.keyM);
      expect(engine.current.volume, closeTo(0.55, 0.001));

      await press(tester, LogicalKeyboardKey.bracketRight);
      expect(engine.current.speed, 1.25);

      expect(find.text('Albums'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.keyB, ctrl: true);
      expect(find.text('Albums'), findsNothing, reason: 'sidebar collapsed');
      await press(tester, LogicalKeyboardKey.keyB, ctrl: true);
      expect(find.text('Albums'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.keyP, ctrl: true, shift: true);
      expect(find.text('Paroles'), findsWidgets, reason: 'Now playing');
      await press(tester, LogicalKeyboardKey.arrowLeft, alt: true);
      expect(find.text('Échos'), findsOneWidget, reason: 'back on Tracks');
      await press(tester, LogicalKeyboardKey.arrowRight, alt: true);
      expect(find.text('Paroles'), findsWidgets, reason: 'forward again');
    });

    testWidgets('typing in a field never triggers plain keys', (tester) async {
      await pumpApp(tester, start: Routes.tracks);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Basse marée')),
      );
      await container.read(queueProvider.notifier).playAll([
        queueEntryOf(track(1, 'Basse marée')),
      ]);
      await settle(tester);
      await press(tester, LogicalKeyboardKey.keyK, ctrl: true);
      await press(tester, LogicalKeyboardKey.space);
      await press(tester, LogicalKeyboardKey.keyM);
      expect(engine.current.status, PlaybackStatus.playing);
      expect(engine.current.volume, 1);
    });

    testWidgets('W-S3: change a key, resolve a conflict, restore', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.settings}/shortcuts');
      expect(find.text('Raccourcis clavier'), findsOneWidget);
      expect(find.text('Plein écran'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^Plein écran : F')));
      await settle(tester);
      expect(find.text('Appuyez sur une touche…'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.keyG);
      expect(find.bySemanticsLabel(RegExp('^Plein écran : G')), findsOneWidget);
      expect(
        (settings.values['shortcuts'] as Map)['fullscreen'],
        isA<String>(),
      );

      // M for the subtitles: used by Mute everywhere → asked first.
      await tester.tap(find.bySemanticsLabel(RegExp('^Sous-titres : C')));
      await settle(tester);
      await press(tester, LogicalKeyboardKey.keyM);
      expect(
        find.text('M est déjà utilisé par « Couper le son ».'),
        findsOneWidget,
      );
      await tester.tap(find.text('Remplacer'));
      await settle(tester);
      expect(find.bySemanticsLabel(RegExp('^Sous-titres : M')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Couper le son : Aucune')),
        findsOneWidget,
      );

      await tester.tap(find.text('Rétablir les valeurs'));
      await settle(tester);
      expect(find.bySemanticsLabel(RegExp('^Plein écran : F')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Couper le son : M')),
        findsOneWidget,
      );
    });

    testWidgets('the video player follows the changed keys; . steps', (
      tester,
    ) async {
      settings.values['shortcuts'] = {
        'fullscreen': const KeySpec(LogicalKeyboardKey.keyG).encode(),
      };
      await pumpApp(tester, start: Routes.cinema);
      await tester.tap(find.text('Le Dernier Ferry'));
      await settle(tester);
      expect(find.byType(WatchScreen), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WatchScreen)),
      );
      await press(tester, LogicalKeyboardKey.keyF);
      expect(container.read(videoFullscreenProvider), isFalse);
      await press(tester, LogicalKeyboardKey.keyG);
      expect(container.read(videoFullscreenProvider), isTrue);
      await press(tester, LogicalKeyboardKey.period);
      expect(engine.frameSteps, 1);
    });

    testWidgets('About lists the bundled fonts and icons licenses', (
      tester,
    ) async {
      await pumpApp(tester, start: '${Routes.settings}/about');
      expect(find.text('GPL-3.0-only'), findsOneWidget);
      expect(find.text('Version de développement'), findsOneWidget);
      await tester.tap(find.text('Afficher'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Phosphor Icons'), findsWidgets);
      expect(find.textContaining('Manrope'), findsWidgets);
    });
  });
}
