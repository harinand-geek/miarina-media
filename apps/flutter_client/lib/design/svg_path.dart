import 'dart:ui';

/// Reads SVG path data (the `d` attribute) into a [Path]: M L H V C S Q T
/// A Z, absolute and relative, with the compact forms SVG minifiers write
/// ("-.5.5", "1e-3", arc flags without separators). Used for the brand
/// marks shipped with the app (Simple Icons, 24 × 24); not a full SVG
/// renderer.
Path parseSvgPath(String data) {
  final r = _Reader(data);
  final path = Path();
  var x = 0.0, y = 0.0; // current point
  var sx = 0.0, sy = 0.0; // start of the subpath
  // Last control point, for S and T (reflected), and which kind set it.
  var cx = 0.0, cy = 0.0;
  var last = '';
  String? command;
  while (true) {
    r.skipSeparators();
    if (r.done) break;
    if (r.atCommand) {
      command = r.next();
    } else if (command == null) {
      throw FormatException('path data must start with a command', data);
    }
    final c = command;
    final rel = c == c.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (c.toUpperCase()) {
      case 'M':
        x = ox + r.number();
        y = oy + r.number();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        // Further pairs are implicit line-tos.
        command = rel ? 'l' : 'L';
      case 'L':
        x = ox + r.number();
        y = oy + r.number();
        path.lineTo(x, y);
      case 'H':
        x = ox + r.number();
        path.lineTo(x, y);
      case 'V':
        y = oy + r.number();
        path.lineTo(x, y);
      case 'C':
        final x1 = ox + r.number(), y1 = oy + r.number();
        cx = ox + r.number();
        cy = oy + r.number();
        x = ox + r.number();
        y = oy + r.number();
        path.cubicTo(x1, y1, cx, cy, x, y);
      case 'S':
        final reflect = last == 'C' || last == 'S';
        final x1 = reflect ? 2 * x - cx : x, y1 = reflect ? 2 * y - cy : y;
        cx = ox + r.number();
        cy = oy + r.number();
        x = ox + r.number();
        y = oy + r.number();
        path.cubicTo(x1, y1, cx, cy, x, y);
      case 'Q':
        cx = ox + r.number();
        cy = oy + r.number();
        x = ox + r.number();
        y = oy + r.number();
        path.quadraticBezierTo(cx, cy, x, y);
      case 'T':
        final reflect = last == 'Q' || last == 'T';
        cx = reflect ? 2 * x - cx : x;
        cy = reflect ? 2 * y - cy : y;
        x = ox + r.number();
        y = oy + r.number();
        path.quadraticBezierTo(cx, cy, x, y);
      case 'A':
        final rx = r.number(), ry = r.number(), rotation = r.number();
        final large = r.flag(), sweep = r.flag();
        x = ox + r.number();
        y = oy + r.number();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        x = sx;
        y = sy;
      default:
        throw FormatException('unknown path command "$c"', data);
    }
    last = c.toUpperCase();
    // A close has no arguments: what follows must be a new command.
    if (last == 'Z') command = null;
  }
  return path;
}

class _Reader {
  _Reader(this.s);

  final String s;
  var i = 0;

  bool get done => i >= s.length;

  bool get atCommand {
    final ch = s.codeUnitAt(i);
    // Letters other than the exponent marker.
    return (ch >= 65 && ch <= 90 || ch >= 97 && ch <= 122) &&
        ch != 69 &&
        ch != 101;
  }

  String next() => s[i++];

  void skipSeparators() {
    while (!done) {
      final ch = s[i];
      if (ch == ' ' || ch == ',' || ch == '\n' || ch == '\r' || ch == '\t') {
        i++;
      } else {
        break;
      }
    }
  }

  /// An arc flag: a single 0 or 1, separators optional.
  bool flag() {
    skipSeparators();
    if (done) throw FormatException('missing arc flag', s, i);
    final ch = s[i++];
    if (ch != '0' && ch != '1') throw FormatException('bad arc flag', s, i);
    return ch == '1';
  }

  double number() {
    skipSeparators();
    final start = i;
    if (!done && (s[i] == '-' || s[i] == '+')) i++;
    var dot = false;
    while (!done) {
      final ch = s[i];
      if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        i++;
      } else if (ch == '.' && !dot) {
        dot = true;
        i++;
      } else {
        break;
      }
    }
    if (!done && (s[i] == 'e' || s[i] == 'E')) {
      i++;
      if (!done && (s[i] == '-' || s[i] == '+')) i++;
      while (!done && s[i].codeUnitAt(0) >= 48 && s[i].codeUnitAt(0) <= 57) {
        i++;
      }
    }
    final value = double.tryParse(s.substring(start, i));
    if (value == null) throw FormatException('expected a number', s, start);
    return value;
  }
}
