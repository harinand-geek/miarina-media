import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/playback/auto_library.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/l10n/app_localizations.dart';
import 'package:miarina_media/src/rust/api/library.dart';

import 'support/fakes.dart';

LibraryItem song(int id, {bool favorite = false, bool video = false}) =>
    LibraryItem(
      id: id,
      title: 'T${100 - id}',
      path: '/storage/music/t$id.mp3',
      isVideo: video,
      artist: id.isEven ? 'Stony' : null,
      missing: id == 9,
      favorite: favorite,
      plays: 0,
    );

void main() {
  test(
    'the car gets the mix, favourites, recent plays and all titles',
    () async {
      final store = FakePlaybackStore();
      final container = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          playbackStoreProvider.overrideWithValue(store),
          libraryApiProvider.overrideWithValue(
            FakeLibraryApi([
              for (var i = 1; i <= 40; i++) song(i, favorite: i <= 2),
              song(41, video: true),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      store.values[historyKey] = jsonEncode([
        PlayEntry(
          id: 5,
          title: 'T95',
          kind: 'audio',
          at: DateTime(2026, 11, 28),
        ).toJson(),
        PlayEntry(
          id: 7,
          title: 'T93',
          kind: 'audio',
          at: DateTime(2026, 11, 27),
        ).toJson(),
      ]);
      final json = await container.read(
        FutureProvider(
          (ref) => buildAutoLibrary(ref, lookupL10n(const Locale('fr'))),
        ).future,
      );
      final sections = (jsonDecode(json) as Map)['sections'] as List;
      Map<String, dynamic> section(String id) =>
          sections.firstWhere((s) => s['id'] == id) as Map<String, dynamic>;
      List<String> ids(String id) => [
        for (final i in section(id)['items'] as List) i['id'] as String,
      ];

      expect(section('mix')['title'], 'Mix du jour');
      expect(ids('mix').length, 30);
      expect(ids('favorites'), ['1', '2']);
      expect(ids('recent'), ['5', '7']);
      expect(section('all')['title'], 'Titres');
      expect(ids('all').length, 39, reason: 'no video, no missing file');
      expect(ids('all').first, '40', reason: 'by title: T60 first');
      final first = (section('all')['items'] as List).first as Map;
      expect(first['path'], '/storage/music/t40.mp3');
      expect(first['artist'], 'Stony');
    },
  );
}
