import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
import 'package:miarina_media/features/library/tag_editor.dart';
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

/// The core's tag editor in memory.
class FakeTagsApi implements TagsApi {
  FakeTagsApi(this.item, {this.writable = true});

  LibraryItem item;
  final bool writable;
  Object? saveError;
  final saves = <(TagFields, bool, String?)>[];
  final covers = <(String, String?)>[];

  @override
  Future<TagSheet> get(int id) async => TagSheet(
    fields: const TagFields(
      title: 'Track 05',
      artist: 'Nafy Rakoto',
      album: 'Saisons de sel',
      year: 2024,
    ),
    writable: writable,
    hasSourceCover: false,
  );

  @override
  Future<LibraryItem> save(
    int id,
    TagFields fields, {
    required bool writeToFile,
    String? renameTo,
  }) async {
    if (saveError != null) throw saveError!;
    saves.add((fields, writeToFile, renameTo));
    return LibraryItem(
      id: id,
      title: fields.title ?? item.title,
      path: item.path,
      isVideo: false,
      artist: fields.artist,
      album: fields.album,
      format: item.format,
      missing: false,
      favorite: false,
      plays: 0,
      durationSecs: item.durationSecs,
    );
  }

  @override
  Future<LibraryItem> cover(int id, String from, {String? image}) async {
    covers.add((from, image));
    return LibraryItem(
      id: item.id,
      title: item.title,
      path: item.path,
      isVideo: false,
      missing: false,
      favorite: false,
      plays: 0,
      thumbnail: from == 'none' ? null : 'C:/covers/5-1.jpg',
    );
  }
}

void main() {
  test('tags from a file name, as the Tauri app reads them', () {
    expect(tagsFromFileName(r'D:\M\05 - Nafy Rakoto - Marée haute.flac'), {
      'trackNo': '5',
      'artist': 'Nafy Rakoto',
      'title': 'Marée haute',
    });
    expect(tagsFromFileName('C:/M/Toky - Ny lanitra - live.mp3'), {
      'artist': 'Toky',
      'title': 'Ny lanitra - live',
    });
    expect(tagsFromFileName('C:/M/07 Seuil.mp3'), {'title': 'Seuil'});
    expect(tagsFromFileName('C:/M/Mena_demo.ogg'), {'title': 'Mena demo'});
  });

  final song = LibraryItem(
    id: 5,
    title: 'Track 05',
    path: r'D:\Musique\05 - Nafy Rakoto - Marée haute.flac',
    isVideo: false,
    durationSecs: 248,
    artist: 'Nafy Rakoto',
    album: 'Saisons de sel',
    format: 'FLAC 24/96',
    missing: false,
    favorite: false,
    plays: 0,
  );
  late FakeTagsApi tags;
  String? picked;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          libraryApiProvider.overrideWithValue(FakeLibraryApi([song])),
          cinemaApiProvider.overrideWithValue(FakeCinemaApi(const [])),
          focusApiProvider.overrideWithValue(FakeFocusApi()),
          indexerApiProvider.overrideWithValue(FakeIndexerApi()),
          healthApiProvider.overrideWithValue(FakeHealthApi()),
          getApiProvider.overrideWithValue(FakeGetApi()),
          tagsApiProvider.overrideWithValue(tags),
          coverImagePickerProvider.overrideWithValue((_) async => picked),
          desktopShellProvider.overrideWithValue(true),
          settingsStoreProvider.overrideWithValue(
            FakeSettingsStore()..values['onboardingDone'] = true,
          ),
          lyricsLoaderProvider.overrideWithValue((_) async => null),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          initialRouteProvider.overrideWithValue(Routes.tracks),
        ],
        child: const MiarinaApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text('Track 05'), buttons: kSecondaryButton);
    await settle(tester);
    await tester.tap(find.text('Modifier les tags'));
    await settle(tester);
  }

  setUp(() {
    tags = FakeTagsApi(song);
    picked = null;
  });

  testWidgets('fill from the name, rename, write into the file', (
    tester,
  ) async {
    await pumpApp(tester);
    await openEditor(tester);
    expect(find.text('Modifier les tags'), findsOneWidget);
    expect(find.text('FLAC'), findsOneWidget, reason: 'file type badge');

    await tester.tap(find.text('Remplir depuis le nom du fichier'));
    await settle(tester);
    expect(find.text('Marée haute'), findsOneWidget);
    await tester.tap(find.text('Renommer le fichier « Artiste - Titre »'));
    await settle(tester);
    expect(
      find.text('Le fichier sera renommé : Nafy Rakoto - Marée haute.flac'),
      findsOneWidget,
    );

    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    final (fields, toFile, rename) = tags.saves.single;
    expect(
      (fields.title, fields.trackNo, fields.year),
      ('Marée haute', 5, 2024),
    );
    expect((toFile, rename), (true, 'Nafy Rakoto - Marée haute'));
    expect(find.text('Tags écrits dans le fichier.'), findsOneWidget);
    expect(find.text('Marée haute'), findsOneWidget, reason: 'row updated');
  });

  testWidgets('a bad year blocks Save; Ctrl I opens; library only', (
    tester,
  ) async {
    tags = FakeTagsApi(song, writable: false);
    await pumpApp(tester);
    await tester.tap(find.text('Track 05'));
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(
      find.text(
        'Ce format garde ses tags dans la bibliothèque Miarina seulement.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('tag-year')), '20x4');
    await settle(tester);
    expect(find.text('Nombre entier attendu'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    expect(tags.saves, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('tag-year')), '2023');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    expect(tags.saves.single.$2, isFalse, reason: 'not writable');
    expect(
      find.text('Tags enregistrés dans la bibliothèque. Fichier inchangé.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed write says so and keeps the editor open', (
    tester,
  ) async {
    tags.saveError = Exception('tags_write');
    await pumpApp(tester);
    await openEditor(tester);
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    expect(
      find.text(
        'Les tags n’ont pas pu être écrits dans le fichier : rien n’a été enregistré.',
      ),
      findsOneWidget,
    );
    expect(find.text('Modifier les tags'), findsOneWidget);
  });

  testWidgets('a chosen picture becomes the cover at once', (tester) async {
    picked = r'C:\Users\Hery\Pictures\pochette.jpg';
    await pumpApp(tester);
    await openEditor(tester);
    await tester.tap(find.text('Choisir une image…'));
    await settle(tester);
    expect(tags.covers.single, ('image', picked));
    expect(find.text('Pochette mise à jour'), findsOneWidget);
    // Now it can be removed.
    await tester.tap(find.text('Retirer la pochette'));
    await settle(tester);
    expect(tags.covers.last.$1, 'none');
    expect(find.text('Pochette retirée'), findsOneWidget);
  });
}
