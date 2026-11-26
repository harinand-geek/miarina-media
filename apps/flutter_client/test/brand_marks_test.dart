import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/design/brand_marks.dart';
import 'package:miarina_media/design/svg_path.dart';
import 'package:miarina_media/design/widgets/brand_badge.dart';
import 'package:miarina_media/features/browser/browser_data.dart'
    show startSites;

void main() {
  group('SVG path data', () {
    test('absolute and relative commands draw the same square', () {
      final a = parseSvgPath('M2 2H22V22H2Z').getBounds();
      final b = parseSvgPath('m2 2h20v20h-20z').getBounds();
      expect(a, const Rect.fromLTRB(2, 2, 22, 22));
      expect(b, a);
    });

    test('compact numbers: signs, leading dots, exponents', () {
      final p = parseSvgPath('M.5.5l1e1-0.5L-1-1z').getBounds();
      expect(p.left, -1);
      expect(p.right, 10.5);
      expect(p.top, -1);
    });

    test('arcs, with flags written without separators', () {
      // A half circle from (0,12) to (24,12) through the top.
      final p = parseSvgPath('M0 12a12 12 0 0124 0z').getBounds();
      expect(p.left, closeTo(0, 0.01));
      expect(p.right, closeTo(24, 0.01));
      expect(p.top, closeTo(0, 0.01));
      expect(p.bottom, closeTo(12, 0.01));
    });

    test('smooth curves reflect the previous control point', () {
      final p = parseSvgPath('M0 0C0 10 10 10 10 0S20-10 20 0').getBounds();
      expect(p.right, 20);
      expect(p.top, lessThan(0), reason: 'reflected below the line');
      expect(p.bottom, greaterThan(0));
    });

    test('bad data says so', () {
      expect(() => parseSvgPath('12 3'), throwsFormatException);
      expect(() => parseSvgPath('M1 1X'), throwsFormatException);
      expect(() => parseSvgPath('M0 0a1 1 0 21 1 1'), throwsFormatException);
    });
  });

  group('brand marks', () {
    test('every start site has its mark, drawn inside 24 × 24', () {
      for (final (name, url) in startSites) {
        final mark = brandMarkFor(url);
        expect(mark, isNotNull, reason: name);
        // Bounds include the curves' control points: a little margin.
        final box = parseSvgPath(mark!.path).getBounds();
        expect(box.left, greaterThanOrEqualTo(-0.5), reason: name);
        expect(box.top, greaterThanOrEqualTo(-0.5), reason: name);
        expect(box.right, lessThanOrEqualTo(24.5), reason: name);
        expect(box.bottom, lessThanOrEqualTo(24.5), reason: name);
        expect(box.width, greaterThan(10), reason: name);
      }
    });

    test('found by host and subdomain, not by look-alikes', () {
      expect(brandMarkFor('https://m.youtube.com/watch?v=x'), isNotNull);
      expect(brandMarkFor('https://youtu.be/x'), isNotNull);
      expect(
        brandMarkFor('https://www.youtube.com'),
        same(brandMarkFor('https://music.youtube.com')),
      );
      expect(brandMarkFor('https://notyoutube.com'), isNull);
      expect(brandMarkFor('https://youtube.com.evil.example'), isNull);
      expect(brandMarkFor('https://example.org'), isNull);
      expect(brandMarkFor('not a url'), isNull);
    });

    testWidgets('a badge paints without errors', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final (_, url) in startSites)
                BrandBadge(mark: brandMarkFor(url)!),
            ],
          ),
        ),
      );
      expect(find.byType(BrandBadge), findsNWidgets(startSites.length));
      expect(tester.takeException(), isNull);
    });
  });
}
