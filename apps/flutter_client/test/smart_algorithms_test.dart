import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/smart_queue.dart';
import 'package:miarina_media/features/playback/taste.dart';
import 'package:miarina_media/src/rust/api/library.dart';

LibraryItem item(
  int id, {
  String? artist,
  String? album,
  String folder = '/music',
  bool favorite = false,
  bool video = false,
}) => LibraryItem(
  id: id,
  title: 'T$id',
  path: '$folder/t$id.mp3',
  isVideo: video,
  artist: artist,
  album: album,
  missing: false,
  favorite: favorite,
  plays: 0,
);

QueueEntry entry(int id, {String? artist, String? album}) => QueueEntry(
  source: MediaSource.file('/music/t$id.mp3', title: 'T$id'),
  title: 'T$id',
  subtitle: artist,
  album: album,
  libraryId: id,
);

void main() {
  final now = DateTime(2026, 11, 28, 12);

  group('taste', () {
    test('heard to the end gains, passed loses, and both fade', () {
      var t = Taste.empty.finished(1, now).finished(1, now).skipped(2, now);
      expect(t.score(1, now), 2);
      expect(t.score(2, now), -1);
      // Half as much after the half-life.
      expect(t.score(1, now.add(tasteHalfLife)), closeTo(1, 0.01));
      t = t.started(3, now);
      expect(t.lastPlayed(3), now);
      expect(t.score(3, now), 0);
    });

    test('heard one after the other: neighbours both ways', () {
      final t = Taste.empty
          .finished(1, now)
          .finished(2, now, after: 1)
          .finished(1, now, after: 2);
      expect(t.together(1, 2), 2);
      expect(t.together(2, 1), 2);
      expect(t.together(1, 3), 0);
    });

    test('survives being stored, and a broken store gives nothing', () {
      final t = Taste.empty
          .finished(5, now)
          .started(5, now)
          .finished(6, now, after: 5);
      final back = Taste.parse(t.encode());
      expect(back.score(5, now), closeTo(1, 0.001));
      expect(back.lastPlayed(5), now);
      expect(back.together(6, 5), 1);
      expect(Taste.parse('{oops').tracks, isEmpty);
      expect(Taste.parse(null).tracks, isEmpty);
    });

    test('scores stay bounded', () {
      var t = Taste.empty;
      for (var i = 0; i < 30; i++) {
        t = t.finished(1, now).skipped(2, now);
      }
      expect(t.score(1, now), 10);
      expect(t.score(2, now), -5);
    });
  });

  group('smart shuffle', () {
    test('starts with the chosen one and keeps every entry once', () {
      final entries = [for (var i = 0; i < 20; i++) entry(i, artist: 'A$i')];
      final order = smartShuffleOrder(
        entries,
        first: 7,
        taste: Taste.empty,
        random: math.Random(1),
        now: now,
      );
      expect(order.first, 7);
      expect(order.toSet(), {for (var i = 0; i < 20; i++) i});
      expect(order.length, 20);
    });

    test('never the same artist twice in a row when it can be helped', () {
      // Ten of one artist, ten of others.
      final entries = [
        for (var i = 0; i < 10; i++) entry(i, artist: 'Stony'),
        for (var i = 10; i < 20; i++) entry(i, artist: 'A$i'),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final order = smartShuffleOrder(
          entries,
          first: 0,
          taste: Taste.empty,
          random: math.Random(seed),
          now: now,
        );
        for (var i = 1; i < order.length; i++) {
          expect(
            entries[order[i]].subtitle == 'Stony' &&
                entries[order[i - 1]].subtitle == 'Stony',
            isFalse,
            reason: 'seed $seed at $i: $order',
          );
        }
      }
    });

    test('liked tracks come sooner, often passed ones later', () {
      var taste = Taste.empty;
      for (var i = 0; i < 4; i++) {
        taste = taste.finished(1, now).skipped(2, now);
      }
      final entries = [for (var i = 0; i < 12; i++) entry(i, artist: 'A$i')];
      var liked = 0, passed = 0;
      for (var seed = 0; seed < 300; seed++) {
        final order = smartShuffleOrder(
          entries,
          first: 0,
          taste: taste,
          random: math.Random(seed),
          now: now,
        );
        liked += order.indexOf(1);
        passed += order.indexOf(2);
      }
      expect(liked / 300, lessThan(4.5));
      expect(passed / 300, greaterThan(7));
    });
  });

  group('radio', () {
    final library = [
      for (var i = 1; i <= 5; i++) item(i, artist: 'Stony', album: 'S'),
      for (var i = 6; i <= 30; i++) item(i, artist: 'Other $i'),
      item(31, artist: 'Stony', video: true),
    ];

    test('close tracks first: the same artist leads the radio', () {
      var sameArtist = 0;
      for (var seed = 0; seed < 50; seed++) {
        final picks = radioPicks(
          seeds: [TrackKey.ofItem(library.first)],
          library: library,
          taste: Taste.empty,
          random: math.Random(seed),
          now: now,
          exclude: {1},
          count: 8,
        );
        expect(picks.map((i) => i.id), isNot(contains(1)));
        expect(picks.map((i) => i.id), isNot(contains(31)), reason: 'video');
        expect(picks.length, 8);
        sameArtist += picks.where((i) => i.artist == 'Stony').length;
      }
      // 4 of 29 candidates are Stony's: far more than chance (≈ 1.1 of 8).
      expect(sameArtist / 50, greaterThan(2.5));
    });

    test('tracks heard together come along', () {
      var taste = Taste.empty;
      for (var i = 0; i < 3; i++) {
        taste = taste.finished(1, now).finished(20, now, after: 1);
      }
      var found = 0;
      for (var seed = 0; seed < 50; seed++) {
        final picks = radioPicks(
          seeds: [TrackKey.ofItem(library.first)],
          library: library,
          taste: taste,
          random: math.Random(seed),
          now: now,
          exclude: {1},
          count: 5,
        );
        if (picks.any((i) => i.id == 20)) found++;
      }
      expect(found, greaterThan(25));
    });

    test('at most two of one artist in a row', () {
      final picks = radioPicks(
        seeds: [TrackKey.ofItem(library.first)],
        library: library,
        taste: Taste.empty,
        random: math.Random(3),
        now: now,
        exclude: {1},
        count: 20,
      );
      for (var i = 2; i < picks.length; i++) {
        expect(
          picks[i].artist == picks[i - 1].artist &&
              picks[i].artist == picks[i - 2].artist,
          isFalse,
        );
      }
    });

    test('nothing to offer: empty', () {
      expect(
        radioPicks(
          seeds: const [],
          library: [library.last],
          taste: Taste.empty,
          random: math.Random(1),
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('daily mix', () {
    LibraryItem played(int id, {int plays = 0, bool favorite = false}) =>
        LibraryItem(
          id: id,
          title: 'T$id',
          path: '/m/a$id/t$id.mp3',
          isVideo: false,
          artist: 'A${id % 12}',
          missing: false,
          favorite: favorite,
          plays: plays,
        );

    test('thirty different tracks, the loved ones far more often', () {
      final library = [for (var i = 1; i <= 120; i++) played(i)];
      var taste = Taste.empty;
      for (final id in [1, 2, 3, 4, 5]) {
        for (var k = 0; k < 4; k++) {
          taste = taste.finished(id, now.subtract(const Duration(days: 2)));
        }
      }
      var loved = 0;
      for (var seed = 0; seed < 40; seed++) {
        final mix = dailyMixPicks(
          library: library,
          taste: taste,
          recentIds: const [],
          random: math.Random(seed),
          now: now,
        );
        expect(mix.length, 30);
        expect(mix.map((i) => i.id).toSet().length, 30);
        loved += mix.where((i) => i.id <= 5).length;
      }
      // By chance: 5 × 30 / 120 = 1.25 per mix.
      expect(loved / 40, greaterThan(2.5));
    });

    test('forgotten favourites come back; the ones heard lately wait', () {
      final library = [
        for (var i = 1; i <= 100; i++) played(i),
        played(200, favorite: true),
        played(201, plays: 9),
      ];
      final taste = Taste.empty
          .started(200, now.subtract(const Duration(days: 90)))
          .started(201, now.subtract(const Duration(days: 2)));
      var forgotten = 0, recent = 0;
      for (var seed = 0; seed < 40; seed++) {
        final ids = dailyMixPicks(
          library: library,
          taste: taste,
          recentIds: const [201],
          random: math.Random(seed),
          now: now,
        ).map((i) => i.id);
        if (ids.contains(200)) forgotten++;
        if (ids.contains(201)) recent++;
      }
      expect(forgotten, 40, reason: 'among the forgotten, always taken');
      expect(recent, lessThan(forgotten));
    });

    test('close to what was heard lately', () {
      final library = [for (var i = 1; i <= 100; i++) played(i)];
      var close = 0;
      for (var seed = 0; seed < 40; seed++) {
        final mix = dailyMixPicks(
          library: library,
          taste: Taste.empty,
          recentIds: const [12],
          random: math.Random(seed),
          now: now,
        );
        // Artist A0: ids 12, 24, 36… (8 others out of 99).
        close += mix.where((i) => i.artist == 'A0' && i.id != 12).length;
      }
      expect(close / 40, greaterThan(4));
    });

    test('an empty library gives nothing', () {
      expect(
        dailyMixPicks(
          library: const [],
          taste: Taste.empty,
          recentIds: const [],
          random: math.Random(1),
          now: now,
        ),
        isEmpty,
      );
    });
  });
}
