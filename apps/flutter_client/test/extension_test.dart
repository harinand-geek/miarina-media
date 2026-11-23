import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:miarina_media/app/app.dart';
import 'package:miarina_media/app/launch_args.dart';
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
import 'package:miarina_media/features/settings/extension_settings.dart';

import 'support/fakes.dart';

// Settings › Extension navigateur (EXT-01) and links sent by the extension.

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class FakeExtensionApi implements ExtensionApi {
  FakeExtensionApi({this.bridge = true});

  final bool bridge;
  bool connected = false;
  final calls = <String>[];
  bool answers = true;

  ExtensionStatus _status() => ExtensionStatus(
    bridge: bridge,
    chrome: connected,
    edge: connected,
    other: false,
    folder: bridge ? r'C:\Miarina Media\browser-extension' : null,
  );

  @override
  ExtensionStatus status(String dataDir) => _status();

  @override
  ExtensionStatus setEnabled(String dataDir, bool enabled) {
    calls.add('enabled $enabled in $dataDir');
    connected = enabled;
    return _status();
  }

  @override
  Future<bool> test(String dataDir) async {
    calls.add('test');
    return answers;
  }
}

void main() {
  test('a link from the extension is kept; anything else is not', () {
    expect(
      LaunchArgs.parse(['--link', 'https://web.facebook.com/reel/1']).link,
      'https://web.facebook.com/reel/1',
    );
    for (final bad in [
      'file:///C:/secret.txt',
      'https://user:pass@example.com/',
      'javascript:alert(1)',
      'https://example.com/${'a' * 2100}',
    ]) {
      expect(LaunchArgs.parse(['--link', bad]).link, isNull, reason: bad);
    }
    // The link is not taken for a file, nor the flag alone.
    final both = LaunchArgs.parse([
      '--link',
      'https://example.com/v',
    ], exists: (_) => true);
    expect(both.media, isNull);
    expect(LaunchArgs.parse(['--link']).link, isNull);
  });

  group('in Settings', () {
    late FakeExtensionApi api;

    Future<void> pumpApp(WidgetTester tester, {String? start}) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaEngineProvider.overrideWithValue(FakeEngine()),
            libraryApiProvider.overrideWithValue(FakeLibraryApi(const [])),
            cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
            focusApiProvider.overrideWithValue(FakeFocusApi()),
            indexerApiProvider.overrideWithValue(FakeIndexerApi()),
            healthApiProvider.overrideWithValue(FakeHealthApi()),
            getApiProvider.overrideWithValue(FakeGetApi()),
            extensionApiProvider.overrideWithValue(api),
            dataDirProvider.overrideWith((_) async => r'C:\data'),
            desktopShellProvider.overrideWithValue(true),
            settingsStoreProvider.overrideWithValue(
              FakeSettingsStore()..values['onboardingDone'] = true,
            ),
            lyricsLoaderProvider.overrideWithValue((_) async => null),
            playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
            initialRouteProvider.overrideWithValue(
              start ?? '${Routes.settings}/extension',
            ),
          ],
          child: const MiarinaApp(),
        ),
      );
      await settle(tester);
    }

    testWidgets('connect, test, then the hint in Obtenir; disconnect', (
      tester,
    ) async {
      api = FakeExtensionApi();
      await pumpApp(tester);
      expect(find.text('Extension navigateur'), findsWidgets);
      expect(
        find.text('Accepter les liens envoyés par l’extension'),
        findsWidgets,
      );
      expect(find.text('Rien n’est capturé automatiquement.'), findsOneWidget);
      expect(find.text('Pas encore testée.'), findsOneWidget);

      await tester.tap(find.text('Connecter'));
      await settle(tester);
      expect(api.calls, [r'enabled true in C:\data']);
      expect(find.text('Chrome et Edge sont connectés.'), findsOneWidget);

      await tester.tap(find.text('Tester'));
      await settle(tester);
      expect(api.calls.last, 'test');
      expect(find.textContaining('Dernier test : réussi à'), findsOneWidget);

      await tester.tap(find.text('Déconnecter'));
      await settle(tester);
      expect(api.calls.last, r'enabled false in C:\data');
      expect(find.text('Connecter'), findsOneWidget);
    });

    testWidgets('Obtenir mentions the extension once connected', (
      tester,
    ) async {
      api = FakeExtensionApi()..connected = true;
      await pumpApp(tester, start: Routes.get);
      expect(
        find.text('Ou envoyez-le depuis l’extension Chrome/Edge'),
        findsOneWidget,
      );
    });

    testWidgets('a build without the bridge says so and cannot connect', (
      tester,
    ) async {
      api = FakeExtensionApi(bridge: false);
      await pumpApp(tester);
      expect(
        find.text(
          'Cette version de Miarina Media n’inclut pas le pont du navigateur.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Connecter'));
      await settle(tester);
      expect(api.calls, isEmpty);
    });
  });
}
