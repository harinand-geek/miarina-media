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
import 'online_data.dart';

/// One online result, in the style of the Titres rows: picture, title,
/// channel, duration.
class OnlineTile extends ConsumerWidget {
  const OnlineTile({super.key, required this.track, this.onTap});

  final OnlineTrack track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final tr = track;
    return Pressable(
      onTap: onTap,
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
              imageUrl: tr.thumbnail,
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
                    style: MmType.labelStrong.copyWith(color: c.fg),
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
    body: t.onlineToolsBody,
  ),
  OnlineFailureKind.network => (
    icon: PhosphorRegular.wifiSlash,
    title: t.onlineOfflineTitle,
    body: t.onlineOfflineBody,
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
