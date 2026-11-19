import 'dart:io';

/// Files handed over by Windows ("Open with", file association, drag onto the
/// exe). Only existing regular files are kept; anything else is ignored.
class LaunchArgs {
  const LaunchArgs({this.media, this.subtitle});

  final String? media;
  final String? subtitle;

  static const _subtitleFlag = '--sub=';

  factory LaunchArgs.parse(List<String> args, {bool Function(String)? exists}) {
    final isFile = exists ?? (p) => File(p).existsSync();
    String? media;
    String? subtitle;
    for (final arg in args) {
      if (arg.startsWith(_subtitleFlag)) {
        final path = arg.substring(_subtitleFlag.length);
        if (isFile(path)) subtitle = path;
      } else if (!arg.startsWith('-') && media == null && isFile(arg)) {
        media = arg;
      }
    }
    return LaunchArgs(media: media, subtitle: subtitle);
  }
}
