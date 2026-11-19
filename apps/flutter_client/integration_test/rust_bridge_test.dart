import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miarina_media/src/rust/api/library.dart';
import 'package:miarina_media/src/rust/frb_generated.dart';

// Calls the shared Rust core (crates/storage) through flutter_rust_bridge.
// POC_WORK: a writable folder on the device. POC_DB (optional): a *copy* of
// an existing Miarina library database; never the live one, since opening it
// runs the migrations.
const _work = String.fromEnvironment('POC_WORK');
const _realCopy = String.fromEnvironment('POC_DB');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => RustLib.init());

  testWidgets('a fresh database is migrated, written and read back', (
    tester,
  ) async {
    final db = File('$_work/bridge-test.db');
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${db.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }

    final empty = await librarySummary(dbPath: db.path, limit: 10);
    expect(empty.total, BigInt.zero);
    expect(empty.schemaVersion, greaterThan(0));

    final id = await libraryAddFile(
      dbPath: db.path,
      path: '$_work/poc-media/test.flac',
      title: 'Test FLAC',
      isVideo: false,
      sizeBytes: BigInt.from(255396),
    );
    final s = await librarySummary(dbPath: db.path, limit: 10);
    expect(s.total, BigInt.one);
    expect(s.audioCount, BigInt.one);
    expect(s.items.single.id, id);
    expect(s.items.single.title, 'Test FLAC');
    expect(s.schemaVersion, empty.schemaVersion);
  });

  testWidgets('reads a copy of a real library', (tester) async {
    final s = await librarySummary(dbPath: _realCopy, limit: 5);
    // ignore: avoid_print
    print(
      'real library copy: schema v${s.schemaVersion}, ${s.total} items '
      '(${s.audioCount} audio, ${s.videoCount} video)',
    );
    expect(s.total, greaterThan(BigInt.zero));
    expect(s.items, isNotEmpty);
  }, skip: _realCopy.isEmpty);

  testWidgets('a broken database path is an error, not a crash', (
    tester,
  ) async {
    await expectLater(
      librarySummary(dbPath: '$_work/no-such-dir/x/y.db', limit: 1),
      throwsA(anything),
    );
  });
}
