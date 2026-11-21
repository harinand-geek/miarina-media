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
}

void main() {
  late FakeDeviceMediaApi device;
  late FakeIndexerApi indexer;
  late FakeSettingsStore settings;

  Future<void> pumpPhone(WidgetTester tester, {String? start}) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          libraryApiProvider.overrideWithValue(FakeLibraryApi([])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(indexer),
          healthApiProvider.overrideWithValue(FakeHealthApi()),
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

  testWidgets('other tabs are not gated; Obtenir says it comes later', (
    tester,
  ) async {
    await pumpPhone(tester, start: Routes.get);
    expect(find.byType(AskAccessView), findsNothing);
    expect(find.text('Obtenir arrive dans une prochaine bêta'), findsOneWidget);
  });
}
