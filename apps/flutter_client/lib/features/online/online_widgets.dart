import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/states.dart';
import '../../design/widgets/track_bar.dart' show formatClock;
import '../../l10n/app_localizations.dart';
import '../playback/playback.dart' show queueProvider;
import 'online_data.dart';
import '../../src/rust/api/library.dart' show LibraryItem;
import 'online_obtain.dart';
import 'online_playback.dart';

/// One online result, in the style of the Titres rows: picture, title,
/// channel, duration, then Obtenir (or « Hors connexion » once
/// obtained). A tap plays [tracks] from this one, the others following;
/// obtained ones play from their file.
class OnlineTile extends ConsumerWidget {
  const OnlineTile({
    super.key,
    required this.track,
    this.tracks = const [],
    this.local = const {},
    this.onPlay,
  });

  final OnlineTrack track;

  /// The list the result belongs to: it becomes the queue.
  final List<OnlineTrack> tracks;

  /// The results already obtained, by video id.
  final Map<String, LibraryItem> local;

  /// Called before playing (the En ligne page remembers its search).
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final tr = track;
    final picture = tr.thumbnail == null
        ? null
        : ref.watch(onlineThumbnailProvider(tr.thumbnail!)).value;
    final obtained = local[tr.videoId];
    final playing = ref.watch(
      queueProvider.select(
        (q) =>
            q.current?.onlineId == tr.videoId ||
            (obtained != null && q.current?.libraryId == obtained.id),
      ),
    );
    final list = tracks.isEmpty ? [tr] : tracks;
    return Pressable(
      onTap: () {
        onPlay?.call();
        final i = list.indexWhere((x) => x.videoId == tr.videoId);
        playOnline(
          ref,
          list,
          i < 0 ? 0 : i,
          unknownArtist: t.unknownArtist,
          local: local,
        );
      },
      semanticLabel: tr.title,
      borderRadius: BorderRadius.circular(MmRadius.md),
      hoverColor: c.cardHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            CoverArt(
              size: 40,
              radius: MmRadius.sm,
              shadow: false,
              seed: tr.videoId.hashCode,
              imagePath: picture,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.labelStrong.copyWith(
                      color: playing ? c.coralHover : c.fg,
                    ),
                  ),
                  Text(
                    tr.channel ?? t.unknownArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.caption.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatClock(
                Duration(milliseconds: (tr.durationSecs * 1000).round()),
              ),
              style: MmType.monoStyle(size: 11.5, color: c.muted),
            ),
            const SizedBox(width: 4),
            OnlineObtainButton(track: tr, local: obtained, picture: picture),
          ],
        ),
      ),
    );
  }
}

/// One result as a card of the En ligne page's grids: the clip's picture
/// in 16:9 with its duration, the title on two lines, the channel. A tap
/// plays [tracks] from this one.
class OnlineCard extends ConsumerWidget {
  const OnlineCard({
    super.key,
    required this.track,
    required this.width,
    this.tracks = const [],
    this.local = const {},
  });

  final OnlineTrack track;
  final double width;
  final List<OnlineTrack> tracks;
  final Map<String, LibraryItem> local;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final tr = track;
    final picture = tr.thumbnail == null
        ? null
        : ref.watch(onlineThumbnailProvider(tr.thumbnail!)).value;
    final obtained = local[tr.videoId];
    final playing = ref.watch(
      queueProvider.select(
        (q) =>
            q.current?.onlineId == tr.videoId ||
            (obtained != null && q.current?.libraryId == obtained.id),
      ),
    );
    final list = tracks.isEmpty ? [tr] : tracks;
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: () {
          final i = list.indexWhere((x) => x.videoId == tr.videoId);
          playOnline(
            ref,
            list,
            i < 0 ? 0 : i,
            unknownArtist: t.unknownArtist,
            local: local,
          );
        },
        semanticLabel: tr.title,
        borderRadius: BorderRadius.circular(MmRadius.md),
        pressScale: 0.98,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverArt(
                  size: width,
                  aspectRatio: 16 / 9,
                  radius: MmRadius.md,
                  shadow: false,
                  seed: tr.videoId.hashCode,
                  imagePath: picture,
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      formatClock(
                        Duration(
                          milliseconds: (tr.durationSecs * 1000).round(),
                        ),
                      ),
                      style: MmType.monoStyle(
                        size: 11,
                        color: const Color(0xFFF1F1F1),
                      ),
                    ),
                  ),
                ),
                if (obtained != null)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Tooltip(
                      message: t.onlineOffline,
                      child: Icon(
                        PhosphorFill.checkCircle,
                        size: 18,
                        color: c.accent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MmType.labelStrong.copyWith(
                color: playing ? c.coralHover : c.fg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tr.channel ?? t.unknownArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.caption.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// What to say when an online search fails, by the core's error code.
({IconData icon, String title, String body}) onlineProblemText(
  L10n t,
  OnlineFailureKind kind,
) => switch (kind) {
  OnlineFailureKind.tools => (
    icon: PhosphorRegular.downloadSimple,
    title: t.onlineToolsTitle,
    body: '',
  ),
  OnlineFailureKind.network => (
    icon: PhosphorRegular.wifiSlash,
    title: t.onlineOfflineTitle,
    body: '',
  ),
  OnlineFailureKind.slow => (
    icon: PhosphorRegular.hourglass,
    title: t.onlineSlowTitle,
    body: '',
  ),
  OnlineFailureKind.blocked => (
    icon: PhosphorRegular.hourglass,
    title: t.onlineBlockedTitle,
    body: t.onlineBlockedBody,
  ),
  _ => (
    icon: PhosphorRegular.warningCircle,
    title: t.onlineErrorTitle,
    body: t.onlineErrorBody,
  ),
};

/// The actions that answer a failure: install the tools (in Obtenir, which
/// asks for consent first), see the tracks already got, or retry.
List<StateAction> onlineProblemActions(
  BuildContext context,
  L10n t,
  OnlineFailureKind kind,
  VoidCallback onRetry,
) => switch (kind) {
  OnlineFailureKind.tools => [
    StateAction(
      t.onlineToolsInstall,
      () => context.go(Routes.get),
      primary: true,
      icon: PhosphorRegular.downloadSimple,
    ),
  ],
  OnlineFailureKind.network => [
    StateAction(t.retry, onRetry, primary: true),
    StateAction(
      t.onlineOpenTracks,
      () => context.go(Routes.tracks),
      icon: PhosphorRegular.musicNote,
    ),
  ],
  _ => [StateAction(t.retry, onRetry, primary: true)],
};

/// A failure on the En ligne page: the whole body.
class OnlineProblemView extends StatelessWidget {
  const OnlineProblemView({
    super.key,
    required this.kind,
    required this.onRetry,
  });

  final OnlineFailureKind kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final text = onlineProblemText(t, kind);
    return EmptyState(
      icon: text.icon,
      title: text.title,
      body: text.body,
      actions: onlineProblemActions(context, t, kind, onRetry),
    );
  }
}

/// A failure inside the search results' « En ligne » section: one line,
/// so the library's results above stay in view.
class OnlineProblemLine extends StatelessWidget {
  const OnlineProblemLine({
    super.key,
    required this.kind,
    required this.onRetry,
  });

  final OnlineFailureKind kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final text = onlineProblemText(t, kind);
    final actions = onlineProblemActions(context, t, kind, onRetry);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(text.icon, size: 20, color: c.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.title,
                  style: MmType.labelStrong.copyWith(color: c.fg),
                ),
                const SizedBox(height: 2),
                Text(text.body, style: MmType.caption.copyWith(color: c.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  children: [
                    for (final a in actions)
                      Pressable(
                        onTap: a.onTap,
                        semanticLabel: a.label,
                        child: Text(
                          a.label,
                          style: MmType.labelStrong.copyWith(
                            fontSize: 13,
                            color: a.primary ? c.coralStrong : c.fgSoft,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
