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

/// Display title for a file without tags: its name without the extension.
String fileTitle(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  final name = cut < 0 ? path : path.substring(cut + 1);
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

const _videoExtensions = {
  'mkv',
  'mp4',
  'm4v',
  'mov',
  'avi',
  'webm',
  'wmv',
  'ts',
  'm2ts',
  'mpg',
  'mpeg',
  'ogv',
  '3gp',
};

/// Whether a file not in the library is a video, from its extension.
bool looksLikeVideo(String path) {
  final dot = path.lastIndexOf('.');
  return dot > 0 &&
      _videoExtensions.contains(path.substring(dot + 1).toLowerCase());
}
