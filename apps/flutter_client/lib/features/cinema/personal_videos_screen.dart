import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/states.dart';
import '../../design/widgets/track_bar.dart';
import '../../l10n/app_localizations.dart';
import '../common/state_views.dart';
import '../playback/playback.dart';
import 'cinema_data.dart';
import 'cinema_screen.dart';
import 'cinema_widgets.dart';

/// "Vidéos perso" (sidebar, Cinema group): short videos, newest first, as
/// 16:9 tiles. The handoff has no dedicated mockup; it reuses the W-C1
/// "Reprendre" tiles.
class PersonalVideosScreen extends ConsumerWidget {
  const PersonalVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final lib = ref.watch(cinemaLibraryProvider);
    final watch = ref.watch(watchStateProvider).value ?? const WatchState();
    final videos = lib.value?.personal ?? const [];
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());

    final header = Padding(
      padding: mobile
          ? const EdgeInsets.fromLTRB(16, 12, 16, 10)
          : const EdgeInsets.fromLTRB(32, 24, 32, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.navPersonalVideos,
            style: mobile
                ? MmType.titleLg.copyWith(fontSize: 20, color: c.fg)
                : MmType.display.copyWith(color: c.fg),
          ),
          const SizedBox(height: 2),
          if (lib.hasValue)
            Text(
              t.videosCount(videos.length),
              style: MmType.bodySm.copyWith(color: c.muted),
            ),
        ],
      ),
    );

    Widget body;
    if (lib.hasError) {
      body = LibraryErrorView(
        error: lib.error!,
        onRetry: () => ref.invalidate(cinemaLibraryProvider),
      );
    } else if (!lib.hasValue) {
      body = SkeletonGrid(
        aspectRatio: 16 / 9,
        minTile: 240,
        padding: mobile ? 16 : 32,
      );
    } else if (videos.isEmpty) {
      body = LibraryEmpty(
        icon: PhosphorRegular.monitorPlay,
        title: t.personalEmptyTitle,
        body: t.personalEmptyBody,
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) {
          final pad = mobile ? 16.0 : 32.0;
          const gap = 16.0;
          final width = box.maxWidth - pad * 2;
          final cols = mobile
              ? 2
              : math.max(2, ((width + gap) / (240 + gap)).floor());
          final tile = (width - gap * (cols - 1)) / cols;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: gap,
              mainAxisSpacing: 18,
              mainAxisExtent: tile * 9 / 16 + 8 + 20 + 18,
            ),
            itemCount: videos.length,
            itemBuilder: (context, i) {
              final v = videos[i];
              final d = durationOf(v);
              return VideoTile(
                width: tile,
                aspectRatio: 16 / 9,
                title: v.item.title,
                subtitle: date.format(
                  DateTime.fromMillisecondsSinceEpoch(v.addedAt.toInt()),
                ),
                imagePath: v.item.thumbnail,
                seed: v.item.id,
                progress: progressOf(v, watch),
                dimmed: v.item.missing,
                topRight: d == null ? null : PicturePill(formatClock(d)),
                onTap: () async {
                  await playVideos(
                    ref.read(queueProvider.notifier),
                    videos,
                    start: i,
                  );
                  if (context.mounted) openPlayer(context);
                },
              );
            },
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }
}
