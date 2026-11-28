import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/playback/listen_months.dart';

void main() {
  final day = DateTime(2026, 11, 28, 20);

  test('adds time per month, day, artist and track; newest month first', () {
    final m = ListenMonths.empty
        .add(day, 120, artist: 'Stony', trackId: 1)
        .add(day, 60, artist: 'Stony', trackId: 2)
        .add(day.subtract(const Duration(days: 3)), 30, artist: 'Iony')
        .add(DateTime(2026, 10, 2), 10, trackId: 1);
    final nov = m['2026-11'];
    expect(nov.seconds, 210);
    expect(nov.days, {28: 180, 25: 30});
    expect(nov.activeDays, 2);
    expect(nov.bestDay!.key, 28);
    expect(nov.topArtists.first.key, 'Stony');
    expect(nov.topTracks.map((e) => e.key), [1, 2]);
    expect(m.keys, ['2026-11', '2026-10']);
    expect(m['2025-01'].seconds, 0);
    expect(ListenMonths.monthOf('2026-11'), DateTime(2026, 11));
  });

  test('kept 24 months, and survives being stored', () {
    var m = ListenMonths.empty;
    for (var i = 0; i < 30; i++) {
      m = m.add(DateTime(2024, 1 + i, 5), 10, artist: 'A', trackId: i);
    }
    expect(m.months.length, listenMonthsKept);
    expect(m.keys.last, '2024-07');
    final back = ListenMonths.parse(m.encode());
    expect(back.keys, m.keys);
    expect(back['2026-06'].tracks, {29: 10});
    expect(back['2026-06'].days, {5: 10});
    expect(ListenMonths.parse('{nope').months, isEmpty);
  });

  test('nothing heard changes nothing', () {
    expect(
      identical(ListenMonths.empty.add(day, 0), ListenMonths.empty),
      isTrue,
    );
  });
}
