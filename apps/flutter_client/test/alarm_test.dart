import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/alarm/alarm_data.dart';
import 'package:miarina_media/features/library/library_data.dart';
import 'package:miarina_media/features/playback/playback.dart';
import 'package:miarina_media/features/playback/playback_memory.dart';
import 'package:miarina_media/features/playback/settings_store.dart';
import 'package:miarina_media/src/rust/api/library.dart';

import 'support/fakes.dart';

class FakeAlarm implements AlarmApi {
  DateTime? scheduled;
  bool launch = false;
  bool exact = true;
  int released = 0;
  final _fired = StreamController<void>.broadcast();

  void fire() => _fired.add(null);

  @override
  Future<bool> schedule(DateTime at) async {
    scheduled = at;
    return exact;
  }

  @override
  Future<void> cancel() async => scheduled = null;

  @override
  Future<bool> canExact() async => exact;

  @override
  Future<void> requestExact() async {}

  @override
  Future<bool> takeLaunch() async {
    final l = launch;
    launch = false;
    return l;
  }

  @override
  Stream<void> get fired => _fired.stream;

  @override
  Future<void> release() async => released++;

  @override
  bool get ringsWhenClosed => true;
}

LibraryItem song(int id, {bool favorite = false}) => LibraryItem(
  id: id,
  title: 'T$id',
  path: 'C:/m/t$id.mp3',
  isVideo: false,
  artist: 'A${id % 4}',
  missing: false,
  favorite: favorite,
  plays: 0,
);

void main() {
  group('next time', () {
    final wed = DateTime(2026, 11, 25, 6, 30); // a Wednesday
    const s = AlarmSettings(enabled: true, hour: 7, minute: 15);

    test('once: today if still ahead, else tomorrow', () {
      expect(nextAlarm(s, wed), DateTime(2026, 11, 25, 7, 15));
      expect(
        nextAlarm(s, DateTime(2026, 11, 25, 7, 15)),
        DateTime(2026, 11, 26, 7, 15),
      );
    });

    test('chosen days only; off: none', () {
      final weekend = s.copyWith(days: {DateTime.saturday, DateTime.sunday});
      expect(nextAlarm(weekend, wed), DateTime(2026, 11, 28, 7, 15));
      final monday = s.copyWith(days: {DateTime.monday});
      expect(nextAlarm(monday, wed), DateTime(2026, 11, 30, 7, 15));
      expect(nextAlarm(s.copyWith(enabled: false), wed), isNull);
    });

    test('settings survive being stored; bad values are bounded', () {
      final back = AlarmSettings.fromJson(
        s.copyWith(days: {1, 5}, source: AlarmSource.favorites).toJson(),
      );
      expect(back.days, {1, 5});
      expect(back.source, AlarmSource.favorites);
      expect(back.hour, 7);
      final bad = AlarmSettings.fromJson({
        'hour': 40,
        'volume': 9,
        'days': [0, 3],
      });
      expect(bad.hour, 23);
      expect(bad.volume, 1);
      expect(bad.days, {3});
    });
  });

  group('ringing', () {
    late FakeEngine engine;
    late FakeAlarm alarm;
    late FakeSettingsStore settings;
    late ProviderContainer container;
    AlarmController ctl() => container.read(alarmProvider.notifier);
    AlarmState state() => container.read(alarmProvider);

    Future<void> start() async {
      container = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
          playbackStoreProvider.overrideWithValue(FakePlaybackStore()),
          settingsStoreProvider.overrideWithValue(settings),
          libraryApiProvider.overrideWithValue(
            FakeLibraryApi([
              for (var i = 1; i <= 40; i++) song(i, favorite: i <= 3),
            ]),
          ),
          presenceCheckProvider.overrideWithValue((_) async => true),
          alarmApiProvider.overrideWithValue(alarm),
        ],
      );
      container.listen(alarmProvider, (_, _) {});
      await ctl().ready();
    }

    setUp(() {
      engine = FakeEngine();
      alarm = FakeAlarm();
      settings = FakeSettingsStore();
    });
    tearDown(() => container.dispose());

    test('saved: set in the system, kept for the next launch', () async {
      await start();
      await ctl().save(const AlarmSettings(enabled: true, hour: 6));
      expect(alarm.scheduled, state().next);
      expect(alarm.scheduled!.hour, 6);
      await ctl().save(state().settings.copyWith(enabled: false));
      expect(alarm.scheduled, isNull);
      expect(state().next, isNull);
      expect(AlarmSettings.fromJson(settings.values['alarm']).hour, 6);
    });

    test('rings: the favourites play, low first; once turns it off', () {
      return Future(() async {
        await start();
        await ctl().save(
          const AlarmSettings(enabled: true, source: AlarmSource.favorites),
        );
        alarm.fire();
        await pumpEventQueue();
        expect(state().ringing, isTrue);
        final ids = [
          for (final e in container.read(queueProvider).entries) e.libraryId,
        ];
        expect(ids.toSet(), {1, 2, 3});
        expect(engine.current.volume, lessThan(0.2), reason: 'gradual');
        expect(state().settings.enabled, isFalse, reason: 'once');
        expect(alarm.scheduled, isNull);

        await ctl().stop();
        expect(engine.current.isPlaying, isFalse);
        expect(engine.current.volume, 1);
        expect(alarm.released, 1);
        expect(state().ringing, isFalse);
      });
    });

    test('snooze: silence, then again in ten minutes', () async {
      await start();
      await ctl().save(
        const AlarmSettings(enabled: true, days: {1, 2, 3, 4, 5, 6, 7}),
      );
      alarm.fire();
      await pumpEventQueue();
      final before = DateTime.now();
      await ctl().snooze();
      expect(state().ringing, isFalse);
      final at = alarm.scheduled!;
      expect(at.difference(before).inMinutes, inInclusiveRange(9, 10));
      expect(state().settings.enabled, isTrue, reason: 'repeating');
    });

    test('opened by the alarm: it rings at launch', () async {
      settings.values['alarm'] = const AlarmSettings(
        enabled: true,
        days: {1, 2, 3, 4, 5, 6, 7},
      ).toJson();
      alarm.launch = true;
      await start();
      await pumpEventQueue();
      expect(state().ringing, isTrue);
      expect(container.read(queueProvider).entries, isNotEmpty);
      expect(alarm.scheduled, isNotNull, reason: 'the next day set again');
      await ctl().stop();
    });

    test('exact alarms refused: said so', () async {
      alarm.exact = false;
      await start();
      await ctl().save(const AlarmSettings(enabled: true));
      expect(state().exactAllowed, isFalse);
    });
  });
}
