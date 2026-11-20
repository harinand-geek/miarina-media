import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/launch_args.dart' show looksLikeVideo;
import '../../design/mm_icons.g.dart';
import '../../design/widgets/states.dart';
import '../../engine/media_engine.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/cinema_data.dart';
import '../focus/focus_data.dart';
import '../home/home_data.dart';
import '../library/groups.dart';
import '../library/library_data.dart';
import '../playback/playback.dart';
import 'open_media.dart';

/// Media files the library indexes (crates/library/src/files.rs).
const mediaExtensions = [
  'mp3',
  'm4a',
  'flac',
  'ogg',
  'oga',
  'opus',
  'wav',
  'aac',
  'weba',
  'mp4',
  'm4v',
  'webm',
  'mkv',
  'mov',
  'avi',
  'ogv',
];

/// Every screen built on the library reads it again.
void refreshLibrary(WidgetRef ref) {
  ref
    ..invalidate(libraryStatsProvider)
    ..invalidate(groupsProvider)
    ..invalidate(cinemaLibraryProvider)
    ..invalidate(focusLibraryProvider)
    ..invalidate(homeProvider);
}

/// "Ouvrir des fichiers…": adds the chosen files to the library and plays
/// the first one. Returns how many were added.
Future<int> openFilesIntoLibrary(BuildContext context, WidgetRef ref) async {
  final t = L10n.of(context);
  final files = await openFiles(
    acceptedTypeGroups: [
      XTypeGroup(label: t.mediaFiles, extensions: mediaExtensions),
    ],
  );
  if (files.isEmpty) return 0;
  final api = ref.read(libraryApiProvider);
  final ids = <int>[];
  for (final f in files.take(500)) {
    ids.add(await api.addFile(f.path, isVideo: looksLikeVideo(f.path)));
  }
  refreshLibrary(ref);
  final first = await api.item(ids.first);
  if (first != null && context.mounted) await openMedia(context, ref, first);
  return ids.length;
}

/// W-E1 for the library screens: their own title and explanation, the
/// formats read, "Open files…", and the link with the Get space.
class LibraryEmpty extends ConsumerWidget {
  const LibraryEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.onAdded,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    return EmptyState(
      icon: icon,
      title: title,
      body: '$body\n${t.emptyFormats}',
      actions: [
        StateAction(
          t.emptyOpenFiles,
          () async {
            final n = await openFilesIntoLibrary(context, ref);
            if (n > 0) onAdded?.call();
          },
          primary: true,
          icon: PhosphorRegular.folderOpen,
        ),
      ],
      note: t.emptyNote,
    );
  }
}

/// W-E3 for a library that does not open.
class LibraryErrorView extends StatelessWidget {
  const LibraryErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final text = '$error';
    final broken = RegExp(
      'malformed|corrupt|not a database|disk image',
      caseSensitive: false,
    ).hasMatch(text);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ErrorCard(
            title: broken ? t.errLibraryRepairTitle : t.errLibraryTitle,
            body: broken ? t.errLibraryRepairBody : t.errLibraryBody,
            details: text,
            copyLabel: t.copyDetails,
            copiedLabel: t.detailsCopied,
            actions: [
              if (onRetry != null) StateAction(t.retry, onRetry, primary: true),
            ],
          ),
        ),
      ),
    );
  }
}

enum PlaybackProblem { format, damaged, access, missing, other }

/// Sorts an engine message (libmpv, Media3) into the cases of W-E3.
PlaybackProblem classifyPlayback(String message) {
  final m = message.toLowerCase();
  bool any(List<String> words) => words.any(m.contains);
  if (any([
    'no such file',
    'not found',
    'filenotfound',
    'source error: file',
  ])) {
    return PlaybackProblem.missing;
  }
  if (any(['denied', 'permission', 'eacces'])) return PlaybackProblem.access;
  if (any([
    'codec',
    'decoder',
    'unsupported',
    'not supported',
    'unrecognized',
    'failed to recognize',
  ])) {
    return PlaybackProblem.format;
  }
  if (any([
    'demux',
    'invalid data',
    'corrupt',
    'truncated',
    'malformed',
    'parser',
  ])) {
    return PlaybackProblem.damaged;
  }
  return PlaybackProblem.other;
}

/// W-E3 for a file that does not play: what happened, that the file is
/// kept, skip to the next one, details to copy.
class PlaybackErrorView extends ConsumerWidget {
  const PlaybackErrorView({super.key, required this.error});

  final PlaybackError error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final (title, body) = switch (classifyPlayback(error.message)) {
      PlaybackProblem.format => (t.errFormatTitle, t.errFormatBody),
      PlaybackProblem.damaged => (t.errDamagedTitle, t.errDamagedBody),
      PlaybackProblem.access => (t.errAccessTitle, t.errAccessBody),
      PlaybackProblem.missing => (t.errMissingTitle, t.errMissingBody),
      PlaybackProblem.other => (t.errPlaybackTitle, t.errPlaybackBody),
    };
    final queue = ref.watch(queueProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ErrorCard(
        title: title,
        body: body,
        details: [
          if (queue.current?.source.uri case final uri?)
            uri.isScheme('file') ? uri.toFilePath() : '$uri',
          error.message,
        ].join('\n'),
        copyLabel: t.copyDetails,
        copiedLabel: t.detailsCopied,
        actions: [
          if (queue.hasNext)
            StateAction(
              t.skipNext,
              () => ref.read(queueProvider.notifier).next(),
              primary: true,
            ),
        ],
      ),
    );
  }
}

/// The error card of W-E3 when the current file stopped with an error;
/// nothing otherwise. Placed by the players.
class PlaybackErrorOverlay extends ConsumerWidget {
  const PlaybackErrorOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = currentSnapshot(ref);
    final error = snap.error;
    if (snap.status != PlaybackStatus.error || error == null) {
      return const SizedBox.shrink();
    }
    return PlaybackErrorView(error: error);
  }
}
