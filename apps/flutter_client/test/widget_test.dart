import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/engine/media_engine.dart';

void main() {
  group('PlaybackSnapshot.copyWith', () {
    test('keeps nullable fields unless explicitly cleared', () {
      const error = PlaybackError('codec');
      final s = const PlaybackSnapshot().copyWith(
        selectedSubtitle: '2',
        error: error,
      );

      expect(
        s.copyWith(position: const Duration(seconds: 3)).selectedSubtitle,
        '2',
      );
      expect(
        s.copyWith(position: const Duration(seconds: 3)).error,
        same(error),
      );
      expect(s.copyWith(selectedSubtitle: null).selectedSubtitle, isNull);
      expect(s.copyWith(error: null).error, isNull);
    });

    test('hasVideo requires a non-empty size', () {
      expect(const PlaybackSnapshot().hasVideo, isFalse);
      expect(
        const PlaybackSnapshot(videoSize: Size(1920, 1080)).hasVideo,
        isTrue,
      );
    });
  });

  group('TrackInfo.label', () {
    test('joins the known parts', () {
      expect(
        const TrackInfo(id: '1', title: 'Commentaires', language: 'fre').label,
        'Commentaires · fre',
      );
    });

    test('falls back to the id', () {
      expect(const TrackInfo(id: '3').label, 'Piste 3');
    });
  });

  test('MediaSource.file builds a file URI', () {
    final s = MediaSource.file(r'C:\Musique\titre.flac');
    expect(s.uri.isScheme('file'), isTrue);
    expect(s.uri.toFilePath(windows: true), r'C:\Musique\titre.flac');
  });
}
