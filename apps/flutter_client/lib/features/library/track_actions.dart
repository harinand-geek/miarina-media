import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/widgets/action_sheet.dart';
import '../../design/widgets/cover_art.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../device_media/device_media.dart';
import '../health/health_data.dart';
import '../playback/playback.dart';
import '../playlists/playlists_screen.dart' show showAddToPlaylistDialog;
import 'groups.dart';
import 'library_data.dart';
import 'track_info.dart';

/// « Radio de ce titre »: [seed] then close tracks of the library
/// (smart_queue.dart); says so, or that the library is too small.
Future<void> startTrackRadio(
  BuildContext context,
  WidgetRef ref,
  QueueEntry seed,
) async {
  final t = L10n.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  HapticFeedback.selectionClick();
  final found = await ref
      .read(queueProvider.notifier)
      .startRadio(seed, unknownArtist: t.unknownArtist);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(found > 0 ? t.radioStarted : t.radioEmpty),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// The actions on one title outside the Titres list (album and artist
/// pages on the phone): the same grouped sheet. [onChanged] runs after a
/// change the page must show (favorite, deletion).
Future<void> showTrackActions(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item, {
  VoidCallback? onChanged,
}) {
  final t = L10n.of(context);
  final phone = ref.read(deviceMediaSupportedProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  void toast(String text) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  final entry = queueEntryOf(item, unknownArtist: t.unknownArtist);

  Future<void> enqueue({required bool next}) async {
    await ref.read(queueProvider.notifier).enqueue([entry], next: next);
    toast(next ? t.playNextDone(1) : t.queueAddDone(1));
  }

  Future<void> favorite() async {
    HapticFeedback.lightImpact();
    await ref
        .read(libraryApiProvider)
        .setFavorite(item.id, favorite: !item.favorite);
    ref
        .read(queueProvider.notifier)
        .markFavorite(item.id, favorite: !item.favorite);
    ref.invalidate(favoritesCountProvider);
    onChanged?.call();
  }

  Future<void> share() async {
    final ok = await ref
        .read(deviceMediaApiProvider)
        .share(item.path, item.title);
    if (!ok) toast(t.shareFailed);
  }

  Future<void> delete() async {
    final answer = await ref.read(deviceMediaApiProvider).delete([item.path]);
    if (answer == 'canceled') return;
    if (answer != 'deleted') {
      toast(t.deleteFailed);
      return;
    }
    await ref.read(healthApiProvider).remove([item.id]);
    ref
      ..invalidate(favoritesCountProvider)
      ..invalidate(healthCountsProvider);
    onChanged?.call();
    toast(t.deletedFromPhone(1));
  }

  return showActionSheet(
    context,
    header: SheetHeader(
      leading: CoverArt(
        size: 64,
        radius: 16,
        seed: item.id,
        imagePath: item.thumbnail,
        shadow: false,
      ),
      title: item.title,
      subtitle: item.artist ?? t.unknownArtist,
    ),
    groups: [
      [
        SheetAction(
          icon: PhosphorRegular.arrowBendDownRight,
          label: t.playNext,
          onTap: () => unawaited(enqueue(next: true)),
        ),
        SheetAction(
          icon: PhosphorRegular.queue,
          label: t.addToQueue,
          onTap: () => unawaited(enqueue(next: false)),
        ),
        SheetAction(
          icon: PhosphorRegular.listPlus,
          label: t.addToPlaylist,
          onTap: () =>
              unawaited(showAddToPlaylistDialog(context, ref, [item.id])),
        ),
        if (!item.isVideo)
          SheetAction(
            icon: PhosphorRegular.sparkle,
            label: t.startRadio,
            onTap: () => unawaited(startTrackRadio(context, ref, entry)),
          ),
        SheetAction(
          icon: item.favorite ? PhosphorFill.heart : PhosphorRegular.heart,
          label: item.favorite ? t.favoriteRemove : t.favoriteAdd,
          onTap: () => unawaited(favorite()),
        ),
      ],
      [
        if (item.album != null)
          SheetAction(
            icon: PhosphorRegular.disc,
            label: t.viewAlbum,
            onTap: () => openGroup(context, ref, (
              kind: GroupKind.album,
              name: item.album!,
            )),
          ),
        if (item.artist != null)
          SheetAction(
            icon: PhosphorRegular.user,
            label: t.viewArtist,
            onTap: () => openGroup(context, ref, (
              kind: GroupKind.artist,
              name: item.artist!,
            )),
          ),
        SheetAction(
          icon: PhosphorRegular.info,
          label: t.trackInfo,
          onTap: () => unawaited(showTrackInfo(context, item)),
        ),
      ],
      if (phone)
        [
          SheetAction(
            icon: PhosphorRegular.shareNetwork,
            label: t.share,
            onTap: () => unawaited(share()),
          ),
          SheetAction(
            icon: PhosphorRegular.trash,
            label: t.deleteFromPhone,
            danger: true,
            onTap: () => unawaited(delete()),
          ),
        ],
    ],
  );
}
