import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/router.dart';
import 'package:miarina_media/features/cinema/cinema_data.dart';
import 'package:miarina_media/features/focus/focus_data.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/features/health/health_data.dart';
import 'package:miarina_media/features/import/import_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/lyrics_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/features/settings/settings_screen.dart';
import 'package:miarina_media/features/updates/updates_data.dart';
import 'package:miarina_media/features/updates/updates_view.dart';

import 'support/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

final release = UpdateRelease(
  version: '0.2.1',
  notes: '- Lecteur plus rapide\n- Corrections',
  size: BigInt.from(80 * 1048576),
);

/// The core's updater in memory.
class FakeUpdatesApi implements UpdatesApi {
  FakeUpdatesApi({this.enabled = true});

  @override
  final bool enabled;
  UpdateRelease? available;
  Object? checkError;
  Completer<UpdateRelease>? downloading;
  int downloaded = 0;
  var installs = 0;
  final prefsSet = <(String, bool)>[];

  @override
  Future<UpdateStatusInfo> status() async => UpdateStatusInfo(
    installed: '0.2.0',
    release: null,
    ready: false,
    downloaded: BigInt.zero,
    downloading: false,
  );

  @override
  Future<UpdateRelease?> check() async {
    if (checkError != null) throw checkError!;
    return available;
  }

  @override
  Future<UpdateRelease> download() {
    downloading = Completer<UpdateRelease>();
    return downloading!.future;
  }

  @override
  void cancel() => downloading?.completeError(Exception('update_canceled: x'));

  @override
  int progress() => downloaded;

  @override
  Future<void> install() async => installs++;

  @override
  Future<UpdatePrefsInfo> prefs() async =>
      UpdatePrefsInfo(channel: 'stable', autoDownload: false);

  @override
  Future<UpdatePrefsInfo> setPrefs(String channel, bool autoDownload) async {
    prefsSet.add((channel, autoDownload));
    return UpdatePrefsInfo(channel: channel, autoDownload: autoDownload);
  }

  @override
  Future<bool> autoAllowed() async => false;
}

void main() {
  late FakeUpdatesApi updates;
  late FakeEngine engine;
  late int closes;

  Future<void> pumpApp(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
          libraryApiProvider.overrideWithValue(FakeLibraryApi(const [])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(FakeIndexerApi()),
          healthApiProvider.overrideWithValue(FakeHealthApi()),
          getApiProvider.overrideWithValue(FakeGetApi()),
          updatesApiProvider.overrideWithValue(updates),
          appCloserProvider.overrideWithValue(() async => closes++),
          desktopShellProvider.overrideWithValue(true),
          settingsStoreProvider.overrideWithValue(
            FakeSettingsStore()..values['onboardingDone'] = true,
          ),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    updates = FakeUpdatesApi();
    engine = FakeEngine();
    closes = 0;
  });

  final page = sectionPath(SettingsSection.updates);

  testWidgets('a development build says updates are off', (tester) async {
    updates = FakeUpdatesApi(enabled: false);
    await pumpApp(tester, page);
    expect(
      find.text(
        'Version de développement : les mises à jour sont désactivées.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('found, downloaded, verified, then installed on a click', (
    tester,
  ) async {
    updates.available = release;
    await pumpApp(tester, page);
    await tester.tap(find.text('Rechercher une mise à jour'));
    await settle(tester);
    expect(find.text('Miarina 0.2.1 est disponible'), findsWidgets);
    expect(find.text('•  Lecteur plus rapide'), findsOneWidget);
    expect(find.textContaining('canal Stable'), findsOneWidget);

    await tester.tap(find.text('Télécharger · 80 Mio'));
    await settle(tester);
    expect(find.text('Téléchargement de 0.2.1…'), findsOneWidget);
    updates.downloaded = 40 * 1048576;
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(
      find.text('40 Mio / 80 Mio · vérification à la fin'),
      findsOneWidget,
    );

    updates.downloading!.complete(release);
    await settle(tester);
    expect(find.text('0.2.1 est prête'), findsOneWidget);
    expect(find.text('Signature et SHA-256 vérifiées'), findsOneWidget);
    expect(closes, 0, reason: 'never installs by itself');

    await tester.tap(find.text('Installer maintenant'));
    await settle(tester);
    expect((updates.installs, closes), (1, 1));
  });

  testWidgets('a cancel keeps the bytes; a network loss is explained', (
    tester,
  ) async {
    updates.available = release;
    await pumpApp(tester, page);
    await tester.tap(find.text('Rechercher une mise à jour'));
    await settle(tester);
    await tester.tap(find.text('Télécharger · 80 Mio'));
    await settle(tester);
    updates.downloaded = 30 * 1048576;
    await tester.tap(find.text('Annuler'));
    await settle(tester);
    expect(find.text('Reprendre le téléchargement'), findsOneWidget);
    expect(
      find.textContaining('30 Mio / 80 Mio déjà téléchargés'),
      findsOneWidget,
    );

    updates
      ..available = null
      ..checkError = Exception('update_network: timed out');
    await tester.tap(find.text('Reprendre le téléchargement'));
    await settle(tester);
    updates.downloading!.completeError(Exception('update_network: reset'));
    await settle(tester);
    expect(
      find.textContaining('Connexion au serveur de mises à jour perdue'),
      findsOneWidget,
    );
  });

  testWidgets('channel and automatic download are saved', (tester) async {
    await pumpApp(tester, page);
    await tester.tap(find.text('Stable'));
    await settle(tester);
    await tester.tap(find.text('Bêta').last);
    await settle(tester);
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(updates.prefsSet, [('beta', false), ('beta', true)]);
  });

  testWidgets('15 s after launch, an update found is announced', (
    tester,
  ) async {
    updates.available = release;
    await pumpApp(tester, Routes.listenHome);
    await tester.pump(const Duration(seconds: 16));
    await settle(tester);
    expect(find.text('Miarina 0.2.1 est disponible'), findsOneWidget);
    await tester.tap(find.text('Voir'));
    await settle(tester);
    expect(find.text('Installer maintenant'), findsNothing);
    expect(find.text('Télécharger · 80 Mio'), findsOneWidget);
  });
}
