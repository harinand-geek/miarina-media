import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/states.dart';
import '../../l10n/app_localizations.dart';
import '../common/state_views.dart';
import '../../src/rust/api/library.dart';
import 'groups.dart';
import 'library_data.dart';

/// W-M1a Albums / W-M1b Artists (Windows) and their Android lists: a grid
/// in auto-fill columns (cards at least 168 px, circles 140 px), virtualised.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key, required this.kind});

  final GroupKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final groups = ref.watch(groupsProvider(kind));
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final albums = kind == GroupKind.album;

    final list = groups.value ?? const <LibraryGroup>[];
    final tracks = list.fold<int>(0, (n, g) => n + g.count.toInt());
    final summary = albums
        ? '${t.albumsCount(list.length)} · ${t.tracksSummary(tracks)}'
        : '${t.artistsCount(list.length)} · ${t.artistsGrouping}';

    final header = Padding(
      padding: mobile
          ? const EdgeInsets.fromLTRB(16, 12, 16, 10)
          : const EdgeInsets.fromLTRB(32, 24, 32, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            albums ? t.navAlbums : t.navArtists,
            style: mobile
                ? MmType.titleLg.copyWith(fontSize: 20, color: c.fg)
                : MmType.display.copyWith(color: c.fg),
          ),
          const SizedBox(height: 2),
          Text(summary, style: MmType.bodySm.copyWith(color: c.muted)),
        ],
      ),
    );

    Widget body;
    if (groups.hasError) {
      body = LibraryErrorView(
        error: groups.error!,
        onRetry: () => ref.invalidate(groupsProvider(kind)),
      );
    } else if (groups.isLoading && list.isEmpty) {
      body = SkeletonGrid(
        minTile: albums ? 168 : 140,
        padding: mobile ? 16 : 32,
      );
    } else if (list.isEmpty) {
      body = LibraryEmpty(
        icon: albums ? PhosphorRegular.vinylRecord : PhosphorRegular.user,
        title: albums ? t.albumsEmptyTitle : t.artistsEmptyTitle,
        body: albums ? t.albumsEmptyBody : t.artistsEmptyBody,
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) {
          final pad = mobile ? 16.0 : 32.0;
          final gap = albums ? 18.0 : 16.0;
          final minTile = albums ? 168.0 : 140.0;
          final width = box.maxWidth - pad * 2;
          final cols = mobile
              ? (albums ? 2 : 3)
              : math.max(2, ((width + gap) / (minTile + gap)).floor());
          final tile = (width - gap * (cols - 1)) / cols;
          // Album cards have an 8 px hover padding around the cover.
          final cover = albums ? tile - 16 : tile - 12;
          final height = albums
              ? cover + 16 + 9 + 18 + 16
              : cover + 8 + 10 + 18 + 16;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: gap,
              mainAxisSpacing: albums ? 14 : 18,
              mainAxisExtent: height,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) => albums
                ? AlbumCard(group: list[i], size: cover)
                : ArtistCircle(group: list[i], size: cover),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (mobile) ...[
          MusicChips(current: albums ? Routes.albums : Routes.artists),
          const SizedBox(height: 12),
        ],
        Expanded(child: body),
      ],
    );
  }
}
