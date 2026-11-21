import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/get/download_notifications.dart';
import 'package:miarina_media/features/get/get_data.dart';
import 'package:miarina_media/l10n/app_localizations.dart';

import 'support/fakes.dart';

const mb = 1024 * 1024;

void main() {
  final fr = lookupL10n(const Locale('fr'));
  final en = lookupL10n(const Locale('en'));

  DownloadTask task(
    String state, {
    int downloaded = 0,
    int? total,
    double speed = 0,
    int? eta,
  }) => DownloadTask(
    taskInfo('t1', 'Big Buck Bunny', state: state, total: total),
    downloaded: downloaded,
    total: total,
    bytesPerSec: speed,
    etaSecs: eta,
  );

  test('a running download: size, speed and time left, in each language', () {
    final t = task(
      'downloading',
      downloaded: 12 * mb,
      total: 25 * mb,
      speed: 1.25 * mb,
      eta: 90,
    );
    expect(describe(t, fr), contains(' sur '));
    expect(describe(t, fr), contains('1,3 Mo/s'));
    expect(describe(t, fr), endsWith('2 min restantes'));
    expect(describe(t, en), contains(' of '));
    expect(describe(t, en), contains('1.3 MB/s'));
    expect(describe(t, en), endsWith('2 min left'));
    expect(percentOf(t), 48);
  });

  test('waiting, reading formats, converting: words, unknown percent', () {
    expect(describe(task('queued'), fr), "En attente d'une place libre");
    expect(describe(task('analyzing'), en), 'Reading the formats…');
    final converting = task('processing', downloaded: 9, total: 9);
    expect(describe(converting, fr), 'Préparation du fichier…');
    expect(percentOf(converting), -1);
    expect(percentOf(task('downloading', downloaded: 5)), -1);
  });

  test('time left: under a minute, and over an hour', () {
    expect(
      describe(task('downloading', eta: 30), fr),
      endsWith('moins d\'une minute restante'),
    );
    expect(
      describe(task('downloading', eta: 3720), en),
      endsWith('1 h 2 min left'),
    );
  });

  test('what keeps the download service running', () {
    for (final s in [
      'queued',
      'analyzing',
      'waiting',
      'downloading',
      'processing',
    ]) {
      expect(isActive(s), isTrue, reason: s);
    }
    for (final s in ['paused', 'completed', 'failed', 'canceled']) {
      expect(isActive(s), isFalse, reason: s);
    }
  });
}
