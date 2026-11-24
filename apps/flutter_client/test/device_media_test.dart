import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/device_media/device_media.dart';
import 'package:miarina_media/features/device_media/device_media_view.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';

import 'package:miarina_media/src/rust/api/library.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// The Android side: the access [granted] after the system dialog, the
/// phone's media [paths], every call recorded.
class FakeDeviceMediaApi implements DeviceMediaApi {
  FakeDeviceMediaApi({this.granted = true, this.paths = const []});

  bool granted;
  final List<String> paths;
  var current = DeviceAccess.none;
  var requests = 0;
  var settingsOpened = 0;

  @override
  Future<DeviceAccess> access() async => current;

  @override
  Future<DeviceAccess> request() async {
    requests++;
    if (granted) current = const DeviceAccess(audio: true, video: true);
    return current;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<(DeviceAccess, List<String>)> list() async =>
      (current, current.any ? paths : const <String>[]);

  /// What the system confirmation answers.
  var deleteAnswer = 'deleted';
  final deleted = <List<String>>[];
  final shared = <String>[];

  @override
  Future<String> delete(List<String> paths) async {
    deleted.add(paths);
    return deleteAnswer;
  }

  @override
  Future<bool> share(String path, String title) async {
    shared.add(path);
    return true;
  }
}

void main() {
  late FakeDeviceMediaApi device;
  late FakeIndexerApi indexer;
  late FakeSettingsStore settings;
  late FakeHealthApi health;

  Future<void> pumpPhone(
    WidgetTester tester, {
    String? start,
    List<LibraryItem> tracks = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          libraryApiProvider.overrideWithValue(FakeLibraryApi([...tracks])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(indexer),
          healthApiProvider.overrideWithValue(health),
          desktopShellProvider.overrideWithValue(false),
          deviceMediaSupportedProvider.overrideWithValue(true),
          deviceMediaApiProvider.overrideWithValue(device),
          settingsStoreProvider.overrideWithValue(settings),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(start ?? Routes.listenHome),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    device = FakeDeviceMediaApi(paths: ['/storage/emulated/0/Music/a.flac']);
    indexer = FakeIndexerApi();
    settings = FakeSettingsStore()..values['onboardingDone'] = true;
    health = FakeHealthApi();
  });

  testWidgets('A-06: explanation, system dialog, then the phone is indexed', (
    tester,
  ) async {
    await pumpPhone(tester);
    expect(find.byType(AskAccessView), findsOneWidget);
    expect(
      find.text('Accédez à la musique et aux vidéos de ce téléphone'),
      findsOneWidget,
    );
    for (final reason in ['Musique et audio', 'Vidéos', 'Notifications']) {
      expect(find.text(reason), findsOneWidget);
    }
    // Not built yet: not shown.
    expect(find.text('Choisir un dossier à la place'), findsNothing);

    await tester.tap(find.text("Autoriser l'accès"));
    await settle(tester);
    expect(device.requests, 1);
    expect(settings.values[DeviceMediaController.askedKey], true);
    expect(indexer.synced.last, ['/storage/emulated/0/Music/a.flac']);
    expect(find.byType(AskAccessView), findsNothing);
  });

  testWidgets('A-07: a refusal leads to the system settings; granting there '
      'indexes the phone on return', (tester) async {
    device.granted = false;
    await pumpPhone(tester);
    await tester.tap(find.text("Autoriser l'accès"));
    await settle(tester);
    expect(find.byType(AccessDeniedView), findsOneWidget);
    expect(find.text('Accès aux fichiers refusé'), findsOneWidget);
    expect(indexer.synced, isEmpty);

    await tester.tap(find.text('Ouvrir les paramètres Android'));
    await settle(tester);
    expect(device.settingsOpened, 1);

    // Granted in the settings, then back to the app.
    device.current = const DeviceAccess(audio: true, video: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.byType(AccessDeniedView), findsNothing);
    expect(indexer.synced.last, ['/storage/emulated/0/Music/a.flac']);
  });

  testWidgets('a refusal remembered across launches shows A-07 directly', (
    tester,
  ) async {
    settings.values[DeviceMediaController.askedKey] = true;
    await pumpPhone(tester);
    expect(find.byType(AccessDeniedView), findsOneWidget);
  });

  // 0.2.7: downloaded first, the library was not empty and the access was
  // never offered, so the phone's music never showed.
  testWidgets('downloads before the access: a banner offers it', (
    tester,
  ) async {
    await pumpPhone(tester, tracks: [track(1, 'Volamena')]);
    expect(find.byType(AskAccessView), findsNothing);
    expect(find.byType(DeviceAccessBanner), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(DeviceAccessBanner),
        matching: find.text("Autoriser l'accès"),
      ),
    );
    await settle(tester);
    expect(device.requests, 1);
    expect(indexer.synced.last, ['/storage/emulated/0/Music/a.flac']);
    expect(find.byType(DeviceAccessBanner), findsNothing);
  });

  testWidgets('the banner: Android settings after a refusal, ✕ hides it', (
    tester,
  ) async {
    settings.values[DeviceMediaController.askedKey] = true;
    await pumpPhone(tester, tracks: [track(1, 'Volamena')]);
    await tester.tap(find.text('Ouvrir les paramètres Android'));
    await settle(tester);
    expect(device.settingsOpened, 1);
    await tester.tap(find.byTooltip('Fermer'));
    await settle(tester);
    expect(find.byType(DeviceAccessBanner), findsNothing);
    expect(settings.values['deviceMediaBannerHidden'], true);
  });

  // 0.2.7: a title had no actions on the phone (no long press, no menu).
  group('Titres on a phone: long press or dots, then the sheet', () {
    final songs = [track(1, 'Volamena'), track(2, 'Saina Tonga')];

    setUp(() => device.current = const DeviceAccess(audio: true, video: true));

    testWidgets('Supprimer du téléphone: confirmed, the title leaves', (
      tester,
    ) async {
      await pumpPhone(tester, start: Routes.tracks, tracks: songs);
      await tester.tap(find.byKey(const ValueKey('track-more-2')));
      await settle(tester);
      for (final label in [
        'Lire ensuite',
        'Ajouter à la file',
        'Ajouter à une playlist…',
        'Partager',
        'Supprimer du téléphone',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Supprimer du téléphone'));
      await settle(tester);
      expect(device.deleted, [
        ['C:/Musique/Saina Tonga.flac'],
      ]);
      expect(health.removed, [2]);
      expect(find.text('Supprimé du téléphone'), findsOneWidget);
    });

    testWidgets('canceled in the Android window: nothing changes', (
      tester,
    ) async {
      device.deleteAnswer = 'canceled';
      await pumpPhone(tester, start: Routes.tracks, tracks: songs);
      await tester.longPress(find.text('Volamena'));
      await settle(tester);
      await tester.tap(find.text('Supprimer du téléphone'));
      await settle(tester);
      expect(device.deleted, hasLength(1));
      expect(health.removed, isEmpty);
      expect(find.text('Volamena'), findsOneWidget);
    });

    testWidgets('Partager opens the system sheet with the file', (
      tester,
    ) async {
      await pumpPhone(tester, start: Routes.tracks, tracks: songs);
      await tester.longPress(find.text('Volamena'));
      await settle(tester);
      await tester.tap(find.text('Partager'));
      await settle(tester);
      expect(device.shared, ['C:/Musique/Volamena.flac']);
    });
  });

  testWidgets('with access, the phone is indexed again at launch', (
    tester,
  ) async {
    device.current = const DeviceAccess(audio: true, video: true);
    await pumpPhone(tester);
    expect(find.byType(AskAccessView), findsNothing);
    expect(indexer.synced, [
      ['/storage/emulated/0/Music/a.flac'],
    ]);
  });

  testWidgets('Obtenir on a phone: link card, share hint, quick actions', (
    tester,
  ) async {
    await pumpPhone(tester, start: Routes.get);
    expect(find.text('Coller un lien'), findsOneWidget);
    expect(find.text('Analyser le lien'), findsOneWidget);
    expect(
      find.text(
        "Ou partagez un lien vers Miarina Media depuis n'importe quelle app.",
      ),
      findsOneWidget,
    );
    expect(find.text('Audio seul'), findsOneWidget);
    // Playlist is available (DL-07): no badge left.
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('PRÉVU'), findsNothing);
  });

  testWidgets('other tabs are not gated', (tester) async {
    await pumpPhone(tester, start: Routes.focus);
    expect(find.byType(AskAccessView), findsNothing);
  });
}
