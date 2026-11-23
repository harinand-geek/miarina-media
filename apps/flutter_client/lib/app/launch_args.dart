import 'dart:io';

/// Files handed over by Windows ("Open with", file association, drag onto the
/// exe), and a link sent by the browser extension (`--link <url>`, from the
/// native host). Only existing regular files and web links are kept;
/// anything else is ignored.
class LaunchArgs {
  const LaunchArgs({this.media, this.subtitle, this.link});

  final String? media;
  final String? subtitle;

  /// A page or media link to analyze (never downloaded without the user).
  final String? link;

  static const _subtitleFlag = '--sub=';
  static const _linkFlag = '--link';

  /// http(s), no credentials, bounded (as the extension and its host check).
  static bool _webLink(String url) {
    final u = Uri.tryParse(url);
    return u != null &&
        url.length <= 2048 &&
        (u.scheme == 'http' || u.scheme == 'https') &&
        u.host.isNotEmpty &&
        u.userInfo.isEmpty;
  }

  factory LaunchArgs.parse(List<String> args, {bool Function(String)? exists}) {
    final isFile = exists ?? (p) => File(p).existsSync();
    String? media;
    String? subtitle;
    String? link;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == _linkFlag && i + 1 < args.length) {
        final url = args[++i];
        if (_webLink(url)) link = url;
      } else if (arg.startsWith(_subtitleFlag)) {
        final path = arg.substring(_subtitleFlag.length);
        if (isFile(path)) subtitle = path;
      } else if (!arg.startsWith('-') && media == null && isFile(arg)) {
        media = arg;
      }
    }
    return LaunchArgs(media: media, subtitle: subtitle, link: link);
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
