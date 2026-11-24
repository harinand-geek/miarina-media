import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/features/library/library_data.dart';

// B1: the stable Android app goes on with the 0.1.x database.

void main() {
  const files = '/data/user/0/org.miarina.media/files';

  test('the 0.1.x database is used where it is', () {
    final dir = androidDataDir(
      files,
      (p) => p == '/data/user/0/org.miarina.media/miarina.db',
    );
    expect(dir, '/data/user/0/org.miarina.media');
  });

  test('a fresh install, or once our own exists, uses files', () {
    expect(androidDataDir(files, (_) => false), files);
    expect(androidDataDir(files, (_) => true), files);
    // The separate beta never had 0.1.x data.
    const beta = '/data/user/0/org.miarina.media.beta/files';
    expect(androidDataDir(beta, (p) => p.endsWith('/files/miarina.db')), beta);
  });
}
