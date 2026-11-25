import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/playback/listen_journal.dart';

// Listening journal of the phone home (decision 0010).

void main() {
  final monday = DateTime(2026, 11, 23, 21, 30);

  test('adds seconds per day and per artist, survives a round trip', () {
    var j = ListenJournal.empty
        .add(monday, 120, artist: 'Hanta')
        .add(monday, 60, artist: 'Toky')
        .add(monday, 30)
        .add(monday.add(const Duration(days: 1)), 200, artist: 'Toky');
    j = ListenJournal.parse(j.encode());
    expect(j.days['2026-11-23']!.seconds, 210);
    expect(j.days['2026-11-23']!.artists, {'Hanta': 120, 'Toky': 60});
    expect(j.days['2026-11-24']!.seconds, 200);
  });

  test('seven days, oldest first, empty days at zero; top artist', () {
    final j = ListenJournal.empty
        .add(monday, 120, artist: 'Hanta')
        .add(monday.add(const Duration(days: 2)), 300, artist: 'Toky')
        .add(monday.subtract(const Duration(days: 9)), 999, artist: 'Old');
    final days = j.lastDays(DateTime(2026, 11, 25, 8));
    expect(days.length, 7);
    expect(days.first.$1, DateTime(2026, 11, 19));
    expect(days.last.$1, DateTime(2026, 11, 25));
    expect([for (final d in days) d.$2], [0, 0, 0, 0, 120, 0, 300]);
    expect(j.topArtist(DateTime(2026, 11, 25)), ('Toky', 300));
  });

  test('forgets days beyond 35, ignores junk', () {
    final old = DateTime(2026, 10, 1);
    final j = ListenJournal.empty
        .add(old, 50)
        .add(old.add(const Duration(days: 40)), 10);
    expect(j.days.keys, ['2026-11-10']);
    expect(ListenJournal.parse('not json').days, isEmpty);
    expect(
      ListenJournal.parse('{"x": 3, "2026-11-01": {"s": -4}}').days,
      isEmpty,
    );
  });
}
