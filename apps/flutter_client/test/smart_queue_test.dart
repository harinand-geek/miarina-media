import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/now_playing/queue_view.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';

import 'support/fakes.dart';

void main() {
  test(
    'close tracks: same artist then album, never queued or missing',
    () async {
      final a = track(
        1,
        'Marée haute',
        artist: 'Nafy Rakoto',
        album: 'Rivages',
      );
      final b = track(2, 'Seuil', artist: 'Nafy Rakoto', album: 'Rivages');
      final c = track(3, 'Perdu', artist: 'Nafy Rakoto', missing: true);
      final d = track(4, 'Ville lente', artist: 'Iony', album: 'Rivages');
      final e = track(5, 'Échos', artist: 'Collectif Rova');
      final library = FakeLibraryApi([a, b, c, d, e]);
      final container = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(FakeEngine()),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          libraryApiProvider.overrideWithValue(library),
          presenceCheckProvider.overrideWithValue((_) async => true),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(smartQueueProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(queueProvider.notifier).playAll([queueEntryOf(a)]);
      final picks = await container.read(smartQueueProvider.future);
      expect(picks.map((i) => i.id).toSet(), {2, 4});

      // Added to the queue: no longer suggested.
      await container.read(queueProvider.notifier).enqueue([
        queueEntryOf(b),
      ], next: false);
      expect(
        (await container.read(smartQueueProvider.future)).map((i) => i.id),
        [4],
      );
    },
  );
}
